function Invoke-SensitiveTypes {
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

        $types = @(Get-DlpSensitiveInformationType -ErrorAction Stop |
            Select-Object Name, Publisher, Type, RecommendedConfidence)

        $custom = @($types | Where-Object { $_.Publisher -ne 'Microsoft Corporation' })
        $builtin = @($types | Where-Object { $_.Publisher -eq 'Microsoft Corporation' })

        return @{
            pass          = $types.Count -gt 0
            total         = $types.Count
            custom_count  = $custom.Count
            builtin_count = $builtin.Count
            custom_types  = @($custom | Select-Object -First 20)
            detail        = "$($types.Count) sensitive info types ($($custom.Count) custom, $($builtin.Count) built-in)"
        }
    } catch {
        if ($_.Exception.Message -like '*is not recognized*') {
            return @{ pass = $false; na = $true; na_reason = 'not_licensed'; detail = "SensitiveTypes cmdlet not available  -- feature not licensed on this tenant" }
        }
        throw
    } finally {
        Disconnect-Exo
    }
}
