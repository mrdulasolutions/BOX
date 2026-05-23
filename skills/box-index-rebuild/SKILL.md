---
name: box-index-rebuild
description: Rebuild a folder's _index.json (or the workspace-root rollup) from scratch by listing the folder and re-reading every memory's frontmatter. Use when an index is suspected stale, drifted, corrupted, or after a bulk Box-side change (manual file upload, file deletion, version replace). Also detects stale file companions whose hash no longer matches the binary. Invoke when the user says "rebuild the index", "refresh the index", "fix the index", "check companion freshness", or runs /box-index-rebuild.
---

# box-index-rebuild

You scan a folder (or the whole workspace), re-read every memory/companion's frontmatter, and write a fresh `_index.json`. The source of truth is always the memory files themselves; the index is derived state. Rebuilding from source is always safe.

## When you fire

- Index is suspected stale (e.g., folder's `modified_at` is newer than index's `updated_at` by more than a write would explain).
- User uploaded or modified files directly in Box (outside the plugin).
- Recall returned suspicious results (missing memories the user knows exist).
- Companion hash mismatch detection — for a folder of companions, check each against its binary.
- User explicitly runs `/box-index-rebuild [<folder-path>]`.

## Inputs

- **Scope** — one folder, one team, or the whole workspace. Default: the workspace root rollup + every per-folder index.
- **Mode** — `rebuild` (regenerate from source, default) or `check` (compare current index to source without writing changes — for diagnostics).

## What you do

### Step 0 — Verify workspace

Read `_box-memory.json`. Determine scope.

### Step 1 — Determine target folders

- Workspace-wide rebuild: every folder containing `_index.json` (workspace `memories/`, all team `memories/`, all `companions/` folders, etc.).
- Folder-scoped rebuild: just that folder.
- The workspace-root rollup is rebuilt last, after per-folder indexes are fresh.

### Step 2 — For each target folder, scan and parse

1. List the folder's contents via Box MCP. Capture every file: `file_id`, `filename`, `size`, `modified_at`, `sha1` (Box provides).
2. Filter to memory files: `*.md` files, **excluding** `README.md` and `_*.json`.
3. For each memory file:
   - Fetch its content (markdown text).
   - Parse the YAML frontmatter (between `---` delimiters at the top).
   - Extract: `id`, `slug`, `title`, `kind`, `status`, `team`, `tags`, `related`, `companion_for` (if companion), `sha256` (if companion), `created_at`, `updated_at`.
   - If frontmatter is malformed (missing `id`, missing `kind`, no `---` delimiters), capture it in an "orphans" list with the problem. Don't drop silently.
4. Build the entry list in the new index, matching `references/schema.md`.

### Step 3 — Build inverted maps

For the rebuilt entries:

- `by_id[<mem_id>]` → entries array index
- `by_slug[<slug>]` → mem_id
- `by_wikilink[<title>]` → mem_id
- `by_kind[<kind>]` → [mem_id, …]
- `by_tag[<tag>]` → [mem_id, …]
- `by_status[<status>]` → [mem_id, …]
- `by_companion_for[<binary_file_id>]` → mem_id (companion entries)

**Detect ID collisions.** If two files have the same `id` (should never happen, but possible after manual editing), flag as a conflict in the orphans report.

**Detect slug collisions.** Same slug across two memories with `status: active` is a conflict; flag.

### Step 4 — Companion staleness check (optional, on companion folders)

For each companion entry in the index:

1. Find the binary: look up the file ID in `companion_for.file_id`.
2. Fetch the binary's current metadata. Compare the binary's current `sha1` to what Box stored at the time we wrote the companion (we store Box's SHA1 in addition to our SHA256 if available; if not, fall back to comparing modification times).
3. If different:
   - Mark the companion in the rebuilt index with `stale: true` (this is a transient flag, not part of the schema — clear it after the user acts).
   - Add to a `stale_companions[]` list in the rebuild report.

Companions whose binary has been deleted from Box → mark `orphaned: true` and surface separately.

### Step 5 — Write the new `_index.json`

Upload as a new version of the existing `_index.json` (preserves Box version history of the index). Bump `updated_at`.

If `_index.json` didn't exist (e.g., folder was created manually outside the plugin), create one.

### Step 6 — Update the workspace-root rollup

After all per-folder indexes are rebuilt:

1. Read each per-folder `_index.json`.
2. Aggregate entries into the rollup.
3. Rebuild the rollup's inverted maps.
4. Update `child_indexes[]` to reflect the current set of per-folder indexes.
5. Upload as new version of the workspace-root `_index.json`.

### Step 7 — Report

```
✓ Index rebuild complete.

Scope:       <workspace | folder | team>
Folders processed: <N>
Memories indexed:  <N>
Companions indexed: <N>
Time:        <approx>

Issues found:
  Stale companions:   <N>      (hash mismatch — binary changed since review)
  Orphan companions:  <N>      (binary deleted from Box)
  Frontmatter errors: <N>      (parse failures — see below)
  ID collisions:      <N>
  Slug collisions:    <N>

<details for each category if N > 0>
```

For each stale companion:

```
- companion: <filename> (id: <mem_…>)
  binary:     <binary filename> (file_id: <…>)
  reviewed:   <reviewed_at>
  stored sha: <hash>
  current sha: <hash>
  
  → Regenerate? /box-companion <binary file_id>
```

For each frontmatter error:

```
- file:   <filename> (file_id: <…>)
  error:  <e.g. "missing 'id' field", "no closing --- delimiter">
  
  → Open in Box and fix, or move to <_archive>/.
```

## Check mode (read-only diagnostic)

Same scan as rebuild, but instead of writing the new index:

- Compare entries the rebuild *would* produce against the current `_index.json`.
- Report drift:
  - Entries in current index that don't exist in source (deleted files).
  - Entries in source that aren't in current index (added files).
  - Entries where frontmatter doesn't match current index entry (modified files).
- Don't change anything.

Useful for "before I commit to a rebuild, what would change?"

## Performance

- Each file read is one Box GET. A workspace with 200 memories → ~200 GETs.
- For very large workspaces (1000+ memories), consider rebuilding folder-by-folder in batches.
- The rollup rebuild reads every per-folder index but not every memory file — it's much cheaper than the full rebuild.

## When to suggest a rebuild

After your work, if you detected drift or orphans, mention proactively:

```
Note: rebuild detected <N> issues. Resolve them before relying on recall for those memories.
```

If everything was clean, just say: *"No drift detected. Index is consistent with source."*

## Errors to surface clearly

- **Permission denied on a folder** → "Skipped folder `<path>` — no read access."
- **Frontmatter parse failure on a memory** → captured in report, doesn't fail the rebuild.
- **Cannot fetch a memory's content** → captured in report as "unreadable", doesn't fail the rebuild.

## Don't

- Don't modify memory files during rebuild. The index is derived; sources are authoritative.
- Don't delete files marked as orphan companions or frontmatter-error — they may be salvageable. Surface them; let the user decide.
- Don't rebuild silently if any non-trivial drift was found. Report what changed.
- Don't trust Box Search to find missing memories — it lags. The folder listing is the canonical source for "what exists in this folder right now".

## References

- `references/schema.md` — index schema
- `references/architecture.md` — derived state vs source state
- `skills/box-write` — the writer that's supposed to keep the index fresh
