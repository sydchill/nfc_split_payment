"""Google Sign-In: verify an ID token and resolve it to a Patela account.

The mobile app performs native Google Sign-In and sends the resulting **ID
token** here. The token is a JWT signed by Google; this module verifies its
signature, issuer, audience and expiry against Google's published keys before
trusting anything inside it.

Never trust the email/sub from an unverified token — verification is what proves
the client actually signed in with Google rather than fabricating a payload.
"""

from __future__ import annotations

from flask import current_app
from sqlalchemy import select

from .extensions import db
from .models import User
from .services import ServiceError

_GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


def _verify_id_token(token: str) -> dict:
    """Return the verified token payload, or raise [ServiceError]."""
    client_ids = current_app.config.get("GOOGLE_CLIENT_IDS") or []
    if not client_ids:
        raise ServiceError(
            "Google sign-in is not configured on the server "
            "(set GOOGLE_CLIENT_ID in the backend environment).",
            503,
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError:  # pragma: no cover - dependency missing
        raise ServiceError(
            "Server is missing the google-auth dependency.", 503
        ) from None

    last_error: Exception | None = None
    for client_id in client_ids:
        try:
            payload = google_id_token.verify_oauth2_token(
                token, google_requests.Request(), client_id
            )
            if payload.get("iss") not in _GOOGLE_ISSUERS:
                raise ValueError("Wrong issuer.")
            return payload
        except ValueError as exc:  # bad signature / audience / expiry
            last_error = exc
            continue

    current_app.logger.warning("Google ID token rejected: %s", last_error)
    raise ServiceError("Google sign-in failed: invalid token.", 401)


def sign_in_with_google(id_token_str: str, *, mode: str = "personal") -> tuple[User, bool]:
    """Verify the token and find-or-create the matching account.

    Returns `(user, created)`. Accounts are matched on Google's `sub` first, then
    on a verified email address — so an existing email/password account gets
    linked to Google rather than duplicated.
    """
    if not id_token_str:
        raise ServiceError("Missing Google id_token.")
    if mode not in {"personal", "business"}:
        mode = "personal"

    payload = _verify_id_token(id_token_str)

    sub = payload.get("sub")
    email = (payload.get("email") or "").strip().lower()
    if not sub:
        raise ServiceError("Google token has no subject.", 401)
    if not email:
        raise ServiceError("Google account has no email address.", 400)
    if payload.get("email_verified") is False:
        raise ServiceError("Your Google email address is not verified.", 403)

    # 1) Already linked to this Google account.
    user = db.session.scalar(select(User).where(User.google_sub == sub))
    if user:
        return user, False

    # 2) Same verified email as an existing account -> link it.
    user = db.session.scalar(select(User).where(User.email == email))
    if user:
        user.google_sub = sub
        if not user.full_name and payload.get("name"):
            user.full_name = payload["name"]
        db.session.commit()
        return user, False

    # 3) Brand new account.
    user = User(
        email=email,
        google_sub=sub,
        mode=mode,
        full_name=(payload.get("name") or "").strip() or None,
    )
    # password_hash stays null: this account signs in with Google only.
    db.session.add(user)
    db.session.commit()
    return user, True
