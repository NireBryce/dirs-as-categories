# Reading the code

This page is for someone about to read or change the code in `nix/` who
doesn't write Nix every day. It shows how the five files fit together, then
explains each piece of Nix syntax they use, with an example from the code.
The rules themselves are in [`../doc/convention.md`](../doc/convention.md);
how to change one is in the skill
[`change-a-rule`](../.agents/skills/change-a-rule/SKILL.md).

dirs-as-categories is experimental (see the [README](../README.md)).

## How the files fit together

```
your flake:  imports = [ (inputs.dirs-as-categories.lib.tree ./modules) ];
                                         │
nix/default.nix    lib.tree: asks import-tree for every .nix file under ./modules
                                         │  the list of files
nix/module.nix     the flake-parts module; first hands the list to …
                                         │
nix/scan.nix       … which decides what each file is: module, defaults.nix,
                   or ordinary flake-parts module; which folders are
                   categories; and every error
                                         │  the scan's result
nix/module.nix     builds flake.modules.<class>.<name> and imports the
                   ordinary flake-parts modules
nix/publish.nix    builds this tree's flake.moduleGraph from the same scan
                                         │  one report per tree
nix/shared.nix     loaded once however many trees a flake imports: declares
                   the options, publishes the graph, adds the orphan check
```

The split between `scan.nix` and `module.nix` is the one design constraint
to keep in mind. `scan.nix` decides the *names* in `flake.modules` and the
list of files to import. The module system needs both before it can work
out `config`, so `scan.nix` must never read `config`: doing so asks for a
value that depends on itself, and Nix stops with `infinite recursion
encountered`. `module.nix` may read `config`, but only inside a module's
contents, which the module system evaluates later.

## Nix in five minutes

Nix is a language of expressions: every file is one expression, and
evaluating it gives a value. Nix evaluates lazily, so a value is computed
only when something needs it. That is why `scan.nix` can define `fail`
calls all over the place: a `fail` only stops evaluation if the branch
holding it is the one taken.

| You see | It means | From the code |
|---|---|---|
| `{ a = 1; b = "x"; }` | an attribute set (a record, a dictionary) | `{ inherit dir; flag = scan.flagOf dir; }` |
| `[ a b c ]` | a list; elements are separated by spaces, not commas | `[ "includes" "enables" "folderIsCategory" ]` |
| `x: x + 1` | a function of one argument | `path: dirOf path == "."` |
| `a: b: …` | a function of two arguments, one at a time | `within = dir: path: …`, called as `within dir path` |
| `{ lib, inputs, ... }: …` | a function taking a set, picking out `lib` and `inputs`; `...` allows other attributes | the first line of `module.nix` |
| `{ x ? 1 }: …` | an argument with a default | `requiredArgs` in `scan.nix` finds the ones without |
| `f x y` | calling `f` with `x`, then `y`; no parentheses or commas | `filter isCategory folders` |
| `let a = …; in body` | local names, visible in `body` | the top of each file |
| `inherit (lib) filter map;` | short for `filter = lib.filter; map = lib.map;` | the top of `scan.nix` |
| `inherit path;` inside a set | short for `path = path;` | `{ inherit path file value; … }` |
| `a // b` | the set `a` with `b`'s attributes added or replaced | `checkKeys moduleKeys entry // { name = …; }` |
| `s ? key` | whether the set `s` has the attribute `key` | `entry.value ? folderIsCategory` |
| `s.key or d` | `s.key`, or `d` when `s` has no `key` | `mod.value.includes or { }` |
| `s.${name}` | the attribute whose name is the string `name` | `config.flake.modules.${class}.${name}` |
| `"a ${x} b"` | a string with `x` interpolated | every error message |
| `''…''` | a multi-line string | the option description in `module.nix` |
| `if c then a else b` | an expression, like `c ? a : b` elsewhere; there is no `if` without `else` | `nameOf` |
| `throw "msg"` | stop evaluation with an error | `fail` in `scan.nix` |
| `builtins.tryEval e` | `{ success = true; value = e; }`, or `success = false` if evaluating `e` throws; only a `throw` or `assert` is caught | `peekKeys` in `scan.nix` |
| `builtins.deepSeq a b` | `b`, after evaluating all of `a` (not only its outermost layer) | `openCall` in `scan.nix` |
| `args@{ config, ... }: …` | as `{ config, ... }: …`, with the whole argument set also named `args` | the comment on `flakePartsArgs` |
| `assert c; body` | stop evaluation unless `c` is true, else `body` | `assert scan.checked;` in `module.nix` |
| `import ./file.nix` | the value of that file's expression | `import ./scan.nix { … }`: import, then call the function the file is |

