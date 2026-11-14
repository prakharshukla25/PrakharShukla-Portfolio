[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$HtmlPath,
    [string]$FeedPath,
    [string]$FeedUrl = 'https://www.prakharshukla.org/blog-feed.xml',
    [string]$MetadataPath
)

$ErrorActionPreference = 'Stop'
$invariant = [Globalization.CultureInfo]::InvariantCulture
$htmlFile = [IO.Path]::GetFullPath($HtmlPath)
$originalHtml = [IO.File]::ReadAllText($htmlFile)
$startMarker = '<!-- BLOG_POSTS_START -->'
$endMarker = '<!-- BLOG_POSTS_END -->'
if ([regex]::Matches($originalHtml, [regex]::Escape($startMarker)).Count -ne 1 -or
    [regex]::Matches($originalHtml, [regex]::Escape($endMarker)).Count -ne 1) {
    throw 'Blog sync requires exactly one BLOG_POSTS_START and BLOG_POSTS_END marker.'
}
$startIndex = $originalHtml.IndexOf($startMarker, [StringComparison]::Ordinal) + $startMarker.Length
$endIndex = $originalHtml.IndexOf($endMarker, [StringComparison]::Ordinal)
if ($endIndex -le $startIndex) { throw 'Blog markers must be in start/end order.' }

function Get-FeedText {
    if ($FeedPath) {
        $localFeed = [IO.Path]::GetFullPath($FeedPath)
        if ((Get-Item -LiteralPath $localFeed).Length -gt 2097152) { throw 'Blog feed exceeds the 2 MB limit.' }
        return [IO.File]::ReadAllText($localFeed)
    }
    $feedUri = $null
    if (-not [Uri]::TryCreate($FeedUrl, [UriKind]::Absolute, [ref]$feedUri) -or $feedUri.Scheme -ne 'https') {
        throw 'FeedUrl must be an absolute HTTPS URL.'
    }
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
    $handler.MaxAutomaticRedirections = 3
    $client = New-Object Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(20)
    $client.MaxResponseContentBufferSize = 2097152
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('PrakharPortfolioBlogSync/1.0')
    try {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try { return $client.GetStringAsync($feedUri).GetAwaiter().GetResult() }
            catch {
                if ($attempt -eq 3) { throw "Blog feed fetch failed after 3 attempts: $($_.Exception.Message)" }
                Start-Sleep -Seconds $attempt
            }
        }
    } finally { $client.Dispose(); $handler.Dispose() }
}

function Get-NodeText {
    param([Xml.XmlNode]$Node, [string]$XPath)
    $child = $Node.SelectSingleNode($XPath)
    if ($null -eq $child) { return '' }
    return [string]$child.InnerText
}

function ConvertTo-PlainText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $timeout = [TimeSpan]::FromSeconds(1)
    $options = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline
    $plain = [regex]::Replace($Value, '<(script|style|noscript)\b[^>]*>.*?</\1\s*>', ' ', $options, $timeout)
    $plain = [regex]::Replace($plain, '<!--.*?-->', ' ', $options, $timeout)
    $plain = [regex]::Replace($plain, '<[^>]*>', ' ', $options, $timeout)
    $plain = [Net.WebUtility]::HtmlDecode($plain)
    return ([regex]::Replace($plain, '\s+', ' ')).Trim()
}

function Get-Excerpt {
    param([string]$Text)
    if ($Text.Length -le 180) { return $Text }
    $short = $Text.Substring(0, 177).TrimEnd()
    $lastSpace = $short.LastIndexOf(' ')
    if ($lastSpace -ge 120) { $short = $short.Substring(0, $lastSpace) }
    return $short.TrimEnd(' ', '.', ',') + '...'
}

