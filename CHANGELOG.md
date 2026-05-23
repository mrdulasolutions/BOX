# Changelog

All notable changes to box-memory will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
