# Architecture

The design rationale behind box-memory. Read this if you want to understand *why* the plugin works the way it does — what tradeoffs were made and what alternatives were rejected.

---

## The problem we're solving

AI agents need persistent memory and persistent file storage. The popular options today fall into two camps:

**Camp A — RAG-based memory tools** (Mem0, Supermemory, ChatGPT Memories, most "vector store + retriever" stacks).

- Files get chunked into embeddings.
- Recall is approximate (cosine similarity).
- Original file becomes second-class metadata behind the chunks.
- Embeddings drift across model versions; what your agent "remembered" in 2024 isn't reproducible in 2029.
- Provenance is best-effort.

**Camp B — Markdown-vault tools** (Obsidian + iCloud / Syncthing / Git, plain folder-of-notes setups).

- Files stay whole.
- Recall is exact (filename + body grep).
- Great for single users.
- No compliance certifications. No real multi-user access control. No retention guarantees.
- Sync conflicts under multi-agent / multi-team load.

**Box-memory** picks Camp B's data model (whole files, exact recall) and runs it on Box's substrate (compliance, ACLs, retention, durability). The plugin adds the agent-memory primitives — schema, index, companions, recall — on top.

---

## Why Box specifically

Box is the only major file storage that's:

- **Certified for regulated workloads.** SOC 2 on Business+, HIPAA BAA / FedRAMP Moderate on Enterprise, FedRAMP High / DISA IL4 / ITAR on Enterprise+. No other consumer-friendly cloud storage matches this stack.
- **API-first with stable IDs.** Every file has an immutable ID that never changes across renames, moves, version updates. The plugin keys everything on these IDs.
- **Native previews of agent-relevant formats.** Markdown, PDF, Office, CAD (DWG, DXF, RVT, IGES, STEP), images. Agents can show a user "this is the file I'm working with" without a separate viewer service.
- **Folder ACLs that actually work.** Multi-team isolation is a folder permission, not an application convention.
- **Has working AI / metadata extraction features** (Box AI, Box Skills) for cases where you do want server-side processing.
- **Has a working MCP server** that Claude can talk to.

What Box is bad at: search. The Search API has a 10-minute indexing lag, body content is gated to Business+, and it's fuzzy/prefix-only. **This is the central design constraint of box-memory.** The plugin's index files exist specifically to route around it.

---

## Core design decisions

### 1. Box file IDs are the only reliable identifier

Filenames change. Wikilinks rot. Slugs collide. But Box file IDs are permanent. **Every internal reference is an ID.** The frontmatter `id:` field is the agent-facing primary key; the Box `file_id` is the substrate-facing primary key. The index file maps between them.

### 2. Append-only by default

Agents don't overwrite memories. To "change your mind," write a new memory with `status: active`, mark the old one `status: superseded`, link them via `supersedes:` / `superseded_by:`. This gives you history for free and matches how humans actually think.

The exceptions:

- **Frontmatter `updated_at`** — updated on every write to that memory file.
- **Index files** — updated on every memory write. The index is derived state; rebuilding from source files is always safe.
- **Status transitions** — `draft` → `active` → `superseded`/`archived` are legitimate mutations.

### 3. The index file pattern (not Box search)

Box search has a 10-minute indexing lag and a 10 KB body limit (Business+). On Personal, body search doesn't work at all. **Any plugin that depended on Box search would be broken on every tier for the first 10 minutes of every memory's life.**

Instead, every folder gets a `_index.json` maintained on every write. The index is:

- **Instant to read** (single GET against a known file ID)
- **Complete** (every memory in the folder appears in the index)
- **Self-describing** (the index reflects the YAML frontmatter; agents don't need to read each memory to know its kind/tags/links)
- **Rebuildable** (`box-index-rebuild` skill scans the folder and regenerates from source if drift is detected)

Read order for any lookup:

1. Known file ID → direct fetch
2. Known folder + slug/title/kind/tag → `_index.json`
3. Cross-folder → workspace-root rollup `_index.json`
4. (Business+) → Metadata Query API
5. (Last resort) → Box Search, with a warning about lag and stale results

### 4. Companions instead of chunking

Binaries don't get chunked, embedded, or indexed. They get a *companion `.md`* — a separate markdown file describing what the binary is, written by the agent that last reviewed it.

```
report.pdf              ← binary, never touched
report.pdf.md           ← companion, agent-written, describes the binary
```

Companion frontmatter pins the description to a specific version of the file via `companion_for.sha256`. If the binary changes, the companion is stale — and the plugin can detect this.

This pattern trades RAG's "embeddings sort-of know about page 137" for "the agent reviewed page 137 on May 22 and explicitly noted what's there." The first is faster to set up; the second is provable.

For genuine sub-document search where RAG would shine (a 500-page PDF where something material is on page 437 that nobody read carefully), the agent can still run Box's body full-text search as a *signal*, not as the system of record. It hits the same 10 KB cap as everything else but it's there for opportunistic discovery.

### 5. Tier-aware, never tier-gated

Every feature has a working path on every Box tier. Business+ unlocks faster paths (metadata templates, body search) but the same agent-facing API. A Personal-tier user and an Enterprise-tier user write memories the same way and recall memories the same way — the plugin chooses the route under the hood.

This matters because:

- The plugin should help individual developers, hobbyists, and students, not just enterprises.
- A team that starts on Personal and graduates to Business shouldn't have to rewrite their agent prompts.
- The schema portable across tiers means Box-memory data can be exported and imported across accounts.

### 6. Folder ACLs are the multi-team boundary

Frontmatter has a `team:` field, but **it's a hint, not enforcement.** The real isolation is the folder ACL. Each team gets its own subfolder under `teams/`, with Box's native permissions controlling who can read/write.

This means:

- Conflict detection between teams works by listing folders, not by trusting frontmatter.
- A user with access to multiple teams' folders can recall across teams; a user without access can't.
- The plugin doesn't need to implement its own auth model — Box already has one.

### 7. The Box MCP is the auth boundary

The plugin doesn't manage Box authentication. It invokes the Box MCP tools that the user already has connected. This means:

- The plugin has no secrets, no token storage, no OAuth flow code.
- If the Box MCP works, the plugin works.
- If the user is logged into Box as Alice, the plugin acts as Alice. Folder ACLs are enforced naturally.
- The plugin works the same on Claude Code, Claude Cowork, and (when the same MCP or equivalent Box client is available) any other agent platform.

---

## What's deliberately out of scope

### Embeddings, RAG, vector stores

If you want them, run them as a *secondary* signal on top of box-memory. The plugin won't build them in.

### Box auth

Use the Box MCP. The plugin won't ship its own OAuth flow.

### Sync to other vaults (Obsidian iCloud, etc.)

Box is the system of record. If you want to mirror to Obsidian, that's a downstream concern.

### Versioning UI

Box has native version history. The plugin uses it for binary files (re-upload = new version). For markdown memories, the append-only `supersedes:` chain *is* the version history — readable in plain text, scriptable, durable.

### CI/test integration

A future v0.4 or v0.5 thing. The plugin is currently agent-facing.

### Single-template multi-schema

Box's Metadata Query API only queries one template at a time. The plugin uses **one wide template** for everything (memory, companion, etc.) and differentiates via the `kind` field. This is by design — the alternative (multiple templates, joining client-side) is slower and more complex than just keeping the index file in sync.

---

## Failure modes and how the plugin handles them

| Failure | Symptom | Plugin response |
|---|---|---|
| Box MCP not connected | Tool calls fail | Skill instructions tell agent to surface a clear message: "Connect Box MCP via your platform's MCP configuration." |
| Filename collision | 409 from Box | Plugin appends `-2`, `-3`, etc. to filename; slug remains stable; index reflects actual filename. |
| Index drift (folder content doesn't match index) | Detected on read | Plugin offers to rebuild via `box-index-rebuild`. Agent can opt to rebuild or continue with stale index. |
| Wikilink target doesn't exist | Recall returns nothing | Treated as a dangling reference. Not an error. Agent should mention it: "No memory titled X yet." |
| Companion's hash doesn't match current binary | Detected on companion read | Marked stale. Agent re-reviews binary and rewrites companion. |
| Metadata template missing (Business+ workspace, template deleted) | Plugin can't apply metadata | Falls back to index-only mode; warns; offers to recreate template. |
| Box search returns stale results | Returns 0 or wrong results | Plugin warns that search is best-effort and prefers index lookup. |
| Tier downgrade (account moved Business → Personal) | Template fields can't be applied to new files | Plugin detects on next write, switches to index-only mode, surfaces a one-time message. |
| `search_files_metadata` MCP tool returns empty when data exists | Bulk metadata queries via the dedicated tool fail | Plugin routes all metadata-filtered queries through `search_files_keyword` + `mdfilters` instead. See [operational-notes.md Note 1](operational-notes.md#1-search_files_metadata-mcp-wrapper-returns-empty-when-data-exists). |
| OAuth token scope stale after tier upgrade | Template-create or metadata-write 403s after the account upgrade should have unlocked it | Surface a clear "disconnect/reconnect Box MCP" prompt. See [operational-notes.md Note 2](operational-notes.md#2-oauth-token-scope-does-not-widen-on-tier-upgrade). |
| Fresh metadata template — bulk queries empty for ~10 minutes | Documented as real-time, empirically isn't | Fall through to `_index.json` path during warm-up window. See [operational-notes.md Note 3](operational-notes.md#3-fresh-metadata-templates-have-a-~10-minute-warm-up-window). |
| `search_files_keyword` rejects empty query parameter | Pure metadata-filter searches fail | Pass a stopword like `"the"` as a pseudo-wildcard. See [operational-notes.md Note 4](operational-notes.md#4-keyword-search-requires-a-non-empty-query-parameter). |
| `gt` comparison on float metadata fields is inclusive | `confidence > 0.9` matches `confidence == 0.9` | Use an epsilon when strict exclusion matters (e.g. `> 0.9001`). See [operational-notes.md Note 5](operational-notes.md#5-gt-comparison-on-float-metadata-fields-is-inclusive). |

For the complete operational quirk catalog see [references/operational-notes.md](operational-notes.md).

---

## Why not just use…

**…the OpenAI Memories feature?** No file storage. No compliance. Single-tenant. Vendor-locked.

**…ChromaDB / Pinecone / Weaviate?** Vector storage. Approximate retrieval. No file storage. No compliance unless you self-host on a compliant substrate (and then you're operating that substrate, which is the hard part Box solves).

**…Obsidian + Git?** Great for single-user notes. No real multi-user. No compliance. No retention. Wikilinks are exact text matches; rename and they break. No native CAD preview.

**…Notion?** No FedRAMP. Limited HIPAA. Block-based (not file-based) — your CAD file becomes a "file attachment" inside a page, not a first-class storage primitive.

**…S3 + Postgres index?** Closest to box-memory architecturally. But you operate the substrate (compliance, retention, ACLs, audit) yourself. Box does it for you.

**…SharePoint / Google Drive?** Both have agent-memory potential but neither has Box's compliance breadth, native CAD support, or as clean an MCP integration today.

---

## Roadmap considerations

Things being thought about but not committed:

- **MCP server build.** The plugin's primitives could be exposed as their own MCP server for non-Claude agents. Probably v0.3+.
- **Hooks.** A SessionStart hook that surfaces recent memories. A Stop hook that summarizes the session. Both would deepen the integration but add scope.
- **Optional CLI.** For batch operations (`box-memory rebuild-all-indexes`, etc.) outside of an agent context.
- **Wikilink integrity checker.** Walk all memories, find dead `[[links]]`, surface a report.
- **Cross-workspace federation.** Multiple Box workspaces with one logical agent memory layer on top.

None of these are needed for v1.
