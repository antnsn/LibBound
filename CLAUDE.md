# LibBound-1.0: instructions for AI agents

Shared core of the Bound class addons (WoW: Forever). Used by Chronobound, Stormbound, Packbound,
Spiritbound, Felbound and Dreambound, and by Lightbound on its LibBound branch. A change here must
keep every embedding addon's scenarios green: run `tools/sync-libbound.sh && wowbench test .` in
each of them. The developer docs (docs/, https://antnsn.github.io/LibBound/) document the API:
update them with an API change.

- Lua 5.1; only API in wowbench's `api/client.txt`; `wowbench check .` 0 errors; luacheck clean.
- Everything per addon goes through `ns` (no shared mutable state between addons).
- Bump `MINOR` in `Core.lua` with every behaviour change: LibStub keeps the newest copy.
- Git: protected main, PRs Claude opens and merges; beads for issues (no Dolt remote).
- `/codex:review` before every commit.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
