# How the docs are written

These rules cover `README.md`, `doc/`, `wiki/`, `AGENTS.md` and the skills
under `.agents/skills/`. Code comments follow the same rules, more briefly.

## Where a fact goes

| File | For | Holds |
|---|---|---|
| `README.md` | someone arriving cold | what this is, a quick start, one example, links into `doc/` |
| `doc/*.md` | someone looking something up | one topic per file, complete and exact |
| `wiki/*.md` | someone using or changing it | guides, worked examples, reasoning, troubleshooting -- [`../wiki/styleguide.md`](../wiki/styleguide.md) |
| `nix/README.md` | someone reading the code | how the files fit together, and the Nix they use |
| `AGENTS.md` | an agent starting a session | what applies to every session, and where the rest is |
| `.agents/skills/<name>/SKILL.md` | an agent doing one kind of task | that task's procedure and traps |

**One fact lives in one place**, and everywhere else points to that place.
A fact written twice drifts, and nothing tells you which copy is right.
When a copy is unavoidable (a summary table in the README), the README
points to the full statement.

## Writing

- **Write whole sentences that say who does what.** Give each sentence a
  subject and a verb: "This page lists every rule", not "Every rule
  dirs-as-categories applies." Name the actor -- dirs-as-categories, Nix,
  flake-parts, or "you" -- in the active voice: "dirs-as-categories loads
  the file as a flake-parts module", not "it is loaded as one". In guides,
  speak to the reader.
- **Name the thing instead of writing "it"** when the referent is more than
  a clause back or could be read two ways.
- **Table cells may be short noun phrases**, but a cell never mixes a
  fragment with a sentence ("`1`. A change increments it.").
- **Use the present tense for how things are now.** Give history as one
  dated line ("until 2026-10-16, …") or leave it to the commit log, not a
  narrative.
- **Use plain words.** Define a term at first use. Prefer the word a reader
  would search for.
- **Write exact names.** Write options, keys, flags, error messages and
  commands exactly as they appear, in backticks.
- **Use tables for lookups**, prose for reasoning, and code blocks for
  anything a reader would type. Every code block must run as written.
- **Examples are generic.** Hosts are `laptop` and `server`, categories
  `base` and `desktop`, users `me`. Never use a real person's machines,
  network or accounts.
- **Confidence stays with the claim** (skill `fact-hygiene`): say how you
  checked a claim, or say in the same sentence that you didn't.
- **Security in public text stays mechanical**: describe what a check
  enforces and how you verified it, not what got past an older version or
  what a hole could reach.

## Shape

- Open each doc with a sentence or two on what the doc is for.
- Headings are link anchors: grep for `<file>#` before renaming one.
- A doc past roughly 1,000 words opens with a short table of the key facts,
  or splits into several docs.

## Keeping it true

A change that makes a doc wrong fixes the doc in the same change (skill
`docs-sync`). `just preflight` runs the examples the tests cover; run the
rest yourself.
