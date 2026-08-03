[CmdletBinding()]
param(
    [string]$GodotPath = "D:\Godot\Godot_v4.6.1-stable_win64_console.exe",
    [string]$OutputDirectory = "build\windows",
    [switch]$SkipTests,
    [switch]$SkipSmokeTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$outputRoot = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
}
$projectPrefix = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output directory must stay inside the project: $outputRoot"
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$artifactPath = Join-Path $outputRoot "ProjectJokerDemo.exe"
$packagePath = Join-Path $outputRoot "ProjectJokerDemo.pck"
$manifestPath = Join-Path $outputRoot "build-info.json"
$verificationLog = Join-Path $outputRoot "verification.log"
$smokeLog = Join-Path $outputRoot "smoke-test.log"

foreach ($stalePath in @($artifactPath, $packagePath, $manifestPath, $verificationLog, $smokeLog)) {
    if (Test-Path -LiteralPath $stalePath -PathType Leaf) {
        Remove-Item -LiteralPath $stalePath -Force
    }
}

Push-Location $projectRoot
try {
    if (-not $SkipTests) {
        & $GodotPath --headless --path $projectRoot --log-file $verificationLog -s res://tests/run_all.gd
        if ($LASTEXITCODE -ne 0) {
            throw "Automated verification failed with exit code $LASTEXITCODE. See $verificationLog"
        }
    }

    & $GodotPath --headless --path $projectRoot --export-release "Windows Demo" $artifactPath
    if ($LASTEXITCODE -ne 0) {
        throw "Windows release export failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "Windows release artifact was not created: $artifactPath"
    }
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Windows release package was not created: $packagePath"
    }

    if (-not $SkipSmokeTest) {
        Push-Location $outputRoot
        try {
            & $GodotPath --headless --log-file $smokeLog --main-pack $packagePath --quit-after 2 -- --release-smoke-test
            $smokeExitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        if ($smokeExitCode -ne 0) {
            throw "Exported package smoke test failed with exit code $smokeExitCode. See $smokeLog"
        }
        $scopeProbe = Select-String -LiteralPath $smokeLog -SimpleMatch "RELEASE_SMOKE demo=true release_files=false" | Select-Object -First 1
        if ($null -eq $scopeProbe) {
            throw "Exported package did not confirm demo scope and release-file exclusion. See $smokeLog"
        }
    }

    $versionLine = Select-String -LiteralPath (Join-Path $projectRoot "project.godot") -Pattern '^config/version="([^"]+)"$' | Select-Object -First 1
    if ($null -eq $versionLine) {
        throw "application/config/version is missing from project.godot"
    }
    $version = $versionLine.Matches[0].Groups[1].Value
    $commit = (& git -C $projectRoot rev-parse --short=12 HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $commit = "unavailable"
    }
    $dirty = $false
    if ($commit -ne "unavailable") {
        $dirty = [bool](& git -C $projectRoot status --porcelain)
    }
    $artifacts = @($artifactPath, $packagePath) | ForEach-Object {
        $item = Get-Item -LiteralPath $_
        $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
        [ordered]@{
            file = $item.Name
            bytes = $item.Length
            sha256 = $hash.Hash.ToLowerInvariant()
        }
    }
    $productName = [string]::Concat(
        [char]0x516D,
        [char]0x9762,
        [char]0x8BE1,
        [char]0x5C40,
        " Demo"
    )
    $manifest = [ordered]@{
        product = $productName
        version = $version
        preset = "Windows Demo"
        architecture = "x86_64"
        git_commit = [string]$commit
        working_tree_dirty = $dirty
        built_at_utc = [DateTime]::UtcNow.ToString("o")
        artifacts = $artifacts
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Output "Windows demo build completed: $outputRoot"
    Write-Output "Manifest: $manifestPath"
} finally {
    Pop-Location
}
