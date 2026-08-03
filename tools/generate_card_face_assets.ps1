param(
    [string]$Godot = 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe',
    [string]$Python = 'python',
    [string]$Font = 'C:\Windows\Fonts\NotoSansSC-VF.ttf'
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $projectRoot 'resources\ui\dream_glass\card_faces\card_face_manifest.json'
$sourceDir = Join-Path $projectRoot 'resources\ui\dream_glass\card_faces\sources'
$outputDir = Join-Path $projectRoot 'resources\ui\dream_glass\card_faces\prototypes'
$logPath = Join-Path $env:TEMP 'project-joker-card-face-export.log'

& $Godot --headless --path $projectRoot --log-file $logPath `
    -s res://tools/export_card_face_data.gd -- --output=res://resources/ui/dream_glass/card_faces/card_face_manifest.json
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $Python (Join-Path $projectRoot 'tools\generate_card_face_svgs.py') `
    --manifest $manifest --font $Font --output-dir $sourceDir
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $PSScriptRoot 'pathify_card_face_text.ps1') `
    -SourceDir $sourceDir -OutputDir $outputDir -FontFamily 'Noto Sans SC'
exit $LASTEXITCODE
