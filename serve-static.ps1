param(
  [string]$Root = (Get-Location).Path,
  [int]$Port = 8123
)

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Prefixes.Add("http://localhost:$Port/")

$mimeTypes = @{
  ".css"  = "text/css; charset=utf-8"
  ".gif"  = "image/gif"
  ".htm"  = "text/html; charset=utf-8"
  ".html" = "text/html; charset=utf-8"
  ".ico"  = "image/x-icon"
  ".jpeg" = "image/jpeg"
  ".jpg"  = "image/jpeg"
  ".js"   = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".png"  = "image/png"
  ".svg"  = "image/svg+xml"
  ".txt"  = "text/plain; charset=utf-8"
  ".webp" = "image/webp"
  ".woff" = "font/woff"
  ".woff2" = "font/woff2"
}

function Send-TextResponse {
  param(
    [System.Net.HttpListenerContext]$Context,
    [int]$StatusCode,
    [string]$Body
  )

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
  $Context.Response.StatusCode = $StatusCode
  $Context.Response.ContentType = "text/plain; charset=utf-8"
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.OutputStream.Close()
}

try {
  $listener.Start()
  Write-Host "Serving $resolvedRoot at http://127.0.0.1:$Port/"

  while ($listener.IsListening) {
    $context = $listener.GetContext()

    try {
      $rawPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
      if ([string]::IsNullOrWhiteSpace($rawPath) -or $rawPath -eq "/") {
        $rawPath = "/index.html"
      }

      $relativePath = $rawPath.TrimStart("/").Replace("/", "\")
      $targetPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))

      if (-not $targetPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Send-TextResponse -Context $context -StatusCode 403 -Body "Forbidden"
        continue
      }

      if ((Test-Path -LiteralPath $targetPath) -and (Get-Item -LiteralPath $targetPath).PSIsContainer) {
        $targetPath = Join-Path $targetPath "index.html"
      }

      if (-not (Test-Path -LiteralPath $targetPath)) {
        Send-TextResponse -Context $context -StatusCode 404 -Body "Not Found"
        continue
      }

      $extension = [System.IO.Path]::GetExtension($targetPath).ToLowerInvariant()
      $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($targetPath)

      $context.Response.StatusCode = 200
      $context.Response.ContentType = $contentType
      $context.Response.ContentLength64 = $bytes.Length
      if ($context.Request.HttpMethod -ne "HEAD") {
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      }
      $context.Response.OutputStream.Close()
    } catch {
      try {
        Send-TextResponse -Context $context -StatusCode 500 -Body "Internal Server Error"
      } catch {
      }
    }
  }
} finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }
  $listener.Close()
}
