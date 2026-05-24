---
name: box-tier-detect
description: Probe a Box account to detect its tier (Personal, Business, Enterprise, Enterprise Plus) and capability matrix - custom metadata templates, body search, max file size, retention, legal holds. Mostly invoked internally by other skills; can also be called directly when the user asks what tier their Box account is on or what features it supports.
argument-hint: "[--refresh]"
---

# /box-tier-detect

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Probe Box account capabilities and cache the result so other skills don't have to re-probe. Routes other skills to the right path (index files on Personal, metadata templates on Business+, retention on Enterprise+).

## Usage

```
/box-tier-detect [--refresh]
```

Examples:
- `/box-tier-detect` — return cached result if fresh, otherwise probe
- `/box-tier-detect --refresh` — force re-probe (use after a Box plan change)

## What to do

1. **Check cache.** If `_box-memory.json` has `tier_detected_at` within 30 days and user didn't ask for `--refresh`, return cached `tier` + `capabilities` and stop.
2. **Probe enterprise metadata scope** via the Box MCP. Success (returns a list, even empty) = Business+ tier. Error "user does not have an enterprise" = Personal.
3. **(Business+) Probe template-create permission.** Try to read `boxMemory` template. If missing, try creating a probe template. Success = admin; 403 = non-admin (mark `template_create: false`).
4. **Read storage/upload limits** via user-info Box MCP call. Map `max_upload_size` → tier:
   - 250 MB → Personal
   - 2 GB → Business Starter
   - 5 GB → Business / Business Plus
   - 50 GB → Enterprise
   - 500 GB → Enterprise Plus
5. **Cross-check.** If Step 2 and Step 4 disagree, prefer the lower-capability tier. If signals strongly conflict (e.g. quota says Business+ but enterprise scope rejected), **suspect a stale OAuth token from a recent tier upgrade** — surface that as the most likely cause and recommend disconnect/reconnect of the Box MCP.
6. **Compliance certifications.** Not API-detectable. Preserve any user-declared values in `capabilities.compliance`. Otherwise leave empty with a note.
7. **Build capability object** and write to `_box-memory.json` under `capabilities` + `tier_detected_at`.
8. **Report.** Tier, key capability flags, and routing decisions.

## Detection rules for stale OAuth scope

When signals contradict, prefer the diagnosis "stale OAuth token after tier upgrade" over "ambiguous tier" — it's the more common cause and the fix is concrete (disconnect/reconnect MCP). Only conclude "ambiguous" after ruling out the stale-token case with the user.

## Errors to surface clearly

- **Box MCP not connected** → "Connect Box MCP via your platform's MCP configuration, then retry."
- **Token expired** → "Your Box session expired. Re-authorize Box MCP."
- **Conflicting signals** → suspect stale token; recommend reconnect.

## Don't

- Don't claim compliance certs without user declaration.
- Don't re-probe on every skill invocation — 30-day cache.
- Don't fail other skills because tier detection was ambiguous; use the lowest-common-denominator path.

## Deep reference

For the full probe sequence, tier-inference rules, capability matrix mapping, and OAuth recovery flow:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-tier-detect-detail.md
- Tier matrix: https://github.com/mrdulasolutions/BOX/blob/main/references/tier-matrix.md
- Operational notes (OAuth scope after upgrade): https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
