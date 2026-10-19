# AGENTS.md

> **Written by agents, for agents.** Working notes for a session with no
> memory of the last one. `README.md` is the human entry point.
>
> This file is canonical; `CLAUDE.md` is a symlink to it. Skills are plain
> markdown at `.agents/skills/<name>/SKILL.md` (Claude Code reads them
> through `.claude/skills`); any agent can read them as files.

## What this is

An import-tree preset for flake-parts: it reads a modules folder, names
each module after its file, finds categories from the folder tree, and
fills `flake.modules.<class>.<name>`. It also publishes what it built as
`flake.moduleGraph`, which
[flake-module-graph](https://github.com/NireBryce/flake-module-graph) draws.
`doc/convention.md` is every rule; `doc/format.md` the published graph, `doc/format.schema.json` the same as a JSON Schema.

## Hard rules

- **This project is experimental.** Never describe it as stable or
  production-ready; keep the README's notice and the pointers to it in
  `doc/` and `wiki/`. Say what a change breaks for users, since nothing
  here promises compatibility yet.
- **"push" means skill `ship`**: branch, PR, green CI, one confirmation
  covering merge and branch deletion. Never push to `main` directly.
  GitHub enforces it (branch protection since 2026-10-18): `main` takes
  only pull requests whose required checks pass. An admin can bypass it;
  an agent never does.
- **Branching work happens in its own worktree** (skill `use-a-worktree`).
- **`git add` before `nix eval` or `nix flake check`**: flakes ignore
  untracked files, so a new fixture silently doesn't exist.
- **`nix/scan.nix` stays close to linear in the tree's size**: a lookup
  repeated per file is a set (`setOf`), not a search (`elem`, `filter`,
  `lib.unique`); `just bench` fails otherwise (issue 6).
- **Nothing in `nix/scan.nix` reads `config`** -- it decides names and
  imports, which the module system needs before `config` exists (skill
  `change-a-rule`).
- **Never file anything outside this repository** without the user saying
  so explicitly (skill `propose-issue`).
- **Write down what surprised you** about Nix, flake-parts or the inputs
  before ending a task, unasked (skill `record-a-lesson`); read
  `wiki/agents-lessons-learned.md` before probing or fetching inputs.
- **Say which rung you reached**: evaluates, `nix flake check` passes, CI
  is green. Never more than you saw.
- **A change that makes a doc stale fixes it in the same change** (skill
  `docs-sync`).
- **Examples are generic** -- `laptop`, `base`, `me` -- never anyone's real
  machines (`doc/style.md`).
- **Trailer `Co-Authored-By: Claude`** on agent commits, name only; prose
  says "the user".

## Commands

```sh
just                 # list recipes
just check           # nix flake check: the main fixture, every error fixture, the template
just errors          # each error fixture's message (a Nix check can only see that it failed)
just lint            # statix and deadnix over the Nix code, actionlint over the workflows (needs the dev shell)
just docs            # skills listed, links resolve, every error documented and tested, nix blocks parse
just schema          # every published graph against doc/format.schema.json (needs the dev shell)
just bench           # evaluation time at 500 and 2,000 modules; fails when it grows faster than the tree
just preflight       # all of the above -- what CI runs
just expected-diff   # how the main fixture's result differs from tests/expected/main.json
just expected-accept # record it, once every difference is one you meant
just new-error <name> '<message>'   # start an error fixture and its tests/errors.json entry
just examples        # each example flake's host with real nixpkgs and home-manager (network; not in preflight)
nix develop ./dev    # a shell with just, python3, statix, deadnix, nixd
```

## Layout

| Path | Holds |
|---|---|
| `nix/README.md` | how the files fit together, and the Nix syntax they use -- for readers new to Nix |
| `nix/default.nix` | `lib.tree`, `lib.tree.addClasses` and `lib.tree.withClasses` |
| `nix/scan.nix` | the rules: shapes, names, categories, flags, errors |
| `nix/module.nix` | `flake.modules`: includes, enables, defaults, `key`s |
| `nix/publish.nix` | one tree's `flake.moduleGraph` |
| `nix/shared.nix` | what a flake gets once however many trees it imports: the options, `flake.moduleGraph`, the orphan check |
| `tests/` | fixtures, expected results, and the scripts behind `just errors`, `docs`, `expected-*`, `new-error` |
| `example-flake/` | two example flakes, `default` and `home-manager`, to read, evaluate and draw (not configurations to switch to, and not `nix flake init` templates); their trees are checked by `just check` |
| `doc/` | the exact rules (`convention.md`) and format (`format.md`); `style.md` for all docs |
| `wiki/` | guides: `using-the-flake.md`; `agents-lessons-learned.md` for agents; `styleguide.md` before adding a page |
| `dev/` | the development shell's own flake (kept out of the main flake's inputs) |
| `CONTRIBUTING.md` | where a person starts: issues, the contributor wiki page, the code guide |
| `CHANGELOG.md` | what changed for users, and what breaks; `Unreleased`, then each release |
| `.github/` | CI (`check`), the weekly test against the latest inputs (`upstream`), Dependabot for Actions, weekly lock PRs (`update-flake-lock`), issue and PR templates |

## Testing discipline

- **Test first**: the case that shows a behaviour or an error is written,
  and seen to fail, before the code changes.
- **Read an expected result before recording it**; every difference from
  the last one must be one you meant.
- **Break it on purpose**: undo the core of a change and confirm a check
  fails for *that* reason.
- **Read the output, not the status.** Nix prints the innermost cause last.
  Before believing a zero, show the query can return something else.

## The contract with flake-module-graph

`flake.moduleGraph` is versioned (`doc/format.md`, and
`doc/format.schema.json`, which must change with it). Adding a field is fine;
removing, renaming or changing one's meaning increments `version`, and
flake-module-graph refuses a version it doesn't know. A change to the
format is a change to both repositories.

## Skills

| Skill | For |
|---|---|
| `change-a-rule` | changing a rule, key, error or published field |
| `ship` | landing work on `main` |
| `release` | tagging and publishing `vX.Y.Z` |
| `use-a-worktree` | branching work in isolation |
| `review` | reviewing a change here |
| `docs-sync` | keeping docs true in the same change |
| `fact-hygiene` | facts, dates and cross-references that stay true |
| `investigate-bug` | a reported bug, to a failing test |
| `help-a-user` | someone's own flake erroring or missing a module |
| `update-inputs` | bumping `flake.lock` or `dev/flake.lock` |
| `propose-issue` | filing a bug found along the way |
| `record-a-lesson` | writing down what Nix or the inputs taught you |
| `git-archaeology` | when and why something changed |
| `boyscouting` | small fixes beside a change |
| `explain-tricky-code` | comments that teach a hard mechanism |
| `trim-docs` | tightening prose |
| `new-skill` | writing a skill |
