# TreeSitter4D

[Tree-sitter](https://github.com/tree-sitter/tree-sitter), the incremental parsing library, built
with **C++Builder** and used from **Delphi** and **C++Builder** programs. Everything is
compiled by RAD Studio's own tools: bcc64x for the C, dcc64 for Delphi. There are no DLLs
unless you want them, because the objects link straight into the executable with Delphi's
`{$L}`.

The repository holds only C, Delphi and C++. You don't need Node, Rust or Python to build it:
the grammar's parser is the C that tree-sitter generated, committed here.

*Work in progress: the C side builds. The Delphi and C++Builder programs are next.*

## What's here

| Folder | What | From | Version |
|---|---|---|---|
| `c/tree-sitter` | the runtime (`src/`, `include/`) | [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter), MIT | v0.25.10, `da6fe9beb4f7f67beb75914ca8e0d48ae48d6406` |
| `c/tree-sitter-delphi13` | a Delphi 13 grammar, generated (`parser.c`, `scanner.c`) | [Alexl-git/tree-sitter-delphi13](https://github.com/Alexl-git/tree-sitter-delphi13), MIT | v1.3.0 |

Each folder keeps its project's `LICENSE`. The runtime's `src/wasm` folder is left out: it is
only compiled with `TREE_SITTER_FEATURE_WASM`. `c/tree-sitter/exports.def` lists the API's
functions, for building `tree-sitter.dll`.

## Building the C

From a RAD Studio command prompt:

```
build-c.cmd          rem obj\ts_lib.o, obj\delphi13_parser.o, obj\delphi13_scanner.o
build-c.cmd dll      rem also obj\tree-sitter.dll and obj\tree-sitter-delphi13.dll
```

Tested with bcc64x 7.80 (C++Builder 13, Clang 20). It takes about ten seconds; the grammar
is 17 MB of generated C.

## See also

- [modersohn/delphi-tree-sitter](https://github.com/modersohn/delphi-tree-sitter): a fuller
  Delphi binding of the tree-sitter API, loading `tree-sitter.dll` and a DLL per grammar.
