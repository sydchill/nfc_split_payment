"""Patela Flask application factory."""

from __future__ import annotations

import os

from flask import Flask, jsonify
from werkzeug.exceptions import HTTPException

# config.py calls load_dotenv() at import time, so .env is applied before any
# config value is read.
from .config import Config, TestConfig
from .extensions import cors, db, jwt, migrate
from .services import ServiceError


def create_app(config_object: type[Config] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_object or Config)

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    cors.init_app(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})

    _register_jwt_hooks()
    _register_blueprints(app)
    _register_error_handlers(app)
    _register_cli(app)

    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok", "service": "patela-api"})

    return app


def _register_blueprints(app: Flask) -> None:
    from .routes.api import bp as api_bp
    from .routes.auth import bp as auth_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(api_bp)


def _register_jwt_hooks() -> None:
    from .routes.blocklist import is_revoked

    @jwt.token_in_blocklist_loader
    def _check_revoked(_header, payload):  # noqa: ANN001
        return is_revoked(payload["jti"])

    @jwt.revoked_token_loader
    @jwt.expired_token_loader
    def _expired(_header, _payload):  # noqa: ANN001
        return jsonify({"error": "Session expired. Please sign in again."}), 401

    @jwt.unauthorized_loader
    @jwt.invalid_token_loader
    def _unauthorized(reason):  # noqa: ANN001
        return jsonify({"error": "Authentication required."}), 401


def _register_error_handlers(app: Flask) -> None:
    @app.errorhandler(ServiceError)
    def _service_error(err: ServiceError):
        return jsonify({"error": err.message}), err.status

    @app.errorhandler(HTTPException)
    def _http_error(err: HTTPException):
        return jsonify({"error": err.description}), err.code or 500

    @app.errorhandler(Exception)
    def _unexpected(err: Exception):
        app.logger.exception("Unhandled error: %s", err)
        db.session.rollback()
        return jsonify({"error": "Something went wrong."}), 500


def ensure_schemas() -> None:
    """Create the `auth` and `app` schemas if the backend supports schemas."""
    from sqlalchemy import text

    from .models import ALL_SCHEMAS

    if db.engine.dialect.name != "postgresql":
        return  # SQLite has no schemas; see attach_sqlite_schemas()
    for schema in ALL_SCHEMAS:
        db.session.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))
    db.session.commit()


def attach_sqlite_schemas() -> None:
    """Emulate the schemas on SQLite so tests can run without PostgreSQL.

    SQLite has no schemas, but an ATTACHed database is addressed with the same
    `schema.table` syntax, so attaching one in-memory database per schema makes
    the models work unchanged.
    """
    from sqlalchemy import text

    from .models import ALL_SCHEMAS

    if db.engine.dialect.name != "sqlite":
        return
    for schema in ALL_SCHEMAS:
        db.session.execute(text(f"ATTACH DATABASE ':memory:' AS {schema}"))
    db.session.commit()


def _register_cli(app: Flask) -> None:
    @app.cli.command("init-db")
    def init_db() -> None:
        """Create the schemas and all tables (use migrations in production)."""
        with app.app_context():
            ensure_schemas()
            db.create_all()
        print("Schemas (auth, app) and tables created.")


__all__ = [
    "create_app",
    "Config",
    "TestConfig",
    "db",
    "ensure_schemas",
    "attach_sqlite_schemas",
]
