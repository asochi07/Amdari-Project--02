"""Structured audit logging for security-sensitive actions.

Emits one JSON object per audited event to stdout. The container runtime
captures stdout; in Week 2 this stream is shipped to centralised logging
(CloudWatch / Loki). The app does not own log storage — it only emits.
"""
import json
import logging
import sys
from datetime import datetime, timezone

_audit = logging.getLogger("audit")
if not _audit.handlers:
    _handler = logging.StreamHandler(sys.stdout)
    _handler.setFormatter(logging.Formatter("%(message)s"))  # message is already JSON
    _audit.addHandler(_handler)
    _audit.setLevel(logging.INFO)
    _audit.propagate = False  # don't double-log via the root logger


def audit_log(action, actor_id, result, **fields):
    """Emit a structured audit entry.

    action  - dotted event name, e.g. 'wallet.debit'
    actor_id - authenticated user id performing the action
    result  - 'success' or 'failure'
    fields  - any extra context (account_id, amount, source_ip, reference, reason)
    """
    entry = {
        "event": "audit",
        "ts": datetime.now(timezone.utc).isoformat(),
        "action": action,
        "actor_id": actor_id,
        "result": result,
        **fields,
    }
    _audit.info(json.dumps(entry))
