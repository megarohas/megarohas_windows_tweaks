# Builds DisplayHotkeys.exe with the C# compiler that ships with .NET Framework 4.
$ErrorActionPreference = 'Stop'
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$src = Join-Path $PSScriptRoot 'DisplayHotkeys.cs'
$out = Join-Path $PSScriptRoot 'DisplayHotkeys.exe'
& $csc /nologo /target:winexe /optimize+ /codepage:65001 "/out:$out" $src
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $out"
