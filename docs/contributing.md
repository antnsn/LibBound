---
title: Contributing
nav_order: 5
description: How changes to LibBound and the Bound addons are made.
---

# Contributing
{: .no_toc }

1. TOC
{:toc}

## The rules

- **Lua 5.1**, and only API that wowbench knows. `wowbench check .` with 0 errors, luacheck clean.
- **Everything per addon goes through `ns`.** No shared mutable state between addons: two Bound addons run side by side on the same library code.
- **Bump `MINOR`** in `Core.lua` with every behavior change. LibStub keeps the newest copy; see [LibStub and the MINOR rule](./#libstub-and-the-minor-rule).
- **Keep every embedding addon's tests green.** Run `tools/sync-libbound.sh && wowbench test .` in each addon that uses LibBound. See [How LibBound is tested](testing.html#how-libbound-is-tested).
- **Shared things go in LibBound.** Anything every Bound addon needs belongs here, not in one addon.

## Git: protected main

`main` is protected. Every change goes through a pull request:

```bash
git switch -c <topic>
# work, run the checks, review
git commit
git push -u origin <topic>
gh pr create --fill
gh pr merge --squash --delete-branch
```

LibBound's commit titles name the version: `LibBound 18: the buff key (#13)`.

## Code review

Run `/codex:review` before every commit. Fix or answer each finding before committing. Pure prose changes (Markdown, comments) may skip it.

## Issues: beads

Issues and follow-ups are tracked with beads (`bd`), not in Markdown TODO lists or TODO comments:

```bash
bd ready                 # what is open and not blocked
bd show <id>             # the details
bd update <id> --claim   # take it
bd close <id>            # done and verified
bd create "title" -t bug -p 2   # something found but not fixed
```

The beads state travels with git (`.beads/issues.jsonl`): commit it with the related work. There is no Dolt remote, so skip `bd dolt push`.

## A LibBound change, step by step

1. Branch from `main`.
2. Change the code. Keep the header comment of the file up to date: it is the contract the addons read (and that this site quotes).
3. Bump `MINOR` in `Core.lua`.
4. In LibBound: `luac5.1 -p`, `luacheck .`, `wowbench check .`.
5. In every embedding addon: `tools/sync-libbound.sh && wowbench test .`. Add or change a scenario for new behavior.
6. `/codex:review`, then commit, PR, merge.
7. Update the addons that need the new behavior in their own PRs. CurseForge builds fetch LibBound from its repository (`.pkgmeta` externals); `wowbench pack` embeds the local `../LibBound`, so pull it first.

## These docs

The site lives in `docs/` (Jekyll 4 with just-the-docs) and is published to GitHub Pages by `.github/workflows/pages.yml` on every push to `main` that touches `docs/`. To build it locally:

```bash
cd docs
bundle config set --local path vendor/bundle
bundle install
bundle exec jekyll serve
```

When you change a function's signature or a config table, update its page under [API reference](api/).
