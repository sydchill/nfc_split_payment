"""Revoked-token registry for logout.

An in-process set is fine for a single instance; swap for Redis (or a small
`revoked_tokens` table) when the API runs behind more than one worker.
"""

_revoked: set[str] = set()


def revoke(jti: str) -> None:
    _revoked.add(jti)


def is_revoked(jti: str) -> bool:
    return jti in _revoked
