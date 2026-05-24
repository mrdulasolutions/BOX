---
name: box-ai-agent
description: Create, update, or invoke a persistent Box AI Studio agent for memory recall. The "memory librarian" agent has locked instructions ("answer only from the indexed workspace, cite file IDs, never speculate"). Enterprise Advanced only. Use when the user wants a fixed-behavior AI assistant over their memory workspace, with locked guardrails instead of ad-hoc prompts.
argument-hint: "<create|update|invoke|delete|status> [--name=<agent-name>] [--question=<prompt>]"
---

# /box-ai-agent

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../../CONNECTORS.md).

Manage a Box AI Studio agent that's pre-configured to answer questions over your memory workspace. The agent has locked instructions (model, system prompt, file-access scope, temperature) so behavior is consistent across users and audit-friendly.

**Tier:** Enterprise Advanced only — AI Studio is gated to that tier. The skill auto-checks via `box-tier-detect` and surfaces a clear "not available on your tier" message otherwise.

## Usage

```
/box-ai-agent <subcommand> [args]
```

Subcommands:
- `create [--name=<n>]` — create the "memory librarian" agent for this workspace
- `update [--name=<n>]` — update agent config (instructions, model, etc.)
- `invoke --question="<question>"` — ask the agent a question
- `delete --name=<n>` — remove the agent
- `status [--name=<n>]` — show the agent's current config

## What to do — Create

1. **Verify tier.** Call `box-tier-detect`. If `capabilities.ai_studio_agents` is false, surface: *"AI Studio agents require Enterprise Advanced. Your current tier is `<tier>`. Falling back: use `/box-ai-recall` for per-call Q&A with ad-hoc prompts (Business+)."*
2. **Verify Box AI tools.** Confirm the Box MCP exposes `box_ai_agent_create` or equivalent. The official Box remote MCP includes this; community MCPs typically don't.
3. **Read workspace state.** Determine if the workspace is folder-backed or Hub-backed (`workspace_type`). Hub-backed unlocks indexed Q&A over up to 20k files; folder-backed limits to file-set Q&A (up to 25 files per call).
4. **Build the agent config:**

```json
{
  "name": "box-memory-librarian-<workspace_name>",
  "type": "ai_agent_ask",
  "ask": {
    "model": "<from settings.ai_model or default GPT-5 mini>",
    "system_message": "You are the memory librarian for the <workspace_name> agent-memory workspace. Your role: answer questions strictly from the indexed memory files. Cite the source memory ID and title for every fact in your answer. If you cannot find an answer in the indexed memories, say so explicitly — do not speculate, do not generalize, do not invent. Refuse to discuss content outside this workspace.",
    "prompt_template": "{user_question}",
    "temperature": 0.2,
    "include_citations": true
  },
  "access_state": "enabled"
}
```

   Customize via `--name=` and `--instructions-from-file=<path>` for users who want different guardrails.

5. **Call /2.0/ai_agents** via the Box MCP's `box_ai_agents_create` tool. Capture the returned `agent_id`.
6. **Persist in workspace config:**

```yaml
ai_studio_agent:
  id: <agent_id>
  name: <name>
  created_at: <ISO>
  workspace_scope: <folder | hub>
  model: <model>
  last_invoked_at: null
```

7. **Report:**

```
✓ AI Studio agent created.

  Name:           <name>
  ID:             <agent_id>
  Model:          <model>
  System prompt:  locked — see workspace config for full text
  Scope:          <folder N files | hub up to 20,000 files>

Invoke with:
  /box-ai-agent invoke --question="<your question>"

The agent's behavior is locked. To change instructions or model:
  /box-ai-agent update [args]
```

## What to do — Invoke

1. Read `_box-memory.json.ai_studio_agent.id`. If missing, suggest `/box-ai-agent create` first.
2. Call `box_ai_agents_invoke` (or equivalent) on the Box MCP, passing the agent ID and the user's question.
3. Update `last_invoked_at` in workspace config.
4. Return the agent's answer with citations:

```
Question: <user's question>
Agent:    <name> (id: <agent_id>)
Model:    <model>

Answer:
<agent response>

Citations:
- mem_<id> "<title>"
- ...
```

## What to do — Update

1. Read existing agent config from workspace + Box AI API.
2. Apply requested changes (model, instructions, temperature). Re-validate the system prompt for compliance with guardrails (no "speculate," "guess," or "imagine" verbs — those defeat the agent's purpose).
3. Call the update endpoint.
4. Update workspace config's `ai_studio_agent` block.

## What to do — Delete

1. Confirm twice. AI Studio agents persist across sessions and may be used by other teams — deletion is shared-state.
2. Call the delete endpoint.
3. Remove `ai_studio_agent` block from workspace config.

## What to do — Status

1. Read workspace config's `ai_studio_agent` block.
2. Fetch live agent config from Box AI API.
3. Diff config-vs-live; surface any drift (e.g., admin changed model in Box UI but our cached config is stale).
4. Report:

```
AI Studio agent for workspace <workspace_name>:
  Name:                <name>
  ID:                  <agent_id>
  Created:             <ISO>
  Model:               <model>
  Temperature:         <value>
  System prompt:       <first 100 chars>...
  Citations enabled:   <yes/no>
  Last invoked:        <ISO or never>
  Workspace scope:     <folder | hub>
  Live config drift:   <none | <details>>
```

## When to invoke

- User wants consistent agent behavior across sessions and users (regulated workflow, audit trail)
- Multiple users querying the same workspace want the same locked guardrails
- User is on Enterprise Advanced and wants to leverage AI Studio specifically
- Org has compliance requirements for AI access controls (locked model, locked prompt, locked scope)

## When NOT to invoke

- Tier doesn't support AI Studio → fall back to `/box-ai-recall` which works on Business+
- One-off ad-hoc question → `/box-ai-recall` is simpler, doesn't require setting up a persistent agent
- User wants flexible/varied prompts → AI Studio's strength is locking; if you want flexibility, use ad-hoc `box-ai-recall`

## AI Unit cost

AI Studio agents consume AI Units per invocation, same as `/ai/ask`. Enterprise Advanced includes 20,000 units/month by default. Specific consumption rates aren't publicly published — see [references/box-ai-units.md](../../references/box-ai-units.md).

## Errors to surface clearly

- **Tier insufficient** → "AI Studio requires Enterprise Advanced. Use `/box-ai-recall` for per-call Q&A on Business+."
- **MCP missing AI agent tools** → "The connected Box MCP doesn't expose AI Studio tools. Confirm you're on the official `mcp.box.com` remote MCP (run `/box-mcp-check`)."
- **Agent already exists** → "Agent `<name>` exists at `<id>`. Use `/box-ai-agent update` to modify it, or `/box-ai-agent invoke` to query."
- **AI Units exhausted** → "AI Unit quota reached. Wait for refresh or purchase additional units via Box admin."
- **Live config drift** (admin changed agent in Box UI) → surface and offer to re-sync workspace config

## Don't

- Don't create an agent without locked guardrails. The whole point is consistency; an unlocked agent is just a wrapper around `box-ai-recall`.
- Don't delete agents that other teams might be using without confirming. AI Studio agents are account-scoped, not workspace-scoped.
- Don't update the system prompt to weaken the "cite or refuse" guardrail. That defeats the audit-friendliness.
- Don't invoke an agent that's been disabled in Box admin — surface clearly that the agent is in `access_state: "disabled"` state.

## References

- [Box AI Studio agents docs](https://developer.box.com/guides/ai-studio/ai-studio-agents/create-agents/) — for human readers
- [Box AI Agents endpoint](https://developer.box.com/reference/post-ai-agents) — for human readers
- references/box-ai-units.md — cost model
- references/airgap-trust-model.md (in BOX-Onprem) — AI Studio is incompatible with air-gap; on-prem users can't use this skill
