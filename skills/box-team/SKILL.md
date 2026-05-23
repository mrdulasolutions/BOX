---
name: box-team
description: Add or manage a team subtree in a box-memory workspace. Creates a team folder under teams/<name>/ with its own memories/, files/, optional companions/, and _index.json - and updates the workspace config to track the new team. Folder ACLs are the real isolation boundary; this skill creates the structure but does not set permissions (use Box UI for that). Invoke when the user says "create a team", "add team X", "set up engineering team in Box", "let ops have their own memory", or runs /box-team <name>.
---

# box-team

You add a new team to a box-memory workspace, or manage existing team subtrees. Teams are how multi-team isolation works in this plugin — each team gets its own folder with its own indexes, and Box folder ACLs are the enforcement boundary.

## Why folder-ACL-based isolation

A frontmatter field `team: ops` is a hint. A folder permission that says *user X cannot read folder Y* is enforcement. The plugin separates the two on purpose: frontmatter is a categorization signal that anyone with read access to a memory can see; the ACL is the actual security boundary. If you want real isolation, set the folder ACL in Box (UI or admin API) — this skill creates the folder structure but does not set permissions for you. The Box MCP may or may not have the right tools to set ACLs depending on tier; in any case, the human-in-the-loop step of choosing who-has-access-to-what should not be automated silently.

## When you fire

- User says "create a team", "add team <name>", "set up <team> in Box", "let <team> have their own memory".
- User runs `/box-team <name>` or `/box-init --team=<name>` for an additional team.
- User wants to list existing teams, see team contents, or detect cross-team conflicts.

## Modes

This skill has several sub-modes inferred from the user's ask:

| Sub-mode | Trigger |
|---|---|
| Create | "add team", "create team", "set up a team" |
| List | "what teams exist", "show teams", "list teams" |
| Inspect | "what's in <team>", "show me <team>'s memories", `/box-team inspect <name>` |
| Conflict scan | "find duplicate memories across teams", "check for slug collisions", "are there conflicts" |
| Remove (rare) | "remove team", "delete team" — see *Remove* section |

## Create

### Inputs

- **Team name** — required. Kebab-case, lowercase, alphanumeric + hyphens. Examples: `engineering`, `ops`, `legal`, `customer-success`.
- **Companion layout** — defaults to the workspace's setting. Override if the team needs a different layout.
- **Initial agent allowlist** — optional. Capture which agents may write to this team. (Hint only — Box ACLs enforce.)

### What you do

1. **Verify workspace.** Read `_box-memory.json`. If missing, run `box-init` first.
2. **Verify the team name is valid** (no slashes, no spaces, lowercase). Suggest a clean version if not.
3. **Check for existing team.** If `_box-memory.json.teams[]` already contains the name, stop and report. Don't duplicate.
4. **Create folders under `teams/`:**
   - `teams/<name>/` (the team root)
   - `teams/<name>/memories/`
   - `teams/<name>/files/`
   - `teams/<name>/companions/` (only if folder layout)
   - Capture every folder ID.
5. **Seed `_index.json` files** in each new folder — same template as `box-init` Step 6.
6. **Update `_box-memory.json`:**
   - Append `<name>` to `teams[]`.
   - Append the team's `folder_ids` to the `folder_ids` map (using prefix `team_<name>_*` keys).
   - Bump `updated_at`.
   - Re-upload as a new version.
7. **Optional README in the team folder.** Brief: "This is the `<name>` team's box-memory subtree. Memories here are scoped to this team. To grant access, set Box folder ACLs on `<this folder>` in Box's web UI."
8. **Surface the access boundary clearly:**

```
✓ Team `<name>` created.

Folders:
  teams/<name>/             (Box folder ID: <id>)
  teams/<name>/memories/    (Box folder ID: <id>)
  teams/<name>/files/       (Box folder ID: <id>)
  teams/<name>/companions/  (Box folder ID: <id>, if folder layout)

⚠ Isolation reminder: Box folder ACLs are what actually keep this team's content 
private. To grant access, open Box web UI → Share Settings on the team folder, 
or have an admin set permissions via Box Admin Console. Frontmatter `team: <name>` 
on memories is a categorization signal, not an access control mechanism.

To write to this team:
  "Save this to the <name> team: <content>"
  /box-write --team=<name>

To recall from this team:
  /box-recall --team=<name> <query>
```

## List

### What you do

