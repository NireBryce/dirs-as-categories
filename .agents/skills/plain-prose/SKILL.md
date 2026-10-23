---
name: plain-prose
description: How to rewrite mannered or indirect sentences in docs, skills and comments so a reader gets the point on first read, without changing what they say.
when_to_use: Asked to lint prose for mannered, indirect, oblique or unclear speech, or to make docs or comments plainer.
---

# Rewriting mannered prose

## Applies to

Asked to lint `wiki/`, `doc/`, `README.md`, `.agents/skills/*/SKILL.md`,
`.github/` templates or code comments for mannered or indirect wording.
Do not use it to cut length (skill `trim-docs`) or to fix a stale fact
(skill `docs-sync`). `doc/style.md` is the house style; this skill applies
it to existing text.

## What to rewrite

Each kind with an edit made on 2026-10-23:

| Kind | Before | After |
|---|---|---|
| Oblique: the reader decodes the rule | Assuming *no* is the mistake this flow exists to prevent | If unsure whether an ask means `main`, ask; don't assume it doesn't. |
| Aphorism | the vaguer true statement outlives the sharper false one | Don't state more precisely than you checked |
| No subject or verb | Not `gh pr merge --delete-branch`: it removes only the remote branch. | Do not use `gh pr merge --delete-branch`: it removes only the remote branch. |
| Personification | A later rename can't know the sentence exists. | A later rename doesn't update the sentence. |
| Referent far back | must not pass too few arguments: the second is an error | a missing argument is an error |
| Actor hidden | Checked lazily, when something reads `flake.modules` | The check is lazy and runs when something reads `flake.modules` |

## What to leave

- Facts, exact names, commands, error message text, dates, version
  numbers, and every qualifier about confidence (skill `fact-hygiene`).
- Headings (they are link anchors) and frontmatter `name`.
- Code, strings and error messages: in code files, edit comments only.
- Table cells that are short noun phrases, which `doc/style.md` allows.
- Plain text that is merely terse. If unsure whether a phrase is
  mannered, leave it. Make the smallest edit that makes the sentence
  plain; don't add content or restructure a section.

## Check each edit kept its meaning

A plainer sentence that says something else is worse than the original.
These are the meaning changes found while reviewing the 2026-10-23 pass:

- **A guessed referent.** "A file may be called only with `lib` and
  `inputs`" became "`scan.nix` takes only …"; the file is a user's module
  file. Before resolving "it", "a file" or "this", find what it refers to
  in the code or the surrounding text.
- **A swapped verb.** "see each other's checkouts" became "change
  each other's checkouts".
- **A softened or hardened claim.** "puts you back" became "can put you
  back"; "however small" became "however small the cause".
- **A lost implication.** "an infinite recursion waiting for the right
  tree" became "causes infinite recursion on the right tree", dropping
  that no current tree triggers it.
- **A rewrite no plainer than before.** "This is the opposite trade"
  became "This style trades the other way".

Read the whole diff (`git diff -U1`) and compare each changed line with
the line it replaced.

## Splitting the work

When agents share the pass, give each one a disjoint set of files in the
same checkout, the lists above as its brief, and no git commands. Review
every agent's diff yourself against "Check each edit kept its meaning"
above. An agent flags its own guesses only sometimes, so don't rely on
its report.

## After

- Rewrap any line the edit made longer than its neighbours (about 75
  columns in Markdown and comments; one line for a `justfile` recipe's
  comment, which `just --list` shows).
- A change to `nix/*.nix`, even comments only, needs a `CHANGELOG.md`
  line under `Unreleased`, or CI's `changelog` job fails; "No change for
  users" is the section for it.
- Run `just preflight` (or, without the dev shell, `python3 tests/docs.py`
  and `nix flake check`, per `wiki/agents-lessons-learned.md`).

## See also

`doc/style.md`, skills `trim-docs`, `fact-hygiene`, `docs-sync`.
