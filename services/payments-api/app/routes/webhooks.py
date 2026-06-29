"""Webhook registration, signed dispatch, and callback testing."""
import os
import json
import secrets
import requests
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.signing import sign_payload

webhooks_bp = Blueprint("webhooks", __name__)

WEBHOOK_TIMEOUT = int(os.environ.get("WEBHOOK_TIMEOUT", "10"))


@webhooks_bp.route("/", methods=["POST"])
@require_auth
def register_webhook():
    """Register a callback URL. Generates a per-webhook signing secret and
    returns it ONCE so the merchant can verify future callbacks."""
    data = request.get_json() or {}
    callback_url = data.get("callback_url")
    event_type = data.get("event_type", "transaction.completed")

    if not callback_url:
        return jsonify({"error": "callback_url required"}), 400

    signing_secret = secrets.token_hex(32)  # 256-bit, cryptographically strong

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO webhooks (user_id, callback_url, event_type, signing_secret) "
            "VALUES (%s, %s, %s, %s) RETURNING id",
            (request.current_user_id, callback_url, event_type, signing_secret)
        )
        webhook_id = cur.fetchone()["id"]
        conn.commit()
        # Return the secret ONCE; the merchant stores it to verify signatures.
        return jsonify({
            "id": webhook_id,
            "callback_url": callback_url,
            "signing_secret": signing_secret,
            "note": "Store this secret now; it is shown only once."
        }), 201
    finally:
        cur.close()
        conn.close()


@webhooks_bp.route("/<int:webhook_id>/send", methods=["POST"])
@require_auth
def send_webhook(webhook_id):
    """Dispatch a signed event to a registered webhook's callback URL.

    The payload is signed with HMAC-SHA256 over 'timestamp.body' using the
    webhook's signing secret, sent in X-SentinelPay-Signature /
    X-SentinelPay-Timestamp headers so the merchant can verify authenticity.
    """
    data = request.get_json() or {}
    event = data.get("event", {"type": "transaction.completed", "test": True})

    conn = get_connection()
    cur = conn.cursor()
    try:
        # Owner-scoped lookup (consistent with the IDOR fixes elsewhere)
        cur.execute(
            "SELECT callback_url, signing_secret FROM webhooks "
            "WHERE id = %s AND user_id = %s",
            (webhook_id, request.current_user_id)
        )
        row = cur.fetchone()
        if not row:
            return jsonify({"error": "webhook not found"}), 404

        body = json.dumps(event, separators=(",", ":"), sort_keys=True)
        timestamp, signature = sign_payload(row["signing_secret"], body)
        headers = {
            "Content-Type": "application/json",
            "X-SentinelPay-Timestamp": timestamp,
            "X-SentinelPay-Signature": f"sha256={signature}",
        }
        try:
            resp = requests.post(row["callback_url"], data=body,
                                 headers=headers, timeout=WEBHOOK_TIMEOUT)
            delivered = resp.status_code
        except Exception as e:
            delivered = f"delivery_failed: {e}"

        # Return what was signed/sent so delivery can be verified/inspected.
        return jsonify({
            "webhook_id": webhook_id,
            "signed_body": body,
            "timestamp": timestamp,
            "signature": f"sha256={signature}",
            "delivery_result": delivered,
        })
    finally:
        cur.close()
        conn.close()


@webhooks_bp.route("/test", methods=["POST"])
@require_auth
def test_webhook():
    """Test-fire a webhook by fetching the supplied URL.

    V-APP-04 (still open): SSRF — the URL is fetched with no scheme/host/IP
    validation. Tracked separately; not addressed in this signing change.
    """
    data = request.get_json() or {}
    url = data.get("url")
    if not url:
        return jsonify({"error": "url required"}), 400
    try:
        resp = requests.get(url, timeout=WEBHOOK_TIMEOUT)
        return jsonify({
            "status_code": resp.status_code,
            "headers": dict(resp.headers),
            "body": resp.text[:5000]
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500
