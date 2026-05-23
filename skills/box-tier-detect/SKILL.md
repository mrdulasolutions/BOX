---
name: box-tier-detect
description: Probe a Box account to detect its tier (Personal, Business, Enterprise, Enterprise Plus) and capability matrix (custom metadata templates, body search, max file size, retention/legal-hold availability). Invoke this internally before any other box-memory operation that depends on tier — most other skills call this skill and read its cached output from _box-memory.json. Also invoke directly when the user asks "what tier am I on", "what can Box do here", or after a Box plan change.
---

# box-tier-detect

You probe the Box account that the Box MCP is currently connected to and figure out what capabilities are available. You cache the result so other skills don't have to re-probe.

## When you fire

- Another box-memory skill needs to know the tier and there's no cached result, or the cache is older than 30 days.
- The user explicitly asks about their Box tier or capabilities.
- The user just changed their Box plan (force re-detection).
- A previously-available feature stops working (likely tier downgrade).

## Inputs you need

- A connected Box MCP. If Box MCP tools aren't available, surface a clear message: *"Box MCP is not connected. Install and authorize it via your platform's MCP configuration (e.g., Claude Code/Cowork → Settings → Connectors → Box, or your platform's equivalent), then re-run."* Stop.
- (Optional) The path or ID of the workspace root, if the user has already run `box-setup`. If you don't have it, you can still detect tier — the workspace is just where you'd cache the result.

## What you do

### Step 1 — Check for cached result

If a workspace root is known, read `_box-memory.json` from the root. If `tier_detected_at` is within the last 30 days and the user didn't ask for a re-probe, return the cached `tier` + `capabilities` and stop.

### Step 2 — Probe metadata template scope

Call the Box MCP tool that lists metadata templates with `scope: "enterprise"`.

- **Success (returns a list, even if empty):** the account has enterprise-scope metadata. This means **Business tier or higher**.
- **Error containing "user does not have an enterprise" or 403 forbidden on enterprise scope:** the account is **Personal / Free tier**. Skip Step 3.

### Step 3 — Probe template creation permission (Business+ only)

Try to read an existing template named `boxMemory` in the enterprise scope.

- **Exists:** the plugin was set up here before. Read its fields to confirm schema compatibility.
- **Does not exist:** check whether the user has permission to create templates by calling the Box MCP tool to create a *probe* template named `boxMemoryProbe` (with a single field). 
  - **Success:** the user has admin rights. Immediately delete the probe template. Note `template_create: true`.
  - **403 Forbidden:** Business+ account but non-admin user. Note `template_create: false` — the plugin will need an admin to create the `boxMemory` template once.

### Step 4 — Probe storage and file-size limits

Call the Box MCP tool that returns the current user's info / quota. Look for:
- `max_upload_size` — this is the per-file cap.
- `space_used` / `space_amount` — total quota and current usage.

Map the limits back to a tier:

| `max_upload_size` | Likely tier |
|---|---|
| 250 MB (262144000 bytes) | Personal / Free |
| 2 GB | Business Starter |
| 5 GB | Business / Business Plus |
| 50 GB | Enterprise |
| 500 GB | Enterprise Plus |

Cross-check with Step 2's result. Discrepancies are possible (custom plans); when in doubt, prefer the **lower** capability.

### Step 5 — Compliance certifications

There is **no Box API that returns the account's compliance status.** Compliance is sold/contracted, not API-discoverable.

If the user previously declared their compliance posture in `_box-memory.json` under `capabilities.compliance`, preserve that. Otherwise leave the array empty and surface a note: *"Compliance certifications (HIPAA, SOC, FedRAMP) aren't API-detectable. If your Box plan includes them, declare them in `_box-memory.json` under `capabilities.compliance` so the plugin can flag features that depend on them."*

### Step 6 — Build the capability object

```json
{
  "tier": "personal" | "business" | "enterprise" | "enterprise_plus" | "unknown",
  "tier_detected_at": "<ISO-8601 now>",
  "capabilities": {
    "custom_metadata_templates": <bool from Step 2/3>,
    "template_create_permission": <bool from Step 3>,
    "body_search": <bool — true if Business+>,
    "max_file_size_mb": <integer from Step 4>,
    "storage_unlimited": <bool — true if no quota cap returned>,
    "storage_used_gb": <number>,
    "storage_total_gb": <number or null>,
    "box_sign": <bool — true if Business+>,
    "retention_policies": <bool — true if Enterprise+>,
    "legal_holds": <bool — true if Enterprise+>,
    "keysafe": <bool — declared by user, not detectable>,
    "compliance": [<from user declaration, e.g. "soc2", "hipaa", "fedramp-moderate">]
  }
}
```

Tier inference:

- `custom_metadata_templates: false` + `max_file_size_mb <= 250` → `personal`
- `custom_metadata_templates: true` + `max_file_size_mb <= 5120` + no retention → `business`
- `custom_metadata_templates: true` + `max_file_size_mb <= 51200` + retention available → `enterprise`
- `custom_metadata_templates: true` + `max_file_size_mb >= 500000` → `enterprise_plus`
- If signals conflict → `unknown` and surface to user

### Step 7 — Cache the result

If `_box-memory.json` exists (workspace is set up), merge the capability object into it. Otherwise, return it for whoever called you to cache.

### Step 8 — Report

Return a brief summary to the user (or calling skill). Format:

```
Box tier: <tier>
Custom metadata templates: <yes/no>
Body search: <yes/no>
Max file size: <N> MB
Retention policies: <yes/no>
Legal holds: <yes/no>
Compliance (declared): <list or "none declared">

Routing:
- Memory recall by structured fields → <Metadata Query API | _index.json>
- Body full-text search → <Box search | not available>
- Companion hash anchoring → <hash via metadata template | hash in frontmatter only>
```

## When detection is ambiguous

If you can't confidently determine the tier (e.g. signals conflict, or the user's Box plan is a custom contract), set `tier: "unknown"` and use **the lowest plausible capability set**. Tell the user what was ambiguous and how they can clarify (typically by declaring their tier explicitly in `_box-memory.json`).

