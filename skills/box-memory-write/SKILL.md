---
name: box-memory-write
description: Write a new memory to a box-memory workspace. Generates a ULID, builds YAML frontmatter (kind, status, tags, related wikilinks), composes the markdown body, uploads to the appropriate Box folder, and updates the folder's _index.json — plus, on Business+ tier, applies the boxMemory metadata template instance. Invoke when the user says "remember that…", "save this to Box", "log a decision", "record an observation", "note that…", or anything that should persist as durable agent memory. Also fires when the user runs /box-write.
---

# box-memory-write

You commit a piece of agent knowledge to Box as a durable, append-only memory file with structured frontmatter and Obsidian-style links. Every memory you write is recallable by the `box-memory-recall` skill instantly via the index, and (on Business+) via Box's Metadata Query API.

## When you fire

- The user says "remember…", "save…", "log…", "record…", "note that…", "let's capture…", or anything that signals durable persistence.
- The user runs `/box-write`.
- Another skill (often `box-file-companion`) calls you to write a memory.
- You detect a decision, fact, or insight in the conversation that the user has not explicitly said "don't save" about, **and** the user has a workspace set up. Be conservative — when in doubt, ask before writing.

## Inputs you need

Required:

- **Workspace** — must exist. If it doesn't, call `box-setup` first.
- **Title** — a plain-English title. You can infer from the user's request, but confirm if it's not obvious.
- **Body content** — the actual knowledge being captured.

Inferred (with defaults, ask only if ambiguous):

- **Kind** — `decision` if the user said "we decided", `fact` if a static piece of info, `task` if there's an action verb + future tense, `observation` if it's a noticing, `reference` if it's a pointer to external info, `note` as default catch-all. Companions use a separate skill.
- **Tags** — extract from content. Lowercase, hyphenated, flat (or nested via `/`).
- **Related** — `[[wikilinks]]` to other memories. Recall the workspace index to find existing memories that might be related; don't invent dangling links unless the target is something the user clearly intends to capture next.
- **Team** — `default` unless the user specifies a team or you're inside a team-scoped conversation.
- **Status** — `active` unless the user says "draft" or "tentative" (→ `draft`).
- **Confidence** — 0.9 if the user stated this directly; 0.7 for an agent-inferred observation; 0.5 for speculation. Skip if unsure.

## What you do

### Step 1 — Verify workspace exists

Read `_box-memory.json` from the user's expected workspace root. If missing, call `box-setup` first. Don't proceed without it.

### Step 2 — Determine target folder

- If the user mentioned a team or you're in a team context: target `teams/<team>/memories/`.
- Otherwise: target `memories/` at the workspace root.

Get the target folder's ID from `_box-memory.json` under `folder_ids`.

### Step 3 — Generate identifiers

- **ID:** ULID prefixed `mem_`. Compose from current UTC timestamp (10 chars) + 16 chars of Crockford base32 random. Example: `mem_01HXYZA1B2C3D4E5F6G7H8J9K0`.
- **Slug:** derive from title — lowercase, replace non-alphanumeric with `-`, collapse runs, trim. Example: `"JWT vs Sessions Decision"` → `jwt-vs-sessions-decision`.

### Step 4 — Check for slug collision

Read the target folder's `_index.json`. If `by_slug[<slug>]` exists:

- If the existing memory has `status: active` and you're writing the same conceptual thing, prefer **superseding it** (Step 7 handles this).
- If you're writing a different concept that happens to share a slug, append `-2` (or `-3` etc.) until unique. Update the slug field accordingly.

### Step 5 — Build the frontmatter

```yaml
---
id: <ULID>
slug: <slug>
title: <title>
kind: <kind>
status: <status, default active>
team: <team, default "default">
agent: <e.g. "claude-code">
created_at: <ISO-8601 now in UTC>
updated_at: <ISO-8601 now in UTC>
confidence: <float or omit>
tags: [<tag>, ...]
related:
  - "[[Other Memory Title]]"
links:
  - url: <url>
    label: <label>
supersedes: [<id>, ...]   # only if superseding (Step 7)
---
```

Omit optional fields rather than emitting `null`. Use double-quoted strings for wikilinks (they contain brackets).

### Step 6 — Compose the body

