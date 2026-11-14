@echo off
rem Builds TreeSitter4D.groupproj with msbuild, as the IDE's Build All does: the C objects
rem if they aren't there yet, then the two Delphi walkers and the two C++Builder ones.
rem   build-msbuild.cmd                 Release
rem   build-msbuild.cmd /p:Config=Debug and any other msbuild arguments
rem From a RAD Studio command prompt, or anywhere: rsvars.bat is called if BDS isn't set.
rem The IDE's EnvOptions.proj can be without C++Builder's paths, so a C++ project fails with
rem "'stdlib.h' file not found"; tools\cpp-paths.ps1 adds them from the registry (it says why).
setlocal
cd /d "%~dp0"
if not defined BDS call "%ProgramFiles(x86)%\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
if not exist obj mkdir obj
powershell -NoProfile -ExecutionPolicy Bypass -File tools\cpp-paths.ps1 "%CD%\obj\EnvOptions-cpp.proj" || exit /b 1
msbuild TreeSitter4D.groupproj /nologo /v:m "/p:EnvOptions=%CD%\obj\EnvOptions-cpp.proj" %*
