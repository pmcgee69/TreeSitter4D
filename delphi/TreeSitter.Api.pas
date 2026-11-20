unit TreeSitter.Api;

{ The part of tree-sitter's C API (tree_sitter/api.h) these programs use, and
  the Delphi 13 grammar. Another unit can't add to it: Delphi links the
  objects' functions only for externals declared in the unit that has the $L.

  By default the C is linked into the executable with $L: no DLLs. The
  objects are compiled by C++Builder (build-c.cmd): bcc64x for Win64
  (obj\*.o) and bcc32c for Win32 (obj\win32\*.obj); a release carries them
  ready-made, so Delphi alone can build. The objects' C library comes from
  System.Win.Crtl (msvcrt.dll); what it doesn't declare is declared here, from
  msvcrt.dll too.

  With TS_DLL defined, the same functions come from tree-sitter.dll and
  tree-sitter-delphi13.dll instead, beside the executable. }

interface

uses
  Winapi.Windows, System.Win.Crtl;

type
  TSParser   = Pointer;
  TSTree     = Pointer;
  TSLanguage = Pointer;

  // passed and returned by value: 32 bytes on Win64, 24 on Win32
  TSNode = record
    Context : array[0..3] of UInt32;
    Id      : Pointer;
    Tree    : Pointer;
  end;

  TSPoint = record
    Row    : UInt32;
    Column : UInt32;
  end;

  // a walk of a tree that keeps its way down: its next sibling and its parent in constant time,
  // where ts_node_child(N, I) counts from N's first child (so a loop over a node's children by
  // index is quadratic in their number) and ts_node_parent searches down from the root. 24 bytes
  // on Win64, 20 on Win32; its functions take it by address, and ts_tree_cursor_delete frees
  // what it holds
  TSTreeCursor = record
    Tree    : Pointer;
    Id      : Pointer;
    Context : array[0..2] of UInt32;
  end;

  // an edit of the text, for ts_tree_edit before a parse given the old tree: bytes and points
  // before and after (36 bytes)
  TSInputEdit = record
    StartByte   : UInt32;
    OldEndByte  : UInt32;
    NewEndByte  : UInt32;
    StartPoint  : TSPoint;
    OldEndPoint : TSPoint;
    NewEndPoint : TSPoint;
  end;

  // queries (tree-sitter's query.c, which lib.c includes)
  TSQuery       = Pointer;
  TSQueryCursor = Pointer;
  TSQueryError  = UInt32;   // a C enum: 4 bytes, where a Delphi enumeration would be 1

  // 40 bytes on Win64 (the node's 32, the index, padding), 28 on Win32
  TSQueryCapture = record
    Node  : TSNode;
    Index : UInt32;
  end;
  PSQueryCapture = ^TSQueryCapture;

  TSQueryMatch = record
    Id           : UInt32;
    PatternIndex : UInt16;
    CaptureCount : UInt16;
    Captures     : PSQueryCapture;
  end;

const
  // a C name as linked: Win32's C names begin with an underscore
{$IF Defined(WIN32) and not Defined(TS_DLL)}
  TS_C = '_';
{$ELSE}
  TS_C = '';
{$ENDIF}
  TSQueryErrorNone      = 0;
  TSQueryErrorSyntax    = 1;
  TSQueryErrorNodeType  = 2;
  TSQueryErrorField     = 3;
  TSQueryErrorCapture   = 4;
  TSQueryErrorStructure = 5;
  TSQueryErrorLanguage  = 6;
{$IFDEF TS_DLL}
  TS_RUNTIME = 'tree-sitter.dll';
  TS_GRAMMAR = 'tree-sitter-delphi13.dll';
{$ENDIF}

function  ts_parser_new: TSParser; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_parser_new';
procedure ts_parser_delete(Parser: TSParser); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_parser_delete';
function  ts_parser_set_language(Parser: TSParser; Language: TSLanguage): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_parser_set_language';
function  ts_parser_parse_string(Parser: TSParser; OldTree: TSTree; Source: PByte;
            Length: UInt32): TSTree; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_parser_parse_string';
