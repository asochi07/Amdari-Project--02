"""Account lookup and listing endpoints."""
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

accounts_bp = Blueprint("accounts", __name__)


@accounts_bp.route("/<int:account_id>", methods=["GET"])
@require_auth
def get_account(account_id):
    """Look up an account by ID.

    V-APP-03 (the originating incident): No ownership check. Any authenticated
    user can read any account by guessing or enumerating IDs. This is the
    finding the researcher publicly disclosed on 14 April 2026.
    """
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT id, user_id, account_number, currency, balance, status, created_at "
            "FROM accounts WHERE id = %s AND user_id = %s",
            (account_id, request.current_user_id)
        )
        account = cur.fetchone()
        if not account:
            return jsonify({"error": "account not found"}), 404
        return jsonify(dict(account))
    finally:
        cur.close()
        conn.close()


@accounts_bp.route("/", methods=["GET"])
@require_auth
def list_accounts():
    """List accounts belonging to the current user."""
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT id, account_number, currency, balance, status FROM accounts WHERE user_id = %s",
            (request.current_user_id,)
        )
        rows = cur.fetchall()
        return jsonify([dict(r) for r in rows])
    finally:
        cur.close()
        conn.close()


@accounts_bp.route("/<int:account_id>/profile", methods=["PUT"])
@require_auth
def update_profile(account_id):
    """Update account profile fields.

    V-APP-07 remediation: only an explicit allowlist of non-sensitive columns
    may be updated. Sensitive columns (id, user_id, balance, status,
    account_number) are never client-writable, which closes both the mass-
    assignment flaw and the column-name SQL-injection Semgrep flagged, because
    column names now come from a fixed set rather than client input.
    """
    ALLOWED_UPDATE_FIELDS = {"currency"}

    data = request.get_json() or {}
    if not data:
        return jsonify({"error": "no fields supplied"}), 400

    invalid = set(data.keys()) - ALLOWED_UPDATE_FIELDS
    if invalid:
        return jsonify({"error": f"fields not permitted: {sorted(invalid)}"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        # Column names are drawn from the fixed allowlist above, never from
        # raw client input; values remain fully parameterised.
        set_clause = ", ".join([f"{col} = %s" for col in data.keys()])
        values = list(data.values()) + [account_id, request.current_user_id]

        cur.execute(
            f"UPDATE accounts SET {set_clause} WHERE id = %s AND user_id = %s RETURNING *",  # nosec B608 - column names come from a fixed allowlist (ALLOWED_UPDATE_FIELDS); values are parameterised
            values,
        )
        updated = cur.fetchone()
        if not updated:
            return jsonify({"error": "account not found"}), 404
        conn.commit()
        return jsonify(dict(updated))
    finally:
        cur.close()
        conn.close()
