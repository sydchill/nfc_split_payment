"""Domain endpoints: friends, bills/splits, transactions, sales summary."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from .. import services as svc

bp = Blueprint("api", __name__, url_prefix="/api")


def _user():
    return svc.get_user(get_jwt_identity())


# ---------------------------------------------------------------------------
# Friends
# ---------------------------------------------------------------------------
@bp.get("/friends")
@jwt_required()
def list_friends():
    return jsonify([f.to_dict() for f in svc.list_friends(_user())])


@bp.post("/friends")
@jwt_required()
def add_friend():
    data = request.get_json(silent=True) or {}
    friend = svc.add_friend(_user(), data.get("name"), data.get("color"))
    return jsonify(friend.to_dict()), 201


@bp.delete("/friends/<friend_id>")
@jwt_required()
def delete_friend(friend_id: str):
    svc.delete_friend(_user(), friend_id)
    return "", 204


# ---------------------------------------------------------------------------
# Bills / splits
# ---------------------------------------------------------------------------
@bp.get("/bills")
@jwt_required()
def list_bills():
    return jsonify([b.to_dict() for b in svc.list_bills(_user())])


@bp.post("/bills")
@jwt_required()
def create_bill():
    data = request.get_json(silent=True) or {}
    bill = svc.create_bill(
        _user(),
        merchant=data.get("merchant"),
        total=data.get("total"),
        participants=data.get("participants") or [],
    )
    return jsonify(bill.to_dict()), 201


@bp.get("/bills/<bill_id>")
@jwt_required()
def get_bill(bill_id: str):
    return jsonify(svc.get_bill(_user(), bill_id).to_dict())


@bp.post("/bills/<bill_id>/participants/<participant_id>/pay")
@jwt_required()
def pay_participant(bill_id: str, participant_id: str):
    data = request.get_json(silent=True) or {}
    bill, txn = svc.pay_participant(
        _user(), bill_id, participant_id, data.get("method") or "card"
    )
    return jsonify({"bill": bill.to_dict(), "transaction": txn.to_dict()})


@bp.post("/bills/<bill_id>/settle")
@jwt_required()
def settle_bill(bill_id: str):
    return jsonify(svc.settle_bill(_user(), bill_id).to_dict())


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------
@bp.get("/transactions")
@jwt_required()
def list_transactions():
    limit = min(int(request.args.get("limit", 100)), 500)
    return jsonify([t.to_dict() for t in svc.list_transactions(_user(), limit)])


@bp.post("/transactions/sale")
@jwt_required()
def record_sale():
    data = request.get_json(silent=True) or {}
    txn = svc.record_sale(
        _user(),
        amount=data.get("amount"),
        method=data.get("method") or "card",
        reference=data.get("reference"),
        subtitle=data.get("subtitle"),
        title=data.get("title") or "Card sale",
    )
    return jsonify(txn.to_dict()), 201


@bp.get("/sales/today")
@jwt_required()
def sales_today():
    return jsonify(svc.today_sales(_user()))