procedure ts_tree_delete(Tree: TSTree); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_delete';
function  ts_tree_root_node(Tree: TSTree): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_root_node';
function  ts_node_type(Node: TSNode): PAnsiChar; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_type';
function  ts_node_is_null(Node: TSNode): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_is_null';
function  ts_node_has_error(Node: TSNode): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_has_error';
function  ts_node_start_byte(Node: TSNode): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_start_byte';
function  ts_node_end_byte(Node: TSNode): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_end_byte';
function  ts_node_start_point(Node: TSNode): TSPoint; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_start_point';
function  ts_node_child_count(Node: TSNode): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_child_count';
function  ts_node_child(Node: TSNode; Index: UInt32): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_child';
function  ts_node_child_by_field_name(Node: TSNode; Name: PByte;
            Length: UInt32): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_child_by_field_name';

function  ts_node_end_point(Node: TSNode): TSPoint; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_end_point';
// the child that holds (or follows) a byte, and the smallest node spanning a byte range: one
// pass down, not a search of each node's children
function  ts_node_first_child_for_byte(Node: TSNode; Byte: UInt32): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_first_child_for_byte';
function  ts_node_descendant_for_byte_range(Node: TSNode; StartByte, EndByte: UInt32): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_descendant_for_byte_range';
// a node's parent: found by searching down from the root, so a walk that looks up often is
// better done with a cursor, or a table of parents built on the way down
function  ts_node_parent(Node: TSNode): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_node_parent';

function  ts_tree_cursor_new(Node: TSNode): TSTreeCursor; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_new';
procedure ts_tree_cursor_delete(var Cursor: TSTreeCursor); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_delete';
procedure ts_tree_cursor_reset(var Cursor: TSTreeCursor; Node: TSNode); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_reset';
function  ts_tree_cursor_current_node(const [ref] Cursor: TSTreeCursor): TSNode; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_current_node';
function  ts_tree_cursor_current_field_name(const [ref] Cursor: TSTreeCursor): PAnsiChar; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_current_field_name';
function  ts_tree_cursor_current_depth(const [ref] Cursor: TSTreeCursor): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_current_depth';
function  ts_tree_cursor_goto_parent(var Cursor: TSTreeCursor): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_goto_parent';
function  ts_tree_cursor_goto_first_child(var Cursor: TSTreeCursor): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_goto_first_child';
function  ts_tree_cursor_goto_next_sibling(var Cursor: TSTreeCursor): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_goto_next_sibling';
// to the first child holding or after the byte: its index, or -1 for none
function  ts_tree_cursor_goto_first_child_for_byte(var Cursor: TSTreeCursor; Byte: UInt32): Int64; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_cursor_goto_first_child_for_byte';

// the old tree told of an edit, then given to ts_parser_parse_string as OldTree: what didn't
// change is reused, and parsing is quicker
procedure ts_tree_edit(Tree: TSTree; const [ref] Edit: TSInputEdit); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_tree_edit';

function  ts_query_new(Language: TSLanguage; Source: PByte; SourceLength: UInt32;
            out ErrorOffset: UInt32; out ErrorType: TSQueryError): TSQuery; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_new';
procedure ts_query_delete(Query: TSQuery); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_delete';
function  ts_query_pattern_count(Query: TSQuery): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_pattern_count';
function  ts_query_capture_count(Query: TSQuery): UInt32; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_capture_count';
function  ts_query_capture_name_for_id(Query: TSQuery; Index: UInt32;
            out Length: UInt32): PAnsiChar; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_capture_name_for_id';
function  ts_query_cursor_new: TSQueryCursor; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_cursor_new';
procedure ts_query_cursor_delete(Cursor: TSQueryCursor); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_cursor_delete';
procedure ts_query_cursor_exec(Cursor: TSQueryCursor; Query: TSQuery; Node: TSNode); cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_cursor_exec';
function  ts_query_cursor_set_byte_range(Cursor: TSQueryCursor;
            StartByte, EndByte: UInt32): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_cursor_set_byte_range';
function  ts_query_cursor_next_capture(Cursor: TSQueryCursor; out Match: TSQueryMatch;
            out CaptureIndex: UInt32): Boolean; cdecl;
            external {$IFDEF TS_DLL}TS_RUNTIME{$ENDIF} name TS_C + 'ts_query_cursor_next_capture';

function  tree_sitter_delphi13: TSLanguage; cdecl;
            external {$IFDEF TS_DLL}TS_GRAMMAR{$ENDIF} name TS_C + 'tree_sitter_delphi13';

implementation

{$IFNDEF TS_DLL}

{$IFDEF WIN64}
{$L ..\obj\ts_lib.o}
{$L ..\obj\delphi13_scanner.o}
{$L ..\obj\delphi13_parser.o}
{$ENDIF}
{$IFDEF WIN32}
{$L ..\obj\win32\ts_lib.obj}
{$L ..\obj\win32\delphi13_scanner.obj}
{$L ..\obj\win32\delphi13_parser.obj}
{$ENDIF}

