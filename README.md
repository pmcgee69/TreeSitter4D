# TreeSitter4D

[Tree-sitter](https://github.com/tree-sitter/tree-sitter), the incremental parsing library, built
with **C++Builder** and used from **Delphi** and **C++Builder** programs. 

Everything is compiled by RAD Studio's own tools: bcc64x for the C, dcc64 for Delphi. 

There are no DLLs unless you want them, because the objects link straight into the executable with Delphi's
`{$L}`.

The repository holds C, Delphi and C++ (and [Delf](https://github.com/pmcgee69/delfpascal)). 
You don't need Node, Rust or Python to build it: the grammar's parser is the C that tree-sitter generated, committed here.

## What's here

| Folder | What | From | Version |
|---|---|---|---|
| `c/tree-sitter` | the runtime (`src/`, `include/`) | [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter), MIT | v0.25.10, `da6fe9beb4f7f67beb75914ca8e0d48ae48d6406` |
| `c/tree-sitter-delphi13` | a Delphi 13 grammar, generated (`parser.c`, `scanner.c`) | [Alexl-git/tree-sitter-delphi13](https://github.com/Alexl-git/tree-sitter-delphi13), MIT | v1.3.0 |

Each folder keeps its project's `LICENSE`.  
`c/tree-sitter/exports.def` lists the API's functions, for building `tree-sitter.dll`.

## Building the C

From a RAD Studio command prompt:

```
build-c.cmd          rem obj\ts_lib.o, obj\delphi13_parser.o, obj\delphi13_scanner.o
build-c.cmd dll      rem also obj\tree-sitter.dll and obj\tree-sitter-delphi13.dll
```

Tested with bcc64x 7.80 (C++Builder 13, Clang 20). It takes about ten seconds; the grammar
is 17 MB of generated C.

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
  `{$L}`; `TreeSitter.pas` puts a parser class, a tree class and a node record over it;
  `TsWalk.dpr` is the walker.
- **C++17** (`cpp\tswalk.cpp`): tree-sitter's own `api.h`, the same objects.
- **C++23** (`cpp\tswalk23.cpp`): same, using `std::print`, `std::expected`, ranges,
  and `std::unique_ptr` for C handle ownership.

Over the Delphi 13 RTL's `source\rtl\common` (99 files), all three report the same, line for
line:

```
99 files, 1537727 nodes, 37 misgrouped <, 853-868 ms     (Delphi)
99 files, 1537727 nodes, 37 misgrouped <, 928-939 ms     (C++17)
99 files, 1537727 nodes, 37 misgrouped <, 909-917 ms     (C++23)
```

The 37 are the grammar's misreadings, not bugs in the RTL. Delphi groups them correctly, by definition.

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

It reports the same 37, line for line, in 954-958 ms with `Children` building an array per node.
Other approaches are being examined as well.

## Building the two Delphi walkers with Delphi alone

Both walkers are ordinary Delphi programs. The Delf one is Delphi too: `delf\generated\`
holds everything it needs, so building it takes no Delf tools, only dcc64. Both need the C
objects first (`build-c.cmd`, above), which `TreeSitter.Api.pas` links with
`{$L ..\obj\*.o}`.

The hand-written walker:

```
cd delphi
dcc64 -B -E..\obj -NU..\obj\dcu "-NSSystem;Winapi" TsWalk.dpr
```

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
objects aren't there yet, so **Build All** works from a fresh clone. The same from a RAD Studio
command prompt:

```
msbuild TreeSitter4D.groupproj
```

(Tried from an empty `obj\`: the C objects, then all four walkers, which report the same 37.)

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
