---
name: box-index-rebuild
description: Rebuild a folder's _index.json (or the workspace-root rollup) from scratch by listing the folder and re-reading every memory's frontmatter. Also detects stale file companions whose hash no longer matches the binary. Use when an index is suspected stale, drifted, corrupted, or after a bulk Box-side change like manual file upload, deletion, or version replace.
argument-hint: "[<folder-path>] [--check] [--companions-only] [--team=<name>]"
---

# /box-index-rebuild

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Scan folders, re-read memory frontmatter, write fresh `_index.json` files. The source of truth is always the memory files; the index is derived state. Rebuilding from source is always safe.

## Usage

```
/box-index-rebuild [<folder-path>] [--check] [--companions-only] [--team=<name>]
```

Examples:
- `/box-index-rebuild` — rebuild every per-folder index + the rollup
- `/box-index-rebuild memories/` — rebuild just one folder
- `/box-index-rebuild --check` — diagnostic only, don't write
- `/box-index-rebuild --companions-only` — only check companion hash freshness
- `/box-index-rebuild --team=engineering` — rebuild one team's subtree

## What to do

1. **Verify workspace** (`_box-memory.json`). Determine scope: workspace-wide, folder-scoped, or team-scoped.
2. **List target folder.** Via Box MCP, capture every file's `file_id`, `filename`, `size`, `modified_at`, `sha1`.
3. **Parse memory files.** For each `*.md` (excluding `README.md` and `_*.json`): fetch content, parse YAML frontmatter, extract id/slug/title/kind/status/team/tags/related/companion_for/sha256/created_at/updated_at. If frontmatter is malformed, capture in "orphans" list — don't drop.
4. **Build entry list + inverted maps** (`by_id`, `by_slug`, `by_wikilink`, `by_kind`, `by_tag`, `by_status`, `by_companion_for`).
5. **Detect collisions.** Same `id` across two files = error. Same `slug` across two `status: active` memories = conflict. Surface both.
6. **Companion staleness check.** For each `kind: companion`: fetch binary's current Box SHA1. If different from companion's stored hash, mark `stale: true` and add to `stale_companions[]` report. If binary was deleted, mark `orphaned: true`.
7. **Write new `_index.json`** as a new version (Box keeps history). Bump `updated_at`. Skip this step if `--check`.
8. **Rebuild rollup.** After all per-folder indexes are fresh, read each, aggregate into workspace-root `_index.json`, rebuild rollup inverted maps.
9. **Report.** Folders processed, memories/companions indexed, issues found (stale, orphan, frontmatter errors, collisions). For each issue, give the resolution next step.

## Check mode

`--check` does the same scan but doesn't write. Compares what rebuild WOULD produce vs current `_index.json`. Reports drift: entries in current that source doesn't have (deleted files), entries in source missing from current (added files), entries with differing frontmatter (modified files).

## Don't

- Don't modify memory files during rebuild. The index is derived; sources are authoritative.
- Don't delete orphan or frontmatter-error files — surface them; user decides.
- Don't rebuild silently if non-trivial drift exists. Report what changed.
- Don't trust Box Search to find missing memories — it lags 10+ min. Folder listing is canonical.

## Performance

- One Box GET per file. 200 memories → ~200 GETs. For 1000+ memory workspaces, batch by folder.
- Rollup-only rebuild is much cheaper than full rebuild.

## Deep reference

For the full scan algorithm, companion-staleness logic, check-mode drift detection, and large-workspace batching:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-index-rebuild-detail.md
- Schema (index structure, frontmatter): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Architecture (derived state vs source state): https://github.com/mrdulasolutions/BOX/blob/main/references/architecture.md
- Operational notes: https://github.com/mrdulasolutions/BOX/blob/main/references/operational-notes.md
