---
name: wrapup
description: Save state, commit, and sync -- complete end-of-session command
argument-hint: "[commit message]"
---

Wrap up the current work: save state, commit, push. $ARGUMENTS

## Steps

1. **Mark completed WOs** -- use the three-tier fallback:
   - Check which WOs were completed in this session
   - **Tier 1 (MCP):** `workledger_update_wo(project, id, status="done")` or `workledger_update_many(project, ids, status="done")`. Add note: `workledger_add_note(project, id, text="Completed: <SHA> -- <summary>")`
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `source ~/.workledger/api-key.env`
     - `curl -s --max-time 10 -X PATCH -H "Authorization: Bearer $WORKLEDGER_API_KEY" -H "Content-Type: application/json" '${WORKLEDGER_URL}/api/v1/wo/<project>/<id>' -d '{"status":"done"}'`
     - `curl -s --max-time 10 -X POST -H "Authorization: Bearer $WORKLEDGER_API_KEY" -H "Content-Type: application/json" '${WORKLEDGER_URL}/api/v1/wo/<project>/<id>/note' -d '{"content":"Completed: <SHA> -- <summary>"}'`
   - **Tier 3 (flat file):** if both are unavailable and `docs/work-orders.md` exists, update status there
   - If no WOs were completed, skip this step

2. **Save context** -- write `docs/context.txt` with: Task, Key Decisions, Current Status, Files Modified, Open Issues

3. **Save memory** -- update the project's `MEMORY.md` with any new stable patterns or decisions confirmed during this session. If nothing new, skip.

4. **Push shared state** -- push memory and context to workledger:
   - Read MEMORY.md and all topic files from the local memory directory
   - **Tier 1 (MCP):** for each file, call `workledger_memory_put(project, key="memory/<filename>", content=...)`. Call `workledger_context_put(project, content=...)`
   - **Tier 2 (HTTP API):** if MCP is unavailable:
     - `curl -s --max-time 10 -X PUT -H "Authorization: Bearer $WORKLEDGER_API_KEY" -H "Content-Type: application/octet-stream" --data-binary @<path> '${WORKLEDGER_URL}/api/v1/blob/<project>/memory/<filename>'`
     - `curl -s --max-time 10 -X PUT -H "Authorization: Bearer $WORKLEDGER_API_KEY" -H "Content-Type: application/octet-stream" --data-binary @docs/context.txt '${WORKLEDGER_URL}/api/v1/blob/<project>/context'`
   - **Tier 3 (local only):** if both are unavailable, skip sync
   - Show: `Pushed N memory files and context to workledger`

5. **Commit** -- if there are changes:
   - Stage relevant files
   - Commit with the provided message or auto-generate a conventional commit message
   - If no changes, report "nothing to commit"

6. **Push** -- push to remote. If diverged, report error (do NOT auto-rebase)

7. **Report** -- summarize:
   ```
   Done:
   - WOs marked done: WO-XX (or "no WOs completed")
   - Context saved
   - Memory updated (or "no updates needed")
   - Committed: <message> -> <SHA>
   - Pushed to origin
   ```

## Rules

- Commit message: `type: concise imperative statement`
- NEVER force push
- NEVER run `workledger import`
- Each step is independent -- if one fails, continue and report all results
