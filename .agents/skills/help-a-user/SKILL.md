---
name: help-a-user
description: How to help someone whose own flake using dirs-as-categories doesn't evaluate or doesn't do what they expect.
when_to_use: A user pastes an error from their flake, or says a host is missing a module, or asks why a file isn't a module.
---

# Helping a user with their flake

## Applies to

Someone's own flake -- not this repository's tests -- stops with an error,
or builds without something they expected. Not for a bug already narrowed
to this repository's code (skill `investigate-bug`).

## 1. Read the error to the bottom

Nix prints the innermost cause last. Find the line starting
`error: dirs-as-categories:` if there is one.

- **It starts `dirs-as-categories:`**: find the message in the table in
  `wiki/using-the-flake.md#when-evaluation-stops` and give the user that
  row's fix, quoting their file's path from the message.
- **It doesn't**: the mistake is outside what dirs-as-categories reads --
  in a class part's own settings, or in an admin file. Say which file Nix
  names, and treat it as an ordinary NixOS, Home Manager or flake-parts
  error.

## 2. If something is missing, ask the graph

```sh
nix eval --json .#moduleGraph --apply 'g: g.includes'       # what each module includes
nix eval --json .#moduleGraph --apply 'g: g.orphans'        # modules nothing reaches
nix eval --json .#moduleGraph --apply 'g: g.admin'          # files loaded as flake-parts modules
nix eval --json .#moduleGraph --apply 'g: g.categories'     # each category's members
```

The usual causes, in order: the file is in `admin` because it has no
class key, or asks for `config` and returns none; the module is an orphan;
the folder the user meant as a category is a plain folder (`folders` in
the graph); `defaults.nix` applies through a category the host doesn't
include.

## 3. Reproduce it here when it looks like ours

If the user's tree does what the rules in `doc/convention.md` say it
shouldn't, or the error is a confusing one dirs-as-categories could have
raised clearly, rebuild the smallest version of their tree as a fixture
(`just new-error <name> '<message>'` for an error) and continue with skill
`investigate-bug`. A confusing error with no dirs-as-categories message is
a missing error: propose one (skill `propose-issue`).

## 4. Say what you checked

Their flake isn't here: say which advice comes from the message alone and
which you reproduced. Examples you give use the user's paths; examples you
write into this repository use generic names (`doc/style.md`).
