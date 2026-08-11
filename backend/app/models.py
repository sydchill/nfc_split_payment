"""SQLAlchemy models for Patela.

The schema is split in two so identity is isolated from domain data:

    auth schema   auth.users               credentials + account type only
    app  schema   app.friends              business-logic data, each row
                  app.bills                owned by an auth.users id
                  app.bill_participants
                  app.transactions

That boundary keeps password hashes in one place, makes it possible to grant
narrower privileges per schema later, and means a domain migration can never
accidentally alter the credentials table.

Ownership is enforced in the service layer (every query is scoped to the
authenticated user), replacing the row-level-security policies used previously.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Index, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from werkzeug.security import check_password_hash, generate_password_hash

from .extensions import db

#: Identity / credentials live here.
AUTH_SCHEMA = "auth"
#: Business-logic data lives here.
APP_SCHEMA = "app"

ALL_SCHEMAS = (AUTH_SCHEMA, APP_SCHEMA)

_USERS = f"{AUTH_SCHEMA}.users"


def _uuid() -> str:
    return str(uuid.uuid4())


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _money(value: Decimal | float | int | None) -> float:
    return float(value or 0)


class User(db.Model):
    """An account. `mode` decides which home screen the app shows."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    # Null for accounts that only sign in with Google (no password ever set).
    password_hash: Mapped[str | None] = mapped_column(String(255))
    # Google's stable subject id, set when the account is linked to Google.
    google_sub: Mapped[str | None] = mapped_column(String(64), unique=True, index=True)
    mode: Mapped[str] = mapped_column(String(16), nullable=False, default="personal")
    full_name: Mapped[str | None] = mapped_column(String(120))
    business_name: Mapped[str | None] = mapped_column(String(120))
    category: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(default=utcnow, nullable=False)

    friends: Mapped[list[Friend]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    bills: Mapped[list[Bill]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    transactions: Mapped[list[Transaction]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint("mode in ('personal','business')", name="ck_users_mode"),
        {"schema": AUTH_SCHEMA},
    )

    # ---- password handling ----
    def set_password(self, raw: str) -> None:
        self.password_hash = generate_password_hash(raw)

    def check_password(self, raw: str) -> bool:
        # Google-only accounts have no password: password login must fail.
        if not self.password_hash:
            return False
        return check_password_hash(self.password_hash, raw)

    @property
    def has_password(self) -> bool:
        return bool(self.password_hash)

    @property
    def google_linked(self) -> bool:
        return bool(self.google_sub)

    # ---- serialisation ----
    @property
    def display_name(self) -> str:
        if self.mode == "business":
            return (self.business_name or "").strip() or "Your business"
        return (self.full_name or "").strip() or self.email.split("@")[0]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "email": self.email,
            "mode": self.mode,
            "full_name": self.full_name,
            "business_name": self.business_name,
            "category": self.category,
            "display_name": self.display_name,
            "has_password": self.has_password,
            "google_linked": self.google_linked,
            "created_at": self.created_at.isoformat(),
        }


class Friend(db.Model):
    """A saved contact a personal user can split bills with."""

    __tablename__ = "friends"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    owner_id: Mapped[str] = mapped_column(
        ForeignKey(f"{_USERS}.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    color: Mapped[str] = mapped_column(String(9), nullable=False, default="#2E3A87")
    created_at: Mapped[datetime] = mapped_column(default=utcnow, nullable=False)

    owner: Mapped[User] = relationship(back_populates="friends")

    __table_args__ = ({"schema": APP_SCHEMA},)

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name, "color": self.color}


class Bill(db.Model):
    """A split: where the user paid, the total, and who owes what."""

    __tablename__ = "bills"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    owner_id: Mapped[str] = mapped_column(
        ForeignKey(f"{_USERS}.id", ondelete="CASCADE"), nullable=False
    )
    merchant: Mapped[str] = mapped_column(String(160), nullable=False)
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(default=utcnow, nullable=False)
    settled_at: Mapped[datetime | None] = mapped_column()

    owner: Mapped[User] = relationship(back_populates="bills")
    participants: Mapped[list[BillParticipant]] = relationship(
        back_populates="bill",
        cascade="all, delete-orphan",
        order_by="BillParticipant.created_at",
    )

    __table_args__ = (
        CheckConstraint("total >= 0", name="ck_bills_total_non_negative"),
        Index("ix_bills_owner_created", "owner_id", "created_at"),
        {"schema": APP_SCHEMA},
    )

    # ---- derived amounts (business logic lives server-side) ----
    @property
    def owed_total(self) -> float:
        return round(sum(_money(p.amount) for p in self.participants), 2)

    @property
    def collected(self) -> float:
        return round(sum(_money(p.amount) for p in self.participants if p.paid), 2)

    @property
    def your_share(self) -> float:
        return max(0.0, round(_money(self.total) - self.owed_total, 2))

    @property
    def all_paid(self) -> bool:
        return bool(self.participants) and all(p.paid for p in self.participants)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "merchant": self.merchant,
            "total": _money(self.total),
            "owed_total": self.owed_total,
            "collected": self.collected,
            "your_share": self.your_share,
            "all_paid": self.all_paid,
            "paid_count": sum(1 for p in self.participants if p.paid),
            "created_at": self.created_at.isoformat(),
            "settled_at": self.settled_at.isoformat() if self.settled_at else None,
            "participants": [p.to_dict() for p in self.participants],
        }


class BillParticipant(db.Model):
    """One friend's share of a specific bill."""

    __tablename__ = "bill_participants"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    bill_id: Mapped[str] = mapped_column(
        ForeignKey(f"{APP_SCHEMA}.bills.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    friend_id: Mapped[str | None] = mapped_column(
        ForeignKey(f"{APP_SCHEMA}.friends.id", ondelete="SET NULL")
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    color: Mapped[str] = mapped_column(String(9), nullable=False, default="#E08579")
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    paid: Mapped[bool] = mapped_column(nullable=False, default=False)
    paid_at: Mapped[datetime | None] = mapped_column()
    method: Mapped[str | None] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(default=utcnow, nullable=False)

    bill: Mapped[Bill] = relationship(back_populates="participants")

    __table_args__ = (
        CheckConstraint("amount >= 0", name="ck_participant_amount_non_negative"),
        {"schema": APP_SCHEMA},
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "friend_id": self.friend_id,
            "name": self.name,
            "color": self.color,
            "amount": _money(self.amount),
            "paid": self.paid,
            "paid_at": self.paid_at.isoformat() if self.paid_at else None,
            "method": self.method,
        }


class Transaction(db.Model):
    """Unified ledger entry backing the Activity feed and receipts."""

    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    owner_id: Mapped[str] = mapped_column(
        ForeignKey(f"{_USERS}.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[str] = mapped_column(String(24), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(200))
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    method: Mapped[str | None] = mapped_column(String(16))
    reference: Mapped[str | None] = mapped_column(String(64))
    bill_id: Mapped[str | None] = mapped_column(
        ForeignKey(f"{APP_SCHEMA}.bills.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(default=utcnow, nullable=False)

    owner: Mapped[User] = relationship(back_populates="transactions")

    __table_args__ = (
        CheckConstraint(
            "kind in ('sale','split_incoming','refund')", name="ck_txn_kind"
        ),
        Index("ix_transactions_owner_created", "owner_id", "created_at"),
        {"schema": APP_SCHEMA},
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "title": self.title,
            "subtitle": self.subtitle,
            "amount": _money(self.amount),
            "method": self.method,
            "reference": self.reference,
            "bill_id": self.bill_id,
            "created_at": self.created_at.isoformat(),
        }
