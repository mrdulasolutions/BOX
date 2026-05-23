# Schema reference

Three file types live in a box-memory workspace: **memories**, **companions** (a special kind of memory), and **indexes**. Plus one workspace-level config. This document is the canonical reference; skills should follow it exactly.

---

## Memory file

Every memory is a markdown file with YAML frontmatter followed by free-form body content. Filename convention: `<kind>__<slug>.md` (double underscore separator).

### Frontmatter (required fields)

| Field | Type | Notes |
|---|---|---|
| `id` | string | Globally unique. ULID prefixed `mem_` (e.g. `mem_01HXYZA1B2C3D4E5F6G7H8J9K0`). Never changes. |
| `slug` | string | Kebab-case. Stable for the life of the memory. Used in the filename. Lowercase ASCII, hyphens only. |
| `title` | string | Plain English title. Used as the wikilink target — `[[title]]` must resolve to this memory. |
| `kind` | enum | One of: `decision`, `fact`, `task`, `observation`, `reference`, `note`, `companion`. See *Kinds* below. |
| `status` | enum | One of: `active`, `draft`, `superseded`, `archived`, `held`. |
| `created_at` | ISO-8601 datetime | UTC, with `Z` suffix. |
| `updated_at` | ISO-8601 datetime | UTC, with `Z` suffix. Update on every write. |

### Frontmatter (optional fields)

| Field | Type | Notes |
|---|---|---|
| `team` | string | Team scope. Defaults to `default`. Frontmatter is a hint; folder ACL is enforcement. |
| `agent` | string | Which agent wrote it (e.g. `claude-code`, `gpt-4`, `user`). |
| `confidence` | float | 0.0 – 1.0. How sure the agent is. |
| `tags` | array of strings | Flat tags. Lowercase, hyphen-separated. Nested tags allowed via `/` (e.g. `domain/auth`). |
| `related` | array of wikilink strings | `["[[Other Memory Title]]", "[[Another Title]]"]`. Targets are other memory `title` fields. |
| `links` | array of `{url, label}` objects | External URLs. |
| `sources` | array | Optional citations. Each entry is free-form object — at minimum `{type, ref}`. |
| `supersedes` | array of IDs | If this memory replaces older ones, list their IDs. The older ones should have `status: superseded`. |
| `superseded_by` | string ID | Set automatically when a newer memory supersedes this one. |
| `expires_at` | ISO-8601 datetime | For ephemeral memories (e.g. session-scoped). |

### Kinds

| Kind | Purpose |
|---|---|
| `decision` | A choice that was made, with reasoning. The most common kind in active projects. |
| `fact` | A static piece of knowledge — schema, config, address, ID. |
| `task` | Something to do. Status moves `draft` → `active` (in-progress) → `archived` (done). |
| `observation` | Something the agent noticed but isn't deciding on. |
| `reference` | A pointer — external URL, third-party doc, vendor capability. |
| `note` | Catch-all. Default if nothing fits. |
| `companion` | Special — paired with a binary. See *Companion file* below. |

### Statuses

| Status | Meaning |
|---|---|
| `active` | Live, in use. Default. |
| `draft` | Not finalized. Agents may skip in recall by default. |
| `superseded` | Replaced by a newer memory. Recall by default excludes these unless `include_superseded: true`. |
| `archived` | Done / obsolete. Hidden by default. |
| `held` | Legal hold (Enterprise tier). Cannot be modified or deleted. |

### Body

Free-form markdown. Conventional structure:

```markdown
# <title matching frontmatter title>

> One-line summary or callout.

## Context
…

## Decision (or Fact / Task / etc.)
…

## Why
…

## Related
- [[Other Memory]]
- [[Another One]]

## Open questions
- [ ] …
```

The wikilinks `[[Title]]` in the body do **not** need to match `related:` exactly — `related:` is the structured graph; in-body wikilinks are inline references.

---

## Companion file

A companion is a memory with `kind: companion` paired to a binary file. It describes what the binary is so agents can reason about it without chunking or embedding it.

