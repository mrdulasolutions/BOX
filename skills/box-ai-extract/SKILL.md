---
name: box-ai-extract
description: Extract structured metadata from a binary file in Box using Box AI Extract Structured. Replaces "couldn't parse this format" stubs in companions with OCR + schema-driven extraction for PDFs / TIFF / PNG / JPEG. Returns extracted fields with confidence scores and source-text citations. Use during companion generation or when the user explicitly wants metadata extracted from a file.
argument-hint: "<file-id> [--template=<template-key>] [--fields=<field-spec>] [--apply-template]"
---

# /box-ai-extract

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Use Box AI Extract Structured to pull schema-driven metadata out of a binary file. OCR runs automatically for PDFs / TIFF / PNG / JPEG. Output is structured JSON matching a Box metadata template (the canonical `boxMemory` template or one of your own).

This is the bridge between binary files Box stores and structured memory the agent can reason about — without us doing the OCR ourselves.

## Usage

```
/box-ai-extract <file-id> [--template=<key>] [--fields=<spec>] [--apply-template]
```

Examples:
- `/box-ai-extract 2241144661879` — uses the default `boxMemory` template
- `/box-ai-extract 12345 --template=contractFields` — extract against a specific template
- `/box-ai-extract 12345 --fields=parties,effective_date,renewal_clause` — inline ad-hoc fields (no template)
- `/box-ai-extract 12345 --apply-template` — also write the extracted values as a metadata instance on the file

## What to do

### Step 1 — Verify prerequisites

1. Read `_box-memory.json`. Confirm tier is Business+ and `settings.ai_extract_enabled` is `true` (default `false` — same opt-in pattern as `box-ai-recall`).
2. Confirm the file ID exists and the agent has read access via Box MCP.
3. Confirm the Box MCP exposes the AI Extract tool (`box_ai_extract_structured` on the official remote MCP at `mcp.box.com`).

### Step 2 — Determine the extraction spec

Pick one path:

| Source of fields | When to use |
|---|---|
| `--template=<key>` (metadata template key) | When extracting against a defined template (recommended for consistency) |
| `--fields=<comma-separated names>` | One-off extraction without a template |
| Default `boxMemory` template | When called during companion generation — uses the workspace's canonical template |

If `--template=boxMemory` (the default in companion flow), the field set is the canonical schema from [references/schema.md](../../references/schema.md):

```
memory_id, slug, title, kind (enum), status (enum), team, agent,
tags, companion_for_file_id, sha256, created_at, updated_at
```

For binaries (companions), Extract Structured fills in fields that can be inferred from content: `title` (from doc title / filename), `tags` (themes detected in the text), plus any custom `summary` or `key_facts` fields if you've extended the template.

### Step 3 — Build the AI Extract request

```json
{
  "items": [{"type": "file", "id": "<file_id>"}],
  "metadata_template": {
    "scope": "enterprise_<id>",
    "template_key": "<template_key>"
  },
  "include_reference": true,
  "ai_agent": { "type": "ai_agent_extract_structured", "long_text": { "include_long_text": true } }
}
```

For ad-hoc fields (`--fields=`):

```json
{
  "items": [{"type": "file", "id": "<file_id>"}],
  "fields": [
    {"key": "parties", "description": "Names of all parties to the agreement"},
    {"key": "effective_date", "description": "Effective date in ISO-8601"},
    {"key": "renewal_clause", "description": "Renewal terms verbatim"}
  ],
  "include_reference": true
}
```

