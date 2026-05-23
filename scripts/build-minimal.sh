#!/usr/bin/env bash
#
# build-minimal.sh — Experiment A from the v0.1.8 research report.
#
# Builds a stripped-down test plugin matching Anthropic's customer-support
# layout exactly:
#
#   box-memory-minimal/
#   ├── .claude-plugin/plugin.json
#   ├── .mcp.json
#   ├── CONNECTORS.md
#   ├── LICENSE
#   ├── README.md
#   └── skills/
#       └── box-init/
#           └── SKILL.md       (only — no references/, no examples/)
#
# Goal: if Cowork accepts THIS, we know the full plugin failed because of
# structural bloat (per-skill duplicates, extra top-level dirs, file count).
# If Cowork rejects this too, the cause is something else (possibly the
# server-side bug in claude-code#24328) and we need a different approach.
#
# All files chmod'd to 0644 (matches Anthropic). Dirs 0755. Zipped with
# zip -X (no extended attrs) for clean output.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

STAGE="$(mktemp -d)"
trap "rm -rf '$STAGE'" EXIT

OUT="$DIST_DIR/box-memory-minimal.zip"
PKG="$STAGE/box-memory-minimal"

mkdir -p "$PKG/.claude-plugin" "$PKG/skills/box-init"

# ---------- .claude-plugin/plugin.json (4-field, matches Anthropic) ----------
cat > "$PKG/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "box-memory",
  "version": "0.1.9-minimal",
  "description": "Use Box.com as agent memory + file storage. Markdown memories with frontmatter, paired companions for binaries, instant index-file recall.",
  "author": {
    "name": "MR Dula Solutions"
  }
}
EOF

# ---------- .mcp.json (empty mcpServers; minimal valid shape) ----------
# Anthropic plugins declare HTTP MCP servers here. For box-memory, the user
# already has the Box MCP connected separately — we don't declare a public
# Box URL since the connector setup is environment-specific. Empty object
# is valid per the .mcp.json spec.
cat > "$PKG/.mcp.json" <<'EOF'
{
  "mcpServers": {}
}
EOF

# ---------- CONNECTORS.md (slim, matches Anthropic's style) ----------
cat > "$PKG/CONNECTORS.md" <<'EOF'
# Connectors

## How tool references work

This plugin's skills assume a Box MCP server is connected to your agent platform. The plugin does not manage Box authentication itself — the skills invoke Box MCP tools you've already authorized.

## Connectors for this plugin

| Category | Placeholder | Required server | Where to install |
|----------|-------------|----------------|------------------|
| File storage | `~~box` | Box MCP | Your platform's MCP / Connectors settings |

## Setup

1. In Claude Cowork / Claude Code / your agent platform, open MCP or Connector settings.
2. Add the Box MCP server and authorize it (OAuth flow to your Box account).
3. Once Box is connected, the `box-init` skill can bootstrap a workspace.

That's it. Tier detection (Personal vs Business vs Enterprise), schema handling, and recall routing all happen inside the skill — no further setup needed.
EOF

# ---------- LICENSE (copy of repo LICENSE) ----------
cp "$REPO_ROOT/LICENSE" "$PKG/LICENSE"

# ---------- README.md (slim, mirrors Anthropic structure) ----------
cat > "$PKG/README.md" <<'EOF'
# Box Memory Plugin (minimal test build)

This is a **minimal experimental build** of the box-memory plugin, shipped to test whether the full release fails Cowork validation because of structural bloat. It contains only one skill (`box-init`) and matches Anthropic's published plugin layout exactly.

The full plugin with all 8 skills (`box-init`, `box-write`, `box-recall`, `box-companion`, `box-team`, `box-status`, `box-tier-detect`, `box-index-rebuild`) lives in the v0.1.8 release. If this minimal build installs cleanly in Cowork, the full plugin will be re-released matching the same structural template.

## Installation

```
claude plugins add knowledge-work-plugins/customer-support
```

Or upload `box-memory-minimal.zip` to Cowork via Plugins → Add plugin.

## What it does

Bootstraps a Box.com workspace as agent memory + file storage. Detects your Box account tier (Personal / Business / Enterprise) and routes accordingly — index files on Personal, custom metadata templates on Business+.

## Skills

| Skill | Description |
|---|---|
| `box-init` | Bootstrap a box-memory workspace at a chosen Box folder. Tier-aware. |

## Repo

Full source: https://github.com/mrdulasolutions/BOX
EOF

# ---------- skills/box-init/SKILL.md (mirrors draft-response style) ----------
cat > "$PKG/skills/box-init/SKILL.md" <<'EOF'
---
name: box-init
description: Bootstrap a Box.com workspace for agent memory and file storage. Creates the standard folder structure, writes the workspace config, detects Box account tier and capabilities, and on Business+ tier optionally creates a metadata template for instant recall. Use when the user wants to set up box-memory, initialize a workspace, or create a Box vault for the first time.
argument-hint: "[workspace-name]"
---

