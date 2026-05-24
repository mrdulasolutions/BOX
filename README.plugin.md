# Box Memory

A Claude Cowork / Claude Code plugin that uses Box.com as agent memory + file storage. Markdown memories with YAML frontmatter and Obsidian-style wikilinks, paired companion `.md` files for binaries (no chunking, no RAG), instant recall via per-folder index files (all Box tiers) or metadata templates (Business+).

## Skills

| Skill | Slash | Description |
|---|---|---|
| `box-init` | `/box-init` | Bootstrap a Box workspace |
| `box-status` | `/box-status` | Show workspace state (tier, counts, health) |
| `box-tier-detect` | `/box-tier-detect` | Probe Box account capabilities |
| `box-write` | `/box-write` | Save a memory |
| `box-recall` | `/box-recall` | Find memories |
| `box-companion` | `/box-companion` | Describe a binary file in markdown |
| `box-team` | `/box-team` | Manage multi-team subtrees |
| `box-index-rebuild` | `/box-index-rebuild` | Refresh per-folder indexes |

## Setup

1. Connect a Box MCP server to your platform (Cowork → Connectors, Claude Code → MCP settings, etc.). See [CONNECTORS.md](./CONNECTORS.md).
2. Run `/box-init my-workspace` (or just ask your agent to set up Box memory).
3. The plugin auto-detects your Box tier and routes accordingly.

## Repo

Source, docs, examples, and design rationale: https://github.com/mrdulasolutions/BOX

## License

MIT
