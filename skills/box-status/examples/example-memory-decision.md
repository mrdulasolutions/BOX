---
id: mem_01HXYZA1B2C3D4E5F6G7H8J9K0
slug: jwt-vs-sessions-decision
title: JWT vs Sessions Decision
kind: decision
status: active
team: default
agent: claude-code
created_at: 2026-05-22T18:32:00Z
updated_at: 2026-05-22T18:32:00Z
confidence: 0.9
tags: [auth, mobile, security]
related:
  - "[[Login Flow]]"
  - "[[Session Management Pattern]]"
links:
  - url: https://datatracker.ietf.org/doc/html/rfc7519
    label: RFC 7519 (JWT)
---

# JWT vs Sessions Decision

> We're going with JWT instead of server-side sessions because mobile clients can't reliably persist cookies and we don't want a stateful session store on the gateway.

## Context

The auth layer needs to support three clients: web (cookie-friendly), mobile (cookies fight the OS), and a public API (no cookies at all). Earlier prototypes used express-session with a Redis backing store. Worked fine for web; mobile got logged out every time the OS evicted the cookie jar, and we ended up writing a fragile token bridge.

## Decision

Use stateless JWTs signed with a rotating asymmetric key (ES256). Access tokens live 15 minutes; refresh tokens live 30 days and are rotated on every use. Token revocation list (TRL) stored in Redis — TTL-bounded so it doesn't grow forever.

## Why

- Mobile and API clients carry tokens explicitly, identically to web. One auth path.
- Stateless gateway means we can scale horizontally without a session store.
- Asymmetric signing means downstream services can verify without contacting auth.
- Short access token life + refresh rotation keeps the blast radius of a stolen token small without making every request hit the auth service.

## Tradeoffs we accepted

- Revocation isn't instant — a stolen access token is usable until expiry unless we blacklist it. Acceptable: 15-minute window.
- JWTs are bigger than session IDs. Acceptable: we're not bandwidth-constrained.
- Key rotation is more operational work than session secret rotation. Acceptable: we're rotating monthly via cron.

## Related

- [[Login Flow]] — the user-facing flow that consumes these tokens.
- [[Session Management Pattern]] — the older pattern this supersedes.

## Open questions

- [ ] Do we need to revoke on password change, or is the 15-min window acceptable?
- [ ] Audit log retention — JWT `jti` claim is what we'd log; how long do we keep them?

---

#decision #auth #mobile #security
