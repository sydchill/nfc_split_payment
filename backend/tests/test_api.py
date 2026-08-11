"""End-to-end API tests: auth, friends, splits, sales."""

import json

import pytest

from app import (
    TestConfig,
    attach_sqlite_schemas,
    create_app,
    db,
    ensure_schemas,
)


@pytest.fixture()
def app():
    app = create_app(TestConfig)
    with app.app_context():
        # The models live in the `auth` and `app` schemas: create them on
        # PostgreSQL, or emulate them via ATTACH on SQLite.
        ensure_schemas()
        attach_sqlite_schemas()
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


def auth_headers(client, email="alex@example.com", mode="personal", **extra):
    res = client.post(
        "/api/auth/register",
        json={
            "email": email,
            "password": "hunter2pass",
            "mode": mode,
            "full_name": "Alex Rivera",
            **extra,
        },
    )
    assert res.status_code == 201, res.get_json()
    return {"Authorization": f"Bearer {res.get_json()['access_token']}"}


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
def test_health(client):
    assert client.get("/api/health").get_json()["status"] == "ok"


def test_register_login_and_me(client):
    headers = auth_headers(client)
    me = client.get("/api/auth/me", headers=headers).get_json()
    assert me["email"] == "alex@example.com"
    assert me["mode"] == "personal"
    assert me["display_name"] == "Alex Rivera"

    login = client.post(
        "/api/auth/login",
        json={"email": "alex@example.com", "password": "hunter2pass"},
    )
    assert login.status_code == 200
    assert login.get_json()["access_token"]


def test_business_account_display_name(client):
    headers = auth_headers(
        client, email="cafe@example.com", mode="business", business_name="Fig & Vine"
    )
    me = client.get("/api/auth/me", headers=headers).get_json()
    assert me["display_name"] == "Fig & Vine"


def test_duplicate_email_rejected(client):
    auth_headers(client)
    res = client.post(
        "/api/auth/register",
        json={"email": "alex@example.com", "password": "hunter2pass"},
    )
    assert res.status_code == 409


def test_bad_password_rejected(client):
    auth_headers(client)
    res = client.post(
        "/api/auth/login", json={"email": "alex@example.com", "password": "wrong"}
    )
    assert res.status_code == 401


def test_short_password_rejected(client):
    res = client.post(
        "/api/auth/register", json={"email": "x@example.com", "password": "short"}
    )
    assert res.status_code == 400


def test_protected_route_requires_token(client):
    assert client.get("/api/friends").status_code == 401


def test_logout_revokes_token(client):
    headers = auth_headers(client)
    assert client.post("/api/auth/logout", headers=headers).status_code == 200
    assert client.get("/api/auth/me", headers=headers).status_code == 401


# ---------------------------------------------------------------------------
# Friends
# ---------------------------------------------------------------------------
def test_friends_crud_and_isolation(client):
    a = auth_headers(client, email="a@example.com")
    b = auth_headers(client, email="b@example.com")

    created = client.post("/api/friends", json={"name": "Maya Chen"}, headers=a)
    assert created.status_code == 201
    friend_id = created.get_json()["id"]

    assert len(client.get("/api/friends", headers=a).get_json()) == 1
    # B must not see A's friends.
    assert client.get("/api/friends", headers=b).get_json() == []
    # B must not delete A's friend.
    assert client.delete(f"/api/friends/{friend_id}", headers=b).status_code == 404

    assert client.delete(f"/api/friends/{friend_id}", headers=a).status_code == 204
    assert client.get("/api/friends", headers=a).get_json() == []


# ---------------------------------------------------------------------------
# Splits
# ---------------------------------------------------------------------------
def _make_bill(client, headers, total=128.40, share=32.10, n=3):
    names = ["Maya Chen", "Leo Park", "Priya Rao"][:n]
    participants = [{"name": nm, "amount": share} for nm in names]
    res = client.post(
        "/api/bills",
        json={"merchant": "The Fig Tree", "total": total, "participants": participants},
        headers=headers,
    )
    assert res.status_code == 201, res.get_json()
    return res.get_json()


def test_create_bill_computes_shares(client):
    headers = auth_headers(client)
    bill = _make_bill(client, headers)
    assert bill["merchant"] == "The Fig Tree"
    assert bill["owed_total"] == pytest.approx(96.30)
    assert bill["your_share"] == pytest.approx(32.10)
    assert bill["collected"] == 0
    assert bill["all_paid"] is False
    assert len(bill["participants"]) == 3


def test_bill_rejects_shares_over_total(client):
    headers = auth_headers(client)
    res = client.post(
        "/api/bills",
        json={
            "merchant": "X",
            "total": 50,
            "participants": [{"name": "A", "amount": 60}],
        },
        headers=headers,
    )
    assert res.status_code == 400


def test_bill_requires_participants(client):
    headers = auth_headers(client)
    res = client.post(
        "/api/bills",
        json={"merchant": "X", "total": 50, "participants": []},
        headers=headers,
    )
    assert res.status_code == 400


