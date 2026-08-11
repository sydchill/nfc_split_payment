"""Configuration loaded from environment variables."""

import os
from datetime import timedelta

from dotenv import load_dotenv

# Load .env *before* the config classes read os.environ — their values are
# resolved at class-definition time, so loading later would be ignored when the
# app is started directly (python run.py) rather than through the flask CLI.
load_dotenv()


# Placeholder values used when .env is missing. They are deliberately obvious:
# `create_app` refuses to start with them outside development, because a JWT
# signing key that is published in this file lets anyone forge a session.
DEV_SECRET = "dev-secret-change-me"
DEV_DATABASE_URL = "postgresql+psycopg://patela:patela@localhost:5432/patela"


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", DEV_SECRET)

    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", DEV_DATABASE_URL)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", SECRET_KEY)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(
        minutes=int(os.environ.get("JWT_ACCESS_MINUTES", "60"))
    )
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    CORS_ORIGINS = [
        o.strip() for o in os.environ.get("CORS_ORIGINS", "*").split(",") if o.strip()
    ]

    # Google Sign-In: the OAuth client id(s) an ID token may be issued for.
    # Use the **Web** client id (that's the audience when the mobile app signs in
    # with `serverClientId`). Comma-separate to accept more than one.
    GOOGLE_CLIENT_IDS = [
        c.strip()
        for c in os.environ.get("GOOGLE_CLIENT_ID", "").split(",")
        if c.strip()
    ]

    JSON_SORT_KEYS = False


class TestConfig(Config):
    TESTING = True
    # Tests run against a throwaway Postgres database when available; the
    # portable column types also allow SQLite for quick local runs.
    SQLALCHEMY_DATABASE_URI = os.environ.get("TEST_DATABASE_URL", "sqlite://")
    # 32+ bytes so HS256 signing doesn't warn about a short key.
    JWT_SECRET_KEY = "test-secret-key-for-patela-suite-0123456789"
