---
name: workledger
description: Use workledger to query, create, update, and relate work orders
argument-hint: "[project] [command or goal]"
---

Use workledger for: $ARGUMENTS

Use this skill when the user asks about work orders, backlog state, WO lookup, duplicate checks, dependency checks, status updates, notes, or general workledger usage.

## Access tiers (use in order)

1. **Tier 1 (MCP):** if workledger MCP is available, use MCP tools directly (workledger_list_wos, workledger_get_wo, workledger_create_wo, etc.)
2. **Tier 2 (CLI):** prefer `workledger` if on `PATH`, otherwise `~/go/bin/workledger`
3. **Tier 3 (HTTP API):** if CLI is unavailable or times out (Neon free tier cold start ~5-10s):
   - Load key: `source ~/.workledger/api-key.env`
   - Base URL: `https://workledger.fly.dev/api/v1`
   - Auth: `Authorization: Bearer $WORKLEDGER_API_KEY`
   - Use `--max-time 10` on all curl calls
   - Key endpoints:
     - `GET /wo?project=<p>&status=open` -- list WOs
     - `GET /wo/<project>/<id>` -- get single WO
     - `POST /wo` -- create WO (JSON body: project, title, priority, tags, sections)
     - `PATCH /wo/<project>/<id>` -- update WO (JSON body: status, sections, etc.)
     - `POST /wo/<project>/<id>/note` -- add note (JSON body: content)
     - `GET /search?q=<query>&project=<p>` -- search WOs
     - `GET /stats?project=<p>` -- counts by status/priority
     - `GET /wo/unclaimed?project=<p>` -- unclaimed WOs
     - `PUT /blob/<project>/<key>` -- push memory/context blob
     - `GET /blob/<project>/<key>` -- pull memory/context blob
     - `GET /blob/<project>` -- list blobs
4. **Tier 4 (flat file):** if all above are unavailable, fall back to `docs/work-orders.md`

## Backend verification

The authoritative store is Neon PostgreSQL via `WORKLEDGER_DSN`. The CLI silently falls back to local SQLite if DSN is unset.

**Before any write operation:**
1. Verify DSN is set: `echo "${WORKLEDGER_DSN:0:10}"` -- must show `postgresql`
2. If empty, STOP and tell the user to set WORKLEDGER_DSN
3. Read operations are safe against either backend but SQLite results may be stale

## Common commands

### Project overview

- `workledger list <project> --status open`
- `workledger stats [project]`
- `workledger blocked <project>`

### Lookup

- `workledger get <project> <id>`
- `workledger detail <project> <id>` -- WO plus notes, relationships, history
- `workledger search "<query>" --project <project>`

### Create and update

- `workledger create <project> --title "<title>" --priority P1 [--tags tag1,tag2] [--section summary="..."]`
- `workledger update <project> <id> --status done`
- `workledger note <project> <id> "Completed: <SHA> -- <summary>"`

### Relationships

- `workledger relate <from-project> <from-id> depends_on <to-project> <to-id>`
- `workledger deps <project> <id>` -- transitive dependency chain

### Memory and context sync

- `workledger memory put <project> <key> --file <path>`
- `workledger memory pull <project> <key> --file <path>`
- `workledger memory list <project>`
- `workledger context-put <project> --file docs/context.txt`
- `workledger context-pull <project> --file docs/context.txt`

## Rules

- Always run `search` before creating a WO to avoid duplicates
- When marking a WO done, add a note with the commit SHA
- Workledger is the source of truth -- flat files are fallback views
- NEVER run `workledger import` for normal WO creation
