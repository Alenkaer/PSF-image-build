function Invoke-ExternalInOutlook {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $tenantId     = $Body.tenantId     ?? $env:DEFAULT_TENANT_ID
    $clientSecret = $Body.clientSecret ?? $env:DEFAULT_CLIENT_SECRET

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        throw "tenantDomain, appId, tenantId and clientSecret required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -TenantId $tenantId -ClientSecret $clientSecret

        # Retry up to 2 times on transient MS server-side errors
        $cfg = $null
        $lastErr = $null
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                $cfg = Get-ExternalInOutlook -ErrorAction Stop
                $lastErr = $null
                break
            } catch {
                $lastErr = $_.Exception.Message
                if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
            }
        }
        if ($lastErr) {
            return @{
                pass   = $false
                na     = $true
                detail = "Get-ExternalInOutlook not available in app-only context -- check via Secure Score or admin portal"
            }
        }

        $enabled = $false
        if ($cfg) { $enabled = [bool]($cfg | Select-Object -First 1 -ExpandProperty Enabled -ErrorAction SilentlyContinue) }
        $pass = $enabled

        return @{
            pass    = $pass
            enabled = $enabled
            detail  = "External sender tag in Outlook: $(if($enabled){'enabled'}else{'disabled'})"
        }
    } finally {
        Disconnect-Exo
    }
}
