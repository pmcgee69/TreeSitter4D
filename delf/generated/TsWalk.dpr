program TsWalk;

(* The walker of delphi\TsWalk.dpr, in Delf: parses Delphi files with
  tree-sitter, walks every node, and lists where the grammar groups a `<`
  wrongly: as the right operand of a tighter operator, A + (B < C), or of
  `not`, where Delphi reads (A + B) < C.

  TsWalk <file or folder>...   (a folder: its .pas files, recursively) *)

{$APPTYPE CONSOLE}

uses Delf.Prelude,
  System.SysUtils, System.IOUtils, System.Diagnostics,
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
  Exit( TOptional.OrDefault<string>(TOptional.Map<TSNode, string>(Field(N, 'operator'), Kind), '') );
end;

// a node's text, on one line: each line trimmed, joined with a space
function OneLine(const S: string): string;
begin
  Exit( TFunctions.Join(TFunctions.Map<string, string>(S.Split([#13#10, #10]), Trim), ' ') );
end;

function ToString(const P: TParsed; const N: Optional<TSNode>): string;
begin
  Exit( TOptional.OrDefault<string>(TOptional.Map<TSNode, string>(N, function(X: TSNode): string begin Result := OneLine(Text(P, X)); end), '') );
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
          const Head = if Unary then 'not' else ToString(P, Field(N, 'lhs')) + ' ' + ToString(P, Field(N, 'operator'));
          const B    = ToString(P, Field(R, 'lhs'));
          const C    = ToString(P, Field(R, 'rhs'));
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

// walks one file, if there is one: an argument that is neither a folder nor a
// file is skipped, and not counted
function WalkFile(const Fn: string): Boolean;
begin
  if not TFile.Exists(Fn) then Exit( False );
  Current := Fn;
  const P = Parse(TFile.ReadAllText(Fn));
  Walk(P, Root(P));
  Release(P);
  Exit( True );
end;

function ToFiles(const Arg: string): TArray<string>;
begin
  if TDirectory.Exists(Arg) then
    Exit( TDirectory.GetFiles(Arg, '*.pas', TSearchOption.soAllDirectories) );
  Result := [Arg];
end;

(* The main loop, earlier versions. *)

(* 1. As first written, in plain Delphi's style:

    procedure WalkFile(const FileName: string);
    …
    var Files := 0;
    for var i := 1 to ParamCount do
      for const F in ToFiles(ParamStr(i)) do
      begin
        WalkFile(F);
        Inc(Files);
      end;
*)

(* 2. The library's Args and AndThen, the count from the array:

    procedure WalkFile(const FileName: string);
    …
    const Files := Args.AndThen(ToFiles);
    for const F in Files do WalkFile(F);
    Writeln(Length(Files), ' files, ', …
*)

(* 3. A fold, WalkFile taking the count in and giving one more out:

    function WalkFile(const Count: Integer; const Fn: string): Integer;
    …
    var Count := 0;
    for const Fn in Args.AndThen(ToFiles) do Count := WalkFile(Count, Fn);
*)

(* 4. WalkFile saying whether it walked, the loop counting:

    function WalkFile(const Fn: string): Boolean;
    …
    var Count := 0;
    for const Fn in Args.AndThen(ToFiles) do if WalkFile(Fn) then Inc(Count);
*)

begin
  const Watch = TStopwatch.StartNew;
  const Count = Length(TFunctions.Filter<string>(TFunctions.AndThen<string, string>(TFunctions.Args, ToFiles), WalkFile));
  Writeln(Count, ' files, ', Nodes, ' nodes, ', Found, ' misgrouped <, ',
          Watch.ElapsedMilliseconds, ' ms');
end.
