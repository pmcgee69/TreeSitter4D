unit TreeSitter;

{ A small Delphi layer over tree-sitter: a parser, the tree it makes, a
  node record with methods, and queries: a compiled query (a highlights.scm,
  say) and a cursor that runs it over a node, capture by capture. }

interface

uses
  System.SysUtils, System.Generics.Collections, TreeSitter.Api;

type
  TTSNode = record
  private
    FNode: TSNode;
  public
    function Kind: string;
    function IsNull: Boolean;
    function HasError: Boolean;
    function ChildCount: Integer;
    function Child(Index: Integer): TTSNode;       // counts from the first child: see Children
    // every child, in order, by a tree cursor: each step constant, where Child(I) in a loop is
    // quadratic in the number of children (a unit of 3,000 statements in one routine, say)
    function Children: TArray<TTSNode>;
    function Field(const Name: string): TTSNode;   // IsNull when it isn't there
    function StartByte: Integer;
    function EndByte: Integer;
    function Line: Integer;                        // from 1
    function StartPoint: TSPoint;                  // row and column (bytes) from 0
    function EndPoint: TSPoint;
    property Raw: TSNode read FNode;               // for TreeSitter.Api's functions
  end;

  TTSTree = class
  private
    FTree    : TSTree;
    FSource  : TBytes;
    FParents : TDictionary<Pointer, TSNode>;   // a node's id -> its parent; built when first asked
    procedure BuildParents;
  public
    constructor Create(Tree: TSTree; const Source: TBytes);
    destructor Destroy; override;
    function Root: TTSNode;
    function Text(const Node: TTSNode): string;
    // a node's parent (IsNull for the root). tree-sitter's nodes don't hold their parent, and
    // ts_node_parent searches down from the root each time; here the first call walks the tree
    // once with a cursor and keeps a table, and each call after is a lookup (System.SysUtils,
    // 204,062 nodes: every node's parent 5.9 s by ts_node_parent, 0.6 s by a table, in
    // Python). The table costs a dictionary entry per node, kept until the tree is freed
    function Parent(const Node: TTSNode): TTSNode;
    // the parent, its parent, ... up to the root: "which routine is this in?"
    function Ancestors(const Node: TTSNode): TArray<TTSNode>;
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

function TTSNode.Children: TArray<TTSNode>;
begin
  SetLength(Result, ts_node_child_count(FNode));
  if Length(Result) = 0 then
    Exit;
  var Cursor := ts_tree_cursor_new(FNode);
  try
    var I := 0;
    if ts_tree_cursor_goto_first_child(Cursor) then
      repeat
        Result[I].FNode := ts_tree_cursor_current_node(Cursor);
        Inc(I);
      until (I = Length(Result)) or not ts_tree_cursor_goto_next_sibling(Cursor);
    SetLength(Result, I);
  finally
    ts_tree_cursor_delete(Cursor);
  end;
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
  FParents.Free;
  ts_tree_delete(FTree);
  inherited;
end;

procedure TTSTree.BuildParents;
begin
  FParents := TDictionary<Pointer, TSNode>.Create;
  var Cursor := ts_tree_cursor_new(ts_tree_root_node(FTree));
  const Way = TList<TSNode>.Create;   // the root down to the cursor's node
  try
    Way.Add(ts_tree_cursor_current_node(Cursor));
    while True do
    begin
      if ts_tree_cursor_goto_first_child(Cursor) then
      begin
        const N = ts_tree_cursor_current_node(Cursor);
        FParents.AddOrSetValue(N.Id, Way.Last);
        Way.Add(N);
        Continue;
      end;
      // no children: the next sibling, or up until there is one
      while True do
      begin
        if Way.Count = 1 then
          Exit;                       // back at the root: every node seen
        Way.Delete(Way.Count - 1);
        if ts_tree_cursor_goto_next_sibling(Cursor) then
        begin
          const N = ts_tree_cursor_current_node(Cursor);
          FParents.AddOrSetValue(N.Id, Way.Last);
          Way.Add(N);
          Break;
        end;
        ts_tree_cursor_goto_parent(Cursor);
      end;
    end;
  finally
    Way.Free;
    ts_tree_cursor_delete(Cursor);
  end;
end;

function TTSTree.Parent(const Node: TTSNode): TTSNode;
begin
  if FParents = nil then
    BuildParents;
  if not FParents.TryGetValue(Node.FNode.Id, Result.FNode) then
    Result.FNode := Default(TSNode);  // the root, or a node of another tree: null
end;

function TTSTree.Ancestors(const Node: TTSNode): TArray<TTSNode>;
begin
  Result := nil;
  var N := Parent(Node);
  while not N.IsNull do
  begin
    Result := Result + [N];
    N := Parent(N);
  end;
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
