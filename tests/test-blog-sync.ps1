[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$syncScript = Join-Path $projectRoot 'scripts/sync-blog.ps1'
$fixturePath = Join-Path $PSScriptRoot 'fixtures/blog-feed.xml'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempRoot ('portfolio-blog-tests-' + [Guid]::NewGuid().ToString('N'))))
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = 0

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}

function Assert-PublishedInstant {
    param([object]$Value)
    # Windows PowerShell preserves JSON timestamps as strings; newer PowerShell
    # can return DateTime values. Compare the instant rather than string methods.
    $expected = [DateTimeOffset]::Parse('2026-11-14T05:33:53Z', [Globalization.CultureInfo]::InvariantCulture)
    $actual = if ($Value -is [string]) {
        [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture)
    } else {
        [DateTimeOffset]$Value
    }
    Assert-Test ($actual.UtcDateTime.Ticks -eq $expected.UtcDateTime.Ticks) 'Metadata must record the newest UTC publication across JSON date representations.'
}

function Assert-PreservedOnFailure {
    param([string]$Name, [string]$Feed, [string]$Html)
    $htmlPath = Join-Path $testRoot ($Name + '.html')
    $feedPath = Join-Path $testRoot ($Name + '.xml')
    $metadataPath = Join-Path $testRoot ($Name + '.json')
    [IO.File]::WriteAllText($htmlPath, $Html, $utf8)
    [IO.File]::WriteAllText($feedPath, $Feed, $utf8)
    [IO.File]::WriteAllText($metadataPath, 'preserve existing metadata', $utf8)
    $before = (Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256).Hash
    $failed = $false
    try { & $syncScript -HtmlPath $htmlPath -FeedPath $feedPath -MetadataPath $metadataPath | Out-Null }
    catch { $failed = $true }
    Assert-Test $failed "$Name must fail."
    Assert-Test ((Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256).Hash -eq $before) "$Name must preserve HTML byte-for-byte."
    Assert-Test ([IO.File]::ReadAllText($metadataPath) -eq 'preserve existing metadata') "$Name must preserve metadata."
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $start = '<!-- BLOG_POSTS_START -->'
    $end = '<!-- BLOG_POSTS_END -->'
    $prefix = '<!doctype html><html><body><h1>Keep &amp; preserve this header</h1>' + "`r`n  " + $start
    $suffix = $end + "`r`n<footer data-keep='unchanged'>Keep this footer</footer></body></html>"
    $template = $prefix + "`r`n<div>Old content</div>`r`n" + $suffix
    $htmlPath = Join-Path $testRoot 'portfolio.html'
    $feedPath = Join-Path $testRoot 'feed.xml'
    $metadataPath = Join-Path $testRoot 'blog.json'
    $fixture = [IO.File]::ReadAllText($fixturePath)
    # Long article text verifies both content:encoded reading estimates and excerpt truncation.
    $fixture = $fixture.Replace('CONTENT_WORDS', ((1..401 | ForEach-Object { 'word' }) -join ' '))
    $fixture = $fixture.Replace('DESCRIPTION_WORDS', ((1..80 | ForEach-Object { 'description' }) -join ' '))
    [IO.File]::WriteAllText($htmlPath, $template, $utf8)
    [IO.File]::WriteAllText($feedPath, $fixture, $utf8)
    & $syncScript -HtmlPath $htmlPath -FeedPath $feedPath -MetadataPath $metadataPath | Out-Null
    $rendered = [IO.File]::ReadAllText($htmlPath)
    Assert-Test ($rendered.StartsWith($prefix, [StringComparison]::Ordinal)) 'Everything before the start marker must remain unchanged.'
    Assert-Test ($rendered.EndsWith($suffix, [StringComparison]::Ordinal)) 'Everything after the end marker must remain unchanged.'
    Assert-Test ([regex]::Matches($rendered, '<article>').Count -eq 3) 'Render only the latest three valid unique posts.'
    Assert-Test ($rendered.IndexOf('/post/newest') -lt $rendered.IndexOf('/post/second') -and $rendered.IndexOf('/post/second') -lt $rendered.IndexOf('/post/india-date')) 'Order posts by actual publication time descending.'
    Assert-Test ([regex]::Matches($rendered, '/post/newest').Count -eq 1) 'Deduplicate www/bare-host aliases and tracking URLs.'
    Assert-Test ($rendered -notmatch 'Duplicate stale|Unsafe scheme|Foreign domain|userinfo trick|Wrong path|HTTP link|Broken date|Oldest post') 'Exclude stale duplicates, unsafe URLs, bad dates, and older fourth posts.'
    Assert-Test ($rendered.Contains('Newest &lt;script&gt; &amp; &quot;quoted&quot; title')) 'HTML-escape feed titles.'
    Assert-Test ($rendered.Contains('Technical &amp; &lt;cloud&gt;')) 'Use and escape real RSS categories.'
    Assert-Test ($rendered.Contains('A useful shell guide &amp; practical examples.')) 'Strip description formatting and escape text.'
    Assert-Test ($rendered -notmatch 'neverImportThis|noImportedComment|<script>') 'Never import feed scripts or comments.'
    Assert-Test ($rendered.Contains('<time datetime="2025-06-28T00:00:00+05:30">Jun 28, 2025</time>')) 'Convert dates to India time before formatting the day.'
    Assert-Test ($rendered.Contains('<time datetime="2026-11-14T11:03:53+05:30">Nov 14, 2026</time>')) 'Preserve the publication instant with the India offset.'
    Assert-Test ($rendered.Contains('~3 min read')) 'Estimate reading time from content:encoded rather than short description.'
    Assert-Test ([regex]::Matches($rendered, 'min read').Count -eq 1) 'Omit reading time when only a feed excerpt is available.'
    $excerpts = [regex]::Matches($rendered, '<p>(.*?)</p>')
    foreach ($excerpt in $excerpts) { Assert-Test ($excerpt.Groups[1].Value.Length -le 190) 'Excerpts must be bounded.' }
    Assert-Test ($rendered.Contains('description description...')) 'Long excerpts must truncate on a word boundary.'
    $metadata = [IO.File]::ReadAllText($metadataPath) | ConvertFrom-Json
    Assert-Test ($metadata.postCount -eq 3) 'Metadata must record rendered post count.'
    Assert-PublishedInstant $metadata.latestPublishedUtc
    # Exercise both runtime representations even when running locally on 5.1,
    # plus an equivalent offset timestamp to verify UTC normalization.
    Assert-PublishedInstant '2026-11-14T05:33:53.0000000+00:00'
    $utcTimestamp = [DateTime]::SpecifyKind((New-Object DateTime(2026, 11, 14, 5, 33, 53)), [DateTimeKind]::Utc)
    Assert-PublishedInstant $utcTimestamp
    Assert-PublishedInstant ($utcTimestamp.ToLocalTime())
    Assert-PublishedInstant ([DateTimeOffset]::Parse('2026-11-14T11:03:53+05:30', [Globalization.CultureInfo]::InvariantCulture))

    $singleFeed = '<rss><channel><item><title><![CDATA[One CDATA post]]></title><link>https://prakharshukla.org/post/only-one</link><pubDate>Sat, 14 Nov 2026 05:33:53 GMT</pubDate><description><![CDATA[One post is enough.]]></description></item></channel></rss>'
    $singlePath = Join-Path $testRoot 'single.xml'
    [IO.File]::WriteAllText($singlePath, $singleFeed, $utf8)
    [IO.File]::WriteAllText($htmlPath, $template, $utf8)
    & $syncScript -HtmlPath $htmlPath -FeedPath $singlePath | Out-Null
    $singleRendered = [IO.File]::ReadAllText($htmlPath)
    Assert-Test ([regex]::Matches($singleRendered, '<article>').Count -eq 1) 'A feed with only one valid article must work.'
    Assert-Test ($singleRendered.Contains('https://www.prakharshukla.org/post/only-one')) 'Normalize the bare blog hostname.'
    Assert-Test ($singleRendered.Contains('>01</span>')) 'Use two-digit article numbering.'
    Assert-Test ($singleRendered -notmatch 'min read') 'A description-only feed cannot estimate full article reading time.'

    $duplicateDescription = $singleFeed.Replace('One post is enough.', 'One CDATA post')
    [IO.File]::WriteAllText($singlePath, $duplicateDescription, $utf8)
    & $syncScript -HtmlPath $htmlPath -FeedPath $singlePath | Out-Null
    Assert-Test ([IO.File]::ReadAllText($htmlPath) -notmatch '<p>') 'Omit a description that merely repeats the title.'

    $shortFullBody = $singleFeed.Replace('<rss>', '<rss xmlns:content="http://purl.org/rss/1.0/modules/content/">').Replace('</item>', '<content:encoded><![CDATA[<p>Short complete article.</p>]]></content:encoded></item>')
    [IO.File]::WriteAllText($singlePath, $shortFullBody, $utf8)
    & $syncScript -HtmlPath $htmlPath -FeedPath $singlePath | Out-Null
    Assert-Test ([IO.File]::ReadAllText($htmlPath).Contains('~1 min read')) 'Full article reading time must be at least one minute.'

    Assert-PreservedOnFailure 'malformed' '<rss><channel><item></rss>' $template
    Assert-PreservedOnFailure 'empty' '<rss><channel /></rss>' $template
    Assert-PreservedOnFailure 'invalid-only' '<rss><channel><item><title>Unsafe</title><link>javascript:alert(1)</link><pubDate>bad</pubDate></item></channel></rss>' $template
    Assert-PreservedOnFailure 'missing-markers' $singleFeed '<html><body>Keep me unchanged</body></html>'
    Assert-PreservedOnFailure 'reversed-markers' $singleFeed ($end + ' unchanged ' + $start)
    Assert-PreservedOnFailure 'duplicate-markers' $singleFeed ($template + $start)
    Assert-PreservedOnFailure 'external-entity' '<!DOCTYPE rss [<!ENTITY ext SYSTEM "file:///not-readable">]><rss><channel><item><title>&ext;</title></item></channel></rss>' $template
    Write-Output "PASS: $checks offline blog sync checks."
} finally {
    # Resolve and verify the exact, task-created directory before recursive cleanup.
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $testRoot).Path)
        $boundary = $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if ($resolved -ne $testRoot -or -not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolved) -notlike 'portfolio-blog-tests-*') { throw 'Unsafe test cleanup path.' }
        if ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test cleanup target cannot be a symbolic link.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
