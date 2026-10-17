# Wiki style guide

_Last modified: 2026-10-16_

How this wiki is organised and written. The rest of the docs follow
[`../doc/style.md`](../doc/style.md); this page adds what is particular to
the wiki. Read it before adding, splitting or renaming a page.

## Contents

- [What the wiki is for](#what-the-wiki-is-for)
- [Every page](#every-page)
- [Naming and placing a page](#naming-and-placing-a-page)
- [Writing a page](#writing-a-page)
- [Linking](#linking)
- [Keeping it true](#keeping-it-true)

## What the wiki is for

Three places hold docs, and each has one job:

| Where | For | Holds |
|---|---|---|
| `README.md` | someone deciding whether to use this | what it is, a quick start, one example |
| `doc/` | someone looking up an exact rule | every rule, key, error and published field, stated once |
| `wiki/` | someone using it or changing it | guides, worked examples, the reasoning behind a design, troubleshooting |

**The wiki explains and walks through; it never restates a rule table.** A
page that needs the rules links to [`../doc/convention.md`](../doc/convention.md)
and says what the rule means for the task at hand. A fact written in two
places drifts, and nothing says which copy is right.

## Every page

1. `# Title` -- what the reader wants, not what the code calls it
   ("Using the flake", not "lib.tree").
2. `_Last modified: YYYY-MM-DD_` on the line after the title. **Bump it in
   the same change that edits the page's content.** A typo fix or a
   mechanical link update doesn't need it.
3. One or two sentences on what the page is for and who it is for.
4. `## Contents`, one bullet per `##` heading, when the page has three or
   more of them. Anchors are GitHub's: lowercase, spaces to hyphens,
   punctuation dropped (`` `defaults.nix` `` → `#defaultsnix`).
5. A page over roughly 1,000 words opens with `## Quick facts` -- a table
   of the facts a returning reader looks up -- as its first section after
   Contents.
6. An entry in [00-INDEX.md](00-INDEX.md).

## Naming and placing a page

- Lowercase, hyphenated, named for the task or topic: `using-the-flake.md`,
  `migrating-from-handwritten-names.md`.
- One level: `wiki/*.md`. A subdirectory only when a single topic has grown
  several pages of its own, and then with its own `00-INDEX.md`.
- Before creating a page, check whether the subject belongs as a section of
  an existing one.

## Writing a page

- **Worked examples are real.** Build the example as a flake and evaluate
  it before publishing; a snippet that doesn't evaluate is a bug in the
  page. Use the generic names from `doc/style.md` (`laptop`, `base`,
  `me`).
- **Show the file, then what it does.** A code block of the file, then a
  sentence on its effect -- not the other way round.
- **Errors appear as Nix prints them**, so a reader can search the page for
  the message they got.
- **Explain why where the reason is not obvious**, in the section it
  concerns. History is one dated line ("until 2026-10-16, …"), not a story.
- **Confidence stays with the claim** (skill `fact-hygiene`): say what an
  example was checked with, and mark anything unchecked.

## Linking

- Relative links: `[convention](../doc/convention.md#orphans)`.
- Headings are anchors other pages use: grep for `<page>.md#` before
  renaming one.
- One pointer per fact, at the place it is needed; no "see also" lists of
  everything.

## Keeping it true

A change to behaviour, a name, a key or an error message updates every
wiki page that shows it, in the same change (skill `docs-sync`). Search the
wiki for the old text before committing:

```sh
git grep -n '<old name or message>' -- wiki/
```
