function Invoke-CommunicationCompliance {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $certName     = $Body.certName     ?? $env:DEFAULT_CERT_NAME

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId)) {
        throw "tenantDomain and appId required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -CertName $certName

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
    } finally {
        Disconnect-Exo
    }
}
