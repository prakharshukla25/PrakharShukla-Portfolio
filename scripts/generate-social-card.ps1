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

function Draw-Node {
    param([single]$X, [single]$Y, [string]$Symbol, [string]$Label)
    Draw-Rectangle $X $Y 77 61 '#1b2419' '#4a5a3b'
    Draw-Text $Symbol ($X + 18) ($Y + 7) 'Consolas' 25 Regular '#c7f58a'
    Draw-TrackedText $Label ($X + 10) ($Y + 44) 8 0.35 '#adbda1'
}

try {
    $graphics.Clear((Get-Color '#101410'))

    # A restrained grid links the artwork to the portfolio's infrastructure map.
    for ($x = 778; $x -le 1150; $x += 27) {
        Draw-Line $x 169 $x 480 '#1b2519'
    }
    for ($y = 169; $y -le 480; $y += 27) {
        Draw-Line 778 $y 1150 $y '#1b2519'
    }

    Draw-Text 'ps' 65 57 'Consolas' 48 Bold '#f0f1e9'
    Draw-Text '_' 115 57 'Consolas' 48 Bold '#c7f58a'
    Draw-Line 153 65 153 120 '#30382d'
    Draw-TrackedText 'PRAKHAR SHUKLA' 177 70 22 1.6 '#f0f1e9'
    Draw-TrackedText 'DEVOPS ENGINEER' 178 104 12 1.35 '#c7f58a'
    Draw-TrackedText 'CLOUD / AUTOMATION / DELIVERY' 827 88 10 0.75 '#84927a'
    Draw-Line 66 144 1134 144 '#30382d'

    Draw-Text 'Built to ship.' 61 187 'Segoe UI' 86 Bold '#f0f1e9'
    Draw-Text 'Engineered to' 64 291 'Georgia' 68 Italic '#f0f1e9'
    Draw-Text 'stay up.' 65 369 'Georgia' 68 Italic '#c7f58a'

    # Code-native cloud/network illustration. This is decorative artwork, not live status.
    Draw-TrackedText 'INFRASTRUCTURE, AS INTENDED.' 810 184 9 0.8 '#8f9d81'
    Draw-Circle 861 225 204 '#35442b'
    Draw-Circle 833 197 260 '#263421'
    Draw-Line 852 248 963 327 '#657b50'
    Draw-Line 1074 248 963 327 '#657b50'
    Draw-Line 852 406 963 327 '#657b50'
    Draw-Line 1074 406 963 327 '#657b50'

    Draw-Node 810 214 '>_' 'GIT'
    Draw-Node 1038 214 '{ }' 'TERRAFORM'
    Draw-Node 810 378 '[ ]' 'DOCKER'
    Draw-Node 1038 378 '+ +' 'K8S / AKS'

    $coreBrush = New-Object Drawing.SolidBrush((Get-Color '#20301a'))
    $corePen = New-Object Drawing.Pen((Get-Color '#708d53'), [single]1)
    try {
        $graphics.FillEllipse($coreBrush, [single]900, [single]264, [single]126, [single]126)
        $graphics.DrawEllipse($corePen, [single]900, [single]264, [single]126, [single]126)
    } finally { $coreBrush.Dispose(); $corePen.Dispose() }

    $cloud = New-Object Drawing.Drawing2D.GraphicsPath
    $cloudPen = New-Object Drawing.Pen((Get-Color '#c7f58a'), [single]1.8)
    try {
        $cloud.AddBezier(943, 328, 926, 328, 927, 306, 943, 305)
        $cloud.AddBezier(943, 305, 946, 283, 979, 284, 981, 307)
        $cloud.AddBezier(981, 307, 1000, 306, 1002, 328, 982, 328)
        $cloud.AddLine(982, 328, 943, 328)
        $graphics.DrawPath($cloudPen, $cloud)
    } finally { $cloud.Dispose(); $cloudPen.Dispose() }
    Draw-TrackedText 'AZURE' 933 347 13 3.6 '#c7f58a'
    Draw-TrackedText 'PLAN > CODE > SHIP > IMPROVE' 820 466 8 0.8 '#8f9d81'

    Draw-Line 66 526 1134 526 '#30382d'
    $separator = '  ' + [char]0x00B7 + '  '
    Draw-Text ('AZURE' + $separator + 'TERRAFORM' + $separator + 'KUBERNETES' + $separator + 'CI/CD') 66 557 'Consolas' 17 Regular '#adb9a3'
    Draw-TrackedText 'DEVOPS / INDIA' 989 562 10 1.1 '#c7f58a'

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
