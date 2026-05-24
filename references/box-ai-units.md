<!--
  Cost model for Box AI consumption. Both the cloud and on-prem plugins
  link to this doc. The on-prem variant doesn't consume AI Units (the
  plugin makes zero outbound Box calls), but its docs reference this so
  users know what they're giving up by choosing the air-gapped path.
-->

# Box AI Units — cost model for box-memory

Box AI usage is gated by **AI Units** — a per-call consumption budget that depends on your Box plan. This document captures what each plan allocates, how the plugin's AI-powered skills consume units, and how to bound your costs.

## Plan × allocation matrix

Per [Box AI Features in Business Plans](https://support.box.com/hc/en-us/articles/43797379758739) and [Expanded AI API Access](https://support.box.com/hc/en-us/articles/45612941554835):

| Plan | AI Units allocation | What's included |
|---|---|---|
| **Free Developer** | 1,000 / month | Ask, Extract, Text Gen — yes; multi-doc Ask — yes; Hubs Q&A — no; AI Studio — no |
| **Business / Business Plus** | Purchase as needed | Ask, Extract, Text Gen — yes (per-unit cost); multi-doc Ask — no; Hubs Q&A — no; AI Studio — no |
| **Enterprise** | 1,000 / month included | Ask, Extract, Text Gen — yes; multi-doc Ask — no; Hubs Q&A — **yes**; AI Studio — no |
| **Enterprise Plus** | 2,000 / month included | Ask, Extract, Text Gen — yes; multi-doc Ask — **yes**; Hubs Q&A — yes; AI Studio — no |
| **Enterprise Advanced** | 20,000 / month included | All of the above + **AI Studio agents** |

Sources:
- [Box AI Features in Business Plans (Box Support)](https://support.box.com/hc/en-us/articles/43797379758739)
- [Expanded AI API Access and AI Units (Box Support)](https://support.box.com/hc/en-us/articles/45612941554835)
- [Free Developer plan](https://developer.box.com/platform/free-developer-plan/)

**Per-call unit consumption rates are not publicly published.** Box directs prospective customers to sales for rate cards. Plan your usage by knowing your monthly allocation, not by counting per-call.

## How this plugin's skills consume units

| Skill | Operation | Units consumed | Frequency |
|---|---|---|---|
| `box-ai-recall` | `/2.0/ai/ask` multi-doc or Hubs Q&A | 1 unit minimum per call; cost scales with input file count and prompt complexity | Per user invocation |
| `box-ai-extract` | `/2.0/ai/extract_structured` | 1 unit minimum per call; cost scales with file size and field count | Per binary processed during companion generation |
| `box-ai-agent invoke` | `/2.0/ai_agents` invocation | 1 unit minimum per invocation | Per user query against the persistent agent |
| `box-companion` (with AI path) | Same as `box-ai-extract` | Per binary | When generating companions for AI-supported file types and `settings.ai_extract_enabled: true` |
| All other skills (`box-init`, `box-write`, `box-recall`, etc.) | None | 0 units — no AI calls | N/A |

The plugin **defaults AI-consuming behavior to OFF** via `_box-memory.json.settings`:

```yaml
settings:
  ai_recall_enabled: false       # box-ai-recall is gated
  ai_extract_enabled: false      # box-companion AI path is gated
  ai_studio_agent_enabled: false # box-ai-agent operations are gated
```

Users explicitly opt in. The plugin never silently incurs AI Unit costs.

## How to bound your AI cost

### Inspect current consumption

Box doesn't expose programmatic AI Unit consumption via the public API today. To check usage:

- Box Admin Console → Account Information → AI Units used / remaining (per billing period)
- Box's web UI may surface running totals depending on your plan

### Set workspace-level limits

In `_box-memory.json.settings`:

```yaml
ai_budget:
  monthly_unit_cap: 500              # plugin tracks; refuses calls above this
  per_session_cap: 50                # also enforce per-session limit
  warn_at_pct: 80                    # log a warning when 80% of cap reached
```

(This is a v0.2+ feature — not in v0.1.0. Current behavior: opt-in flags only, no cap enforcement.)

### Use exact paths where possible

The plugin's design prefers exact-lookup paths over AI paths:

- `/box-recall` by ID / wikilink / slug / structured filter — **0 units**
- `/box-recall` free-text with sparse local results → suggests `/box-ai-recall` — **opt-in, 1+ units**
- `/box-companion` for supported file types — AI path uses 1+ units; sparse path uses 0

A workspace with disciplined slug + tag usage will rarely need `box-ai-recall`. Heavy AI users are typically the ones with sloppy memory hygiene.

## What happens when you exhaust units

The AI Box endpoints return **HTTP 402** (Payment Required) or a quota-specific error code when the account has consumed its monthly allocation.

Plugin behavior:

1. Surface the error clearly: *"Box AI Unit quota reached. Skills falling back to non-AI paths. Quota refreshes at the start of next billing period, or your admin can purchase additional units via Box admin."*
2. Stop attempting AI calls for the session — switch ALL of `ai_recall_enabled`, `ai_extract_enabled`, etc. to `false` for the duration of the session.
3. Continue providing service via the non-AI paths (`/box-recall` index-only, `/box-companion` sparse mode).
4. On the next session, re-detect tier and AI Units availability via `/box-tier-detect --refresh`.

## Trade-off vs the air-gap variant

The on-prem plugin (`box-memory-onprem`) consumes **zero AI Units** — it makes no Box API calls. That's a different trade-off:

| Cloud plugin (`box-memory`) | On-prem (`box-memory-onprem`) |
|---|---|
| Uses AI Units for AI-powered skills | Uses no AI Units (no Box AI access) |
| Box AI Extract handles OCR for PDFs/images automatically | Companion generation falls back to "couldn't parse" for non-text formats |
| Semantic Q&A via `box-ai-recall` | Local index match only (no fuzzy / semantic) |
| AI Studio agents available (Enterprise Advanced) | Not available |

Both are valid choices. Pick the cloud plugin when AI features are worth the unit cost; pick on-prem when air-gap matters more than AI quality.

## References

- [Box AI Features in Business Plans](https://support.box.com/hc/en-us/articles/43797379758739-Box-AI-Features-in-Business-Plans)
- [Expanded AI API Access and AI Units for Business/Plus/Enterprise](https://support.box.com/hc/en-us/articles/45612941554835)
- [Box AI guide](https://developer.box.com/guides/box-ai)
- [Free Developer plan (1,000 units/month)](https://developer.box.com/platform/free-developer-plan/)
- [AI models catalog (model choice affects cost)](https://developer.box.com/guides/box-ai/ai-models/)
