function Invoke-DlpPolicies {
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

        $policies = @(Get-DlpCompliancePolicy -ErrorAction Stop |
            Select-Object Name, Enabled, Mode, Type, ExchangeLocation, SharePointLocation, OneDriveLocation, TeamsLocation)

        $rules = @(Get-DlpComplianceRule -ErrorAction SilentlyContinue |
            Select-Object Name, ParentPolicyName, BlockAccess, NotifyUser, GenerateAlert, Disabled)

        $enabledPolicies = @($policies | Where-Object { $_.Enabled })

        return @{
            pass           = $enabledPolicies.Count -gt 0
            total_policies = $policies.Count
            enabled_count  = $enabledPolicies.Count
            total_rules    = $rules.Count
            policies       = @($policies | Select-Object -First 20)
            rules          = @($rules | Select-Object -First 20)
            detail         = "$($policies.Count) DLP policies ($($enabledPolicies.Count) enabled), $($rules.Count) rules"
        }
    } finally {
        Disconnect-Exo
    }
}
