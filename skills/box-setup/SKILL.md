---
name: box-setup
description: Bootstrap a Box workspace for agent memory + file storage. Creates the standard folder structure (memories, files, companions, teams), writes the workspace config file (_box-memory.json), seeds initial _index.json files, and on Business+ tier optionally creates the boxMemory metadata template. Invoke this when the user runs /box-init, asks to "set up Box memory", "initialize a workspace", "create a Box vault", or when another skill discovers no workspace exists yet.
---

# box-setup

You bootstrap a new box-memory workspace. After you run, the user can write and recall memories, store binaries with companions, and isolate by team — all the other skills depend on the structure you create.

## When you fire

- User runs `/box-init` or asks to set up Box memory.
- Another skill (write, recall, companion) discovers no `_box-memory.json` and asks you to bootstrap.
- User asks to create a new workspace under an existing Box account.

## Inputs to gather (ask the user, with sensible defaults)

1. **Workspace name** (default: `box-memory`). Used as the root folder name in Box.
2. **Workspace location** (default: Box root `0`). Box folder ID under which to create the workspace folder. If the user already has a "Documents" or similar folder they want to nest under, accept the folder ID or path.
3. **Initial teams** (default: `["default"]`). The user can add more later via `box-team-isolate`.
4. **Companion layout** (default: `sibling`). Either `sibling` (companion `.md` lives next to its binary in the same folder) or `folder` (all companions live in a `companions/` subdirectory).
5. **Compliance posture** (default: empty). If the user knows their Box plan includes SOC 2, HIPAA, FedRAMP, etc., capture it for the config file. Optional. They can declare later.

If the user just says "set it up" without specifying, use defaults and confirm: *"Creating workspace `box-memory` under Box root, with team `default`, sibling companion layout. Sound good?"* Proceed unless they object.

## What you do

### Step 1 — Detect tier

Call `box-tier-detect` first. You need the capability matrix before you can decide whether to create a metadata template.

### Step 2 — Check for existing workspace

Search the chosen parent folder for `_box-memory.json`. If one exists, **do not overwrite.** Surface its current state and ask:

- *"A workspace already exists here named `<name>` (tier: <tier>, created <date>). Do you want to (a) use the existing workspace, (b) create another alongside it with a different name, or (c) re-initialize from scratch (destructive — will overwrite the config)?"*

Default is (a). Stop and proceed with the existing workspace.

### Step 3 — Create the workspace root folder

Call Box MCP to create a folder named `<workspace-name>` under the parent folder. Capture its `folder_id`.

If a folder with that name already exists at the parent, Box returns 409. Surface: *"A folder named `<name>` already exists. Use that one, or pick a different name?"* — let the user choose.

### Step 4 — Create the subfolder structure

Under the workspace root, create:

- `memories/` — default-scope memories
- `files/` — binary uploads
- (If `companion_layout == "folder"`) `companions/` — paired `.md` files
- `teams/` — placeholder for multi-team subtrees
- `teams/<default-team>/` plus `teams/<default-team>/memories/`, `teams/<default-team>/files/`, and `companions/` if folder layout
- `_archive/` — for `status: archived` memories that someone wants moved out of the active set (optional, agents can create on demand)

Capture every folder ID. You'll need them for the workspace config.

### Step 5 — Build and upload `_box-memory.json`

Build the config object following `references/schema.md`:

```json
{
  "version": 1,
  "schema_version": 1,
  "workspace_name": "<name>",
  "workspace_root_id": "<root folder ID>",
  "created_at": "<ISO now>",
  "updated_at": "<ISO now>",
  "tier": "<from tier detect>",
  "tier_detected_at": "<ISO now>",
  "capabilities": { ... from tier detect ... },
  "metadata_template_key": null,
  "metadata_template_created_at": null,
  "teams": ["<default-team>"],
  "agents": ["<the current agent's identifier, e.g. claude-code>"],
  "settings": {
    "default_team": "<default-team>",
    "companion_layout": "<sibling | folder>",
    "include_superseded_in_recall": false,
    "rebuild_index_on_drift": true
  },
  "folder_ids": {
    "root": "<id>",
    "memories": "<id>",
    "files": "<id>",
    "companions": "<id or null>",
    "teams": "<id>",
    "team_<name>_root": "<id>",
    "team_<name>_memories": "<id>",
    "team_<name>_files": "<id>",
    "team_<name>_companions": "<id or null>"
  }
}
```

