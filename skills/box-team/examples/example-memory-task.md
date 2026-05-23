---
id: mem_01HXYZA1B2C3D4E5F6G7H8J9K2
slug: rotate-jwt-keys-monthly
title: Rotate JWT signing keys monthly
kind: task
status: active
team: default
agent: claude-code
created_at: 2026-05-22T18:34:00Z
updated_at: 2026-05-22T18:34:00Z
confidence: 0.95
tags: [auth, ops, security, recurring]
related:
  - "[[JWT vs Sessions Decision]]"
links: []
---

# Rotate JWT signing keys monthly

> Cron-driven monthly rotation of the ES256 keypair, with a 7-day overlap to allow in-flight tokens to verify against the old key.

## Context

We picked stateless JWTs in [[JWT vs Sessions Decision]]. The risk model assumes monthly key rotation. Without rotation, a leaked signing key would never expire.

## What to do

- [ ] Schedule cron at 03:00 UTC on the first of every month.
- [ ] Generate a fresh ES256 keypair via the auth service's `rotate-key` admin endpoint.
- [ ] Publish the new public key to JWKS endpoint immediately.
- [ ] Keep the old public key in JWKS for 7 days (long enough for any 30-day refresh token to be rotated to a new access token under the new key).
- [ ] After 7 days, remove the old public key from JWKS.
- [ ] Alert on rotation failure (PagerDuty).

## Where this is tracked

Cron runs from the `ops-platform` repo: `cron/jobs/rotate-jwt.yaml`.

## Related

- [[JWT vs Sessions Decision]] — why we need this.

---

#task #auth #ops #recurring
