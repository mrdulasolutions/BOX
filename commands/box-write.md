---
description: Write a memory to Box — captures a decision, fact, task, observation, or note as a durable markdown file with frontmatter and wikilinks
argument-hint: "[--kind=<kind>] [--team=<team>] [--tags=<comma-list>] [--title=<title>] [content]"
---

# /box-write

Force a memory write with optional structured arguments. Useful when you want to be explicit instead of relying on the agent to infer from conversation.

## What this command does

Invoke the `box-memory-write` skill with the user's arguments. The skill will:

1. Generate a ULID for the memory.
2. Derive a slug from the title.
3. Compose frontmatter (kind, status, tags, related, etc.).
4. Compose the body from the user's content.
5. Upload to the appropriate folder.
6. Update the folder's `_index.json`.
7. On Business+, apply the `boxMemory` metadata template.

## Argument handling

- **No arguments** → ask the user for content. They probably triggered this on a hunch; give them a chance to fill in the gap.
- **Free text after the command** → treat as the body content. Infer title and kind. Example: `/box-write We decided to use JWT instead of sessions because of mobile.` → title inferred as "JWT vs Sessions Decision", kind = `decision`.
- **`--kind=<kind>`** → explicit kind. One of: `decision`, `fact`, `task`, `observation`, `reference`, `note`.
- **`--team=<name>`** → write to a specific team's `memories/` folder.
- **`--tags=<a,b,c>`** → comma-separated tags.
- **`--title="..."`** → explicit title (overrides inferred title).
- **`--status=<status>`** → default `active`. Set `draft` if tentative.
- **`--supersedes=<mem_id>`** → mark the new memory as a replacement for a prior one. The skill handles updating both records.

If both content and arguments are provided, arguments win for structured fields, content is the body.

## Invocation

Pass parsed arguments to `box-memory-write`. Surface the skill's confirmation report.

## When the user has no content

If the user runs `/box-write` with nothing else, ask:

> What should we remember? You can say it freely, or paste/quote content. I'll infer the kind, tags, and title — or you can specify with `--kind=`, `--title=`, etc.

Don't write empty memories.

## Errors

- **No workspace** → ask the user to run `/box-init` first, or run `box-setup` then proceed.
- **Box MCP not connected** → standard MCP message.
