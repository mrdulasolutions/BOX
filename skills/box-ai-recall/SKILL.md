---
name: box-ai-recall
description: Semantic Q&A over box-memory contents using Box AI. Wraps the Box AI /ai/ask endpoint - multi-doc Q&A across up to 25 files (Business+) or Hub-indexed Q&A across up to 20,000 files (Enterprise Plus). Returns answers with citations. Use when the user asks an open-ended question, box-recall returns sparse results, or when the user wants fuzzy semantic search instead of exact match.
argument-hint: "<question> [--scope=<team|workspace|file-ids>] [--mode=multi-doc|hub] [--limit=<n>]"
---

# /box-ai-recall

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Ask Box AI a question about your memory contents. Two routes:

- **Multi-doc Q&A** (up to 25 files at once) — works on Business+ accounts with AI Units
- **Hubs Q&A** (up to 20,000 files indexed) — Enterprise Plus, requires the workspace to be Hub-backed

The skill auto-routes based on tier + workspace type. Costs AI Units per call — gate via `_box-memory.json.settings.ai_recall_enabled` to keep costs bounded.

## Usage

```
/box-ai-recall <question> [--scope=<team|workspace|file-ids>] [--mode=multi-doc|hub] [--limit=<n>]
```

Examples:
- `/box-ai-recall what did we decide about JWT vs sessions?` — semantic Q&A over the whole workspace
- `/box-ai-recall summarize all open tasks --scope=team --team=engineering` — scoped + summarization
- `/box-ai-recall --file-ids=12345,67890,... what are the consistent themes?` — explicit file set
- `/box-ai-recall --mode=hub which contracts mention force-majeure clauses?` — Hubs Q&A (Enterprise Plus)

## What to do

### Step 1 — Verify prerequisites

1. Read `_box-memory.json`. Confirm workspace exists. Confirm `capabilities.custom_metadata_templates` is `true` (Business+) — Box AI is gated by AI Units which Business+ accounts purchase.
2. Confirm `settings.ai_recall_enabled` is `true` (default `false` so users opt in to AI Unit consumption). If disabled, surface a clear opt-in path: *"Box AI recall is disabled in this workspace. Enable via `_box-memory.json.settings.ai_recall_enabled = true` if you want semantic Q&A. AI Units are consumed per call — see references/box-ai-units.md."*
3. Confirm Box MCP is connected and exposes the AI tools (`ask`, `extract_structured`, etc.). If not, surface: *"Box AI requires the official remote MCP at mcp.box.com. Install via Settings → Connectors → Box, ensure the `ai.readwrite` scope is granted."*

### Step 2 — Determine routing

Decide between **multi-doc** and **hub** mode:

| Condition | Route |
|---|---|
| Workspace is Hub-backed (`workspace_type: "hub"`) AND tier is Enterprise Plus | Hubs Q&A — `mode=single_item_qa` with `items.type=hubs` |
| Workspace is folder-backed, OR tier < Enterprise Plus | Multi-doc Q&A — `mode=multiple_item_qa` with up to 25 file IDs |
| Explicit `--mode=` flag | Honor the user's choice; warn if their tier can't support it |

### Step 3 — Hub warm-up check (if hub mode)

Read `_box-memory.json.hub.created_at` and `hub.last_item_added_at`. If either is within the last 10 minutes, fall through to multi-doc Q&A — Hubs Q&A returns empty during the indexing warm-up (see [operational-notes.md Note 7](../../references/operational-notes.md)). Tell the user *"Falling back to multi-doc Q&A — Hub was created/updated within the indexing warm-up window."*

### Step 4 — Build file set (if multi-doc mode)

