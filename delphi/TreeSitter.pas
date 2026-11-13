unit TreeSitter;

{ A small Delphi layer over tree-sitter: a parser, the tree it makes, a
  node record with methods, and queries: a compiled query (a highlights.scm,
  say) and a cursor that runs it over a node, capture by capture. }

interface

uses
  System.SysUtils, TreeSitter.Api;

type
  TTSNode = record
  private
    FNode: TSNode;
  public
    function Kind: string;
    function IsNull: Boolean;
    function HasError: Boolean;
    function ChildCount: Integer;
    function Child(Index: Integer): TTSNode;
    function Field(const Name: string): TTSNode;   // IsNull when it isn't there
    function StartByte: Integer;
    function EndByte: Integer;
    function Line: Integer;                        // from 1
    function StartPoint: TSPoint;                  // row and column (bytes) from 0
    function EndPoint: TSPoint;
  end;

  TTSTree = class
  private
    FTree   : TSTree;
    FSource : TBytes;
  public
    constructor Create(Tree: TSTree; const Source: TBytes);
    destructor Destroy; override;
    function Root: TTSNode;
    function Text(const Node: TTSNode): string;
  end;

  TTSParser = class
  private
    FParser: TSParser;
  public
    constructor Create(Language: TSLanguage);
    destructor Destroy; override;
    function Parse(const Source: string): TTSTree;
  end;

  // a query that doesn't compile: its kind (Syntax, NodeType, ...) and where
  ETSQuery = class(Exception)
  public
    Kind   : TSQueryError;
    Offset : Integer;   // in the query's UTF-8 bytes
  end;

  TTSQuery = class
  private
    FQuery : TSQuery;
    FNames : TArray<string>;
  public
    constructor Create(Language: TSLanguage; const Source: string);
    destructor Destroy; override;
    function PatternCount: Integer;
    function CaptureName(Index: Integer): string;   // without the @
  end;

  // one capture: the node, the capture's index in the query, and the pattern
  // that made it (the lower, the earlier in the file: a highlighter's winner)
  TTSCapture = record
    Node    : TTSNode;
    Capture : Integer;
    Pattern : Integer;
  end;

  TTSQueryCursor = class
  private
    FCursor : TSQueryCursor;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Exec(Query: TTSQuery; const Node: TTSNode);
    procedure SetByteRange(StartByte, EndByte: Integer);   // before Exec
    function Next(out Capture: TTSCapture): Boolean;       // in the order of the text
  end;

implementation

{ TTSNode }

function TTSNode.Kind: string;
begin
  Result := UTF8ToString(ts_node_type(FNode));
end;

function TTSNode.IsNull: Boolean;
begin
  Result := ts_node_is_null(FNode);
end;

function TTSNode.HasError: Boolean;
begin
  Result := ts_node_has_error(FNode);
end;

function TTSNode.ChildCount: Integer;
begin
  Result := ts_node_child_count(FNode);
end;

function TTSNode.Child(Index: Integer): TTSNode;
begin
  Result.FNode := ts_node_child(FNode, Index);
end;

function TTSNode.Field(const Name: string): TTSNode;
begin
  var Utf8 := UTF8String(Name);
  Result.FNode := ts_node_child_by_field_name(FNode, PByte(Utf8), Length(Utf8));
end;

function TTSNode.StartByte: Integer;
begin
  Result := ts_node_start_byte(FNode);
end;

function TTSNode.EndByte: Integer;
begin
  Result := ts_node_end_byte(FNode);
end;

function TTSNode.Line: Integer;
begin
  Result := ts_node_start_point(FNode).Row + 1;
end;

function TTSNode.StartPoint: TSPoint;
begin
  Result := ts_node_start_point(FNode);
end;

function TTSNode.EndPoint: TSPoint;
begin
  Result := ts_node_end_point(FNode);
end;

{ TTSTree }

constructor TTSTree.Create(Tree: TSTree; const Source: TBytes);
begin
  inherited Create;
  FTree   := Tree;
  FSource := Source;