Upload as `_box-memory.json` to the workspace root.

### Step 6 — Seed `_index.json` files

For every folder that holds memories (workspace `memories/`, each team's `memories/`, optionally `files/` and `companions/`), upload an initial empty `_index.json`:

```json
{
  "version": 1,
  "folder_id": "<the folder's ID>",
  "folder_path": "<relative path>",
  "updated_at": "<ISO now>",
  "tier": "<from tier detect>",
  "entry_count": 0,
  "entries": [],
  "by_id": {},
  "by_slug": {},
  "by_wikilink": {},
  "by_kind": {},
  "by_tag": {},
  "by_status": {},
  "by_companion_for": {}
}
```

Also upload a workspace-root rollup `_index.json` that references the per-folder indexes:

```json
{
  "version": 1,
  "folder_id": "<root folder ID>",
  "folder_path": "/",
  "updated_at": "<ISO now>",
  "tier": "<from tier detect>",
  "entry_count": 0,
  "child_indexes": [
    {"folder_path": "memories/", "folder_id": "<id>", "index_file_id": "<id of _index.json>"},
    {"folder_path": "teams/<default-team>/memories/", "folder_id": "<id>", "index_file_id": "<id>"}
  ],
  "entries": [],
  "by_id": {},
  "by_slug": {},
  "by_wikilink": {},
  "by_kind": {},
  "by_tag": {}
}
```

### Step 7 — (Business+ only) Create the boxMemory metadata template

If `capabilities.custom_metadata_templates` is true AND `capabilities.template_create_permission` is true:

Create an enterprise-scope metadata template via Box MCP with these fields (see `references/schema.md` for the canonical definition):

```yaml
scope: enterprise
templateKey: boxMemory
displayName: box-memory
fields:
  - {key: memory_id,             displayName: Memory ID,            type: string}
  - {key: slug,                  displayName: Slug,                 type: string}
  - {key: title,                 displayName: Title,                type: string}
  - {key: kind,                  displayName: Kind,                 type: enum, options: [decision, fact, task, observation, reference, note, companion]}
  - {key: status,                displayName: Status,               type: enum, options: [active, draft, superseded, archived, held]}
  - {key: team,                  displayName: Team,                 type: string}
  - {key: agent,                 displayName: Agent,                type: string}
  - {key: tags,                  displayName: Tags,                 type: string}  # comma-separated; multiSelect requires preset options
  - {key: companion_for_file_id, displayName: Companion for file,   type: string}
  - {key: sha256,                displayName: SHA256 at review,     type: string}
  - {key: created_at,            displayName: Created,              type: date}
  - {key: updated_at,            displayName: Updated,              type: date}
```

Set `metadata_template_key` in `_box-memory.json` to `"boxMemory"` after success. Also set `metadata_template_created_at` to the current ISO timestamp — `box-memory-recall` checks this to know whether the template is still in its ~10 min warm-up window. Update the config in Box.

**Surface the warm-up window to the user.** When you report setup success, include: *"Metadata template `boxMemory` created. Bulk `mdfilters` queries may take ~10 minutes to return correct results for freshly-applied template instances (a Box behavior, not a plugin bug). Direct file fetches and `_index.json` recall work immediately. During the warm-up window, recall automatically falls back to index files."* See [references/operational-notes.md Note 3](references/operational-notes.md).

If template creation fails with 403 (user is Business+ but not admin OR token scope is stale), surface a two-option message:

1. *"Your Box plan supports metadata templates. If you recently upgraded your Box account, your OAuth token may be scoped to the old plan. Disconnect and reconnect the Box MCP in your platform's settings to get a fresh token, then re-run setup."* See [references/operational-notes.md Note 2](references/operational-notes.md).
2. *"If the current user is genuinely a non-admin on a Business+ account, have a Box admin create the `boxMemory` template (see [references/schema.md](references/schema.md)) or proceed with index-file mode."*

If `capabilities.custom_metadata_templates` is false (Personal tier), skip this step entirely. Recall via index files is the primary path on Personal.

**Note on alternate template names:** This skill creates the canonical `boxMemory` template. If you encounter a workspace where the live deployment uses a different name (e.g. `agentMemory`), the plugin honors whatever `metadata_template_key` is set in `_box-memory.json` — you don't have to migrate immediately. See [references/operational-notes.md Note 6](references/operational-notes.md) for migration guidance.

### Step 8 — Write a workspace README

Upload `README.md` to the workspace root with a brief orientation for humans who open the folder directly in Box:

```markdown
# <workspace-name>

This is a box-memory workspace — an agent-managed memory + file store on Box.

- `memories/` — markdown memory files written by AI agents (one file per memory)
- `files/` — binary files (PDFs, CAD, Office docs, etc.) referenced by memories
- `companions/` — markdown descriptions paired with each binary file (or sibling layout — see `_box-memory.json` settings)
- `teams/` — multi-team isolation; each team subfolder is permission-scoped via Box ACLs
- `_box-memory.json` — workspace config (tier, capabilities, settings)
- `_index.json` (per folder) — fast-lookup index of memory metadata; do not edit by hand

Tier: <tier>
Capabilities: <one-line summary>

Plugin: https://github.com/mrdulasolutions/BOX

Do not delete `_box-memory.json` or `_index.json` files — they are required for plugin operation.
```

### Step 9 — Report to the user

Output a clear summary:

```
✓ box-memory workspace created.

Name:     <workspace-name>
Root:     <Box folder path, with link if MCP returns one>
Tier:     <tier>
Teams:    [<list>]
Layout:   <sibling | folder>

Capabilities:
- Custom metadata templates: <yes/no>
- Body full-text search:     <yes/no>
- Max file size:             <N> MB
- Retention / legal hold:    <yes/no>
- Compliance (declared):     <list or none>

Routing:
- Memory recall:    <Metadata Query API | index files>
- File companions:  <metadata + frontmatter | frontmatter only>

Next steps:
1. Save a memory:  "Remember that <thing>" or /box-write
2. Recall:         "What do I know about <topic>" or /box-recall <query>
3. Add a team:     /box-team-isolate <team-name>
4. Status check:   /box-status
```

## Idempotency

Running setup again with the same name should be safe:

- Folder already exists → re-use, don't recreate.
- `_box-memory.json` already exists → don't overwrite without user confirmation.
- `_index.json` already exists → preserve. Don't reset entry counts.
- Metadata template already exists → re-use, don't recreate.

If the user explicitly asks to *re-initialize from scratch*, confirm twice before any destructive action and never delete memory files (only config files can be regenerated).

## Errors to surface clearly

- **Box MCP not connected** → see `box-tier-detect`.
- **Permission denied on parent folder** → "Choose a different parent folder or get write access."
- **409 conflict on workspace folder name** → "Pick a different name or use the existing folder."
- **Metadata template create 403 (Business+)** → Surface the admin-required message above; proceed with index-only mode.

## Don't

- Don't create a workspace at Box root unless explicitly asked. Default parent should be Box root only if the user agrees; otherwise ask.
- Don't write memory files in setup. Setup is structure only.
- Don't fail because tier detection was ambiguous. Use the lowest-common-denominator path and proceed.

## References

- `references/schema.md` — the canonical config and index schemas
- `references/tier-matrix.md` — what tier-specific features mean
- `references/architecture.md` — why this layout
