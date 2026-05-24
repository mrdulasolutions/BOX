---
name: box-init
description: Bootstrap a Box.com workspace for agent memory and file storage. Creates the standard folder structure, writes workspace config, detects Box account tier and capabilities, and on Business+ tier optionally creates a metadata template for instant recall. Use when the user wants to set up box-memory, initialize a workspace, or create a Box vault for the first time.
argument-hint: "[workspace-name] [--team=<team>] [--parent=<folder-id>]"
---

# /box-init

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Bootstrap a fresh box-memory workspace on the user's Box account, or add structure to an existing one. Tier-aware: Personal uses index files, Business+ unlocks metadata templates.

## Usage

```
/box-init [workspace-name] [--team=<team>] [--parent=<folder-id>]
```

Examples:
- `/box-init` — workspace named `box-memory` at Box root
- `/box-init my-vault` — workspace named `my-vault`
- `/box-init my-vault --team=engineering` — workspace plus an extra team subtree

## What to do

1. **Detect tier.** Probe metadata template scope via the Box MCP. Success = Business+; "user does not have an enterprise" = Personal. Cache capabilities (custom metadata templates, body search, max file size, retention, legal holds) in `_box-memory.json`.
2. **Check for existing workspace.** Search the parent folder for `_box-memory.json`. If found, don't overwrite — offer use-existing / create-alongside / re-initialize (confirm twice for the last).
3. **Create folder structure.** Under the workspace root: `memories/`, `files/`, `companions/` (only if folder layout chosen), `teams/<default-team>/memories/`, `teams/<default-team>/files/`. Capture every Box folder ID.
4. **Write `_box-memory.json`.** Workspace config with tier, capabilities, folder IDs, agent identifier, default team, companion layout. Upload at workspace root.
5. **Seed `_index.json`** in every memory-holding folder. Empty entries + initialized inverted maps (by_id, by_slug, by_wikilink, by_kind, by_tag, by_status, by_companion_for). See schema reference below.
6. **(Business+ only) Create the `boxMemory` metadata template.** Enterprise-scope, fields per the schema reference. Set `metadata_template_key` and `metadata_template_created_at` in workspace config.
7. **Warm-up notice.** Surface to user: bulk `mdfilters` queries against a fresh template take ~10 min to return correctly (Box behavior). During warm-up, `box-recall` falls back to the index-file path automatically.
8. **Write workspace README.** Brief orientation doc at workspace root explaining the layout.
9. **Report.** Confirm name, root, tier, teams, capabilities, routing strategy, and next-step commands.

## Idempotency

Re-running with the same name should be safe: re-use existing folders, never overwrite `_box-memory.json` without explicit confirmation, preserve existing `_index.json` content. Setup is structure only — no memory files are written.

## Errors to surface clearly

- **Box MCP not connected** → "Connect Box MCP via your platform's MCP configuration, then retry."
- **403 on template create with Business+ account** → likely stale OAuth token after a recent tier upgrade. Disconnect and reconnect the Box MCP to refresh scope.
- **409 conflict on workspace folder** → pick a different name or use the existing folder.

## Deep reference

For the detailed step-by-step procedure, edge cases, full schema, compliance handling, and template field types, fetch these from the repo:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-init-detail.md
- Schema: https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Tier matrix: https://github.com/mrdulasolutions/BOX/blob/main/references/tier-matrix.md
- Operational notes (OAuth scope, warm-up windows): https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md

Fetch these when the workflow gets non-trivial or you hit something not covered in the brief procedure above.
