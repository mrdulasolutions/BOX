---
name: box-mcp-check
description: Verify the connected Box MCP server. Confirms whether the user is on Box's official remote MCP at mcp.box.com (recommended; required for Box AI tools) or a community/deprecated Box MCP. Reports OAuth scopes granted and tool coverage. Use when setting up box-memory for the first time, when AI tools fail with "tool not found" errors, or when the user asks which Box MCP they're using.
argument-hint: "[--detail]"
---

# /box-mcp-check

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Audit the user's Box MCP connection. The cloud plugin works against any Box MCP that exposes basic file operations, but only Box's **official remote MCP at `mcp.box.com`** exposes the full toolset (Box AI Ask, AI Extract, AI Agents, Hubs, Doc Gen).

This skill detects which MCP is connected and reports the gaps — pushing users toward the canonical surface.

## Usage

```
/box-mcp-check [--detail]
```

Examples:
- `/box-mcp-check` — quick summary
- `/box-mcp-check --detail` — full tool inventory and scope diff vs the official MCP

## What to do

1. **Identify the connected Box MCP.** Call `who_am_i` (the canonical Box MCP exposes this). Inspect:
   - Server name / identifier from the response
   - Connected user email and enterprise ID
   - Token scopes granted

2. **Detect MCP variant.** Cross-reference against known signatures:

   | Signature | Variant |
   |---|---|
   | Server name `box-remote-mcp`, URL `mcp.box.com`, scopes include `ai.readwrite` and `docgen.readwrite` | **Official Box remote MCP** (recommended) |
   | Server name from `hmk/box-mcp-server` or any GitHub-community repo | **Community Box MCP** |
   | Server name from `box/mcp-server-box` (self-hosted) | **Deprecated self-hosted Box MCP** (Box no longer recommends) |
   | None of the above | **Unknown** — could be a custom MCP or a relay |

3. **Inventory exposed tools.** Probe whether the following tools are available (each is a separate MCP introspection call or attempted no-op invocation):

   | Tool name | Required for | Present on official MCP? |
   |---|---|---|
   | `who_am_i` | Identity check | Yes |
   | `list_folder_content_by_folder_id` | All workspace ops | Yes |
   | `upload_file` | `box-write`, `box-companion` | Yes |
   | `get_file_content` | `box-recall`, `box-index-rebuild` | Yes |
   | `search_files_keyword` | `box-recall`, `box-write` slug collision check | Yes |
   | `search_files_metadata` | `box-recall` Business+ structured queries (known broken — see operational-notes Note 1) | Yes (but broken; use keyword + mdfilters instead) |
   | `create_metadata_template` | `box-init` (Business+) | Yes |
   | `set_file_metadata` | `box-write` (Business+ metadata instance) | Yes |
   | `box_ai_ask` | `box-ai-recall` | **Official only** |
   | `box_ai_extract_structured` | `box-ai-extract`, `box-companion` AI path | **Official only** |
   | `box_ai_agents_*` (create/invoke/update) | `box-ai-agent` | **Official only** |
   | `list_hubs` / `create_hub` / Hub item management | `box-init --as-hub`, `box-ai-recall` hub mode | **Official only** |
   | `list_docgen_templates` / `create_docgen_batch` | (future — Doc Gen integration) | **Official only** |

4. **Check OAuth scopes** if accessible. Box's MCP integrations support these scope grants:
   - `root_readwrite` (file/folder operations)
   - `ai.readwrite` (Box AI tools)
   - `docgen.readwrite` (Doc Gen tools)
   - `manage_managed_users` (admin operations — not needed by this plugin)
   - `manage_enterprise_properties` (template create — needed for `box-init` on Business+)

5. **Report.** Two formats depending on `--detail`:

### Quick mode (default)

```
Box MCP check

Connected MCP:        <variant>
Server identifier:    <name>
URL (if applicable):  <url>
User:                 <email>
Enterprise:           <enterprise_id>

Status:               <PASS | DEGRADED | INCOMPATIBLE>
  PASS         — official MCP, all Box AI tools available
  DEGRADED     — alternate MCP works for basics; AI/Hubs/Doc Gen tools unavailable
  INCOMPATIBLE — missing core tools (upload/list/search); plugin can't function

Box AI tools:         <available | unavailable>
Box Hubs support:     <available | unavailable>
Recommended action:   <if not PASS: "Switch to mcp.box.com via your platform's connector settings">
```

