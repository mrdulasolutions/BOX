---
description: Generate a paired companion markdown for a binary file in Box — describes what's in the file, pinned to a SHA256 hash
argument-hint: "<file-id-or-path> [--team=<team>] [--tags=<comma-list>] [--force]"
---

# /box-companion

Create a companion `.md` for a binary file: PDF, CAD, Office doc, image, video, anything. The companion describes the file in agent-readable markdown without chunking or embedding it. It's the no-RAG alternative.

## What this command does

Invoke the `box-file-companion` skill with the user's arguments. The skill will:

1. Resolve the file (by Box ID or path).
2. Check if a companion already exists. If yes, verify hash freshness.
3. Compute SHA256 of the current binary.
4. Review the file (text extraction for documents, visual for images, etc.).
5. Generate companion markdown with frontmatter pinned to the hash.
6. Upload as sibling or to `companions/` folder per workspace layout.
7. Update the relevant `_index.json` with the companion entry and reverse pointer.
8. On Business+, apply the `boxMemory` metadata template (kind=companion, companion_for_file_id, sha256).

## Argument handling

- **First positional argument** → Box file ID (numeric, ≥10 digits) or path to the file (e.g., `files/report.pdf`). Required.
- **`--team=<name>`** → if the file is in a team subtree and the companion should land in the same team.
- **`--tags=<a,b,c>`** → extra tags beyond the auto-derived ones.
- **`--force`** → regenerate the companion even if hash matches (rarely needed).
- **`--check`** → only check if the existing companion is fresh; don't regenerate.

## Examples

- `/box-companion 2241144661879` → companion for that file ID.
- `/box-companion files/contract.pdf` → companion for the file at that path.
- `/box-companion 2241144661879 --check` → is the existing companion still current?
- `/box-companion 2241144661879 --tags=cad,turbine --team=engineering` → custom tags, team scope.

## Invocation

Pass parsed arguments to `box-file-companion`. Surface the skill's report including the companion's first ~500 chars.

## On hash mismatch

The skill will surface the difference and offer to regenerate. The old companion is marked `superseded`; a new one is written.

## On large or unreadable files

The skill produces an honest, sparse companion noting what couldn't be parsed. This is better than fabricating contents.

## Errors

- **File not found** → "Check the file ID or path."
- **No read access** → "Box ACLs deny access; check folder permissions."
- **No workspace** → run `/box-init` first.
