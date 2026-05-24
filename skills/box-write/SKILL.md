---
name: box-write
description: Save a memory to Box as a durable markdown file with YAML frontmatter and Obsidian-style wikilinks. Append-only, never overwrites. Use when the user says "remember that...", "save this", "log a decision", "record an observation", or anything that should persist as agent memory across sessions.
argument-hint: "[content] [--kind=<kind>] [--title=<title>] [--team=<team>] [--tags=<a,b,c>]"
---

# /box-write

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Commit a piece of agent knowledge to Box as a durable, append-only markdown memory. Every memory is recallable by `box-recall` instantly via the per-folder index.

## Usage

```
/box-write [content] [--kind=<kind>] [--title=<title>] [--team=<team>] [--tags=<a,b,c>]
```

Examples:
- `/box-write We decided to use JWT instead of sessions because of mobile.` — saves a decision
- `/box-write --kind=task --title="Rotate JWT keys" --tags=ops,security Cron monthly` — explicit fields

## What to do

1. **Verify workspace.** Read `_box-memory.json`. If missing, call `box-init` first.
2. **Generate IDs.** Memory ID = ULID prefixed `mem_`. Slug = kebab-case from title.
3. **Determine kind.** decision | fact | task | observation | reference | note | companion. Infer from content unless `--kind=` provided.
4. **Check for slug collision.** Read target folder's `_index.json`. If existing active memory has same slug and same concept, supersede it (set old → `status: superseded`, `superseded_by: <new_id>`). If different concept, append `-2` to slug.
5. **Build frontmatter.** Fields: id, slug, title, kind, status (default `active`), team, agent, created_at, updated_at, tags, related (wikilinks), links, supersedes (if applicable). Use double quotes around wikilinks.
6. **Compose body.** Markdown with H1 title, brief summary callout, context section, kind-specific sections, related wikilinks. Use Obsidian-style `[[Title]]` for cross-memory references.
7. **Upload.** Filename = `<kind>__<slug>.md` (double underscore). Folder = `memories/` at workspace root or `teams/<team>/memories/` if team scope.
8. **(Business+ only) Apply metadata template.** Map frontmatter fields to `boxMemory` template instance. If template is in 10-min warm-up, log but don't fail.
9. **Update folder's `_index.json`.** Append entry, update all inverted maps (by_id, by_slug, by_wikilink, by_kind, by_status, by_tag). Always update — recall depends on it.
10. **Report.** Title, ID, file path, tags, related, supersession info.

## Quality bar

- **Title is searchable** — real words humans would type, not internal jargon.
- **Body explains WHY**, not just WHAT. Capture reasoning.
- **Tags are sparse** — 2–5 per memory.
- **Wikilinks are intentional** — only link to memories you've verified exist or are about to write.

## When NOT to write

- Conversational acknowledgments ("got it", "thanks")
- Recap of code already in git
- Time-bound trivia with no recall value
- Content the user said "don't save" about

## Errors to surface clearly

- **No workspace** → call `box-init` first.
- **Permission denied on target folder** → check Box folder ACLs or pick a different team.

## Deep reference

For full frontmatter schema, append-only design rationale, supersession chain rules, metadata template field mapping, and edge cases:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-write-detail.md
- Schema: https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Architecture: https://github.com/mrdulasolutions/BOX/blob/main/references/architecture.md
- Operational notes: https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
