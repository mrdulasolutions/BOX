<!--
  This file documents Box webhooks as a pattern users can layer on top of
  box-memory if they self-host a webhook receiver. The plugin itself does
  NOT subscribe to webhooks — there's no place to host the receiver inside
  a Claude Code / Cowork plugin.

  Both mrdulasolutions/BOX and mrdulasolutions/BOX-Onprem can reference
  this doc, but the on-prem variant cannot integrate webhooks at all
  (webhooks require a publicly-reachable HTTPS endpoint, which violates
  the air-gap claim).
-->

# Box webhooks — for users self-hosting a receiver

This document is a **reference pattern**, not a plugin feature. If you self-host a webhook receiver, you can wire Box events to trigger box-memory workflows automatically (e.g., on file upload → generate companion).

The plugin itself doesn't subscribe to webhooks — there's no place to host the receiver inside a Claude Code or Cowork plugin runtime, and the on-prem variant explicitly cannot host one (would break the air-gap claim).

## When to use this pattern

- You operate your own server (anywhere with a public HTTPS endpoint) that can receive Box events
- You want automatic actions on Box-side changes — e.g., a user drops a CAD file into the workspace, your server generates a companion automatically
- You have IT / DevOps capacity to maintain a webhook receiver and HMAC verification

If any of those don't apply, skip webhooks. The plugin works fine in pull-mode (user invokes skills explicitly or Claude does on demand).

## Box webhook v2 basics

Box webhooks v2 (GA) let you subscribe to events on specific files or folders. When the event fires, Box sends a POST to your `address` (the receiver URL) with the event payload.

