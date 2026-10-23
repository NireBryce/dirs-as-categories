# Contributing

Thanks for looking. dirs-as-categories is **experimental** (see the
[README](README.md)), so changes may break flakes that use it, and each
one says how in the [CHANGELOG](CHANGELOG.md).

- **Reporting a problem**: open an issue with the bug form. It asks for
  the revision, your Nix version, the modules tree and the whole error,
  which is what reproducing it takes. The wiki's
  [table of errors](wiki/using-the-flake.md#when-evaluation-stops) may
  already say what to change.
- **Changing the code or docs**: read
  [Changing dirs-as-categories](wiki/changing-dirs-as-categories.md). In
  short: `nix develop ./dev`, write the failing test first, then
  `just preflight`, and a CHANGELOG line under `Unreleased`.
- **Reading the code**: [`nix/README.md`](nix/README.md) explains the five
  files and the Nix they use.

Pull requests use the template's sections, including **Breaks**: what a
flake using dirs-as-categories would have to change.
