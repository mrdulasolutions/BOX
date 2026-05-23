# Connectors

## How tool references work

This plugin's skills assume a Box MCP server is connected to your agent platform. The plugin does not manage Box authentication itself — the skills invoke Box MCP tools you've already authorized.

## Connectors for this plugin

| Category | Placeholder | Required server | Where to install |
|----------|-------------|-----------------|------------------|
| File storage | `~~box` | Box MCP | Your platform's MCP / Connector settings |

## Setup

1. In Claude Cowork, Claude Code, or your agent platform: open MCP / Connector settings.
2. Add the Box MCP server and authorize it (OAuth flow to your Box account).
3. Once Box is connected, the `box-init` skill can bootstrap a workspace.

That's it. Tier detection (Personal / Business / Enterprise), schema handling, and recall routing all happen inside the skills — no further setup needed.

## Why we don't pre-declare the Box MCP in `.mcp.json`

Box has multiple MCP server implementations (official Anthropic-built, community-built, custom enterprise deployments). Hardcoding a specific URL in `.mcp.json` would lock users into one of those — which isn't great when several work fine. The skills detect available Box tools at runtime and route accordingly, so any Box MCP your platform supports works.

If your platform requires explicit MCP server registration before plugin install, point it at whichever Box MCP server you prefer in your platform's MCP settings before running `/box-init`.
