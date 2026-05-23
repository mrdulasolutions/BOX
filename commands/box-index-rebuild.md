---
description: Rebuild a folder's _index.json (or the whole workspace) from source memory files; also detects stale companions
argument-hint: "[<folder-path>] [--check] [--companions-only]"
---

# /box-index-rebuild

Refresh indexes by re-reading every memory's frontmatter and writing a fresh `_index.json`. Use when the index is suspected stale (manual Box edits, recall returning suspicious results, after bulk operations).

## What this command does

Invoke the `box-index-rebuild` skill. The skill will:

1. List the target folder(s).
2. Read each memory's frontmatter.
3. Rebuild the inverted maps (`by_id`, `by_slug`, `by_wikilink`, `by_kind`, `by_tag`, `by_status`, `by_companion_for`).
4. Detect companion staleness (binary hash differs from companion's recorded hash).
5. Detect orphan companions (binary deleted).
6. Detect ID and slug collisions.
7. Write the new index as a new version of the existing `_index.json`.
8. Refresh the workspace-root rollup.

## Argument handling

- **No arguments** → rebuild every per-folder index plus the rollup.
- **First positional argument** → rebuild a specific folder only. Example: `/box-index-rebuild memories/`.
- **`--check`** → diagnostic mode. Compute what the rebuild would change without writing. Useful as a pre-flight.
- **`--companions-only`** → only check companion freshness against current binary hashes; skip the index rewrite.
- **`--team=<name>`** → rebuild a specific team's subtree.

## Examples

- `/box-index-rebuild` → full workspace rebuild.
- `/box-index-rebuild --check` → see what would change without committing.
- `/box-index-rebuild teams/engineering/` → just engineering's subtree.
- `/box-index-rebuild --companions-only` → catch stale companions only.

## Invocation

Pass parsed arguments to `box-index-rebuild`. Surface the report including issue counts and per-issue details.

## When issues are found

The skill surfaces actionable next steps (regenerate companion, fix frontmatter, etc.). Pass them through verbatim.

## Errors

- **Permission denied on a folder** → skipped, continue with accessible folders.
- **No workspace** → run `/box-init`.
