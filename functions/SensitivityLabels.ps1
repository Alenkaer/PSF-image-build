function Invoke-SensitivityLabels {
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

        $labels = @(Get-Label -ErrorAction Stop |
            Select-Object Name, DisplayName, Guid, Priority, Disabled, ContentType, EncryptionEnabled, ParentLabelDisplayName)

        $policies = @(Get-LabelPolicy -ErrorAction SilentlyContinue |
            Select-Object Name, Enabled, Labels, ExchangeLocation, SharePointLocation, ModernGroupLocation)

        $activeLabels = @($labels | Where-Object { -not $_.Disabled })

        return @{
            pass            = $activeLabels.Count -gt 0
            total_labels    = $labels.Count
            active_labels   = $activeLabels.Count
            total_policies  = $policies.Count
            labels          = @($labels | Select-Object -First 30)
            policies        = @($policies | Select-Object -First 10)
            detail          = "$($labels.Count) sensitivity labels ($($activeLabels.Count) active), $($policies.Count) label policies"
        }
    } catch {
        if ($_.Exception.Message -like '*is not recognized*') {
            return @{ pass = $false; na = $true; na_reason = 'not_licensed'; detail = "SensitivityLabels cmdlet not available  -- feature not licensed on this tenant" }
        }
        throw
    } finally {
        Disconnect-Exo
    }
}
