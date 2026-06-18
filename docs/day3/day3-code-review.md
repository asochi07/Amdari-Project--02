# SentinelPay — Day 3: Manual Code Review

**Engineer:** Charles (asochi07) · **Date:** 16 June 2026 · **Deliverable:** D-02 (source)

## 1. Purpose & method

Day 2 established findings by breadth (scanners + threat model). Day 3 establishes them by
depth: a line-by-line read of the authentication, authorisation, and money-movement paths.
The review has two objectives — (1) validate each scanner / Day-2 finding as a true positive
by pointing at the exact lines that make it real, and (2) identify the authorisation and
business-logic flaws that no scanner can detect.

Scope note: Day 3 is review, not repair. No code was changed. Each finding records a
remediation direction to make the Day 4+ fixes fast to justify, but nothing was fixed today.

Findings are numbered CR-01..CR-23 plus one cross-file exploit chain (CHAIN-01). "Verified
safe" notes are included where code was read and found acceptable — a review that only lists
faults is indistinguishable from a scanner.

## 2. Files reviewed

| File | Theme | Key findings |
|------|-------|--------------|
| `payments-api/app/routes/auth.py` | Authentication | CR-01..CR-07 |
| `payments-api/app/routes/accounts.py` | Authorisation | CR-08..CR-11 |
| `payments-api/app/routes/wallets.py` | Money movement | CR-12..CR-17 |
| `kyc-api/app/routes/verify.py` | Auth + SSRF + SQLi (KYC) | CR-18..CR-21 |
| `payments-api/app/routes/admin.py` | Privileged paths + RCE | CR-22..CR-23 |

## 3. Authentication — `routes/auth.py`

| CR | Finding | Type | Severity |
|----|---------|------|----------|
| CR-01 | `register` accepts a client-supplied `role`, so anyone can self-register as admin | Confirms V-APP-07; exploit path proven | Critical |
| CR-02 | Duplicate-email INSERT throws unhandled, leaking account existence (user enumeration) | New logic flaw | Medium |
| CR-03 | No input validation on register (email format, password strength, length) | New logic flaw | Low |
| CR-04 | `login` has no rate limiting or lockout — trivial brute force | Confirms V-APP-08 | High |
| CR-05 | Non-existent email short-circuits the hash check, creating a timing oracle for enumeration | New logic flaw | Low |
| CR-06 | OTP printed to logs in plaintext (`print(... otp ...)`) | Confirms hint | Medium |
| CR-07 | OTP is never stored or sent; the step-up control is non-functional theatre | New logic flaw | High |
| -- | `login` checks credentials before `is_active`, avoiding a status-leak | Verified safe | -- |

Key point: CR-07 is the standout — a security control that does not actually exist. The
function generates an OTP, logs it, discards it, and returns `{"status":"sent"}` with no way
to later verify it. Only a manual read reveals a control that is present in name only.

## 4. Authorisation — `routes/accounts.py`

| CR | Finding | Type | Severity |
|----|---------|------|----------|
| CR-08 | IDOR in `get_account`: `WHERE id = %s` with no ownership check — any user reads any account | Confirms V-APP-03 (the originating incident) | Critical |
| CR-09 | Mass assignment in `update_profile`: `balance`, `user_id`, `status` are client-writable | Confirms V-APP-07 | Critical |
| CR-10 | SQL injection via column names in `update_profile` — values are parameterised, keys are not | New (code comment downplays it) | High |
| CR-11 | IDOR in `update_profile`: no ownership check, so any account can be modified | New (compounds CR-09) | Critical |
| -- | `list_accounts` correctly scopes to `request.current_user_id` | Verified safe (the contrast) | -- |

Key point: `list_accounts` (correct) sits directly beside `get_account` (vulnerable). The
secure ownership pattern already exists in the same file, so the IDOR is an inconsistency, not
a knowledge gap — and the fix is the known `WHERE user_id = %s` scoping. CR-10 is a reminder
that reassuring code comments ("SQLi is not the bug here") must be verified, not trusted.

## 5. Money movement — `routes/wallets.py`

