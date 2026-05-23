# Changelog

All notable changes to box-memory will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.7] - 2026-05-23

### Fixed

**Cowork rejected v0.1.6 with "Plugin validation failed"** even though `claude plugin validate` passed. Discovered by inspecting Anthropic's own published Cowork plugins ([anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins)) — `customer-support`, `engineering`, `legal`, `data`, `design`, `marketing`, `productivity`, `sales` — every one uses the **same 4-field minimal `plugin.json`**:

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "...",
  "author": { "name": "Anthropic" }
}
```

No `homepage`, `repository`, `license`, `keywords`, `author.email`, `author.url`. Anthropic's `create-cowork-plugin` skill confirms: *"Minimal required field is `name`. Full recommended structure: name + version + description + author.name."*

The official `schemastore.org/claude-code-plugin-manifest.json` schema permits all those extra fields, and so does `claude plugin validate`. But Cowork's runtime validator is stricter than both — it rejects manifests with fields beyond the minimal pattern.

- **Stripped `plugin.json` to the 4-field Cowork-compatible pattern.** Moved `homepage`, `repository`, `license`, `keywords` to the README where they're more discoverable for humans anyway. Removed `author.email` and `author.url` for the same reason.

### Validation methodology improved

The local `claude plugin validate` CLI is necessary but not sufficient for Cowork. Going forward, the canonical reference is **comparing against Anthropic's own working plugins**. The repo `anthropics/knowledge-work-plugins` is the source of truth for what Cowork accepts. Schema docs (schemastore + plugins-reference) describe the spec; Anthropic's plugins demonstrate what passes Cowork's runtime check.

### Compatibility

- No skill, schema, or behavior changes from v0.1.6.
- Per-skill zip names unchanged from v0.1.5.
- If you successfully installed v0.1.6 in Claude Code, v0.1.7 works identically there — the dropped manifest fields were optional metadata Claude Code ignored anyway.
- For Cowork: uninstall the previous failed upload first, then upload `box-memory-plugin.zip` from v0.1.7.

## [0.1.6] - 2026-05-23

### Fixed

Cowork rejected v0.1.5 with a generic "plugin validation failed" despite Claude Code accepting it. Cowork's manifest/skill validator is stricter than the local `claude plugin validate` CLI; fixed the most likely culprits.

- **Stripped non-ASCII characters from SKILL.md frontmatter `description` fields.** Six of the eight SKILL.md files contained em-dashes (U+2014) and ellipses (U+2026) inside the YAML `description` value. The local `claude plugin validate` accepts these; some strict YAML/manifest validators do not. Replaced with ASCII equivalents (`-`, `...`). Body content keeps its unicode — only the frontmatter values needed cleaning since that's what schema validators parse.
- **Added `author.email`** for stricter validators that flag missing author contact info. The official schema only requires `author.name`, but some downstream validators flag missing email as a warning that may be treated as an error elsewhere.

### Validation

Verified against both local `claude plugin validate` (Claude Code 2.1.97) and the official [schemastore.org plugin manifest schema](https://www.schemastore.org/claude-code-plugin-manifest.json):

```text
$ claude plugin validate .
✔ Validation passed

