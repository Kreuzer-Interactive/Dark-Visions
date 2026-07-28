# serve.ps1 - tiny local server for the Dark Visions hit-area web editor.
# Serves haedit.html and reads/writes the .PIC/.PAC files in ..\.. (the src folder),
# so "Save" in the browser writes straight back to disk.  No dependencies.
#
#   powershell -ExecutionPolicy Bypass -File serve.ps1      (or just double-click run.bat)
#
param([int]$Port = 8745)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$data = (Resolve-Path (Join-Path $root '..\..')).Path

# Bind the first free port at/after $Port (Windows can dynamically reserve ports).
$listener = $null
foreach ($p in $Port..($Port + 25)) {
  try {
    $try = New-Object System.Net.HttpListener
    $try.Prefixes.Add("http://localhost:$p/")
    $try.Start()
    $listener = $try; $port = $p; break
  } catch { }
}
if ($null -eq $listener) {
  Write-Host ("Could not bind a port in {0}..{1}." -f $Port, ($Port + 25)) -ForegroundColor Red
  Write-Host "Try another range:  powershell -ExecutionPolicy Bypass -File serve.ps1 -Port 9100"
  Write-Host "Or just double-click haedit.html to use file mode."
  exit 1
}
$prefix = "http://localhost:$port/"

Write-Host ""
Write-Host "  Dark Visions - hit-area editor" -ForegroundColor Cyan
Write-Host "  data folder : $data"
Write-Host "  open in your browser:  $prefix" -ForegroundColor Green
Write-Host "  (close this window or press Ctrl+C to stop the server)"
Write-Host ""
try { Start-Process $prefix } catch {}

function Send-Bytes($res, $bytes, $type) {
  $res.ContentType = $type
  $res.AddHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
  $res.ContentLength64 = $bytes.Length
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
}
function Safe-Name($n) { if (-not $n) { return '' } ; return ($n -replace '[^A-Za-z0-9_]', '') }

