function Invoke-M365AppsUpdate {
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

        $cfg = Get-OrganizationConfig -ErrorAction Stop
        $channel = $cfg.OfficeUpdateChannel
        if (-not $channel) { $channel = 'unknown' }
        $goodChannels = @('MonthlyEnterprise','Monthly','Current','CurrentPreview')
        $pass = $channel -in $goodChannels

        return @{
            pass       = $pass
            channel    = $channel
            acceptable = $goodChannels
            detail     = "M365 Apps update channel: $channel $(if($pass){'(acceptable cadence)'}else{'(for langsomt — overvej Monthly Enterprise)'})"
        }
    } finally {
        Disconnect-Exo
    }
}
