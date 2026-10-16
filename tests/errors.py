#!/usr/bin/env python3
"""Each error fixture must fail with the message tests/errors.json gives it.

`nix flake check` already proves every error fixture fails; a Nix check can't
see what the error said, so this reads the messages from `nix eval`.

    python3 tests/errors.py            # from the repository root
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PREFIX = 'category-tree: '


def message(case):
    r = subprocess.run(
        ['nix', 'eval', '--json', f'path:{ROOT}#tests', '--apply', f't: t.force "{case}"'],
        capture_output=True, text=True)
    if r.returncode == 0:
        return None
    hits = [line[line.index(PREFIX) + len(PREFIX):] for line in r.stderr.splitlines() if PREFIX in line]
    return hits[0].strip() if hits else r.stderr.strip().splitlines()[-1]


def main():
    expected = json.loads((ROOT / 'tests' / 'errors.json').read_text())
    failed = 0
    for case, want in sorted(expected.items()):
        got = message(case)
        ok = got is not None and want in got
        failed += not ok
        print(f'{"PASS" if ok else "FAIL"}  {case:18}  {got if got is not None else "(no error)"}')
        if not ok:
            print(f'      expected to contain: {want}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
