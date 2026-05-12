function Invoke-CommunicationCompliance {
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

        $policies = Get-SupervisoryReviewPolicyV2 -ErrorAction Stop |
            Where-Object { $_.IsValid -eq $true -and $_.Enabled -eq $true }
        $total = ($policies | Measure-Object).Count
        $pass = $total -ge 1

        return @{
            pass            = $pass
            active_policies = $total
            recent          = @($policies | Select-Object -First 10 | ForEach-Object { @{ name=$_.Name; enabled=$_.Enabled } })
            detail          = "$total aktive Communication Compliance policies"
        }
    } catch {
        if ($_.Exception.Message -like '*is not recognized*') {
            return @{ pass = $false; na = $true; na_reason = 'not_licensed'; detail = "CommunicationCompliance cmdlet not available  -- feature not licensed on this tenant" }
        }
        throw
    } finally {
        Disconnect-Exo
    }
}
