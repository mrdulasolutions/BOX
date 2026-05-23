---
description: Bootstrap a box-memory workspace on Box.com — folder structure, config, indexes, optional metadata template
argument-hint: "[workspace-name] [--team=<team>] [--parent=<folder-id>]"
---

# /box-init

Set up a fresh box-memory workspace on the user's Box account, or add structure to an existing workspace.

## What this command does

Invoke the `box-setup` skill with the user's arguments. The skill will:

1. Detect the Box account tier via `box-tier-detect`.
2. Create the workspace folder structure: `memories/`, `files/`, `companions/` (if folder layout), `teams/<default>/`.
3. Write `_box-memory.json` with the detected capabilities.
4. Seed `_index.json` files in every folder that holds memories.
5. On Business+ tier, optionally create the `boxMemory` metadata template.
6. Surface a confirmation with workspace path, tier, and capabilities.

## Argument handling

- **No arguments** → use defaults: workspace name `box-memory`, parent = Box root, single team `default`, sibling companion layout.
- **First positional argument** → workspace name. Example: `/box-init my-vault` → workspace named `my-vault`.
- **`--team=<name>`** → add an additional team beyond `default`. Example: `/box-init my-vault --team=engineering`.
- **`--parent=<folder-id>`** → create the workspace under a specific Box folder. Default is Box root (folder ID `0`).
- **`--layout=sibling|folder`** → companion layout. Default `sibling`.
- **`--reinit`** → force re-initialization (asks twice before overwriting `_box-memory.json`).

If arguments are ambiguous, ask once for clarification. If the user has an existing workspace, respect it — don't silently overwrite.

## Invocation

Pass the parsed arguments to `box-setup`. Surface the skill's report verbatim to the user.

## Errors

If the Box MCP is not connected, `box-setup` will surface the standard error message. Don't try to proceed without Box MCP.
