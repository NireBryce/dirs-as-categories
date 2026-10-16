# What the tree contains, decided from paths and from the shape of what each
# file evaluates to -- never from `config`, so nothing here can recurse
# through the module system. doc/convention.md states each rule.
{ lib, inputs, settings, root, files }:
let
    inherit (lib) filter concatMap unique hasPrefix optional length elem attrNames concatStringsSep;
    inherit (settings) classes;

    fail = msg: throw "dirs-as-categories: ${msg}";

    # ── paths ───────────────────────────────────────────────────────────────
    rootStr    = toString root;
    rel        = f: lib.removePrefix "${rootStr}/" (toString f);
    depth      = d: length (lib.splitString "/" d);
    ancestors  = p: let d = dirOf p; in if d == "." then [ ] else [ d ] ++ ancestors d;
    within     = d: p: hasPrefix "${d}/" p;              # strictly beneath d
    isDefaults = p: baseNameOf p == "defaults.nix";

    nameOf = p:
        let base = lib.removeSuffix ".nix" (baseNameOf p); in
        if base != "default" then base
        else if dirOf p == "." then fail "${p}: a default.nix needs a folder to take its name from"
        else baseNameOf (dirOf p);

    # ── shape: what each file is ────────────────────────────────────────────
    reserved        = [ "includes" "enables" "folderIsCategory" ];
    moduleKeys      = classes ++ reserved;
    defaultsKeys    = classes ++ [ "folderIsCategory" ];

    checkKeys = allowed: e:
        let bad = filter (k: !(elem k allowed)) (attrNames e.value); in
        if bad == [ ] then e
        else fail ("${e.path}: unknown key ${concatStringsSep ", " (map (k: "`${k}`") bad)}; "
                 + "expected one of: ${concatStringsSep ", " allowed}");

    # A file may be a function of only `lib` and `inputs` -- both exist
    # before `config` does (`inputs` is a flake-parts special argument) -- so
    # it can be called here to see what it returns. A function asking for
    # anything else (`config`, `withSystem`, …) is never called: it is an
    # ordinary flake-parts module.
    pure = { inherit lib inputs; };
    callable = raw:
        builtins.isFunction raw
        && lib.all (a: elem a (attrNames pure))
                   (attrNames (lib.filterAttrs (_: hasDefault: !hasDefault) (lib.functionArgs raw)));
    call = raw:
        let wanted = lib.functionArgs raw; in
        raw (if wanted == { } then pure else builtins.intersectAttrs wanted pure);

    isModuleShaped = v: builtins.isAttrs v && lib.any (k: elem k moduleKeys) (attrNames v);

    entries = map (f:
        let raw = import f; in
        { path = rel f; file = f; inherit raw; value = if callable raw then call raw else raw; }) files;

    shapeOf = e:
        if isDefaults e.path then
            (if builtins.isAttrs e.value && !builtins.isFunction e.value then "defaults"
             else fail "${e.path}: defaults.nix must be an attribute set, or a function of lib/inputs returning one")
        # a function's result decides: class keys make it a module, anything
        # else (perSystem, imports, flake.*) an ordinary flake-parts module
        else if builtins.isFunction e.raw then (if callable e.raw && isModuleShaped e.value then "module" else "admin")
        # a plain attribute set the same way: `{ perSystem = …; }` is an
        # ordinary flake-parts module
        else if builtins.isAttrs e.value then (if isModuleShaped e.value then "module" else "admin")
        else fail "${e.path}: expected an attribute set (a module) or a function (a module of lib/inputs, or a flake-parts module)";

    ofShape  = s: filter (e: shapeOf e == s) entries;
    admin    = ofShape "admin";
    defaults = map (checkKeys defaultsKeys) (ofShape "defaults");

    moduleFiles = map (e: checkKeys moduleKeys e // {
        name      = nameOf e.path;
        classesOf = filter (c: e.value ? ${c} || (e.value.includes or { }) ? ${c}) classes;
    }) (ofShape "module");

    # a file holding only a flag declares no module
    modules = filter (m: m.classesOf != [ ]) moduleFiles;

    # ── categories ──────────────────────────────────────────────────────────
    moduleDirs = unique (map (m: dirOf m.path) modules);
    folders    = unique (concatMap (e: ancestors e.path) (moduleFiles ++ defaults));

    flagsOf = d: unique (concatMap (e: optional (e.value ? folderIsCategory) e.value.folderIsCategory)
                                   (filter (e: dirOf e.path == d) (moduleFiles ++ defaults)));
    flagOf  = d: let f = flagsOf d; in if f == [ ] then null else builtins.head f;

    isCategory = d:
        let f = flagsOf d; in
        if length f > 1 then fail "${d}: files disagree on folderIsCategory"
        else if f != [ ] && !builtins.isBool (builtins.head f) then fail "${d}: folderIsCategory must be true or false"
        else if depth d < 2 then
            (if f == [ true ] then fail "${d}: a top-level folder is an area and can't be a category" else false)
        else if f == [ true ]  then true
        else if f == [ false ] then false
        else lib.any (within d) moduleDirs;      # the rule: a subfolder that holds modules

    categories = filter isCategory folders;

    # nearest category strictly above a path; for a file, the one it belongs to
    categoryAbove     = p: let cs = filter (d: elem d categories) (ancestors p); in
                           if cs == [ ] then null else builtins.head cs;
    categoryAtOrAbove = d: if elem d categories then d else categoryAbove d;

    ownModules = d: filter (m: categoryAbove m.path == d) modules;
    nestedIn   = d: filter (c: categoryAbove c == d) categories;

    # ── names: modules and categories share one namespace ──────────────────
    named   = map (m: { inherit (m) name path; }) modules
           ++ map (d: { name = baseNameOf d; path = d; }) categories;
    clashes = lib.filterAttrs (_: ps: length ps > 1)
                  (lib.groupBy' (acc: x: acc ++ [ x.path ]) [ ] (x: x.name) named);

    known   = map (x: x.name) named;
    knownIn = class: map (m: m.name) (filter (m: elem class m.classesOf) modules)
                  ++ map baseNameOf categories;

    # every name in includes/enables, checked up front rather than when a
    # host happens to force it (an unused `enabled` entry never would be)
    refProblem = from: kind: class: n:
        if !(elem class classes) then "${from}: ${kind}.${class}: unknown class"
        else if elem n (knownIn class) then null
        else if elem n known then "${from}: ${kind}.${class}: `${n}` has no ${class} module"
        else "${from}: ${kind}.${class}: unknown name `${n}`";
    refProblems = filter (p: p != null) (concatMap (m:
        concatMap (kind: lib.concatLists (lib.mapAttrsToList
            (class: names: map (refProblem m.path kind class) names) (m.value.${kind} or { })))
        [ "includes" "enables" ]) moduleFiles);

    # ── defaults.nix reach ──────────────────────────────────────────────────
    # A defaults.nix in F applies whenever anything in F's subtree is reached:
    # through the nearest category at or above F, or through a direct include
    # of any module or category inside F.
    defaultsReach = D: let F = dirOf D.path; in { dir = F; category = categoryAtOrAbove F; };
    appliesTo     = D: q: let r = defaultsReach D; in
                          q == r.dir || within r.dir q || q == r.category;

    checked =
        if clashes != { } then
            fail ("names used more than once: "
                + concatStringsSep "; " (lib.mapAttrsToList (n: ps: "${n} (${concatStringsSep ", " ps})") clashes))
        else if refProblems != [ ] then fail (concatStringsSep "; " refProblems)
        else true;
in
{
    inherit rootStr depth admin defaults modules categories folders flagOf
            ownModules nestedIn defaultsReach appliesTo checked;
}
