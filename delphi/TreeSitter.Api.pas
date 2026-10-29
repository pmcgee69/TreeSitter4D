unit TreeSitter.Api;

{ The part of tree-sitter's C API (tree_sitter/api.h) these programs use, and
  the Delphi 13 grammar. The C is compiled by C++Builder's bcc64x
  (build-c.cmd) and linked into the executable with $L: no DLLs.

  The objects' C library comes from System.Win.Crtl (msvcrt.dll). What it
  doesn't declare is declared here, from msvcrt.dll too. }

interface

uses
  Winapi.Windows, System.Win.Crtl;

type
  TSParser   = Pointer;
  TSTree     = Pointer;
  TSLanguage = Pointer;

  // passed and returned by value: 32 bytes
  TSNode = record
    Context : array[0..3] of UInt32;
    Id      : Pointer;
    Tree    : Pointer;
  end;

  TSPoint = record
    Row    : UInt32;
    Column : UInt32;
  end;

function  ts_parser_new: TSParser; cdecl; external;
procedure ts_parser_delete(Parser: TSParser); cdecl; external;
function  ts_parser_set_language(Parser: TSParser; Language: TSLanguage): Boolean; cdecl; external;
function  ts_parser_parse_string(Parser: TSParser; OldTree: TSTree; Source: PAnsiChar;
            Length: UInt32): TSTree; cdecl; external;
procedure ts_tree_delete(Tree: TSTree); cdecl; external;
function  ts_tree_root_node(Tree: TSTree): TSNode; cdecl; external;
function  ts_node_type(Node: TSNode): PAnsiChar; cdecl; external;
function  ts_node_is_null(Node: TSNode): Boolean; cdecl; external;
function  ts_node_has_error(Node: TSNode): Boolean; cdecl; external;
function  ts_node_start_byte(Node: TSNode): UInt32; cdecl; external;
function  ts_node_end_byte(Node: TSNode): UInt32; cdecl; external;
function  ts_node_start_point(Node: TSNode): TSPoint; cdecl; external;
function  ts_node_child_count(Node: TSNode): UInt32; cdecl; external;
function  ts_node_child(Node: TSNode; Index: UInt32): TSNode; cdecl; external;
function  ts_node_child_by_field_name(Node: TSNode; Name: PAnsiChar;
            Length: UInt32): TSNode; cdecl; external;

function  tree_sitter_delphi13: TSLanguage; cdecl; external;

implementation

{$L ..\obj\ts_lib.o}
{$L ..\obj\delphi13_scanner.o}
{$L ..\obj\delphi13_parser.o}

const
  CRT = 'msvcrt.dll';

function  iswctype(C: Word; Mask: Word): Integer; cdecl; external CRT;
function  fputc(C: Integer; F: Pointer): Integer; cdecl; external CRT;
function  fwrite(P: Pointer; Size, Count: NativeUInt; F: Pointer): NativeUInt; cdecl; external CRT;
function  fclose(F: Pointer): Integer; cdecl; external CRT;
function  _fdopen(Fd: Integer; Mode: PAnsiChar): Pointer; cdecl; external CRT;
function  _get_osfhandle(Fd: Integer): NativeInt; cdecl; external CRT;
function  _open_osfhandle(H: NativeInt; Flags: Integer): Integer; cdecl; external CRT;
procedure abort; cdecl; external CRT;
procedure _assert(Msg, F: PAnsiChar; Line: Cardinal); cdecl; external CRT;
function  __iob_func: PByte; cdecl; external CRT;

// System.Win.Crtl's malloc, realloc and free are Delphi's memory manager, so
// calloc must be too: msvcrt's calloc gives blocks Crtl's free can't take back
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

end.
