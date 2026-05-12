function Invoke-EDiscoveryCases {
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

        $cases = @(Get-ComplianceCase -ErrorAction Stop |
            Select-Object Name, Status, CaseType, CreatedDateTime, ClosedDateTime, Description)

        $active = @($cases | Where-Object { $_.Status -eq 'Active' })
        $closed = @($cases | Where-Object { $_.Status -eq 'Closed' })

        return @{
            pass   = $true
            total  = $cases.Count
            active = $active.Count
            closed = $closed.Count
            cases  = @($cases | Select-Object -First 20)
            detail = "$($cases.Count) eDiscovery cases ($($active.Count) active, $($closed.Count) closed)"
        }
    } finally {
        Disconnect-Exo
    }
}
