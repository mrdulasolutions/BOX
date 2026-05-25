# Changelog

All notable changes to box-memory will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-05-25

### Added — non-Claude harness OAuth setup support

Field finding from Hermes integration: Box's OAuth server does **not** support Dynamic Client Registration (DCR). Every non-Claude harness (Hermes, OpenClaw, Codex, Cursor, custom) must pre-register a Box Custom App in the developer console, then configure the harness's MCP server block with the resulting `client_id`/`client_secret`. The plugin now surfaces this walkthrough.

- **`references/harness-oauth-setup.md`** — new source-of-truth doc keyed by harness name. Documents Box developer console steps, required scopes (by both Box-console label AND OAuth scope string), and per-harness redirect URIs, config locations, and silent-failure modes. Hermes section captures the verified-working flow from a 2026-05-25 Claude 4.7 setup.

- **`/box-mcp-check --harness=auto|claude|hermes|generic`** — new flag selects which setup narrative to surface. `auto` (default) preserves current behavior. `hermes` surfaces Hermes-specific config including the `auth: oauth` silent-failure gotcha and post-OAuth `/reload-mcp` requirement. `generic` walks through manual OAuth for any non-Claude harness.

### The "Auth: none" silent failure

Hermes config requires both:
- `oauth:` block with `client_id`, `client_secret`, `redirect_port`
- Top-level `auth: oauth` key (separate from the credentials block)

Without the top-level `auth: oauth` key, `hermes mcp test box` reports `Auth: none` and the server 401s — even though credentials parsed correctly. This is the #1 setup failure mode for Hermes users; the new harness doc and `/box-mcp-check --harness=hermes` both call it out prominently.

### Model floor for setup

The OAuth setup flow (browser dev-console → copy creds → edit YAML → debug silent failures → retry) requires **Claude 4.5+ or equivalent**. Smaller/older models may stall on the silent failure modes. For weak-model deployments: do the one-time setup in a Claude 4.5+ session; any model can use the connection afterwards (tokens persist in harness config).

### Verification

- `claude plugin validate` — PASSES
- Hermes + Claude 4.7 + Box Custom App + 30 tools live (2026-05-25)
- Existing Claude Code / Cowork installs: zero behavior change (the new flag is opt-in; `--harness=auto` matches prior default)

### Why patch not minor

The new flag is additive and optional. No existing functionality changed. Plugin shape, manifest fields, and all 12 skill behaviors are unchanged for users not invoking the new flag.

## [0.1.0] - 2026-05-24

### The Box-native release — Box AI, Hubs, AI Studio, official MCP

After canvassing developer.box.com across Box AI, Box Skills, official SDKs, MCP servers, Hubs, Doc Gen, webhooks, and 2026 H1 launches, the plugin now leverages Box's full product surface where it makes sense and explicitly documents where it doesn't.

### Added — 4 new skills

| Skill | Purpose | Tier |
|---|---|---|
| **`box-ai-recall`** | Semantic Q&A via Box AI `/2.0/ai/ask` — auto-routes between multi-doc Q&A (up to 25 files, Business+) and Hubs Q&A (up to 20k files, Enterprise Plus). Returns citations. | Business+ (AI Units) |
| **`box-ai-extract`** | Schema-driven metadata extraction via `/2.0/ai/extract_structured`. OCR for PDFs / TIFF / PNG / JPEG. Targets the `boxMemory` template. Used by `box-companion` for non-text formats. | Business+ (AI Units) |
| **`box-ai-agent`** | Create/manage persistent Box AI Studio agents. "Memory librarian" persona with locked instructions ("cite or refuse, never speculate"). Audit-friendly for regulated environments. | Enterprise Advanced |
| **`box-mcp-check`** | Verifies the user is on Box's official remote MCP at `mcp.box.com` (vs deprecated self-hosted or community variants). Reports OAuth scopes, tool coverage, and exact upgrade steps. | All tiers |

### Changed — 4 existing skills enhanced

- **`box-init`** — new `--as-hub` flag creates a Box Hub instead of a folder workspace (Enterprise Plus only; unlocks Hubs Q&A across up to 20k files). Formalized the `boxMemory` metadata template definition. New workspace config fields: `workspace_type`, `hub.{id,created_at,last_item_added_at}`, `settings.{ai_recall_enabled,ai_extract_enabled,ai_studio_agent_enabled,ai_model,compliance_target}`. All AI-consuming settings default to **false** — explicit opt-in.
- **`box-recall`** — when local lookup returns sparse free-text results and `settings.ai_recall_enabled` is true, suggests `/box-ai-recall` as a fallback. Never auto-calls AI for exact lookups (ID / wikilink / slug).
- **`box-companion`** — new "Path A" using `box-ai-extract` for PDFs / TIFF / PNG / JPEG / Office docs. Replaces the previous "couldn't parse this format" stubs with structured OCR + per-field source-text citations. Falls back to the previous local-inspection path when AI isn't available or `--no-ai` is passed.
- **`box-tier-detect`** — also probes for the official Box MCP (`box_mcp_official` capability), Box AI tool availability (`box_ai_tools_available`), AI Units availability (`ai_units_available`), Box Hubs support, and AI Studio agent eligibility. Surfaces gaps with specific upgrade paths.

### Added — new reference docs

