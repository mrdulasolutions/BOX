---
name: box-team
description: Add or manage a team subtree in a box-memory workspace. Creates team folders with their own memories, files, and index - and tracks teams in workspace config. Box folder ACLs are the real isolation boundary; this skill creates structure only. Use when the user wants to create a team, list teams, inspect a team's contents, find cross-team conflicts, or remove a team.
argument-hint: "<create|ls|inspect|conflicts|remove> [name]"
---

# /box-team

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Multi-team operations on a box-memory workspace. Each team gets its own subfolder with its own indexes. **Box folder ACLs (not frontmatter `team:`) are what actually keeps team content isolated** — this skill creates structure; permissions are set in Box's web UI.

## Usage

```
/box-team <subcommand> [name]
```

Subcommands:
- `create <name>` — add a new team subtree
- `ls` (or `list`) — list teams + memory counts
- `inspect <name>` — show what's in a team
- `conflicts` — find duplicate slugs/titles across teams
- `remove <name>` — remove team from config (preserves files; confirms twice)

If no subcommand, default to `ls`. If just a name with no subcommand, default to `create <name>`.

Examples:
- `/box-team engineering` — create team
- `/box-team ls` — list teams
- `/box-team inspect ops` — show ops contents

## What to do — Create

1. **Verify workspace** (`_box-memory.json`). If missing, run `box-init` first.
2. **Validate name.** Kebab-case, lowercase, alphanumeric + hyphens. Suggest a clean version if not.
3. **Check duplicate.** If `teams[]` in config already includes the name, stop and report.
4. **Create folders** under `teams/<name>/`: `memories/`, `files/`, `companions/` (only if folder layout). Capture all folder IDs.
5. **Seed `_index.json`** in each new memory-holding folder.
6. **Update `_box-memory.json`.** Append name to `teams[]`, add `folder_ids.team_<name>_*` keys, bump `updated_at`.
7. **Surface the access-control reminder** prominently: "Box folder ACLs (not frontmatter) are what enforces isolation. Open Box web UI → Share Settings on the team folder to grant access."

## What to do — Conflicts

Read every accessible team's `_index.json`. Build `slug -> [(team, mem_id, title, updated_at), ...]`. Report slugs appearing in 2+ teams + titles matching exactly across teams. Don't auto-resolve — surface and let user decide.

## What to do — Remove (cautious)

1. **Confirm twice.** "This removes the team from config and stops tracking it. Memory files stay in Box untouched. Proceed?"
2. **Do not delete files.** Only remove from `_box-memory.json.teams[]` and the corresponding `folder_ids.team_<name>_*` keys.
3. Optionally offer to move the team folder under `_archive/`. Move ≠ delete.

## Errors to surface clearly

- **Invalid team name** → suggest clean version.
- **Permission denied creating folder** → check parent folder ACLs.
- **403 inspecting a team** → "No read access (Box ACLs). Skipping." — continue with other teams.

## Don't

- Don't try to set Box folder ACLs automatically. The user does this in Box web UI with intent.
- Don't delete memory files when a team is "removed" — files are durable artifacts.
- Don't skip the access-control reminder. People assume frontmatter is access control. It isn't.

## Deep reference

For the full subcommand specifications, conflict-detection algorithm, fuzzy title matching, archive move semantics, and folder ACL design rationale:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-team-detail.md
- Architecture (why folder ACLs are the boundary): https://github.com/mrdulasolutions/BOX/blob/main/references/architecture.md
- Schema (workspace config, folder_ids): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
