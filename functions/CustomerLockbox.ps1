function Invoke-CustomerLockbox {
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
        $enabled = [bool]($cfg.CustomerLockBoxEnabled)
        $pass = $enabled

        return @{
            pass    = $pass
            enabled = $enabled
            detail  = "Customer Lockbox: $(if($enabled){'ENABLED'}else{'DISABLED - Microsoft support kan tilgå data uden jeres godkendelse'})"
        }
    } finally {
        Disconnect-Exo
    }
}