def test_pay_participants_settles_bill_and_writes_ledger(client):
    headers = auth_headers(client)
    bill = _make_bill(client, headers)

    for i, p in enumerate(bill["participants"], start=1):
        res = client.post(
            f"/api/bills/{bill['id']}/participants/{p['id']}/pay",
            json={"method": "google_pay"},
            headers=headers,
        )
        assert res.status_code == 200, res.get_json()
        body = res.get_json()
        assert body["transaction"]["kind"] == "split_incoming"
        assert body["bill"]["paid_count"] == i

    final = client.get(f"/api/bills/{bill['id']}", headers=headers).get_json()
    assert final["all_paid"] is True
    assert final["collected"] == pytest.approx(96.30)
    assert final["settled_at"] is not None

    txns = client.get("/api/transactions", headers=headers).get_json()
    assert len(txns) == 3
    assert sum(t["amount"] for t in txns) == pytest.approx(96.30)


def test_double_pay_rejected(client):
    headers = auth_headers(client)
    bill = _make_bill(client, headers, n=1, share=10)
    pid = bill["participants"][0]["id"]
    url = f"/api/bills/{bill['id']}/participants/{pid}/pay"
    assert client.post(url, json={"method": "card"}, headers=headers).status_code == 200
    assert client.post(url, json={"method": "card"}, headers=headers).status_code == 409


def test_bill_isolated_between_users(client):
    a = auth_headers(client, email="a@example.com")
    b = auth_headers(client, email="b@example.com")
    bill = _make_bill(client, a)
    assert client.get(f"/api/bills/{bill['id']}", headers=b).status_code == 404
    assert client.get("/api/bills", headers=b).get_json() == []


def test_invalid_pay_method_rejected(client):
    headers = auth_headers(client)
    bill = _make_bill(client, headers, n=1, share=5)
    pid = bill["participants"][0]["id"]
    res = client.post(
        f"/api/bills/{bill['id']}/participants/{pid}/pay",
        json={"method": "bitcoin"},
        headers=headers,
    )
    assert res.status_code == 400


# ---------------------------------------------------------------------------
# Sales
# ---------------------------------------------------------------------------
def test_record_sale_and_today_summary(client):
    headers = auth_headers(client, email="cafe@example.com", mode="business")
    assert client.get("/api/sales/today", headers=headers).get_json() == {
        "count": 0,
        "total": 0,
        "average": 0.0,
        **{
            k: client.get("/api/sales/today", headers=headers).get_json()[k]
            for k in ("window_start", "window_end")
        },
    }

    for amount in (12.50, 6.75):
        res = client.post(
            "/api/transactions/sale",
            json={
                "amount": amount,
                "method": "card",
                "reference": f"TXN-{int(amount * 100)}",
                "subtitle": "Fig & Vine · card tap",
            },
            headers=headers,
        )
        assert res.status_code == 201, res.get_json()

    summary = client.get("/api/sales/today", headers=headers).get_json()
    assert summary["count"] == 2
    assert summary["total"] == pytest.approx(19.25)
    # 19.25 / 2 = 9.625, rounded to 2dp.
    assert summary["average"] == pytest.approx(9.625, abs=0.01)


def test_sale_reference_is_idempotent(client):
    headers = auth_headers(client, email="cafe@example.com", mode="business")
    payload = {"amount": 20, "method": "card", "reference": "TXN-DUP"}
    first = client.post("/api/transactions/sale", json=payload, headers=headers)
    second = client.post("/api/transactions/sale", json=payload, headers=headers)
    assert first.get_json()["id"] == second.get_json()["id"]
    assert len(client.get("/api/transactions", headers=headers).get_json()) == 1


def test_sale_rejects_zero_amount(client):
    headers = auth_headers(client, email="cafe@example.com", mode="business")
    res = client.post(
        "/api/transactions/sale", json={"amount": 0, "method": "card"}, headers=headers
    )
    assert res.status_code == 400


# ---------------------------------------------------------------------------
# Google Sign-In
# ---------------------------------------------------------------------------
@pytest.fixture()
def fake_google(monkeypatch):
    """Stub Google's token verification; returns whatever payload we set."""
    payload: dict = {}

    def _verify(token: str) -> dict:
        if token == "bad-token":
            from app.services import ServiceError

            raise ServiceError("Google sign-in failed: invalid token.", 401)
        return payload

    monkeypatch.setattr("app.google_auth._verify_id_token", _verify)
    return payload


def test_google_sign_in_creates_account(client, app, fake_google):
    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    fake_google.update(
        {
            "sub": "google-sub-1",
            "email": "gmail.user@gmail.com",
            "email_verified": True,
            "name": "Gmail User",
        }
    )
    res = client.post(
        "/api/auth/google", json={"id_token": "good", "mode": "personal"}
    )
    assert res.status_code == 201, res.get_json()
    body = res.get_json()
    assert body["access_token"]
    assert body["user"]["email"] == "gmail.user@gmail.com"
    assert body["user"]["display_name"] == "Gmail User"
    assert body["user"]["google_linked"] is True
    assert body["user"]["has_password"] is False

    # Signing in again reuses the same account (200, not 201).
    again = client.post("/api/auth/google", json={"id_token": "good"})
    assert again.status_code == 200
    assert again.get_json()["user"]["id"] == body["user"]["id"]


