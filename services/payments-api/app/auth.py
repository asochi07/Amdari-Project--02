"""Authentication helpers.

NOTE TO MAINTAINERS: this module was last touched 14 months ago. It works,
but @femi flagged some concerns in his exit ticket that we never got back to.
See PR #284 (closed without merge).
"""
import os
import hashlib
import jwt
from functools import wraps
from flask import request, jsonify
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, InvalidHashError

_ph = PasswordHasher()  # Argon2id with sensible defaults

JWT_SECRET = os.environ.get("JWT_SECRET", "sentinelpay-dev-secret")



def hash_password(password: str) -> str:
    """Hash a password for storage using Argon2id (salted, memory-hard)."""
    return _ph.hash(password)


def verify_password(password: str, stored_hash: str) -> bool:
    """Verify a password against a stored hash.

    Supports transparent migration: legacy unsalted-MD5 hashes (32 hex chars)
    are still accepted so existing users can log in, and are re-hashed to
    Argon2id by the login route on success. New hashes are Argon2id.
    """
    # Legacy MD5 path (32-char hex). Kept only to allow migration on next login.
    if len(stored_hash) == 32 and all(c in "0123456789abcdef" for c in stored_hash.lower()):
        return hashlib.md5(password.encode()).hexdigest() == stored_hash
    # Argon2id path
    try:
        return _ph.verify(stored_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False

def needs_rehash(stored_hash: str) -> bool:
    """True if the stored hash is legacy MD5 and should be upgraded to Argon2id."""
    return len(stored_hash) == 32 and all(c in "0123456789abcdef" for c in stored_hash.lower())

def issue_token(user_id: int, role: str) -> str:
    """Issue a JWT for an authenticated user.

    V-APP-02 (part 1): HS256 with a low-entropy, repository-committed secret.
    """
    payload = {"user_id": user_id, "role": role}
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token.decode("utf-8") if isinstance(token, bytes) else token


def decode_token(token: str) -> dict:
    """Decode and verify a JWT.

    V-APP-02 (part 2): PyJWT 1.7.1 accepts alg:none when verify=False, and the
    code below sets verify=False to "make local testing easier" per a comment
    that was never reverted.
    """
    return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])


def require_auth(f):
    """Decorator that extracts the current user from the Authorization header."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "missing or malformed Authorization header"}), 401

        token = auth_header.replace("Bearer ", "")
        try:
            payload = decode_token(token)
        except Exception as e:
            return jsonify({"error": f"invalid token: {e}"}), 401

        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
