# Box Memory

A Claude Cowork / Claude Code plugin that uses Box.com as agent memory + file storage. Markdown memories with YAML frontmatter and Obsidian-style wikilinks, paired companion `.md` files for binaries (Box AI Extract handles OCR on Business+), instant recall via per-folder index files plus optional AI-powered Q&A on tiers that support it.

## Skills

| Skill | Slash | Description | Tier |
|---|---|---|---|
| `box-init` | `/box-init` | Bootstrap a Box workspace (folder or Hub via `--as-hub`) | All; `--as-hub` Enterprise Plus |
| `box-status` | `/box-status` | Show workspace state (tier, counts, health) | All |
| `box-tier-detect` | `/box-tier-detect` | Probe Box capabilities + MCP variant + AI availability | All |
| `box-mcp-check` | `/box-mcp-check` | Verify official Box MCP (`mcp.box.com`) and OAuth scopes | All |
| `box-write` | `/box-write` | Save a memory | All |
| `box-recall` | `/box-recall` | Find memories via local index | All |
| `box-ai-recall` | `/box-ai-recall` | Semantic Q&A via Box AI Ask (multi-doc or Hubs) | Business+ (AI Units) |
| `box-companion` | `/box-companion` | Describe a binary file (uses Box AI Extract on Business+) | All |
| `box-ai-extract` | `/box-ai-extract` | Schema-driven metadata extraction via Box AI | Business+ (AI Units) |
| `box-team` | `/box-team` | Manage multi-team subtrees | All |
| `box-ai-agent` | `/box-ai-agent` | Manage persistent AI Studio "memory librarian" agent | Enterprise Advanced |
| `box-index-rebuild` | `/box-index-rebuild` | Refresh per-folder indexes | All |

## Setup

1. Connect Box's official remote MCP at `mcp.box.com` to your platform:
   - Claude Code / Cowork: Settings → Connectors → Box
   - Custom agent: configure the remote MCP (see CONNECTORS.md)
2. Run `/box-mcp-check` to verify the connection (official MCP, required scopes).
3. Run `/box-init my-workspace` to bootstrap.
4. The plugin auto-detects tier and routes accordingly. AI features are opt-in (set `settings.ai_recall_enabled: true` to enable; AI Units consumed per call).

## Repo

Full source, docs, examples, AI cost model, webhooks pattern, and design rationale: https://github.com/mrdulasolutions/BOX

Air-gapped variant: https://github.com/mrdulasolutions/BOX-Onprem

## License

MIT
