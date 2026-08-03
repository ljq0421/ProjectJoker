[CmdletBinding()]
param(
    [string]$GodotPath = "D:\Godot\Godot_v4.6.1-stable_win64_console.exe",
    [string]$OutputDirectory = "release\steam_demo\store_assets\screenshots"
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
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "release\steam_demo\store_assets\screenshots"))
if (-not $outputRoot.StartsWith($releaseRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Screenshot output must stay inside $releaseRoot"
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$logRoot = Join-Path $projectRoot "tmp\steam-demo-capture-logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

$captures = @(
    @{ File = "01_demo_main_menu.png"; Script = "res://tests/main_menu_visual_capture.gd"; Args = @("--scope=demo", "--state=main") },
    @{ File = "02_first_run_setup.png"; Script = "res://tests/expedition_setup_visual_capture.gd"; Args = @("--state=first-run") },
    @{ File = "03_gold_corridor_encounter.png"; Script = "res://tests/area_presentation_visual_capture.gd"; Args = @("--area=gold", "--state=encounter") },
    @{ File = "04_mirror_hall_encounter.png"; Script = "res://tests/area_presentation_visual_capture.gd"; Args = @("--area=mirror", "--state=encounter") },
    @{ File = "05_faceless_hub_encounter.png"; Script = "res://tests/area_presentation_visual_capture.gd"; Args = @("--area=faceless", "--state=encounter") }
)

foreach ($capture in $captures) {
    $target = Join-Path $outputRoot $capture.File
    $log = Join-Path $logRoot ($capture.File + ".log")
    $arguments = @(
        "--path", $projectRoot,
        "--log-file", $log,
        "-s", $capture.Script,
        "--", "--output=$target"
    ) + $capture.Args
    & $GodotPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Capture failed for $($capture.File). See $log"
    }
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Capture did not create $target"
    }
}

Write-Output "Steam demo screenshots captured: $outputRoot"