Filename convention — two options:

- **Sibling layout** (recommended for small workspaces): `<original-filename>.md` next to the binary in the same folder. Example: `turbine-blade-rev3.dwg` and `turbine-blade-rev3.dwg.md` in the same folder.
- **Companion folder layout** (recommended when binaries and companions have different ACLs): all companions live in `companions/` with the convention `<original-filename>.md`.

### Extra frontmatter (required for `kind: companion`)

```yaml
companion_for:
  file_id: "<Box file ID>"          # the binary's Box file ID — primary key
  filename: "<original filename>"    # for human reference
  sha256: "<hash at review time>"    # captured when the companion was written
  size_bytes: <integer>
  mime_type: "<e.g. application/pdf>"
  reviewed_at: "<ISO-8601>"          # when the agent reviewed the file
  reviewed_by: "<agent name>"
  box_version_id: "<optional version ID>"  # pin to a specific Box version
```

### Body convention

```markdown
# Companion — <original filename>

## What's in this file
<plain-English description of contents>

## Key facts
- <whatever matters most for this file type>

## Classification / handling notes (if applicable)
- <retention, sensitivity, compliance tags>

## Related
- [[Other companions or memories]]

## Hash chain
File reviewed at `sha256:<hash>` on `<date>`. If the binary's current sha256 
differs, this companion is stale and must be regenerated.

## What the agent did NOT verify
- [ ] <known gaps>
```

### Why hash anchoring?

If the binary changes (new version uploaded), the companion's `sha256` no longer matches. The plugin's `box-index-rebuild` (or a future hook) can flag stale companions automatically. Without hash anchoring, you'd silently trust outdated descriptions.

Box returns sha1 by default on file metadata; the plugin computes sha256 by downloading the representation. Both are stored; sha256 is the canonical anchor.

---

## Index file

One per folder. JSON. Maintained on every write. The source of truth for instant lookup by ID, slug, title, kind, tag, or wikilink target — without hitting Box's lagged search API.

### Structure

```json
{
  "version": 1,
  "folder_id": "<Box folder ID>",
  "folder_path": "memories/",
  "updated_at": "<ISO-8601>",
  "tier": "personal | business | enterprise",
  "entry_count": <integer>,
  "entries": [
    {
      "id": "mem_…",
      "file_id": "<Box file ID>",
      "filename": "<filename in Box>",
      "title": "<memory title>",
      "slug": "<slug>",
      "kind": "<kind>",
      "status": "<status>",
      "team": "<team or null>",
      "tags": ["<tag>", "…"],
      "related": ["[[Title 1]]", "…"],
      "companion_for": "<file_id or null>",
      "sha256": "<hash or null>",
      "size_bytes": <integer>,
      "created_at": "<ISO-8601>",
      "updated_at": "<ISO-8601>"
    }
  ],
  "by_id": {
    "mem_…": <index in entries[] array>
  },
  "by_slug": {
    "<slug>": "mem_…"
  },
  "by_wikilink": {
    "<title>": "mem_…"
  },
  "by_kind": {
    "decision": ["mem_…", "mem_…"]
  },
  "by_tag": {
    "auth": ["mem_…"]
  },
  "by_status": {
    "active": ["mem_…"]
  },
  "by_companion_for": {
    "<file_id>": "mem_…"
  }
}
```

### Update rules

- **Every memory write updates the index of the folder containing the memory.** No exceptions.
- The index is read at the start of every recall operation. If `updated_at` is older than the folder's `modified_at` from Box, the index is stale and should be rebuilt (or recall falls back to listing + frontmatter parse).
- A workspace-wide rollup index lives at `<workspace-root>/_index.json` and aggregates entries from all folder indexes. Updated on a slower cadence (lazy: only when explicitly asked, or on `/box-status`).

### Read order

When looking up a memory, agents follow this order:

