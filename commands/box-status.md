---
description: Show box-memory workspace status — tier, capabilities, teams, memory counts, index health
argument-hint: "[--refresh-tier]"
---

# /box-status

Print a snapshot of the box-memory workspace. Use it as a sanity check, an audit summary, or a pre-flight before a heavy operation.

## What this command does

Read `_box-memory.json` and the workspace-root rollup `_index.json`. Optionally re-detect tier. Produce a human-readable summary.

## Argument handling

- **No arguments** → standard status report (cached tier info).
- **`--refresh-tier`** → force `box-tier-detect` to re-probe and update `_box-memory.json`.
- **`--check-indexes`** → for each per-folder index, compare its `updated_at` to the folder's `modified_at`; surface drift suspicions. Doesn't rebuild — use `/box-index-rebuild` for that.
- **`--team=<name>`** → show stats for a specific team only.

## What to output

```
box-memory workspace: <workspace-name>

Root:          <Box folder path / link>
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
  Storage:                    <used> / <total or unlimited>
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
  Drift suspected:     <none | list of folders>

Most recent memories:
  - <title> (<kind>, <updated_at>, <team>)
  - ...

Top tags:
  <tag>: <count>
  ...

Settings:
  Default team:              <name>
  Companion layout:          <sibling | folder>
  Include superseded:        <yes/no>
  Auto-rebuild on drift:     <yes/no>

Next steps if useful:
  /box-write             save a new memory
  /box-recall <query>    look something up
  /box-companion <id>    describe a binary
  /box-team-isolate ls   list teams
  /box-index-rebuild     refresh indexes
```

If `--check-indexes` was set and drift was found, list the suspect folders and suggest `/box-index-rebuild [folder]`.

## When no workspace exists

Don't error. Surface:

> No box-memory workspace found at this Box account. Run `/box-init` to create one.

## Errors

- **Box MCP not connected** → standard MCP message.
- **Permission denied reading workspace root** → "Can't read `_box-memory.json`. Check Box folder permissions."
