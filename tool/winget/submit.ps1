#Requires -Version 7
<#
.SYNOPSIS
    Writes, checks and - with -Submit - submits the WinGet manifests for one
    published MarkLens release (docs/11_PACKAGING_UPDATE.md, "WinGet").

.DESCRIPTION
    Local on purpose. A pull request on microsoft/winget-pkgs has to come from a
    fork, which takes a classic token on the maintainer's account, and doc 14
    keeps long-lived secrets out of CI - so this runs here, after a person has
    published the release.

    Without -Submit nothing is written outside build/winget/ and build/komac/.

.PARAMETER Version
    x.y.z of a published release that is not a prerelease.

.PARAMETER ManifestDir
    Check - and with -Submit, submit - hand-written manifests instead of
    generating them. The first submission needs it: `komac update` starts from
    a package that already exists in winget-pkgs.

.PARAMETER Submit
    Open the pull request. Without it this is a dry run.

.EXAMPLE
    pwsh tool/winget/submit.ps1 -Version 1.0.2
    pwsh tool/winget/submit.ps1 -Version 1.0.2 -Submit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,

    [string] $ManifestDir,

    [switch] $Submit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# What doc 11 records. test/repo/winget_test.dart holds each to its source.
$PackageIdentifier = 'poli0981.MarkLens'
$Publisher = 'poli0981'
$PackageName = 'MarkLens'
$ProductCode = '{D40DDB92-8D60-4FA4-8D52-4C526834C355}_is1'
$License = 'GPL-3.0-only'
$Dependency = 'Microsoft.VCRedist.2015+.x64'
$Repo = 'poli0981/MarkLens'

# Komac is handed a GitHub token, so it is pinned by digest and the digest is
# checked on every run - a cached copy included, because build/ is writable by
# anything that runs here.
$KomacVersion = '2.16.0'
$KomacSha256 = 'bdc45baf028f750da7519cc8a5f2eab5dfef46dfe88650eeb0d0a9bf51446e4f'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$work = Join-Path $root "build/winget/$Version"
$tag = "v$Version"
$asset = "MarkLens-Setup-$Version.exe"
$url = "https://github.com/$Repo/releases/download/$tag/$asset"

function Assert-Exit([string] $What) {
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)." }
}

foreach ($tool in 'gh', 'winget') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is not on PATH."
    }
}

# 1. Published, not a draft, not a prerelease. A draft's assets are a 404 to
#    everybody else, and UpdateService ignores prereleases - so does this.
$release = gh release view $tag --repo $Repo --json isDraft,isPrerelease | ConvertFrom-Json
Assert-Exit "gh release view $tag"
if ($release.isDraft) { throw "$tag is still a draft. Publish it first." }
if ($release.isPrerelease) { throw "$tag is a prerelease; WinGet gets stable releases only." }
$immutable = gh api "repos/$Repo/releases/tags/$tag" --jq '.immutable'
Assert-Exit "gh api releases/tags/$tag"
if ($immutable -ne 'true') {
    Write-Warning "$tag is not an immutable release. WinGet pins the installer's hash: never replace $asset."
}

# 2. The bytes WinGet will pin are the bytes release.yml hashed.
$download = Join-Path $work 'download'
Remove-Item $download, (Join-Path $work 'out') -Recurse -Force -ErrorAction Ignore
New-Item -ItemType Directory -Force $download | Out-Null
gh release download $tag --repo $Repo --dir $download --pattern SHA256SUMS --pattern $asset
Assert-Exit 'gh release download'
$line = Select-String -Path (Join-Path $download 'SHA256SUMS') `
    -Pattern "^([0-9a-f]{64})\s+\*?$([regex]::Escape($asset))$"
if (-not $line) { throw "SHA256SUMS has no line for $asset." }
$sha256 = $line.Matches[0].Groups[1].Value.ToUpperInvariant()
$actual = (Get-FileHash -Algorithm SHA256 (Join-Path $download $asset)).Hash
if ($actual -ne $sha256) { throw "$asset hashes to $actual; SHA256SUMS says $sha256." }

# 3. Nothing already in flight. Komac checks for an open pull request only when
#    it submits by itself, which is never here: generating is a dry run, and
#    `komac submit` does not check at all.
$open = gh pr list --repo microsoft/winget-pkgs --state open `
    --search "$PackageIdentifier $Version in:title" --json url --jq '.[].url'
Assert-Exit 'gh pr list'
gh api "repos/microsoft/winget-pkgs/contents/manifests/p/poli0981/MarkLens/$Version" --silent 2>$null
$merged = $LASTEXITCODE -eq 0
if ($open -or $merged) {
    $what = if ($open) { "an open pull request ($open)" } else { 'a merged manifest' }
    if ($Submit) { throw "winget-pkgs already has $what for $Version." }
    Write-Warning "winget-pkgs already has $what for $Version. Dry run only."
}

# 4. Komac, verified before every use.
$komac = Join-Path $root "build/komac/komac-$KomacVersion-x86_64-pc-windows-msvc.exe"
if (-not (Test-Path $komac)) {
    New-Item -ItemType Directory -Force (Split-Path $komac) | Out-Null
    Invoke-WebRequest -OutFile $komac `
        "https://github.com/russellbanks/Komac/releases/download/v$KomacVersion/$(Split-Path $komac -Leaf)"
}
$komacHash = (Get-FileHash -Algorithm SHA256 $komac).Hash.ToLowerInvariant()
if ($komacHash -ne $KomacSha256) {
    Remove-Item $komac
    throw ("komac: sha256 mismatch`n  expected $KomacSha256`n  got      $komacHash`n" +
        'Do not just update the constant - find out which one moved.')
}

