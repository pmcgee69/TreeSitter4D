@echo off
rem Builds the Delf walker from delf\generated, the Delphi that delfc made from
rem delf\*.delf (delfc itself isn't needed), into obj\delf\TsWalk.exe.
rem After build-c.cmd.
setlocal
cd /d "%~dp0"
if not exist obj\delf mkdir obj\delf
if not exist obj\dcu-delf mkdir obj\dcu-delf

pushd delf\generated
dcc64 -Q -B -E..\..\obj\delf -NU..\..\obj\dcu-delf "-NSSystem;Winapi" -U..\..\delphi TsWalk.dpr || (popd & exit /b 1)
popd
