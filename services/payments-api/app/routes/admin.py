"""Internal admin endpoints.

These were originally on a separate internal-only network. The 'separate
internal-only network' never materialised, and the endpoints now ship behind
the same ALB as everything else.
"""
import base64
import json
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

admin_bp = Blueprint("admin", __name__)


@admin_bp.route("/session/restore", methods=["POST"])
@require_auth
def restore_session():
    """Restore an admin session from a serialised blob.

    V-APP-10 (remediated): the session payload was formerly a base64-encoded
    pickle, which allowed arbitrary code execution. It is now parsed as JSON,
    which cannot execute code. The endpoint only reads back the session keys.

    """
    data = request.get_json() or {}
    blob = data.get("session")

    if not blob:
        return jsonify({"error": "session blob required"}), 400

    try:
        raw = base64.b64decode(blob)
        # V-APP-10 remediation: never unpickle untrusted input (RCE). JSON cannot
        # execute code. Reject anything that is not a JSON object.
        session = json.loads(raw)
        if not isinstance(session, dict):
            return jsonify({"error": "invalid session payload"}), 400
        return jsonify({"restored": True, "session_keys": list(session.keys())})
    except Exception as e:
        return jsonify({"error": str(e)}), 400


@admin_bp.route("/users", methods=["GET"])
@require_auth
def list_users():
    """List all users.

    V-APP-03 variant: role check uses the JWT-supplied role claim with no
    verification. Combined with V-APP-02 (alg:none accepted), any client can
    self-promote to admin by minting a token with role='admin'.
    """
    if request.current_user_role != "admin":
        return jsonify({"error": "admin only"}), 403

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id, email, full_name, role, is_active, created_at FROM users")
        return jsonify([dict(r) for r in cur.fetchall()])
    finally:
        cur.close()
        conn.close()
