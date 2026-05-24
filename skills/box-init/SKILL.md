---
name: box-init
description: Bootstrap a Box.com workspace for agent memory and file storage. Creates folder structure (or a Box Hub on Enterprise Plus), writes workspace config, detects tier and capabilities, defines the boxMemory metadata template (Business+) so Box AI Extract can target it. Use when the user wants to set up box-memory, initialize a workspace, or create a Box vault for the first time.
argument-hint: "[workspace-name] [--team=<team>] [--parent=<folder-id>] [--as-hub]"
---

# /box-init

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Bootstrap a fresh box-memory workspace, or extend an existing one. Tier-aware routing:

- **Personal** — folder workspace; index-file recall only
- **Business+** — folder workspace with `boxMemory` metadata template; instant `mdfilters` queries plus Box AI Extract / Ask available
- **Enterprise Plus** — option to create a Box Hub instead of a folder, unlocking Hubs Q&A (up to 20,000 docs, AI-indexed)

## Usage

```
/box-init [workspace-name] [--team=<team>] [--parent=<folder-id>] [--as-hub]
```

Examples:
- `/box-init` — folder workspace named `box-memory` at Box root
- `/box-init my-vault --team=engineering` — workspace plus extra team subtree
- `/box-init my-vault --as-hub` — **Box Hub** workspace (Enterprise Plus only — for AI-indexed recall across up to 20k files)

## What to do

1. **Detect tier.** Call `box-tier-detect`. Read `capabilities.custom_metadata_templates`, `body_search`, `box_hubs`, `box_ai_units_available`. Cache in `_box-memory.json`.

2. **Check for existing workspace.** Search the parent folder for `_box-memory.json`. If found, don't overwrite — offer use-existing / create-alongside / re-initialize (confirm twice for the last).

3. **Choose workspace type:**
   - If `--as-hub` AND tier is Enterprise Plus → **Hub workspace**. Call `POST /2.0/hubs` to create a Hub via the Box MCP's Hubs tools. Record `workspace_type: "hub"` and the Hub ID in workspace config.
   - Otherwise → **folder workspace** (default). Create folders via the standard Box MCP file/folder tools.
   - If `--as-hub` was passed but tier doesn't support Hubs, surface: *"Hubs require Enterprise Plus. Creating a folder workspace instead; you can promote to a Hub later by running `/box-init <name> --as-hub` once your account is upgraded."* Continue with folder.

4. **Create folder structure** (for folder workspace):
   - `<workspace>/memories/`, `<workspace>/files/`, `<workspace>/companions/` (if folder layout), `<workspace>/teams/<default-team>/memories/`, `<workspace>/teams/<default-team>/files/`
   - For Hub workspace: just create the Hub via `POST /2.0/hubs`, then add items via `POST /2.0/hubs/{id}/manage-items` once memories are written. The Hub is the workspace's logical container; per-team subfolders aren't applicable to Hubs.

5. **Write `_box-memory.json`** at workspace root:

```json
{
  "version": 1,
  "schema_version": 2,
  "workspace_name": "<name>",
  "workspace_type": "folder | hub",
  "workspace_root_id": "<folder ID or Hub ID>",
  "workspace_owner_app": "box-memory",
  "created_at": "<ISO now>",
  "updated_at": "<ISO now>",
  "tier": "<from tier-detect>",
  "capabilities": { ...from tier-detect... },
  "metadata_template_key": "boxMemory",
  "metadata_template_created_at": "<ISO now>",
  "hub": {
    "id": "<Hub ID, if workspace_type=hub>",
    "created_at": "<ISO>",
    "last_item_added_at": "<ISO>"
  },
  "teams": ["<default-team>"],
  "agents": ["<agent identifier>"],
  "settings": {
    "default_team": "<default-team>",
    "companion_layout": "sibling",
    "include_superseded_in_recall": false,
    "rebuild_index_on_drift": true,
    "ai_recall_enabled": false,
    "ai_extract_enabled": false,
    "ai_model": null,
    "compliance_target": null
  }
}
```

Note `ai_recall_enabled` and `ai_extract_enabled` default to **false** — explicit opt-in for AI Unit consumption.

6. **Seed `_index.json`** in every memory-holding folder. See schema for the inverted-map shape.

7. **(Business+) Create the `boxMemory` metadata template.** Per the canonical schema in `references/schema.md`. Set `metadata_template_key` and `metadata_template_created_at`. This is what Box AI Extract Structured targets.

   **Warm-up window:** Surface to the user: *"Metadata template `boxMemory` created. Bulk mdfilters queries may take ~10 minutes to return correct results (Box's metadata index warm-up). Direct file fetches work immediately. `box-recall` falls back to `_index.json` during warm-up."*

8. **(Hub workspace only) Hub warm-up notice.** Same pattern: *"Hub `<name>` created. Box AI Q&A over the Hub may take several minutes to return results for newly-added files (Hub indexing warm-up). `box-recall` and `box-ai-recall` fall back to file-set Q&A during the window."* See [operational-notes.md Note 7](../../references/operational-notes.md).

9. **Write workspace README.** Brief orientation doc.

10. **Report.** Workspace name, type (folder/hub), tier, capabilities, routing strategy, next-step commands:

```
✓ Workspace ready.

Name:         <name>
Type:         <folder | hub>
Root ID:      <id>
Tier:         <tier>
Routing:
  Memory recall:        _index.json (instant; works on every tier)
  AI semantic recall:   <available if ai_recall_enabled + Business+, gated behind /box-ai-recall>
  Hub Q&A:              <available if workspace_type=hub + Enterprise Plus>
  Companion extraction: <available if ai_extract_enabled + Business+, via /box-ai-extract>

Next:
  /box-write          save a memory
  /box-companion <id> describe a binary
  /box-team ls        list teams
  /box-ai-recall ...  (opt-in) semantic Q&A — toggle settings.ai_recall_enabled to enable
```

## Idempotency

Re-running with the same name is safe. Hub mode: if the Hub already exists, reuse it; don't create a duplicate. Folder mode: same as before.

## Errors to surface clearly

- **Box MCP not connected** → "Connect via your platform's MCP configuration. We recommend the official Box remote MCP at `mcp.box.com`."
- **403 on template / Hub create with Business+ account** → likely stale OAuth token. Disconnect and reconnect Box MCP to refresh scope.
- **409 conflict on workspace folder** → pick a different name or use the existing folder.
- **`--as-hub` requested but tier insufficient** → fall back to folder, surface clearly.

## Deep reference

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-init-detail.md
- Schema (workspace config v2 with Hub support): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Tier matrix: https://github.com/mrdulasolutions/BOX/blob/main/references/tier-matrix.md
- Operational notes (template + Hub warm-up windows, OAuth scope): https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
- Box AI Units cost model: https://github.com/mrdulasolutions/BOX/blob/main/references/box-ai-units.md
- Hubs reference (Box official): https://developer.box.com/guides/hubs-api/use-cases
