---
name: load-context
description: Load project context and work orders for a new agent session
argument-hint:
---

Load project context so an agent can resume work on this project without prior conversation history.

## Steps

1. **Sync shared state** -- pull memory and context from workledger using the three-tier fallback:
   - **Tier 1 (MCP):** if workledger MCP is available:
     - Call `workledger_memory_list(project="<current-project>")` to get all stored memory keys
     - For each key, call `workledger_memory_pull(project, key)` -- if remote is newer than local, write to `~/.claude/projects/<project-key>/memory/<key>`
     - Call `workledger_context_pull(project)` -- if remote is newer, write to `docs/context.txt`
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `source ~/.workledger/api-key.env`
     - List blobs: `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/blob/<project>'`
     - Pull each blob: `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/blob/<project>/memory/<key>'`
     - Pull context: `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/blob/<project>/context'`
   - **Tier 3 (local only):** if both are unavailable, skip and proceed with local files
   - Show: `Synced N memory files and context from workledger (last updated <date> from <machine>)`
2. Read `CLAUDE.md` in the project root
3. If `docs/context.txt` exists, read it
4. **Load work orders** -- use the three-tier fallback:
   - **Tier 1 (MCP):** call `workledger_list_wos(project)` for open WOs, `workledger_stats(project)` for counts, `workledger_blocked(project)` for blockers. Recent: `workledger_list_wos(project, done_since="YYYY-MM-DD")` with 7 days ago
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/wo?project=<project>&status=open'`
     - `curl -s --max-time 10 -H "Authorization: Bearer $WORKLEDGER_API_KEY" 'https://workledger.fly.dev/api/v1/stats?project=<project>'`
   - **Tier 3 (flat file):** if both are unavailable and `docs/work-orders.md` exists, read it
5. If `docs/plans/` exists and contains .md files, list them
6. Summarize in 5-10 bullets: what the project is, current status, next WO, blockers
7. Ask: "Ready to work. Which work order should I start?"

## Rules

- Read ALL available files before summarizing
- Do NOT modify any files -- this is read-only orientation
- Do NOT start implementing until the user confirms which WO
- NEVER run `workledger import`
