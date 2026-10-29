unit Delf.Optional;

{ Runtime support for Delf's Optional<T> (SPEC §5, §9.4; poc/README.md).

  Optional<T> is the built-in two-arm sum

    type Optional<T> =
      | Absent
      | Present(Value: T);

  written here by hand in exactly the shape delfc generates for any sum type
  (SPEC §9.1): a tag, a private field, static constructors, and a Value
  property whose getter checks the tag. Delf code never reads Value: it uses
  match, or the operations below.

  The operations are static generic functions on TOptional, not methods of
  Optional<T>: a generic record's method can't introduce its own type
  parameter and return the same record at a different instantiation
  (experiment 5d, E2086). delfc turns Opt.Map(F) into TOptional.Map<T, U>(Opt, F),
  with the type arguments written out, because dcc32 doesn't infer them through
  an anonymous method (experiment 18, P8).

  Names (user, 20 Oct): Present and Absent; AndThen for bind, not FlatMap;
  OrDefault, as in Spring4D's GetValueOrDefault, with the lazy form an overload
  taking a function. Optional<Optional<T>> keeps both layers: AndThen and
  Flatten join them, Map doesn't (SPEC §12).

  Representation: a flag plus a value, for every T (SPEC §5: correctness before
  size). The bare-pointer form for a class T is a later optimisation. }

interface

uses
  System.SysUtils;

type
{$SCOPEDENUMS ON}
  TOptionalKind = (Absent, Present);
{$SCOPEDENUMS OFF}

  Optional<T> = record
  strict private
    FKind         : TOptionalKind;
    FPresentValue : T;
    function GetValue: T;
  public
    class function Absent: Optional<T>; static; inline;
    class function Present(const AValue: T): Optional<T>; static; inline;
    property Kind  : TOptionalKind read FKind;
    property Value : T             read GetValue;
  end;

  // A function whose parameter is const, as the RTL's routines and Delf's own
  // mostly are (Trim, Kind(const N: TSNode)). Delphi matches const exactly when a
  // routine is passed as a value, both ways (E2010; the user's _QC/12.3 probe), so
  // each operation taking a function comes twice, TFunc and TConstFunc, and
  // Delphi picks by the routine passed (30 Oct, user: overloads, not wrappers)
  TConstFunc<T, TResult> = reference to function(const Arg: T): TResult;

  TOptional = record
    class function Map<T, U>(const O: Optional<T>; const F: TFunc<T, U>): Optional<U>; overload; static;
    class function Map<T, U>(const O: Optional<T>; const F: TConstFunc<T, U>): Optional<U>; overload; static;
    class function AndThen<T, U>(const O: Optional<T>; const F: TFunc<T, Optional<U>>): Optional<U>; overload; static;
    class function AndThen<T, U>(const O: Optional<T>; const F: TConstFunc<T, Optional<U>>): Optional<U>; overload; static;
    class function Filter<T>(const O: Optional<T>; const P: TFunc<T, Boolean>): Optional<T>; overload; static;
    class function Filter<T>(const O: Optional<T>; const P: TConstFunc<T, Boolean>): Optional<T>; overload; static;
    class function Flatten<T>(const O: Optional<Optional<T>>): Optional<T>; static;
    class function OrDefault<T>(const O: Optional<T>; const D: T): T; overload; static;
    class function OrDefault<T>(const O: Optional<T>; const F: TFunc<T>): T; overload; static;
  end;

implementation

{ Optional<T> }

class function Optional<T>.Absent: Optional<T>;
begin
  Result := Default(Optional<T>);
  Result.FKind := TOptionalKind.Absent;
end;

class function Optional<T>.Present(const AValue: T): Optional<T>;
begin
  Result := Default(Optional<T>);
  Result.FKind         := TOptionalKind.Present;
  Result.FPresentValue := AValue;
end;

function Optional<T>.GetValue: T;
begin
  if FKind <> TOptionalKind.Present then
    raise EInvalidOpException.Create('Optional.Value read on Absent');
  Exit( FPresentValue );
end;

{ TOptional }

class function TOptional.Map<T, U>(const O: Optional<T>; const F: TFunc<T, U>): Optional<U>;
begin
  if O.Kind = TOptionalKind.Present then Exit( Optional<U>.Present(F(O.Value)) );
  Exit( Optional<U>.Absent );
end;

class function TOptional.AndThen<T, U>(const O: Optional<T>; const F: TFunc<T, Optional<U>>): Optional<U>;
begin
  if O.Kind = TOptionalKind.Present then Exit( F(O.Value) );
  Exit( Optional<U>.Absent );
end;

class function TOptional.Filter<T>(const O: Optional<T>; const P: TFunc<T, Boolean>): Optional<T>;
begin
  if (O.Kind = TOptionalKind.Present) and P(O.Value) then Exit( O );
  Exit( Optional<T>.Absent );
end;

class function TOptional.Map<T, U>(const O: Optional<T>; const F: TConstFunc<T, U>): Optional<U>;
begin
  if O.Kind = TOptionalKind.Present then Exit( Optional<U>.Present(F(O.Value)) );
  Exit( Optional<U>.Absent );
end;

class function TOptional.AndThen<T, U>(const O: Optional<T>; const F: TConstFunc<T, Optional<U>>): Optional<U>;
begin
  if O.Kind = TOptionalKind.Present then Exit( F(O.Value) );
  Exit( Optional<U>.Absent );
end;

class function TOptional.Filter<T>(const O: Optional<T>; const P: TConstFunc<T, Boolean>): Optional<T>;
begin
  if (O.Kind = TOptionalKind.Present) and P(O.Value) then Exit( O );
  Exit( Optional<T>.Absent );
end;

class function TOptional.Flatten<T>(const O: Optional<Optional<T>>): Optional<T>;
begin
  if O.Kind = TOptionalKind.Present then Exit( O.Value );
  Exit( Optional<T>.Absent );
end;

class function TOptional.OrDefault<T>(const O: Optional<T>; const D: T): T;
begin
  if O.Kind = TOptionalKind.Present then Exit( O.Value );
  Exit( D );
end;

class function TOptional.OrDefault<T>(const O: Optional<T>; const F: TFunc<T>): T;
begin
  if O.Kind = TOptionalKind.Present then Exit( O.Value );
  Exit( F() );
end;

end.
