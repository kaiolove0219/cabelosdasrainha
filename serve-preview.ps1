param(
  [string]$Root = $PSScriptRoot,
  [int]$Port = 4173,
  [switch]$OpenBrowser
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Get-Location).Path
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)

if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
  throw "Directory not found: $resolvedRoot"
}

$mimeTypes = @{
  ".avif"  = "image/avif"
  ".css"   = "text/css; charset=utf-8"
  ".gif"   = "image/gif"
  ".htm"   = "text/html; charset=utf-8"
  ".html"  = "text/html; charset=utf-8"
  ".ico"   = "image/x-icon"
  ".jpeg"  = "image/jpeg"
  ".jpg"   = "image/jpeg"
  ".js"    = "application/javascript; charset=utf-8"
  ".json"  = "application/json; charset=utf-8"
  ".map"   = "application/json; charset=utf-8"
  ".png"   = "image/png"
  ".svg"   = "image/svg+xml"
  ".txt"   = "text/plain; charset=utf-8"
  ".webp"  = "image/webp"
  ".woff"  = "font/woff"
  ".woff2" = "font/woff2"
}

function Get-ContentType {
  param(
    [string]$Path
  )

  $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($mimeTypes.ContainsKey($extension)) {
    return $mimeTypes[$extension]
  }

  return "application/octet-stream"
}

function Write-HttpResponse {
  param(
    [System.IO.Stream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [byte[]]$BodyBytes,
    [string]$ContentType,
    [bool]$HeadOnly
  )

  if ($null -eq $BodyBytes) {
    $BodyBytes = [byte[]]::new(0)
  }

  if ([string]::IsNullOrWhiteSpace($ContentType)) {
    $ContentType = "text/plain; charset=utf-8"
  }

  $headerLines = @(
    "HTTP/1.1 $StatusCode $StatusText"
    "Content-Type: $ContentType"
    "Content-Length: $($BodyBytes.Length)"
    "Cache-Control: no-store"
    "Connection: close"
    ""
    ""
  )

  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes(($headerLines -join "`r`n"))
  $Stream.Write($headerBytes, 0, $headerBytes.Length)

  if (-not $HeadOnly -and $BodyBytes.Length -gt 0) {
    $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
  }
}

function Write-TextResponse {
  param(
    [System.IO.Stream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [string]$Body,
    [bool]$HeadOnly
  )

  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
  Write-HttpResponse -Stream $Stream -StatusCode $StatusCode -StatusText $StatusText -BodyBytes $bodyBytes -ContentType "text/plain; charset=utf-8" -HeadOnly $HeadOnly
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)

try {
  $listener.Start()
  $homeUrl = "http://127.0.0.1:$Port/"

  Write-Host "Preview server running from $resolvedRoot"
  Write-Host "Open $homeUrl"

  if ($OpenBrowser) {
    Start-Process $homeUrl
  }

  while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $null
    $reader = $null

    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()

      if ([string]::IsNullOrWhiteSpace($requestLine)) {
        continue
      }

      $requestParts = $requestLine.Split(" ")
      $method = if ($requestParts.Length -ge 1) { $requestParts[0].ToUpperInvariant() } else { "" }
      $target = if ($requestParts.Length -ge 2) { $requestParts[1] } else { "/" }
      $headOnly = $method -eq "HEAD"

      while ($true) {
        $headerLine = $reader.ReadLine()
        if ($null -eq $headerLine -or $headerLine -eq "") {
          break
        }
      }

      if ($method -notin @("GET", "HEAD")) {
        Write-TextResponse -Stream $stream -StatusCode 405 -StatusText "Method Not Allowed" -Body "Method Not Allowed" -HeadOnly $headOnly
        continue
      }

      $pathOnly = $target.Split("?")[0]
      $rawPath = [System.Uri]::UnescapeDataString($pathOnly)
      if ([string]::IsNullOrWhiteSpace($rawPath) -or $rawPath -eq "/") {
        $rawPath = "/index.html"
      }

      $relativePath = $rawPath.TrimStart("/").Replace("/", "\")
      $targetPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))

      if (-not $targetPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-TextResponse -Stream $stream -StatusCode 403 -StatusText "Forbidden" -Body "Forbidden" -HeadOnly $headOnly
        continue
      }

      if ((Test-Path -LiteralPath $targetPath) -and (Get-Item -LiteralPath $targetPath).PSIsContainer) {
        $targetPath = Join-Path $targetPath "index.html"
      }

      if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        Write-TextResponse -Stream $stream -StatusCode 404 -StatusText "Not Found" -Body "Not Found" -HeadOnly $headOnly
        continue
      }

      $bytes = [System.IO.File]::ReadAllBytes($targetPath)
      $contentType = Get-ContentType -Path $targetPath
      Write-HttpResponse -Stream $stream -StatusCode 200 -StatusText "OK" -BodyBytes $bytes -ContentType $contentType -HeadOnly $headOnly
      Write-Host ("[{0}] {1}" -f $method, $rawPath)
    } catch {
      if ($client.Connected) {
        try {
          Write-TextResponse -Stream $stream -StatusCode 500 -StatusText "Internal Server Error" -Body "Internal Server Error" -HeadOnly $false
        } catch {
        }
      }
    } finally {
      if ($reader) {
        $reader.Dispose()
      }

      if ($stream) {
        $stream.Dispose()
      }

      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
