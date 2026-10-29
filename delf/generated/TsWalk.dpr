program TsWalk;

(* The walker of delphi\TsWalk.dpr, in Delf: parses Delphi files with
  tree-sitter, walks every node, and lists where the grammar groups a `<`
  wrongly: as the right operand of a tighter operator, A + (B < C), or of
  `not`, where Delphi reads (A + B) < C.

  TsWalk <file or folder>...   (a folder: its .pas files, recursively) *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IOUtils, System.Diagnostics, System.RegularExpressions,
  TreeSitter.Api, TreeSitter.Nodes, Delf.Optional;

{ The else of an exhaustive match (SPEC §9.3): unreachable from Delf code, which checks every
  value is covered. noreturn tells dcc32 so, and removes W1035 (experiment 20). }
procedure __dpp_Unreachable(const TypeName: string; Ordinal: Integer); noreturn;
begin
  // the ordinal, not the name: GetEnumName reads past its table for a
  // corrupt value (experiment 27)
  raise EInvalidOpException.CreateFmt('Delf: a match met %s ordinal %d, '
    + 'which it does not cover', [TypeName, Ordinal]);
end;


var
  Nodes   : Int64;
  Found   : Int64;
  Current : string;   // the file being walked, written before its first finding

function Op(const N: TSNode): string;
begin
  var __dpp_1 := Field(N, 'operator');
  case __dpp_1.Kind of
    TOptionalKind.Present :
      begin
        const O = __dpp_1.Value;
        Exit( Kind(O) );
      end;
    TOptionalKind.Absent  : Exit( '' );
  else
    __dpp_Unreachable('TOptionalKind', Ord(__dpp_1.Kind));
  end;
end;

// a node's text, on one line: a line break and the indent after it become a space
function TextOf(const P: TParsed; const N: Optional<TSNode>): string;
begin
  case N.Kind of
    TOptionalKind.Present :
      begin
        const X = N.Value;
        Exit( TRegEx.Replace(Text(P, X), '[\r\n]\s*', ' ') );
      end;
    TOptionalKind.Absent  : Exit( '' );
  else
    __dpp_Unreachable('TOptionalKind', Ord(N.Kind));
  end;
end;

// the adding and multiplying operators, which bind tighter than a comparison
function Tighter(const Op: string): Boolean;
begin
  if (Op = 'kAdd') or (Op = 'kSub') or (Op = 'kOr') or (Op = 'kXor') or (Op = 'kMul') or (Op = 'kFdiv') or (Op = 'kDiv') or (Op = 'kMod') or (Op = 'kAnd') or (Op = 'kShl') or (Op = 'kShr') then
    Exit( True )
  else
    Exit( False );
end;

procedure Check(const P: TParsed; const N: TSNode);
begin
  const Unary = Kind(N) = 'exprUnary';
  if not ( Tighter(Op(N)) or (Unary and (Op(N) = 'kNot')) ) then Exit;
  const Inner = Field(N, if Unary then 'operand' else 'rhs');
  case Inner.Kind of
    TOptionalKind.Present :
      begin
        const R = Inner.Value;
        if (Kind(R) = 'exprBinary') and (Op(R) = 'kLt') then
        begin
          Inc(Found);
          if Current <> '' then
          begin
            Writeln(Current);
            Current := '';
          end;
          const Head = if Unary then 'not' else TextOf(P, Field(N, 'lhs')) + ' ' + TextOf(P, Field(N, 'operator'));
          const B    = TextOf(P, Field(R, 'lhs'));
          const C    = TextOf(P, Field(R, 'rhs'));
          Writeln(Line(N):6, '  tree-sitter: ', Head, ' (', B, ' < ', C, ')',
                  '   Delphi: (', Head, ' ', B, ') < ', C);
        end;
      end;
    TOptionalKind.Absent  : ;
  else
    __dpp_Unreachable('TOptionalKind', Ord(Inner.Kind));
  end;
end;

procedure Walk(const P: TParsed; const N: TSNode);
begin
  Inc(Nodes);
  if (Kind(N) = 'exprBinary') or (Kind(N) = 'exprUnary') then Check(P, N);
  for var C {const} in Children(N) do Walk(P, C);
end;

procedure WalkFile(const FileName: string);
begin
  Current := FileName;
  const P = Parse(TFile.ReadAllText(FileName));
  Walk(P, Root(P));
  Release(P);
end;

function FilesOf(const Arg: string): TArray<string>;
begin
  if TDirectory.Exists(Arg) then
    Exit( TDirectory.GetFiles(Arg, '*.pas', TSearchOption.soAllDirectories) );
  Result := [Arg];
end;

begin
  var Files   := 0;
  const Watch = TStopwatch.StartNew;
  for var i := 1 to ParamCount do
    for var F {const} in FilesOf(ParamStr(i)) do
    begin
      WalkFile(F);
      Inc(Files);
    end;
  Writeln(Files, ' files, ', Nodes, ' nodes, ', Found, ' misgrouped <, ',
          Watch.ElapsedMilliseconds, ' ms');
end.
