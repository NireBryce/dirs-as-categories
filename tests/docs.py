#!/usr/bin/env python3
"""Mechanical checks on the docs, so keeping them true needs less memory.

    python3 tests/docs.py            # from the repository root; `just docs`

Each check prints what it found wrong and where. The checks:

- skills:   every .agents/skills/<name>/SKILL.md is listed in AGENTS.md, and
            every skill AGENTS.md lists exists; frontmatter follows skill
            `new-skill`.
- links:    every relative Markdown link points at a file that exists, and
            every `#anchor` at a heading in that file.
- errors:   every error in doc/convention.md's errors table has an error
            fixture (tests/errors.json) and a row in the wiki's "When
            evaluation stops" table, and every fixture and wiki row matches
            a documented error.
- nix:      every ```nix block parses (as written, or as the body of a set).
- wiki:     every wiki page has a `_Last modified:` line and is listed in
            wiki/00-INDEX.md.
- release:  every `github:NireBryce/dirs-as-categories/v…` pin (README,
            wiki, example-flake) names the newest release in CHANGELOG.md, so
            a release can't leave one behind.
- tracked:  nothing under nix/, tests/ or example-flake/ is untracked. A flake
            sees only files git knows, so an untracked fixture silently
            doesn't exist -- and an error fixture that doesn't exist still
            "fails", for the wrong reason.
- examples: every example-flake/*/ flake appears in tests/default.nix's
            graphs (so `just check` and `just schema` see it) and in
            tests/examples.sh, so a new example can't ship untested.
- fixtures: every tests/fixtures/ tree is a tests/errors.json case or named
            in tests/default.nix, so no fixture is silently never evaluated.
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
problems = []


def problem(where, what):
    problems.append(f'{where}: {what}')


def markdown_files():
    tracked = subprocess.run(['git', 'ls-files', '*.md'], cwd=ROOT, capture_output=True, text=True).stdout
    return [ROOT / line for line in tracked.splitlines() if not line.startswith('tests/fixtures/')]


def rel(path):
    return path.relative_to(ROOT).as_posix()


# ── skills ──────────────────────────────────────────────────────────────────
ALLOWED_KEYS = {'name', 'description', 'when_to_use'}


def frontmatter(path):
    text = path.read_text()
    if not text.startswith('---\n'):
        return None
    block = text[4:text.index('\n---\n', 4)]
    return dict(line.split(': ', 1) for line in block.splitlines() if line.strip())


def check_skills():
    agents = (ROOT / 'AGENTS.md').read_text()
    listed = set(re.findall(r'^\| `([a-z0-9-]+)` \|', agents, re.M))
    present = {path.parent.name for path in (ROOT / '.agents' / 'skills').glob('*/SKILL.md')}
    for name in sorted(present - listed):
        problem('AGENTS.md', f'skill `{name}` is not in the skills table')
    for name in sorted(listed - present):
        problem('AGENTS.md', f'lists skill `{name}`, which has no .agents/skills/{name}/SKILL.md')
    for name in sorted(present):
        path = ROOT / '.agents' / 'skills' / name / 'SKILL.md'
        fields = frontmatter(path)
        if fields is None:
            problem(rel(path), 'no frontmatter')
            continue
        for key in sorted(set(fields) - ALLOWED_KEYS):
            problem(rel(path), f'unknown frontmatter key `{key}` (allowed: {", ".join(sorted(ALLOWED_KEYS))})')
        if fields.get('name') != name:
            problem(rel(path), f'name `{fields.get("name")}` differs from its folder `{name}`')
        if 'description' not in fields:
            problem(rel(path), 'no description')
        for key, value in fields.items():
            if value[:1] in '"\'':
                problem(rel(path), f'{key} opens with a quote')
            if ': ' in value or ' #' in value:
                problem(rel(path), f'{key} contains ": " or " #", which YAML misreads')
        if len(fields.get('description', '')) + len(fields.get('when_to_use', '')) > 1536:
            problem(rel(path), 'description + when_to_use is over 1,536 characters')


# ── links ───────────────────────────────────────────────────────────────────
def slug(heading):
    """GitHub's anchor for a heading: lowercase, punctuation dropped, spaces to hyphens."""
    text = re.sub(r'[`*_]', '', heading.strip().lower())
    text = re.sub(r'[^\w\- ]', '', text)
    return text.replace(' ', '-')


