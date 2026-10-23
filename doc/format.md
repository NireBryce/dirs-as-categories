# flake.moduleGraph, version 1

dirs-as-categories publishes what it built, as data, in `flake.moduleGraph`.
To print the graph, run `nix eval --json .#moduleGraph`.

**This format is experimental** (see the [README](../README.md)): version 1
does not yet promise stability. A breaking change still increments
`version`, so a reader can refuse a version it doesn't know, but fields may
come and go between releases.

[`format.schema.json`](format.schema.json) is the same format as a JSON
Schema (draft 2020-12), which `just schema` checks every graph the tests
build against. It rejects fields it doesn't know, so validate with the
schema from the release you read.

Paths are relative to the folder you pass to `lib.tree`. Every name is unique
across modules and categories.

```json
{
  "version": 1,
  "classes": ["nixos", "homeManager", "darwin"],
  "categories": {
    "base": { "dir": "shared/base", "members": ["locale", "ssh"], "nested": [], "flag": null }
  },
  "folders": [
    { "dir": "shared/base/ssh", "flag": null }
  ],
  "modules": {
    "ssh":    { "path": "shared/base/ssh/ssh.nix", "classes": ["nixos"] },
    "laptop": { "path": "hosts/laptop.nix",        "classes": ["nixos"] }
  },
  "includes": { "laptop": { "nixos": ["base"] } },
  "enables":  { "home": { "homeManager": ["my-home"] } },
  "defaults": [
    { "path": "shared/base/defaults.nix", "dir": "shared/base", "category": "shared/base", "classes": ["nixos"] }
  ],
  "admin": ["hosts/hosts.nix"],
  "orphans": []
}
```

| Field | Content |
|---|---|
| `version` | the format's version, `1` (in every release since `v0.1.0`); any change that breaks readers increments `version` |
| `classes` | the classes this tree uses |
| `categories.<name>.dir` | the category's folder |
| `categories.<name>.members` | modules beneath the category that belong to no nested category |
| `categories.<name>.nested` | categories directly nested in this category (no other category between) |
| `categories.<name>.flag` | the category's `folderIsCategory`, or `null` when the subfolder rule decided |
| `folders[]` | plain folders (not categories) below the top level, each with the folder's `folderIsCategory` or `null` |
| `modules.<name>.path` | the module file |
| `modules.<name>.classes` | the classes the module declares, including classes where the module only has `includes` |
| `includes.<name>.<class>` | names the module imports, as written |
| `enables.<name>.<class>` | names the module receives as `enabled` |
| `defaults[].path`, `.dir` | the defaults file and its folder |
| `defaults[].category` | the nearest category at or above `dir`, or `null` |
| `defaults[].classes` | the classes the defaults file has parts for |
| `admin` | files dirs-as-categories loads as ordinary flake-parts modules |
| `orphans` | modules inside a category that no `includes`/`enables` reaches ([convention](convention.md#orphans)); optional when reading, because this field arrived after version 1's first release |

The first component of every path is a top-level folder (an area), except
for a file directly in the tree's root: a root `defaults.nix` has `dir`
`"."` and `category` `null`.

A host or a home configuration is usually a module with `includes`.
