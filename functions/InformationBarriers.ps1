function Invoke-InformationBarriers {
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

        $policies = @(Get-InformationBarrierPolicy -ErrorAction Stop |
            Select-Object Name, State, AssignedSegment, SegmentsAllowed, SegmentsBlocked)

        $segments = @(Get-OrganizationSegment -ErrorAction SilentlyContinue |
            Select-Object Name, UserGroupFilter)

        $active = @($policies | Where-Object { $_.State -eq 'Active' })

        return @{
            pass             = $active.Count -gt 0
            configured       = $policies.Count -gt 0
            active_policies  = $active.Count
            total_policies   = $policies.Count
            total_segments   = $segments.Count
            policies         = @($policies | Select-Object -First 10)
            segments         = @($segments | Select-Object -First 20)
            detail           = "$($policies.Count) IB policies ($($active.Count) active), $($segments.Count) segments"
        }
    } catch {
        if ($_.Exception.Message -like '*is not recognized*') {
            return @{ pass = $false; na = $true; na_reason = 'not_licensed'; detail = "InformationBarriers cmdlet not available  -- feature not licensed on this tenant" }
        }
        throw
    } finally {
        Disconnect-Exo
    }
}
