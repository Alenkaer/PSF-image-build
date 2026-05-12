function Invoke-AttackSimTraining {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $tenantId     = $Body.tenantId     ?? $env:DEFAULT_TENANT_ID
    $clientSecret = $Body.clientSecret ?? $env:DEFAULT_CLIENT_SECRET

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        throw "tenantDomain, appId, tenantId and clientSecret required"
    }

    try {
        # Attack Sim is a Defender cmdlet — uses ExO session, not S&C
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -TenantId $tenantId -ClientSecret $clientSecret

        $since = (Get-Date).AddMonths(-12)
        $campaigns = Get-AttackSimulationTrainingCampaign -ErrorAction Stop |
            Where-Object { $_.CreatedDateTime -and $_.CreatedDateTime -ge $since }
        $total = @($campaigns).Count
        $completed = @($campaigns | Where-Object { $_.Status -eq 'Completed' }).Count
        $pass = $total -ge 2

        return @{
            pass          = $pass
            campaigns_12m = $total
            completed_12m = $completed
            recent        = @($campaigns | Select-Object -First 10 | ForEach-Object { @{ name=$_.Name; status=$_.Status; createdDateTime=$_.CreatedDateTime } })
            detail        = "$total Attack Sim campaigns i 12 mnd, $completed afsluttede"
        }
    } catch {
        if ($_.Exception.Message -like '*is not recognized*') {
            return @{ pass = $false; na = $true; na_reason = 'not_licensed'; detail = 'Attack Simulation Training not available — requires Defender for Office 365 P2' }
        }
        throw
    } finally {
        Disconnect-Exo
    }
}
