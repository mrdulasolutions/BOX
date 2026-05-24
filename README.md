# box-memory

**Use Box.com as agent memory + file storage. For any AI agent.**

> **Looking for air-gapped / on-prem use?** See [`mrdulasolutions/BOX-Onprem`](https://github.com/mrdulasolutions/BOX-Onprem). It uses Box Drive's local filesystem mount instead of the Box API — no outbound network calls to Box from the agent runtime during skill execution. Same agent-memory model; different backend; intended for HIPAA / FedRAMP / ITAR workflows where the data path through Box must be air-gapped.

A skill bundle that turns any Box account into a durable, multi-team, audit-friendly memory substrate. Ships in four forms so any agent platform can use it:

- **Claude Code plugin** — git clone or unzip into `~/.claude/plugins/box-memory/`. All skills and `/box-*` commands available.
- **Claude Cowork plugin** (admin) — upload `box-memory-plugin.zip` via Cowork → Plugins → Add plugin. All skills available org-wide.
- **Claude Cowork skills** (personal) — upload individual `box-<skill>.zip` files via Cowork → Settings → Skills → Upload skill. Pick which skills you want.
- **Any other agent** — point your agent at the skill directories (`skills/box-init/SKILL.md`, etc.). Each skill is self-contained.

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

## Two variants of this plugin

| Variant | Repo | Backend | When to use |
|---|---|---|---|
| `box-memory` (this repo) | [`mrdulasolutions/BOX`](https://github.com/mrdulasolutions/BOX) | Box MCP (network) | Agent works from any device with internet; cloud-mode features like Business+ metadata templates |
| `box-memory-onprem` | [`mrdulasolutions/BOX-Onprem`](https://github.com/mrdulasolutions/BOX-Onprem) | Local Box Drive filesystem | Skills make zero outbound calls to Box; HIPAA / FedRAMP / ITAR-compliant data path |

You can install both — they don't conflict. Plugin namespace disambiguates: `box-memory:box-init` vs `box-memory-onprem:box-init`.

---

## Installation

Four install paths cover Claude Code, Claude Cowork (admin plugin + personal skills), and any other agent platform. Pick the one that fits.

### Prerequisites (all paths)

1. **A Box account** — any tier. The bundle auto-detects capabilities and routes accordingly.
2. **The official Box remote MCP server** — `box-remote-mcp` hosted by Box at `https://mcp.box.com`. Box-maintained, OAuth 2.0, ~50+ tools across files / search / Box AI / Hubs / Doc Gen / metadata. Setup: Box Admin Console → Integrations → enable "Box MCP server" predefined integration; grant scopes `root_readwrite`, `ai.readwrite`, `docgen.readwrite`. In Claude Code or Cowork, install via **Settings → Connectors → Box**.

> **Box deprecated the older self-hosted MCP server.** Don't start new projects with it. If you've installed a community Box MCP (e.g., `hmk/box-mcp-server`), the cloud plugin will still work, but switch to the official remote MCP when you can — that's the Box-supported surface and the one this plugin is designed against.

### Authentication for non-Claude / headless agents

If you're integrating from outside Claude Code / Cowork:

| Use case | Recommended auth | Why |
|---|---|---|
| **Headless agent** (server-to-server, no human in loop) | **Client Credentials Grant (CCG)** | Service-account model; no keypair rotation; Box's documented recommendation for agent workflows. See [Box CCG guide](https://developer.box.com/guides/authentication/client-credentials). |
| **Per-user agent** (acts as the logged-in user) | **OAuth 2.0** | What the official remote MCP uses. Each agent action is attributed and audited to that user. |
| Migrating from JWT | Stick with JWT or switch to CCG | JWT still works; CCG is simpler for new builds. |

The plugin itself doesn't manage auth — it invokes whatever Box MCP your agent has configured. Use the matrix above to pick the right path before connecting.

### For non-Claude agent frameworks

Box maintains integrations into popular agent frameworks. The cloud plugin's skills can coexist with these:

| Framework | Box integration | Notes |
|---|---|---|
| **LangChain (Python)** | [`langchain-box`](https://python.langchain.com/docs/integrations/providers/box/) — `BoxLoader`, `BoxRetriever`, `BoxBlobLoader` | Maintained by `box-community`. Auth: Dev Token / JWT / CCG. |
| **LlamaIndex** | [`llama-index-readers-box`](https://docs.llamaindex.ai/en/stable/api_reference/readers/box/) — `BoxReader`, `BoxReaderTextExtraction`, `BoxReaderAIPrompt`, `BoxReaderAIExtract` | First-party in the LlamaIndex monorepo. Auth: CCG / JWT / OAuth 2.0 / Dev Token. |
| **CrewAI / AutoGen / MS Agent Framework** | No first-party Box integration. Route through MCP, official SDK, or LangChain tools. | |

If you're building outside Claude entirely, you may also want Box's official SDKs (Python / Node / Java / .NET / iOS — see [Box SDKs index](https://developer.box.com/sdks-and-tools)). All actively maintained at v10, support CCG out of the box.

### Path 1 — Claude Code (plugin)

Option A: git clone directly into the plugins directory:

```bash
git clone https://github.com/mrdulasolutions/BOX.git ~/.claude/plugins/box-memory
```

Option B: download and unzip into a named subdirectory (the plugin zip is flat, so you must specify the target name):

```bash
mkdir -p ~/.claude/plugins/box-memory
curl -L -o /tmp/box-memory-plugin.zip \
  https://github.com/mrdulasolutions/BOX/releases/latest/download/box-memory-plugin.zip
unzip /tmp/box-memory-plugin.zip -d ~/.claude/plugins/box-memory/
```

After install, the eight skills (each is also a `/box-*` slash command) are available in Claude Code.

### Path 2 — Claude Cowork plugin (admin, recommended for orgs)

Cowork accepts the same plugin format as Claude Code. The plugin zip works in both — one install, all skills + commands available to every user in your org.

1. Download `box-memory-plugin.zip` from the [latest release](https://github.com/mrdulasolutions/BOX/releases/latest).
2. In Cowork (as an org admin), go to **Cowork settings → Plugins → Add plugin**.
3. Drag the zip in, or click and select the file.
4. Once installed, every user in your org gets the plugin's eight skills (each invokable as a `/box-*` slash command).

**Requirements** (per Cowork's docs): zip must be ≤50 MB and have a plugin name in lowercase-hyphenated form — `box-memory` matches. The plugin zip's contents are at the zip root (`.claude-plugin/plugin.json` at root, plus `skills/`, `commands/`, etc.) as Cowork expects.

### Path 3 — Claude Cowork personal skills (any user)

If you don't have admin rights, or you only want a subset of the skills, upload them individually as personal skills.

1. Download the individual skill zips from the [latest release](https://github.com/mrdulasolutions/BOX/releases/latest):
   - `box-init.zip`
   - `box-status.zip`
   - `box-tier-detect.zip`
   - `box-write.zip`
   - `box-recall.zip`
   - `box-companion.zip`
   - `box-team.zip`
   - `box-index-rebuild.zip`
2. In Cowork, go to **Settings → Skills → Upload skill**.
3. Drop each `.zip` you want. Cowork unpacks each as a self-contained skill.

Each per-skill zip contains a folder matching the skill name (e.g., `box-init/SKILL.md` inside `box-init.zip`) — the format Cowork's skill uploader requires.

**Recommended upload order** if you want to test the minimum useful set first: `box-init` → `box-tier-detect` → `box-write` → `box-recall`. Add the rest as you need them.

Slash commands aren't available via personal skills — only when the full plugin is installed (Path 1 or 2). The skills still auto-fire from their `description` field when the user asks something matching.

### Path 4 — Any other agent (Codex, Cursor, OpenClaw, custom SDK)

Each skill directory is self-contained: `SKILL.md` + `references/` + `examples/`. Any agent that can read `SKILL.md` and follow its instructions can use these.

```bash
git clone https://github.com/mrdulasolutions/BOX.git
# Point your agent at the skill directories:
ls skills/
# → box-init/  box-write/  box-recall/  box-companion/
#   box-team/  box-tier-detect/  box-index-rebuild/
```

For agents that accept the Anthropic Skills format directly, use the per-skill zips from the release.

For agents that expect a `skills/` directory to drop in, use `box-memory-skills.zip` from the release — it unzips to a `skills/` directory with all 8 skill subdirectories inside.

### Building from source

```bash
./scripts/build.sh              # build all artifacts
./scripts/build.sh --check      # verify per-skill refs match canonical (no zip)
./scripts/build.sh --sync       # force-sync canonical refs into skills, then build
```

Outputs land in `dist/`:

```
dist/
├── box-memory-plugin.zip       # Cowork Plugins upload + Claude Code (flat, .claude-plugin/ at root)
├── box-memory-skills.zip       # all 8 skills bundled as skills/<name>/ (drop into any agent)
└── skills/
    ├── box-init.zip           # Cowork Skills upload (wrapped: box-init/SKILL.md inside)
    ├── box-tier-detect.zip
    ├── box-write.zip
    ├── box-recall.zip
    ├── box-companion.zip
    ├── box-team.zip
    └── box-index-rebuild.zip
```

### Which artifact for which install?

| Scenario | Artifact | Zip shape |
|---|---|---|
| Claude Code plugin install | `box-memory-plugin.zip` | Flat (.claude-plugin/, skills/, commands/ at zip root) |
| Cowork org plugin install (admin) | `box-memory-plugin.zip` | Same flat shape — Cowork uses Claude Code plugin format |
| Cowork personal skill upload | individual `skills/<name>.zip` | Wrapped (`<name>/SKILL.md` inside) — Cowork Skills requirement |
| Drop into another agent's skills folder | `box-memory-skills.zip` | Wrapped as `skills/<name>/...` — drop-in for any agent |
| Adapt one skill into another project | individual `skills/<name>.zip` | Per-skill self-contained kit |

---

## Quick start

**Claude Code:**

```text
/box-init my-workspace
```

**Cowork or any other agent** — just ask in natural language:

> *"Set up a Box memory workspace called my-workspace."*

The `box-init` skill fires from its description. Same result either way:

1. Probes your Box account to detect tier and capabilities
2. Creates a workspace folder structure (`memories/`, `files/`, `companions/`, `teams/`)
3. Writes `_box-memory.json` (workspace config)
4. Writes initial `_index.json` files
5. On Business+, creates a metadata template for instant queries

Then just talk to your agent:

> *"Remember that we decided to use JWT instead of sessions because of mobile."*

The `box-write` skill fires, generates a memory file with frontmatter, uploads to Box, updates the index.

> *"What did we decide about auth?"*

The `box-recall` skill fires, reads the index, returns the memory instantly.

> *"Take a look at this PDF and remember what it is."*

The `box-companion` skill fires, generates a paired `.md` with the file's hash, summary, and links.

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

## Skills

Each skill is both an auto-invoked capability (fires from its `description` when the user's request matches) and a slash command (in environments that support them — Claude Code, Claude Cowork with the plugin installed). The skill name *is* the slash command.

| Skill / Slash command | When it fires | Typical invocation |
|---|---|---|
| `box-init` (`/box-init`) | First-time workspace setup, or no workspace is found | *"set up Box memory"* |
| `box-status` (`/box-status`) | User asks about workspace state, tier, counts | *"what's in my Box workspace"* |
| `box-tier-detect` (`/box-tier-detect`) | Internal — other skills call it; user can force re-probe | *"what tier am I on"* |
| `box-write` (`/box-write`) | User wants to save a memory | *"remember that we decided X"* |
| `box-recall` (`/box-recall`) | User asks about past decisions/facts/etc. | *"what did we decide about Y"* |
| `box-companion` (`/box-companion`) | A binary needs a paired markdown description | *"describe this PDF"* |
| `box-team` (`/box-team`) | Multi-team operations | *"create a team called ops"* |
| `box-index-rebuild` (`/box-index-rebuild`) | Index drift suspected, or after a manual Box-side change | *"refresh the indexes"* |

In Cowork (with the plugin installed), the same eight skills are available as `/box-*` slash commands. With personal-skill upload (no plugin), the skills still auto-fire from their `description` but slash command syntax may not work in your client.

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
- **`search_files_metadata` MCP tool is broken in current Box MCP versions** — returns empty results even when data is queryable. The plugin routes around this by using `search_files_keyword + mdfilters` instead.
- **OAuth token scopes don't widen on Box tier upgrade.** If you upgrade your Box plan and template-create operations 403, disconnect and reconnect the Box MCP to refresh the token.
- **Fresh metadata templates have a ~10 minute warm-up window** before bulk `mdfilters` queries return correct results — empirically, despite Box docs claiming real-time. Direct file reads work immediately; recall falls back to index files during the warm-up.

For the full operational quirk catalog with workarounds, see [references/operational-notes.md](references/operational-notes.md).

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
