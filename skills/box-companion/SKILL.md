---
name: box-companion
description: Generate a paired companion markdown file for a binary file in Box. The companion describes what the file is - summary, key facts, classification, related memories - pinned to a specific version via SHA256 hash. This is the no-chunking, no-embedding alternative to RAG. Invoke when the user uploads a binary (PDF, CAD, image, Office doc, video) and asks to "remember what this is", "describe this file", "make a companion", "review this file", or when another skill needs companion context for a binary. Also fires when the user runs /box-companion.
---

# box-companion

You produce a markdown "companion" file that describes a binary file in Box. The binary stays whole — never chunked, never embedded. The companion is what agents read when they need to know what's in the file.

## Why companions instead of RAG

RAG-style chunking + embedding has known weaknesses for files where provenance matters: chunks lose context, retrieval is approximate, embeddings drift across model versions, and the original file becomes "metadata behind the index." A companion file is the opposite — exact, human-readable, audit-friendly, version-pinned via hash.

Tradeoff: you don't get free sub-document search across millions of pages. For that, fall back to Box's body full-text search (Business+, 10 KB cap). The companion is for the things an agent *actually understood* about the file when it last reviewed it.

## When you fire

- The user uploads or references a binary and asks you to remember/describe/review it.
- Another skill (often `box-write` when writing about a file) needs to ensure a companion exists first.
- The user runs `/box-companion <file-id-or-path>`.
- You're rebuilding companions after a binary changed (hash mismatch — see `box-index-rebuild`).

## Inputs

Required:

- **Box file ID** (preferred) or path to the binary.
- **Workspace** — must exist.

Optional:

- **Classification fields** — if the user has a domain-specific schema (e.g., export-control class, retention class), capture as additional frontmatter.
- **Force overwrite** — if a companion already exists and the user wants to replace.

## What you do

### Step 0 — Verify workspace, find file

Read `_box-memory.json`. Get the workspace's companion layout (`sibling` or `folder`).

Resolve the file: if given a Box file ID, fetch its metadata. If given a path, list the parent folder and find the file. Get:

- `file_id`
- `filename`
- `size`
- Box's stored `sha1` (for cross-check)
- Box's `modified_at`
- Mime type (from name extension if not exposed)
- Parent folder ID

### Step 1 — Check for existing companion

Compute the companion's expected location and filename:

- **Sibling layout:** same folder as the binary, filename = `<original-filename>.md` (so `report.pdf` → `report.pdf.md`).
- **Folder layout:** in `companions/` (workspace) or `teams/<team>/companions/` (team scope), filename = `<original-filename>.md`.

Look up the binary's `file_id` in the relevant `_index.json` under `by_companion_for`. If a companion exists:

- **Hash matches current binary** → companion is current. Surface the existing companion content and stop, unless the user asked to regenerate.
- **Hash mismatch** → companion is stale (the binary changed since last review). Continue to regenerate.
- **No companion** → continue to create one.

### Step 2 — Compute SHA256 of current binary

Box returns SHA1 by default but the canonical anchor in this plugin is SHA256.

Approach:
- Box MCP may expose a way to fetch the file's content / representation. Use the most lightweight representation (the binary itself).
- Stream-hash the bytes to compute SHA256. Don't load multi-GB files into memory; chunk-stream.
- For very large files (>100 MB), if streaming isn't available, fall back to using Box's SHA1 as the anchor with a frontmatter note that says so: `hash_algo: sha1` instead of `sha256`. This is acceptable for huge files.

Capture:
- `sha256` (or `sha1` if fallback)
- `size_bytes`

### Step 3 — Review the file

What "review" means depends on the file type. Use the most appropriate Box MCP capability:

| File type | Approach |
|---|---|
| `.pdf` | Fetch text representation (Box PDF preview API returns extracted text). Skim for structure: title, sections, page count. |
| `.docx`, `.doc` | Fetch text representation. Note headings, length, key sections. |
| `.xlsx`, `.csv` | Fetch text / structured representation. Note sheet names, column headers, row count. |
| `.md`, `.txt`, code files | Fetch raw content. Read directly. |
| `.dwg`, `.dxf`, `.rvt`, CAD | Box preview gives a thumbnail/representation. Note that text extraction is limited; companion should describe what the agent can infer from filename + preview + context. |
| Images (`.png`, `.jpg`, `.heic`, etc.) | Fetch image representation if multimodal; describe visually. |
| Video, audio | Limited — describe based on metadata (filename, duration, mime type). |
| Unknown / proprietary | Describe what's known (size, name, source) and explicitly note "agent did not parse contents". |

**Be honest about what you couldn't read.** A companion that says "this is a 50 MB CAD file; I cannot extract layer info from this format" is more useful than a companion that hallucinates technical details.

### Step 4 — Generate the companion ID

ULID, prefixed `mem_`. Slug: derive from the binary's filename — e.g., `report.pdf` → `report-pdf-companion`.

If a previous companion exists for this file and is being replaced because of hash mismatch:
- New companion gets a fresh ID.
- Old companion gets `status: superseded`, `superseded_by: <new-id>`. (See `box-write` Step 7.)

### Step 5 — Build frontmatter

