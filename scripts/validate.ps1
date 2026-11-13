[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = New-Object 'System.Collections.Generic.List[string]'

function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

$requiredFiles = @('index.html', 'styles.css', 'script.js', 'assets/resume.pdf', 'assets/favicon.svg', 'assets/social-card.png')
foreach ($relative in $requiredFiles) {
    $target = Join-Path $projectRoot $relative
    Assert-Check (Test-Path -LiteralPath $target -PathType Leaf) "Missing required file: $relative"
}
if ($failures.Count -gt 0) { throw ($failures -join "`n") }

$html = [IO.File]::ReadAllText((Join-Path $projectRoot 'index.html'))
Assert-Check ($html -match '(?i)<!doctype\s+html>') 'HTML5 doctype is required.'
Assert-Check ($html -match '(?i)<html\b[^>]*\blang=["''][^"'']+["'']') 'Set a document language.'
Assert-Check ($html -match '(?is)<title>\s*[^<\s].*?</title>') 'Set a descriptive page title.'
Assert-Check ($html -match '(?i)<meta\b[^>]*name=["'']viewport["'']') 'Set the responsive viewport metadata.'
Assert-Check ($html -match '(?i)<meta\b[^>]*name=["'']description["'']') 'Set the search description metadata.'
Assert-Check ([regex]::Matches($html, '(?i)<h1(?:\s|>)').Count -eq 1) 'Use exactly one primary heading.'

# Social crawlers read the initial HTML without running the site's JavaScript.
$openGraph = @{}
foreach ($match in [regex]::Matches($html, '(?is)<meta\b[^>]*>')) {
    $property = [regex]::Match($match.Value, '(?i)\bproperty\s*=\s*["'']([^"'']+)["'']')
    $content = [regex]::Match($match.Value, '(?i)\bcontent\s*=\s*["'']([^"'']*)["'']')
    if ($property.Success -and $content.Success) { $openGraph[$property.Groups[1].Value] = $content.Groups[1].Value }
}
foreach ($property in @('og:title', 'og:description', 'og:url', 'og:image')) {
    Assert-Check (-not [string]::IsNullOrWhiteSpace($openGraph[$property])) "Missing social preview metadata: $property"
}
$imageUri = $null
$hasImageUri = [Uri]::TryCreate($openGraph['og:image'], [UriKind]::Absolute, [ref]$imageUri)
Assert-Check ($hasImageUri -and $imageUri.Scheme -eq 'https') 'Social preview image must use an absolute HTTPS URL.'

$preview = [IO.File]::ReadAllBytes((Join-Path $projectRoot 'assets/social-card.png'))
$isPng = $preview.Length -ge 24 -and [BitConverter]::ToString($preview, 0, 8) -eq '89-50-4E-47-0D-0A-1A-0A'
Assert-Check $isPng 'Social preview must be a real PNG.'
Assert-Check ($preview.Length -lt 5MB) 'Social preview image must stay below 5 MB.'
if ($isPng) {
    # IHDR stores dimensions as unsigned big-endian integers; no imaging library is needed in CI.
    $width = [uint64]$preview[16] * 16777216 + [uint64]$preview[17] * 65536 + [uint64]$preview[18] * 256 + $preview[19]
    $height = [uint64]$preview[20] * 16777216 + [uint64]$preview[21] * 65536 + [uint64]$preview[22] * 256 + $preview[23]
    Assert-Check ($width -ge 1200 -and $height -ge 627) 'Social preview needs at least 1200 x 627 pixels.'
    Assert-Check ($openGraph['og:image:width'] -eq [string]$width -and $openGraph['og:image:height'] -eq [string]$height) 'Social preview metadata must match the PNG dimensions.'
}

$ids = @{}
foreach ($match in [regex]::Matches($html, '\bid\s*=\s*["'']([^"'']+)["'']')) {
    $id = $match.Groups[1].Value
    Assert-Check (-not $ids.ContainsKey($id)) "Duplicate HTML ID: $id"
    $ids[$id] = $true
}

foreach ($match in [regex]::Matches($html, '(?i)\b(?:href|src)\s*=\s*["'']([^"'']*)["'']')) {
    $link = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    Assert-Check (-not [string]::IsNullOrWhiteSpace($link)) 'Empty href/src attribute.'
    if ([string]::IsNullOrWhiteSpace($link)) { continue }
    if ($link -match '^(?:https?:|mailto:|tel:|data:)') { continue }
    if ($link.StartsWith('#')) {
        $anchor = [Uri]::UnescapeDataString($link.Substring(1))
        Assert-Check ($anchor.Length -gt 0 -and $ids.ContainsKey($anchor)) "Broken internal anchor: $link"
        continue
    }
    Assert-Check (-not $link.StartsWith('/')) "Use relative paths for GitHub project Pages: $link"
    Assert-Check ($link -notmatch '^[a-z][a-z0-9+.-]*:') "Unsupported URL scheme: $link"
    $relative = [Uri]::UnescapeDataString(($link -split '[?#]', 2)[0])
    $target = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    Assert-Check ($target.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) "Link escapes project: $link"
    Assert-Check (Test-Path -LiteralPath $target -PathType Leaf) "Missing linked file: $link"
}

foreach ($match in [regex]::Matches($html, '(?is)<img\b[^>]*>')) {
    Assert-Check ($match.Value -match '(?i)\balt\s*=') 'Every image needs an alt attribute (empty for decoration).'
}
foreach ($match in [regex]::Matches($html, '(?is)<a\b[^>]*target=["'']_blank["''][^>]*>')) {
    Assert-Check ($match.Value -match '(?i)\brel=["''][^"'']*noopener') 'External new-tab links need rel="noopener".'
}

$pdf = [IO.File]::ReadAllBytes((Join-Path $projectRoot 'assets/resume.pdf'))
Assert-Check ($pdf.Length -gt 100 -and [Text.Encoding]::ASCII.GetString($pdf, 0, 5) -eq '%PDF-') 'Resume must be a real PDF.'
$css = [IO.File]::ReadAllText((Join-Path $projectRoot 'styles.css'))
Assert-Check ($css -match 'prefers-reduced-motion') 'Styles must respect reduced-motion preferences.'
foreach ($match in [regex]::Matches($css, 'url\(\s*["'']?([^"'')\s]+)')) {
    $link = $match.Groups[1].Value
    if ($link -match '^(?:https?:|data:|#)') { continue }
    $relative = ($link -split '[?#]', 2)[0]
    Assert-Check (Test-Path -LiteralPath (Join-Path $projectRoot $relative) -PathType Leaf) "Missing CSS asset: $link"
}

$assetsPath = Join-Path $projectRoot 'assets'
foreach ($item in Get-ChildItem -LiteralPath $assetsPath -Recurse -Force) {
    Assert-Check (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Symbolic links are not allowed in assets: $($item.Name)"
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL: $failure" -ForegroundColor Red }
    throw "Portfolio validation failed ($($failures.Count) checks)."
}
Write-Host "PASS: page metadata, social preview image, headings, unique IDs, local links, resume, assets, and accessibility basics." -ForegroundColor Green
