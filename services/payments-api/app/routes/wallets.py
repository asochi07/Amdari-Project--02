"""Wallet credit and debit operations."""
import uuid
from decimal import Decimal
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.audit import audit_log

wallets_bp = Blueprint("wallets", __name__)


@wallets_bp.route("/<int:account_id>/credit", methods=["POST"])
@require_auth
def credit_wallet(account_id):
    """Credit funds to a wallet (e.g. inbound transfer settlement)."""
    data = request.get_json() or {}
    amount = Decimal(str(data.get("amount", "0")))
    description = data.get("description", "credit")

    if amount <= 0:
        return jsonify({"error": "amount must be positive"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT balance FROM accounts WHERE id = %s", (account_id,))
        row = cur.fetchone()
        if not row:
            return jsonify({"error": "account not found"}), 404

        new_balance = Decimal(str(row["balance"])) + amount
        cur.execute("UPDATE accounts SET balance = %s WHERE id = %s", (new_balance, account_id))

        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, description, status) "
            "VALUES (%s, %s, %s, 'credit', %s, 'completed')",
            (account_id, reference, amount, description)
        )
        conn.commit()

        audit_log("wallet.credit", actor_id=request.current_user_id,
                  result="success", account_id=account_id, amount=str(amount),
                  new_balance=str(new_balance), reference=reference,
                  source_ip=request.remote_addr)

        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()


@wallets_bp.route("/<int:account_id>/debit", methods=["POST"])
@require_auth
def debit_wallet(account_id):
    """Debit funds from a wallet.

    V-APP-05: fixed — atomic check-and-decrement (see UPDATE below).
    V-APP-11: fixed — structured audit logging on success and failure.
    """
    data = request.get_json() or {}
    amount = Decimal(str(data.get("amount", "0")))
    counterparty = data.get("counterparty", "")
    description = data.get("description", "debit")

    if amount <= 0:
        return jsonify({"error": "amount must be positive"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        # Atomic check-and-decrement: the balance >= amount guard runs inside the
        # UPDATE, so concurrent debits cannot both pass. Also scopes to the owner
        # (closes the IDOR on this endpoint).
        cur.execute(
            "UPDATE accounts SET balance = balance - %s "
            "WHERE id = %s AND user_id = %s AND balance >= %s "
            "RETURNING balance",
            (amount, account_id, request.current_user_id, amount)
        )
        result = cur.fetchone()
        if not result:
            # No row updated: account not owned/found, OR insufficient funds.
            audit_log("wallet.debit", actor_id=request.current_user_id,
                      result="failure", account_id=account_id, amount=str(amount),
                      source_ip=request.remote_addr,
                      reason="insufficient_funds_or_not_owned")
            return jsonify({"error": "insufficient funds or account not found"}), 400

        new_balance = Decimal(str(result["balance"]))

        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, counterparty, description, status) "
            "VALUES (%s, %s, %s, 'debit', %s, %s, 'completed')",
            (account_id, reference, amount, counterparty, description)
        )
        conn.commit()

        audit_log("wallet.debit", actor_id=request.current_user_id,
                  result="success", account_id=account_id, amount=str(amount),
                  new_balance=str(new_balance), reference=reference,
                  counterparty=counterparty, source_ip=request.remote_addr)

        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()
