[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
$mimeTypes = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.svg'='image/svg+xml'; '.pdf'='application/pdf'; '.png'='image/png'; '.jpg'='image/jpeg'; '.webp'='image/webp'; '.woff2'='font/woff2' }
$listener.Start()
Write-Host "Portfolio preview: http://localhost:$Port/ (Ctrl+C to stop)" -ForegroundColor Green
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()
            $headerSize = 0
            while ($null -ne ($header = $reader.ReadLine()) -and $header -ne '') {
                $headerSize += $header.Length
                if ($headerSize -gt 16384) { throw 'Request headers too large.' }
            }
            $parts = $requestLine -split ' '
            $method = $parts[0]
            $urlPath = [Uri]::UnescapeDataString(($parts[1] -split '\?', 2)[0])
            if ($urlPath -eq '/') { $urlPath = '/index.html' }
            $allowed = $urlPath -match '^/(?:index\.html|styles\.css|script\.js|assets/[a-zA-Z0-9_./-]+)$'
            $target = [IO.Path]::GetFullPath((Join-Path $projectRoot $urlPath.TrimStart('/')))
            $allowed = $allowed -and $target.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar) -and $urlPath -notmatch '(?:^|/)\.\.(?:/|$)'
            $status = '200 OK'
            $contentType = 'text/plain; charset=utf-8'
            if ($method -notin @('GET','HEAD')) {
                $status = '405 Method Not Allowed'
                $body = [Text.Encoding]::UTF8.GetBytes('Method not allowed')
            } elseif (-not $allowed -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $status = '404 Not Found'
                $body = [Text.Encoding]::UTF8.GetBytes('Not found')
            } else {
                $body = [IO.File]::ReadAllBytes($target)
                $extension = [IO.Path]::GetExtension($target).ToLowerInvariant()
                if ($mimeTypes.ContainsKey($extension)) { $contentType = $mimeTypes[$extension] }
            }
            $headers = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
            $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            if ($method -ne 'HEAD') { $stream.Write($body, 0, $body.Length) }
            $stream.Flush()
        } catch {
            Write-Verbose $_.Exception.Message
        } finally {
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
