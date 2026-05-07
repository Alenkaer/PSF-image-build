# PSF Pode Server — replaces Azure Functions PowerShell sidecar
# Exposes 8 Exchange Online compliance checks as HTTP POST endpoints.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Load shared helpers + function handlers ───────────────────────
. /app/shared/ExoConnect.ps1
Get-ChildItem /app/functions/*.ps1 | ForEach-Object { . $_.FullName }

# ── Start Pode HTTP server ────────────────────────────────────────
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # Request logging to stdout (Docker captures)
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging

    # ── Auth middleware: validate x-functions-key ──────────────────
    Add-PodeMiddleware -Name 'ApiKeyAuth' -ScriptBlock {
        # Skip auth for health endpoint
        if ($WebEvent.Path -eq '/health') { return $true }

        $key = $WebEvent.Request.Headers['x-functions-key']
        if ([string]::IsNullOrWhiteSpace($key) -or $key -ne $env:PSF_FUNCTION_KEY) {
            Set-PodeResponseStatus -Code 401
            Write-PodeJsonResponse -Value @{ error = 'Unauthorized' }
            return $false
        }
        return $true
    }

    # ── Health endpoint (no auth) ─────────────────────────────────
    Add-PodeRoute -Method Get -Path '/health' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            status    = 'healthy'
            timestamp = (Get-Date -Format 'o')
        }
    }

    # ── Function routes: POST /api/<Name> ─────────────────────────
    $functions = @(
        'QuarantinePolicy', 'SharingPolicy', 'AttackSimTraining',
        'ExternalInOutlook', 'CustomerLockbox', 'M365AppsUpdate',
        'CommunicationCompliance', 'RecordsRetention'
    )

    foreach ($fn in $functions) {
        Add-PodeRoute -Method Post -Path "/api/$fn" -ArgumentList @($fn) -ScriptBlock {
            param($fnName)
            $body = $WebEvent.Data
            if (-not $body) { $body = @{} }

            try {
                $result = & "Invoke-$fnName" -Body $body
                Write-PodeJsonResponse -Value $result -Depth 6
            } catch {
                Set-PodeResponseStatus -Code 500
                Write-PodeJsonResponse -Value @{
                    pass   = $false
                    na     = $true
                    detail = "PSF $fnName error: $($_.Exception.Message)"
                }
            }
        }
    }

}
