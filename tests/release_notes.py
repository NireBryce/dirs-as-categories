#!/usr/bin/env python3
"""The newest release in CHANGELOG.md: its version, or its notes.

    python3 tests/release_notes.py version   # v0.3.0
    python3 tests/release_notes.py notes     # that release's section; `just release-notes`

.github/workflows/release.yml tags and publishes with both. The newest
release is the first `## vX.Y.Z — YYYY-MM-DD` heading, which must come right
after `## Unreleased`; anything else stops with what is wrong, so a
CHANGELOG.md the workflow can't read fails the job instead of publishing
the wrong section.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HEADING = re.compile(r'(v\d+\.\d+\.\d+) — \d{4}-\d{2}-\d{2}')


def newest():
    # sections[0] is the introduction, then one per `## ` heading:
    #   [ "# Changelog …", "Unreleased\n…", "v0.3.0 — 2026-10-23\n…", … ]
    sections = re.split(r'^## ', (ROOT / 'CHANGELOG.md').read_text(), flags=re.M)
    if len(sections) < 3 or sections[1].split('\n', 1)[0] != 'Unreleased':
        sys.exit('CHANGELOG.md: expected `## Unreleased`, then the newest `## vX.Y.Z — YYYY-MM-DD`')
    heading, _, body = sections[2].partition('\n')
    match = HEADING.fullmatch(heading)
    if not match:
        sys.exit(f'CHANGELOG.md: `## {heading}` is not `## vX.Y.Z — YYYY-MM-DD`')
    if not body.strip():
        sys.exit(f'CHANGELOG.md: `## {heading}` has no notes')
    return match.group(1), body.strip() + '\n'


def main(argv):
    if argv[1:] not in (['version'], ['notes']):
        sys.exit(__doc__)
    version, notes = newest()
    sys.stdout.write(version + '\n' if argv[1] == 'version' else notes)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
