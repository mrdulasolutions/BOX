---
name: box-memory-recall
description: Recall memories from a box-memory workspace. Multi-strategy lookup that bypasses Box's 10-minute search indexing lag: tries Box Metadata Query API first (Business+ tier), falls back to per-folder _index.json (every tier), then folder listing, then Box search (last resort with stale-data warning). Returns matching memories ranked by relevance with their IDs, file paths, and content excerpts. Invoke when the user asks "what do I know about…", "what did we decide…", "find memories tagged…", "recall…", "search my Box memory", "what's in the [team] folder", or runs /box-recall.
---

# box-memory-recall

You find and return memories from the user's box-memory workspace. Box's Search API has a ~10-minute indexing lag and gates body search to Business+ tier, so you don't rely on it. Instead you read structured indexes that the plugin maintains on every write.

## When you fire

- The user asks about past decisions, facts, observations, tasks, or anything that may have been saved.
- The user runs `/box-recall <query>`.
- Another skill needs context (e.g., `box-memory-write` checking for slug collisions, `box-file-companion` finding related memories).
- The user references a topic by wikilink-style phrasing ("the auth decision", "the Jane memo") — these are recallable.

## Inputs

- **Query** — what to find. Could be:
  - A memory ID (`mem_…`) → exact direct fetch.
  - A wikilink-style title (`[[…]]` or just the title text).
  - A slug.
  - A free-text query (becomes tag/title/body search).
  - A structured filter (`kind:decision`, `tag:auth`, `team:engineering`, `status:active`).
- **Workspace** — must exist.
- **Optional filters** — `kind`, `tag`, `team`, `status`, `since`, `until`, `agent`, `include_superseded`.

If the query is ambiguous, ask for clarification, but lean toward executing a recall and surfacing what you found — a recall with zero results is informative.

## What you do

### Step 0 — Verify workspace

Read `_box-memory.json`. If missing, surface "No box-memory workspace found. Run `/box-init` first" and stop.

Cache the workspace's `tier`, `capabilities`, `metadata_template_key`, and `folder_ids`. You'll use them to pick a route.

### Step 1 — Parse the query

Detect query shape:

| Shape | Examples | Route |
|---|---|---|
| Memory ID | `mem_01HXYZ…` | Direct fetch (step 2) |
| Box file ID (numeric, ≥10 digits) | `2241144661879` | Direct fetch (step 2) |
| Wikilink | `[[JWT vs Sessions Decision]]` | `by_wikilink` (step 3) |
| Slug | `jwt-vs-sessions-decision` | `by_slug` (step 3) |
| Structured filter | `kind:decision tag:auth` | Filter scan (step 4) |
| Free-text | `what did we decide about auth` | Multi-route (step 5) |

### Step 2 — Direct ID fetch (instant, no lag)

If the query is a memory ID or file ID:

- For memory ID (`mem_…`): look it up in the workspace-root rollup `_index.json` → `by_id[<id>]` to get the file_id.
- For file ID: fetch directly from Box.

Read the file, parse frontmatter, return the memory. Done.

If `by_id` lookup misses (rollup stale), fall through to scanning each folder's `_index.json` for the memory ID.

### Step 3 — Wikilink / slug lookup via index

If the query is a wikilink target or slug:

1. Read the workspace-root rollup `_index.json` first → `by_wikilink[<title>]` or `by_slug[<slug>]`.
2. If found, look up `by_id` → entry → `file_id` → fetch the file.
3. If not found in rollup, read each per-folder `_index.json` and check there. The rollup may be stale; per-folder is authoritative.
4. If still not found, the wikilink is dangling. Surface: "No memory found for `<title>`. It may not have been written yet."

### Step 4 — Structured filter (kind, tag, team, status, etc.)

Build the filter set from the query.

**Business+ path — metadata-filtered keyword search:**

If `capabilities.custom_metadata_templates` is true and `metadata_template_key` is set:

Call `search_files_keyword` with the `mdfilters` parameter. **Do not call the dedicated `search_files_metadata` tool** — it returns empty results in current Box MCP implementations (see [references/operational-notes.md Note 1](references/operational-notes.md)).

The query parameter must be non-empty. Pass `"the"` as a pseudo-wildcard since virtually every memory body contains it. The `mdfilters` parameter does the actual filtering on `<metadata_template_key>` (`boxMemory` canonically, or whatever the workspace declares).

Example shape:

```text
search_files_keyword(
  query: "the",
  mdfilters: [
    { templateKey: "boxMemory",
      filters: { kind: "decision", status: "active" } }
  ]
)
```

This is fast — no Search API indexing lag for already-indexed metadata, no body-size limit, reflects writes immediately *once the template is warm* (see warm-up note below).

**Template warm-up window (first 10 minutes after template creation):** Fresh templates take ~10 minutes before bulk `mdfilters` queries return correct results. If `_box-memory.json` has `metadata_template_created_at` and `now - created_at < 10 min`, **skip this Business+ path and fall through to the index-scan path below**. Tell the user once: *"Skipping metadata query — template still in its ~10 min warm-up window. Using index files for this recall."* See [references/operational-notes.md Note 3](references/operational-notes.md).

**Strict-comparison caveat:** `gt` on float fields is inclusive (`confidence > 0.9` matches `confidence == 0.9`). When the user asks for strict ranges, use a small epsilon: `confidence > 0.9001`. See [references/operational-notes.md Note 5](references/operational-notes.md).

Limitations:
- Single template per query (the plugin uses one wide template by design).
- No JOIN-like ops; do post-filter in agent code if needed.
- The pseudo-wildcard `"the"` only matches files whose searchable body contains the word `the` — true for prose memories, may miss pure-metadata files. If you suspect coverage gaps, fall through to the index-scan path as a verification.

