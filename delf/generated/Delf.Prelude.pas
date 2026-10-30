unit Delf.Prelude;

{ Runtime support for Delf's universal library, the prelude (prelude.py):
  what every Delf file has without naming it. Optional<T> has its own unit,
  Delf.Optional. delfc adds this one to a Delf file's uses clause when the
  output calls TFunctions, or when the file uses System.Types (so the TPoint
  helper is in scope wherever TPoint is).

  - Id (user, 23 Oct: "the generic should be called Id and be part of the
    universal library"). Like Optional's operations, a static generic
    function on a record, TFunctions: Delphi has no free generic functions.
    delfc writes TFunctions.Id<T>, with the type argument, when it is passed
    as a value (dcc32 doesn't infer it, experiment 18, P8). X is passed by
    value, not const: Id is passed where a TFunc<T, T> is expected, and dcc32
    doesn't take a routine with a const parameter there (🧪 dcc32 37.0,
    Claude, 23 Oct, a scratch probe: E2010).

  - TInitArray<T>.Create(Length, Fill): an array of Length copies of Fill
    (user, 23 Oct).

  - TPointDelta, a move rather than a place (user, 23 Oct): TPoint +
    TPointDelta is a TPoint, and Delta(dx, dy) makes one. The RTL has no
    delta type.

  - A helper for TPoint (user: "it is evil that the RTL offset is a
    procedure"): P.Delta(D) answers a new point instead of changing this
    one, and ToString answers '(x, y)'. Named Delta, not Offset (user,
    23 Oct; "or use the greek letter": Δ works too, 🧪 dcc32 and both
    grammars): a helper's method hides the record's own of the same name,
    all its overloads (🧪 a scratch probe: P.Offset(1, 2) was then E2010),
    and experiment 32 found SynEdit calling the RTL's Offset, which a Delphi
    file renamed to .delf would lose. The method sits beside the global
    Delta(dx, dy) (🧪). The RTL declares no helper for TPoint, so none is
    displaced. A program's own can be (SynEdit's SynFunc has one): a type
    has one helper in scope, the nearest, so delfc puts this unit first in
    uses, and the program's helper wins, with a delfc warning that this
    one is hidden there (user, 25 Oct; 🧪 a helper-order probe on dcc32 and
    dcc64: with this unit last, the program's TPoint.Create(Int64, Int64)
    silently became TPoint's own).

  - Arrays (30 Oct, from TreeSitter4D's walker; user: "we have found the sort
    of smooth look of the code we want"): Map, AndThen (bind: for each element
    an array, joined into one) and Filter, each taking a TFunc or a TConstFunc,
    so a routine with a const parameter (the RTL's Trim) passes as it is
    (user: overloads, not wrappers; Delf.Optional.pas, TConstFunc); Enumerate,
    each element with its index from 0, as a tuple; Join for strings; Args, the
    command line's arguments. Called through TFunctions: Lines.Map(Trim) is
    TFunctions.Map<string, string>(Lines, Trim).

  - Searching and summing an array (30 Oct; user: "proceed as you think on
    Arrays", after Willi Commer's ArrayHelper, docs/library.md): Find, the
    first element a test passes; IndexOf, where a value first is; Contains;
    Count, how many pass a test; Min and Max; Sum for Integer, Int64 and
    Double. Read-only, every one, and where ArrayHelper answers -1, these
    answer an Optional: Absent for not found, and for the Min or Max of an
    empty array. Equality and order are the RTL's defaults for T
    (TEqualityComparer<T>.Default, TComparer<T>.Default). }

interface

uses
  System.SysUtils, System.Types, System.Generics.Defaults, Delf.Optional, Delf.Tuples;

type
  TFunctions = record
    class function Id<T>(X: T): T; static;

    class function Map<T, U>(const Xs: TArray<T>; const F: TFunc<T, U>): TArray<U>; overload; static;
    class function Map<T, U>(const Xs: TArray<T>; const F: TConstFunc<T, U>): TArray<U>; overload; static;
    class function AndThen<T, U>(const Xs: TArray<T>; const F: TFunc<T, TArray<U>>): TArray<U>; overload; static;
    class function AndThen<T, U>(const Xs: TArray<T>; const F: TConstFunc<T, TArray<U>>): TArray<U>; overload; static;
    class function Filter<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): TArray<T>; overload; static;
    class function Filter<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): TArray<T>; overload; static;
    class function Enumerate<T>(const Xs: TArray<T>): TArray<TTuple<Integer, T>>; static;
    class function Join(const Xs: TArray<string>; const Sep: string): string; static;
    class function Args: TArray<string>; static;

    class function Find<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): Optional<T>; overload; static;
    class function Find<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): Optional<T>; overload; static;
    class function IndexOf<T>(const Xs: TArray<T>; const X: T): Optional<Integer>; static;
    class function Contains<T>(const Xs: TArray<T>; const X: T): Boolean; static;
    class function Count<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): Integer; overload; static;
    class function Count<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): Integer; overload; static;
    class function Min<T>(const Xs: TArray<T>): Optional<T>; static;
    class function Max<T>(const Xs: TArray<T>): Optional<T>; static;
    class function Sum(const Xs: TArray<Integer>): Integer; overload; static;
    class function Sum(const Xs: TArray<Int64>): Int64; overload; static;
    class function Sum(const Xs: TArray<Double>): Double; overload; static;
  end;

  // an array of Length elements, each Fill (user, 23 Oct). Not TArray<T>.Create:
  // that is Delphi's own constructor, whose arguments are the elements
  // (🧪 TArray<Integer>.Create(3, 0) is [3, 0])
  TInitArray<T> = record
    class function Create(Length: Integer; const Fill: T): TArray<T>; static;
  end;

  TPointDelta = record
    dx, dy : Integer;
    class operator Add(const P: TPoint; const D: TPointDelta): TPoint;
  end;

  TPointHelper = record helper for TPoint
    function Delta(const D: TPointDelta): TPoint;
    function ToString: string;
  end;