### The library functions

`lib` is nixpkgs' standard library. The code uses these:

| Function | Does |
|---|---|
| `map f list` | `f` applied to each element |
| `filter pred list` | the elements where `pred` is true |
| `concatMap f list` | `map`, then join the resulting lists into one |
| `lib.any pred list`, `lib.all pred list` | whether some, or every, element passes |
| `elem x list` | whether `x` is in `list` |
| `unique list` | `list` without repeats, first occurrence kept |
| `attrNames set` | the set's attribute names, sorted |
| `lib.mapAttrs f set` | a set with `f name value` as each value |
| `listToAttrs [ (nameValuePair n v) … ]` | a set built from name–value pairs |
| `genAttrs names f` | `{ <name> = f name; … }` for each name |
| `lib.groupBy' op start key list` | a set of lists, grouping elements by `key element` |
| `lib.functionArgs f` | `{ <argument> = <has a default>; … }` for a function taking a set |
| `lib.setFunctionArgs f args` | `f`, reporting `args` as the arguments it takes |
| `lib.imap0 f list` | `map`, with each element's index (from 0) as `f`'s first argument |
| `lib.groupBy key list` | `{ <key element> = [ the elements with that key, in order ]; }` |
| `lib.throwIfNot cond msg value` | `value`, or a `throw msg` when `cond` is false |
| `lib.findFirst pred default list` | the first element passing `pred`, or `default` |
| `lib.attrValues set` | the set's values, in the order of `attrNames` |
| `lib.optionalString cond s` | `s`, or the empty string when `cond` is false |
| `lib.mkMerge [ a b ]`, `lib.mkIf cond x` | module-system values: the definitions `a` and `b` together; `x` only when `cond` is true |
| `lib.sort less list` | `list` sorted, `less a b` saying whether `a` goes first |
| `lib.toLower s`, `lib.replaceStrings from to s` | `s` in lower case; `s` with each string in `from` replaced by its partner in `to` |
| `lib.strings.levenshtein a b`, `lib.strings.levenshteinAtMost k a b` | how many single-letter edits turn `a` into `b`; whether that is at most `k` |
| `dirOf "a/b/c.nix"`, `baseNameOf "a/b/c.nix"` | `"a/b"`, and `"c.nix"` |

### Module-system words

| Word | Meaning |
|---|---|
| module | a set (or a function returning one) with `imports`, `options` and `config`; NixOS, Home Manager and flake-parts are all built from modules |
| class | which kind of configuration a module is for: `nixos`, `homeManager`, `darwin` |
| `imports` | other modules to merge in |
| `key` | an identity: two imports with one `key` load once |
| `_file` | the file the module system names in errors |
| `config` | the merged result of every module; only safe to read lazily |
| `_module.args` | arguments the module system passes to every module, such as `pkgs` |
| `options` | every declared option, with its type; like `config`, only safe to read lazily |

## Trying an expression

`nix repl` evaluates expressions as you type them:

```sh
nix repl
nix-repl> lib = (builtins.getFlake "github:hercules-ci/flake-parts").inputs.nixpkgs-lib.lib
nix-repl> lib.filter (x: x > 1) [ 1 2 3 ]
[
  2
  3
]
```

To see what dirs-as-categories built from the test fixture, run
`nix eval --json .#tests.main` from the repository root.
