# Windows-only source for the portfolio's social preview artwork.
# Uses installed Windows fonts and System.Drawing; no browser or package install is needed.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputPath = Join-Path $projectRoot 'assets/social-card.png'
$canvas = New-Object Drawing.Bitmap(2400, 1254)
$graphics = [Drawing.Graphics]::FromImage($canvas)
$graphics.ScaleTransform(2, 2)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality

function Get-Color {
    param([string]$Hex, [int]$Alpha = 255)
    $color = [Drawing.ColorTranslator]::FromHtml($Hex)
    return [Drawing.Color]::FromArgb($Alpha, $color.R, $color.G, $color.B)
}

function Draw-Line {
    param([single]$X1, [single]$Y1, [single]$X2, [single]$Y2, [string]$Color, [single]$Width = 1)
    $pen = New-Object Drawing.Pen((Get-Color $Color), $Width)
    try { $graphics.DrawLine($pen, $X1, $Y1, $X2, $Y2) } finally { $pen.Dispose() }
}

function Draw-Rectangle {
    param([single]$X, [single]$Y, [single]$Width, [single]$Height, [string]$Fill, [string]$Stroke)
    $brush = New-Object Drawing.SolidBrush((Get-Color $Fill))
    $pen = New-Object Drawing.Pen((Get-Color $Stroke), [single]1)
    try {
        $graphics.FillRectangle($brush, $X, $Y, $Width, $Height)
        $graphics.DrawRectangle($pen, $X, $Y, $Width, $Height)
    } finally { $brush.Dispose(); $pen.Dispose() }
}

