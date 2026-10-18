#!/usr/bin/env python3
"""How evaluation time grows with the modules tree.

    python3 tests/bench.py       # from the repository root; `just bench`

Generates trees of SMALL and LARGE modules (10 per category, each in its own
plain folder, one host including every category), evaluates each one's
`flake.moduleGraph` and `flake.modules` names, and fails when the large tree
costs more than RATIO times the small one, or more than CEILING seconds.
LARGE is 4 x SMALL, so growth in proportion to the tree is about 4 x; the
ratio, unlike a time, doesn't depend on how fast the machine is.
"""
import pathlib
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SMALL, LARGE = 500, 2000
RATIO = 6.0
CEILING = 30.0


def tree(base, modules):
    categories = modules // 10
    for category in range(categories):
        for module in range(10):
            path = base / 'shared' / f'cat{category}' / f'sub{module}' / f'mod{category}x{module}.nix'
            path.parent.mkdir(parents=True)
            path.write_text('{ nixos = { }; }\n')
    (base / 'hosts').mkdir()
    includes = ' '.join(f'"cat{category}"' for category in range(categories))
    (base / 'hosts' / 'host.nix').write_text(f'{{ includes.nixos = [ {includes} ]; }}\n')


def seconds(base):
    expression = f'''
        let repo = builtins.getFlake "path:{ROOT}";
            flake-parts = repo.inputs.flake-parts;
            flake = flake-parts.lib.mkFlake {{ inputs = {{ self = {{ }}; inherit flake-parts; }}; }} {{
                systems = [ ];
                imports = [ flake-parts.flakeModules.modules (repo.lib.tree {base}) ];
            }};
        in builtins.deepSeq [ flake.moduleGraph (builtins.mapAttrs (_: builtins.attrNames) flake.modules) ] true'''
    start = time.monotonic()
    result = subprocess.run(['nix', 'eval', '--impure', '--expr', expression], capture_output=True, text=True)
    elapsed = time.monotonic() - start
    if result.returncode != 0:
        sys.exit(result.stderr)
    return elapsed


def main():
    with tempfile.TemporaryDirectory() as scratch:
        times = {}
        for modules in (SMALL, LARGE):
            base = pathlib.Path(scratch) / str(modules)
            tree(base, modules)
            seconds(base)                       # warm: fetch inputs, fill the eval cache
            times[modules] = min(seconds(base) for _ in range(2))
            print(f'{modules:5} modules: {times[modules]:.2f} s')
    ratio = times[LARGE] / times[SMALL]
    print(f'{LARGE // SMALL} x the modules: {ratio:.1f} x the time (limit {RATIO})')
    failed = ratio > RATIO or times[LARGE] > CEILING
    if times[LARGE] > CEILING:
        print(f'FAIL  {LARGE} modules took over {CEILING:.0f} s')
    if ratio > RATIO:
        print(f'FAIL  evaluation time grows faster than the tree')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
