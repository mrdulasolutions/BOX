# box-memory

**Use Box.com as agent memory + file storage. For any AI agent.**

A skill bundle that turns any Box account into a durable, multi-team, audit-friendly memory substrate. Ships in three forms so any agent can use it:

- **Claude Code plugin** — one git clone, all skills and `/box-*` commands available.
- **Claude Cowork skills** — per-skill `.zip` artifacts, uploaded individually via Cowork's skill settings.
- **Generic skills bundle** — point any agent (Codex, Cursor, OpenClaw, custom SDKs) at the skill directories; each `SKILL.md` is self-contained.

Markdown memories with YAML frontmatter and Obsidian-style wikilinks. Every binary file gets a paired companion `.md` so agents can recall what a file is *without* chunking it into a vector store. Instant lookup via per-folder index files (works on every Box tier) or Box metadata templates (Business+).

---

## Why Box for agent memory?

Most agent-memory tools (Obsidian + sync, Mem0, Supermemory, OpenAI Memories) chop your files into RAG chunks and approximate retrieval. That's fine for chat but wrong for anything regulated. Box gives you:

- **Real file storage** — binaries are first-class, not "context the embedding sort-of remembers"
- **Compliance certifications on Business+ and Enterprise tiers** — SOC 2, HIPAA BAA, FedRAMP Moderate/High, DISA IL4, ITAR alignment
- **Audit-grade provenance** — every file has an immutable ID, version history, sha1 hash, and (on Enterprise) retention/legal-hold
- **Native file previews** — including CAD (DWG, DXF, RVT), Office docs, PDFs — without RAG
- **Folder ACLs** for genuine multi-team isolation

The plugin adds the agent-memory layer on top: schema, index, companions, recall.

---

## What this plugin gives you

| Capability | How it works | Works on |
|---|---|---|
| **Memory write** | Markdown + YAML frontmatter + Obsidian-style `[[wikilinks]]`. Append-only by design. | All tiers |
| **Memory recall** | Multi-strategy: metadata query (Business+) → index file → folder listing → search (fallback). Sub-second on every tier. | All tiers |
| **File companions** | Every binary gets a paired `.md` describing what it is, hash, classification, links. Agents never chunk files. | All tiers |
| **Index files** | Per-folder `_index.json` mapping title/slug/tag/wikilink → file ID. Sidesteps Box's 10-min search indexing lag. | All tiers |
| **Metadata templates** | Optional. On Business+, frontmatter fields are promoted to Box metadata for SQL-like queries. | Business+ |
| **Multi-team isolation** | Folder-ACL-based. Each team gets its own subtree with its own index. | All tiers |

---

## Installation

Three install paths cover Claude Code, Claude Cowork, and any other agent platform. Pick the one that fits.

### Prerequisites (all paths)

1. **A Box account** — any tier. The bundle auto-detects capabilities and routes accordingly.
2. **A Box MCP server connected to your agent** — the skills invoke Box MCP tools under the hood; they do not manage Box auth themselves. Available out of the box on Claude Code and Cowork; for other platforms, point your agent at any Box MCP server (e.g., `@anthropic/box-mcp` or your own Box API wrapper).

### Path 1 — Claude Code (plugin)

```bash
git clone https://github.com/mrdulasolutions/BOX.git ~/.claude/plugins/box-memory
```

Or install from a downloaded zip:

```bash
curl -L -o /tmp/box-memory-plugin.zip \
  https://github.com/mrdulasolutions/BOX/releases/latest/download/box-memory-plugin.zip
unzip /tmp/box-memory-plugin.zip -d ~/.claude/plugins/
```

After install, the seven skills and `/box-*` slash commands are available in Claude Code.

### Path 2 — Claude Cowork (per-skill zips)

Cowork accepts skills as individual `.zip` files. The build produces one zip per skill — upload only the skills you want.

```bash
# Build the skill zips locally
git clone https://github.com/mrdulasolutions/BOX.git
cd BOX
./scripts/build.sh

# Skill zips land in dist/skills/
ls dist/skills/
# → box-setup.zip, box-tier-detect.zip, box-memory-write.zip,
#   box-memory-recall.zip, box-file-companion.zip,
#   box-team-isolate.zip, box-index-rebuild.zip
```