Default structure (skip sections that aren't relevant):

```markdown
# <title>

> <one-line summary or callout>

## Context
<why this is being captured>

## <Kind-specific section>
- Decision: ## Decision and ## Why
- Fact: ## Fact and ## Source
- Task: ## Task with [ ] checklist
- Observation: ## Observation
- Reference: ## Reference

## Related
- [[Other Memory]]
- [[Another One]]

## Open questions
- [ ] <if any>
```

Use Obsidian-style `[[wikilinks]]` for cross-memory references in the body. The `related:` frontmatter array is the structured graph; the body wikilinks are inline reading aids. They don't need to match exactly.

End the body with a tag line like:
```
#<kind> #<tag1> #<tag2>
```
This is optional but helpful for downstream Obsidian rendering.

### Step 7 — Handle supersession

If a prior `status: active` memory has the same slug or covers the same concept:

1. The **new memory** sets `supersedes: [<old-id>]` in frontmatter.
2. The **old memory** is updated: `status: superseded`, `superseded_by: <new-id>`, `updated_at: <now>`. Re-upload as a new version of the old file (Box keeps the version history).
3. Update the old memory's index entry to reflect `status: superseded`.

Don't delete the old memory file. Append-only.

### Step 8 — Compose filename

`<kind>__<slug>.md` — double underscore separator. Example: `decision__jwt-vs-sessions-decision.md`.

If you appended `-N` to the slug for collision, the filename uses the suffixed slug.

### Step 9 — Upload to Box

Call the Box MCP tool to create the file in the target folder. Body is the rendered markdown (frontmatter + body). Capture the new `file_id`.

If you get 409 conflict on filename despite slug uniqueness, the slug counter logic missed something. Bump the slug suffix and retry once. If still failing, surface to the user.

### Step 10 — (Business+ only) Apply metadata template instance

If `capabilities.custom_metadata_templates` is true and `metadata_template_key` is set:

Apply the `boxMemory` metadata instance to the new file with the matching frontmatter values. Map:

- `memory_id` → frontmatter `id`
- `slug` → frontmatter `slug`
- `title` → frontmatter `title`
- `kind` → frontmatter `kind`
- `status` → frontmatter `status`
- `team` → frontmatter `team`
- `agent` → frontmatter `agent`
- `tags` → comma-joined frontmatter `tags`
- `companion_for_file_id` → null for non-companion memories
- `sha256` → null for non-companion memories
- `created_at` → frontmatter `created_at`
- `updated_at` → frontmatter `updated_at`

If the metadata apply fails (template missing, permission), log the failure but **don't fail the write** — the index is the primary fallback. Note the discrepancy in your report.

### Step 11 — Update the folder's `_index.json`

1. Download the current `_index.json` for the target folder.
2. Append the new entry to `entries[]`:
   ```json
   {
     "id": "<mem_ID>",
     "file_id": "<Box file ID>",
     "filename": "<kind>__<slug>.md",
     "title": "<title>",
     "slug": "<slug>",
     "kind": "<kind>",
     "status": "<status>",
     "team": "<team>",
     "tags": [<tags>],
     "related": [<related wikilinks>],
     "companion_for": null,
     "sha256": null,
     "size_bytes": <bytes>,
     "created_at": "<ISO>",
     "updated_at": "<ISO>"
   }
   ```
3. Update the inverted maps:
   - `by_id[<id>]` → entries array index
   - `by_slug[<slug>]` → `<id>`
   - `by_wikilink[<title>]` → `<id>`
   - `by_kind[<kind>]` → append `<id>`
   - `by_status[<status>]` → append `<id>`
   - For each tag: `by_tag[<tag>]` → append `<id>`
4. If superseding: update the old entry's `status` → `superseded` and rebuild `by_status` for both entries.
5. Bump `updated_at` and `entry_count`.
6. Upload as a new version of `_index.json` (Box keeps version history of the index too).

### Step 12 — Update the workspace-root rollup index

This is lazy by default. Only update the rollup if:

- The skill caller explicitly asked for rollup consistency, OR
- This is a cross-team operation, OR
- The rollup's `updated_at` is more than 1 hour old AND we're writing more than 1 memory in this session

Otherwise, leave the rollup for the next `/box-status` or `box-index-rebuild` to refresh.

### Step 13 — Report

Output a brief confirmation:

```
✓ Memory saved.

Title:    <title>
ID:       <mem_…>
File:     <kind>__<slug>.md
Folder:   <path>
File ID:  <Box file ID>
Tags:     [<tags>]
Related:  [<wikilinks>]
Metadata template: <applied | skipped — reason>

To recall: /box-recall <title> or /box-recall id:<mem_…>
```

If you superseded an older memory, mention it: `Superseded: mem_… (now status: superseded)`.

## Quality bar — what makes a good memory

- **Title is searchable.** Real words humans would type, not internal jargon.
- **Body explains WHY**, not just WHAT. The user can read the diff for what. Capture reasoning.
- **Tags are sparse and meaningful.** 2–5 tags per memory. Don't tag everything.
- **Wikilinks are intentional.** Only link to memories you've verified exist or are about to write.
- **Status is honest.** Don't mark something `active` if it's actually `draft`.

## When to ask before writing

- **The user's signal is ambiguous** ("interesting" — is that a save request or just a comment?).
- **Writing would create duplicates.** Three near-identical memories from one conversation is a smell.
- **The content is volatile.** "We *might* use JWT" → don't write a `decision`; either wait or write an `observation` with low confidence.
- **The content is sensitive.** PHI, credentials, customer-identifying details. Confirm the workspace's compliance posture allows it (and that the user wants it in Box).

## When NOT to write

- Pure conversational fillers — "thanks", "got it", acknowledgments.
- Recap of code that's already in git — the diff and commit message are authoritative.
- Highly time-bound trivia ("it's 3pm right now") — these have no recall value.
- Anything the user said "don't save" or "don't remember" about.

## Errors to surface clearly

- **No workspace** → "No box-memory workspace found. Run `/box-init` first." Then call `box-setup`.
- **Box MCP not connected** → standard MCP message.
- **Permission denied on target folder** → "Can't write to <folder>. Check Box folder permissions or pick a different team."
- **409 on filename** (after slug bump) → "Slug collision is recurring. Check `_index.json` for drift, run `/box-index-rebuild`."

## Don't

- Don't overwrite existing memory files. Always create-new or version-up.
- Don't skip the index update — recall depends on it.
- Don't invent wikilinks to memories that don't exist. Only link to titles you've verified in the index, or to titles you're about to write next.
- Don't write to a team folder the user doesn't have access to (Box will 403 anyway; surface clearly).
- Don't compress the body to one line. Capture enough context that the memory makes sense to a future agent or user reading it cold.

## References

- `references/schema.md` — full frontmatter, body, and index schemas
- `references/architecture.md` — append-only design, ID rules, index pattern
