function Invoke-RetentionPolicies {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $tenantId     = $Body.tenantId     ?? $env:DEFAULT_TENANT_ID
    $clientSecret = $Body.clientSecret ?? $env:DEFAULT_CLIENT_SECRET

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        throw "tenantDomain, appId, tenantId and clientSecret required"
    }

    try {
        Connect-SccForTenant -TenantDomain $tenantDomain -AppId $appId -TenantId $tenantId -ClientSecret $clientSecret

        $policies = @(Get-RetentionCompliancePolicy -ErrorAction Stop |
            Select-Object Name, Enabled, Mode, Type, RetentionDuration, ExchangeLocation, SharePointLocation, ModernGroupLocation)

        $rules = @(Get-RetentionComplianceRule -ErrorAction SilentlyContinue |
            Select-Object Name, Policy, RetentionDuration, RetentionComplianceAction, Enabled)

        return @{
            pass            = @($policies | Where-Object { $_.Enabled }).Count -gt 0
            total_policies  = $policies.Count
            enabled_count   = @($policies | Where-Object { $_.Enabled }).Count
            total_rules     = $rules.Count
            policies        = @($policies | Select-Object -First 20)
            rules           = @($rules | Select-Object -First 20)
            detail          = "$($policies.Count) retention policies ($(@($policies | Where-Object { $_.Enabled }).Count) enabled), $($rules.Count) rules"
        }
    } finally {
        Disconnect-Exo
    }
}
