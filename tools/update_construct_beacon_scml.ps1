param(
    [string]$ScmlPath = "animSource/construct_beacon/construct_beacon.scml",
    [int]$FrameCount = 40,
    [int]$FrameDurationMs = 33,
    [double]$MaxFloatY = 4.0,
    [double]$StartPhaseRad = 0.0,
    [int]$FloatCycleImageLoops = 2,
    [int]$ImageWidth = 73,
    [int]$ImageHeight = 84
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$fullPath = Resolve-Path $ScmlPath
[xml]$xml = Get-Content -LiteralPath $fullPath

if ($FloatCycleImageLoops -lt 1) {
    throw "FloatCycleImageLoops must be >= 1"
}

$totalFrameCount = $FrameCount * $FloatCycleImageLoops

$folder = $xml.spriter_data.folder
$entity = $xml.spriter_data.entity
$animation = $entity.animation
$mainline = $animation.mainline
$timeline = $animation.timeline

# Normalize and rebuild frame image list.
$folderFileNodes = $folder.SelectNodes("file")
foreach ($node in @($folderFileNodes)) {
    $null = $folder.RemoveChild($node)
}

for ($i = 1; $i -le $FrameCount; $i++) {
    $fileNode = $xml.CreateElement("file")
    $fileNode.SetAttribute("id", ($i - 1).ToString())
    $fileNode.SetAttribute("name", ("construct/construct_beacon_{0}.png" -f $i.ToString("00")))
    $fileNode.SetAttribute("width", $ImageWidth.ToString())
    $fileNode.SetAttribute("height", $ImageHeight.ToString())
    $fileNode.SetAttribute("pivot_x", "0.5")
    $fileNode.SetAttribute("pivot_y", "0")
    $null = $folder.AppendChild($fileNode)
}

$animation.SetAttribute("length", ($totalFrameCount * $FrameDurationMs).ToString())

$mainlineKeyNodes = $mainline.SelectNodes("key")
foreach ($node in @($mainlineKeyNodes)) {
    $null = $mainline.RemoveChild($node)
}

$timelineKeyNodes = $timeline.SelectNodes("key")
foreach ($node in @($timelineKeyNodes)) {
    $null = $timeline.RemoveChild($node)
}

for ($i = 0; $i -lt $totalFrameCount; $i++) {
    $time = $i * $FrameDurationMs

    $mainKey = $xml.CreateElement("key")
    $mainKey.SetAttribute("id", $i.ToString())
    if ($i -gt 0) {
        $mainKey.SetAttribute("time", $time.ToString())
    }

    $objRef = $xml.CreateElement("object_ref")
    $objRef.SetAttribute("id", "0")
    $objRef.SetAttribute("timeline", "0")
    $objRef.SetAttribute("key", $i.ToString())
    $objRef.SetAttribute("z_index", "0")
    $null = $mainKey.AppendChild($objRef)
    $null = $mainline.AppendChild($mainKey)

    $timelineKey = $xml.CreateElement("key")
    $timelineKey.SetAttribute("id", $i.ToString())
    if ($i -gt 0) {
        $timelineKey.SetAttribute("time", $time.ToString())
    }
    $timelineKey.SetAttribute("spin", "0")

    # Smooth periodic floating with phase control.
    # Range is [0, MaxFloatY], and default phase starts at the lowest point (y=0).
    # One full floating cycle spans FloatCycleImageLoops image-animation loops.
    $angle = 2.0 * [Math]::PI * $i / $totalFrameCount + $StartPhaseRad
    $y = [Math]::Round(0.5 * $MaxFloatY * (1.0 - [Math]::Cos($angle)), 3)

    $fileIndex = $i % $FrameCount

    $obj = $xml.CreateElement("object")
    $obj.SetAttribute("folder", "0")
    $obj.SetAttribute("file", $fileIndex.ToString())
    $obj.SetAttribute("x", "0")
    $obj.SetAttribute("y", [string]$y)
    $null = $timelineKey.AppendChild($obj)
    $null = $timeline.AppendChild($timelineKey)
}

$timeline.SetAttribute("name", "construct_beacon_01")

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.IndentChars = "    "
$settings.NewLineChars = "`r`n"
$settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)

$writer = [System.Xml.XmlWriter]::Create($fullPath, $settings)
$xml.Save($writer)
$writer.Close()

Write-Host "Updated $fullPath"
Write-Host "FrameCount=$FrameCount FloatCycleImageLoops=$FloatCycleImageLoops TotalFrameCount=$totalFrameCount FrameDurationMs=$FrameDurationMs MaxFloatY=$MaxFloatY StartPhaseRad=$StartPhaseRad"
