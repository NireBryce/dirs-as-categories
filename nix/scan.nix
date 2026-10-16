# What the tree contains, decided from paths and from the shape of what each
# file evaluates to -- never from `config`, so nothing here can recurse
# through the module system. doc/convention.md states each rule.
{ lib, inputs, settings, root, files }:
let
    inherit (lib) filter concatMap unique hasPrefix optional length elem attrNames concatStringsSep;
    inherit (settings) classes;

    fail = message: throw "dirs-as-categories: ${message}";

    # ── paths ───────────────────────────────────────────────────────────────
    rootStr    = toString root;
    rel        = file: lib.removePrefix "${rootStr}/" (toString file);
    isTopLevel = path: dirOf path == ".";
    ancestors  = path: let dir = dirOf path; in if dir == "." then [ ] else [ dir ] ++ ancestors dir;
    within     = dir: path: hasPrefix "${dir}/" path;            # strictly beneath dir
    isDefaults = path: baseNameOf path == "defaults.nix";

    nameOf = path:
        let base = lib.removeSuffix ".nix" (baseNameOf path); in
        if base != "default" then base
        else if isTopLevel path then fail "${path}: a default.nix needs a folder to take its name from"
        else baseNameOf (dirOf path);

    # ── shape: what each file is ────────────────────────────────────────────
    reserved        = [ "includes" "enables" "folderIsCategory" ];
    moduleKeys      = classes ++ reserved;
    defaultsKeys    = classes ++ [ "folderIsCategory" ];

    checkKeys = allowed: entry:
        let unknown = filter (key: !(elem key allowed)) (attrNames entry.value); in
        if unknown == [ ] then entry
        else fail ("${entry.path}: unknown key ${concatStringsSep ", " (map (key: "`${key}`") unknown)}; "
                 + "expected one of: ${concatStringsSep ", " allowed}");

    # A file may be a function of only `lib` and `inputs` -- both exist
    # before `config` does (`inputs` is a flake-parts special argument) -- so
    # it can be called here to see what it returns. A function asking for
    # anything else (`config`, `withSystem`, …) is never called: it is an
    # ordinary flake-parts module.
    pure = { inherit lib inputs; };
    callable = raw:
        builtins.isFunction raw
        && lib.all (arg: elem arg (attrNames pure))
                   (attrNames (lib.filterAttrs (_: hasDefault: !hasDefault) (lib.functionArgs raw)));
    call = raw:
        let wanted = lib.functionArgs raw; in
        raw (if wanted == { } then pure else builtins.intersectAttrs wanted pure);

    isModuleShaped = value: builtins.isAttrs value && lib.any (key: elem key moduleKeys) (attrNames value);

    # `value` is what the file evaluates to: a function of lib/inputs has
    # been called, any other function is still a function.
    shapeOf = path: raw: value:
        if isDefaults path then
            (if builtins.isAttrs value then "defaults"
             else fail "${path}: defaults.nix must be an attribute set, or a function of lib/inputs returning one")
        # class keys make a module; anything else -- `{ perSystem = …; }`, or
        # a function of `config` -- is an ordinary flake-parts module
        else if builtins.isAttrs value || builtins.isFunction raw then
            (if isModuleShaped value then "module" else "admin")
        else fail "${path}: expected an attribute set (a module) or a function (a module of lib/inputs, or a flake-parts module)";

    entries = map (file:
        let path  = rel file;
            raw   = import file;
            value = if callable raw then call raw else raw;
        in { inherit path file value; shape = shapeOf path raw value; }) files;

    ofShape  = shape: filter (entry: entry.shape == shape) entries;
    admin    = ofShape "admin";
    defaults = map (checkKeys defaultsKeys) (ofShape "defaults");

    moduleFiles = map (entry: checkKeys moduleKeys entry // {
        name      = nameOf entry.path;
        classesOf = filter (class: entry.value ? ${class} || (entry.value.includes or { }) ? ${class}) classes;
    }) (ofShape "module");

    # a file holding only a flag declares no module
    modules   = filter (mod: mod.classesOf != [ ]) moduleFiles;
    hasClass  = class: mod: elem class mod.classesOf;
    modulesOf = class: filter (hasClass class) modules;

    # ── categories ──────────────────────────────────────────────────────────
    moduleDirs = unique (map (mod: dirOf mod.path) modules);
    folders    = unique (concatMap (entry: ancestors entry.path) (moduleFiles ++ defaults));

    # The folderIsCategory the files directly in a folder give it, or null
    # when none does.
    flagOf = dir:
        let flags = unique (concatMap (entry: optional (entry.value ? folderIsCategory) entry.value.folderIsCategory)
                                      (filter (entry: dirOf entry.path == dir) (moduleFiles ++ defaults)));
        in
        if flags == [ ] then null
        else if length flags > 1 then fail "${dir}: files disagree on folderIsCategory"
        else if !builtins.isBool (builtins.head flags) then fail "${dir}: folderIsCategory must be true or false"
        else builtins.head flags;

    isCategory = dir:
        let flag = flagOf dir; in
        if isTopLevel dir then
            (if flag == true then fail "${dir}: a top-level folder is an area and can't be a category" else false)
        else if flag != null then flag
        else lib.any (within dir) moduleDirs;      # the rule: a subfolder that holds modules

    categories = filter isCategory folders;

    # nearest category strictly above a path; for a file, the one it belongs to
    categoryAbove     = path: let above = filter (dir: elem dir categories) (ancestors path); in
                              if above == [ ] then null else builtins.head above;
    categoryAtOrAbove = dir: if elem dir categories then dir else categoryAbove dir;

    ownModules = category: filter (mod: categoryAbove mod.path == category) modules;
    nestedIn   = category: filter (nested: categoryAbove nested == category) categories;

    # ── names: modules and categories share one namespace ──────────────────
    named   = map (mod: { inherit (mod) name path; }) modules
           ++ map (dir: { name = baseNameOf dir; path = dir; }) categories;
    clashes = lib.filterAttrs (_: paths: length paths > 1)
                  (lib.groupBy' (paths: item: paths ++ [ item.path ]) [ ] (item: item.name) named);

    known   = map (item: item.name) named;
    knownIn = class: map (mod: mod.name) (modulesOf class) ++ map baseNameOf categories;

    # every name in includes/enables, checked up front rather than when a
    # host happens to force it (an unused `enabled` entry never would be)
    references = concatMap (mod: concatMap (kind:
        lib.concatLists (lib.mapAttrsToList (class: names:
            map (name: { from = mod.path; inherit kind class name; }) names)
        (mod.value.${kind} or { })))
    [ "includes" "enables" ]) moduleFiles;

    referenceProblem = { from, kind, class, name }:
        let where = "${from}: ${kind}.${class}"; in
        if !(elem class classes) then "${where}: unknown class"
        else if elem name (knownIn class) then null
        else if elem name known then "${where}: `${name}` has no ${class} module"
        else "${where}: unknown name `${name}`";

    referenceProblems = filter (problem: problem != null) (map referenceProblem references);

    # ── orphans ─────────────────────────────────────────────────────────────
    # A module inside a category that nothing reaches: valid, evaluates, and
    # installs nothing, so evaluation can't report it. Reached means some
    # `includes` or `enables` names the module itself or a category above it
    # (a category includes everything beneath it). Modules outside every
    # category are entry points -- hosts, home aggregates -- and nothing is
    # meant to name them.
    reachedNames = unique (map (reference: reference.name) references);
    orphans = map (mod: mod.name) (filter (mod:
        let above = filter (dir: elem dir categories) (ancestors mod.path); in
        above != [ ] && !(elem mod.name reachedNames) && !(lib.any (category: elem (baseNameOf category) reachedNames) above))
        modules);

    # ── defaults.nix reach ──────────────────────────────────────────────────
    # A defaults.nix in a folder applies whenever anything in that folder's
    # subtree is reached: through the nearest category at or above the
    # folder, or through a direct include of any module or category inside it.
    defaultsReach = defaultsFile:
        let dir = dirOf defaultsFile.path; in
        { inherit dir; category = categoryAtOrAbove dir; };
    appliesTo = defaultsFile: target:
        let reach = defaultsReach defaultsFile; in
        target == reach.dir || within reach.dir target || target == reach.category;

    checked =
        if clashes != { } then
            fail ("names used more than once: "
                + concatStringsSep "; " (lib.mapAttrsToList (name: paths: "${name} (${concatStringsSep ", " paths})") clashes))
        else if referenceProblems != [ ] then fail (concatStringsSep "; " referenceProblems)
        else true;
in
{
    inherit rootStr isTopLevel admin defaults modules hasClass modulesOf categories folders flagOf
            ownModules nestedIn defaultsReach appliesTo orphans checked;
}
