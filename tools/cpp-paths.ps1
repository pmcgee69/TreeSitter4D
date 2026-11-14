# Writes an environment-options file for msbuild from the command line, for build-msbuild.cmd.
#
# msbuild reads the IDE's library paths from %APPDATA%\Embarcadero\BDS\<version>\EnvOptions.proj,
# which the IDE writes. That file can be without C++Builder's paths (seen on 14 Nov 2026: only
# Delphi's, for every platform), while the IDE still has them in the registry and builds fine.
# Then a C++ project fails from the command line with "'stdlib.h' file not found".
#
# The file written here imports EnvOptions.proj as it is, and adds C++Builder's Win64x include
# and library paths from the registry only where EnvOptions.proj left them empty. msbuild
# evaluates it as a project file, so the registry's $(BDSINCLUDE)-style macros expand as the
# IDE's do.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\cpp-paths.ps1 <output file>
param([Parameter(Mandatory = $true)][string]$Out)

$version = if ($env:PRODUCTVERSION) { $env:PRODUCTVERSION } else { '37.0' }
$key = "HKCU:\Software\Embarcadero\BDS\$version\C++\Paths\Win64x"
$envOptions = "$env:APPDATA\Embarcadero\BDS\$version\EnvOptions.proj"

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

$include = ''
$library = ''
if (Test-Path $key) {
    $paths = Get-ItemProperty $key
    $include = $paths.IncludePath
    $library = $paths.LibraryPath
} else {
    Write-Host "no C++Builder Win64x paths in the registry ($key): the IDE's own settings only"
}

$xml = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <!-- written by tools\cpp-paths.ps1 for build-msbuild.cmd: the IDE's EnvOptions.proj, and
       C++Builder's Win64x paths from the registry where it has none -->
  <Import Project="$(Esc $envOptions)" Condition="Exists('$(Esc $envOptions)')"/>
  <PropertyGroup Condition="'`$(Platform)'=='Win64x' and '`$(CBuilderIncludePath)'==''">
    <CBuilderIncludePath>$(Esc $include)</CBuilderIncludePath>
  </PropertyGroup>
  <PropertyGroup Condition="'`$(Platform)'=='Win64x' and '`$(CBuilderLibraryPath)'==''">
    <CBuilderLibraryPath>$(Esc $library)</CBuilderLibraryPath>
  </PropertyGroup>
</Project>
"@

New-Item -ItemType Directory -Force (Split-Path -Parent $Out) | Out-Null
Set-Content -Path $Out -Value $xml -Encoding UTF8
