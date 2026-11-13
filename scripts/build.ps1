[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
& (Join-Path $PSScriptRoot 'validate.ps1')
$outputPath = [IO.Path]::GetFullPath((Join-Path $projectRoot '_site'))
# Only this fixed, project-local output directory may be replaced.
if ($outputPath -ne (Join-Path $projectRoot '_site') -or -not $outputPath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) {
    throw 'Build output must stay inside this project.'
}
if (Test-Path -LiteralPath $outputPath) {
    $existing = Get-Item -LiteralPath $outputPath -Force
    if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Build output cannot be a symbolic link.' }
    foreach ($item in Get-ChildItem -LiteralPath $outputPath -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Build output contains a symbolic link.' }
    }
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $outputPath | Out-Null
foreach ($relative in @('index.html', 'styles.css', 'script.js', 'assets')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $outputPath -Recurse
}
foreach ($relative in @('404.html', 'robots.txt', 'CNAME')) {
    $source = Join-Path $projectRoot $relative
    if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination $outputPath }
}
[IO.File]::WriteAllText((Join-Path $outputPath '.nojekyll'), '')
$commit = if ($env:SOURCE_COMMIT) { $env:SOURCE_COMMIT } else { 'local-preview' }
$metadata = [ordered]@{ sourceCommit = $commit; builtAtUtc = [DateTime]::UtcNow.ToString('o'); generator = 'static-portfolio' }
[IO.File]::WriteAllText((Join-Path $outputPath 'deployment.json'), ($metadata | ConvertTo-Json))
$hashLines = foreach ($file in Get-ChildItem -LiteralPath $outputPath -File -Recurse | Sort-Object FullName) {
    $relative = $file.FullName.Substring($outputPath.Length + 1).Replace('\', '/')
    '{0}  {1}' -f (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
}
[IO.File]::WriteAllLines((Join-Path $outputPath 'SHA256SUMS'), [string[]]$hashLines)
Write-Host "Built _site/ with deployment metadata and SHA-256 asset manifest." -ForegroundColor Green