while ($listener.IsListening) {
  # GetContext() blocks and swallows Ctrl+C; poll an async wait so the engine can act on Ctrl+C.
  $async = $listener.BeginGetContext($null, $null)
  while (-not $async.AsyncWaitHandle.WaitOne(200)) { }
  $ctx = $listener.EndGetContext($async)
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = $req.Url.AbsolutePath
    if ($path -eq '/' -or $path -eq '/index.html') {
      Send-Bytes $res ([IO.File]::ReadAllBytes((Join-Path $root 'haedit.html'))) 'text/html; charset=utf-8'
    }
    elseif ($path -eq '/api/list') {
      $pacs = @(Get-ChildItem (Join-Path $data '*.PAC') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
      $names = @(Get-ChildItem (Join-Path $data '*.PIC') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } | Where-Object { $pacs -contains $_ } | Sort-Object)
      $json = ConvertTo-Json @($names) -Compress
      if ($null -eq $json) { $json = '[]' }
      Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes($json)) 'application/json'
    }
    elseif ($path -eq '/api/pics') {
      $names = @(Get-ChildItem (Join-Path $data '*.PIC') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } | Sort-Object)
      $json = ConvertTo-Json @($names) -Compress
      if ($null -eq $json) { $json = '[]' }
      Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes($json)) 'application/json'
    }
    elseif ($path -eq '/api/pcts') {
      $names = @(Get-ChildItem (Join-Path $data '*.PCT') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } | Sort-Object)
      $json = ConvertTo-Json @($names) -Compress
      if ($null -eq $json) { $json = '[]' }
      Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes($json)) 'application/json'
    }
    elseif ($path -eq '/api/pct') {
      $name = Safe-Name $req.QueryString['name']
      $f = Join-Path $data ($name + '.PCT')
      if ($req.HttpMethod -eq 'POST') {
        $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Close()
        $body = ($body -replace "`r`n", "`n") -replace "`n", "`r`n"
        [IO.File]::WriteAllText($f, $body)
        Write-Host ("  saved {0}.PCT  ({1} bytes)" -f $name, $body.Length) -ForegroundColor Green
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif ($req.HttpMethod -eq 'DELETE') {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host ("  deleted {0}.PCT" -f $name) -ForegroundColor Yellow }
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8' }
      else { $res.StatusCode = 404; Write-Host ("  404 .PCT not found: $f") -ForegroundColor Yellow }
    }
    elseif ($path -eq '/api/msks') {
      $names = @(Get-ChildItem (Join-Path $data '*.MSK') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } | Sort-Object)
      $json = ConvertTo-Json @($names) -Compress
      if ($null -eq $json) { $json = '[]' }
      Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes($json)) 'application/json'
    }
    elseif ($path -eq '/api/msk') {
      $name = Safe-Name $req.QueryString['name']
      $f = Join-Path $data ($name + '.MSK')
      if ($req.HttpMethod -eq 'POST') {
        $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Close()
        $body = ($body -replace "`r`n", "`n") -replace "`n", "`r`n"
        [IO.File]::WriteAllText($f, $body)
        Write-Host ("  saved {0}.MSK  ({1} bytes)" -f $name, $body.Length) -ForegroundColor Green
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif ($req.HttpMethod -eq 'DELETE') {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host ("  deleted {0}.MSK" -f $name) -ForegroundColor Yellow }
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8' }
      else { $res.StatusCode = 404; Write-Host ("  404 .MSK not found: $f") -ForegroundColor Yellow }
    }
    elseif ($path -eq '/api/pic') {
      $name = Safe-Name $req.QueryString['name']
      $f = Join-Path $data ($name + '.PIC')
      if ($req.HttpMethod -eq 'POST') {
        $ms = New-Object IO.MemoryStream
        $req.InputStream.CopyTo($ms)
        [IO.File]::WriteAllBytes($f, $ms.ToArray())
        Write-Host ("  saved {0}.PIC  ({1} bytes)" -f $name, $ms.Length) -ForegroundColor Green
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'application/octet-stream' }
      else { $res.StatusCode = 404; Write-Host ("  404 .PIC not found: $f") -ForegroundColor Yellow }
    }
    elseif ($path -eq '/api/pac') {
      $name = Safe-Name $req.QueryString['name']
      $f = Join-Path $data ($name + '.PAC')
      if ($req.HttpMethod -eq 'POST') {
        $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Close()
        # staleness guard: the editor sends the mtime it LOADED; if the file moved
        # on disk since (another session / another tool saved), refuse the write
        $base = $req.Headers['X-Base-Mtime']
        if ($base -and (Test-Path $f) -and (''+[IO.File]::GetLastWriteTimeUtc($f).Ticks) -ne $base) {
          $res.StatusCode = 409
          Write-Host ("  409 STALE save refused: {0}.PAC changed on disk since the editor loaded it" -f $name) -ForegroundColor Red
          Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('stale')) 'text/plain'
        }
        else {
          [IO.File]::WriteAllText($f, $body)
          Write-Host ("  saved {0}.PAC  ({1} bytes)" -f $name, $body.Length) -ForegroundColor Green
          $res.Headers.Add('X-File-Mtime', ('' + [IO.File]::GetLastWriteTimeUtc($f).Ticks))
          Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
        }
      }
      elseif (Test-Path $f) {
        $res.Headers.Add('X-File-Mtime', ('' + [IO.File]::GetLastWriteTimeUtc($f).Ticks))
        Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8'
      }
      else { $res.StatusCode = 404; Write-Host ("  404 .PAC not found: $f") -ForegroundColor Yellow }
    }
    elseif ($path -eq '/api/dat') {
      $name = Safe-Name $req.QueryString['name']
      $f = Join-Path $data ($name + '.DAT')
      if ($req.HttpMethod -eq 'POST') {
        $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Close()
        $body = ($body -replace "`r`n", "`n") -replace "`n", "`r`n"
        [IO.File]::WriteAllText($f, $body)
        Write-Host ("  saved {0}.DAT  ({1} bytes)" -f $name, $body.Length) -ForegroundColor Green
        Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
      }
      elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8' }
      else { $res.StatusCode = 404; Write-Host ("  404 .DAT not found: $f") -ForegroundColor Yellow }
    }
    elseif ($path -eq '/api/anims') {
      $f = Join-Path $data 'ANIMS.PAC'
      if ($req.HttpMethod -eq 'POST') {
        $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Close()
        $body = ($body -replace "`r`n", "`n") -replace "`n", "`r`n"
        # staleness guard (same as /api/pac): refuse to clobber a newer file
        $base = $req.Headers['X-Base-Mtime']
        if ($base -and (Test-Path $f) -and (''+[IO.File]::GetLastWriteTimeUtc($f).Ticks) -ne $base) {
          $res.StatusCode = 409
          Write-Host ("  409 STALE save refused: ANIMS.PAC changed on disk since the editor loaded it") -ForegroundColor Red
          Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('stale')) 'text/plain'
        }
        else {
          [IO.File]::WriteAllText($f, $body)
          Write-Host ("  saved ANIMS.PAC  ({0} bytes)" -f $body.Length) -ForegroundColor Green
          $res.Headers.Add('X-File-Mtime', ('' + [IO.File]::GetLastWriteTimeUtc($f).Ticks))
          Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
        }
      }
      elseif (Test-Path $f) {
        $res.Headers.Add('X-File-Mtime', ('' + [IO.File]::GetLastWriteTimeUtc($f).Ticks))
        Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8'
      }
      else { $res.StatusCode = 404 }
    }
    elseif ($path -eq '/api/fontfile') {
      $name = ('' + $req.QueryString['name']).ToLower()
      if (@('font', 'font3', 'fontbold') -notcontains $name) { $res.StatusCode = 400 }
      else {
        $f = Join-Path $data ($name + '.txt')
        if ($req.HttpMethod -eq 'POST') {
          $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
          $body = $reader.ReadToEnd(); $reader.Close()
          $body = ($body -replace "`r`n", "`n") -replace "`n", "`r`n"
          [IO.File]::WriteAllText($f, $body)
          Write-Host ("  saved {0}.txt  ({1} bytes)" -f $name, $body.Length) -ForegroundColor Green
          Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes('ok')) 'text/plain'
        }
        elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8' }
        else { $res.StatusCode = 404 }
      }
    }
    elseif ($path -eq '/api/font') {
      # legacy endpoint: reads OK; SAVES REFUSED - old editor pages predate the height-header
      # font format and would write a file the game misreads. Refresh the editor page instead.
      $f = Join-Path $data 'font.txt'
      if ($req.HttpMethod -eq 'POST') {
        $res.StatusCode = 410
        Write-Host '  REFUSED legacy font save (410) - refresh the editor page in the browser' -ForegroundColor Yellow
      }
      elseif (Test-Path $f) { Send-Bytes $res ([IO.File]::ReadAllBytes($f)) 'text/plain; charset=utf-8' }
      else { $res.StatusCode = 404 }
    }
    else { $res.StatusCode = 404 }
  }
  catch {
    try {
      $res.StatusCode = 500
      $b = [Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
      $res.OutputStream.Write($b, 0, $b.Length)
    } catch {}
    Write-Host ("  error: " + $_.Exception.Message) -ForegroundColor Red
  }
  finally { try { $res.Close() } catch {} }
}
