# Operational notes

Findings from live testing of box-memory against a real Box account that the canonical reference docs don't already cover. Read this if you're hitting unexpected behavior — most of these are upstream quirks (Box, OAuth, MCP) rather than plugin bugs.

Each note has the symptom, the verified cause, and the workaround. If you discover a new one, add it here and link to it from wherever else in the docs the issue would surface.

---

## 1. `search_files_metadata` MCP wrapper returns empty when data exists

**Symptom:** The Box MCP's dedicated metadata-query tool (`search_files_metadata` or equivalent name) returns an empty result set even when you can see the matching files in Box's web UI and they have correctly applied metadata template instances.

**Cause:** The MCP wrapper around Box's Metadata Query API does not pass through query parameters correctly in current implementations. The underlying Box REST endpoint (`POST /metadata_queries/execute_read`) works correctly; the wrapper does not.

**Workaround:** Use `search_files_keyword` with the `mdfilters` parameter to filter by metadata. Route every bulk metadata query through keyword search with filters — never the dedicated metadata-query tool.

**Implementation impact:** `box-recall` Step 4 (Business+ structured filter path) calls `search_files_keyword` with a non-empty query (see [Note 4](#4-keyword-search-requires-a-non-empty-query-parameter)) plus `mdfilters` for the actual filtering. The behavior is correct; the tool name is misleading.

**Tracking:** If a future MCP version fixes `search_files_metadata`, the skill should still prefer `search_files_keyword + mdfilters` for now — switching back would mean re-testing. Update this note when the wrapper is verified working.

---

## 2. OAuth token scope does not widen on tier upgrade

**Symptom:** You upgrade your Box account (e.g., Personal → Business) and then a metadata-template-create operation fails with `403 forbidden` or `insufficient scope`, even though your account now has the permission.

**Cause:** The OAuth token you authorized before the upgrade was scoped to the capabilities your account had *at the time of authorization*. Token scopes don't dynamically widen when the account's plan changes. Box's OAuth tokens are immutable — the only way to widen scope is to issue a new token.

**Workaround:** After any tier change (upgrade, plan change, role change), disconnect and reconnect the Box MCP in your platform's MCP configuration. This forces a fresh OAuth flow and a new token with the current scope set.

**Implementation impact:** `box-tier-detect` should surface this explicitly when it detects capability mismatches between what the account *should* support (based on plan) and what the token *can do* (based on observed 403s). See [Note 3](#3-fresh-metadata-templates-have-a-~10-minute-warm-up-window) for a related symptom that looks similar but has a different cause.

**Recovery flow for users:**

1. Note current state: workspace works, but a feature is failing with 403.
2. Go to your platform's MCP/connector settings.
3. Disconnect Box.
4. Reconnect Box (full OAuth flow — accept the scope grants).
5. Retry the failing operation.

If retry still fails after reconnect, the issue is *not* a stale token — escalate to [Note 3](#3-fresh-metadata-templates-have-a-~10-minute-warm-up-window) or check Box admin permissions.

---

## 3. Fresh metadata templates have a ~10-minute warm-up window

**Symptom:** You create a new metadata template, immediately apply it to a file, then query for that file via `mdfilters`. The query returns empty — even though the file definitively has the template applied.

**Cause:** Box's documentation states Metadata Query is real-time. Empirically it is not for *freshly created templates*. After template creation, there's a ~10-minute warm-up before bulk queries return correct results. Direct file metadata reads work immediately; bulk filter-based queries do not. This appears to be similar in mechanism to Box's 10-minute Search API indexing lag but for the metadata index specifically.

**Workaround for `box-init`:**

- Create the template.
- Apply it to one canary file.
- Surface a note to the user: *"Metadata template `<key>` created. Bulk queries via mdfilters may take ~10 minutes to return correct results for freshly-applied instances. Direct file fetches work immediately. The `_index.json` fallback path is unaffected."*
- Don't block setup on the warm-up completing.

**Workaround for `box-recall`:**

- On Business+ tier, if `mdfilters`-based queries return suspiciously empty results within 10 minutes of any template-related change, fall through to the `_index.json` path automatically.
- Mention to the user when this fallback fires (so they know why the path is slower than usual).

**Detection:** Track template creation timestamps in `_box-memory.json` under `metadata_template_created_at`. If `now - created_at < 10 minutes`, prefer the index path over the metadata-query path.

---

## 4. Keyword search requires a non-empty query parameter

**Symptom:** You want to filter files only by metadata (`mdfilters`), with no text query. The `search_files_keyword` tool rejects an empty `query` field or returns no results.

**Cause:** Box's search endpoint treats `query` as required. The `mdfilters` parameter alone is insufficient to identify a search; the endpoint expects a query string and applies filters on top of the matches.

**Workaround:** Pass a common stopword as a pseudo-wildcard. `"the"` works well in English-language workspaces because virtually every document body contains it. Other safe options: `"a"`, `"is"`, or any short common word.

**Implementation:** Wherever the plugin issues a metadata-filtered search:

```text
search_files_keyword(
  query: "the",                    # pseudo-wildcard — required by endpoint
  mdfilters: [...your real filter...]
)
```

**Caveat:** This only matches files whose searchable content contains `"the"`. For workspaces of pure metadata-only files (which doesn't happen in practice — every memory has body text), pick a query word likely to appear. Markdown frontmatter alone won't satisfy the keyword match since frontmatter isn't always indexed; the body usually is.

---

## 5. `gt` comparison on float metadata fields is inclusive

**Symptom:** You query `mdfilters: {confidence: {gt: 0.9}}` expecting to get only files where `confidence > 0.9`. The result includes files where `confidence == 0.9`.

**Cause:** Either a floating-point representation issue in how Box stores and compares numeric metadata fields, or an off-by-one inclusivity behavior in the MCP wrapper. Not yet root-caused; reproducible empirically.

**Workaround:** Use a small epsilon when you genuinely need strict greater-than:

```text
# Instead of:    confidence > 0.9
# Use:           confidence > 0.9001
mdfilters: {confidence: {gt: 0.9001}}
```

For most agent-memory queries this distinction doesn't matter (you usually want "high confidence" which means `>= 0.9` anyway). Note this caveat in skill instructions where strict comparisons matter — e.g., `box-recall`'s confidence-based filtering.

**Also affects:** `lt`, `gte`, `lte` may behave similarly. If you're building a numeric range query and strict bounds matter, test against your data before relying on the comparison.

---

## 6. Metadata template name in live deployments may differ from canonical

**Symptom:** This repo's canonical metadata template is named `boxMemory` (defined in [schema.md](schema.md)). At least one live deployment used `agentMemory` as the template key, with a slightly simpler schema than the canonical one.

**Cause:** Naming drift between an early prototype and the documented canonical schema. Not a bug — just two names for similar things in the wild.

**Resolution options (pick one):**

### Option A — Migrate the live template to canonical

Recommended for new deployments and any deployment where the divergence is recent.

1. Export all instances of the legacy template (via `search_files_keyword` + `mdfilters` with the legacy template scope).
2. Apply the canonical `boxMemory` template to each file with mapped field values.
3. Delete the legacy `agentMemory` template after verifying all instances are migrated.
4. Update `_box-memory.json.metadata_template_key` to `boxMemory`.

### Option B — Update the repo to match what's live

Reasonable if you can't easily migrate, or if multiple downstream consumers depend on the legacy template name.

1. Document the alternate template name and field mapping in your workspace's `_box-memory.json` under `metadata_template_key`.
2. The plugin reads from `_box-memory.json`, not from a hardcoded value, so as long as the field names align, this works.
3. If field names *don't* align (e.g., legacy template lacks `companion_for_file_id`), the plugin will fall back to index-file-only mode for affected operations.

### What this plugin does by default

`box-init` creates the template using the canonical name `boxMemory`. If a workspace's `_box-memory.json` declares a different `metadata_template_key`, the plugin uses that key as-is for all operations — so manual override is supported.

If you're seeing dual templates (`boxMemory` and `agentMemory` both exist on the same account), pick one as authoritative and migrate or delete the other. Don't leave both active — recall behavior is ambiguous.

---

## When you find another quirk

Add a new numbered section here following the same shape:

```markdown
## N. Short symptom title

**Symptom:** ...
**Cause:** ...
**Workaround:** ...
**Implementation impact:** ...
```

Link to it from any other doc that would touch the issue. Operational lessons that nobody documents have a way of needing to be re-learned.
