# Examples

Reference files showing the shape of box-memory artifacts. None of these are uploaded automatically — they exist so users and contributors can see what the schema produces.

## Files

- **example-memory-decision.md** — a `kind: decision` memory with full frontmatter, body, wikilinks, and tag line.
- **example-memory-task.md** — a `kind: task` memory with a checklist and a `related:` reference to the decision above.
- **example-companion.md** — a `kind: companion` paired with a hypothetical Q2 revenue PDF, with SHA256 anchoring.
- **example-_index.json** — a folder's `_index.json` containing the three example memories with full inverted maps.
- **example-_box-memory.json** — a workspace config showing a Personal-tier setup.

## How to use them

- **As schema reference:** when writing custom skills or external tooling, mirror these shapes exactly.
- **As a regression check:** if the plugin starts producing files that look different, compare against these to find drift.
- **As copy-paste starters:** if you want to seed a workspace by hand, you can.

The file IDs (`file_id`, `folder_id`) here are placeholder strings — they look like real Box IDs but aren't. Memory IDs (`mem_…`) follow the ULID format. Hashes are placeholder values.

## What's NOT here

- Plugin source code — see `skills/`, `commands/`, `references/` in the repo root.
- Domain-specific examples (export compliance, healthcare, etc.) — the plugin is domain-neutral by design. Users build their own conventions on top.