```yaml
---
id: <mem_ULID>
slug: <derived-slug>
title: Companion — <original-filename>
kind: companion
status: active
team: <from context, default "default">
agent: <agent identifier>
created_at: <ISO now>
updated_at: <ISO now>
companion_for:
  file_id: "<Box file ID of the binary>"
  filename: <original filename>
  sha256: <hash>                       # or sha1 if fallback
  hash_algo: sha256                    # or sha1
  size_bytes: <int>
  mime_type: <mime>
  reviewed_at: <ISO now>
  reviewed_by: <agent identifier>
  box_version_id: <optional version ID if pinning>
tags: [companion, <file type tag like "pdf", "cad", "image", and any user-supplied tags>]
related:
  - "[[Other memory or companion]]"  # only if you've verified the target exists
supersedes: [<old-companion-id>]        # if regenerating after hash change
---
```

### Step 6 — Compose the body

```markdown
# Companion — <original-filename>

## What's in this file
<plain-English description of contents, 2-5 sentences>

## Key facts
- <bulleted list of the most important things to know about this file>
- <e.g. for a contract: parties, effective date, term, key clauses>
- <e.g. for a CAD drawing: assembly name, rev, key components>
- <e.g. for a spreadsheet: what each sheet is for, row count, key formulas>

## Structure
- <if applicable: TOC, sections, page count, layer count, sheet names>

## Classification / handling notes
<retention, sensitivity, compliance flags — if user provided or context implies>

## Related
- [[Other companions or memories]]

## Hash chain
File reviewed at `<hash_algo>:<hash>` on `<reviewed_at>`. If the binary's current 
hash differs, this companion is stale and should be regenerated.

## What the agent did NOT verify
- [ ] <known gaps — be honest>
- [ ] <e.g. "did not parse encrypted attachment", "preview did not include layers 47-92">

---

#companion #<file-type> #<other tags>
```

### Step 7 — Upload companion to Box

Determine the target folder:
- **Sibling layout:** same folder as the binary.
- **Folder layout:** `companions/` under workspace, or `teams/<team>/companions/` if team-scoped.

Filename: `<original-filename>.md`. If a collision exists (rare, but possible if you didn't catch existing companion in Step 1), regenerate the file as a new version of the existing companion file. Box keeps versions.

Capture the new `file_id`.

### Step 8 — (Business+) Apply metadata template instance

If `capabilities.custom_metadata_templates` is true:

Apply the `boxMemory` template instance to the companion file with:

- `memory_id` → frontmatter `id`
- `slug`, `title`, `kind` (= "companion"), `status`, `team`, `agent` → frontmatter values
- `tags` → comma-joined frontmatter `tags`
- `companion_for_file_id` → the **binary's** file ID
- `sha256` → frontmatter `companion_for.sha256`
- `created_at`, `updated_at` → frontmatter values

This makes the companion findable by Metadata Query API: *"Find all companions for file ID X"*, *"Find all companions whose hash doesn't match a stored value"*, etc.

### Step 9 — Update the folder's `_index.json`

Same pattern as `box-write` Step 11, with these companion-specific entries:

- Entry includes `companion_for: <binary's file ID>` (not null).
- Entry includes `sha256` from companion frontmatter.
- Index map `by_companion_for[<binary's file_id>]` → `<companion mem_id>`.

If superseding an old companion, also update the old companion's index entry (`status: superseded`, `superseded_by`).

### Step 10 — Update binary's reverse pointer

The binary itself doesn't get a companion .md file modification, but the index can capture the relationship in both directions. The folder's `_index.json` should have, for the binary:

- An entry (if not present already — bin files may not have index entries by default).
- A `companions: [<companion-id>]` array on the binary's entry (if you choose to track binaries in the index — optional but recommended for medium+ workspaces).

If you don't track binaries in the index, `by_companion_for` on the companion's side is sufficient.

### Step 11 — Report

```
✓ Companion created.

For file:        <original-filename> (Box ID: <file-id>)
Hash:            <hash_algo>:<hash>
Size:            <size_bytes / human-readable>
Companion:       <kind>__<slug>.md (Box ID: <companion file-id>)
Companion path:  <relative path>
Metadata:        <template applied | skipped — reason>

Companion content:
─────────────────
<first ~500 chars of body>
...
```

## Hash mismatch handling

If you detected a hash mismatch in Step 1:

1. Mention it explicitly: *"The existing companion was reviewed at sha256:abc… on <date>. The binary's current hash is sha256:xyz… — they differ, so the companion is stale."*
2. Show what the old companion said (one-line summary or first paragraph).
3. Generate the fresh companion via the rest of the steps.
4. Mark old companion as `superseded`.

If the user *just* wants to know "is the companion still accurate?" and not regenerate, the hash check answers that — surface the result and stop.

## Companion for a memory file?

If the user asks to companion a `.md` memory file (which is already in box-memory format), don't create a meta-companion. Instead, suggest:
- They edit the original memory via `box-write` if it needs updates.
- Or `/box-recall` it if they want to see what's there.

A companion *of* a memory is a category error in this system.

## Errors to surface clearly

- **File not found** → "No file at <id or path>. Check the ID or run `/box-status` to see workspace contents."
- **File too large to hash on this client** → Fall back to Box's SHA1 with a frontmatter note. Don't fail the companion.
- **Preview unavailable for file type** → Generate a sparse companion that captures filename, size, hash, and known context; explicitly note the agent couldn't read contents.
- **Permission denied on file** → "Can't read <file>. Check Box ACLs."

## Don't

- Don't chunk or embed the file. The whole point is to *not* do that.
- Don't hallucinate content you couldn't read. A small honest companion beats a large fabricated one.
- Don't skip the hash. The hash is what makes the companion auditable.
- Don't write the companion to a folder the binary isn't in (for sibling layout) — it'll be confusing in Box.

## References

- `references/schema.md` — companion frontmatter schema
- `references/architecture.md` — why companions, not RAG
