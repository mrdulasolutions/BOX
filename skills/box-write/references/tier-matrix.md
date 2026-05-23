# Box tier capability matrix

How tier affects what the plugin can do — and which fallback paths it uses where features aren't available.

---

## What's in every tier

These work the same on Personal, Business, Enterprise, and Enterprise Plus:

| Capability | Notes |
|---|---|
| Upload, download, list files | Standard REST API |
| File IDs (immutable, instant lookup) | The plugin's primary key |
| Folder structure | The plugin's organizing principle |
| File versioning | Built-in; new upload of same filename → new version |
| Filename + description search | But subject to ~10 minute indexing lag |
| 409 conflict on duplicate filename | The plugin uses this for collision safety |
| Webhooks (if enabled) | Out of scope for v1 but available |

---

## Tier-by-tier feature matrix

| Feature | Personal / Free | Business Starter | Business / Business Plus | Enterprise | Enterprise Plus / Government |
|---|---|---|---|---|---|
| **Max file size** | 250 MB | 2 GB | 5 GB | 50 GB | 500 GB |
| **Storage** | 10 GB | 100 GB | 100 GB / Unlimited | Unlimited | Unlimited |
| **Body full-text search (≤10 KB/doc)** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Custom metadata templates** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Metadata Query API** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Box Sign** | ❌ | Limited | ✅ | ✅ | ✅ |
| **Native CAD preview (DWG, DXF, RVT, IGES, STEP)** | Limited | Yes | Yes | Yes | Yes |
| **Retention policies** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Legal holds** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Box KeySafe (CMEK)** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **Box Zones (data residency)** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **Box Shield (threat detection)** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **Box Governance** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **Watermarking** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **SOC 1 / 2 / 3** | ❌ | Limited | ✅ | ✅ | ✅ |
| **HIPAA BAA available** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **FedRAMP Moderate** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **FedRAMP High** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **DoD IL4 (CUI)** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **ITAR alignment** | ❌ | ❌ | ❌ | Add-on | ✅ |
| **GxP / GDPR / GLBA / PCI** | Varies | Varies | ✅ | ✅ | ✅ |

*Verified against Box's published documentation as of 2026. Pricing tiers and exact line items change — verify with Box sales before relying on a specific certification.*

---

## Universal caveats (all tiers)

**Box Search API has a ~10 minute indexing lag.** From Box's own documentation: *"In most cases, you can expect newly added or changed files to be available via Box search in 10 minutes. The current service load determines the index time and it may take more than 10 minutes in some cases."* This applies to every tier including Enterprise.

**Box Search is fuzzy/prefix-only.** No infix or suffix matching. Wildcards limited. Treat as a discovery aid, not a system-of-record query.

**Body full-text indexing has a 10 KB cap per document.** Even on Business+. Anything past 10 KB of body text isn't searchable as text.

**Filename collisions return 409 (this is good).** No silent overwrite. The plugin uses this as a safety net.

**Direct ID-based fetch is always instant.** No matter the tier, `GET /files/<id>` is sub-second and reflects the current state. The plugin's index pattern leverages this.