The `include_reference: true` flag (added in Box's 2026-03-18 update) returns the source-text excerpt each field was extracted from — used for citation in companion frontmatter.

### Step 4 — Call /2.0/ai/extract_structured

Via the Box MCP's `box_ai_extract_structured` tool. Surface 402 / quota errors immediately.

### Step 5 — Map the response

Response shape:

```json
{
  "answer": {
    "memory_id": "...",
    "title": "...",
    "tags": [...],
    ...
  },
  "references": [
    { "field": "title", "text": "<excerpt>", "page": 1 },
    ...
  ],
  "ai_agent_info": { "models": [...] }
}
```

For each field, surface (a) the extracted value, (b) the source-text reference, (c) confidence if returned.

### Step 6 — Optional: apply template instance

If `--apply-template` was passed:

1. Call Box's `POST /files/{file_id}/metadata/<scope>/<template_key>` to attach the extracted values as a metadata instance on the file.
2. This makes the values queryable via `mdfilters` and visible in Box's web UI metadata sidebar.

### Step 7 — Return

```
Extracted from file <file_id>:
  Template: <template_key or "ad-hoc fields">

  <field_name>: <value>     [page <N>: "<excerpt>"]
  <field_name>: <value>     [page <N>: "<excerpt>"]
  ...

Model: <model_id>
Source references: <yes/no>
Template instance applied: <yes/no>

If this was called from box-companion, the companion frontmatter is being populated with these values automatically.
```

## Integration with box-companion

When `box-companion` runs and the binary is one of the formats Box AI can OCR (PDF, TIFF, PNG, JPEG):

1. `box-companion` invokes `box-ai-extract` with `--template=boxMemory`
2. The extracted fields populate `companion_for.title`, `companion_for.tags`, plus any custom summary fields
3. The companion frontmatter includes `extracted_via: box-ai-extract-structured` and `extracted_at: <ISO>` for auditability
4. If `box-companion` is called with `--no-ai`, this skill is skipped and the agent falls back to the old "couldn't parse this format" stubs

## File format support

Box AI Extract Structured supports:

- **PDF** — full text + OCR
- **TIFF / PNG / JPEG** — OCR
- **DOCX / XLSX / PPTX** — text extraction
- **TXT / MD / code** — text extraction

Not supported:
- CAD formats (DWG, DXF, RVT) — Box AI doesn't parse these. Companion remains a sparse "agent couldn't read this format" note.
- Audio / video — same.
- Encrypted / password-protected PDFs — same.

## When to invoke

- Inside `box-companion` for any supported binary format (automatic on Business+ when `settings.ai_extract_enabled: true`)
- Standalone when the user asks "extract the parties / dates / amounts from this contract"
- When updating a stale companion (the binary changed; re-extract is cheaper than re-prompting the user)

## When NOT to invoke

- Format isn't supported (CAD, audio, video) — go to the sparse-companion path
- `settings.ai_extract_enabled: false` — opt-in costs control
- File is already richly described in its frontmatter (already-existing memory written by hand)
- Tier doesn't support AI — fall back to non-AI companion

## Cost awareness

Same model as `box-ai-recall` — each call consumes AI Units. Per-call rate not publicly published. Bound costs by:

- Opt-in via `settings.ai_extract_enabled`
- Skip if a fresh companion already exists (hash unchanged)
- Use `--check` first if you only want to validate freshness
- Watch for 402 / quota errors

See [references/box-ai-units.md](../../references/box-ai-units.md).

## Errors to surface clearly

- **Format unsupported** → "Box AI Extract doesn't support `<ext>`. Falling back to sparse companion."
- **OCR failed** (e.g., scanned PDF with no readable text) → "Box AI couldn't extract text from this file. Companion will note that the agent couldn't parse it."
- **402 / quota** → "AI Unit quota reached. Use `--no-ai` flag or wait for quota refresh."
- **Wrong template key** → "Template `<key>` not found in your Box account. Run `/box-init` to create the canonical `boxMemory` template, or specify a different template."

## Don't

- Don't extract from non-supported formats. Surface clearly.
- Don't apply the template instance unless `--apply-template` is explicit — irreversible without admin access on some plans.
- Don't fabricate fields not in the response. If Box AI didn't extract a value, leave it empty.
- Don't double-extract — if a fresh companion already exists for this file's current SHA256, skip.

## References

- [Box AI Extract Structured endpoint](https://developer.box.com/reference/post-ai-extract-structured/) — human-readable docs
- [Extract metadata tutorial](https://developer.box.com/guides/box-ai/ai-tutorials/extract-metadata-structured) — usage examples
- references/schema.md — the `boxMemory` canonical template
- references/box-ai-units.md — cost guidance
