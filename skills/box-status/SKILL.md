---
name: box-status
description: Report the box-memory workspace status - tier, capabilities, teams, memory counts, index health, recent activity. Read-only. Use when the user asks what's in their Box workspace, wants to show workspace status, asks how many memories or what tier, or wants a sanity check before a heavy operation.
argument-hint: "[--refresh-tier] [--check-indexes] [--team=<name>]"
---

# /box-status

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Produce a human-readable snapshot of a box-memory workspace. Read-only — never modifies anything. Useful as a sanity check, an audit summary, or a pre-flight before a heavy operation.

## Usage

```
/box-status [--refresh-tier] [--check-indexes] [--team=<name>]
```

Examples:
- `/box-status` — standard report (cached tier info)
- `/box-status --refresh-tier` — re-probe Box capabilities before reporting
- `/box-status --check-indexes` — flag index drift suspicions
- `/box-status --team=engineering` — scope to one team

## What to do

1. **Read `_box-memory.json`.** If missing, output "No box-memory workspace found at this Box location. Run `/box-init` to create one." Don't error.
2. **(If `--refresh-tier`)** Call `box-tier-detect` to re-probe and update cached capabilities.
3. **Read workspace-root rollup `_index.json`** for total counts. If missing or older than 24h, walk per-folder indexes. Note staleness in the report.
4. **Per-team stats.** For each team in `_box-memory.json.teams[]`, read the team's `memories/_index.json` and count by status/kind. If a team folder is 403-inaccessible, mark "access denied" and continue.
5. **(If `--check-indexes`)** Compare each per-folder index's `updated_at` to the folder's `modified_at` from Box. Flag suspect folders. Don't rebuild — suggest `/box-index-rebuild [folder]`.
6. **Compose report** with sections: workspace info, account (tier + capabilities), routing, contents (totals by status/kind), teams, index health, most recent memories (top 5), top tags (top 5), settings, next-step commands.
7. **Flag actionable issues.** Drift suspicions, tier-mismatch hints, stale-OAuth-token symptoms, missing compliance declarations.

## Don't

- Don't modify anything. Status is read-only.
- Don't trigger a tier re-probe unless `--refresh-tier` was asked — cached value is fine.
- Don't rebuild indexes during status; surface drift, suggest `box-index-rebuild`.
- Don't load every memory's full content; index entries are enough.

## Errors to surface clearly

- **Box MCP not connected** → standard MCP message.
- **Permission denied reading workspace root** → check Box folder permissions on the workspace root.

## Deep reference

For the full report template, drift-detection logic, and actionable-issue heuristics:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-status-detail.md
- Schema (workspace config, index format): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Operational notes (when index health checks matter): https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
