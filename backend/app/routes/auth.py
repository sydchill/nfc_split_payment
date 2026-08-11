"""Authentication endpoints: register, login, refresh, me, logout."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
)

from ..extensions import db
from ..google_auth import sign_in_with_google
from ..models import User
from ..services import authenticate, get_user, register_user
from .blocklist import revoke

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


def _tokens(user: User) -> dict:
    return {
        "access_token": create_access_token(identity=user.id),
        "refresh_token": create_refresh_token(identity=user.id),
        "user": user.to_dict(),
    }


@bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    user = register_user(
        email=data.get("email"),
        password=data.get("password"),
        mode=data.get("mode", "personal"),
        full_name=data.get("full_name"),
        business_name=data.get("business_name"),
        category=data.get("category"),
    )
    return jsonify(_tokens(user)), 201


@bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    user = authenticate(data.get("email"), data.get("password"))
    return jsonify(_tokens(user))


@bp.post("/google")
def google():
    """Sign in (or sign up) with a Google ID token from the mobile app."""
    data = request.get_json(silent=True) or {}
    user, created = sign_in_with_google(
        data.get("id_token") or "",
        mode=data.get("mode") or "personal",
    )
    return jsonify(_tokens(user)), (201 if created else 200)


@bp.post("/refresh")
@jwt_required(refresh=True)
def refresh():
    user = get_user(get_jwt_identity())
    return jsonify({"access_token": create_access_token(identity=user.id)})


@bp.get("/me")
@jwt_required()
def me():
    return jsonify(get_user(get_jwt_identity()).to_dict())


@bp.patch("/me")
@jwt_required()
def update_me():
    user = get_user(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    for field in ("full_name", "business_name", "category"):
        if field in data:
            setattr(user, field, (data.get(field) or "").strip() or None)
    if data.get("mode") in {"personal", "business"}:
        user.mode = data["mode"]
    db.session.commit()
    return jsonify(user.to_dict())


@bp.post("/logout")
@jwt_required()
def logout():
    """Revoke the presented access token so it can't be reused."""
    revoke(get_jwt()["jti"])
    return jsonify({"message": "Signed out"})