const
  CRT = 'msvcrt.dll';

function  __iob_func: PByte; cdecl; external CRT;

// System.Win.Crtl's malloc, realloc and free are Delphi's memory manager, so
// calloc must be too: msvcrt's calloc gives blocks Crtl's free can't take back

{$IFDEF WIN64}
function  iswctype(C: Word; Mask: Word): Integer; cdecl; external CRT;
function  fputc(C: Integer; F: Pointer): Integer; cdecl; external CRT;
function  fwrite(P: Pointer; Size, Count: NativeUInt; F: Pointer): NativeUInt; cdecl; external CRT;
function  fclose(F: Pointer): Integer; cdecl; external CRT;
function  _fdopen(Fd: Integer; Mode: PAnsiChar): Pointer; cdecl; external CRT;
function  _get_osfhandle(Fd: Integer): NativeInt; cdecl; external CRT;
function  _open_osfhandle(H: NativeInt; Flags: Integer): Integer; cdecl; external CRT;
procedure abort; cdecl; external CRT;
procedure _assert(Msg, F: PAnsiChar; Line: Cardinal); cdecl; external CRT;

function calloc(Count, Size: NativeUInt): Pointer; cdecl;
begin
  Result := AllocMem(Count * Size);
end;

// the UCRT's stream accessor, which the runtime calls for stderr, on msvcrt's
// own table (a FILE is 48 bytes on Win64)
function __acrt_iob_func(Index: Cardinal): Pointer; cdecl;
begin
  Result := __iob_func + Index * 48;
end;

// the parser object calls the scanner object: dcc64 links one object to
// another only through a Delphi declaration of the name
procedure tree_sitter_delphi13_external_scanner_create; cdecl; external;
procedure tree_sitter_delphi13_external_scanner_destroy; cdecl; external;
procedure tree_sitter_delphi13_external_scanner_scan; cdecl; external;
procedure tree_sitter_delphi13_external_scanner_serialize; cdecl; external;
procedure tree_sitter_delphi13_external_scanner_deserialize; cdecl; external;
{$ENDIF}

{$IFDEF WIN32}
// bcc32c's objects name the C library with Win32's leading underscore
function  _iswalnum(C: Word): Integer; cdecl; external CRT name 'iswalnum';
function  _iswspace(C: Word): Integer; cdecl; external CRT name 'iswspace';
function  _fputc(C: Integer; F: Pointer): Integer; cdecl; external CRT name 'fputc';
function  _fwrite(P: Pointer; Size, Count: NativeUInt; F: Pointer): NativeUInt; cdecl; external CRT name 'fwrite';
function  _fclose(F: Pointer): Integer; cdecl; external CRT name 'fclose';
function  __fdopen(Fd: Integer; Mode: PAnsiChar): Pointer; cdecl; external CRT name '_fdopen';
function  __get_osfhandle(Fd: Integer): NativeInt; cdecl; external CRT name '_get_osfhandle';
function  __open_osfhandle(H: NativeInt; Flags: Integer): Integer; cdecl; external CRT name '_open_osfhandle';
procedure _abort; cdecl; external CRT name 'abort';
procedure __assert(Msg, F: PAnsiChar; Line: Cardinal); cdecl; external CRT name '_assert';
// 64-bit unsigned division, which the compiler calls for UInt64 on Win32
procedure __aulldiv; external 'ntdll.dll' name '_aulldiv';

function _calloc(Count, Size: NativeUInt): Pointer; cdecl;
begin
  Result := AllocMem(Count * Size);
end;

// bcc32c's stdin, stdout and stderr are __get_std_stream(0, 1, 2): on msvcrt's
// own table (a FILE is 32 bytes on Win32)
function ___get_std_stream(Id: Cardinal): Pointer; cdecl;
begin
  Result := __iob_func + Id * 32;
end;

procedure _tree_sitter_delphi13_external_scanner_create; cdecl; external;
procedure _tree_sitter_delphi13_external_scanner_destroy; cdecl; external;
procedure _tree_sitter_delphi13_external_scanner_scan; cdecl; external;
procedure _tree_sitter_delphi13_external_scanner_serialize; cdecl; external;
procedure _tree_sitter_delphi13_external_scanner_deserialize; cdecl; external;

{$ENDIF}

{$ENDIF}

end.