function Delta(dx, dy: Integer): TPointDelta;

implementation

class function TFunctions.Id<T>(X: T): T;
begin
  Exit( X );
end;

class function TFunctions.Map<T, U>(const Xs: TArray<T>; const F: TFunc<T, U>): TArray<U>;
begin
  SetLength(Result, Length(Xs));
  for var i := 0 to High(Xs) do Result[i] := F(Xs[i]);
end;

class function TFunctions.Map<T, U>(const Xs: TArray<T>; const F: TConstFunc<T, U>): TArray<U>;
begin
  SetLength(Result, Length(Xs));
  for var i := 0 to High(Xs) do Result[i] := F(Xs[i]);
end;

class function TFunctions.AndThen<T, U>(const Xs: TArray<T>; const F: TFunc<T, TArray<U>>): TArray<U>;
begin
  Result := [];
  for var X in Xs do Result := Result + F(X);
end;

class function TFunctions.AndThen<T, U>(const Xs: TArray<T>; const F: TConstFunc<T, TArray<U>>): TArray<U>;
begin
  Result := [];
  for var X in Xs do Result := Result + F(X);
end;

// the result is sized once and cut to what passed (30 Oct: it grew by one
// element at a time, a reallocation per element kept)
class function TFunctions.Filter<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): TArray<T>;
begin
  SetLength(Result, Length(Xs));
  var N := 0;
  for var X in Xs do
    if P(X) then
    begin
      Result[N] := X;
      Inc(N);
    end;
  SetLength(Result, N);
end;

class function TFunctions.Filter<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): TArray<T>;
begin
  SetLength(Result, Length(Xs));
  var N := 0;
  for var X in Xs do
    if P(X) then
    begin
      Result[N] := X;
      Inc(N);
    end;
  SetLength(Result, N);
end;