function Draw-Text {
    param([string]$Text, [single]$X, [single]$Y, [string]$Family, [single]$Size, [Drawing.FontStyle]$Style, [string]$Color)
    $font = New-Object Drawing.Font($Family, $Size, $Style, [Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object Drawing.SolidBrush((Get-Color $Color))
    $format = [Drawing.StringFormat]::GenericTypographic.Clone()
    try { $graphics.DrawString($Text, $font, $brush, $X, $Y, $format) }
    finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() }
}

function Draw-TrackedText {
    param([string]$Text, [single]$X, [single]$Y, [single]$Size, [single]$Tracking, [string]$Color)
    $font = New-Object Drawing.Font('Consolas', $Size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object Drawing.SolidBrush((Get-Color $Color))
    $format = [Drawing.StringFormat]::GenericTypographic.Clone()
    try {
        foreach ($character in $Text.ToCharArray()) {
            $graphics.DrawString([string]$character, $font, $brush, $X, $Y, $format)
            $X += $Size * 0.55 + $Tracking
        }
    } finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() }
}

function Draw-Circle {
    param([single]$X, [single]$Y, [single]$Diameter, [string]$Color, [single]$Width = 1)
    $pen = New-Object Drawing.Pen((Get-Color $Color), $Width)
    try { $graphics.DrawEllipse($pen, $X, $Y, $Diameter, $Diameter) } finally { $pen.Dispose() }
}

function Draw-Monogram {
    param([single]$X, [single]$Y)
    # These vector letterforms match favicon.svg and need no installed logo font.
    $state = $graphics.Save()
    $letterP = New-Object Drawing.Drawing2D.GraphicsPath
    $letterS = New-Object Drawing.Drawing2D.GraphicsPath
    $white = New-Object Drawing.SolidBrush((Get-Color '#f0f3f7'))
    $cyan = New-Object Drawing.SolidBrush((Get-Color '#69d4e2'))
    try {
        $graphics.TranslateTransform($X, $Y)
        Draw-Rectangle 0 0 64 64 '#0b1220' '#354c64'
        $letterP.AddLine(10, 16, 22, 16)
        $letterP.AddBezier(22, 16, 28, 16, 32, 20, 32, 27)
        $letterP.AddBezier(32, 27, 32, 34, 28, 38, 22, 38)
        $letterP.AddLine(22, 38, 18, 38)
        $letterP.AddLine(18, 38, 18, 47)
        $letterP.AddLine(18, 47, 10, 47)
        $letterP.CloseFigure()
        $letterP.StartFigure()
        $letterP.AddLine(18, 23, 18, 31)
        $letterP.AddLine(18, 31, 22, 31)
        $letterP.AddBezier(22, 31, 24, 31, 25, 29.5, 25, 27)
        $letterP.AddBezier(25, 27, 25, 24.5, 24, 23, 22, 23)
        $letterP.CloseFigure()
        $letterS.AddBezier(53, 18.5, 50.5, 16.2, 47.5, 15, 43.8, 15)
        $letterS.AddBezier(43.8, 15, 37.9, 15, 34.5, 18.7, 34.5, 24.3)
        $letterS.AddBezier(34.5, 24.3, 34.5, 29.6, 37.7, 32.5, 43.8, 34.5)
        $letterS.AddBezier(43.8, 34.5, 47.7, 35.8, 49, 36.9, 49, 38.8)
        $letterS.AddBezier(49, 38.8, 49, 40.8, 47.5, 42, 44.9, 42)
        $letterS.AddBezier(44.9, 42, 41.4, 42, 38.8, 40.5, 36.5, 38.5)
        $letterS.AddLine(36.5, 38.5, 33.5, 45)
        $letterS.AddBezier(33.5, 45, 36.6, 47.8, 40.5, 49, 44.8, 49)
        $letterS.AddBezier(44.8, 49, 51.8, 49, 56, 45.2, 56, 38.7)
        $letterS.AddBezier(56, 38.7, 56, 33.2, 52.7, 30.3, 46.8, 28.4)
        $letterS.AddBezier(46.8, 28.4, 43.2, 27.2, 41.5, 26.2, 41.5, 24.3)
        $letterS.AddBezier(41.5, 24.3, 41.5, 22.8, 42.7, 22, 44.6, 22)
        $letterS.AddBezier(44.6, 22, 47, 22, 49.1, 23.1, 51, 24.8)
        $letterS.CloseFigure()
        $graphics.FillPath($white, $letterP)
        $graphics.FillPath($cyan, $letterS)
    } finally {
        $letterP.Dispose(); $letterS.Dispose(); $white.Dispose(); $cyan.Dispose()
        $graphics.Restore($state)
    }
}

function Draw-Node {
    param([single]$X, [single]$Y, [string]$Symbol, [string]$Label)
    Draw-Rectangle $X $Y 77 61 '#17283c' '#3d6378'
    Draw-Text $Symbol ($X + 18) ($Y + 7) 'Consolas' 25 Regular '#69d4e2'
    Draw-TrackedText $Label ($X + 10) ($Y + 44) 8 0.35 '#b3c5d9'
}

try {
    $graphics.Clear((Get-Color '#0b1220'))

    # A restrained grid links the artwork to the portfolio's infrastructure map.
    for ($x = 778; $x -le 1150; $x += 27) {
        Draw-Line $x 169 $x 480 '#17283c'
    }
    for ($y = 169; $y -le 480; $y += 27) {
        Draw-Line 778 $y 1150 $y '#17283c'
    }

    Draw-Monogram 65 57
    Draw-Line 153 65 153 120 '#2a394e'
    Draw-TrackedText 'PRAKHAR SHUKLA' 177 70 22 1.6 '#f0f3f7'
    Draw-TrackedText 'DEVOPS ENGINEER' 178 104 12 1.35 '#69d4e2'
    Draw-TrackedText 'CLOUD / AUTOMATION / DELIVERY' 827 88 10 0.75 '#a9b6c9'
    Draw-Line 66 144 1134 144 '#2a394e'

    Draw-Text 'Code to' 61 202 'Segoe UI' 94 Bold '#f0f3f7'
    Draw-Text 'production.' 61 312 'Georgia' 88 Italic '#f0b58b'
    Draw-TrackedText 'CLOUD INFRASTRUCTURE. REPEATABLE DELIVERY.' 68 441 12 0.8 '#a9b6c9'

    # Code-native cloud/network illustration. This is decorative artwork, not live status.
    Draw-TrackedText 'FROM COMMIT TO CLOUD' 810 184 9 0.8 '#a9b6c9'
    Draw-Circle 861 225 204 '#3b5a70'
    Draw-Circle 833 197 260 '#2a394e'
    Draw-Line 852 248 963 327 '#5689a0'
    Draw-Line 1074 248 963 327 '#5689a0'
    Draw-Line 852 406 963 327 '#5689a0'
    Draw-Line 1074 406 963 327 '#5689a0'

    Draw-Node 810 214 '</>' 'GIT'
    Draw-Node 1038 214 '{ }' 'TERRAFORM'
    Draw-Node 810 378 '[ ]' 'DOCKER'
    Draw-Node 1038 378 '+ +' 'K8S / AKS'

    $coreBrush = New-Object Drawing.SolidBrush((Get-Color '#17374c'))
    $corePen = New-Object Drawing.Pen((Get-Color '#69a6b9'), [single]1)
    try {
        $graphics.FillEllipse($coreBrush, [single]900, [single]264, [single]126, [single]126)
        $graphics.DrawEllipse($corePen, [single]900, [single]264, [single]126, [single]126)
    } finally { $coreBrush.Dispose(); $corePen.Dispose() }

    $cloud = New-Object Drawing.Drawing2D.GraphicsPath
    $cloudPen = New-Object Drawing.Pen((Get-Color '#69d4e2'), [single]1.8)
    try {
        $cloud.AddBezier(943, 328, 926, 328, 927, 306, 943, 305)
        $cloud.AddBezier(943, 305, 946, 283, 979, 284, 981, 307)
        $cloud.AddBezier(981, 307, 1000, 306, 1002, 328, 982, 328)
        $cloud.AddLine(982, 328, 943, 328)
        $graphics.DrawPath($cloudPen, $cloud)
    } finally { $cloud.Dispose(); $cloudPen.Dispose() }
    Draw-TrackedText 'AZURE' 933 347 13 3.6 '#69d4e2'
    Draw-TrackedText 'CODE > BUILD > DEPLOY > OBSERVE' 820 466 8 0.8 '#a9b6c9'

    Draw-Line 66 526 1134 526 '#2a394e'
    $separator = '  ' + [char]0x00B7 + '  '
    Draw-Text ('AZURE' + $separator + 'TERRAFORM' + $separator + 'KUBERNETES' + $separator + 'CI/CD') 66 557 'Consolas' 17 Regular '#b3c5d9'
    Draw-TrackedText 'DEVOPS / INDIA' 989 562 10 1.1 '#69d4e2'

    $final = New-Object Drawing.Bitmap(1200, 627)
    $export = [Drawing.Graphics]::FromImage($final)
    try {
        $export.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $export.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $export.DrawImage($canvas, 0, 0, 1200, 627)
        $final.SetResolution(96, 96)
        $final.Save($outputPath, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $export.Dispose(); $final.Dispose() }
} finally { $graphics.Dispose(); $canvas.Dispose() }

Get-Item -LiteralPath $outputPath | Select-Object FullName, Length
