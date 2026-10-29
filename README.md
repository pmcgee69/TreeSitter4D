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
Exit( S.Split([#13#10, #10]).Map(Trim).Join(' ') );
const Files := Args.AndThen(FilesOf);
```

Beside them, `delf\generated\` is the Delphi the transpiler made, unedited, with the runtime
units it uses (`Delf.Optional.pas`, `Delf.Prelude.pas`, `Delf.Tuples.pas`). It uses the same
`TreeSitter.Api.pas` and the same objects.

```
build-delf.cmd
obj\delf\TsWalk.exe <file or folder>...
```

It reports the same 37, line for line, in 958-1078 ms with `Children` building an array per node.
Other approaches are being examined as well.

## See also

- [modersohn/delphi-tree-sitter](https://github.com/modersohn/delphi-tree-sitter): a fuller
  Delphi binding of the tree-sitter API, loading `tree-sitter.dll` and a DLL per grammar.
