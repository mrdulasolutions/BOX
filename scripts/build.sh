#!/usr/bin/env bash
#
# build.sh — produce distributable artifacts for box-memory.
#
# Zip shape rules (verified against Claude docs, May 2026):
#
# - Cowork Plugins upload requires the zip to contain `.claude-plugin/plugin.json`
#   at the ZIP ROOT, with `skills/`, `commands/`, etc. also at root — no wrapping
#   directory. (Quote from docs: "All other directories must be at the plugin
#   root.")
#
# - Cowork Skills upload requires the zip to contain a folder named exactly the
#   skill name, with `SKILL.md` inside that folder. (Quote from docs: "The ZIP
#   should contain the Skill folder as its root.")
#
# Outputs:
#
#   dist/box-memory-plugin.zip     FLAT plugin zip — Cowork Plugins + Claude Code
#                                  Root: .claude-plugin/, skills/, commands/, ...
#
#   dist/box-memory-skills.zip     All skills bundled as skills/<name>/...
#                                  Drop-in for an agent that points at skills/
#
#   dist/skills/<name>.zip         WRAPPED per-skill zip — Cowork Skills upload
#                                  Root: <skill-name>/SKILL.md, <skill-name>/references/, ...
#
# Also runs a drift check: every skill's references/ and examples/ must match
# the canonical references/ and examples/ at the repo root. Drift exits non-zero.
#
# Usage:
#   scripts/build.sh                 build everything
#   scripts/build.sh --check         verify drift only, no zips
#   scripts/build.sh --sync          force-sync canonical refs into skills, then build

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DIST_DIR="$REPO_ROOT/dist"
SKILL_DIST_DIR="$DIST_DIR/skills"
CANONICAL_REFS="$REPO_ROOT/references"
CANONICAL_EXAMPLES="$REPO_ROOT/examples"

MODE="build"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
elif [[ "${1:-}" == "--sync" ]]; then
  MODE="sync"
fi

# ----- helpers -----

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

die() {
  red "ERROR: $*"
  exit 1
}

# Remove macOS AppleDouble files that get created on exFAT/non-HFS volumes.
clean_appledouble() {
  find "$1" -name '._*' -delete 2>/dev/null || true
  find "$1" -name '.DS_Store' -delete 2>/dev/null || true
}

# ----- skill discovery -----

discover_skills() {
  find skills -mindepth 1 -maxdepth 1 -type d | sort
}

# ----- validation -----

validate_skill() {
  local skill_dir="$1"
  local skill_name
  skill_name="$(basename "$skill_dir")"

  [[ -f "$skill_dir/SKILL.md" ]] || die "skill '$skill_name' missing SKILL.md"

  # Frontmatter must start with --- on line 1 and contain a name: field.
  head -1 "$skill_dir/SKILL.md" | grep -q '^---$' || die "skill '$skill_name': SKILL.md must start with YAML frontmatter (---)"
  grep -q '^name:' "$skill_dir/SKILL.md" || die "skill '$skill_name': SKILL.md frontmatter missing 'name' field"
  grep -q '^description:' "$skill_dir/SKILL.md" || die "skill '$skill_name': SKILL.md frontmatter missing 'description' field"

  # Cross-check name field matches directory name (warning, not fatal).
  local declared_name
  declared_name="$(grep '^name:' "$skill_dir/SKILL.md" | head -1 | sed -E 's/^name:[[:space:]]*//' | tr -d ' \t')"
  if [[ "$declared_name" != "$skill_name" ]]; then
    yellow "WARN: skill '$skill_name' has frontmatter name '$declared_name' (mismatch)"
  fi
}

# ----- drift check -----

