function Invoke-RecordsRetention {
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

        $events = Get-ComplianceRetentionEvent -ErrorAction Stop
        $total = ($events | Measure-Object).Count
        $pass = $total -gt 0

        return @{
            pass         = $pass
            total_events = $total
            recent       = @($events | Select-Object -First 10 | ForEach-Object { @{ name=$_.Name; eventType=$_.EventType; eventDateTime=$_.EventDateTime } })
            detail       = "$total records retention events (disposition reviews)"
        }
    } finally {
        Disconnect-Exo
    }
}
