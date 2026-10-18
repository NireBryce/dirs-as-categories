#!/usr/bin/env python3
"""Every graph the tests build must match doc/format.schema.json.

    python3 tests/schema.py      # from the repository root; `just schema`

Also checks that the schema's top-level fields are the ones doc/format.md's
table describes, so the two can't drift. Needs the jsonschema package, which
the development shell (`nix develop ./dev`) provides.
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

try:
    import jsonschema
except ImportError:
    sys.exit('tests/schema.py needs the jsonschema package: run it inside `nix develop ./dev`')


def main():
    schema = json.loads((ROOT / 'doc' / 'format.schema.json').read_text())
    jsonschema.Draft202012Validator.check_schema(schema)
    failed = 0

    table = (ROOT / 'doc' / 'format.md').read_text().split('| Field | Content |', 1)[1]
    documented = set(re.findall(r'^\| `([a-z]+)', table, re.M))
    in_schema = set(schema['properties'])
    for field in sorted(documented ^ in_schema):
        where = 'doc/format.md' if field in in_schema else 'doc/format.schema.json'
        print(f'FAIL  `{field}` is missing from {where}')
        failed += 1

    result = subprocess.run(['nix', 'eval', '--json', f'{ROOT}#tests.graphs'], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr)
    validator = jsonschema.Draft202012Validator(schema)
    for name, graph in sorted(json.loads(result.stdout).items()):
        errors = sorted(validator.iter_errors(graph), key=lambda error: list(error.path))
        for error in errors:
            print(f'FAIL  {name}: {"/".join(map(str, error.path)) or "(top)"}: {error.message}')
        failed += len(errors)
        if not errors:
            print(f'PASS  {name}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
