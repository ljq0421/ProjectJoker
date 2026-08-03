param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [Parameter(Mandatory = $true)]
    [string]$OutputDir,
    [string]$FontFamily = 'Noto Sans SC'
)

Add-Type -AssemblyName System.Drawing

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$fontStyle = [System.Drawing.FontStyle]::Regular
$family = [System.Drawing.FontFamily]::new($FontFamily)
$emHeight = [double]$family.GetEmHeight($fontStyle)
$cellAscent = [double]$family.GetCellAscent($fontStyle)

function Format-Number([double]$value) {
    return $value.ToString('0.##', $culture)
}

function Convert-GraphicsPathToSvg([System.Drawing.Drawing2D.GraphicsPath]$glyphPath) {
    $points = $glyphPath.PathPoints
    $types = $glyphPath.PathTypes
    $commands = [System.Collections.Generic.List[string]]::new()
    $index = 0
    while ($index -lt $points.Count) {
        $rawType = [int]$types[$index]
        $kind = $rawType -band 0x07
        if ($kind -eq 0) {
            $commands.Add(('M{0} {1}' -f (Format-Number $points[$index].X), (Format-Number $points[$index].Y)))
            if (($rawType -band 0x80) -ne 0) {
                $commands.Add('Z')
            }
            $index += 1
            continue
        }
        if ($kind -eq 1) {
            $commands.Add(('L{0} {1}' -f (Format-Number $points[$index].X), (Format-Number $points[$index].Y)))
            if (($rawType -band 0x80) -ne 0) {
                $commands.Add('Z')
            }
            $index += 1
            continue
        }
        if ($kind -eq 3 -and $index + 2 -lt $points.Count) {
            $commands.Add((
                'C{0} {1} {2} {3} {4} {5}' -f
                (Format-Number $points[$index].X),
                (Format-Number $points[$index].Y),
                (Format-Number $points[$index + 1].X),
                (Format-Number $points[$index + 1].Y),
                (Format-Number $points[$index + 2].X),
                (Format-Number $points[$index + 2].Y)
            ))
            if (([int]$types[$index + 2] -band 0x80) -ne 0) {
                $commands.Add('Z')
            }
            $index += 3
            continue
        }
        throw "Unsupported GraphicsPath point type $kind at index $index"
    }
    return [string]::Join(' ', $commands)
}

$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$settings.Indent = $true
$settings.NewLineChars = "`n"
$settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$generated = 0
foreach ($source in Get-ChildItem -LiteralPath $SourceDir -Filter '*.svg.txt' -File | Sort-Object Name) {
    $document = [System.Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $false
    $document.Load($source.FullName)
    $textNodes = @($document.SelectNodes("//*[local-name()='text']"))
    foreach ($textNode in $textNodes) {
        $fontSize = [double]::Parse($textNode.GetAttribute('font-size'), $culture)
        $x = [double]::Parse($textNode.GetAttribute('x'), $culture)
        $baseline = [double]::Parse($textNode.GetAttribute('y'), $culture)
        $width = [double]::Parse($textNode.GetAttribute('data-width'), $culture)
        $anchor = $textNode.GetAttribute('text-anchor')
        if ($anchor -eq 'middle') {
            $x -= $width / 2.0
        } elseif ($anchor -eq 'end') {
            $x -= $width
        }
        $top = $baseline - ($fontSize * $cellAscent / $emHeight)
        $glyphPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
        $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoClip
        $glyphPath.AddString(
            $textNode.InnerText,
            $family,
            [int]$fontStyle,
            [single]$fontSize,
            [System.Drawing.PointF]::new([single]$x, [single]$top),
            $format
        )
        $group = $document.CreateElement('g', $document.DocumentElement.NamespaceURI)
        $group.SetAttribute('id', $textNode.GetAttribute('id'))
        $group.SetAttribute('data-copy', $textNode.GetAttribute('data-copy'))
        $group.SetAttribute('data-font-size', $textNode.GetAttribute('font-size'))
        $pathNode = $document.CreateElement('path', $document.DocumentElement.NamespaceURI)
        $pathNode.SetAttribute('d', (Convert-GraphicsPathToSvg $glyphPath))
        $pathNode.SetAttribute('fill', $textNode.GetAttribute('fill'))
        $pathNode.SetAttribute('stroke', $textNode.GetAttribute('stroke'))
        $pathNode.SetAttribute('stroke-width', $textNode.GetAttribute('stroke-width'))
        $pathNode.SetAttribute('stroke-linejoin', 'round')
        $group.AppendChild($pathNode) | Out-Null
        $textNode.ParentNode.ReplaceChild($group, $textNode) | Out-Null
        $format.Dispose()
        $glyphPath.Dispose()
    }
    $outputName = $source.Name.Substring(0, $source.Name.Length - 4)
    $outputPath = Join-Path $OutputDir $outputName
    $writer = [System.Xml.XmlWriter]::Create($outputPath, $settings)
    $document.Save($writer)
    $writer.Dispose()
    $generated += 1
}

$family.Dispose()
Write-Host "PATHIFIED $generated complete card-face SVGs with $FontFamily"
