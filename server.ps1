# PSF HTTP Server — .NET System.Net.HttpListener (zero third-party dependencies)
# Exposes 8 Exchange Online compliance checks as HTTP POST endpoints.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# §6.4: Maximum request body size (prevent resource exhaustion)
$script:MaxBodyBytes = 65536  # 64KB

# ── Load shared helpers + function handlers ───────────────────────
. $PSScriptRoot/shared/ExoConnect.ps1
Get-ChildItem $PSScriptRoot/functions/*.ps1 | ForEach-Object { . $_.FullName }

# ── Route table ───────────────────────────────────────────────────
$script:Routes = @{
    'QuarantinePolicy'       = 'Invoke-QuarantinePolicy'
    'SharingPolicy'          = 'Invoke-SharingPolicy'
    'AttackSimTraining'      = 'Invoke-AttackSimTraining'
    'ExternalInOutlook'      = 'Invoke-ExternalInOutlook'
    'CustomerLockbox'        = 'Invoke-CustomerLockbox'
    'M365AppsUpdate'         = 'Invoke-M365AppsUpdate'
    'CommunicationCompliance'= 'Invoke-CommunicationCompliance'
    'RecordsRetention'       = 'Invoke-RecordsRetention'
}

# ── Helper: send JSON response ────────────────────────────────────
function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse] $Response,
        [int] $StatusCode,
        [hashtable] $Body
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'application/json; charset=utf-8'
    $json = $Body | ConvertTo-Json -Depth 6 -Compress
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.ContentLength64 = $buffer.Length
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.OutputStream.Close()
}

# ── Start HTTP listener ───────────────────────────────────────────
$port = 8080
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:$port/")
$listener.Start()
Write-Host "[startup] PSF HTTP server listening on port $port"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        # §8.2: Request logging (who, what, when, source IP)
        Write-Host "[$([DateTime]::UtcNow.ToString('o'))] $method $path from $($request.RemoteEndPoint)"

        try {
            # ── Health endpoint (no auth) ─────────────────────────
            if ($path -eq '/health' -and $method -eq 'GET') {
                Send-JsonResponse -Response $response -StatusCode 200 -Body @{
                    status    = 'healthy'
                    timestamp = (Get-Date -Format 'o')
                }
                continue
            }

            # ── §4: Auth check (all other endpoints) ─────────────
            $apiKey = $request.Headers['x-functions-key']
            if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -ne $env:PSF_FUNCTION_KEY) {
                Send-JsonResponse -Response $response -StatusCode 401 -Body @{ error = 'Unauthorized' }
                continue
            }

            # ── Route matching: POST /api/<FunctionName> ──────────
            if ($path -match '^/api/([A-Za-z0-9]+)$') {
                $fnName = $Matches[1]

                # §6.1: Method enforcement
                if ($method -ne 'POST') {
                    Send-JsonResponse -Response $response -StatusCode 405 -Body @{ error = 'Method not allowed' }
                    continue
                }

                # Route exists?
                if (-not $script:Routes.ContainsKey($fnName)) {
                    Send-JsonResponse -Response $response -StatusCode 404 -Body @{ error = 'Not found' }
                    continue
                }

                # §6.4: Body size limit (before ConvertFrom-Json on untrusted input)
                if ($request.ContentLength64 -gt $script:MaxBodyBytes) {
                    Send-JsonResponse -Response $response -StatusCode 413 -Body @{ error = 'Request body too large' }
                    continue
                }

                # §6.1: Content-Type validation
                $ct = $request.ContentType
                if ($request.HasEntityBody -and $ct -and -not $ct.StartsWith('application/json')) {
                    Send-JsonResponse -Response $response -StatusCode 415 -Body @{ error = 'Content-Type must be application/json' }
                    continue
                }

                # Parse JSON body
                $body = @{}
                if ($request.HasEntityBody) {
                    $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                    $rawBody = $reader.ReadToEnd()
                    $reader.Close()
                    if ($rawBody) {
                        $parsed = $rawBody | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
                        if ($parsed) { $body = $parsed }
                    }
                }

                # Execute function
                try {
                    $result = & $script:Routes[$fnName] -Body $body
                    Send-JsonResponse -Response $response -StatusCode 200 -Body $result
                } catch {
                    # §8.3: Detail to log, generic message to client
                    Write-Warning "[error] $fnName : $($_.Exception.Message)"
                    Send-JsonResponse -Response $response -StatusCode 500 -Body @{
                        pass   = $false
                        na     = $true
                        detail = "PSF ${fnName}: check failed"
                    }
                }
                continue
            }

            # ── No matching route ─────────────────────────────────
            Send-JsonResponse -Response $response -StatusCode 404 -Body @{ error = 'Not found' }

        } catch {
            # §8.3: Generic error to client, detail to log
            Write-Warning "[fatal] Request handler error: $($_.Exception.Message)"
            try {
                Send-JsonResponse -Response $response -StatusCode 500 -Body @{ error = 'Internal server error' }
            } catch {}
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "[shutdown] Server stopped"
}