**All tiers path — index scan:**

If metadata templates aren't available or you got an empty result that seems wrong:

1. Determine which folders to scan (all `memories/` folders if no team filter; just the team's folder if team filter is set).
2. For each folder, read `_index.json`.
3. Walk `entries[]`, applying the filter set:
   - `kind` filter → use `by_kind` map for fast intersection.
   - `tag` filter → use `by_tag` map (intersection if multiple tags).
   - `status` filter → use `by_status` map.
   - `team` filter → already scoped by folder choice.
   - `since` / `until` → linear scan on `updated_at`.
4. Merge results across folders.

### Step 5 — Free-text query

This is the hardest case because the user's words may match titles, tags, slugs, or body content.

Multi-pass strategy:

**Pass 1 — Title/slug/tag match (instant, every tier):**

For each per-folder `_index.json`:
- Match query tokens against entry `title`, `slug`, `tags` (case-insensitive, substring).
- Score: exact title match (10), exact slug match (8), exact tag match (6), partial title match (4), partial slug match (3), partial tag match (2).

**Pass 2 — Wikilink target match (instant):**

Search the rollup's `by_wikilink` keys for entries whose title contains query tokens. Score: 5.

**Pass 3 — Body content match (Business+ tier only, with caveats):**

If `capabilities.body_search` is true:
- Call Box Search API with the query, filtered to the workspace folder.
- For each result, check if it appears in the index (filter out stray non-memory files).
- Score: 3 per body match (lower than title because body matches are fuzzier).
- **Warn the user:** "Body search may miss fresh writes — Box's index has a ~10 min lag, and only the first 10 KB of each memory body is searchable."

**Pass 4 — Direct content read (last resort, all tiers):**

If passes 1-3 returned no results and the user has fewer than ~50 memories total, read each memory's content directly and grep for the query. Slow but exhaustive. Only do this if explicitly asked or as a fallback when other strategies returned nothing.

### Step 6 — Rank and return

Sort matches by score (descending), then by `updated_at` (descending). Return the top N (default 10, or user-specified).

For each match, return:

```yaml
- id: <mem_…>
  title: <title>
  kind: <kind>
  status: <status>
  team: <team>
  tags: [<tags>]
  score: <relevance>
  matched_on: <title | slug | tag | wikilink | body>
  file_id: <Box file ID>
  filename: <filename>
  folder_path: <relative path>
  updated_at: <ISO>
  excerpt: <first ~200 chars of body, with the matched term highlighted if possible>
```

If the user asked a specific "what did we decide about X" question (not a list query), default to **returning the single best match's full content**, not a list. They want the answer, not a search results page.

### Step 7 — Stale index detection

When you read a folder's `_index.json`:

- Compare its `updated_at` to the folder's `modified_at` returned by Box. If the folder was modified more recently, the index may be stale.
- If stale, surface a soft warning: "The index for `<folder>` may be out of date (folder modified after last index update). Run `/box-index-rebuild` to refresh."
- Still return the results from the index — they're usually still correct for older memories. Drift only affects very recent writes.

### Step 8 — No-result handling

If nothing matches:

- Be specific about what you searched: "No memories match `<query>` in folders [<folders>] across passes [<passes>]."
- Suggest next steps:
  - Broaden the filter
  - Try a different tag or kind
  - Run `/box-index-rebuild` if recent writes might not be indexed
  - On Business+, suggest body search if it wasn't already used
- If the query was a wikilink target that doesn't exist, mention that it may be a forward reference to a memory not yet written.

## Including superseded memories

By default, recall excludes `status: superseded` and `status: archived`. To include them:

- User says "include all versions", "history", "what was the previous decision", or similar.
- `/box-recall --include-superseded`
- Frontmatter setting `include_superseded_in_recall: true` in `_box-memory.json`.

When showing superseded memories, follow the `superseded_by` chain to also surface the current version: *"This was superseded by `<new-id>` on `<date>`."*

## Multi-team queries

If the user asks across teams ("what does engineering know about X"), scan each accessible team folder's index. If Box returns 403 on a folder, skip it silently — that's expected (folder ACLs).

If the user asks "what teams have anything tagged auth", iterate teams and report counts per team. Don't load all content unless asked.

## Performance notes

- Reading an index file is ~1 Box GET per folder. Cheap.
- The workspace-root rollup index is the fastest entry point for cross-folder queries; prefer it when available.
- Body search (Business+) is the slowest legitimate route; use as a backup, not a primary.
- The "read every file" fallback should never run on workspaces over ~50 memories without confirmation — it can mean 50+ Box GETs.

## Errors to surface clearly

- **No workspace** → run `box-setup`.
- **Box MCP not connected** → standard MCP message.
- **Empty workspace** → "Workspace is empty — no memories saved yet. Start with `/box-write`."
- **Permission denied on a folder** → "Skipped folder `<path>` — no read access." Continue with accessible folders.

## Don't

- Don't rely on Box Search as a primary route. It lags by ~10 minutes and gates body content to Business+.
- Don't return raw file contents when the user asked a question. Synthesize the answer from the memory; cite the memory ID for traceability.
- Don't return superseded memories silently — always note they're not current.
- Don't invent memories that aren't in the index. A wikilink target that doesn't resolve is a dangling reference, not a hallucination opportunity.

## References

- `references/schema.md` — index structure and query patterns
- `references/architecture.md` — why this multi-pass approach
- `references/tier-matrix.md` — what's available where
