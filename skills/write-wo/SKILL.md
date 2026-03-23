---
name: write-wo
description: Write work orders for a project from a feature brief or conversation notes
argument-hint: "[project-name] [feature brief or conversation notes]"
---

Write work orders for: $ARGUMENTS

## Process

1. **Read existing orders** -- use the three-tier fallback:
   - **Tier 1 (MCP):** call `workledger_list_wos(project="<project-name>")` to get all WOs, find the highest ID. Dedup: `workledger_search(query="<title keywords>", project="<project-name>")`
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `source ~/.workledger/api-key.env`
     - List: `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/wo?project=<project>'`
     - Search: `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/search?q=<keywords>&project=<project>'`
   - **Tier 3 (flat file):** if both are unavailable, find `docs/work-orders.md` and continue existing numbering
   - If a similar WO is found, warn the user before creating a duplicate

2. **Read project architecture** -- read README.md and source structure to understand conventions

3. **Analyze the brief** -- extract concrete features or research questions, determine scope, identify dependencies

4. **Classify: implementation or research**
   - **Implementation** -- outcome is code changes
   - **Research** -- outcome is findings. Add `(research)` to the title

5. **Write each order** using the format below

6. **Save the WO** -- STOP: you MUST have run the dedup check from step 1. Use the three-tier fallback:
   - **Tier 1 (MCP):** `workledger_create_wo(project, title, priority, sections={...}, tags=[...])`
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `curl -s --max-time 10 -X POST -H "Authorization: Bearer $WORKLEDGER_API_KEY" -H "Content-Type: application/json" 'https://workledger.fly.dev/api/v1/wo' -d '{"project":"<project>","title":"<title>","priority":"<P0-P3>","tags":[...],"sections":{...}}'`
   - **Tier 3 (flat file):** append to `docs/work-orders.md`
   - If Tier 1 or 2 succeeds and `docs/work-orders.md` exists, also append there (dual-write)

## WO format

```markdown
## WO-<NN>: <Title>

**Status:** `[ ]` planned
**Priority:** <high|medium|low> -- <one-line justification>
**Depends on:** WO-<NN>  (optional)

### Summary

<What and why in 2-3 sentences>

### Scope

| File | Change |
|------|--------|
| `path/to/file` | Description of change |

### Acceptance criteria

- [ ] Criterion 1
- [ ] Tests pass
```

## Numbering

- Format: `WO-<NN>` or `WO-<NNN>` depending on project size
- Research orders: `WO-<NN>: <Title> (research)`
- Continue existing numbering in the project
- New projects start with `WO-01`

## Rules

- Every WO must list specific files and have test criteria
- Every WO must be completable in a single session
- Always search before creating to avoid duplicates
- Workledger is the source of truth -- flat files are fallback views
- NEVER run `workledger import` for normal WO creation