end;

destructor TTSTree.Destroy;
begin
  ts_tree_delete(FTree);
  inherited;
end;

function TTSTree.Root: TTSNode;
begin
  Result.FNode := ts_tree_root_node(FTree);
end;

function TTSTree.Text(const Node: TTSNode): string;
begin
  if Node.IsNull then
    Exit('');
  Result := TEncoding.UTF8.GetString(FSource, Node.StartByte, Node.EndByte - Node.StartByte);
end;

{ TTSParser }

constructor TTSParser.Create(Language: TSLanguage);
begin
  inherited Create;
  FParser := ts_parser_new;
  if not ts_parser_set_language(FParser, Language) then
    raise Exception.Create('tree-sitter: this runtime doesn''t take the language''s ABI version');
end;

destructor TTSParser.Destroy;
begin
  ts_parser_delete(FParser);
  inherited;
end;

function TTSParser.Parse(const Source: string): TTSTree;
begin
  var Bytes := TEncoding.UTF8.GetBytes(Source);
  Result := TTSTree.Create(ts_parser_parse_string(FParser, nil, PByte(Bytes), Length(Bytes)), Bytes);
end;

{ TTSQuery }

constructor TTSQuery.Create(Language: TSLanguage; const Source: string);
const
  Kinds: array[TSQueryErrorSyntax..TSQueryErrorLanguage] of string =
    ('Syntax', 'NodeType', 'Field', 'Capture', 'Structure', 'Language');
begin
  inherited Create;
  var Utf8 := UTF8String(Source);
  var Offset : UInt32;
  var Kind   : TSQueryError;
  FQuery := ts_query_new(Language, PByte(Utf8), Length(Utf8), Offset, Kind);
  if FQuery = nil then
  begin
    var Name := if (Kind >= Low(Kinds)) and (Kind <= High(Kinds)) then Kinds[Kind] else IntToStr(Kind);
    var E    := ETSQuery.CreateFmt('tree-sitter query: %s error at byte %d', [Name, Offset]);
    E.Kind   := Kind;
    E.Offset := Offset;
    raise E;
  end;
  SetLength(FNames, ts_query_capture_count(FQuery));
  for var I := 0 to High(FNames) do
  begin
    var Len  : UInt32;
    var Name := ts_query_capture_name_for_id(FQuery, I, Len);
    FNames[I] := UTF8ToString(Copy(RawByteString(Name), 1, Len));
  end;
end;

destructor TTSQuery.Destroy;
begin
  if FQuery <> nil then
    ts_query_delete(FQuery);
  inherited;
end;

function TTSQuery.PatternCount: Integer;
begin
  Result := ts_query_pattern_count(FQuery);
end;

function TTSQuery.CaptureName(Index: Integer): string;
begin
  Result := FNames[Index];
end;

{ TTSQueryCursor }

constructor TTSQueryCursor.Create;
begin
  inherited Create;
  FCursor := ts_query_cursor_new;
end;

destructor TTSQueryCursor.Destroy;
begin
  ts_query_cursor_delete(FCursor);
  inherited;
end;

procedure TTSQueryCursor.Exec(Query: TTSQuery; const Node: TTSNode);
begin
  ts_query_cursor_exec(FCursor, Query.FQuery, Node.FNode);
end;

procedure TTSQueryCursor.SetByteRange(StartByte, EndByte: Integer);
begin
  ts_query_cursor_set_byte_range(FCursor, StartByte, EndByte);
end;

function TTSQueryCursor.Next(out Capture: TTSCapture): Boolean;
begin
  var Match : TSQueryMatch;
  var Index : UInt32;
  Result := ts_query_cursor_next_capture(FCursor, Match, Index);
  if not Result then
    Exit;
  var C := Match.Captures;
  Inc(C, Index);
  Capture.Node.FNode := C.Node;
  Capture.Capture    := C.Index;
  Capture.Pattern    := Match.PatternIndex;
end;

end.