1. If a Box file ID is known, fetch directly (always instant).
2. Else read the relevant folder's `_index.json` and resolve via `by_id` / `by_slug` / `by_wikilink` / `by_tag`.
3. Else (cross-folder query): read the workspace-root rollup index.
4. Else (rollup stale or missing): list folders, read each `_index.json`.
5. Last resort: Box search (with warning: results may be 10+ min behind, body search Business+ only).

---

## Workspace config

One per workspace, at the workspace root: `_box-memory.json`.

```json
{
  "version": 1,
  "schema_version": 1,
  "workspace_name": "my-workspace",
  "workspace_root_id": "<Box folder ID>",
  "created_at": "<ISO-8601>",
  "updated_at": "<ISO-8601>",
  "tier": "personal | business | enterprise | enterprise_plus | unknown",
  "tier_detected_at": "<ISO-8601>",
  "capabilities": {
    "custom_metadata_templates": <bool>,
    "body_search": <bool>,
    "max_file_size_mb": <integer>,
    "storage_unlimited": <bool>,
    "box_sign": <bool>,
    "retention_policies": <bool>,
    "legal_holds": <bool>,
    "keysafe": <bool>,
    "compliance": ["soc2", "hipaa", "fedramp-moderate", "..."]
  },
  "metadata_template_key": "<key or null>",
  "teams": ["default", "engineering", "ops"],
  "agents": ["claude-code"],
  "settings": {
    "default_team": "default",
    "companion_layout": "sibling | folder",
    "include_superseded_in_recall": false,
    "rebuild_index_on_drift": true
  }
}
```

The plugin reads this once per session and caches it. Changes (new team, tier change) require a re-read; skills handle this.

---

## Box metadata template (Business+ only)

When custom metadata templates are available, the plugin can optionally promote frontmatter fields to Box metadata for query-by-metadata. Template definition:

```yaml
scope: enterprise
templateKey: boxMemory
displayName: box-memory
fields:
  - key: memory_id
    displayName: Memory ID
    type: string
  - key: slug
    displayName: Slug
    type: string
  - key: title
    displayName: Title
    type: string
  - key: kind
    displayName: Kind
    type: enum
    options: [decision, fact, task, observation, reference, note, companion]
  - key: status
    displayName: Status
    type: enum
    options: [active, draft, superseded, archived, held]
  - key: team
    displayName: Team
    type: string
  - key: agent
    displayName: Agent
    type: string
  - key: tags
    displayName: Tags
    type: multiSelect
    options: []  # populated dynamically; or use a string for free-form
  - key: companion_for_file_id
    displayName: Companion for file ID
    type: string
  - key: sha256
    displayName: SHA256 hash at review
    type: string
  - key: created_at
    displayName: Created
    type: date
  - key: updated_at
    displayName: Updated
    type: date
```

Once the template exists, every memory write also applies the template instance to the file, and recall can use the Metadata Query API for instant results (no 10-min lag, no body-size limit). The index file still gets maintained as a fallback and for cross-tier portability.

---

## ID generation

- **Memory IDs are ULIDs.** They sort lexicographically by creation time and are URL-safe. Prefix with `mem_`.
- **Slugs are derived from titles** by lowercasing, replacing non-alphanumerics with hyphens, collapsing runs, trimming.
- **Companion IDs follow the same scheme** but are reserved for companion-kind memories.

ULID generation can be done by the agent using current timestamp + random bytes. Format: `mem_<26-char Crockford base32>`.

---

## Conventions agents must follow

1. **Never reuse a memory ID.** New write → new ID, even if it supersedes an older memory.
2. **Update `updated_at` on every write.**
3. **Update the folder's `_index.json` on every write.**
4. **Set `status: superseded` and `superseded_by: <new_id>` on the old memory** when writing a replacement. Don't delete.
5. **Filename = `<kind>__<slug>.md`** with double underscore. Avoid collisions; if a slug exists, append `-2`, `-3`, etc.
6. **Companion filename = `<original-filename>.md`** (e.g. `report.pdf.md`).
7. **Wikilink target = the `title` field**, not the filename. Recall resolves wikilinks via the index's `by_wikilink` map.
