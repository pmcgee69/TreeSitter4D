@echo off
rem Compiles tree-sitter's runtime and the Delphi grammar with C++Builder's bcc64x,
rem into obj\: COFF objects for Delphi's {$L} and for C++Builder's linker.
rem   build-c.cmd          the objects
rem   build-c.cmd dll      also tree-sitter.dll and tree-sitter-delphi13.dll
rem Run from a RAD Studio command prompt (rsvars.bat), so bcc64x is on the PATH.
setlocal
cd /d "%~dp0"
if not exist obj mkdir obj
set TS=c\tree-sitter
set GR=c\tree-sitter-delphi13\src

bcc64x -O2 -c -I %TS%\include -I %TS%\src %TS%\src\lib.c -o obj\ts_lib.o || exit /b 1
bcc64x -O2 -c -I %GR% %GR%\parser.c  -o obj\delphi13_parser.o  || exit /b 1
bcc64x -O2 -c -I %GR% %GR%\scanner.c -o obj\delphi13_scanner.o || exit /b 1

if /i not "%~1"=="dll" goto :eof
bcc64x -O2 -shared obj\ts_lib.o %TS%\exports.def -o obj\tree-sitter.dll || exit /b 1
bcc64x -O2 -shared obj\delphi13_parser.o obj\delphi13_scanner.o -o obj\tree-sitter-delphi13.dll || exit /b 1
