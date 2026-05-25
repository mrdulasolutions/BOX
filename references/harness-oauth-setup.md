# Harness OAuth Setup

How to wire the Box MCP into agent harnesses that don't transparently handle OAuth (i.e., everything other than Claude Code / Cowork, which negotiate the OAuth flow for you in Settings → Connectors).

This doc is **source data** for `/box-mcp-check --harness=<name>`. The skill surfaces the relevant section based on which harness the user identifies.

## Why this exists

Box's OAuth server **does not support Dynamic Client Registration (DCR)**. Harnesses that try to auto-register as an OAuth client against `mcp.box.com` get a 401. Every non-Claude harness must:

1. Have the user pre-create a **Box Custom App** in the developer console
2. Inject the resulting `client_id` + `client_secret` into the harness's MCP server config
3. Set whatever flag the harness uses to mark the server as OAuth-authenticated (this varies per harness and is the #1 source of silent failures — see Hermes below)
4. Trigger the harness's OAuth flow once to mint the initial token

After step 4, the harness caches tokens and auto-refreshes. Re-auth is only needed on token expiry or scope change.

## Model floor for setup

The setup flow touches: browser-based dev-console navigation, copying credentials, editing YAML/TOML config, parsing error messages, identifying silent failure modes ("Auth: none" looks benign but means 401).

**Verified working:** Claude 4.5+, Claude 4.7 (tested in Hermes).
**Likely to stall:** smaller/older models. Hermes's first attempt nearly missed the `auth: oauth` requirement because the failure mode is non-obvious.

**Workaround for weak-model deployments:** have a Claude 4.5+ session do the one-time setup, then any model can use the connection afterwards. Tokens persist in harness config; the agent doesn't redo OAuth per session.

## Required Box developer console setup

This is the same for every harness. Differences below are per-harness config files and quirks.

1. Go to https://app.box.com/developers/console
2. **Create New App → Custom App → User Authentication (OAuth 2.0)**
3. Name it after the harness (e.g. "Hermes COO Agent", "OpenClaw Box", "Cursor Box")
4. In the **Configuration** tab:
   - **OAuth 2.0 Redirect URI:** set to your harness's exact redirect URI (see per-harness sections below)
   - **Application Scopes** — enable at minimum:
     - **Read/write all files** (maps to OAuth scope `root_readwrite`)
     - **Manage enterprise properties** (maps to `manage_enterprise_properties`, needed for `/box-init` metadata template creation on Business+)
     - **Manage AI** (maps to `ai.readwrite`, needed for `/box-ai-recall`, `/box-ai-extract`, `/box-ai-agent`)
   - Copy your **Client ID** and **Client Secret**
5. **Save Changes**

Optional admin step (if your enterprise has Box Admin Console restrictions):
- Box Admin Console → Apps → your new Custom App → authorize for the enterprise. Without this, scope grants may be limited even though the app config looks right.

## Required scopes by Box-console label vs OAuth scope

The Box developer console UI uses friendly labels; the OAuth tokens use scope strings. Mapping for clarity:

| Box console label | OAuth scope | Plugin features it unlocks |
|---|---|---|
| Read/write all files | `root_readwrite` | All file CRUD, all skills |
| Manage enterprise properties | `manage_enterprise_properties` | `/box-init` metadata template creation (Business+) |
| Manage AI | `ai.readwrite` | `/box-ai-recall`, `/box-ai-extract`, `/box-ai-agent` |
| Generate documents | `docgen.readwrite` | Future Doc Gen integration (not yet used) |
| Manage users | `manage_managed_users` | Admin operations (not used by plugin) |

If a harness reports the scope as the OAuth string, refer back to this table to translate.

---

## Harness: Hermes

Hermes is a Python-based agent harness. Config lives in `~/.hermes/config.yaml`.

### Redirect URI

```
http://127.0.0.1:8723/callback
```

Exact match required in your Box app's Configuration tab.

### Config block

Edit `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  box:
    url: https://mcp.box.com
    auth: oauth                # REQUIRED — see gotcha below
    oauth:
      client_id: <from Box app>
      client_secret: <from Box app>
      redirect_port: 8723
```

### The `auth: oauth` gotcha

**Without the top-level `auth: oauth` key**, `hermes mcp test box` reports `Auth: none` and the server 401s — even though the `oauth:` block parsed correctly. This is the #1 setup failure mode.

If you see `Auth: none` in `hermes mcp test` output:

```bash
cd ~/.hermes && python3 -c "
import yaml
with open('config.yaml') as f: cfg = yaml.safe_load(f)
cfg['mcp_servers']['box']['auth'] = 'oauth'
with open('config.yaml','w') as f: yaml.safe_dump(cfg, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
print(cfg['mcp_servers']['box'])
"
```

Then re-run `hermes mcp test box`. Should report `Auth: OAuth 2.1 PKCE`.

### Trigger OAuth flow

```bash
hermes mcp test box
```

Opens browser, prompts Box login, click Authorize. Hermes captures the callback on port 8723 and caches the token.

### Post-OAuth reload

Hermes loads MCP tools at session startup (for prompt caching). After OAuth, in-session box-* skills won't see the live toolset until:

- Start a new Hermes session (`/new`), OR
- Run `/reload-mcp` in the current session

Confirm with `hermes mcp list` — Box should show as connected with 30 tools available.

### Token lifecycle

Hermes auto-refreshes OAuth tokens. No periodic re-auth needed unless:
- Token revoked from Box Admin Console
- Scopes changed (need to re-OAuth to widen grants — see operational-notes.md Note 2)
- Box account password rotated (some tenants enforce token invalidation)

### Verified

- Hermes + Claude 4.7 + Box Custom App + 30 tools live (2026-05-25)

---

## Harness: Generic (OpenClaw, Codex, Cursor, custom)

For any harness that supports remote MCP servers but expects pre-registered OAuth.

### Required info from the user

Before running `/box-mcp-check --harness=generic`, the agent should ask:

1. **What's your harness's redirect URI?** Most use `http://127.0.0.1:<port>/callback` with a fixed port. If you don't know, check the harness's docs or run its OAuth setup command in dry-run / verbose mode.
2. **Where does your harness's MCP config live?** Common patterns:
   - `~/.<harness-name>/config.{yaml,toml,json}`
   - `~/.config/<harness-name>/mcp.json`
   - Environment variables (`<HARNESS>_MCP_<NAME>_*`)
3. **Does your harness need an explicit `auth: oauth` flag** (or equivalent), separate from the credentials block?

The Box dev console setup is the same as Hermes — only the redirect URI changes per harness.

### Common patterns

| Harness | Redirect URI (typical) | Config location | Auth flag name |
|---|---|---|---|
| **OpenClaw** | `http://localhost:11434/callback` (confirm in your install) | `~/.openclaw/mcp_servers.json` | `auth_type: "oauth"` |
| **Codex (OpenAI)** | `http://127.0.0.1:8080/oauth/callback` (confirm in your install) | `~/.codex/mcp.toml` | `[mcp.box.auth] type = "oauth"` |
| **Cursor** | `cursor://mcp-callback` (custom protocol; consult Cursor's MCP docs) | Cursor settings → MCP servers | UI toggle |
| **Custom** | Per your implementation | Per your implementation | Per your implementation |

These are best-effort starting points — **always verify against your harness's official docs**. Plugin maintainers don't track every harness's OAuth quirks.

### Post-OAuth reload

Most harnesses load MCP tools at session start. After OAuth completes, start a new session or invoke the harness's reload command. If skills report "tool not found" after a successful OAuth, this is almost always the cause.

---

## Harness: Claude Code / Cowork (no action needed)

Claude Code and Cowork handle Box OAuth transparently via Settings → Connectors → Box. The user toggles Box on, OAuth happens in the browser, tokens are managed by the platform.

This is the **easiest path** — no developer console steps needed, no client_id/secret to manage. The Anthropic-side Box integration is a pre-registered OAuth app maintained by Anthropic.

`/box-mcp-check --harness=claude` (the default for Claude users) verifies:
- Box is enabled in Connectors
- The official remote MCP at `mcp.box.com` is the connected server
- OAuth scopes are sufficient

If not, surface the platform's Connectors UI rather than the developer console flow.

---

## Token scope upgrades

Once you have OAuth working, **adding new scopes later requires re-authorization**. The OAuth scope set is locked at token-mint time; bumping your Box plan or enabling new Custom App scopes does NOT widen the existing token. (See `references/operational-notes.md` Note 2.)

Process to widen scopes:

1. Update the Box Custom App's enabled scopes in the developer console
2. Save Changes
3. In your harness, delete the cached Box OAuth tokens (location varies; check harness docs)
4. Re-trigger the OAuth flow — the harness mints a fresh token with the updated scope set

This trips users frequently when upgrading from Business to Enterprise+ (gaining metadata template create) or enabling Box AI (gaining `ai.readwrite`). The Box plan upgrade is invisible to the OAuth token until you re-auth.

---

## Contributing a new harness section

If you're using a harness not documented here:

1. Follow the **Generic** section, capturing the harness's redirect URI, config location, and any auth-flag-key quirks
2. Verify the box-* skills work end-to-end (e.g., `/box-init` succeeds, `/box-write` saves a memory)
3. Open a PR adding a new section to this file under `## Harness: <name>` with:
   - Redirect URI
   - Config block (YAML/TOML/JSON as appropriate)
   - Setup gotchas you encountered (silent failure modes are gold — capture them)
   - Post-OAuth reload behavior
   - Token lifecycle notes
   - "Verified" line: `<harness> + <model> + Box Custom App + N tools live (YYYY-MM-DD)`

The bar is empirical, not theoretical — sections must come from real working setups.

## See also

- `references/operational-notes.md` Note 2 — stale OAuth after tier upgrade
- `skills/box-mcp-check/SKILL.md` — surfaces this doc via `--harness=` flag
- [Box developer console](https://app.box.com/developers/console)
- [Box OAuth 2.0 guide](https://developer.box.com/guides/authentication/oauth2/)
- [Box CCG guide](https://developer.box.com/guides/authentication/client-credentials) — for *headless* agents that don't need user-attributed calls
