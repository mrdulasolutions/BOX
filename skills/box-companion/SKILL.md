---
name: box-companion
description: Generate a paired companion markdown file for a binary in Box. The companion describes what the file is - summary, key facts, classification, related memories - pinned to a specific version via SHA256 hash. This is the no-chunking, no-embedding alternative to RAG. Use when the user uploads a binary and asks to remember what it is, describe a file, make a companion, or review a PDF/CAD/Office document.
argument-hint: "<file-id-or-path> [--team=<team>] [--tags=<a,b,c>] [--force] [--check]"
---

# /box-companion

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Produce a markdown companion that describes a binary in Box. The binary stays whole — never chunked, never embedded. The companion is what agents read when they need to know what's in the file.

## Usage

```
/box-companion <file-id-or-path> [--team=<team>] [--tags=<a,b,c>] [--force] [--check]
```

Examples:
- `/box-companion 2241144661879` — companion by Box file ID
- `/box-companion files/contract.pdf` — companion by path
- `/box-companion 2241144661879 --check` — is the existing companion still current?

## What to do

1. **Resolve the file.** Given file ID or path, fetch its Box metadata: filename, size, sha1, mime type, parent folder ID.
2. **Check for existing companion.** Look up `by_companion_for[<file_id>]` in the relevant `_index.json`. If exists and current SHA matches the binary's, the companion is still valid — surface its content unless `--force`. If SHA differs, it's stale and needs regeneration.
3. **Compute SHA256.** Stream-hash the binary. For very large files (>100 MB) where streaming isn't available, fall back to Box's SHA1 with `hash_algo: sha1` in frontmatter.
4. **Review the file.** Use the best Box MCP representation for the file type:
   - PDF/DOCX/XLSX → fetch text representation
   - CAD/images → preview / multimodal description
   - Code/markdown → fetch raw content
   - Unknown → describe by filename + size; be explicit about what you couldn't parse
5. **Generate IDs.** Companion ID = ULID prefixed `mem_`. Slug from filename.
6. **Build frontmatter.** Include `kind: companion`, `companion_for: { file_id, filename, sha256, hash_algo, size_bytes, mime_type, reviewed_at, reviewed_by }`. If superseding stale companion, set `supersedes: [old-id]`.
7. **Compose body.** Sections: "What's in this file", "Key facts" (bulleted), "Structure" (page count / sheets / layers if relevant), "Classification / handling notes", "Related" (wikilinks), "Hash chain" (with current sha256), "What the agent did NOT verify" (be honest about gaps).
8. **Upload companion.** Sibling layout: `<original-filename>.md` next to binary. Folder layout: in `companions/` (or `teams/<team>/companions/`).
9. **(Business+) Apply metadata template** with `kind: companion`, `companion_for_file_id` = binary's file ID, `sha256` = stored hash. Enables reverse-lookup queries.
10. **Update folder's `_index.json`.** Entry with `companion_for` = binary's file ID, `sha256` = stored hash. Update `by_companion_for` map.
11. **Report.** Companion file ID, hash, first ~500 chars of body, and any stale-companion supersession.

## Be honest about what you couldn't read

A small honest companion ("this is a 50 MB CAD file; I cannot extract layer info from this format") beats a fabricated one. Always include a "What the agent did NOT verify" checklist.

## Errors to surface clearly

- **File not found** → check ID or path.
- **No read access** → Box ACLs deny; check folder permissions.
- **Preview unavailable for file type** → generate sparse companion noting the gap.

## Deep reference

For full companion frontmatter spec, hash-anchoring rationale, sibling vs folder layout tradeoffs, RAG-vs-companion design discussion, and file-type-specific review strategies:

- Detailed procedure: https://github.com/mrdulasolutions/BOX/blob/main/references/skills/box-companion-detail.md
- Schema (companion frontmatter): https://github.com/mrdulasolutions/BOX/blob/main/references/schema.md
- Architecture (why companions not RAG): https://github.com/mrdulasolutions/BOX/blob/main/references/architecture.md