- **`references/webhooks.md`** — pattern document for users self-hosting a webhook receiver to wire Box events (`FILE.UPLOADED`, `METADATA_INSTANCE.UPDATED`, etc.) to box-memory workflows. Includes HMAC-SHA256 verification sample. Notes Box Automate as an alternative for in-Box-only workflows. Explicitly notes incompatibility with the air-gap variant.
- **`references/box-ai-units.md`** — Box AI cost model: per-plan unit allocations (Free 1k, Business purchase, Enterprise 1k, Enterprise Plus 2k, Enterprise Advanced 20k), per-skill consumption, opt-in controls, and what happens when units run out (graceful degradation to non-AI paths).

### Changed — operational notes (Notes 7 & 8 added)

- **Note 7** — Box Hubs have an indexing warm-up window (same pattern as fresh metadata templates from Note 3). Newly-created Hubs return empty `box-ai-recall` results for ~10 minutes after creation. Plugin detects via `hub.created_at` / `last_item_added_at` and falls back to file-set Q&A.
- **Note 8** — Box SDK v10.6.0+ (April 2026 release) corrected the `tags` content-type for `search_files_keyword` to match the public API. This was a breaking change for users wrapping the plugin's recall via the SDK directly.

### Changed — README

- Recommended Box MCP is now explicitly the **official remote MCP at `mcp.box.com`** (Box-maintained, OAuth 2.0, full toolset). The deprecated self-hosted Box MCP is called out.
- New "Authentication for non-Claude / headless agents" section: CCG for headless, OAuth for per-user, JWT for legacy.
- New "For non-Claude agent frameworks" section: `langchain-box` and `llama-index-readers-box` integrations pointed out.

### Migration from v0.0.1

- **No workspace data migration** — `_box-memory.json` schema is forward-compatible. New fields (`workspace_type`, `hub`, `settings.ai_*`) default safely when absent.
- **No skill renames** — only additions and enhancements.
- **AI features are opt-in** — default settings preserve v0.0.1 behavior. Set `ai_recall_enabled: true` / `ai_extract_enabled: true` in `_box-memory.json.settings` to opt in.
- Reinstall the plugin zip; existing workspaces continue working without changes.

### v0.0.1 — initial release (preserved below)

---

## [0.0.1] - 2026-05-23

### Initial release

A Claude Code / Claude Cowork plugin that turns Box.com into agent memory + file storage.

**8 skills** (each is also a `/box-*` slash command):

| Skill | Purpose |
|---|---|
| `box-init` | Bootstrap a Box workspace with tier-aware setup |
| `box-status` | Show workspace state (tier, counts, index health) |
| `box-tier-detect` | Probe Box account capabilities |
| `box-write` | Save a memory (markdown + frontmatter + wikilinks) |
| `box-recall` | Find memories (multi-strategy lookup, bypasses Box's 10-min search lag) |
| `box-companion` | Generate a paired markdown describing a binary file (no chunking, no RAG) |
| `box-team` | Manage multi-team subtrees |
| `box-index-rebuild` | Refresh per-folder indexes when drift is detected |

**Architecture:** plugin = thin invocation contract; GitHub repo = deep knowledge. Each SKILL.md is ~4 KB and links to detailed procedures, schemas, tier matrix, and operational notes at `raw.githubusercontent.com/mrdulasolutions/BOX/main/references/...`. Agents fetch the deep content on demand when a workflow needs it.

**Plugin zip:** 35 KB uncompressed / 19 KB compressed. Sized inside Anthropic's published Cowork plugins range. Verified to install cleanly in Cowork.

**Tier-aware, never tier-gated:**
- Personal/Free: per-folder `_index.json` for instant recall (bypasses Box's universal 10-min search lag)
- Business+: optional `boxMemory` metadata template for SQL-like queries
- Enterprise+: retention policies, legal holds, KeySafe (declared in workspace config; the plugin recognizes and routes)

**Compliance posture** (delegated to Box; declared per-workspace):
- SOC 2 on Business+
- HIPAA BAA on Enterprise
- FedRAMP Moderate on Enterprise
- FedRAMP High / DoD IL4 / ITAR on Enterprise Plus

**Distribution paths:**
- `box-memory-plugin.zip` — Claude Code plugin install + Cowork Plugins admin upload
- `box-memory-plugin.plugin` — same bytes, alternate extension some Cowork uploaders prefer
- `box-memory-skills.zip` — all 8 skills as `skills/<name>/` directories; drop into any agent's skills folder
- `box-<skill>.zip` (×8) — per-skill zips for Cowork personal Skills upload

**Repo:** https://github.com/mrdulasolutions/BOX

### Acknowledgments

Built through 11 iterations of debugging Cowork's plugin validation, which is stricter than Claude Code's `claude plugin validate` CLI and stricter than the official schemastore.org schema. The cause turned out to be a bundle of structural deltas against [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins): file permissions, per-skill subdirectory layout, top-level directory expectations, README size, per-SKILL.md content length, and slash-form body headings. The minimal-plugin experiment that ultimately worked is preserved in the repo at `scripts/build-minimal.sh` for anyone hitting similar "plugin validation failed" errors.

### Operational notes documented (see `references/operational-notes.md`)

Six Box-side quirks that affect plugin behavior, captured from live testing:

1. `search_files_metadata` MCP tool returns empty — use `search_files_keyword + mdfilters` instead
2. OAuth token scope doesn't widen on Box tier upgrade — disconnect/reconnect to refresh
3. Fresh metadata templates have a ~10 min warm-up window for bulk `mdfilters` queries
4. `search_files_keyword` requires a non-empty query — use `"the"` as pseudo-wildcard
5. `gt` comparison on float metadata fields is inclusive — use epsilon for strict
6. Canonical template name is `boxMemory`; some early deployments used `agentMemory`