1. Read `_box-memory.json`.
2. Output the `teams[]` list, plus a brief stat per team (read each team's `_index.json` `entry_count` for a quick number):

```
Teams in workspace `<workspace-name>`:

  default          12 memories, 3 files
  engineering      47 memories, 8 files
  ops              23 memories, 0 files
  legal            5 memories, 2 files

To see contents:    /box-team inspect <name>
To add a team:      /box-team <new-team-name>
```

If a team folder is inaccessible (403), show "🔒 access denied" instead of counts. Don't fail the listing.

## Inspect

### What you do

1. Read the team's `memories/_index.json` (and `companions/_index.json` if folder layout).
2. Summarize:

```
Team: <name>

Memories (<count>):
  active:       <N>
    decision:     <n>
    fact:         <n>
    task:         <n>
    observation:  <n>
    reference:    <n>
    note:         <n>
  draft:        <N>
  superseded:   <N>
  archived:     <N>

Most recent:
  - <title> (<kind>, <updated_at>)
  - …

Top tags: <top 5 tag counts>

Files (<count>):
  - <filename> (<size>, companion: yes/no)
  …
```

Limit the output — recent N=5, top tags 5. If the user wants more, they can ask.

## Conflict scan

The thing that motivates this mode: when team A and team B independently write memories about the same topic, conceptually duplicate content appears under different IDs. The frontmatter `slug` is the easiest collision detector — same slug in two teams is a strong signal.

### What you do

1. Read every accessible team's `_index.json`.
2. Build a map: `slug` → `[(team, mem_id, title, updated_at), …]`.
3. Find slugs with more than one occurrence.
4. Also flag titles that match exactly across teams (different slugs but same title).
5. Optionally, flag near-duplicate titles (jaccard similarity > 0.7 on title tokens) — keep this off by default unless the user asks for "fuzzy" conflict detection.

Report:

```
Cross-team conflicts in workspace `<workspace-name>`:

Same slug in multiple teams:
  slug `auth-strategy-decision`:
    engineering / mem_01HABC… (active, updated 2026-05-12)
    ops         / mem_01HDEF… (active, updated 2026-05-15)
  
  slug `vendor-onboarding-checklist`:
    legal       / mem_01HGHI… (active, updated 2026-04-01)
    ops         / mem_01HJKL… (active, updated 2026-05-08)

Same title in multiple teams:
  …

No conflicts: <count of teams with no overlaps>

Resolution options:
  1. Leave as-is (different teams genuinely care about the same topic from different angles).
  2. Reconcile via shared workspace memory:
     /box-write --team=default <merged-content>
     Then mark each team's version superseded with superseded_by pointing to the shared memory.
  3. Rename one slug to be team-specific.
```

Don't auto-resolve — surface the conflict and let the user decide.

## Remove

Be cautious. Removing a team should:

1. **Confirm twice.** "This will remove the team folder from the config and stop tracking it. Memory files remain in Box untouched. Proceed?" Wait for explicit yes.
2. **Do not delete files.** Box has version history; data integrity matters. Only remove the team entry from `_box-memory.json.teams[]` and the corresponding `folder_ids.team_<name>_*` keys.
3. **Optionally move** the team's folder to `_archive/` if the user wants it out of the active workspace view. Move ≠ delete.
4. Report what was changed and what was preserved.

If the user actually wants to delete content, they should do it in Box web UI with appropriate retention/legal-hold awareness. This skill doesn't delete files.

## Idempotency

- Creating a team that already exists → noop with a report.
- Listing → safe to repeat.
- Inspecting → safe to repeat.
- Conflict scan → safe to repeat.
- Removing → confirmed action.

## Errors to surface clearly

- **Invalid team name** → suggest a clean version.
- **Permission denied creating folder** → "Can't create folder under `teams/`. Check parent folder permissions."
- **403 inspecting a team** → "No read access to team `<name>` (Box ACLs). Skipping." — continue with other teams.

## Don't

- Don't try to set Box folder ACLs automatically. The user should do this in Box web UI, with intent.
- Don't write memories during team setup. Setup is structure only — same rule as `box-init`.
- Don't delete memory files when a team is "removed" — the team is a config concept; files are durable artifacts.
- Don't proceed past Create without surfacing the access-control reminder. People will assume frontmatter is access control. It isn't.

## References

- `references/architecture.md` — why folder ACLs are the boundary
- `references/schema.md` — workspace config format including `teams[]` and `folder_ids`
