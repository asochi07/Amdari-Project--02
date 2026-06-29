"""Shared auth helpers (verify-only). RS256: verifies with the public key,
selecting the key by the token's kid. No signing happens in this service."""
import os
import jwt
from functools import wraps
from flask import request, jsonify

JWT_ALG = os.environ.get("JWT_ALG", "RS256")


def _read_key(path):
    if not path:
        return None
    with open(path, "r") as f:
        return f.read()


# kyc-api gets ONLY the public key — it can verify, never sign. This is the
# structural fix for INV-11: the verifying service holds no signing material.
_PUBLIC_KEYS = {}
_pub = _read_key(os.environ.get("JWT_PUBLIC_KEY_PATH"))
if _pub:
    _PUBLIC_KEYS[os.environ.get("JWT_ACTIVE_KID", "k1")] = _pub


def decode_token(token: str) -> dict:
    """Verify a JWT using the RS256 public key matching the token's kid.
    Fails closed: unknown kid or bad signature raises."""
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")
    public_key = _PUBLIC_KEYS.get(kid)
    if not public_key:
        raise jwt.InvalidTokenError("unknown or missing key id")
    return jwt.decode(token, public_key, algorithms=["RS256"])


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "unauthorized"}), 401
        try:
            payload = decode_token(auth.replace("Bearer ", ""))
        except Exception:
            return jsonify({"error": "unauthorized"}), 401
        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
