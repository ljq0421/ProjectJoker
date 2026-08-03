[CmdletBinding()]
param(
    [string]$PlaytestDirectory = "release\steam_demo\playtests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$playtestRoot = if ([IO.Path]::IsPathRooted($PlaytestDirectory)) {
    [IO.Path]::GetFullPath($PlaytestDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $PlaytestDirectory))
}
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "release\steam_demo\playtests"))
if (-not $playtestRoot.StartsWith($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Playtest directory must stay inside $expectedRoot"
}

$sessionFiles = @(Get-ChildItem -LiteralPath $playtestRoot -Filter "session-*.json" -File | Where-Object { $_.Name -ne "session-template.json" } | Sort-Object Name)
if ($sessionFiles.Count -eq 0) {
    throw "No playtest sessions found. Copy session-template.json to session-YYYYMMDD-01.json first."
}

$sessions = @()
foreach ($file in $sessionFiles) {
    $session = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    foreach ($required in @("participant_id", "build_version", "first_time_player", "completed_first_area", "needed_verbal_help", "would_continue", "recognized_three_region_difference", "blocker_tags")) {
        if ($null -eq $session.PSObject.Properties[$required]) {
            throw "$($file.Name) is missing required field: $required"
        }
    }
    if (-not $session.first_time_player) {
        Write-Warning "$($file.Name) is not a first-time-player session and will be excluded"
        continue
    }
    $sessions += $session
}
if ($sessions.Count -eq 0) {
    throw "No eligible first-time-player sessions found."
}

function Get-Rate([int]$count, [int]$total) {
    if ($total -eq 0) { return 0.0 }
    return [Math]::Round($count / [double]$total, 3)
}

$total = $sessions.Count
$firstAreaWithoutHelp = @($sessions | Where-Object { $_.completed_first_area -and -not $_.needed_verbal_help }).Count
$wouldContinue = @($sessions | Where-Object { $_.would_continue }).Count
$recognizedDifference = @($sessions | Where-Object { $_.recognized_three_region_difference }).Count
$completedExpedition = @($sessions | Where-Object { $_.completed_expedition }).Count
$blockerCounts = @{}
foreach ($session in $sessions) {
    foreach ($tag in @($session.blocker_tags | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace([string]$tag)) { continue }
        if (-not $blockerCounts.ContainsKey([string]$tag)) { $blockerCounts[[string]$tag] = 0 }
        $blockerCounts[[string]$tag] += 1
    }
}
$maxBlockerCount = 0
$topBlockers = @()
foreach ($entry in $blockerCounts.GetEnumerator() | Sort-Object @{Expression = "Value"; Descending = $true}, @{Expression = "Name"; Descending = $false}) {
    if ($entry.Value -gt $maxBlockerCount) { $maxBlockerCount = $entry.Value }
    $topBlockers += [ordered]@{ tag = $entry.Key; count = $entry.Value; rate = Get-Rate $entry.Value $total }
}

$metrics = [ordered]@{
    eligible_first_time_players = $total
    first_area_without_help_rate = Get-Rate $firstAreaWithoutHelp $total
    would_continue_rate = Get-Rate $wouldContinue $total
    recognized_three_region_difference_rate = Get-Rate $recognizedDifference $total
    completed_expedition_rate = Get-Rate $completedExpedition $total
    highest_shared_blocker_rate = Get-Rate $maxBlockerCount $total
    blockers = $topBlockers
}
$gates = [ordered]@{
    sample_size = ($total -ge 5)
    first_area_without_help = ($metrics.first_area_without_help_rate -ge 0.8)
    no_shared_blocker = ($metrics.highest_shared_blocker_rate -le 0.4)
    willingness_to_continue = ($metrics.would_continue_rate -ge 0.6)
    region_difference_clear = ($metrics.recognized_three_region_difference_rate -ge 0.8)
}
$decision = "go"
foreach ($value in $gates.Values) {
    if (-not $value) { $decision = "no-go"; break }
}

$summary = [ordered]@{
    schema_version = 1
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_files = @($sessionFiles.Name)
    metrics = $metrics
    gates = $gates
    decision = $decision
    note = "Automated gate result; free-text observations and store readiness still require human review."
}
$summaryPath = Join-Path $playtestRoot "summary.json"
$decisionPath = Join-Path $playtestRoot "release_decision.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
([ordered]@{
    schema_version = 1
    decision = $decision
    generated_at_utc = $summary.generated_at_utc
    eligible_first_time_players = $total
    gates = $gates
}) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $decisionPath -Encoding UTF8

Write-Output "Playtest summary: $summaryPath"
Write-Output "Release decision: $decision"
if ($decision -ne "go") { exit 2 }
