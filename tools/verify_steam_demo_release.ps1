[CmdletBinding()]
param(
    [switch]$RequireStoreAssets,
    [switch]$RequireHumanPlaytest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseRoot = Join-Path $projectRoot "release\steam_demo"
$manifestPath = Join-Path $releaseRoot "store_assets_manifest.json"
$buildManifestPath = Join-Path $projectRoot "build\windows\build-info.json"
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Store asset manifest missing: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

foreach ($screenshot in $manifest.screenshots) {
    $path = Join-Path (Join-Path $releaseRoot "store_assets") $screenshot.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing screenshot: $($screenshot.file)")
        continue
    }
    $image = [System.Drawing.Image]::FromFile($path)
    try {
        if ($image.Width -ne $screenshot.width -or $image.Height -ne $screenshot.height) {
            $errors.Add("Wrong screenshot size: $($screenshot.file) is $($image.Width)x$($image.Height)")
        }
    } finally {
        $image.Dispose()
    }
}

foreach ($capsule in $manifest.capsules) {
    $path = Join-Path (Join-Path $releaseRoot "store_assets") $capsule.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $message = "Missing capsule: $($capsule.file)"
        if ($RequireStoreAssets) { $errors.Add($message) } else { $warnings.Add($message) }
        continue
    }
    $image = [System.Drawing.Image]::FromFile($path)
    try {
        if ($image.Width -ne $capsule.width -or $image.Height -ne $capsule.height) {
            $errors.Add("Wrong capsule size: $($capsule.file) is $($image.Width)x$($image.Height)")
        }
    } finally {
        $image.Dispose()
    }
}

if ($RequireStoreAssets -and $manifest.trailer.status -ne "ready") {
    $errors.Add("Trailer is not marked ready")
} elseif ($manifest.trailer.status -ne "ready") {
    $warnings.Add("Trailer is not ready")
}

if (-not (Test-Path -LiteralPath $buildManifestPath -PathType Leaf)) {
    $warnings.Add("Windows build manifest is absent; run tools\build_windows_demo.cmd")
}

$playtestDecision = Join-Path $releaseRoot "playtests\release_decision.json"
if (-not (Test-Path -LiteralPath $playtestDecision -PathType Leaf)) {
    $message = "Human playtest release decision is absent"
    if ($RequireHumanPlaytest) { $errors.Add($message) } else { $warnings.Add($message) }
} else {
    $decision = Get-Content -LiteralPath $playtestDecision -Raw | ConvertFrom-Json
    if ($decision.decision -ne "go") {
        $message = "Human playtest release decision is $($decision.decision), not go"
        if ($RequireHumanPlaytest) { $errors.Add($message) } else { $warnings.Add($message) }
    }
}

foreach ($warning in $warnings) { Write-Warning $warning }
foreach ($errorMessage in $errors) { Write-Error $errorMessage }
if ($errors.Count -gt 0) { exit 1 }
Write-Output "Steam demo release verification passed with $($warnings.Count) warning(s)."
