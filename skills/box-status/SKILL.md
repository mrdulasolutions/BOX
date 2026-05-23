---
name: box-status
description: Report the box-memory workspace status - tier, capabilities, teams, memory counts, index health, recent activity. Invoke when the user asks "what's in my Box workspace", "show workspace status", "how many memories do I have", "what tier am I on", "is the index healthy", or runs /box-status. Read-only - does not modify the workspace.
---

# box-status

You produce a human-readable snapshot of a box-memory workspace. Read-only — no writes, no rebuilds, no template changes. Use this as a sanity check before heavy operations, as an audit summary, or just to remind the user what's there.

## When you fire

- User runs `/box-status` or asks about workspace state.
- User asks "what's in my Box memory", "how many memories", "what's the tier", "is the index healthy".
- Another skill needs a quick snapshot to decide whether to proceed (e.g., before a bulk recall).
- Pre-flight check before a destructive or expensive operation.

## Inputs

- **Workspace** — must exist. If not, report that fact (don't error; suggest `/box-init`).
- **Optional flags** (parse from the user's invocation):
  - `--refresh-tier` → force `box-tier-detect` to re-probe before reporting.
  - `--check-indexes` → for each per-folder index, compare its `updated_at` to the folder's `modified_at` and flag drift suspicions. Does NOT rebuild — that's `box-index-rebuild`.
  - `--team=<name>` → scope stats to a specific team's subtree.

## What you do

### Step 1 — Read workspace config

Read `_box-memory.json` from the workspace root. If missing, output:

> No box-memory workspace found at this Box location. Run `/box-init` to create one.

Don't error; this is informational.

If `--refresh-tier` was passed, call the `box-tier-detect` skill to re-probe and update the cached values before continuing.

### Step 2 — Read the workspace-root rollup index

Read `_index.json` at the workspace root. This gives you total entry counts and an overview without having to walk every folder.

If the rollup is missing or older than 24h, optionally walk the per-folder indexes for accurate counts. Note in the report if the rollup is stale.

### Step 3 — Per-team stats

For each team in `_box-memory.json.teams[]`:

1. Read the team's `memories/_index.json` (and `companions/_index.json` if folder layout).
2. Count entries by status and kind.
3. If the team folder is inaccessible (403), mark it `🔒 access denied` and continue with other teams. Don't fail.

If `--team=<name>` was passed, only that team's stats.

### Step 4 — Index health (optional, only if `--check-indexes`)

For each per-folder index:

1. Get the index's `updated_at` from the index file.
2. Get the folder's `modified_at` from Box's folder metadata.
3. If folder was modified after the index was last updated → flag as suspicious.

Don't rebuild — list suspect folders and suggest `/box-index-rebuild [folder]`.

### Step 5 — Compose the report

```
box-memory workspace: <workspace-name>

Root:          <Box folder path or link>
Created:       <ISO>
Updated:       <ISO>
Schema:        v<schema_version>
Plugin:        v<plugin_version>

Account:
  Tier:                       <tier>
  Tier detected:              <ISO>
  Custom metadata templates:  <yes/no>
  Body full-text search:      <yes/no>
  Max file size:              <N> MB
  Storage:                    <used> / <total or "unlimited">
  Box Sign:                   <yes/no>
  Retention policies:         <yes/no>
  Legal holds:                <yes/no>
  Compliance (declared):      <list or "none declared">

Routing:
  Memory recall:              <Metadata Query API | index files>
  File companions:            <metadata + frontmatter | frontmatter only>

Workspace contents:
  Total memories:    <N>
    active:            <n>
    draft:             <n>
    superseded:        <n>
    archived:          <n>
  By kind:
    decision:          <n>
    fact:              <n>
    task:              <n>
    observation:       <n>
    reference:         <n>
    note:              <n>
    companion:         <n>
  Total binary files: <N>
  Companions:         <N>

Teams:
  default          <N> memories, <N> files
  <other teams>    ...

Index health:
  Per-folder indexes:  <N>
  Last index update:   <ISO>
  Drift suspected:     <none | list of folders>     (only if --check-indexes)

Most recent memories:
  - <title> (<kind>, <updated_at>, <team>)
  - ...    (up to 5)

Top tags:
  <tag>: <count>
  ...      (up to 5)

Settings:
  Default team:              <name>
  Companion layout:          <sibling | folder>
  Include superseded:        <yes/no>
  Auto-rebuild on drift:     <yes/no>

Next steps if useful:
  /box-write             save a new memory
  /box-recall <query>    look something up
  /box-companion <id>    describe a binary
  /box-team ls           list teams
  /box-index-rebuild     refresh indexes
```

Trim sections that are empty or not relevant. Use `--team=<name>` to keep the team section focused.

### Step 6 — Flag actionable issues

If you detected anything that warrants action, surface it at the end:

- Drift suspected (from `--check-indexes`): `→ Run /box-index-rebuild <folder>`.
- Tier mismatch with cached value: `→ Run /box-status --refresh-tier`.
- Stale OAuth token symptoms: see [references/operational-notes.md Note 2](references/operational-notes.md).
- Compliance certifications not declared but capabilities suggest a paid tier: `→ Declare in _box-memory.json under capabilities.compliance`.

## Errors to surface clearly

- **Box MCP not connected** → standard MCP message; see `box-tier-detect`.
- **Permission denied reading workspace root** → "Can't read `_box-memory.json`. Check Box folder permissions on the workspace root."
- **Workspace partially accessible** → list which folders failed, continue with the rest.

## Don't

- Don't modify anything. Status is read-only.
- Don't trigger a tier re-probe unless `--refresh-tier` was explicitly asked — the cached value is usually fine for status purposes.
- Don't rebuild indexes during status. If drift is suspected, surface it and suggest `box-index-rebuild`.
- Don't load every memory's full content. Index entries are enough for a status report.

## References

- `references/schema.md` — workspace config and index schemas
- `references/tier-matrix.md` — capability matrix
- `references/operational-notes.md` — diagnostic hints when something looks off
