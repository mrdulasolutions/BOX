---
description: Recall memories from Box — instant lookup via index (all tiers) or Metadata Query API (Business+), fallback to Box search as last resort
argument-hint: "<query> [--kind=<kind>] [--tag=<tag>] [--team=<team>] [--status=<status>] [--limit=<n>] [--include-superseded]"
---

# /box-recall

Find memories matching a query. Bypasses Box's 10-minute search indexing lag by reading the structured indexes the plugin maintains on every write.

## What this command does

Invoke the `box-memory-recall` skill with the user's arguments. The skill will:

1. Parse the query to determine shape (ID, wikilink, slug, structured filter, free text).
2. Route to the fastest available path: direct ID fetch → index lookup → Metadata Query API (Business+) → folder scan → Box search (last resort).
3. Rank matches by relevance and recency.
4. Return matches with content excerpts and traceability info.

## Argument handling

- **First positional argument** → the query. Can be a memory ID, wikilink (`[[Title]]`), slug, structured filter, or free text.
- **`--kind=<kind>`** → filter by kind: decision, fact, task, observation, reference, note, companion.
- **`--tag=<tag>`** → filter by tag. Repeat for AND semantics: `--tag=auth --tag=security`.
- **`--team=<name>`** → only search a specific team's folder. Default: all accessible teams + default.
- **`--status=<status>`** → filter by status. Default: `active`. Use `--include-superseded` to also see history.
- **`--limit=<n>`** → max results. Default 10.
- **`--include-superseded`** → include `superseded` and `archived` memories. The skill will note when surfacing them.
- **`--id=<mem_id>`** → shortcut for fetching by exact ID.

## Examples

- `/box-recall auth strategy` → free-text search.
- `/box-recall [[Login Flow]]` → wikilink lookup.
- `/box-recall --kind=decision --tag=auth` → all auth decisions.
- `/box-recall --id=mem_01HXYZ…` → exact fetch.
- `/box-recall what's pending --kind=task --status=draft` → all draft tasks.
- `/box-recall --team=engineering vendor X` → search engineering team only.

## Invocation

Pass parsed arguments to `box-memory-recall`. Surface the skill's results, ranked.

## When nothing matches

The skill will produce a helpful "no results" message including what folders/passes were searched and suggestions to broaden the query or rebuild the index. Don't fabricate matches.

## Errors

- **No workspace** → run `/box-init` first.
- **Box MCP not connected** → standard MCP message.