Or download pre-built zips from the [latest release](https://github.com/mrdulasolutions/BOX/releases/latest). Then in Cowork, go to **Settings → Skills → Upload Skill** and drop each `.zip` you want.

Slash commands aren't supported in Cowork — only skills. The skills auto-fire when the user asks something matching their `description` field, so you usually don't need commands.

### Path 3 — Any other agent (Codex, Cursor, OpenClaw, custom SDK)

Each skill is a self-contained directory: `SKILL.md` + `references/` + `examples/`. Any agent that can read `SKILL.md` and follow its instructions can use these skills.

```bash
git clone https://github.com/mrdulasolutions/BOX.git
# Point your agent at the skill directories:
ls skills/
# → box-setup/  box-memory-write/  box-memory-recall/  box-file-companion/
#   box-team-isolate/  box-tier-detect/  box-index-rebuild/
```

The Anthropic Skills SDK and most agent frameworks accept this format directly. If your platform uses a different skill convention, the SKILL.md content is plain markdown instructions you can adapt or prepend to your system prompt.

### Building from source

```bash
./scripts/build.sh              # build plugin zip + all skill zips
./scripts/build.sh --check      # verify per-skill refs match canonical (no zip)
./scripts/build.sh --sync       # force-sync canonical refs into skills, then build
```

Outputs land in `dist/`:

```
dist/
├── box-memory-plugin.zip       # full Claude Code plugin
└── skills/
    ├── box-setup.zip           # individual skill, Cowork-uploadable
    ├── box-tier-detect.zip
    ├── box-memory-write.zip
    ├── box-memory-recall.zip
    ├── box-file-companion.zip
    ├── box-team-isolate.zip
    └── box-index-rebuild.zip
```

---

## Quick start

**Claude Code:**

```text
/box-init my-workspace
```

**Cowork or any other agent** — just ask in natural language:

> *"Set up a Box memory workspace called my-workspace."*

The `box-setup` skill fires from its description. Same result either way:

1. Probes your Box account to detect tier and capabilities
2. Creates a workspace folder structure (`memories/`, `files/`, `companions/`, `teams/`)
3. Writes `_box-memory.json` (workspace config)
4. Writes initial `_index.json` files
5. On Business+, creates a metadata template for instant queries

Then just talk to your agent:

> *"Remember that we decided to use JWT instead of sessions because of mobile."*

The `box-memory-write` skill fires, generates a memory file with frontmatter, uploads to Box, updates the index.

> *"What did we decide about auth?"*

The `box-memory-recall` skill fires, reads the index, returns the memory instantly.

> *"Take a look at this PDF and remember what it is."*

The `box-file-companion` skill fires, generates a paired `.md` with the file's hash, summary, and links.

---

## Box tier matrix — what you get where

| Feature | Personal / Free | Business | Enterprise | Enterprise Plus |
|---|---|---|---|---|
| Max file size | 250 MB | 5 GB | 50 GB | 500 GB |
| Storage | 10 GB | 100 GB | Unlimited | Unlimited |
| Filename + metadata search | ✅ | ✅ | ✅ | ✅ |
| Full-text body search (≤10 KB/doc) | ❌ | ✅ | ✅ | ✅ |
| **Custom metadata templates** | ❌ | ✅ | ✅ | ✅ |
| **Metadata Query API (instant, no lag)** | ❌ | ✅ | ✅ | ✅ |
| Box Sign | ❌ | ✅ | ✅ | ✅ |
| Retention policies & legal holds | ❌ | ❌ | ✅ | ✅ |
| Native CAD preview | Limited | ✅ | ✅ | ✅ |
| SOC 1/2/3 | ❌ | ✅ | ✅ | ✅ |
| HIPAA BAA | ❌ | ❌ | ✅ | ✅ |
| FedRAMP Moderate | ❌ | ❌ | ✅ | ✅ |
| FedRAMP High / DoD IL4 / ITAR | ❌ | ❌ | Add-on | ✅ |

**Universal caveat (all tiers):** Box's search API has a ~10 minute indexing lag. Direct file/folder ID lookups are instant. This plugin maintains per-folder index files specifically to sidestep this lag.

See [references/tier-matrix.md](references/tier-matrix.md) for the long version.

---

## Architecture

```
<workspace-root>/
├── _box-memory.json          # workspace config (tier, schema version, capabilities)
├── _index.json               # workspace-wide rollup
├── memories/                 # default scope
│   ├── _index.json           # per-folder index
│   └── *.md                  # memory files (one per memory)
├── files/                    # binary uploads
│   ├── _index.json
│   └── *
├── companions/               # paired .md for each binary (or sibling layout)
│   └── *.md
└── teams/                    # multi-team (optional)
    └── <team-name>/
        ├── _index.json
        ├── memories/
        ├── files/
        └── companions/
```

See [references/architecture.md](references/architecture.md) for the full design rationale.

---

## Schemas

**Memory file** (`memories/<kind>__<slug>.md`):

```markdown
---
id: mem_01HXYZ...                  # ULID
slug: jwt-vs-sessions-decision     # kebab-case, stable, used in filename
title: JWT vs Sessions Decision    # human-readable
kind: decision                     # decision | fact | task | observation | reference | note | companion
status: active                     # active | draft | superseded | archived
team: default                      # team scope
agent: claude-code                 # who wrote this
created_at: 2026-05-22T18:32:00Z
updated_at: 2026-05-22T18:32:00Z
confidence: 0.9
tags: [auth, mobile, security]
related:
  - "[[Login Flow]]"
  - "[[Session Management]]"
links:
  - url: https://example.com/rfc
    label: RFC 7519 (JWT)
---

# JWT vs Sessions Decision

Body of the memory…
```

**Companion file** (`companions/<filename>.md` or sibling `<filename>.<ext>.md`):

```markdown
---
id: mem_01HXYZ...
slug: turbine-blade-drawing-companion
title: Companion — turbine-blade-rev3.dwg
kind: companion
status: active
companion_for:
  file_id: "2241144661879"          # Box file ID
  filename: turbine-blade-rev3.dwg
  sha256: f3a9...c821               # at review time
  size_bytes: 47829312
  reviewed_at: 2026-05-22T18:32:00Z
  reviewed_by: claude-code
tags: [cad, drawing]
related:
  - "[[Material Spec — Inconel 718]]"
---

# Companion — turbine-blade-rev3.dwg

## What's in this file
Turbine blade root assembly, rev 3. AutoCAD 2024 format…

## Hash chain
If the binary's current sha256 differs, this companion is stale.
```

**Index** (`<folder>/_index.json`):

```json
{
  "version": 1,
  "folder_id": "12345...",
  "folder_path": "memories/",
  "updated_at": "2026-05-22T18:32:00Z",
  "tier": "personal",
  "entries": [
    {
      "id": "mem_01HXYZ...",
      "file_id": "234...",
      "filename": "decision__jwt-vs-sessions-decision.md",
      "title": "JWT vs Sessions Decision",
      "slug": "jwt-vs-sessions-decision",
      "kind": "decision",
      "status": "active",
      "tags": ["auth", "mobile", "security"],
      "related": ["[[Login Flow]]", "[[Session Management]]"],
      "companion_for": null,
      "sha256": null,
      "updated_at": "2026-05-22T18:32:00Z"
    }
  ],
  "by_tag": {"auth": ["mem_01HXYZ..."]},
  "by_kind": {"decision": ["mem_01HXYZ..."]},
  "by_wikilink": {"JWT vs Sessions Decision": "mem_01HXYZ..."}
}
```

See [references/schema.md](references/schema.md) for the full reference.

---

## Slash commands (Claude Code only)

Cowork doesn't support slash commands — skills auto-fire from their `description`. These commands are convenience wrappers for Claude Code users who prefer explicit invocation.

| Command | What it does |
|---|---|
| `/box-init [workspace-name]` | Bootstrap a workspace |
| `/box-write` | Force a memory write from current context |
| `/box-recall <query>` | Recall memories matching a query |
| `/box-companion <file-id-or-path>` | Generate a companion `.md` for a binary |
| `/box-status` | Show tier, capabilities, workspace stats |
| `/box-team <subcommand>` | Multi-team management (create, list, inspect, conflicts) |
| `/box-index-rebuild` | Regenerate indexes from source memory files |

---

## Skills (auto-invoked, all platforms)

| Skill | When it fires |
|---|---|
| `box-setup` | First-time workspace setup, or when no workspace is found |
| `box-tier-detect` | Internal — runs once per workspace, caches result |
| `box-memory-write` | User asks to save, remember, log, or record something |
| `box-memory-recall` | User asks "what do I know about…", "did we decide…", etc. |
| `box-file-companion` | A binary is referenced and needs a companion |
| `box-team-isolate` | User mentions a team scope or a multi-team workflow |
| `box-index-rebuild` | Index drift detected, or user asks to rebuild |

---

## Design principles

1. **No chunking, no embeddings.** Files stay whole. Agents write companion `.md` files to describe binaries.
2. **Append-only memories.** Don't overwrite. Mark old memories `superseded` and write a new one with `related: ["[[old title]]"]`.
3. **Box IDs are the only reliable identifiers.** Filenames change, wikilinks rot, but file IDs are forever. The index is the source of truth for ID lookup.
4. **Tier-aware, never tier-gated.** Every feature has a path on every tier — Business+ just gets a faster path.
5. **Folder ACLs are the real isolation boundary.** Frontmatter `team:` is a hint; folder permissions are enforcement.

See [references/architecture.md](references/architecture.md).

---

## Limits and known issues

- **Box search indexing lag (~10 min)** affects all tiers. The plugin's index file pattern sidesteps this. Don't rely on Box search for fresh writes.
- **Wikilinks are not validated by Box.** Rename a file → links in other memories silently break. The plugin maintains a `by_wikilink` map in the index; recall uses it.
- **Custom metadata templates require Business+.** On Personal, fall back to index files (same recall API, slightly slower writes).
- **Box MCP must be installed and authorized** in your agent platform's MCP configuration (Claude Code, Cowork, or your own setup). The skills do not handle Box auth.

---

## Roadmap

- [ ] v0.2: Wikilink integrity checker (find dead `[[links]]` across workspace)
- [ ] v0.2: Session-start hook to surface recent memories
- [ ] v0.3: Optional MCP server build of the same primitives (for non-Claude agents)
- [ ] v0.3: Standalone CLI for batch operations
- [ ] v0.4: Box Sign integration for decision attestations
- [ ] v0.4: Retention/legal-hold helpers (Enterprise)

---

## License

MIT. See [LICENSE](LICENSE).
