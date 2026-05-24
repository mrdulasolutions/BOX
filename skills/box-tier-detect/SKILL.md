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
2. **Probe Box MCP identity** via `who_am_i`. Capture the MCP server name from the tool's responding identifier. If it's not `box-remote-mcp` (Box's official remote at `mcp.box.com`), record `box_mcp_official: false` and surface a recommendation: *"You're connected via a community / deprecated Box MCP. The plugin works, but we recommend the official Box remote MCP — install via Claude/Cowork → Settings → Connectors → Box. Required for Box AI tools (`ai.readwrite` scope)."* Run `/box-mcp-check` for full details.
3. **Probe enterprise metadata scope** via the Box MCP. Success (returns a list, even empty) = Business+ tier. Error "user does not have an enterprise" = Personal.
4. **(Business+) Probe template-create permission.** Try to read `boxMemory` template. If missing, try creating a probe template. Success = admin; 403 = non-admin (mark `template_create: false`).
5. **Probe Box AI tool availability** via the MCP. Check if `box_ai_ask`, `box_ai_extract_structured`, and similar tools are exposed (the official remote MCP includes them; community MCPs may not). Record `box_ai_tools_available: <bool>`.
6. **Probe AI Units availability** by attempting a very small `box_ai_ask` call against a known file (if any exist) or check for an account-level AI Units allocation via `who_am_i` if it returns it. Record `ai_units_available: <bool, best-effort>`. If a 402/quota error returns, the account has Box AI gated behind a unit purchase. Document this in the capabilities object.
7. **Probe Hubs availability** (Enterprise Plus only). Try listing Hubs via the MCP. Success = Hubs feature available. Record `box_hubs: <bool>`.
8. **Read storage/upload limits** via user-info Box MCP call. Map `max_upload_size` → tier:
   - 250 MB → Personal
   - 2 GB → Business Starter
   - 5 GB → Business / Business Plus
   - 50 GB → Enterprise
   - 500 GB → Enterprise Plus
9. **Cross-check.** If steps 3 and 8 disagree, prefer the lower-capability tier. If signals strongly conflict (e.g. quota says Business+ but enterprise scope rejected), **suspect a stale OAuth token from a recent tier upgrade** — surface that as the most likely cause and recommend disconnect/reconnect of the Box MCP.
10. **Compliance certifications.** Not API-detectable. Preserve any user-declared values in `capabilities.compliance`. Otherwise leave empty with a note.
11. **Build capability object** and write to `_box-memory.json` under `capabilities` + `tier_detected_at`. The capability object grows to include:

```yaml
capabilities:
  custom_metadata_templates: <bool>     # Business+
  body_search: <bool>                   # Business+ (10KB cap per doc)
  max_file_size_mb: <int>
  retention_policies: <bool>            # Enterprise+
  legal_holds: <bool>                   # Enterprise+
  box_ai_tools_available: <bool>        # NEW — official MCP has these
  ai_units_available: <bool>            # NEW — best-effort
  box_hubs: <bool>                      # NEW — Enterprise Plus
  ai_studio_agents: <bool>              # NEW — Enterprise Advanced
  box_mcp_official: <bool>              # NEW — using mcp.box.com vs other
  compliance: [<user-declared>]
```

12. **Report.** Tier, key capability flags, and routing decisions:

```
Box account capabilities:
  Tier:                       <tier>
  Detected at:                <ISO>

Metadata templates:           <yes (admin) | yes (read-only) | no>
Body full-text search:        <yes | no>
Box AI tools available:       <yes | no>
AI Units available:           <yes | no | unknown>
Box Hubs:                     <yes | no>
AI Studio agents:             <yes | no>
Retention / legal holds:      <yes | no>
Compliance declared:          <list or "none">

Box MCP:                      <official mcp.box.com | community / deprecated>
                              (if not official: run /box-mcp-check for upgrade path)

Routing for this workspace:
  Memory write:               Box MCP (network) + _index.json
  Memory recall:              _index.json (instant) → Metadata Query (Business+) → AI Ask (Business+ AI-units) → AI Hub Q&A (Ent. Plus)
  Companion generation:       Box AI Extract Structured (Business+ AI-units) → local agent inspection (fallback)
```

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