$savedToken = $env:GITHUB_TOKEN
try {
    # Komac reads GITHUB_TOKEN. It lives in this process and its children for
    # the length of the run: never a parameter, never printed, never stored.
    $env:GITHUB_TOKEN = gh auth token
    if ($LASTEXITCODE -ne 0 -or -not $env:GITHUB_TOKEN) { throw 'Run `gh auth login` first.' }

    if ($ManifestDir) {
        $dir = (Resolve-Path $ManifestDir).Path
    } else {
        $out = Join-Path $work 'out'
        & $komac update $PackageIdentifier --version $Version --urls $url --dry-run --output $out
        Assert-Exit 'komac update'
        $found = @(Get-ChildItem $out -Recurse -Filter "$PackageIdentifier.installer.yaml")
        if ($found.Count -ne 1) { throw "komac wrote $($found.Count) installer manifests under $out." }
        $dir = $found[0].DirectoryName
        # Komac copies GitHub's licence detection - `GPL-3.0`, deprecated and
        # silent about "only" - and a link to HEAD. Doc 11 says why both are
        # put back.
        $path = Join-Path $dir "$PackageIdentifier.locale.en-US.yaml"
        (Get-Content $path -Raw) `
            -replace '(?m)^License:[^\r\n]*', "License: $License" `
            -replace '(?m)^LicenseUrl:[^\r\n]*', "LicenseUrl: https://github.com/$Repo/blob/$tag/LICENSE" |
            Set-Content $path -NoNewline
    }

    # 5. Doc 11's invariants, checked in the files that will be submitted - by
    #    field, not by layout: Komac writes CRLF and orders keys its own way.
    function Read-Manifest([string] $Suffix) {
        $file = Join-Path $dir "$PackageIdentifier$Suffix.yaml"
        if (-not (Test-Path $file)) { throw "$file is missing." }
        Get-Content $file -Raw
    }
    $installer = Read-Manifest '.installer'
    $default = Read-Manifest '.locale.en-US'
    $files = @(Get-ChildItem $dir -Filter '*.yaml')
    $checks = [ordered]@{
        'five files: version, installer, en-US, vi-VN, ja-JP' = $files.Count -eq 5
        "one installer, at $url" =
            ([regex]::Matches($installer, 'InstallerUrl:')).Count -eq 1 -and
            $installer.Contains("InstallerUrl: $url")
        "InstallerSha256 is SHA256SUMS's $sha256" = $installer -match "InstallerSha256:\s*$sha256"
        "ProductCode is $ProductCode" = $installer.Contains("ProductCode: '$ProductCode'")
        'per-user, and nothing that makes it machine-wide' =
            ($installer -match 'Scope:\s*user') -and
            ($installer -notmatch 'Scope:\s*machine|/ALLUSERS|ElevationRequirement')
        'inno, upgraded by installing over' =
            ($installer -match 'InstallerType:\s*inno') -and
            ($installer -match 'UpgradeBehavior:\s*install')
        "depends on $Dependency" = $installer.Contains("PackageIdentifier: $Dependency")
        "Publisher $Publisher, PackageName $PackageName" =
            ($default -cmatch "(?m)^Publisher: $Publisher\s*$") -and
            ($default -cmatch "(?m)^PackageName: $PackageName\s*$")
        "License is $License" = $default -cmatch "(?m)^License: $([regex]::Escape($License))\s*$"
    }
    foreach ($file in $files) {
        $checks["$($file.Name) is version $Version"] =
            (Get-Content $file -Raw) -match "(?m)^PackageVersion:\s*'?$([regex]::Escape($Version))'?\s*$"
    }
    # The taglines are copies of what the app ships, so they are checked the way
    # doc 11's "Product strings" checks the .desktop file's.
    foreach ($pair in @('en-US', 'en'), @('vi-VN', 'vi'), @('ja-JP', 'ja')) {
        $arb = Join-Path $root "lib/l10n/app_$($pair[1]).arb"
        $tagline = (Get-Content $arb -Raw -Encoding utf8 | ConvertFrom-Json).aboutTagline
        $checks["ShortDescription ($($pair[0])) is aboutTagline"] =
            (Read-Manifest ".locale.$($pair[0])") -cmatch
                "(?m)^ShortDescription: '?$([regex]::Escape($tagline))'?\s*$"
    }
    $checks.GetEnumerator() | ForEach-Object {
        Write-Host ('  {0}  {1}' -f $(if ($_.Value) { 'ok  ' } else { 'FAIL' }), $_.Key)
    }
    $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
    if ($failed) { throw "$dir breaks doc 11 on $($failed.Count) check(s) above." }

    winget validate --manifest $dir
    switch ($LASTEXITCODE) {
        0 { }
        -1978335192 {
            # 0x8A150028: valid, with warnings.
            if ($Submit) { throw 'winget validate reported warnings. Read them before submitting.' }
            Write-Warning 'winget validate reported warnings.'
        }
        default { throw "winget validate failed (exit $LASTEXITCODE)." }
    }

    # 6. The one step that writes anywhere but build/.
    if ($Submit) {
        & $komac submit $dir --yes
        Assert-Exit 'komac submit'
    } else {
        Write-Host "`nDry run. Read $dir, then run again with -Submit."
    }
} finally {
    if ($null -eq $savedToken) {
        Remove-Item Env:GITHUB_TOKEN -ErrorAction Ignore
    } else {
        $env:GITHUB_TOKEN = $savedToken
    }
}
