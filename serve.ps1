# 9ja Transport — local static server (no installs; uses built-in .NET HttpListener).
# Run: powershell -ExecutionPolicy Bypass -File serve.ps1
# Then open: http://localhost:8080/trip-search.html
$port = 8080
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Output "Serving $root on http://localhost:$port/ (Ctrl+C to stop)"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = $ctx.Request.Url.LocalPath.TrimStart("/")
  if ([string]::IsNullOrEmpty($path)) { $path = "trip-search.html" }
  $file = Join-Path $root $path
  if ((Test-Path $file -PathType Leaf)) {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $ext = [System.IO.Path]::GetExtension($file).ToLower()
    $type = "text/html"
    if ($ext -eq ".css") { $type = "text/css" }
    elseif ($ext -eq ".js") { $type = "application/javascript" }
    $ctx.Response.ContentType = "$type; charset=utf-8"
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else {
    $ctx.Response.StatusCode = 404
    $msg = [System.Text.Encoding]::UTF8.GetBytes("Not found")
    $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
  }
  $ctx.Response.Close()
}
