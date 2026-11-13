program TsQuery;

{ Runs a tree-sitter query (a highlights.scm, say) over Delphi files and prints
  every capture, in the order of the text: one line each,

    start-row:col  end-row:col  pattern  @name  text

  rows and columns from 0, columns in UTF-8 bytes, as tree-sitter counts them;
  the text on one line, cut at 40 characters. A node caught by several patterns
  is printed once for each; a highlighter colours it by the lowest pattern.

  TsQuery <query.scm> <file or folder>...   (a folder: its .pas files, recursively)

  Predicted (Claude, 13 Nov, before the first run):
  - tree-sitter-delphi13 v1.4.0's own queries/highlights.scm compiles against
    the v1.4.0 grammar linked here, with no query error;
  - a query naming a node the grammar hasn't ("(noSuchNode) @x") fails with a
    NodeType error at byte 1;
  - the captures equal py-tree-sitter 0.25.2's for the same grammar DLL, query
    and files, compared as sorted lines without the text;
  - the RTL's System.SysUtils.pas, parse and query, takes under a second.

  Seen (Claude, dcc64 and dcc32 37.0, 13 Nov):
  - right: the v1.4.0 query compiles, 48 patterns;
  - right: "NodeType error at byte 1", exit code 1;
  - right: over the RTL's source\rtl\sys (18 .pas files) and this folder's two,
    354,956 captures, the same as py-tree-sitter's in every file; and the same
    output, line for line, from Win64 with $L, Win64 with TS_DLL, and Win32;
  - wrong: System.SysUtils.pas (1.1 MB) took 1,880 ms, but printing its 148,471
    lines is most of that. Without printing: parse 112 ms, the query over the
    whole file 36 ms, over a 60-line window 0.22 ms. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IOUtils, System.Diagnostics, System.RegularExpressions, TreeSitter.Api, TreeSitter;

var
  Captures : Int64;

function OneLine(const S: string): string;
begin
  Result := TRegEx.Replace(S, '[\r\n]\s*', ' ');
  if Length(Result) > 40 then
    Result := Copy(Result, 1, 40) + '...';
end;

procedure QueryFile(Parser: TTSParser; Query: TTSQuery; const FileName: string);
begin
  Writeln('== ', FileName);
  var Tree   := Parser.Parse(TFile.ReadAllText(FileName));
  var Cursor := TTSQueryCursor.Create;
  try
    Cursor.Exec(Query, Tree.Root);
    var C : TTSCapture;
    while Cursor.Next(C) do
    begin
      Inc(Captures);
      var S := C.Node.StartPoint;
      var E := C.Node.EndPoint;
      Writeln(Format('%d:%d %d:%d p%d @%s  ',
                     [S.Row, S.Column, E.Row, E.Column, C.Pattern, Query.CaptureName(C.Capture)]),
              OneLine(Tree.Text(C.Node)));
    end;
  finally
    Cursor.Free;
    Tree.Free;
  end;
end;

begin
  if ParamCount < 2 then
  begin
    Writeln('TsQuery <query.scm> <file or folder>...');
    Halt(2);
  end;
  var Parser := TTSParser.Create(tree_sitter_delphi13);
  var Query  : TTSQuery := nil;
  try
    try
      Query := TTSQuery.Create(tree_sitter_delphi13, TFile.ReadAllText(ParamStr(1), TEncoding.UTF8));
    except
      on E: ETSQuery do
      begin
        Writeln(E.Message);
        Halt(1);
      end;
    end;
    var Files := 0;
    var Watch := TStopwatch.StartNew;
    for var I := 2 to ParamCount do
      if TDirectory.Exists(ParamStr(I)) then
        for var F in TDirectory.GetFiles(ParamStr(I), '*.pas', TSearchOption.soAllDirectories) do
        begin
          QueryFile(Parser, Query, F);
          Inc(Files);
        end
      else
      begin
        QueryFile(Parser, Query, ParamStr(I));
        Inc(Files);
      end;
    Writeln(Files, ' files, ', Query.PatternCount, ' patterns, ', Captures, ' captures, ',
            Watch.ElapsedMilliseconds, ' ms');
  finally
    Query.Free;
    Parser.Free;
  end;
end.
