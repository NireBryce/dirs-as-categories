---
name: release
description: How to release dirs-as-categories -- a pull request that names the version in CHANGELOG.md, which CI tags and publishes when it merges.
when_to_use: Asked to release, tag, bump the version, cut a version, or publish what is on main.
---

# Cutting a release

## Applies to

Publishing what is on `main` as `vX.Y.Z`. A release is a pull request
that renames `## Unreleased` in `CHANGELOG.md`; when it merges,
`.github/workflows/release.yml` tags the merge commit and publishes the
GitHub release. Nobody pushes a tag by hand: an agent's sandbox can push
only its own branch, and the workflow makes tagging part of the merge.

A release usually names changes that have already landed (skill `ship`).
When the user asks for a change and its release together, both go in one
pull request, as `v0.3.0` did. A release is public and notifies watchers,
so cut one only when the user asks, naming the version or agreeing to the
one you propose.

Not for: landing a change with no release (skill `ship`); bumping
`flake.moduleGraph`'s `version`, which moves only by `doc/format.md`'s rule.

## Which number

Until `1.0` (`CHANGELOG.md`'s introduction), anything under **Breaks**
increments the minor number (`v0.2.0` -> `v0.3.0`); with no breaks, the
patch number (`v0.1.0` -> `v0.1.1`).

## 1. The release pull request

On the session's branch, from `origin/main`:

- `CHANGELOG.md`: rename `## Unreleased` to `## vX.Y.Z — <today>`, add a
  new, empty `## Unreleased` above it, and update the example tags in the
  introduction. Under the heading, one line says whether a flake on the
  last release may have to change (`A flake on v0.2.0 may have to change:
  read **Breaks**.`), and each **Breaks** entry says what such a flake
  must do, not only what changed.
- Every pin: `git grep -n 'github:NireBryce/dirs-as-categories/v'` -- the
  README, `wiki/using-the-flake.md` and the three example flakes'
  `flake.nix`. `just docs` fails until all of them name the newest
  release.
- `just release-notes` prints exactly what the workflow will publish:
  that release's section and nothing else. It stops with the problem if
  `CHANGELOG.md` doesn't start `## Unreleased`, then `## vX.Y.Z — <date>`.
- `just preflight`, and `just examples` (the hosts with real nixpkgs).

Then skill `ship`: pull request, green CI, one confirmation. Merging
publishes the release, so the question says so: "merge (which tags and
publishes `vX.Y.Z`), and delete the branch afterward?"

## 2. What the merge does

`release.yml` runs on every push to `main`. It reads the newest version
with `tests/release_notes.py`; when that version has no tag, it runs
`gh release create` on the merge commit, which makes the tag (a
lightweight one) and the release together. Every other push finds the
version tagged and does nothing, so a pull request that only adds to
`## Unreleased` releases nothing.

The job never moves or deletes a tag: a flake that pinned one would
silently change. Fix a wrong release with a new patch release. If the
job fails, read its log, fix the cause on a branch, and once the fix is
on `main` the next push releases; to retry without a push, run the
workflow from `main` (`workflow_dispatch`; the GitHub tool
`actions_run_trigger`, or `gh workflow run release`).

## 3. Check it as a user would

```sh
nix flake metadata github:NireBryce/dirs-as-categories/vX.Y.Z
nix eval --json --no-write-lock-file 'github:NireBryce/dirs-as-categories/vX.Y.Z?dir=example-flake/default#moduleGraph'
```

Say what you saw. "Merged", "the release job passed", "tagged" and "the
example flake at the tag evaluates" are different claims.

## See also

- Skill `ship`: the pull request, CI and the confirmation.
- Skill `docs-sync`: a release that changes what a doc says.
- `CHANGELOG.md`'s introduction: what a version number promises.
