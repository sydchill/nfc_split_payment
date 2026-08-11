"""Business logic for Patela.

All rules live here rather than in the client or in the database: ownership
checks, split maths, marking shares paid, ledger writes, and sales rollups.
Routes stay thin and only translate HTTP <-> these functions.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import func, select

from .extensions import db
from .models import Bill, BillParticipant, Friend, Transaction, User, utcnow

VALID_METHODS = {"card", "apple_pay", "google_pay"}
DEFAULT_FRIEND_COLOR = "#E08579"


class ServiceError(Exception):
    """Raised for expected failures; carries an HTTP status."""

    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.message = message
        self.status = status


class NotFound(ServiceError):
    def __init__(self, what: str = "Resource"):
        super().__init__(f"{what} not found", 404)


# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------
def register_user(
    *,
    email: str,
    password: str,
    mode: str = "personal",
    full_name: str | None = None,
    business_name: str | None = None,
    category: str | None = None,
) -> User:
    email = (email or "").strip().lower()
    if not email or "@" not in email:
        raise ServiceError("Enter a valid email address.")
    if not password or len(password) < 8:
        raise ServiceError("Password must be at least 8 characters.")
    if mode not in {"personal", "business"}:
        raise ServiceError("Account type must be 'personal' or 'business'.")
    if db.session.scalar(select(User).where(User.email == email)):
        raise ServiceError("An account with that email already exists.", 409)

    user = User(
        email=email,
        mode=mode,
        full_name=(full_name or "").strip() or None,
        business_name=(business_name or "").strip() or None,
        category=(category or "").strip() or None,
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()
    return user


def authenticate(email: str, password: str) -> User:
    email = (email or "").strip().lower()
    user = db.session.scalar(select(User).where(User.email == email))
    if not user or not user.check_password(password or ""):
        raise ServiceError("Invalid email or password.", 401)
    return user


def get_user(user_id: str) -> User:
    user = db.session.get(User, user_id)
    if not user:
        raise NotFound("User")
    return user


# ---------------------------------------------------------------------------
# Friends
# ---------------------------------------------------------------------------
def list_friends(user: User) -> list[Friend]:
    return list(
        db.session.scalars(
            select(Friend).where(Friend.owner_id == user.id).order_by(Friend.created_at)
        )
    )


def add_friend(user: User, name: str, color: str | None = None) -> Friend:
    name = (name or "").strip()
    if not name:
        raise ServiceError("A friend needs a name.")
    friend = Friend(owner_id=user.id, name=name, color=color or DEFAULT_FRIEND_COLOR)
    db.session.add(friend)
    db.session.commit()
    return friend


def delete_friend(user: User, friend_id: str) -> None:
    friend = db.session.get(Friend, friend_id)
    if not friend or friend.owner_id != user.id:
        raise NotFound("Friend")
    db.session.delete(friend)
    db.session.commit()


# ---------------------------------------------------------------------------
# Bills / splits
# ---------------------------------------------------------------------------
def _own_bill(user: User, bill_id: str) -> Bill:
    bill = db.session.get(Bill, bill_id)
    if not bill or bill.owner_id != user.id:
        raise NotFound("Bill")
    return bill


def create_bill(
    user: User, *, merchant: str, total: float, participants: list[dict]
) -> Bill:
    merchant = (merchant or "").strip()
    if not merchant:
        raise ServiceError("Enter where you paid.")
    if total is None or float(total) <= 0:
        raise ServiceError("Enter the bill total.")
    if not participants:
        raise ServiceError("Add at least one friend to split with.")

    shares = sum(float(p.get("amount") or 0) for p in participants)
    if round(shares, 2) > round(float(total), 2):
        raise ServiceError("Friends' shares exceed the bill total.")

    bill = Bill(owner_id=user.id, merchant=merchant, total=Decimal(str(total)))
    for p in participants:
        name = (p.get("name") or "").strip()
        if not name:
            raise ServiceError("Every participant needs a name.")
        friend_id = p.get("friend_id")
        if friend_id:
            friend = db.session.get(Friend, friend_id)
            if not friend or friend.owner_id != user.id:
                raise ServiceError("Unknown friend in participants.", 400)
        bill.participants.append(
            BillParticipant(
                friend_id=friend_id,
                name=name,
                color=p.get("color") or DEFAULT_FRIEND_COLOR,
                amount=Decimal(str(p.get("amount") or 0)),
            )
        )
    db.session.add(bill)
    db.session.commit()
    return bill


def list_bills(user: User, limit: int = 50) -> list[Bill]:
    return list(
        db.session.scalars(
            select(Bill)
            .where(Bill.owner_id == user.id)
            .order_by(Bill.created_at.desc())
            .limit(limit)
        )
    )


def get_bill(user: User, bill_id: str) -> Bill:
    return _own_bill(user, bill_id)


def pay_participant(
    user: User, bill_id: str, participant_id: str, method: str
) -> tuple[Bill, Transaction]:
    """Mark a share paid and write the matching ledger entry (idempotent)."""
    if method not in VALID_METHODS:
        raise ServiceError(f"method must be one of {sorted(VALID_METHODS)}")

    bill = _own_bill(user, bill_id)
    participant = next((p for p in bill.participants if p.id == participant_id), None)
    if participant is None:
        raise NotFound("Participant")
    if participant.paid:
        raise ServiceError("That share is already paid.", 409)

    participant.paid = True
    participant.paid_at = utcnow()
    participant.method = method

    txn = Transaction(
        owner_id=user.id,
        kind="split_incoming",
        title=participant.name,
        subtitle=f"Bill split · {bill.merchant}",
        amount=participant.amount,
        method=method,
        bill_id=bill.id,
    )
    db.session.add(txn)

    # Auto-settle once every share is in.
    if all(p.paid for p in bill.participants):
        bill.settled_at = utcnow()

    db.session.commit()
    return bill, txn


def settle_bill(user: User, bill_id: str) -> Bill:
    bill = _own_bill(user, bill_id)
    if bill.settled_at is None:
        bill.settled_at = utcnow()
        db.session.commit()
    return bill


# ---------------------------------------------------------------------------
# Transactions / sales
# ---------------------------------------------------------------------------
def list_transactions(user: User, limit: int = 100) -> list[Transaction]:
    return list(
        db.session.scalars(
            select(Transaction)
            .where(Transaction.owner_id == user.id)
            .order_by(Transaction.created_at.desc())
            .limit(limit)
        )
    )


def record_sale(
    user: User,
    *,
    amount: float,
    method: str,
    reference: str | None = None,
    subtitle: str | None = None,
    title: str = "Card sale",
) -> Transaction:
    if amount is None or float(amount) <= 0:
        raise ServiceError("Sale amount must be greater than zero.")
    if method not in VALID_METHODS:
        raise ServiceError(f"method must be one of {sorted(VALID_METHODS)}")

    # Idempotency: the same reference must not create a duplicate sale.
    if reference:
        existing = db.session.scalar(
            select(Transaction).where(
                Transaction.owner_id == user.id,
                Transaction.reference == reference,
                Transaction.kind == "sale",
            )
        )
        if existing:
            return existing

    txn = Transaction(
        owner_id=user.id,
        kind="sale",
        title=title,
        subtitle=subtitle,
        amount=Decimal(str(amount)),
        method=method,
        reference=reference,
    )
    db.session.add(txn)
    db.session.commit()
    return txn


def today_sales(user: User) -> dict:
    """Total / count / average of today's sales for this user."""
    start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    row = db.session.execute(
        select(
            func.coalesce(func.sum(Transaction.amount), 0),
            func.count(Transaction.id),
        ).where(
            Transaction.owner_id == user.id,
            Transaction.kind == "sale",
            Transaction.created_at >= start,
        )
    ).one()
    total, count = float(row[0] or 0), int(row[1] or 0)
    return {
        "count": count,
        "total": round(total, 2),
        "average": round(total / count, 2) if count else 0.0,
        "window_start": start.isoformat(),
        "window_end": (start + timedelta(days=1)).isoformat(),
    }
