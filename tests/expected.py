#!/usr/bin/env python3
"""Compare the main fixture's result with tests/expected/main.json.

    python3 tests/expected.py diff     # show every difference; `just expected-diff`
    python3 tests/expected.py accept   # record the current result; `just expected-accept`

Read the diff before accepting: every line in it must be a change you meant.
Both commands evaluate the flake the way `nix flake check` does, so a file git
doesn't know about isn't part of the result.
"""
import difflib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECTED = ROOT / 'tests' / 'expected' / 'main.json'


def render(value):
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n'


def current():
    result = subprocess.run(['nix', 'eval', '--json', f'{ROOT}#tests.main'], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr)
    return render(json.loads(result.stdout))


def main(argv):
    if argv[1:] not in (['diff'], ['accept']):
        sys.exit(__doc__)
    got, want = current(), EXPECTED.read_text()
    if argv[1] == 'accept':
        EXPECTED.write_text(got)
        print(f'recorded {EXPECTED.relative_to(ROOT)}' if got != want else 'no change')
        return 0
    diff = list(difflib.unified_diff(want.splitlines(True), got.splitlines(True),
                                     'tests/expected/main.json', 'current result'))
    sys.stdout.writelines(diff)
    print('no difference' if not diff else '')
    return 1 if diff else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
