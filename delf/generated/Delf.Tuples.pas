unit Delf.Tuples;

{ Runtime support for Delf tuples (poc/README.md).

  A Delf tuple type (A, B) is emitted as TTuple<A, B>. Delf source never names
  these records: it writes (A, B), (X, Y) and P[0]; the transpiler writes
  TTuple<A, B>.Create(X, Y) and P.Item0.

  Item0, Item1, ... are numbered from 0 to match Delf's P[0], P[1].
  Equality is structural, element by element, through the default equality
  comparer (so it works for any element type, records and strings included).

  Status: written for the POC. Both predictions confirmed by experiment 18
  (Claude, dcc32 and dcc64 37.0, 17 Oct):
    P1  generic records overloaded by arity (TTuple<T0, T1> beside
        TTuple<T0, T1, T2>) compile in one unit, as TFunc<...> does for
        reference types;
    P2  Tuple.Make(1, 'a') infers T0 = Integer, T1 = string. }

interface

uses
  System.Generics.Defaults;

type
  TTuple<T0, T1> = record
    Item0: T0;
    Item1: T1;
    constructor Create(const A0: T0; const A1: T1);
    class operator Equal(const L, R: TTuple<T0, T1>): Boolean;
    class operator NotEqual(const L, R: TTuple<T0, T1>): Boolean;
  end;

  TTuple<T0, T1, T2> = record
    Item0: T0;
    Item1: T1;
    Item2: T2;
    constructor Create(const A0: T0; const A1: T1; const A2: T2);
    class operator Equal(const L, R: TTuple<T0, T1, T2>): Boolean;
    class operator NotEqual(const L, R: TTuple<T0, T1, T2>): Boolean;
  end;

  TTuple<T0, T1, T2, T3> = record
    Item0: T0;
    Item1: T1;
    Item2: T2;
    Item3: T3;
    constructor Create(const A0: T0; const A1: T1; const A2: T2; const A3: T3);
    class operator Equal(const L, R: TTuple<T0, T1, T2, T3>): Boolean;
    class operator NotEqual(const L, R: TTuple<T0, T1, T2, T3>): Boolean;
  end;

  { Used only where the transpiler cannot see the element types and leaves
    them to dcc32's inference: Tuple.Make(X, Y). }
  Tuple = record
    class function Make<T0, T1>(const A0: T0; const A1: T1): TTuple<T0, T1>;
      overload; static; inline;
    class function Make<T0, T1, T2>(const A0: T0; const A1: T1; const A2: T2): TTuple<T0, T1, T2>;
      overload; static; inline;
    class function Make<T0, T1, T2, T3>(const A0: T0; const A1: T1; const A2: T2; const A3: T3): TTuple<T0, T1, T2, T3>;
      overload; static; inline;
  end;

implementation

{ TTuple<T0, T1> }

constructor TTuple<T0, T1>.Create(const A0: T0; const A1: T1);
begin
  Item0 := A0;
  Item1 := A1;
end;

class operator TTuple<T0, T1>.Equal(const L, R: TTuple<T0, T1>): Boolean;
begin
  Result := TEqualityComparer<T0>.Default.Equals(L.Item0, R.Item0)
        and TEqualityComparer<T1>.Default.Equals(L.Item1, R.Item1);
end;

class operator TTuple<T0, T1>.NotEqual(const L, R: TTuple<T0, T1>): Boolean;
begin
  Result := not (L = R);
end;

{ TTuple<T0, T1, T2> }

constructor TTuple<T0, T1, T2>.Create(const A0: T0; const A1: T1; const A2: T2);
begin
  Item0 := A0;
  Item1 := A1;
  Item2 := A2;
end;

class operator TTuple<T0, T1, T2>.Equal(const L, R: TTuple<T0, T1, T2>): Boolean;
begin
  Result := TEqualityComparer<T0>.Default.Equals(L.Item0, R.Item0)
        and TEqualityComparer<T1>.Default.Equals(L.Item1, R.Item1)
        and TEqualityComparer<T2>.Default.Equals(L.Item2, R.Item2);
end;

class operator TTuple<T0, T1, T2>.NotEqual(const L, R: TTuple<T0, T1, T2>): Boolean;
begin
  Result := not (L = R);
end;

{ TTuple<T0, T1, T2, T3> }

constructor TTuple<T0, T1, T2, T3>.Create(const A0: T0; const A1: T1; const A2: T2; const A3: T3);
begin
  Item0 := A0;
  Item1 := A1;
  Item2 := A2;
  Item3 := A3;
end;

class operator TTuple<T0, T1, T2, T3>.Equal(const L, R: TTuple<T0, T1, T2, T3>): Boolean;
begin
  Result := TEqualityComparer<T0>.Default.Equals(L.Item0, R.Item0)
        and TEqualityComparer<T1>.Default.Equals(L.Item1, R.Item1)
        and TEqualityComparer<T2>.Default.Equals(L.Item2, R.Item2)
        and TEqualityComparer<T3>.Default.Equals(L.Item3, R.Item3);
end;

class operator TTuple<T0, T1, T2, T3>.NotEqual(const L, R: TTuple<T0, T1, T2, T3>): Boolean;
begin
  Result := not (L = R);
end;

{ Tuple }

class function Tuple.Make<T0, T1>(const A0: T0; const A1: T1): TTuple<T0, T1>;
begin
  Result := TTuple<T0, T1>.Create(A0, A1);
end;

class function Tuple.Make<T0, T1, T2>(const A0: T0; const A1: T1; const A2: T2): TTuple<T0, T1, T2>;
begin
  Result := TTuple<T0, T1, T2>.Create(A0, A1, A2);
end;

class function Tuple.Make<T0, T1, T2, T3>(const A0: T0; const A1: T1; const A2: T2; const A3: T3): TTuple<T0, T1, T2, T3>;
begin
  Result := TTuple<T0, T1, T2, T3>.Create(A0, A1, A2, A3);
end;

end.
