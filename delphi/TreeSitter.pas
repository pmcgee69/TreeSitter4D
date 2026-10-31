unit TreeSitter;

{ A small Delphi layer over tree-sitter: a parser, the tree it makes, and a
  node record with methods. }

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

end.
