# Build NeSpat.exe ("Stay Awake") with the C# compiler bundled with Windows
# (.NET Framework 4.x) - no SDK or Visual Studio required. Run from this folder.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /codepage:65001 /target:winexe /out:NeSpat.exe `
  /win32icon:StayAwake.ico /win32manifest:app.manifest `
  /resource:StayAwake.ico,appicon `
  StayAwake.cs AssemblyInfo.cs
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }
Get-Item NeSpat.exe | Select-Object Name, Length, LastWriteTime
