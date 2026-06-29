"""Outbound webhook signing (HMAC-SHA256), Stripe-style.

The signature covers "timestamp.body" so the timestamp can't be altered
independently of the payload, and the receiver can reject stale timestamps
to prevent replay.
"""
import hmac
import hashlib
import time


def sign_payload(secret: str, body: str):
    """Return (timestamp, signature) for a raw JSON body string.

    signature = HMAC-SHA256(secret, "timestamp.body") as hex.
    """
    timestamp = str(int(time.time()))
    signed = f"{timestamp}.{body}".encode()
    sig = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    return timestamp, sig


def verify_signature(secret: str, body: str, timestamp: str, signature: str,
                     max_age_seconds: int = 300) -> bool:
    """Verify a webhook signature (this is what a MERCHANT would run).

    Rejects if the signature doesn't match or the timestamp is too old.
    Uses constant-time comparison to avoid timing attacks.
    """
    # Reject stale timestamps (replay protection)
    try:
        if abs(int(time.time()) - int(timestamp)) > max_age_seconds:
            return False
    except (ValueError, TypeError):
        return False
    expected = hmac.new(secret.encode(), f"{timestamp}.{body}".encode(),
                        hashlib.sha256).hexdigest()
    # constant-time compare — prevents leaking the secret via response timing
    return hmac.compare_digest(expected, signature)