# /box-init

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Bootstrap a fresh box-memory workspace on the user's Box account, or add structure to an existing one. Tier-aware — Personal uses index files, Business+ unlocks metadata templates.

## Usage

```
/box-init [workspace-name]
```

Examples:
- `/box-init` — creates a workspace named `box-memory` at Box root
- `/box-init my-vault` — creates a workspace named `my-vault`
- `/box-init my-vault --team=engineering` — workspace with an extra team subtree

## What to do

1. **Detect tier first.** Probe Box's metadata template scope. If `list_metadata_templates(scope="enterprise")` succeeds, the account is Business or higher. If it errors with "user does not have an enterprise", the account is Personal/Free. Capability flags: `custom_metadata_templates`, `body_search`, `max_file_size_mb`, `box_sign`, `retention_policies`, `legal_holds`. Cache the result in `_box-memory.json`.

2. **Check for existing workspace.** Search the parent folder for `_box-memory.json`. If found, don't overwrite — offer to use the existing workspace, create alongside, or re-initialize (destructive confirm).

3. **Create folder structure.** Under the workspace root, create:
   - `memories/` — default-scope markdown memory files
   - `files/` — binary uploads
   - `teams/<default-team>/memories/` plus `teams/<default-team>/files/`
   - `_archive/` — for `status: archived` memories (optional, on demand)

4. **Write workspace config.** Build `_box-memory.json` with tier, capabilities, folder IDs, agent identifier, and settings (default team, companion layout, recall preferences). Upload as `_box-memory.json` at the workspace root.

5. **Seed index files.** Upload empty `_index.json` to each memory-holding folder with the canonical structure (entries array, inverted maps for id/slug/title/kind/tag).

6. **Business+ tier only — create metadata template.** If capabilities allow and the current user can create templates, create the `boxMemory` enterprise-scope template with fields: memory_id, slug, title, kind (enum), status (enum), team, agent, tags, companion_for_file_id, sha256, created_at, updated_at. Set `metadata_template_key` and `metadata_template_created_at` in the workspace config.

7. **Warm-up window.** Surface to the user: bulk `mdfilters` queries against a fresh template need ~10 minutes to return correct results (Box behavior, not a bug). During the warm-up, the index-file path is the primary recall route.

8. **Write workspace README.** Upload a brief `README.md` to the workspace root explaining the layout.

9. **Report.** Confirm workspace details: name, root path, tier, teams, capabilities, routing strategy, and next-step commands.

## Idempotency

Running with the same name should be safe — re-use existing folders, don't overwrite `_box-memory.json` without confirmation, preserve existing `_index.json` content. Don't write memory files in setup. Setup is structure only.

## Errors to surface clearly

- **Box MCP not connected** → "Connect Box MCP via your platform's MCP configuration, then retry."
- **Permission denied on parent folder** → "Choose a different parent folder or get write access."
- **409 conflict on workspace folder name** → "Pick a different name or use the existing folder."
- **Stale OAuth token after Box tier upgrade** → Reconnect Box MCP in your platform's settings; OAuth scopes don't widen automatically after account upgrade.

## Don't

- Don't create a workspace at Box root unless explicitly asked. Default parent should be confirmed.
- Don't write memory files in setup — structure only.
- Don't fail because tier detection was ambiguous. Use the lowest-common-denominator path (index files) and proceed.
- Don't claim compliance certifications without user declaration — the Box API doesn't expose them.
EOF

# ---------- Set permissions to match Anthropic (0644 files, 0755 dirs) ----------
find "$PKG" -type f -exec chmod 0644 {} \;
find "$PKG" -type d -exec chmod 0755 {} \;

# ---------- Strip any AppleDouble cruft from exFAT volume ----------
find "$PKG" -name '._*' -delete 2>/dev/null || true
find "$PKG" -name '.DS_Store' -delete 2>/dev/null || true

# ---------- Validate before zipping ----------
echo "==> validating manifest + skill"
if command -v claude >/dev/null 2>&1; then
  claude plugin validate "$PKG"
fi

# ---------- Zip flat (no wrapper dir), matches our shipped v0.1.4+ layout ----------
# Flat means: unzip dumps .claude-plugin/, .mcp.json, etc. at the cwd, not
# inside a box-memory-minimal/ folder. This matches the shape of our full
# plugin zip — keeps the experiment variables isolated to *contents*, not
# packaging shape.
rm -f "$OUT"
( cd "$PKG" && zip -rqX "$OUT" . -x '._*' '.DS_Store' )

# ---------- Report ----------
echo
echo "==> built $OUT"
echo
echo "Contents:"
unzip -l "$OUT"
echo
echo "Permissions (first 5 entries):"
unzip -Z "$OUT" | head -10
echo
echo "Total size: $(du -h "$OUT" | awk '{print $1}')"
