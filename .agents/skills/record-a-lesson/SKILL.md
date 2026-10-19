---
name: record-a-lesson
description: How to add something a session learned the hard way about Nix, flake-parts or this repo's inputs to the agents' lessons page.
when_to_use: Nix or an input behaved unlike you expected, a check passed over a real bug, or a workaround took more than one try -- before ending the task.
---

# Recording a lesson

## Applies to

Before ending a task in which any of these happened:

- Nix, flake-parts or import-tree behaved differently from what you
  expected, and the difference cost you a try or misled a check.
- A test or check passed while the thing it tests was broken.
- Getting the inputs, the dev shell or an evaluation to work at all needed
  a workaround.

Do it without being asked: the user asked for lessons to be recorded as a
matter of course (2026-10-19). Not for a bug in this repository's code --
that is a fix or an issue (skill `propose-issue`); record only the general
behaviour the bug taught. Not for anything already on the page or in
`AGENTS.md`, `doc/` or another skill: point to it instead, or sharpen the
existing lesson.

## Where

[`wiki/agents-lessons-learned.md`](../../../wiki/agents-lessons-learned.md),
one `##` section per lesson, added to its `## Contents`. Bump the page's
`_Last modified:` date (`wiki/styleguide.md`).

## Each lesson

1. **The error or surprise, as Nix printed it**, in a code block, so a
   later session can find the lesson by searching for the message.
2. **The rule**: what to do or avoid, in a sentence or a short list. A
   general fact about Nix comes first; this repo's case is the evidence.
3. **A command or expression that shows it**, run as written. A `nix`
   block must parse (`just docs` checks).
4. **How you checked it**, with the date and the version or revision
   (skill `fact-hygiene`): "Checked on 2026-10-19 with Nix 2.34.6."
   Anything you didn't run, say so.

Keep it to what transfers. Session narrative ("first I tried…") and the
specific bug's fix don't belong; the commit log and the issue hold those.

## When a lesson becomes a rule

If a lesson would have prevented a mistake every session can make, it may
belong in `AGENTS.md`'s hard rules or in the skill for that task. Propose
the move to the user rather than making it: the lesson page records,
`AGENTS.md` instructs.

## Then

Commit the page with the task's other changes, or alone as `docs:` when the
task changed nothing else; `just docs` must pass.

## See also

- `fact-hygiene` -- dates and confidence on each claim.
- `docs-sync` -- when the lesson changes what another doc says.