class function TFunctions.Enumerate<T>(const Xs: TArray<T>): TArray<TTuple<Integer, T>>;
begin
  SetLength(Result, Length(Xs));
  for var i := 0 to High(Xs) do Result[i] := TTuple<Integer, T>.Create(i, Xs[i]);
end;

class function TFunctions.Join(const Xs: TArray<string>; const Sep: string): string;
begin
  Exit( string.Join(Sep, Xs) );
end;

class function TFunctions.Args: TArray<string>;
begin
  SetLength(Result, ParamCount);
  for var i := 1 to ParamCount do Result[i - 1] := ParamStr(i);
end;

class function TFunctions.Find<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): Optional<T>;
begin
  for var X in Xs do
    if P(X) then Exit( Optional<T>.Present(X) );
  Exit( Optional<T>.Absent );
end;

class function TFunctions.Find<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): Optional<T>;
begin
  for var X in Xs do
    if P(X) then Exit( Optional<T>.Present(X) );
  Exit( Optional<T>.Absent );
end;

class function TFunctions.IndexOf<T>(const Xs: TArray<T>; const X: T): Optional<Integer>;
begin
  const Eq = TEqualityComparer<T>.Default;
  for var i := 0 to High(Xs) do
    if Eq.Equals(Xs[i], X) then Exit( Optional<Integer>.Present(i) );
  Exit( Optional<Integer>.Absent );
end;

class function TFunctions.Contains<T>(const Xs: TArray<T>; const X: T): Boolean;
begin
  Exit( IndexOf<T>(Xs, X).Kind = TOptionalKind.Present );
end;

class function TFunctions.Count<T>(const Xs: TArray<T>; const P: TFunc<T, Boolean>): Integer;
begin
  Result := 0;
  for var X in Xs do
    if P(X) then Inc(Result);
end;

class function TFunctions.Count<T>(const Xs: TArray<T>; const P: TConstFunc<T, Boolean>): Integer;
begin
  Result := 0;
  for var X in Xs do
    if P(X) then Inc(Result);
end;

class function TFunctions.Min<T>(const Xs: TArray<T>): Optional<T>;
begin
  if Length(Xs) = 0 then Exit( Optional<T>.Absent );
  const Cmp = TComparer<T>.Default;
  var M := Xs[0];
  for var i := 1 to High(Xs) do
    if Cmp.Compare(Xs[i], M) < 0 then M := Xs[i];
  Exit( Optional<T>.Present(M) );
end;

class function TFunctions.Max<T>(const Xs: TArray<T>): Optional<T>;
begin
  if Length(Xs) = 0 then Exit( Optional<T>.Absent );
  const Cmp = TComparer<T>.Default;
  var M := Xs[0];
  for var i := 1 to High(Xs) do
    if Cmp.Compare(Xs[i], M) > 0 then M := Xs[i];
  Exit( Optional<T>.Present(M) );
end;

class function TFunctions.Sum(const Xs: TArray<Integer>): Integer;
begin
  Result := 0;
  for var X in Xs do Inc(Result, X);
end;

class function TFunctions.Sum(const Xs: TArray<Int64>): Int64;
begin
  Result := 0;
  for var X in Xs do Inc(Result, X);
end;

class function TFunctions.Sum(const Xs: TArray<Double>): Double;
begin
  Result := 0;
  for var X in Xs do Result := Result + X;
end;

class function TInitArray<T>.Create(Length: Integer; const Fill: T): TArray<T>;
begin
  SetLength(Result, Length);
  for var i := 0 to Length - 1 do Result[i] := Fill;
end;

function Delta(dx, dy: Integer): TPointDelta;
begin
  Result.dx := dx;
  Result.dy := dy;
end;

class operator TPointDelta.Add(const P: TPoint; const D: TPointDelta): TPoint;
begin
  Exit( Point(P.X + D.dx, P.Y + D.dy) );
end;

function TPointHelper.Delta(const D: TPointDelta): TPoint;
begin
  Exit( Self + D );
end;

function TPointHelper.ToString: string;
begin
  Exit( Format('(%d, %d)', [X, Y]) );
end;

end.
