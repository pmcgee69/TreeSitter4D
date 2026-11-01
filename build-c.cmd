@echo off
rem Compiles tree-sitter's runtime and the Delphi grammar with C++Builder,
rem into obj\: objects for Delphi's {$L} and for C++Builder's linker.
rem   build-c.cmd              Win64 objects (bcc64x, COFF): obj\*.o
rem   build-c.cmd dll          also obj\tree-sitter.dll and obj\tree-sitter-delphi13.dll
rem   build-c.cmd win32        Win32 objects (bcc32c, OMF): obj\win32\*.obj
rem   build-c.cmd win32 dll    also obj\win32\tree-sitter.dll and obj\win32\tree-sitter-delphi13.dll
rem Run from a RAD Studio command prompt (rsvars.bat), so the compilers are on the PATH.
setlocal
cd /d "%~dp0"
if not exist obj mkdir obj
set TS=c\tree-sitter
set GR=c\tree-sitter-delphi13\src
if /i "%~1"=="win32" goto win32

bcc64x -O2 -c -I %TS%\include -I %TS%\src %TS%\src\lib.c -o obj\ts_lib.o || exit /b 1
bcc64x -O2 -c -I %GR% %GR%\parser.c  -o obj\delphi13_parser.o  || exit /b 1
bcc64x -O2 -c -I %GR% %GR%\scanner.c -o obj\delphi13_scanner.o || exit /b 1

if /i not "%~1"=="dll" goto :eof
bcc64x -O2 -shared obj\ts_lib.o %TS%\exports.def -o obj\tree-sitter.dll || exit /b 1
bcc64x -O2 -shared obj\delphi13_parser.o obj\delphi13_scanner.o -o obj\tree-sitter-delphi13.dll || exit /b 1
goto :eof

:win32
rem the runtime through c\ts_lib_win32.c, which gives bcc32c the static inline
rem that bcc64x gets for stack.c's forceinline (the file says why)
if not exist obj\win32 mkdir obj\win32
bcc32c -O2 -c -I %TS%\include -I %TS%\src c\ts_lib_win32.c -o obj\win32\ts_lib.obj || exit /b 1
bcc32c -O2 -c -I %GR% %GR%\parser.c  -o obj\win32\delphi13_parser.obj  || exit /b 1
bcc32c -O2 -c -I %GR% %GR%\scanner.c -o obj\win32\delphi13_scanner.obj || exit /b 1

if /i not "%~2"=="dll" goto :eof
rem the .def files export each function under its plain name, as on Win64
pushd obj\win32
bcc32c -tD -etree-sitter.dll ts_lib.obj ..\..\%TS%\exports-win32.def || (popd & exit /b 1)
bcc32c -tD -etree-sitter-delphi13.dll delphi13_parser.obj delphi13_scanner.obj ..\..\c\tree-sitter-delphi13\exports-win32.def || (popd & exit /b 1)
popd