## Errors to surface clearly

- **Box MCP not connected** → "Connect Box MCP via your platform's MCP configuration, then retry."
- **Token expired** → "Your Box session expired. Re-authorize Box MCP in your platform's MCP configuration."
- **Rate limited** → "Box rate-limited the tier-detection probes. Wait 60s and retry."
- **Conflicting signals** → "Couldn't confidently detect tier. Declare it in `_box-memory.json` (see `references/schema.md`)."
- **Stale OAuth token after tier upgrade** → Symptom: `list_metadata_templates(scope="enterprise")` returns "user does not have an enterprise" AND `max_upload_size` from quota suggests Business+ AND/OR template-create probe returns 403. Surface: *"Your Box account looks like Business+ (per file-size quota: <N> MB) but template-related operations are denied. If you recently upgraded your Box plan, your OAuth token is still scoped to the old plan — Box doesn't widen scope automatically. Disconnect and reconnect the Box MCP in your platform's settings to get a fresh token with current scope, then re-run."* See [references/operational-notes.md Note 2](references/operational-notes.md).

## Detection rules for stale OAuth scope

When probing the account, if you see signals that *contradict* (e.g. the quota suggests Business+ but enterprise-scope template listing fails), prefer the diagnosis "stale OAuth token" over "ambiguous tier" — it's much more common and the fix is concrete (reconnect MCP). Only conclude "ambiguous tier" when you've ruled out a stale token by asking the user when they last reconnected the Box MCP and whether the account changed plans recently.

## Don't

- Don't guess the tier from the user's email address or company.
- Don't claim compliance certifications without user declaration — the API doesn't expose them.
- Don't re-probe on every skill invocation. Cache for 30 days minimum unless explicitly re-requested.
- Don't fail other skills because tier detection failed. Other skills should gracefully use the lowest-common-denominator path (index files, no metadata templates).

## References

- `references/tier-matrix.md` — what each tier gives you
- `references/schema.md` — the `capabilities` schema in `_box-memory.json`