def anchors(path):
    text = re.sub(r'^```.*?^```', '', path.read_text(), flags=re.S | re.M)
    return {slug(match) for match in re.findall(r'^#{1,6} (.+)$', text, re.M)}


def check_links():
    for path in markdown_files():
        text = re.sub(r'^\s*```.*?^\s*```', '', path.read_text(), flags=re.S | re.M)
        text = re.sub(r'`[^`\n]*`', '', text)
        for target in re.findall(r'\]\(([^)\s]+)\)', text):
            if re.match(r'[a-z]+:', target):
                continue
            file_part, _, anchor = target.partition('#')
            linked = (path.parent / file_part).resolve() if file_part else path
            if not linked.exists():
                problem(rel(path), f'link to missing file `{target}`')
            elif anchor and linked.suffix == '.md' and anchor not in anchors(linked):
                problem(rel(path), f'link to missing anchor `{target}`')


# ── errors ──────────────────────────────────────────────────────────────────
def code_cells(text, heading):
    """The first cell of each row of the first table under `heading`, as code."""
    section = text.split(heading, 1)[1]
    rows = re.findall(r'^\| (`.+?`) \|', section.split('\n## ', 1)[0], re.M)
    return [row.strip('`').strip() for row in rows]


def pattern(documented):
    """A documented message as a regex: each `<placeholder>` matches anything."""
    parts = re.split(r'<[^>]+>', documented)
    return re.compile('.+?'.join(map(re.escape, parts)))


def check_errors():
    documented = code_cells((ROOT / 'doc' / 'convention.md').read_text(), '## Errors')
    patterns = {row: pattern(row) for row in documented}
    fixtures = json.loads((ROOT / 'tests' / 'errors.json').read_text())
    wiki = code_cells((ROOT / 'wiki' / 'using-the-flake.md').read_text(), '## When evaluation stops')

    # tests/errors.json holds a part of each message (errors.py checks the
    # real one contains it), so a fixture can stop short of a row's end.
    def fits(row, message):
        return patterns[row].search(message) or message.split(': ', 1)[-1] in row

    def matching(message):
        return [row for row in documented if fits(row, message)]

    for case, message in sorted(fixtures.items()):
        if not matching(message):
            problem('tests/errors.json', f'{case}: `{message}` matches no row of doc/convention.md#errors')
    for row in wiki:
        if not matching(row):
            problem('wiki/using-the-flake.md', f'`{row}` matches no row of doc/convention.md#errors')
    for row in documented:
        if not any(fits(row, message) for message in fixtures.values()):
            problem('doc/convention.md', f'error `{row}` has no fixture in tests/errors.json')
        if not any(fits(row, message) for message in wiki):
            problem('doc/convention.md', f'error `{row}` has no row in wiki/using-the-flake.md#when-evaluation-stops')


# ── nix code blocks ─────────────────────────────────────────────────────────
def parses(code):
    run = lambda source: subprocess.run(['nix-instantiate', '--parse', '-E', source],
                                        capture_output=True, text=True).returncode == 0
    return run(code) or run('{\n' + code + '\n}')


def check_nix_blocks():
    for path in markdown_files():
        text = path.read_text()
        for match in re.finditer(r'^( *)```nix\n(.*?)^\1```', text, re.S | re.M):
            indent = len(match.group(1))
            code = '\n'.join(line[indent:] for line in match.group(2).splitlines())
            if not parses(code):
                line = text[:match.start()].count('\n') + 1
                problem(f'{rel(path)}:{line}', 'this nix block does not parse')


