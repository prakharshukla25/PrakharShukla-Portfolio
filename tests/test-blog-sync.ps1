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
    param([string]$Name, [string]$Feed, [string]$Html, [string]$PinnedPostPath)
    $htmlPath = Join-Path $testRoot ($Name + '.html')
    $feedPath = Join-Path $testRoot ($Name + '.xml')
    $metadataPath = Join-Path $testRoot ($Name + '.json')
    [IO.File]::WriteAllText($htmlPath, $Html, $utf8)
    [IO.File]::WriteAllText($feedPath, $Feed, $utf8)
    [IO.File]::WriteAllText($metadataPath, 'preserve existing metadata', $utf8)
    $before = (Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256).Hash
    $failed = $false
    $parameters = @{ HtmlPath = $htmlPath; FeedPath = $feedPath; MetadataPath = $metadataPath }
    if ($PinnedPostPath) { $parameters.PinnedPostPath = $PinnedPostPath }
    try { & $syncScript @parameters | Out-Null }
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

    $pinPath = Join-Path $testRoot 'featured.json'
    function Invoke-PinnedCase {
        param([string]$FeedContent, [hashtable]$PinSettings)
        [IO.File]::WriteAllText($htmlPath, $template, $utf8)
        [IO.File]::WriteAllText($feedPath, $FeedContent, $utf8)
        [IO.File]::WriteAllText($pinPath, ($PinSettings | ConvertTo-Json), $utf8)
        & $syncScript -HtmlPath $htmlPath -FeedPath $feedPath -MetadataPath $metadataPath -PinnedPostPath $pinPath | Out-Null
        return [IO.File]::ReadAllText($htmlPath)
    }
    $pinSettings = @{
        url = 'https://prakharshukla.org/post/oldest?tracking=pin#google_vignette'
        title = 'Saved & <featured>'
        publishedAt = '2021-03-03T12:09:44Z'
        category = 'My thought'
        excerpt = 'Saved personal reflection & clear examples.'
    }
    $pinnedHtml = Invoke-PinnedCase $fixture $pinSettings
    $pinnedLinks = [regex]::Matches($pinnedHtml, 'class="blog-entry" href="([^"]+)"')
    Assert-Test ($pinnedLinks.Count -eq 3 -and $pinnedLinks[0].Groups[1].Value.EndsWith('/post/newest') -and $pinnedLinks[1].Groups[1].Value.EndsWith('/post/second') -and $pinnedLinks[2].Groups[1].Value.EndsWith('/post/oldest')) 'Show two newest posts followed by the older pinned article.'
    Assert-Test ([regex]::Matches($pinnedHtml, '/post/oldest').Count -eq 1) 'Show the pinned article only once.'
    Assert-Test ($pinnedHtml -notmatch 'google_vignette|tracking=pin') 'Remove tracking fragments and query strings from the pinned URL.'
    Assert-Test ($pinnedHtml.Contains('<h3>Oldest post</h3>') -and $pinnedHtml -notmatch 'Saved &amp;') 'Prefer current RSS details when the pinned article is in the feed.'
    Assert-Test ([regex]::Matches($pinnedHtml, 'class="blog-featured"').Count -eq 1) 'Mark exactly one article as featured.'

    $pinSettings.url = 'https://www.prakharshukla.org/post/not-in-feed'
    $pinnedHtml = Invoke-PinnedCase $fixture $pinSettings
    $pinnedLinks = [regex]::Matches($pinnedHtml, 'class="blog-entry" href="([^"]+)"')
    Assert-Test ($pinnedLinks.Count -eq 3 -and $pinnedLinks[2].Groups[1].Value.EndsWith('/post/not-in-feed')) 'Keep the pinned third slot when its article leaves the RSS window.'
    Assert-Test ($pinnedHtml.Contains('<h3>Saved &amp; &lt;featured&gt;</h3>')) 'Escape the saved fallback title.'
    Assert-Test ($pinnedHtml.Contains('Saved personal reflection &amp; clear examples.')) 'Use the saved fallback excerpt safely.'
    Assert-Test ($pinnedHtml.Contains('2021-03-03T17:39:44+05:30')) 'Convert the saved fallback publication time to India time.'
    $pinMetadata = [IO.File]::ReadAllText($metadataPath) | ConvertFrom-Json
    Assert-Test ($pinMetadata.pinnedPostUrl -eq $pinSettings.url) 'Record the featured article in deployment metadata.'

    $pinSettings.url = 'https://www.prakharshukla.org/post/newest'
    $pinnedHtml = Invoke-PinnedCase $fixture $pinSettings
    $pinnedLinks = [regex]::Matches($pinnedHtml, 'class="blog-entry" href="([^"]+)"')
    Assert-Test ($pinnedLinks.Count -eq 3 -and $pinnedLinks[0].Groups[1].Value.EndsWith('/post/second') -and $pinnedLinks[1].Groups[1].Value.EndsWith('/post/india-date') -and $pinnedLinks[2].Groups[1].Value.EndsWith('/post/newest')) 'Exclude a recent pinned article from the automatic slots and append it once.'
    Assert-Test ([regex]::Matches($pinnedHtml, '/post/newest').Count -eq 1) 'A newest-post pin must not create a duplicate.'
    $pinMetadata = [IO.File]::ReadAllText($metadataPath) | ConvertFrom-Json
    Assert-PublishedInstant $pinMetadata.latestPublishedUtc

    $pinSettings.url = 'https://www.prakharshukla.org/post/not-in-feed'
    $pinnedHtml = Invoke-PinnedCase $singleFeed $pinSettings
    Assert-Test ([regex]::Matches($pinnedHtml, '<article>').Count -eq 2) 'A small feed can show one recent article and the featured article.'
    $pinSettings.url = 'https://www.prakharshukla.org/post/only-one'
    $pinnedHtml = Invoke-PinnedCase $singleFeed $pinSettings
    Assert-Test ([regex]::Matches($pinnedHtml, '<article>').Count -eq 1) 'A feed containing only the featured post must show it once.'

    $pinSettings.url = 'https://evil.example/post/fake'
    [IO.File]::WriteAllText($pinPath, ($pinSettings | ConvertTo-Json), $utf8)
    Assert-PreservedOnFailure 'invalid-pin-url' $fixture $template $pinPath
    $pinSettings.url = 'https://www.prakharshukla.org/post/not-in-feed'
    $pinSettings.publishedAt = 'not-a-date'
    [IO.File]::WriteAllText($pinPath, ($pinSettings | ConvertTo-Json), $utf8)
    Assert-PreservedOnFailure 'invalid-pin-date' $fixture $template $pinPath

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
