#!/usr/bin/env python3
"""Start an error fixture: a small tree, and the message it must fail with.

    python3 tests/new_error.py <name> '<expected message>'    # `just new-error`

This creates tests/fixtures/err-<name>/modules/ holding one valid module
(a/c/one/x.nix) and adds the message to tests/errors.json. Then edit the tree
so it makes exactly one mistake, `git add` it, and watch `just errors` show
the case failing before you change the code.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main(argv):
    if len(argv) != 3 or not re.fullmatch(r'[a-z0-9-]+', argv[1]):
        sys.exit(__doc__)
    case, message = f'err-{argv[1]}', argv[2]
    tree = ROOT / 'tests' / 'fixtures' / case / 'modules'
    if tree.exists():
        sys.exit(f'{tree.relative_to(ROOT)} already exists')
    errors_file = ROOT / 'tests' / 'errors.json'
    errors = json.loads(errors_file.read_text())
    errors[case] = message
    (tree / 'a' / 'c' / 'one').mkdir(parents=True)
    (tree / 'a' / 'c' / 'one' / 'x.nix').write_text('{ nixos = { }; }\n')
    errors_file.write_text(json.dumps(dict(sorted(errors.items())), indent=4, ensure_ascii=False) + '\n')
    print(f'created {tree.relative_to(ROOT)}/a/c/one/x.nix and added {case} to tests/errors.json')
    print(f'next: make the tree wrong in one way, then `git add {tree.parent.relative_to(ROOT)}` and `just errors`')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
