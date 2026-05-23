---
description: Manage teams in a box-memory workspace — create, list, inspect, conflict-scan, or remove (config only)
argument-hint: "<subcommand> [args]    where subcommand = create|ls|inspect|conflicts|remove"
---

# /box-team

Multi-team operations for a box-memory workspace. Wraps the `box-team-isolate` skill.

## Subcommands

| Subcommand | Purpose | Example |
|---|---|---|
| `create <name>` | Add a new team subtree | `/box-team create engineering` |
| `ls` (or `list`) | List teams + memory counts | `/box-team ls` |
| `inspect <name>` | Show what's in a team | `/box-team inspect ops` |
| `conflicts` | Cross-team duplicate slug/title detection | `/box-team conflicts` |
| `remove <name>` | Remove team from config (preserves files; confirms twice) | `/box-team remove old-team` |

If no subcommand is given but a name is, default to `create <name>`:

- `/box-team engineering` ≡ `/box-team create engineering`.

If neither is given, default to `ls`.

## What this command does

Parse the subcommand + arguments, invoke `box-team-isolate` with the corresponding mode. Surface the skill's report.

## Reminder this command must enforce

After `create`, the skill surfaces an access-control reminder explaining that Box folder ACLs (not frontmatter) are the real isolation boundary. Don't strip that reminder when relaying to the user — it's load-bearing for security expectations.

## Errors

- **Invalid team name** → suggest a clean version (kebab-case, lowercase).
- **Permission denied** → check Box folder permissions.
- **No workspace** → run `/box-init`.
