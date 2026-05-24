---
name: box-recall
description: Find memories in a box-memory workspace by ID, wikilink, slug, structured filters, or free-text. Bypasses Box's 10-minute search indexing lag by reading the per-folder index files. Use when the user asks "what do I know about X", "what did we decide", "find memories tagged Y", "recall", or "search my Box memory".
argument-hint: "<query> [--kind=<kind>] [--tag=<tag>] [--team=<team>] [--limit=<n>]"
---

# /box-recall

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Look up memories. Multi-strategy: direct ID fetch (instant) > index file lookup (instant on all tiers) > metadata query (Business+, instant) > Box search (last resort, may be 10+ min stale).

## Usage

```
/box-recall <query> [--kind=<k>] [--tag=<t>] [--team=<n>] [--limit=<n>]
```

Examples:
- `/box-recall auth strategy` — free-text
- `/box-recall [[Login Flow]]` — wikilink lookup
- `/box-recall --kind=decision --tag=security` — structured filter
- `/box-recall --id=mem_01HXYZ...` — exact fetch

## What to do

1. **Read workspace config** (`_box-memory.json`). If missing, surface "run `/box-init` first" — don't error.
2. **Parse the query.** Detect shape: memory ID (`mem_...`), Box file ID (numeric), wikilink (`[[Title]]`), slug (kebab-case word), structured filter (`kind:X tag:Y`), or free text.
3. **Direct ID fetch.** If query is a memory ID or file ID, look up via rollup `_index.json` → get file_id → fetch the file. Done.
4. **Index lookup.** Read the relevant folder's `_index.json`. Use `by_id`, `by_slug`, `by_wikilink`, `by_kind`, `by_tag`, `by_status` maps for instant filtering.
5. **(Business+ only) Metadata query.** If filters need metadata-template fields: call `search_files_keyword` with `query: "the"` (pseudo-wildcard) plus `mdfilters` for the actual filter. Do NOT call `search_files_metadata` — that MCP tool returns empty results. If template was created < 10 min ago, skip this path (warm-up window) and use index files instead.
6. **Free-text fallback.** Match query tokens against entry `title`, `slug`, `tags` (case-insensitive substring) across all accessible folder indexes. Score: exact title=10, exact slug=8, exact tag=6, partial=lower.
7. **Rank & return.** Sort by score then `updated_at`. Default limit 10. For single-result questions ("what did we decide about X"), return the best match's full content, not a list.

## Excluding superseded

By default, exclude `status: superseded` and `status: archived`. Include with `--include-superseded` or when user asks "history" / "what was the previous decision".

## Stale-index detection

If folder's `modified_at` from Box is newer than `_index.json.updated_at`, surface a warning: "The index for `<folder>` may be stale. Run `/box-index-rebuild` to refresh." Still return what the index has — only fresh writes are at risk.

## Errors to surface clearly

- **No workspace** → run `/box-init`.
- **Permission denied on a team folder** → skip silently, continue with accessible folders.

## Deep reference

For the multi-pass strategy detail, gt-epsilon caveat on float metadata, pseudo-wildcard mechanics, cross-team semantics, and ranking formula:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-recall-detail.md
- Schema (especially `by_*` inverted maps): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Operational notes (metadata tool bug, warm-up, gt-epsilon): https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
- Tier matrix (what's available on Personal vs Business+): https://github.com/mrdulasolutions/BOX/blob/main/references/tier-matrix.md