$ python -m jsonschema (against schemastore.org schema)
schemastore strict validation: PASSED
```

### Considered but not shipped

- `$schema` and `displayName` fields are valid per the official schema, but the older `claude plugin validate` CLI (≤ v2.1.142) rejects them as "unrecognized keys" with a hard error. Held off until that's resolved upstream or we know Cowork specifically needs them.

### How to re-test in Cowork

1. **Uninstall** any earlier broken upload from your Cowork settings first (Cowork may cache validation failures by plugin name).
2. Download the new `box-memory-plugin.zip` from the v0.1.6 release.
3. Re-upload via Cowork → Plugins → Add plugin.

If validation still fails, paste the **exact** error message — without it I can only guess at the next root cause.

## [0.1.5] - 2026-05-23

### Changed

Migrated from the legacy `commands/` flat-file format to the modern `skills/<name>/SKILL.md` format. After installing v0.1.4, Claude Code emitted:

> *"Plugin installed. Note: it uses the legacy commands/ format. Both formats work — consider migrating to skills/*/SKILL.md."*

v0.1.5 is that migration. In the modern format, each skill's name *is* its slash command — no separate `commands/` directory needed.

**Skill renames** (slash commands now match skill names):

| v0.1.4 skill | v0.1.4 command | v0.1.5 skill / command |
|---|---|---|
| `box-setup` | `/box-init` | `box-init` (`/box-init`) |
| `box-memory-write` | `/box-write` | `box-write` (`/box-write`) |
| `box-memory-recall` | `/box-recall` | `box-recall` (`/box-recall`) |
| `box-file-companion` | `/box-companion` | `box-companion` (`/box-companion`) |
| `box-team-isolate` | `/box-team` | `box-team` (`/box-team`) |
| `box-tier-detect` | (none) | `box-tier-detect` (`/box-tier-detect`) |
| `box-index-rebuild` | `/box-index-rebuild` | `box-index-rebuild` (`/box-index-rebuild`) |

### Added

- **New `box-status` skill** — was previously only a slash command. Now a real skill (auto-fires on "what's in my workspace", "show status", etc.) and a `/box-status` command. Read-only — never modifies the workspace.

### Removed

- `commands/` directory. Slash commands are now part of skills via the modern format.

### Fixed

- No more "legacy commands/ format" warning on install.

### Skill cross-references

All internal cross-references between skills (e.g., `box-init` calls `box-tier-detect`, `box-recall` reads what `box-write` produced) updated to the new names. Plugin validates clean.

### Per-skill zip filename changes

Cowork users uploading individual skill zips: the filenames changed to match the new skill names. Re-download from the v0.1.5 release.

| Old zip name (v0.1.4) | New zip name (v0.1.5) |
|---|---|
| `box-setup.zip` | `box-init.zip` |
| `box-memory-write.zip` | `box-write.zip` |
| `box-memory-recall.zip` | `box-recall.zip` |
| `box-file-companion.zip` | `box-companion.zip` |
| `box-team-isolate.zip` | `box-team.zip` |
| — | `box-status.zip` (new) |

### Compatibility

- **Workspaces created by earlier versions:** unchanged. The `_box-memory.json` config and on-disk memory files have no skill-name references; only the plugin/skill code references skill names.
- **If you installed the plugin via git clone:** `git pull` and you're current.
- **If you installed via zip:** download the new `box-memory-plugin.zip` from v0.1.5 and re-extract.
- **No schema changes.** Memory frontmatter, index format, and template definition are byte-identical to v0.1.4.

## [0.1.4] - 2026-05-23

### Fixed

`claude plugin validate` failed on the manifest and one SKILL.md in v0.1.0–v0.1.3. The plugin would not install in Claude Code or upload to Cowork. Both errors fixed:

- **`plugin.json` — `repository` was an object, must be a string.** The npm-style `{type: "git", url: "..."}` shape was wrong. Per the [Claude Code plugin reference](https://code.claude.com/docs/en/plugins-reference), `repository` is a `string` containing the source URL. Wrong-type fields are a hard load error.

  ```diff
  - "repository": {
  -   "type": "git",
  -   "url": "https://github.com/mrdulasolutions/BOX.git"
  - }
  + "repository": "https://github.com/mrdulasolutions/BOX"
  ```

- **`skills/box-memory-recall/SKILL.md` — YAML frontmatter parse failure.** The description contained the substring `lag: tries` — YAML interpreted `lag:` as a new key/value pair, breaking the description string. Replaced the colon with an em-dash so the description stays a plain scalar.

### Verified

```text
$ claude plugin validate .
Validating plugin manifest: /.claude-plugin/plugin.json
✔ Validation passed
```

### Notes

- All earlier releases (v0.1.0–v0.1.3) would fail `claude plugin validate` and not install. v0.1.4 is the first installable release. If you tried to install any earlier version and got "plugin validation failed," that's why.
- No skill content or schema changes from v0.1.3. Only the manifest and one description string were edited.

## [0.1.3] - 2026-05-23

### Fixed

Zip shapes corrected to match Claude's actual upload requirements (verified against [Claude Code plugin reference docs](https://code.claude.com/docs/en/plugins-reference) and [Claude Skills upload docs](https://support.claude.com/en/articles/12512198-creating-custom-skills)).

- **`box-memory-plugin.zip`** — was wrapping all contents in a `box-memory/` directory (incorrect for Cowork Plugins upload). Now flat: `.claude-plugin/plugin.json` is at the zip root, with `skills/`, `commands/`, `references/`, etc. also at root. This is what both Cowork's Plugins-admin upload and `--plugin-dir` extraction expect.
- **`skills/<name>.zip`** (per-skill) — were flat (`SKILL.md` at zip root). Cowork's Skills upload explicitly requires *"The ZIP should contain the Skill folder as its root"* — now wrapped: each zip contains a `<skill-name>/` folder with `SKILL.md` inside, matching the skill's frontmatter `name`.

### Added

- **Cowork Plugins upload path** documented in README (admin → upload `box-memory-plugin.zip` via Cowork settings → Plugins → Add plugin). Same artifact as Claude Code's plugin install — Cowork accepts the Claude Code plugin format.
- **Recommended upload order** for Cowork personal Skills users — `box-setup` first since other skills check for the workspace.
- **"Which artifact for which install?" table** in README mapping each scenario to the correct zip and explaining the shape requirement.

### Changed

- README install section restructured around four paths (Claude Code plugin / Cowork org plugin / Cowork personal skills / generic agent).
- `scripts/build.sh` header comment now documents the zip-shape contract with quotes from Claude's docs so the rules are checkable next to the implementation.

### Notes

- **If you installed v0.1.0 / v0.1.1 / v0.1.2 plugin zip via Claude Code:** the directory layout under `~/.claude/plugins/` should still be the same since `git clone` was the unaffected path. Only users who used the `unzip -d ~/.claude/plugins/` command got a `box-memory/` subdirectory — which still works since that's the expected layout there.
- **If you tried to upload v0.1.0 / v0.1.1 / v0.1.2 zips to Cowork:** they would have failed (wrong shape). v0.1.3 zips are the first ones Cowork actually accepts.

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