**OAuth token scopes don't widen on tier upgrade.** If you upgrade your account (Personal → Business, etc.) and a template-create or metadata-write operation suddenly 403s, the issue is a stale OAuth token scoped to your old plan's permissions. Disconnect and reconnect the Box MCP to force a fresh token. See [operational-notes.md Note 2](operational-notes.md#2-oauth-token-scope-does-not-widen-on-tier-upgrade).

**Fresh metadata templates have a ~10-minute warm-up window.** Box's docs claim the Metadata Query API is real-time, but empirically a newly-created template needs ~10 minutes before bulk `mdfilters` queries return correct results. Direct file metadata reads work immediately. See [operational-notes.md Note 3](operational-notes.md#3-fresh-metadata-templates-have-a-~10-minute-warm-up-window).

---

## How the plugin routes by tier

The `box-tier-detect` skill probes the account once per workspace, caches the result in `_box-memory.json`, and other skills consult that cache.

### Personal / Free tier

| Operation | Strategy |
|---|---|
| Write memory | Markdown + frontmatter only. No Box metadata applied. |
| Update index | Always. The index file is the only fast-lookup mechanism. |
| Recall by ID | Direct file fetch (instant). |
| Recall by slug / title / kind / tag | Read `_index.json` from relevant folder(s). |
| Recall by wikilink | `_index.json` `by_wikilink` map. |
| Recall by free-text body | Read each candidate's content (slow). Recommend converting to a tagged recall. |
| Cross-folder query | Read workspace-root rollup `_index.json`. |
| Companion file | Standard pattern. Hash computed by downloading and hashing locally. |
| Search fallback | Last resort. Warn user about 10-min lag and filename-only matching. |

### Business / Business Plus

| Operation | Strategy |
|---|---|
| Write memory | Markdown + frontmatter **plus** metadata template instance applied to the file. |
| Update index | Still maintained — provides offline-friendly read path and cross-tier portability. |
| Recall by structured fields | Metadata Query API — instant, no lag, SQL-like filters. |
| Recall by free-text body | Box body search (≤10 KB/doc). Useful for fuzzy matches. Index file still primary. |
| Companion file | Standard pattern. Metadata template captures `companion_for_file_id` for instant reverse-lookup. |
| Multi-template queries | Not supported — Box Metadata Query is single-template. Plugin uses one wide template. |

### Enterprise

Everything Business does, plus:

| Operation | Strategy |
|---|---|
| Retention | Plugin can apply retention policies via metadata + Box Governance (out of scope for v1, available as escape hatch). |
| Legal holds | If a `status: held` memory is written, plugin can mirror to a Box legal hold (out of scope for v1). |
| Compliance audit prep | Metadata template includes all fields auditors typically want; export via Metadata Query API. |

### Enterprise Plus / Government

Adds compliance certifications. The plugin's behavior is identical to Enterprise; the certifications are properties of the substrate.

---

## Detection logic

Pseudocode (skills do this in plain instructions):

```
1. Try list_metadata_templates(scope="enterprise")
   → success → at least Business tier
   → "user does not have an enterprise" → Personal/Free tier, stop here
   
2. Try create a probe metadata template (or check existing if you can read enterprise scope)
   → success → confirmed Business+ with template-create permission
   → 403 → Business+ but no admin rights; templates may exist but plugin can't create one

3. Check account quota via API
   → max_upload_size, used_quota, total_quota
   → these correlate with tier but aren't tier-labeled in the API
   
4. Compliance certs are NOT exposed via API
   → User must declare in config if their account has HIPAA/FedRAMP/etc.
   → Plugin trusts the user-declared value for compliance-gated features

5. Cache the result in _box-memory.json with tier_detected_at timestamp
   → Re-detect if older than 30 days, or on demand via /box-status --refresh
```

---

## When to upgrade

For most agent-memory use cases on a single user's account, **Personal works fine**. The index-file pattern gives sub-second recall, the 10 GB storage holds millions of small markdown files, and you don't need compliance certs to remember things for yourself.

You start needing Business+ when:

- **Recall queries are structured and frequent.** Reading a JSON index is fast but every query reads the whole index. Metadata Query API is faster at scale (1000s of memories per folder).
- **You want full-text body search** as a fuzzy backup, even with the 10 KB cap.
- **You need Box Sign** for attested decisions or signed evidence packs.

You need Enterprise+ when:

- **You handle regulated data** — PHI, CUI, ITAR-controlled technical data, federal data.
- **You need retention guarantees** beyond what your own discipline provides.
- **Your customers' auditors will look at your storage substrate.**

Compliance is the most expensive line in Box's pricing and the cheapest line in your audit costs. If you're in scope for it, the math is clear.

---

## Sources

- Box Developer Documentation — Search API behavior, indexing lag
- Box Help Center — Pricing tier feature lists
- Box Compliance Center — SOC, HIPAA, FedRAMP, DISA IL4 attestations
- Empirical testing — capabilities probed in this plugin's own development

Verify against Box's current docs before relying on any specific number — Box updates tier features periodically.