function Get-PostUrl {
    param([string]$Value)
    $uri = $null
    if (-not [Uri]::TryCreate($Value.Trim(), [UriKind]::Absolute, [ref]$uri)) { return $null }
    if ($uri.Scheme -ne 'https' -or $uri.Port -ne 443 -or $uri.UserInfo -or
        $uri.DnsSafeHost -notin @('www.prakharshukla.org', 'prakharshukla.org')) { return $null }
    $decodedPath = [Uri]::UnescapeDataString($uri.AbsolutePath)
    if ($decodedPath -notmatch '^/post/[^/]+/?$' -or $decodedPath -match '[\\\x00-\x20]' -or
        $decodedPath.TrimEnd('/') -eq '/post/..' -or $decodedPath.TrimEnd('/') -eq '/post/.') { return $null }
    # Canonicalize www/bare host aliases, query strings and fragments before deduplication.
    return 'https://www.prakharshukla.org' + $uri.AbsolutePath.TrimEnd('/')
}

$feedText = Get-FeedText
$settings = New-Object Xml.XmlReaderSettings
$settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$settings.MaxCharactersInDocument = 2097152
$settings.IgnoreComments = $true
$stringReader = New-Object IO.StringReader($feedText)
$xmlReader = [Xml.XmlReader]::Create($stringReader, $settings)
$document = New-Object Xml.XmlDocument
$document.XmlResolver = $null
try { $document.Load($xmlReader) }
finally { $xmlReader.Dispose(); $stringReader.Dispose() }
$items = $document.SelectNodes('/rss/channel/item')
$posts = New-Object 'System.Collections.Generic.List[object]'
foreach ($item in $items) {
    $title = [Net.WebUtility]::HtmlDecode((Get-NodeText $item 'title'))
    $title = ([regex]::Replace($title, '\s+', ' ')).Trim()
    $url = Get-PostUrl (Get-NodeText $item 'link')
    $published = [DateTimeOffset]::MinValue
    $dateText = Get-NodeText $item 'pubDate'
    $dateStyle = [Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [Globalization.DateTimeStyles]::AssumeUniversal
    if (-not $title -or -not $url -or
        -not [DateTimeOffset]::TryParse($dateText, $invariant, $dateStyle, [ref]$published)) { continue }
    $categoryValues = @($item.SelectNodes('category') | ForEach-Object {
        $value = [Net.WebUtility]::HtmlDecode([string]$_.InnerText)
        $value = ([regex]::Replace($value, '\s+', ' ')).Trim()
        if ($value) { $value }
    })
    $category = if ($categoryValues.Count) { $categoryValues -join ' / ' } else { 'Blog' }
    $description = ConvertTo-PlainText (Get-NodeText $item 'description')
    $body = ConvertTo-PlainText (Get-NodeText $item '*[local-name()="encoded" and namespace-uri()="http://purl.org/rss/1.0/modules/content/"]')
    if (-not $description) { $description = $body }
    if ([string]::Equals($description, $title, [StringComparison]::OrdinalIgnoreCase)) { $description = '' }
    # Wix often publishes only an excerpt. Estimate reading time only when the
    # feed actually supplies full article content, never from a short teaser.
    $minutes = $null
    if ($body) {
        $wordCount = [regex]::Matches($body, '\S+').Count
        $minutes = [int][Math]::Max(1, [Math]::Ceiling($wordCount / 200.0))
    }
    $posts.Add([pscustomobject]@{
        Title = $title; Url = $url; Published = $published; Category = $category
        Excerpt = Get-Excerpt $description; Minutes = $minutes
    })
}
$sorted = @($posts | Sort-Object -Property @{ Expression = { $_.Published.UtcDateTime.Ticks }; Descending = $true }, @{ Expression = { $_.Url }; Descending = $false })
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$latest = @($sorted | Where-Object { $seen.Add($_.Url) } | Select-Object -First 3)
if ($latest.Count -eq 0) { throw 'Blog feed contains no valid, dated HTTPS blog posts. Existing HTML was preserved.' }

$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('      <div class="blog-list" aria-label="Latest blog articles">')
for ($index = 0; $index -lt $latest.Count; $index++) {
    $post = $latest[$index]
    $title = [Net.WebUtility]::HtmlEncode($post.Title)
    $url = [Net.WebUtility]::HtmlEncode($post.Url)
    $category = [Net.WebUtility]::HtmlEncode($post.Category)
    $excerpt = [Net.WebUtility]::HtmlEncode($post.Excerpt)
    $excerptMarkup = if ($excerpt) { '<p>{0}</p>' -f $excerpt } else { '' }
    $readingMarkup = if ($null -ne $post.Minutes) { '<span>~{0} min read</span>' -f $post.Minutes } else { '' }
    $indiaDate = $post.Published.ToOffset([TimeSpan]::FromMinutes(330))
    $dateIso = $indiaDate.ToString("yyyy-MM-dd'T'HH:mm:sszzz", $invariant)
    $dateDisplay = $indiaDate.ToString('MMM d, yyyy', $invariant)
    $number = ($index + 1).ToString('00', $invariant)
    $lines.Add('        <article>')
    $lines.Add(('          <a class="blog-entry" href="{0}" target="_blank" rel="noopener noreferrer">' -f $url))
    $lines.Add(('            <span class="blog-index mono" aria-hidden="true">{0}</span>' -f $number))
    $lines.Add(('            <div class="blog-entry-copy"><div class="blog-meta"><span class="blog-topic">{0}</span><time datetime="{1}">{2}</time>{3}</div><h3>{4}</h3>{5}</div>' -f $category, $dateIso, $dateDisplay, $readingMarkup, $title, $excerptMarkup))
    $lines.Add('            <span class="blog-arrow" aria-hidden="true">&#8599;</span>')
    $lines.Add('          </a>')
    $lines.Add('        </article>')
}
$lines.Add('      </div>')
$newline = if ($originalHtml.Contains("`r`n")) { "`r`n" } else { "`n" }
$rendered = $originalHtml.Substring(0, $startIndex) + $newline + ($lines -join $newline) + $newline + '      ' + $originalHtml.Substring($endIndex)
$metadata = [ordered]@{
    feedUrl = $FeedUrl
    fetchedAtUtc = [DateTimeOffset]::UtcNow.ToString('o', $invariant)
    postCount = $latest.Count
    latestPublishedUtc = $latest[0].Published.ToUniversalTime().ToString('o', $invariant)
}

# Finish all parsing/rendering before changing either destination. Stage beside each
# destination so the final HTML replacement stays on the same filesystem.
$utf8 = New-Object Text.UTF8Encoding($false)
$htmlTemporary = $htmlFile + '.blogsync.' + [Guid]::NewGuid().ToString('N') + '.tmp'
$metadataTemporary = $null
try {
    [IO.File]::WriteAllText($htmlTemporary, $rendered, $utf8)
    if ($MetadataPath) {
        $metadataFile = [IO.Path]::GetFullPath($MetadataPath)
        if ($metadataFile -eq $htmlFile) { throw 'MetadataPath and HtmlPath must be different files.' }
        $metadataTemporary = $metadataFile + '.blogsync.' + [Guid]::NewGuid().ToString('N') + '.tmp'
        [IO.File]::WriteAllText($metadataTemporary, ($metadata | ConvertTo-Json), $utf8)
    }
    [IO.File]::Replace($htmlTemporary, $htmlFile, [System.Management.Automation.Language.NullString]::Value)
    if ($MetadataPath) {
        if ([IO.File]::Exists($metadataFile)) { [IO.File]::Replace($metadataTemporary, $metadataFile, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($metadataTemporary, $metadataFile) }
    }
} finally {
    foreach ($temporaryFile in @($htmlTemporary, $metadataTemporary)) {
        if ($temporaryFile -and [IO.File]::Exists($temporaryFile)) { [IO.File]::Delete($temporaryFile) }
    }
}
Write-Output ('Blog sync: rendered {0} latest articles; newest published {1}.' -f $latest.Count, $metadata.latestPublishedUtc)
