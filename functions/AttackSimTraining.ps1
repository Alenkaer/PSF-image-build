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
        Connect-SccForTenant -TenantDomain $tenantDomain -AppId $appId -TenantId $tenantId -ClientSecret $clientSecret

        $since = (Get-Date).AddMonths(-12)
        $campaigns = Get-AttackSimulationTrainingCampaign -ErrorAction Stop |
            Where-Object { $_.CreatedDateTime -and $_.CreatedDateTime -ge $since }
        $total = ($campaigns | Measure-Object).Count
        $completed = ($campaigns | Where-Object { $_.Status -eq 'Completed' } | Measure-Object).Count
        $pass = $total -ge 2

        return @{
            pass          = $pass
            campaigns_12m = $total
            completed_12m = $completed
            recent        = @($campaigns | Select-Object -First 10 | ForEach-Object { @{ name=$_.Name; status=$_.Status; createdDateTime=$_.CreatedDateTime } })
            detail        = "$total Attack Sim campaigns i 12 mnd, $completed afsluttede"
        }
    } finally {
        Disconnect-Exo
    }
}
