---
name: release
description: How to cut a tagged release of dirs-as-categories -- the changelog, the pins, the tag and the GitHub release.
when_to_use: Asked to release, tag, cut a version, or publish what is on main.
---

# Cutting a release

## Applies to

Publishing what is on `main` as `vX.Y.Z`. This skill does not land
changes (skill `ship`); a release only names changes that have already
landed. A tag and
a GitHub release are public and notify watchers, so cut one only when the
user asks, naming the version or agreeing to the one you propose.

## Which number

Until `1.0` (`CHANGELOG.md`'s introduction), anything under **Breaks** in
`Unreleased` increments the minor number (`v0.1.0` -> `v0.2.0`); with no
breaks, it increments the patch number (`v0.1.0` -> `v0.1.1`).
`flake.moduleGraph`'s `version` is separate and moves only by `doc/format.md`'s rule.

## 1. The release PR (skill `ship`)

On a branch from `origin/main`:

- `CHANGELOG.md`: rename `## Unreleased` to `## vX.Y.Z — <today>` and add a
  new, empty `## Unreleased` above it. Update the example tag in the
  file's introduction.
- Every pin: `git grep -n 'github:NireBryce/dirs-as-categories/v'` -- the
  README, `wiki/using-the-flake.md` and both example flakes' `flake.nix`.
  `just docs` fails until all of them name the new version.
- `just preflight`, and `just examples` (the hosts with real nixpkgs).

Then the usual PR, green CI, one confirmation, merge.

## 2. Tag the merge, then publish

```sh
git switch main && git pull --ff-only
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
python3 - <<'PY' > /tmp/notes.md
import re, pathlib
text = pathlib.Path('CHANGELOG.md').read_text()
print(re.split(r'^## ', text, flags=re.M)[2].split('\n', 1)[1].strip())   # the newest release's section
PY
gh release create vX.Y.Z --title vX.Y.Z --notes-file /tmp/notes.md
```

Check the notes file before publishing: it must be that release's
section and nothing else. Never move or delete a pushed tag, because a
flake that pinned it would silently change. Fix a wrong release with a new
patch release.

## 3. Check it as a user would

```sh
nix flake metadata github:NireBryce/dirs-as-categories/vX.Y.Z
nix eval --json --no-write-lock-file 'github:NireBryce/dirs-as-categories/vX.Y.Z?dir=example-flake/default#moduleGraph'
```

Say what you ran. "Tagged", "released" and "the example flake at the
tag evaluates" are different claims.
