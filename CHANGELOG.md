# Changelog

All notable changes to box-memory will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
