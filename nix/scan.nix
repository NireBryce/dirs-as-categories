# nix/scan.nix: reads the modules tree and decides what everything in it is.
#
# In:  `files`, the list of .nix files import-tree found under `root`.
# Out: the attribute set at the bottom of this file: which files are
#      modules, which folders are categories, what each module names in
#      `includes` and `enables`, and the orphans. nix/module.nix turns that
#      into `flake.modules`; nix/publish.nix into `flake.moduleGraph`.
#
# Every decision here comes from a file's path and from the keys of what
# the file evaluates to -- never from `config`. The module system needs
# the names this file decides (and the list of files to import) before
# `config` exists, so reading `config` here would be an infinite recursion.
#
# doc/convention.md states each rule in prose. nix/README.md explains the
# Nix syntax this file uses.
{ lib, inputs, settings, root, files }:
let
    inherit (lib) filter concatMap unique hasPrefix optional length elem attrNames concatStringsSep listToAttrs nameValuePair;
    inherit (settings) classes;

    # Stops evaluation. Every error message starts the same way, so a user
    # can tell it came from here.
    fail = message: throw "dirs-as-categories: ${message}";

    quote     = word: "`${word}`";
    quoteAll  = words: concatStringsSep ", " (map quote words);

    # The candidate a mistyped word most likely meant, or null. Two kinds
    # of near miss count: the same word in another case or spelling
    # (`nixOS`, `home-manager`, `include` for `includes`), and a word at
    # most a couple of letters off (`lcoale` for `locale`).
    looselyEqual = word: candidate:
        let squash = text: lib.toLower (lib.replaceStrings [ "-" "_" ] [ "" "" ] text); in
        squash word == squash candidate || squash word + "s" == squash candidate
        || (word == "hm" && candidate == "homeManager");
    closest = candidates: word:
        let
            loose  = filter (looselyEqual word) candidates;
            limit  = lib.max 1 (lib.stringLength word / 3);
            near   = filter (lib.strings.levenshteinAtMost limit word) candidates;
            byDistance = lib.sort (a: b: lib.strings.levenshtein word a < lib.strings.levenshtein word b) near;
        in
        if loose != [ ] then builtins.head loose
        else if byDistance != [ ] then builtins.head byDistance
        else null;

    # " (did you mean `x`?)", or "" when nothing is close.
    didYouMean = candidates: word:
        let match = closest candidates word; in
        if match == null then "" else " (did you mean ${quote match}?)";

    # ── lookups that stay fast in a large tree ──────────────────────────────
    # Asking "is x in this list?" for every file in turn takes time
    # proportional to files × list (issue 6). A set answers it at once:
    #   setOf [ "a" "b" ] == { a = true; b = true; }, and then  set ? ${x}
    setOf = strings: listToAttrs (map (string: nameValuePair string true) strings);

    # `lib.unique` for strings, in the same order, without comparing each
    # element with every other: an element stays when it is the first with
    # its value. (listToAttrs keeps the first of several equal names.)
    #   uniqueStrings [ "b" "a" "b" ] == [ "b" "a" ]
    uniqueStrings = strings:
        let firstIndex = listToAttrs (lib.imap0 (index: string: nameValuePair string index) strings); in
        map (item: item.string)
            (filter (item: firstIndex.${item.string} == item.index)
                    (lib.imap0 (index: string: { inherit index string; }) strings));

    # groupBy, keyed by a path that may be null (no category): "" stands for null.
    groupByPath = pathOf: list: lib.groupBy (item: let path = pathOf item; in if path == null then "" else path) list;
    inGroup     = groups: path: groups.${if path == null then "" else path} or [ ];

    # ── 1. Paths ────────────────────────────────────────────────────────────
    # Every path from here on is a string relative to the tree's root, such
    # as "shared/base/ssh/ssh.nix". A top-level folder ("shared") is an area.

    rootStr  = toString root;
    relative = file: lib.removePrefix "${rootStr}/" (toString file);

    # dirOf "shared" is ".", so "shared" is top-level.
    isTopLevel = path: dirOf path == ".";

    # Every folder above a path, nearest first:
    #   ancestors "shared/base/ssh/ssh.nix" == [ "shared/base/ssh" "shared/base" "shared" ]
    ancestors = path:
        let parent = dirOf path; in
        if parent == "." then [ ] else [ parent ] ++ ancestors parent;

    # Whether `path` is strictly beneath the folder `dir` (not `dir` itself).
    within = dir: path: hasPrefix "${dir}/" path;

    isDefaults = path: baseNameOf path == "defaults.nix";

    # A module's name is its filename without `.nix`; a default.nix takes
    # its folder's name instead:
    #   nameOf "shared/base/ssh/ssh.nix"         == "ssh"
    #   nameOf "shared/editors/micro/default.nix" == "micro"
    nameOf = path:
        let base = lib.removeSuffix ".nix" (baseNameOf path); in
        if base != "default" then base
        else if isTopLevel path then fail "${path}: a default.nix needs a folder to take its name from"
        else baseNameOf (dirOf path);

    # ── 2. What each file is ────────────────────────────────────────────────
    # Each file is one of three shapes:
    #   "module"   -- a set with class keys (or reserved keys), such as { nixos = …; }
    #   "defaults" -- a defaults.nix
    #   "admin"    -- anything else that is a set or a function: an ordinary
    #                 flake-parts module, imported unchanged (hosts.nix)

    reserved     = [ "includes" "enables" "folderIsCategory" ];
    moduleKeys   = classes ++ reserved;
    defaultsKeys = classes ++ [ "folderIsCategory" ];

    # Fails, naming the file, if the file's set has a key outside `allowed`.
    # Otherwise returns the entry unchanged, so it can sit inside a `map`.
    checkKeys = allowed: entry:
        let
            unknown = filter (key: !(elem key allowed)) (attrNames entry.value);
            quoted  = map (key: quote key + didYouMean allowed key) unknown;
        in
        if unknown == [ ] then entry
        else fail ("${entry.path}: unknown key ${concatStringsSep ", " quoted}; "
                 + "expected one of: ${concatStringsSep ", " allowed}");

    # A file may be a function, `{ lib, inputs, ... }: { nixos = …; }`. To
    # see its keys, this file has to call it -- which is only safe with
    # arguments that exist before `config` does. `lib` and `inputs` do
    # (`inputs` is a flake-parts special argument), so they are the
    # arguments a file can ask for and still be called early.
    earlyArgs = { inherit lib inputs; };

    # The arguments a function needs: those without a default.
    #   requiredArgs ({ lib, inputs ? null, ... }: …) == [ "lib" ]
    requiredArgs = fn: attrNames (lib.filterAttrs (_: hasDefault: !hasDefault) (lib.functionArgs fn));

    # A function asking for anything else (`config`, `withSystem`, …) is
    # never called here: it is an ordinary flake-parts module.
    canCallEarly = raw:
        builtins.isFunction raw && lib.all (arg: elem arg (attrNames earlyArgs)) (requiredArgs raw);

    # A function with a list of arguments gets only those it names, because
    # a function without `...` rejects any others. One written `args: …` (or
    # `{ ... }@args: …`) lists none, so Nix can't tell what it will read: it
    # gets `lib`, `inputs` and the stand-ins below, as `openCall`.
    callEarly = raw:
        let wanted = lib.functionArgs raw; in
        if wanted == { } then openCall raw else raw (builtins.intersectAttrs wanted earlyArgs);

    # ── a function that can't be called early ──
    # A function asking for `config` is usually an ordinary flake-parts
    # module (hosts.nix). Two mistakes look the same from outside, and both
    # end in a confusing error deep in flake-parts:
    #   { pkgs, ... }: { nixos = …; }    -- the arguments belong inside the class
    #   hardware-configuration.nix       -- a NixOS module, not a module file
    # To tell them apart, `peekKeys` calls the function with stand-ins for
    # the arguments that don't exist yet. A stand-in throws if anything
    # reads it, and `tryEval` catches the throw, so `config` is never read:
    # the peek sees the result's keys only when they don't depend on it.

    # Arguments flake-parts passes to every module, besides `lib` and
    # `inputs`; a function written `args@{ config, ... }:` may read any.
    flakePartsArgs = [ "config" "options" "self" "withSystem" "moduleWithSystem"
                       "flake-parts-lib" "getSystem" "specialArgs" ];

    # Arguments only a NixOS, nix-darwin or Home Manager module is given,
    # never a flake-parts one.
    classModuleArgs = [ "pkgs" "modulesPath" "osConfig" "nixosConfig" "darwinConfig" "utils" ];

    standIn  = name: throw "dirs-as-categories read `${name}` while scanning";
    withStandIns = raw: lib.genAttrs (flakePartsArgs ++ requiredArgs raw) standIn // earlyArgs;
    peekKeys = raw:
        let
            wanted  = lib.functionArgs raw;
            all     = withStandIns raw;
            args    = if wanted == { } then all else builtins.intersectAttrs wanted all;
            result  = raw args;
            peeked  = builtins.tryEval (if builtins.isAttrs result then attrNames result else [ ]);
        in
        if peeked.success then peeked.value else [ ];

    # A function written `args: …`, called with stand-ins. It may hand its
    # arguments to a flake-parts module that reads `config`
    # (`args: import ./_hosts.nix args`); then a stand-in throws when the
    # result's keys are read, and the file stays a function -- a flake-parts
    # module, imported unchanged. `tryEval` catches only a `throw`, which is
    # why the stand-ins throw rather than being left out.
    openCall = raw:
        let
            result = raw (withStandIns raw);
            seen   = builtins.tryEval (builtins.isAttrs result && builtins.deepSeq (attrNames result) true);
        in
        if seen.success && seen.value then result else raw;

    # Fails with advice when a function that can't be called early is one
    # of the two mistakes above; otherwise it is an ordinary flake-parts
    # module, "admin".
    lateShape = path: raw:
        let
            late      = filter (arg: !(elem arg (attrNames earlyArgs))) (requiredArgs raw);
            keys      = peekKeys raw;
            classKeys = filter (key: elem key classes) keys;
            example   = if classKeys != [ ] then builtins.head classKeys else builtins.head classes;
            onlyClass = filter (arg: elem arg classModuleArgs) late;
            them      = if length late == 1 then "it" else "them";
            hidden    = "_${baseNameOf path}";
        in
        if lib.any (key: elem key moduleKeys) keys then
            fail ("${path}: asks for ${quoteAll late} at the top of the file, where only `lib` and `inputs` exist; "
                + "move ${them} into the class: `${example} = { ${concatStringsSep ", " late}, ... }: { … };`")
        else if onlyClass != [ ] then
            fail ("${path}: asks for ${quoteAll onlyClass}, which only a NixOS or Home Manager module gets; "
                + "to keep such a module as it is, rename it `${hidden}` (import-tree skips it) "
                + "and import it from a class: `${builtins.head classes}.imports = [ ./${hidden} ];`")
        else "admin";

    # A set with no module key is an ordinary flake-parts module -- unless
    # one of its keys is a class or reserved key in another case or
    # spelling (`nixOS`), the likeliest reason it has none. Only that kind
    # of near miss: a flake-parts option a letter or two from a class name
    # is still a flake-parts option.
    setShape = path: value:
        let nearMisses = filter (key: lib.any (looselyEqual key) moduleKeys) (attrNames value); in
        if nearMisses == [ ] then "admin"
        else fail "${path}: unknown key ${concatStringsSep ", " (map (key: quote key + didYouMean moduleKeys key) nearMisses)}";

    isModuleShaped = value: builtins.isAttrs value && lib.any (key: elem key moduleKeys) (attrNames value);

    # `raw` is what the file contains; `value` is what it evaluates to after
    # an early call (for a function of lib/inputs), or `raw` itself.
    shapeOf = path: raw: value:
        if isDefaults path then
            (if builtins.isAttrs value then "defaults"
             else fail "${path}: defaults.nix must be an attribute set, or a function of lib/inputs returning one")
        else if isModuleShaped value then "module"
        else if builtins.isAttrs value then setShape path value
        else if builtins.isFunction raw then lateShape path raw
        else fail "${path}: expected an attribute set (a module) or a function (a module of lib/inputs, or a flake-parts module)";

    # One entry per file:
    #   { path = "shared/base/locale.nix"; file = /nix/store/…/locale.nix;
    #     value = { nixos = …; }; shape = "module"; }
    entries = map (file:
        let
            path  = relative file;
            raw   = import file;
            value = if canCallEarly raw then callEarly raw else raw;
        in
        { inherit path file value; shape = shapeOf path raw value; }) files;

    ofShape  = shape: filter (entry: entry.shape == shape) entries;
    admin    = ofShape "admin";
    defaults = map (checkKeys defaultsKeys) (ofShape "defaults");

    # Module entries gain a `name`, and `classesOf`: the classes the file
    # declares the module in -- those it has a key for, or `includes` for.
    moduleFiles = map (entry: checkKeys moduleKeys entry // {
        name      = nameOf entry.path;
        classesOf = filter (class: entry.value ? ${class} || (entry.value.includes or { }) ? ${class}) classes;
    }) (ofShape "module");

    # A module file holding only `folderIsCategory` declares no module.
    modules   = filter (mod: mod.classesOf != [ ]) moduleFiles;
    hasClass  = class: mod: elem class mod.classesOf;
    modulesOf = class: filter (hasClass class) modules;

    # ── 3. Which folders are categories ─────────────────────────────────────

    moduleDirs = uniqueStrings (map (mod: dirOf mod.path) modules);

    # The folders with a module in one of their subfolders, at any depth:
    # every folder strictly above a folder that holds a module.
    hasModuleBelow = setOf (concatMap ancestors moduleDirs);

    # Every folder that holds a module file or a defaults.nix, at any depth.
    folders = uniqueStrings (concatMap (entry: ancestors entry.path) (moduleFiles ++ defaults));

    # { <folder> = [ the module files and defaults.nix directly in it ]; }
    filesByDir = lib.groupBy (entry: dirOf entry.path) (moduleFiles ++ defaults);

    # The `folderIsCategory` that the files directly in `dir` set, or null
    # when none sets one. Files that disagree are an error.
    flagOf = dir:
        let
            filesHere = filesByDir.${dir} or [ ];
            flags     = unique (concatMap (entry: optional (entry.value ? folderIsCategory) entry.value.folderIsCategory)
                                          filesHere);
        in
        if flags == [ ] then null
        else if length flags > 1 then fail "${dir}: files disagree on folderIsCategory"
        else if !builtins.isBool (builtins.head flags) then fail "${dir}: folderIsCategory must be true or false"
        else builtins.head flags;

    # A folder below the top level is a category when its flag says so, or,
    # with no flag, when one of its subfolders (at any depth) holds a module.
    isCategory = dir:
        let flag = flagOf dir; in
        if isTopLevel dir then
            (if flag == true then fail "${dir}: a top-level folder is an area and can't be a category" else false)
        else if flag != null then flag
        else hasModuleBelow ? ${dir};

    categories    = filter isCategory folders;
    categorySet   = setOf categories;
    isCategoryDir = dir: categorySet ? ${dir};

    # The categories above a path, nearest first.
    categoriesAbove = path: filter isCategoryDir (ancestors path);

    # The nearest category strictly above a path, or null. For a module
    # file, this is the category the module belongs to.
    categoryAbove = path:
        let above = categoriesAbove path; in
        if above == [ ] then null else builtins.head above;

    categoryAtOrAbove = dir: if isCategoryDir dir then dir else categoryAbove dir;

    # What a category imports directly: its own modules, and the categories
    # nested in it with no other category between. Grouped once, in tree
    # order, rather than searched for once per category.
    modulesByCategory    = groupByPath (mod: categoryAbove mod.path) modules;
    categoriesByCategory = groupByPath categoryAbove categories;
    ownModules = inGroup modulesByCategory;
    nestedIn   = inGroup categoriesByCategory;

    # ── 4. Names ────────────────────────────────────────────────────────────
    # Modules and categories share one namespace: a name means one thing.

    named = map (mod: { inherit (mod) name path; }) modules
         ++ map (dir: { name = baseNameOf dir; path = dir; }) categories;

    # { <name> = [ <path> <path> … ]; } for each name more than one thing has.
    pathsByName = lib.groupBy' (paths: item: paths ++ [ item.path ]) [ ] (item: item.name) named;
    clashes     = lib.filterAttrs (_: paths: length paths > 1) pathsByName;

    # A name that Nix itself treats specially. `builtins.toJSON` and string
    # interpolation read a set with an `outPath` as that one value, so a
    # module called `outPath` would replace all of `moduleGraph.modules`
    # with its own record. (Names starting with `_`, such as `__functor`,
    # never get here: import-tree skips those paths.)
    reservedNames = setOf [ "outPath" ];
    reservedUses  = filter (item: reservedNames ? ${item.name}) named;
    reservedMessage = item: "${item.path}: `${item.name}` can't be a name: Nix reads a set with an `outPath` "
        + "as a path, so the published graph would lose every other module; rename it";

    known   = map (item: item.name) named;
    knownIn = class: map (mod: mod.name) (modulesOf class) ++ map baseNameOf categories;

    # The same, as sets, for checking every reference without a search each.
    knownSet     = setOf known;
    knownInClass = lib.genAttrs classes (class: setOf (knownIn class));

    # Every name a file lists in `includes` or `enables`, one record each:
    #   { from = "hosts/laptop.nix"; kind = "includes"; class = "nixos"; name = "base"; }
    # They are all checked up front, rather than when a host happens to use
    # them -- an `enables` entry nothing reads would never be checked.
    referencesOf = mod: kind:
        lib.concatLists (lib.mapAttrsToList
            (class: names: map (name: { from = mod.path; inherit kind class name; }) names)
            (mod.value.${kind} or { }));
    references = concatMap (mod: referencesOf mod "includes" ++ referencesOf mod "enables") moduleFiles;

    # What is wrong with one reference, or null when nothing is.
    plainFolders = filter (dir: !isTopLevel dir && !(isCategoryDir dir)) folders;

    # Advice for a name that is a plain folder's: such a folder has no name.
    plainFolderHint = name:
        let
            dir      = lib.findFirst (folder: baseNameOf folder == name) null plainFolders;
            category = categoryAbove dir;
            include  = if category == null then "" else "include its category ${quote (baseNameOf category)}, or ";
        in
        " (${dir} is a plain folder, which has no name; ${include}make the folder a category with folderIsCategory = true)";

    referenceProblem = { from, kind, class, name }:
        let where = "${from}: ${kind}.${class}"; in
        if !(elem class classes) then "${where}: unknown class${didYouMean classes class}"
        else if knownInClass.${class} ? ${name} then null
        else if knownSet ? ${name} then "${where}: `${name}` has no ${class} module"
        else if lib.any (dir: baseNameOf dir == name) plainFolders then "${where}: unknown name `${name}`${plainFolderHint name}"
        else "${where}: unknown name `${name}`${didYouMean (knownIn class) name}";

    referenceProblems = filter (problem: problem != null) (map referenceProblem references);

    # ── 5. Orphans ──────────────────────────────────────────────────────────
    # An orphan is a module inside a category that no `includes` or
    # `enables` reaches: it evaluates fine and installs nothing, so no error
    # would ever mention it. Naming the module or any category above it
    # reaches it, since a category includes everything beneath it. Modules
    # outside every category are entry points (hosts, home configurations)
    # that nothing is meant to name, so they are never orphans.

    reachedNames = setOf (map (reference: reference.name) references);
    isReached    = mod: reachedNames ? ${mod.name}
                     || lib.any (category: reachedNames ? ${baseNameOf category}) (categoriesAbove mod.path);
    isOrphan     = mod: categoriesAbove mod.path != [ ] && !(isReached mod);
    orphans      = map (mod: mod.name) (filter isOrphan modules);

    # ── 6. Where each defaults.nix applies ──────────────────────────────────
    # A defaults.nix in a folder applies whenever anything in that folder's
    # subtree is reached: through the nearest category at or above the
    # folder, or through including any module or category inside it.

    defaultsReach = defaultsFile:
        let dir = dirOf defaultsFile.path; in
        { inherit dir; category = categoryAtOrAbove dir; };

    # `target` is a module's path or a category's folder.
    appliesTo = defaultsFile: target:
        let reach = defaultsReach defaultsFile; in
        target == reach.dir || within reach.dir target || target == reach.category;

    # ── 7. Errors that need the whole tree ──────────────────────────────────
    # nix/module.nix asserts this, so these errors stop evaluation even
    # when nothing else happens to look at the names involved.
    clashMessages = lib.mapAttrsToList (name: paths: "${name} (${concatStringsSep ", " paths})") clashes;
    checked =
        if reservedUses != [ ] then fail (reservedMessage (builtins.head reservedUses))
        else if clashes != { } then fail "names used more than once: ${concatStringsSep "; " clashMessages}"
        else if referenceProblems != [ ] then fail (concatStringsSep "; " referenceProblems)
        else true;
in
{
    inherit rootStr isTopLevel admin defaults modules hasClass modulesOf categories isCategoryDir folders flagOf
            ownModules nestedIn defaultsReach appliesTo orphans checked;
}