| CR | Finding | Type | Severity |
|----|---------|------|----------|
| CR-12 | Race condition (TOCTOU) in `debit_wallet`: unlocked read-modify-write; concurrent debits double-spend | Confirms V-APP-05 | Critical |
| CR-13 | No security audit log on money movement (no who/where/idempotency key) | Confirms V-APP-11 | High |
| CR-14 | IDOR on credit and debit: any authenticated user can move money on any account by ID | New -- unflagged | Critical |
| CR-15 | `credit_wallet` has no authorisation and is also racy; unrestricted balance inflation | New -- unflagged | High |
| CR-16 | No upper-bound or account-status checks before moving money | New logic flaw | Low |
| CR-17 | No idempotency key; a retried debit double-charges | New (partially hinted) | Medium |
| -- | Both endpoints correctly reject `amount <= 0` | Verified safe | -- |

Key point: the most-commented bug (the race condition) is **not** the most dangerous one in
this file. The un-commented IDOR (CR-14) is more directly catastrophic — no concurrency
needed, just another account's ID, which CR-08 readily supplies. Chaining CR-08 -> CR-14
yields full fund drainage across accounts.

Remediation direction (for Day 4): replace the read-modify-write with a single atomic
statement, e.g. `UPDATE accounts SET balance = balance - %s WHERE id = %s AND balance >= %s`,
and add an ownership check binding `account_id` to the authenticated user.

## 6. KYC service — `routes/verify.py`

| CR | Finding | Type | Severity |
|----|---------|------|----------|
| CR-18 | SSRF via client-controlled `provider` URL; response body returned to caller (cloud-credential theft once on AWS) | Confirms V-APP-04 variant | Critical |
| CR-19 | BVN + provider combination usable as a PII-validation channel | New logic flaw | Low/Medium |
| CR-20 | SQL injection over `kyc_records` (regulated PII) with `SELECT *` — full KYC dump | Confirms V-APP-01 variant | Critical |
| CR-21 | No ownership/role check on KYC lookup — any user reads any identity record | New -- unflagged | High |
| -- | Both endpoints enforce `@require_auth` | Verified safe | -- |

Key point: same flaw classes as payments-api, higher impact. The SSRF *returns* its loot
(up to 2000 chars), and the SQLi sits over the identity table, turning a technical flaw into a
mass-PII-breach vector. The `provider` override is disguised as a feature, so the fix is an
allowlist of approved providers, not removal of the field.

## 7. Privileged paths — `routes/admin.py`

| CR | Finding | Type | Severity |
|----|---------|------|----------|
| CR-22 | Pickle deserialisation RCE in `restore_session`; assumed network isolation never built | Confirms V-APP-10 + architectural note | Critical |
| CR-23 | `list_users` admin role check reads an unverified, forgeable JWT claim | Confirms V-APP-03 variant | Critical |
| -- | `list_users` *does* implement a role check (correct intent) | Verified -- but undermined upstream | -- |

Key point: CR-23 is the subtle one. Unlike CR-08 (no check at all), `list_users` has a
*correct* admin check — but it trusts `current_user_role`, which derives from a token decoded
with `verify_signature=False`. A correctly-written control built on an untrustworthy input is
no control at all. The file's own opening docstring confirms the compensating control (network
isolation) was never implemented.

## 8. CHAIN-01 — anonymous to remote code execution

The headline synthesis. Three individually-rated flaws compose into the worst case:

1. **Broken JWT (V-APP-02)** — attacker mints an unsigned token with `role:admin`; no credentials needed.
2. **Forgeable role check (CR-23)** — the forged token passes the admin gate and reaches `/admin/*`.
3. **Pickle RCE (CR-22)** — attacker POSTs a malicious pickle to `/admin/session/restore` and executes code on the host.

Result: an anonymous internet user achieves remote code execution on the payments platform,
with no valid account, and no network boundary to stop them reaching the endpoint. No scanner
produces this finding; it requires reading across files and holding the whole system in view.

## 9. Outcome & carry-forward

23 located findings plus one cross-file chain. Every Day-2 scanner / threat-model finding was
validated in code; roughly a dozen new logic flaws were added (notably CR-07, CR-10, CR-14,
CR-21, CHAIN-01). Several "verified safe" notes evidence genuine reading rather than skimming.

Day 4 begins remediation in severity order. The five Critical classes — broken JWT, SQL
injection (x2 services), insecure deserialisation, SSRF, and the money-movement IDOR/race pair
— are the priority queue. Each fix will be a discrete commit referencing its V-APP identifier,
opened as a pull request, closing its tracker issue so the remediation report (D-02) assembles
from the issue-to-PR links.