check_drift() {
  local skill_dir="$1"
  local skill_name
  skill_name="$(basename "$skill_dir")"
  local drift=0

  for canonical_file in "$CANONICAL_REFS"/*.md; do
    local fname
    fname="$(basename "$canonical_file")"
    local target="$skill_dir/references/$fname"
    if [[ ! -f "$target" ]]; then
      yellow "  drift: '$skill_name' missing references/$fname"
      drift=1
    elif ! diff -q "$canonical_file" "$target" >/dev/null 2>&1; then
      yellow "  drift: '$skill_name' references/$fname differs from canonical"
      drift=1
    fi
  done

  for canonical_file in "$CANONICAL_EXAMPLES"/example-*; do
    [[ -f "$canonical_file" ]] || continue
    local fname
    fname="$(basename "$canonical_file")"
    local target="$skill_dir/examples/$fname"
    if [[ ! -f "$target" ]]; then
      yellow "  drift: '$skill_name' missing examples/$fname"
      drift=1
    elif ! diff -q "$canonical_file" "$target" >/dev/null 2>&1; then
      yellow "  drift: '$skill_name' examples/$fname differs from canonical"
      drift=1
    fi
  done

  return $drift
}

# ----- sync -----

sync_skill() {
  local skill_dir="$1"
  mkdir -p "$skill_dir/references" "$skill_dir/examples"
  cp "$CANONICAL_REFS"/*.md "$skill_dir/references/"
  for canonical_file in "$CANONICAL_EXAMPLES"/example-*; do
    [[ -f "$canonical_file" ]] || continue
    cp "$canonical_file" "$skill_dir/examples/"
  done
}

# ----- zip builders -----

build_skill_zip() {
  local skill_dir="$1"
  local skill_name
  skill_name="$(basename "$skill_dir")"
  local out="$SKILL_DIST_DIR/$skill_name.zip"

  clean_appledouble "$skill_dir"
  rm -f "$out"

  # Cowork Skills upload requires the zip to contain a folder named after the
  # skill (e.g. box-setup/SKILL.md), not SKILL.md at the zip root. We zip from
  # the parent so the directory name is preserved inside the archive.
  ( cd "$(dirname "$skill_dir")" && zip -rq "$out" "$skill_name" -x '._*' '.DS_Store' )
  blue "  built $skill_name.zip ($(du -h "$out" | awk '{print $1}'))"
}

build_skills_bundle_zip() {
  local out="$DIST_DIR/box-memory-skills.zip"
  rm -f "$out"
  clean_appledouble "$REPO_ROOT/skills"

  # Bundle ships the whole skills/ directory so consumers can drop it into
  # any plugin or agent setup that expects a skills/ folder.
  ( cd "$REPO_ROOT" && zip -rq "$out" skills -x '._*' '.DS_Store' )
  blue "  built box-memory-skills.zip ($(du -h "$out" | awk '{print $1}'))"
}

build_plugin_zip() {
  local out="$DIST_DIR/box-memory-plugin.zip"
  rm -f "$out"
  clean_appledouble "$REPO_ROOT"

  # Stage in a temp dir so we control exactly what goes in. Cowork Plugins
  # upload requires the plugin's contents to be at the ZIP ROOT (`.claude-plugin/`
  # at root, not nested in a `box-memory/` wrapper). For Claude Code, users
  # extract into a named subdirectory of ~/.claude/plugins/.
  local stage
  stage="$(mktemp -d)"
  trap "rm -rf '$stage'" EXIT

  cp -r .claude-plugin "$stage/"
  cp -r skills         "$stage/"
  cp -r commands       "$stage/"
  cp -r references     "$stage/"
  cp -r examples       "$stage/"
  cp README.md LICENSE CHANGELOG.md "$stage/"

  ( cd "$stage" && zip -rq "$out" . -x '._*' '.DS_Store' )

  blue "  built box-memory-plugin.zip ($(du -h "$out" | awk '{print $1}'))"
}

# ----- main -----

main() {
  command -v zip >/dev/null || die "zip not installed (brew install zip on macOS, apt install zip on Linux)"

  blue "==> validating manifest + skills (claude plugin validate)"
  if command -v claude >/dev/null 2>&1; then
    if ! claude plugin validate "$REPO_ROOT" 2>&1 | tee /tmp/box-memory-validate.log | grep -q "Validation passed"; then
      red "  claude plugin validate failed:"
      cat /tmp/box-memory-validate.log | sed 's/^/    /'
      die "fix the validation errors above before building zips"
    fi
    green "  claude plugin validate: passed"
  else
    yellow "  WARN: 'claude' CLI not found — skipping plugin validate (install Claude Code to enable)"
  fi

  blue "==> validating skill structure"
  while IFS= read -r skill_dir; do
    validate_skill "$skill_dir"
  done < <(discover_skills)
  green "  ok"

  blue "==> drift check"
  local any_drift=0
  while IFS= read -r skill_dir; do
    if ! check_drift "$skill_dir"; then
      any_drift=1
    fi
  done < <(discover_skills)

  if [[ "$any_drift" -eq 1 ]]; then
    if [[ "$MODE" == "check" ]]; then
      red "drift detected (run scripts/build.sh --sync to fix)"
      exit 1
    elif [[ "$MODE" == "sync" ]]; then
      yellow "  drift detected — syncing"
      while IFS= read -r skill_dir; do
        sync_skill "$skill_dir"
      done < <(discover_skills)
      green "  synced"
    else
      yellow "  drift detected — continuing build with current per-skill state"
      yellow "  run 'scripts/build.sh --sync' to refresh skill copies from canonical"
    fi
  else
    green "  in sync"
  fi

  if [[ "$MODE" == "check" ]]; then
    green "==> check complete, no drift"
    exit 0
  fi

  blue "==> building skill zips"
  mkdir -p "$SKILL_DIST_DIR"
  rm -f "$SKILL_DIST_DIR"/*.zip
  while IFS= read -r skill_dir; do
    build_skill_zip "$skill_dir"
  done < <(discover_skills)

  blue "==> building skills-bundle zip"
  build_skills_bundle_zip

  blue "==> building plugin zip"
  build_plugin_zip

  blue "==> manifest"
  local total_size
  total_size="$(du -sh "$DIST_DIR" | awk '{print $1}')"
  echo "  dist/ total: $total_size"
  echo
  echo "  Plugin zip (Claude Code):"
  echo "    dist/box-memory-plugin.zip"
  echo
  echo "  Skills bundle (all 7 skills together, drop into a plugin or agent skills dir):"
  echo "    dist/box-memory-skills.zip"
  echo
  echo "  Individual skill zips (Claude Cowork, or any agent that accepts skill zips):"
  while IFS= read -r f; do
    echo "    $f"
  done < <(ls "$SKILL_DIST_DIR"/*.zip 2>/dev/null | sort)

  green "==> done"
}

main "$@"
