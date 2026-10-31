program TsWalk;

{ Parses Delphi files with tree-sitter, walks every node, and lists where the
  grammar groups a `<` wrongly: as the right operand of a tighter operator,
  A + (B < C), or of `not`, where Delphi reads (A + B) < C.

  TsWalk <file or folder>...   (a folder: its .pas files, recursively) }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.StrUtils, System.IOUtils, System.Diagnostics, System.RegularExpressions, TreeSitter.Api, TreeSitter;

var
  Nodes, Found : Int64;
  Current      : string;   // the file being walked, written before its first finding

// the adding and multiplying operators, which bind tighter than a comparison
function Tighter(const Op: string): Boolean;
begin
  Result := MatchStr(Op, ['kAdd', 'kSub', 'kOr', 'kXor', 'kMul', 'kFdiv',
                          'kDiv', 'kMod', 'kAnd', 'kShl', 'kShr']);
end;

// a node's text, on one line: a line break and the indent after it become a space
function OneLine(const S: string): string;
begin
  Result := TRegEx.Replace(S, '[\r\n]\s*', ' ');
end;

procedure Check(Tree: TTSTree; const Node: TTSNode);
begin
  var Unary := Node.Kind = 'exprUnary';
  var Op    := Node.Field('operator').Kind;
  if not (Tighter(Op) or (Unary and (Op = 'kNot'))) then
    Exit;

  var Inner := Node.Field(if Unary then 'operand' else 'rhs');
  if Inner.IsNull or (Inner.Kind <> 'exprBinary') or (Inner.Field('operator').Kind <> 'kLt') then
    Exit;

  Inc(Found);
  if Current <> '' then
  begin
    Writeln(Current);
    Current := '';
  end;
  var Head := if Unary then 'not' else OneLine(Tree.Text(Node.Field('lhs'))) + ' ' + Tree.Text(Node.Field('operator'));
  var B    := OneLine(Tree.Text(Inner.Field('lhs')));
  var C    := OneLine(Tree.Text(Inner.Field('rhs')));
  Writeln(Node.Line:6, '  tree-sitter: ', Head, ' (', B, ' < ', C, ')',
          '   Delphi: (', Head, ' ', B, ') < ', C);
end;

procedure Walk(Tree: TTSTree; const Node: TTSNode);
begin
  Inc(Nodes);
  var Kind := Node.Kind;
  if (Kind = 'exprBinary') or (Kind = 'exprUnary') then
    Check(Tree, Node);
  for var I := 0 to Node.ChildCount - 1 do
    Walk(Tree, Node.Child(I));
end;

procedure WalkFile(Parser: TTSParser; const FileName: string);
begin
  Current := FileName;
  var Tree := Parser.Parse(TFile.ReadAllText(FileName));
  try
    Walk(Tree, Tree.Root);
  finally
    Tree.Free;
  end;
end;

begin
  var Parser := TTSParser.Create(tree_sitter_delphi13);
  try
    var Files  := 0;
    var Watch  := TStopwatch.StartNew;
    for var I := 1 to ParamCount do
      if TDirectory.Exists(ParamStr(I)) then
        for var F in TDirectory.GetFiles(ParamStr(I), '*.pas', TSearchOption.soAllDirectories) do
        begin
          WalkFile(Parser, F);
          Inc(Files);
        end
      else
      begin
        WalkFile(Parser, ParamStr(I));
        Inc(Files);
      end;
    Writeln(Files, ' files, ', Nodes, ' nodes, ', Found, ' misgrouped <, ',
            Watch.ElapsedMilliseconds, ' ms');
  finally
    Parser.Free;
  end;
end.