# ── wiki ────────────────────────────────────────────────────────────────────
def check_wiki():
    index = (ROOT / 'wiki' / '00-INDEX.md').read_text()
    for path in sorted((ROOT / 'wiki').glob('*.md')):
        head = path.read_text().splitlines()[:3]
        if not any(re.match(r'_Last modified: \d{4}-\d{2}-\d{2}_$', line) for line in head):
            problem(rel(path), 'no `_Last modified: YYYY-MM-DD_` line under the title')
        if path.name != '00-INDEX.md' and f']({path.name})' not in index:
            problem('wiki/00-INDEX.md', f'does not list {path.name}')


# ── release ─────────────────────────────────────────────────────────────
def check_release():
    releases = re.findall(r'^## (v\d+\.\d+\.\d+)\b', (ROOT / 'CHANGELOG.md').read_text(), re.M)
    if not releases:
        problem('CHANGELOG.md', 'no `## vX.Y.Z` release heading')
        return
    newest = releases[0]
    tracked = subprocess.run(['git', 'ls-files'], cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
    for name in tracked:
        if name.startswith('tests/fixtures/') or not name.endswith(('.md', '.nix', '.yml')):
            continue
        for line_number, line in enumerate((ROOT / name).read_text().splitlines(), 1):
            for pinned in re.findall(r'github:NireBryce/dirs-as-categories/(v\d+\.\d+\.\d+)', line):
                if pinned != newest:
                    problem(f'{name}:{line_number}', f'pins {pinned}, but the newest release in CHANGELOG.md is {newest}')


# ── tracked ─────────────────────────────────────────────────────────────────
def check_tracked():
    untracked = subprocess.run(['git', 'ls-files', '--others', '--exclude-standard', 'nix', 'tests', 'example-flake'],
                               cwd=ROOT, capture_output=True, text=True).stdout.split()
    for path in untracked:
        problem(path, 'untracked: the flake can\'t see it until you `git add` it')


# ── examples ────────────────────────────────────────────────────────────────
def strip_nix_comments(text):
    return re.sub(r'#.*', '', re.sub(r'/\*.*?\*/', '', text, flags=re.S))


def check_examples():
    on_disk = {path.name for path in (ROOT / 'example-flake').iterdir()
               if (path / 'flake.nix').exists()}
    tests = strip_nix_comments((ROOT / 'tests' / 'default.nix').read_text())
    graphs = re.findall(r'exampleGraph "([^"]+)"', tests)
    script = (ROOT / 'tests' / 'examples.sh').read_text()
    pairs = re.search(r'^for pair in (.+?); do$', script, re.M).group(1).split()
    in_graphs = set(graphs)
    in_script = {pair.split(':')[0] for pair in pairs}
    for name in sorted(on_disk - in_graphs):
        problem('tests/default.nix', f'example-flake/{name} is in no graphs entry, so `just check` and `just schema` skip it')
    for name in sorted(on_disk - in_script):
        problem('tests/examples.sh', f'example-flake/{name} has no host in the pair list, so `just examples` skips it')


# ── fixtures ────────────────────────────────────────────────────────────────
def check_fixtures():
    on_disk = {path.name for path in (ROOT / 'tests' / 'fixtures').iterdir() if path.is_dir()}
    in_json = set(json.loads((ROOT / 'tests' / 'errors.json').read_text()))
    tests = strip_nix_comments((ROOT / 'tests' / 'default.nix').read_text())
    for name in sorted(on_disk - in_json):
        if f'"{name}"' not in tests and f'fixtures/{name}' not in tests:
            problem('tests/fixtures', f'{name} is in no test: add it to tests/errors.json or name it in tests/default.nix')


def main():
    for check in (check_skills, check_links, check_errors, check_nix_blocks, check_wiki, check_release, check_tracked,
                  check_examples, check_fixtures):
        check()
    for line in problems:
        print(f'FAIL  {line}')
    if not problems:
        print('docs: all checks pass')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