Key facts (per [Box webhooks v2 guide](https://developer.box.com/guides/webhooks/v2)):

- 30+ trigger types: `FILE.UPLOADED`, `FILE.COPIED`, `FILE.MOVED`, `FILE.DELETED`, `FILE.RENAMED`, `METADATA_INSTANCE.CREATED`, `METADATA_INSTANCE.UPDATED`, `METADATA_INSTANCE.DELETED`, `FOLDER.CREATED`, `FOLDER.RENAMED`, `COMMENT.CREATED`, etc.
- Webhook target is a file ID or folder ID (subscribe per-resource, not per-account)
- Up to 5 webhooks per file or folder, 1,000 webhooks per Box application
- HMAC-SHA256 signature verification: Box signs each payload with your webhook's primary or secondary key
- Retry: Box retries failed deliveries with exponential backoff for ~24 h
- Address must be HTTPS and publicly reachable from Box's IP ranges

## Recommended patterns for box-memory

### Pattern 1: Auto-companion on file upload

Trigger: `FILE.UPLOADED` on the workspace's `files/` folder

Receiver flow:
1. Verify HMAC signature.
2. Extract `source.id` (the uploaded file's Box ID), `source.parent.id` (folder), `source.name` (filename).
3. Detect file type. If it's a supported binary (PDF / DOCX / image / CAD / Office), generate a companion.
4. Use the **cloud plugin's** workflow programmatically: agent loop invokes `/box-companion <file_id>` against your Box MCP, which runs the standard companion generation (using `box-ai-extract` if Business+ AI is enabled).
5. The companion `.md` is written to Box; the workspace's `_index.json` is updated; Box Drive (if installed) syncs locally; on-prem users see the new companion on their next read.

Latency budget: webhook delivery (~seconds) + agent invocation (~seconds) + companion generation (~tens of seconds for AI-extracted; <1s for sparse) + Box Drive sync (~seconds to minutes depending on Box Drive's queue). End-to-end: typically <2 minutes.

### Pattern 2: Auto-rebuild index on manual Box edits

Trigger: `METADATA_INSTANCE.UPDATED` and `METADATA_INSTANCE.DELETED` on memory files

Receiver flow:
1. Verify signature.
2. Mark the affected folder as "needs reindex" in your control plane (a small Redis flag, etc.).
3. Throttle: don't trigger `/box-index-rebuild` per event. Aggregate over a 5-minute window, then invoke once.
4. Agent loop invokes `/box-index-rebuild --team=<affected_team>` to bring the `_index.json` back in sync with manual Box edits.

This pattern handles the case where users edit memories via Box's web UI (outside the plugin) and the index would otherwise drift.

### Pattern 3: Alert on companion staleness

Trigger: `FILE.UPLOADED` (new version of an existing binary, detected by `source.id` match with an existing companion's `companion_for.file_id`)

Receiver flow:
1. Verify signature.
2. Look up the binary's existing companion in the workspace's `_index.json`.
3. Compare the binary's current sha1 (from the webhook payload) against the companion's stored `sha1`. If they differ, the companion is now stale.
4. Either auto-regenerate via `/box-companion <file_id>`, or notify the user via your platform's preferred channel.

## HMAC-SHA256 signature verification (sample)

Box sends two headers: `box-signature-primary` and `box-signature-secondary`. Verify against your webhook's primary key, with secondary as a fallback during key rotation.

Reference snippet (Python):

```
import hmac, hashlib

def verify_box_webhook(body_bytes, header_signature, primary_key, secondary_key):
    expected_primary = hmac.new(
        primary_key.encode('utf-8'),
        body_bytes,
        hashlib.sha256
    ).hexdigest()
    if hmac.compare_digest(expected_primary, header_signature):
        return True
    expected_secondary = hmac.new(
        secondary_key.encode('utf-8'),
        body_bytes,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected_secondary, header_signature)
```

Reject the request if neither signature matches. Box's full guidance: [Webhooks v2 signatures](https://developer.box.com/guides/webhooks/v2-handle/setup-signature-keys).

## Subscribing to a webhook

Use the Box MCP's `create_webhook` tool (or call `POST /2.0/webhooks` via the Box SDK):

```json
{
  "target": {"id": "<folder_id>", "type": "folder"},
  "address": "https://your-receiver.example.com/box-webhook",
  "triggers": ["FILE.UPLOADED", "FILE.COPIED"]
}
```

The webhook resource ID returned can be retrieved / deleted / updated later via the same endpoint family.

## Why not Box Automate?

Box Automate (Public API GA'd 2026-04-30) is a Box-hosted workflow engine. For "on upload → run AI on the file → write metadata" you might prefer Automate over webhooks — no receiver to host, Box runs the workflow internally.

We don't ship a Box Automate integration in v0.1.0 because:

- Automate flows are configured in Box's UI; the plugin can't programmatically define them (no API for flow authoring)
- Automate doesn't natively call out to arbitrary agent loops — it's designed for in-Box actions
- Webhooks are more flexible: you host the receiver, you do anything

If you do want Automate, the relevant use case for box-memory is auto-metadata-extraction on file upload — Box Automate can call `/2.0/ai/extract_structured` and write the result as a metadata instance, without any external receiver. The downside vs the plugin's `/box-companion`: Automate writes the metadata directly to Box and doesn't write the companion markdown file. You lose the human-readable companion artifact and the hash-anchored "what the agent reviewed" record.

## Air-gap incompatibility (on-prem variant)

Webhooks **break the air-gap claim**. The on-prem plugin (`box-memory-onprem`) shouldn't subscribe to webhooks because:

- Webhook receivers must be publicly reachable HTTPS endpoints
- Box's webhook delivery is from Box's IP ranges to your server — outbound from Box, inbound to you
- Even if the receiver runs locally, exposing it publicly means an outside party (Box) is poking the air-gapped network

If you need event-driven behavior in an air-gapped environment, use a different pattern:
- Periodic local FS scan (cron job runs `/box-index-rebuild` every N minutes)
- Box Drive's local change notifications (FSEvents on macOS, ReadDirectoryChangesW on Windows) — let Box Drive surface "this folder changed" without an outbound Box connection

## References

- [Box webhooks v2 guide](https://developer.box.com/guides/webhooks/v2)
- [Webhook v2 triggers](https://developer.box.com/guides/webhooks/triggers)
- [Webhook signature verification](https://developer.box.com/guides/webhooks/v2-handle/setup-signature-keys)
- [Box Automate Public API](https://developer.box.com/guides/box-automate/) — alternative for in-Box workflows
- [Webhook resource reference](https://developer.box.com/reference/resources/webhook/)
