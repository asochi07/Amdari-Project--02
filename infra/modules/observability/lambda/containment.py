"""
GuardDuty containment action (minimal stub).

Triggered by EventBridge on high-severity GuardDuty findings. In this
engagement it logs the finding and documents the containment step it WOULD
take; the full action (e.g. disabling the implicated IAM principal, isolating
the instance via a deny-all SG) is exercised in the Week 3 attack simulation.
"""
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    detail = event.get("detail", {})
    finding_type = detail.get("type", "unknown")
    severity = detail.get("severity", "unknown")
    resource = detail.get("resource", {})

    logger.info(
        "GuardDuty high-severity finding received: type=%s severity=%s",
        finding_type, severity,
    )
    logger.info("Affected resource: %s", json.dumps(resource))

    # Containment decision (documented; enacted in Week 3):
    #  - If an IAM principal is implicated -> attach a deny-all policy / deactivate keys
    #  - If an EC2/ECS resource is implicated -> move to a quarantine security group
    containment = {
        "action": "documented-stub",
        "would_contain": finding_type,
        "note": "Full containment enacted and tested in the Week 3 purple-team simulation.",
    }
    logger.info("Containment plan: %s", json.dumps(containment))

    return {"statusCode": 200, "body": json.dumps(containment)}
