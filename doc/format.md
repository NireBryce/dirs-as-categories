# flake.moduleGraph, version 1

What dirs-as-categories built, as data. `nix eval --json .#moduleGraph` prints it.

**Experimental** (see the [README](../README.md)): version 1 is not yet a
stability promise. A breaking change still increments `version`, so a
reader can refuse what it doesn't know, but fields may come and go
between releases.
Paths are relative to the folder passed to `lib.tree`. Every name is unique
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
| `version` | `1`. A change that breaks readers increments it. |
| `classes` | the classes this tree uses |
| `categories.<name>.dir` | the category's folder |
| `categories.<name>.members` | modules beneath it that belong to no nested category |
| `categories.<name>.nested` | categories directly nested in it (no other category between) |
| `categories.<name>.flag` | its `folderIsCategory`, or `null` when the subfolder rule decided |
| `folders[]` | plain folders (not categories) below the top level, with their `folderIsCategory` or `null` |
| `modules.<name>.path` | the module file |
| `modules.<name>.classes` | the classes it declares (including those it only has `includes` for) |
| `includes.<name>.<class>` | names the module imports, as written |
| `enables.<name>.<class>` | names handed to the module as `enabled` |
| `defaults[].path`, `.dir` | the file and its folder |
| `defaults[].category` | the nearest category at or above `dir`, or `null` |
| `defaults[].classes` | the classes it has parts for |
| `admin` | files loaded as ordinary flake-parts modules |
| `orphans` | modules inside a category that no `includes`/`enables` reaches ([convention](convention.md#orphans)); added after version 1's first release, so a reader should treat it as optional |

Top-level folders (areas) are the first component of any path.

A module with `includes` is what a host or a home configuration usually is.
