# TreeSitter4D

[Tree-sitter](https://github.com/tree-sitter/tree-sitter), the incremental parsing library, built
with **C++Builder** and used from **Delphi** and **C++Builder** programs. 

Everything is compiled by RAD Studio's own tools: bcc64x and bcc32c for the C, dcc64 and dcc32
for Delphi. Win64 and Win32.

There are no DLLs unless you want them, because the objects link straight into the executable with Delphi's
`{$L}`.

**Only Delphi, no C++Builder?** Take the C ready-made from a
[release](https://github.com/pmcgee69/TreeSitter4D/releases): the objects, or the DLLs
([below](#with-delphi-alone-a-release)).

The repository holds C, Delphi and C++ (and [Delf](https://github.com/pmcgee69/delfpascal)). 
You don't need Node, Rust or Python to build it: the grammar's parser is the C that tree-sitter generated, committed here.

## What's here

| Folder | What | From | Version |
|---|---|---|---|
| `c/tree-sitter` | the runtime (`src/`, `include/`) | [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter), MIT | v0.25.10, `da6fe9beb4f7f67beb75914ca8e0d48ae48d6406` |
| `c/tree-sitter-delphi13` | a Delphi 13 grammar, generated (`parser.c`, `scanner.c`) | [Alexl-git/tree-sitter-delphi13](https://github.com/Alexl-git/tree-sitter-delphi13), MIT | v1.4.11 |

Each folder keeps its project's `LICENSE`.  
`c/tree-sitter/exports.def` lists the API's functions, for building `tree-sitter.dll`; the
`exports-win32.def` files beside it and in `c/tree-sitter-delphi13` do the same for Win32.

## With Delphi alone: a release

A [release](https://github.com/pmcgee69/TreeSitter4D/releases) carries the C compiled, so
nothing but Delphi is needed:

- **`TreeSitter4D-<version>-objects.zip`**: unzip it into the repository's root. It puts the
  objects in `obj\` (Win64) and `obj\win32\` (Win32), where `TreeSitter.Api.pas` links them.
  Then build as [below](#building-the-two-delphi-walkers-with-delphi-alone), with dcc64 or
  dcc32. Nothing to ship with the program.
- **`TreeSitter4D-<version>-dlls.zip`**: `tree-sitter.dll` and `tree-sitter-delphi13.dll`,
  Win64 and Win32. Put the pair beside the executable and define `TS_DLL`
  (`dcc64 -DTS_DLL …`): `TreeSitter.Api.pas` then takes the same functions from them. Other
  bindings that load `tree-sitter.dll` and a grammar DLL can use them too.

Each zip has the licences, and the release lists their SHA-256 sums. Tried from a folder
holding only `delphi\` and the zips' contents: dcc64 and dcc32, objects and DLLs, all four
report the same line as below.

### Making a release

From a RAD Studio command prompt, with Python:

```
build-c.cmd dll
build-c.cmd win32 dll
python tools\package-release.py 0.3.0     rem dist\: the two zips and SHA256SUMS.txt
python tools\test-release.py 0.3.0        rem as a Delphi-only user would: all four must give the line below
gh release create v0.3.0 dist\*           rem with notes saying what changed
```

## Building the C

From a RAD Studio command prompt:

```
build-c.cmd              rem Win64: obj\ts_lib.o, obj\delphi13_parser.o, obj\delphi13_scanner.o
build-c.cmd dll          rem also obj\tree-sitter.dll and obj\tree-sitter-delphi13.dll
build-c.cmd win32        rem Win32: obj\win32\ts_lib.obj, …parser.obj, …scanner.obj
build-c.cmd win32 dll    rem also obj\win32\tree-sitter.dll and obj\win32\tree-sitter-delphi13.dll
```

Tested with bcc64x 7.80 (C++Builder 13, Clang 20) and bcc32c 7.80. It takes about ten seconds
each; the grammar is 17 MB of generated C. For Win32 the runtime is compiled through
`c\ts_lib_win32.c`, which says why: bcc32c would otherwise leave five of the runtime's
functions without a body.

## The programs

One program, written three ways: it parses Delphi files, walks every node of the tree, and lists
where the grammar fails by grouping a `<` in opposition to the way Delphi does: 
`A + B < C` read as `A + (B < C)`, vs Delphi's `(A + B) < C`.

```
build-programs.cmd
obj\TsWalk.exe     <file or folder>...      rem Delphi
obj\tswalk_cpp.exe <file or folder>...      rem C++17
obj\tswalk23.exe   <file or folder>...      rem C++23
```

- **Delphi** (`delphi\`): `TreeSitter.Api.pas` declares the C API and links the objects with
  `{$L}` (Win64 or Win32), or with `TS_DLL` defined takes it from the DLLs; `TreeSitter.pas`
  puts a parser class, a tree class, a node record and queries over it; `TsWalk.dpr` is the
  walker, `TsQuery.dpr` runs a query ([below](#queries)).
- **C++17** (`cpp\tswalk.cpp`): tree-sitter's own `api.h`, the same objects.
- **C++23** (`cpp\tswalk23.cpp`): same, using `std::print`, `std::expected`, ranges,
  and `std::unique_ptr` for C handle ownership.

Over the Delphi 13 RTL's `source\rtl\common` (99 files), all three report the same, line for
line:

```
99 files, 1538475 nodes, 0 misgrouped <, 883-892 ms      (Delphi)
99 files, 1538475 nodes, 0 misgrouped <, 967-1064 ms     (C++17)
99 files, 1538475 nodes, 0 misgrouped <, 951-967 ms      (C++23)
```

None, since tree-sitter-delphi13 v1.4.6. Up to v1.4.0 (TreeSitter4D 0.2.0) the same folder gave
**37 misgrouped <** (1,537,727 nodes): the grammar's misreadings, not bugs in the RTL, which
v1.4.6 fixed by giving a generic's `<` a token of its own, decided by looking ahead for its
`>`, so every other `<` is a comparison that binds as `=` and `>` do. The walker is kept as
the check that they stay fixed. The times are four runs each on 14 Nov 2026; earlier figures
here were from another day and aren't comparable.

### Queries

Tree-sitter's query engine is part of the runtime (`lib.c` includes `query.c`), so a query file
such as a grammar's `highlights.scm` runs from Delphi too. `TreeSitter.pas` has `TTSQuery`, a
compiled query (it raises `ETSQuery` with the error's kind and byte offset), and
`TTSQueryCursor`, which runs it over a node, optionally within a byte range, one capture at a
time in the order of the text.

```
obj\TsQuery.exe <query.scm> <file or folder>...   rem every capture: positions, pattern, @name, text
```

With tree-sitter-delphi13's own `queries/highlights.scm` (the same file in v1.4.0 and v1.4.11),
over the RTL's `source\rtl\sys` and `delphi\`'s two units: on v1.4.11, 354,976 captures from
Win64, the same as py-tree-sitter 0.25.2's on the same grammar DLL, in every file (counted
through `QueryCursor.matches`: its `captures` lists a node captured by two patterns under one
name differently). On v1.4.0 it was 354,956, the same from Win64, Win64 with `TS_DLL` and Win32;
and on `System.SysUtils.pas` (1.1 MB): parse 112 ms, the query over the whole file 36 ms, over a
60-line window 0.22 ms. The C library doesn't evaluate predicates (`#match?`, `#eq?`); that
query has none, and a query that has them needs the caller to check them.

## And in Delf

[Delf](https://github.com/pmcgee69/DelfPascal) is Delphi with a stricter, nicer type system,
which a transpiler turns into standard Delphi. `delf\` has the walker once more, in Delf:
`TreeSitter.Nodes.delf`, where a field that may be missing is an `Optional`, and `TsWalk.delf`,
written in Delf's fluent style:

```pascal
Exit( Field(N, 'operator').Map(Kind).OrDefault('') );
Exit( S.Split([CRLF, LF]).Map(Trim).Join(' ') );
const Count := Args.AndThen(ToFiles).Filter(WalkFile).Length;
```

Beside them, `delf\generated\` is the Delphi the transpiler made, unedited, with the runtime
units it uses (`Delf.Optional.pas`, `Delf.Prelude.pas`, `Delf.Tuples.pas`). It uses the same
`TreeSitter.Api.pas` and the same objects. It was made by delfc, from `delf\`, with
`-U ..\delphi` so the transpiler can read `TreeSitter.Api.pas` as dcc64 does:
`delfc -U ..\delphi -o generated\TsWalk.dpr TsWalk.delf`. Building it needs only Delphi
(below).

```
build-delf.cmd
obj\delf\TsWalk.exe <file or folder>...
```

It reports the same line, in 1104-1142 ms (14 Nov, four runs) with `Children` building an array
per node.
Other approaches are being examined as well.

## Building the two Delphi walkers with Delphi alone

Both walkers are ordinary Delphi programs. The Delf one is Delphi too: `delf\generated\`
holds everything it needs, so building it takes no Delf tools, only dcc64. Both need the C
objects first (`build-c.cmd`, above, or a [release](#with-delphi-alone-a-release)), which
`TreeSitter.Api.pas` links with `{$L ..\obj\*.o}`, or `{$L ..\obj\win32\*.obj}` for Win32.

The hand-written walker:

```
cd delphi
dcc64 -B -E..\obj -NU..\obj\dcu "-NSSystem;Winapi" TsWalk.dpr
```

For Win32, dcc32 the same way, into folders of its own (say `-E..\obj\w32 -NU..\obj\dcu32`).
Over `source\rtl\common` it reports the same line.

The Delf walker, from delfc's output: the same, plus `-U` for `TreeSitter.Api.pas`, which it
shares with the hand-written one:

```
cd delf\generated
dcc64 -B -E..\..\obj\delf -NU..\..\obj\dcu-delf "-NSSystem;Winapi" -U..\..\delphi TsWalk.dpr
```

(Create `obj\dcu` and `obj\dcu-delf` first, or leave out `-NU` to put the `.dcu` files beside
the sources.) `build-programs.cmd` and `build-delf.cmd` run exactly these.

### In the IDE

Open **`TreeSitter4D.groupproj`**: the four walkers in one project group, the two Delphi
projects (Win64) and the two C++Builder ones (Win64x, C++17 and C++23), building into the same
`obj\` folders as the scripts, in Release by default. Each runs `build-c.cmd` first if the C
objects aren't there yet, so **Build All** works from a fresh clone. The same from the command
line, with msbuild:

```
build-msbuild.cmd                    rem Release; any msbuild arguments after it, /p:Config=Debug
```

It calls `rsvars.bat` if it isn't a RAD Studio command prompt, and runs
`msbuild TreeSitter4D.groupproj`. Plain `msbuild` can fail on the two C++Builder projects with
`'stdlib.h' file not found` while the IDE builds them: msbuild reads the IDE's paths from
`%APPDATA%\Embarcadero\BDS\37.0\EnvOptions.proj`, which can hold Delphi's paths and none of
C++Builder's, and the IDE keeps C++Builder's in the registry. So `tools\cpp-paths.ps1` writes
`obj\EnvOptions-cpp.proj`, which imports `EnvOptions.proj` and adds the registry's Win64x C++
paths where it has none, and msbuild is given that instead.

(Tried from a fresh clone with an empty `obj\`, the grammar's v1.4.11, on a machine whose
`EnvOptions.proj` had no C++Builder paths: the C objects, then all four walkers, which report
the same 0 misgrouped `<`.)

## Credits

- The Delphi grammar is originally from
  [Alexl-git/tree-sitter-delphi13](https://github.com/Alexl-git/tree-sitter-delphi13), by
  Alexander Liberov (MIT), itself derived in part from
  [Isopod/tree-sitter-pascal](https://github.com/Isopod/tree-sitter-pascal) by Philip Zander
  and Benjamin Gray (MIT).
- [tree-sitter](https://github.com/tree-sitter/tree-sitter), by Max Brunsfeld and its
  contributors (MIT).

## See also

- [modersohn/delphi-tree-sitter](https://github.com/modersohn/delphi-tree-sitter): a fuller
  Delphi binding of the tree-sitter API, loading `tree-sitter.dll` and a DLL per grammar.