### Detail mode (`--detail`)

Adds:
- Per-tool present/absent matrix
- OAuth scopes granted vs needed
- Specific recommendations for missing tools (which scopes to add, which integration to install)
- Migration steps if on the deprecated self-hosted MCP

## Recommendations the skill surfaces

If **not on official MCP**:

```
You're on <variant>. To unlock Box AI, Hubs, and Doc Gen:

1. In your platform's settings:
   - Claude Code: settings → Connectors → Box → enable
   - Claude Cowork: settings → Connectors → Box → enable
   - Custom agent: configure remote MCP at mcp.box.com

2. In Box Admin Console:
   - Integrations → enable "Box MCP server" predefined integration
   - Grant scopes: root_readwrite, ai.readwrite, docgen.readwrite
   - Save and re-authorize

3. Disconnect the current Box MCP from your agent platform.

4. Reconnect — the official MCP at mcp.box.com will be available.

This unlocks the AI-powered skills: /box-ai-recall, /box-ai-extract, /box-ai-agent, and Hub workspaces via /box-init --as-hub.

The plugin's other skills (box-write, box-recall, box-companion, box-team, etc.) work on any compatible MCP — you just lose the AI features.
```

If **OAuth scopes incomplete** (on official MCP but missing `ai.readwrite`):

```
You're on the official Box MCP but the `ai.readwrite` scope isn't granted to your token. Box AI calls will fail with 403.

Fix:
1. Disconnect the current Box MCP integration from your platform.
2. In Box Admin Console → your MCP integration → add `ai.readwrite` to the granted scopes.
3. Reconnect — the new scope takes effect on the next OAuth flow.

Until reconnected, AI-powered skills (/box-ai-recall, /box-ai-extract, /box-ai-agent) will return 403. Other skills work normally.
```

If **deprecated self-hosted Box MCP**:

```
You're on the deprecated self-hosted Box MCP (`box/mcp-server-box`). Box says don't start new projects with it; the remote MCP at mcp.box.com is the supported surface.

The self-hosted variant still works for basics but won't get future Box AI features. Migrate when convenient:

[same steps as the not-on-official case above]
```

## When to invoke

- At first install / `/box-init` (called internally to confirm setup is correct)
- When any AI-powered skill returns "tool not found" or "scope insufficient"
- When the user asks "which Box MCP am I using?"
- Periodically (the skill is cheap; running on session start is fine)

## When NOT to invoke

- Box MCP works and you don't suspect a problem — no reason to re-check
- User is on the on-prem variant (no MCP at all — this skill is cloud-only)

## Errors to surface clearly

- **No Box MCP connected at all** → "No Box MCP detected. Install the official Box remote MCP via your platform's Connectors settings; recommended URL: mcp.box.com."
- **Multiple Box MCPs connected simultaneously** → "Multiple Box MCPs detected. The plugin uses whichever the agent calls; behavior may be unpredictable. Disable all but the official remote MCP."
- **MCP responds but `who_am_i` fails** → "Box MCP is connected but authentication is broken. Re-authorize in your platform's settings."

## Don't

- Don't try to fix the MCP connection from within the skill. Box MCP installation is platform-side; surface clear instructions, don't attempt programmatic install.
- Don't claim a tool is missing without probing — sometimes MCPs lazy-load tool lists.
- Don't recommend community MCPs as alternatives. Box's official is the supported surface; community options are best-effort.

## References

- [Box MCP overview](https://developer.box.com/guides/box-mcp) — for human readers
- [Box remote MCP setup](https://developer.box.com/guides/box-mcp/remote)
- [Box MCP tools reference](https://developer.box.com/guides/box-mcp/tools)
- [Box CCG guide (for non-MCP integrations)](https://developer.box.com/guides/authentication/client-credentials)
- references/tier-matrix.md — what each tier unlocks
- references/operational-notes.md — including stale-OAuth-token diagnosis
