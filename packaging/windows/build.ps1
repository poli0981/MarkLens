#Requires -Version 7
<#
.SYNOPSIS
    Builds the two Windows release artefacts: the installer and the portable zip.

.DESCRIPTION
    One script so that CI and the dev machine run the same steps. Everything it
    produces lands in build\installer\ (gitignored, like the rest of build\):

        MarkLens-Setup-<version>.exe
        MarkLens-<version>-win-x64-portable.zip

    The version is read from pubspec.yaml rather than passed in. That file is
    the single source of truth (doc 11), lib/app/version.dart mirrors it under
    test, and the release workflow checks the git tag against both - a version
    typed on this command line would be a fourth copy with no guard.

    iscc is preinstalled on the windows-2025 runner and installs per-user on a
    dev box with `winget install JRSoftware.InnoSetup`. If it is missing the
    script still builds the portable zip, and warns loudly rather than skipping
    quietly - a release that silently produced one artefact where two were
    expected is the failure worth avoiding.

.PARAMETER SkipFlutterBuild
    Reuse whatever is already in build\windows\x64\runner\Release. For iterating
    on the .iss without paying for a release build each time.

.EXAMPLE
    pwsh packaging/windows/build.ps1
#>
[CmdletBinding()]
param(
    [switch] $SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$outputDir = Join-Path $repoRoot 'build\installer'

function Get-PubspecVersion {
    # The `+build` suffix is metadata for pub and means nothing to an installer.
    # Same regex shape as test/app/version_test.dart, deliberately.
    $pubspec = Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw
    if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
        throw 'pubspec.yaml has no `version: x.y.z` line.'
    }
    return $Matches[1]
}

function Find-Iscc {
    $onPath = Get-Command iscc -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    # %LOCALAPPDATA% first: `winget install JRSoftware.InnoSetup` installs
    # per-user by default and never touches PATH, so the machine-wide paths
    # below are the *less* likely ones on a developer's box. The runner image
    # has it under Program Files (x86).
    foreach ($candidate in @(
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles}\Inno Setup 6\ISCC.exe")) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$version = Get-PubspecVersion
Write-Host "MarkLens $version"

if (-not $SkipFlutterBuild) {
    Write-Host '==> flutter build windows --release'
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
}

if (-not (Test-Path (Join-Path $releaseDir 'marklens.exe'))) {
    throw "No build at $releaseDir. Drop -SkipFlutterBuild."
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# ── Portable zip ─────────────────────────────────────────────────────────────
# The same bundle the installer lays down, minus the registration. Config still
# goes to %APPDATA% (doc 05), so a portable copy and an installed one share a
# session rather than fighting over one - which is the honest behaviour for an
# app whose only state is two small files.
$zipPath = Join-Path $outputDir "MarkLens-$version-win-x64-portable.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host "==> $([System.IO.Path]::GetFileName($zipPath))"
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

# ── Installer ────────────────────────────────────────────────────────────────
$iscc = Find-Iscc
if (-not $iscc) {
    Write-Warning @'
Inno Setup (iscc) was not found, so only the portable zip was built.

It ships with the windows-2025 runner image, so CI builds both. To build the
installer here, install Inno Setup 6 or run this on the release workflow.
'@
    Write-Host "`nArtefacts in $outputDir"
    Get-ChildItem $outputDir | ForEach-Object { '  {0,12:N0}  {1}' -f $_.Length, $_.Name }
    exit 0
}

Write-Host "==> $iscc"
& $iscc "/DAppVersion=$version" (Join-Path $PSScriptRoot 'marklens.iss')
if ($LASTEXITCODE -ne 0) { throw "iscc failed ($LASTEXITCODE)" }

Write-Host "`nArtefacts in $outputDir"
Get-ChildItem $outputDir | ForEach-Object { '  {0,12:N0}  {1}' -f $_.Length, $_.Name }
