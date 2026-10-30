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
$ManifestVersion = '1.28.0'
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
$packagePath = "manifests/$($PackageIdentifier.Substring(0, 1).ToLowerInvariant())/$($PackageIdentifier.Replace('.', '/'))"

function Assert-Exit([string] $What) {
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)." }
}

# Komac writes manifest version 1.12.0, and the 1.12.0 schema URL above it,
# whatever winget-pkgs accepts (doc 11). This raises both in one file.
function Set-ManifestVersion([string] $Path) {
    $schema = '(?m)^(# yaml-language-server: \$schema=https://aka\.ms/winget-manifest\.\w+\.)\d+\.\d+\.\d+(?=\.schema\.json)'
    (Get-Content $Path -Raw) `
        -replace $schema, "`${1}$ManifestVersion" `
        -replace '(?m)^ManifestVersion:[^\r\n]*', "ManifestVersion: $ManifestVersion" |
        Set-Content $Path -NoNewline
}

# A request file rather than -f fields: a commit carries every manifest.
function Invoke-GraphQL([string] $Query, [hashtable] $Variables) {
    $request = Join-Path $work 'graphql.json'
    [ordered]@{ query = $Query; variables = $Variables } |
        ConvertTo-Json -Depth 8 -Compress | Set-Content $request -NoNewline
    $response = gh api graphql --input $request
    Assert-Exit 'gh api graphql'
    ($response | ConvertFrom-Json).data
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
#    step 6 submits without Komac.
$open = gh pr list --repo microsoft/winget-pkgs --state open `
    --search "$PackageIdentifier $Version in:title" --json url --jq '.[].url'
Assert-Exit 'gh pr list'
gh api "repos/microsoft/winget-pkgs/contents/$packagePath/$Version" --silent 2>$null
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
        Get-ChildItem $dir -Filter '*.yaml' | ForEach-Object { Set-ManifestVersion $_.FullName }
    }

    # 5. Doc 11's invariants, checked in the bytes that will be submitted - by
    #    field, not by layout: Komac writes CRLF and orders keys its own way.
    #    Each file is read once, here, and step 6 sends these bytes.
    $manifests = [ordered]@{}
    Get-ChildItem $dir -Filter '*.yaml' | Sort-Object Name | ForEach-Object {
        $manifests[$_.Name] = [IO.File]::ReadAllBytes($_.FullName)
    }
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    function Read-Manifest([string] $Suffix) {
        $name = "$PackageIdentifier$Suffix.yaml"
        if (-not $manifests.Contains($name)) { throw "$(Join-Path $dir $name) is missing." }
        $utf8.GetString($manifests[$name])
    }
    $installer = Read-Manifest '.installer'
    $default = Read-Manifest '.locale.en-US'
    $checks = [ordered]@{
        'five files: version, installer, en-US, vi-VN, ja-JP' = $manifests.Count -eq 5
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
    # The manifest version twice over: WinGet reads the field, a reviewer the
    # schema comment, and Komac's output says 1.12.0 in both.
    $mv = [regex]::Escape($ManifestVersion)
    foreach ($name in $manifests.Keys) {
        $text = $utf8.GetString($manifests[$name])
        $checks["$name is version $Version"] =
            $text -match "(?m)^PackageVersion:\s*'?$([regex]::Escape($Version))'?\s*$"
        $checks["$name is manifest version $ManifestVersion, schema comment included"] =
            ($text -match ('(?m)^ManifestVersion:\s*' + $mv + '\s*$')) -and
            ($text -match ('(?m)^# yaml-language-server: \$schema=https://aka\.ms/winget-manifest\.\w+\.' +
                $mv + '\.schema\.json\s*$'))
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

    # The pull request: Komac's title, and a body that ticks what this script
    # checked and nothing else - a Sandbox run (doc 11, "Per release") is
    # ticked by hand. Both are written either way, so a dry run shows them.
    $listing = gh api "repos/microsoft/winget-pkgs/contents/$packagePath" `
        --jq '.[] | select(.type == "dir") | .name' 2>$null
    if ($LASTEXITCODE -eq 0) {
        $latest = @($listing | ForEach-Object { $_ -as [version] } | Where-Object { $_ }) |
            Sort-Object -Descending | Select-Object -First 1
    } elseif ("$listing" -match '"status":\s*"404"') {
        $latest = $null
    } else {
        throw "gh api contents/$packagePath failed (exit $LASTEXITCODE)."
    }
    $state = if (-not $latest) { 'New package' } elseif ([version] $Version -gt $latest) { 'New version' } else { 'Add version' }
    $title = "${state}: $PackageIdentifier version $Version"
    $origin = if ($ManifestDir) { 'Hand-written.' } else {
        "Generated with Komac $KomacVersion, which writes manifest version 1.12.0, and raised to $ManifestVersion."
    }
    $bodyFile = Join-Path $work 'pull-request.md'
    @'
## Description

{0} {1}, the installer published at https://github.com/{2}/releases/tag/{3}.

## Checklist

- [x] Signed the [Contributor License Agreement](https://cla.opensource.microsoft.com)
- [ ] Linked to an issue (if applicable)

## Manifest Checklist

- [x] Checked that there aren't other open [pull requests](https://github.com/microsoft/winget-pkgs/pulls) for the same manifest update/change
- [x] This PR only modifies one (1) manifest
- [x] Validated manifest locally with `winget validate --manifest <path>`
- [ ] Tested manifest locally with `winget install --manifest <path>`
- [x] Manifest conforms to the [{4} schema](https://github.com/microsoft/winget-cli/tree/master/schemas/JSON/manifests/v{5})

{6} [`tool/winget/submit.ps1`](https://github.com/{2}/blob/main/tool/winget/submit.ps1) checked these files against the release and submitted them byte for byte.
'@ -f $PackageName, $Version, $Repo, $tag, ($ManifestVersion -replace '\.0$'), $ManifestVersion, $origin |
        Set-Content $bodyFile
    Write-Host "`n$title"

    # 6. The one step that writes anywhere but build/: a branch on the fork at
    #    winget-pkgs' master, one commit of the bytes step 5 checked, and the
    #    pull request. Not `komac submit`, which re-serialises what it is given:
    #    every released Komac writes the 1.12.0 schema comment whatever a file
    #    says, and 2.17 puts ManifestVersion back to 1.12.0 as well (doc 11).
    if ($Submit) {
        $user = gh api user --jq .login
        Assert-Exit 'gh api user'
        $parent = gh api "repos/$user/winget-pkgs" --jq '.parent.full_name' 2>$null
        if ($LASTEXITCODE -ne 0 -or $parent -ne 'microsoft/winget-pkgs') {
            throw "Fork microsoft/winget-pkgs first: gh repo fork microsoft/winget-pkgs --clone=false"
        }
        $forkId = gh api "repos/$user/winget-pkgs" --jq .node_id
        Assert-Exit "gh api repos/$user/winget-pkgs"
        $base = gh api repos/microsoft/winget-pkgs/git/ref/heads/master --jq .object.sha
        Assert-Exit 'gh api git/ref/heads/master'

        # Komac's branch name: identifier, version, a UUID.
        $branch = "$PackageIdentifier-$Version-$([guid]::NewGuid().ToString('N').ToUpperInvariant())"
        $null = Invoke-GraphQL 'mutation($input: CreateRefInput!) { createRef(input: $input) { ref { name } } }' @{
            input = @{ repositoryId = $forkId; name = "refs/heads/$branch"; oid = $base }
        }
        # createCommitOnBranch, so GitHub signs the commit as it did Komac's.
        $additions = @(foreach ($name in $manifests.Keys) {
                @{ path = "$packagePath/$Version/$name"; contents = [Convert]::ToBase64String($manifests[$name]) }
            })
        $null = Invoke-GraphQL 'mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }' @{
            input = @{
                branch          = @{ repositoryNameWithOwner = "$user/winget-pkgs"; branchName = $branch }
                expectedHeadOid = $base
                message         = @{ headline = $title }
                fileChanges     = @{ additions = $additions }
            }
        }
        $pr = gh api repos/microsoft/winget-pkgs/pulls -f "title=$title" -f "head=${user}:$branch" `
            -f base=master -F "body=@$bodyFile" -F maintainer_can_modify=true --jq .html_url
        Assert-Exit 'gh api pulls'
        Write-Host "`nOpened $pr - link it in doc 15."
    } else {
        Write-Host "`nDry run. Read $dir and $bodyFile, then run again with -Submit."
    }
} finally {
    if ($null -eq $savedToken) {
        Remove-Item Env:GITHUB_TOKEN -ErrorAction Ignore
    } else {
        $env:GITHUB_TOKEN = $savedToken
    }
}
