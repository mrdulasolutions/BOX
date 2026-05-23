# Changelog

All notable changes to box-memory will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-05-23

### Added

- **`references/operational-notes.md`** — six findings from live testing that the canonical docs don't cover: `search_files_metadata` MCP wrapper bug, OAuth scope not widening on tier upgrade, ~10 min metadata-template warm-up window, keyword-search empty-query workaround, `gt` float-comparison inclusivity quirk, and the canonical-vs-live template name discrepancy.
- **Skills bundle zip** — new artifact `dist/box-memory-skills.zip` containing the full `skills/` directory. Drop into any Claude Code plugin, any agent's skills folder, or unzip and point your agent at it. Sits alongside the existing per-skill zips and the full-plugin zip.
- **`metadata_template_created_at`** field in workspace config — tracks when the metadata template was created so `box-memory-recall` knows to skip the metadata-query path during the ~10 min warm-up window.

### Changed

- **`box-memory-recall`** Step 4 routes Business+ metadata queries through `search_files_keyword` + `mdfilters` (NOT the broken `search_files_metadata` MCP tool). Passes `"the"` as a non-empty query pseudo-wildcard. Detects template warm-up window and falls through to `_index.json` recall automatically.
- **`box-setup`** Step 7 surfaces the ~10 min warm-up window to the user, captures `metadata_template_created_at`, and detects stale-OAuth-token symptoms on 403s with a clear reconnect prompt.
- **`box-tier-detect`** adds detection rules for stale OAuth token vs ambiguous tier — when signals contradict, prefers the stale-token diagnosis since it's more common and the fix is concrete.
- **`references/architecture.md`** Failure modes table updated with five new rows covering the operational quirks, each cross-referencing `operational-notes.md`.
- **`references/tier-matrix.md`** universal-caveats section adds the OAuth-reconnect and template-warm-up notes.
- **`references/schema.md`** Metadata Template section adds an "Operational caveats" subsection and a "Template name in live deployments" note acknowledging the `boxMemory` vs `agentMemory` naming drift.

### Notes

- No behavior changes for Personal-tier users — operational quirks are all on the Business+ metadata path.
- No breaking changes to the workspace schema. `metadata_template_created_at` is additive and optional; missing-field handling assumes `null`.

## [0.1.1] - 2026-05-22

### Added

Multi-target distribution. Same skills, three install paths.

- **Claude Cowork support** — each skill ships as a standalone `.zip` artifact uploadable via Cowork's Skills settings. Per-skill zips contain `SKILL.md` at the root alongside copies of `references/` and `examples/`.
- **Generic-agent support** — each skill directory is self-contained (`SKILL.md` + `references/` + `examples/`). Any agent that reads SKILL.md can use the skills directly without needing the Claude Code plugin format.
- **Build script** — `scripts/build.sh` produces `dist/box-memory-plugin.zip` (Claude Code) and `dist/skills/<skill>.zip` (per-skill, for Cowork). Includes drift detection that catches when per-skill ref copies diverge from canonical sources.
- **`--check` mode** for build script — diagnostic-only, verifies drift without writing.
- **`--sync` mode** for build script — refreshes per-skill copies from canonical refs.

### Changed

- README rewritten with three install paths (Claude Code plugin, Cowork skill zips, generic agent).
- SKILL.md error messages now reference "your platform's MCP configuration" instead of "Claude settings", staying agent-platform-neutral.
- `references/architecture.md` updated to acknowledge multi-platform support.
- Each skill directory now contains its own `references/` and `examples/` subdirectories so the skill zip is self-contained.

### Notes

- No API or skill behavior changes. A workspace created by v0.1.0 is fully compatible with v0.1.1.
- The `scripts/` directory is new but doesn't affect plugin behavior — it's dev tooling.

## [Unreleased]

### Planned for v0.2

- Wikilink integrity checker (find dead `[[links]]` across workspace)
- Session-start hook to surface recent memories
- Stop hook to summarize session into a memory

### Planned for v0.3

- Standalone MCP server build of the same primitives (for non-Claude agents)
- Optional CLI for batch operations outside of an agent context

### Planned for v0.4

- Box Sign integration for decision attestations
- Retention / legal-hold helpers (Enterprise tier)

## [0.1.0] - 2026-05-22

### Added

Initial release. Claude Code plugin with seven skills and seven slash commands for using Box.com as agent memory + file storage.

**Skills:**
- `box-setup` — workspace bootstrap (folders, config, indexes, optional metadata template)
- `box-tier-detect` — probe Box account capabilities, cache in workspace config
- `box-memory-write` — write a memory with frontmatter, wikilinks, index update
- `box-memory-recall` — multi-strategy lookup that bypasses Box's 10-min search lag
- `box-file-companion` — generate paired markdown for binaries with SHA256 anchoring
- `box-team-isolate` — multi-team subtree management (create, list, inspect, conflicts, remove)
- `box-index-rebuild` — regenerate indexes from source memory files, detect drift and stale companions

**Slash commands:** `/box-init`, `/box-write`, `/box-recall`, `/box-companion`, `/box-status`, `/box-team`, `/box-index-rebuild`

**Reference documentation:**
- `references/schema.md` — memory, companion, index, and workspace config schemas
- `references/tier-matrix.md` — Box tier capability matrix (Personal through Enterprise Plus)
- `references/architecture.md` — design rationale (why Box, why not RAG, why folder-ACL isolation)

**Examples:**
- Decision memory, task memory, file companion, folder index, and workspace config

### Design highlights

- Tier-aware (Personal / Business / Enterprise / Enterprise Plus), never tier-gated. Every feature has a working path on every Box tier; Business+ unlocks faster paths.
- Box's 10-minute search indexing lag is bypassed via per-folder `_index.json` files updated on every write.
- Binaries get paired companion `.md` files instead of being chunked into RAG. SHA256 hash anchoring detects when companions go stale.
- Folder ACLs are the multi-team isolation boundary — frontmatter `team:` is a hint, not enforcement.
- The plugin invokes the existing Box MCP for all Box API calls; it does not manage Box auth itself.
