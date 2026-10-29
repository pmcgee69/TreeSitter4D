@echo off
rem Builds the two walkers into obj\, after build-c.cmd:
rem   obj\TsWalk.exe      Delphi (dcc64), the C linked in with $L
rem   obj\tswalk_cpp.exe  C++Builder (bcc64x), the same objects linked in
setlocal
cd /d "%~dp0"
if not exist obj\dcu mkdir obj\dcu

pushd delphi
dcc64 -Q -B -E..\obj -NU..\obj\dcu "-NSSystem;Winapi" TsWalk.dpr || (popd & exit /b 1)
popd

bcc64x -O2 -std=c++17 -I c\tree-sitter\include cpp\tswalk.cpp ^
  obj\ts_lib.o obj\delphi13_parser.o obj\delphi13_scanner.o -o obj\tswalk_cpp.exe || exit /b 1