1. Determine scope: `--scope=workspace` (default), `--scope=team --team=<name>`, or explicit `--file-ids=...`
2. Read the relevant `_index.json` files; collect entries' `file_id` values
3. Apply any additional filters (`--kind=`, `--tag=`, etc.) using the inverted maps
4. Cap at 25 files (Box's hard limit for multi-doc Ask). If filters yield more, sort by `updated_at` desc and take the top 25. Tell the user: *"Capped at 25 files (Box limit). Filtered to most recent. To query a larger set, promote the workspace to a Hub via `/box-init --as-hub` (Enterprise Plus)."*

### Step 5 — Build the AI Ask request

For **multi-doc mode**:

```json
{
  "mode": "multiple_item_qa",
  "prompt": "<the user's question>",
  "items": [
    {"type": "file", "id": "12345"},
    {"type": "file", "id": "67890"},
    ...
  ],
  "include_citations": true,
  "ai_agent": { "type": "ai_agent_ask", "ask": { "model": "<from config or default>" } }
}
```

For **hub mode**:

```json
{
  "mode": "single_item_qa",
  "prompt": "<the user's question>",
  "items": [{"type": "hubs", "id": "<hub_id>"}],
  "include_citations": true
}
```

Default model from `_box-memory.json.settings.ai_model` if set; otherwise let Box pick (currently GPT-5 mini as of 2026). Available models per [Box AI models catalog](https://developer.box.com/guides/box-ai/ai-models/) include GPT-5 series, Anthropic Claude Opus / Sonnet / Haiku 4.6, Gemini 3, Llama 4, Mistral.

### Step 6 — Call /2.0/ai/ask

Via the Box MCP's `box_ai_ask` tool (the official MCP exposes this; community MCPs may not). If the tool returns a 402 / quota error, the user has exhausted AI Units — surface and stop.

### Step 7 — Format the answer

Return:

```
Question: <user's question>
Mode: <multi-doc | hub>
Files queried: <N>

Answer:
<Box AI's response>

Citations:
- mem_<id> "<title>" → "<excerpt from the cited source>"
- mem_<id> "<title>" → "<excerpt>"
- ...

AI Units consumed: <if returned by API; otherwise note "see Box AI Units dashboard">
Model: <model_id>
```

If `include_citations` was honored, map each citation's `file_id` back to the workspace's `mem_id` via the index's `by_file_id` reverse lookup (or surface the raw file ID if not in the index).

### Step 8 — Suggest follow-ups

If the answer references concepts the user might want to drill into, suggest follow-up queries:

```
Follow-up suggestions:
- /box-recall mem_<cited_id>     — read the cited memory in full
- /box-ai-recall "<refined question>" --scope=...   — narrow the next query
```

## When to invoke

- User asks an open-ended question that isn't a direct ID/wikilink/slug lookup
- `box-recall` returned sparse or no results AND the workspace has Box AI access
- User explicitly asks for AI / semantic / smart search
- Pre-meeting summary requests ("what's outstanding on the auth project?")

## When NOT to invoke

- User asked for an exact ID, wikilink, or slug — those should go through `box-recall` (faster, no AI Unit cost)
- User explicitly opted out (`settings.ai_recall_enabled: false`)
- Tier doesn't support AI calls — fall back to `box-recall` and tell the user why
- Question is about plugin internals (workspace setup, schema details) — those go to docs, not AI recall

## AI Unit cost awareness

Box AI consumes "AI Units" per call. The plugin doesn't have visibility into per-call unit consumption (Box doesn't publish a public rate card — only sales-quote). Bound costs by:

- Defaulting `settings.ai_recall_enabled` to `false` — user opts in explicitly
- Suggesting `box-recall` first for any query that could plausibly be answered by exact lookup
- Capping file sets at the 25-file Box limit (you can't accidentally query 200 files)
- Surfacing 402 / quota errors immediately so the user knows when they've hit their tier's allowance

See [references/box-ai-units.md](../../references/box-ai-units.md) for the tier × allowance matrix.

## Errors to surface clearly

- **No workspace** → run `/box-init` first
- **Box MCP not the official remote** → "Box AI requires the official Box MCP at mcp.box.com. Run `/box-mcp-check` to verify."
- **AI Units exhausted (402 / quota)** → "AI Unit quota reached for this period. Use `/box-recall` for exact lookups, or purchase more units via Box admin."
- **`ai.readwrite` scope not granted** → "OAuth scope `ai.readwrite` not authorized. Admin needs to grant it on the Box MCP integration."
- **Hub warm-up still active** → falls through to multi-doc mode automatically; informs user
- **No matching files in scope** → "0 files in scope after filters. Broaden scope or check filters."

## Don't

- Don't call `/2.0/ai/ask` if `settings.ai_recall_enabled` is false. Costs real money.
- Don't fabricate citations. Only surface what Box AI's response actually returned.
- Don't call AI when a simple `box-recall` would answer the question — wasteful.
- Don't ignore the warm-up window for fresh Hubs. Falling through to multi-doc is automatic; document when it fires.

## References

- [Box AI Ask endpoint](https://developer.box.com/reference/post-ai-ask) — for human readers; this skill itself makes no runtime HTTP fetches
- [Box AI models](https://developer.box.com/guides/box-ai/ai-models/) — model catalog
- [Box AI Units guide](https://developer.box.com/guides/box-ai/) — cost model
- See operational-notes.md Note 7 for Hub indexing warm-up details