def test_google_sign_in_links_existing_email_account(client, app, fake_google):
    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    headers = auth_headers(client, email="alex@example.com")
    existing_id = client.get("/api/auth/me", headers=headers).get_json()["id"]

    fake_google.update(
        {
            "sub": "google-sub-2",
            "email": "alex@example.com",
            "email_verified": True,
            "name": "Alex Rivera",
        }
    )
    res = client.post("/api/auth/google", json={"id_token": "good"})
    assert res.status_code == 200  # linked, not created
    body = res.get_json()
    assert body["user"]["id"] == existing_id  # same account, no duplicate
    assert body["user"]["google_linked"] is True
    assert body["user"]["has_password"] is True  # password still works too


def test_google_rejects_invalid_token(client, app, fake_google):
    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    res = client.post("/api/auth/google", json={"id_token": "bad-token"})
    assert res.status_code == 401


def test_google_rejects_unverified_email(client, app, fake_google):
    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    fake_google.update(
        {"sub": "s3", "email": "nope@gmail.com", "email_verified": False}
    )
    res = client.post("/api/auth/google", json={"id_token": "good"})
    assert res.status_code == 403


def test_google_disabled_when_not_configured(client, app):
    app.config["GOOGLE_CLIENT_IDS"] = []
    res = client.post("/api/auth/google", json={"id_token": "anything"})
    assert res.status_code == 503
    assert "not configured" in res.get_json()["error"]


def test_google_only_account_cannot_password_login(client, app, fake_google):
    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    fake_google.update(
        {"sub": "s4", "email": "googleonly@gmail.com", "email_verified": True}
    )
    client.post("/api/auth/google", json={"id_token": "good"})
    res = client.post(
        "/api/auth/login",
        json={"email": "googleonly@gmail.com", "password": "anything-at-all"},
    )
    assert res.status_code == 401


def test_transactions_isolated_between_users(client):
    a = auth_headers(client, email="a@example.com")
    b = auth_headers(client, email="b@example.com")
    client.post(
        "/api/transactions/sale",
        json={"amount": 10, "method": "card", "reference": "R1"},
        headers=a,
    )
    assert len(client.get("/api/transactions", headers=a).get_json()) == 1
    assert client.get("/api/transactions", headers=b).get_json() == []


# ---------------------------------------------------------------------------
# Response hygiene
# ---------------------------------------------------------------------------
# `User.to_dict` is an allowlist, so a newly added column is excluded by
# default. These tests fail if someone turns it into a column dump, or adds a
# secret to the list — the credential material must never leave the server, and
# `google_sub` is a stable identifier for the person across Google services.
SECRET_USER_FIELDS = ("password_hash", "google_sub", "password")


def _assert_no_secrets(payload: dict) -> None:
    for field in SECRET_USER_FIELDS:
        assert field not in payload, f"{field} leaked in {sorted(payload)}"


def test_me_exposes_no_credential_material(client):
    headers = auth_headers(client)
    me = client.get("/api/auth/me", headers=headers).get_json()

    _assert_no_secrets(me)
    # The booleans the UI needs are derived, not the underlying values.
    assert me["has_password"] is True
    assert me["google_linked"] is False
    # Nothing resembling the stored hash appears anywhere in the response.
    assert "pbkdf2" not in json.dumps(me)


def test_auth_responses_expose_no_credential_material(client, app, fake_google):
    """Every endpoint that returns a user body, not just /me."""
    _assert_no_secrets(
        client.post(
            "/api/auth/register",
            json={"email": "new@example.com", "password": "hunter2pass"},
        ).get_json()["user"]
    )
    _assert_no_secrets(
        client.post(
            "/api/auth/login",
            json={"email": "new@example.com", "password": "hunter2pass"},
        ).get_json()["user"]
    )

    app.config["GOOGLE_CLIENT_IDS"] = ["test-client-id"]
    fake_google.update(
        {"sub": "google-sub-hygiene", "email": "g@example.com", "email_verified": True}
    )
    _assert_no_secrets(
        client.post("/api/auth/google", json={"id_token": "good"}).get_json()["user"]
    )

    headers = auth_headers(client, email="patch@example.com")
    _assert_no_secrets(
        client.patch(
            "/api/auth/me", json={"full_name": "Renamed"}, headers=headers
        ).get_json()
    )


def test_friends_do_not_leak_owner_identity(client):
    """A friend row carries no owner id or email — only what the UI draws."""
    headers = auth_headers(client)
    client.post("/api/friends", json={"name": "Sam"}, headers=headers)

    friend = client.get("/api/friends", headers=headers).get_json()[0]

    assert set(friend) == {"id", "name", "color"}
