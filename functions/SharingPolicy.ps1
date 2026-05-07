function Invoke-SharingPolicy {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $certName     = $Body.certName     ?? $env:DEFAULT_CERT_NAME

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId)) {
        throw "tenantDomain and appId required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -CertName $certName

        $policies = Get-SharingPolicy -ErrorAction Stop |
            Select-Object Identity, Name, Enabled, Default, Domains
        $defaultPolicy = $policies | Where-Object { $_.Default -eq $true } | Select-Object -First 1

        $anonymousAllowed = $false
        if ($defaultPolicy -and $defaultPolicy.Domains) {
            foreach ($d in $defaultPolicy.Domains) {
                if ($d -match '^Anonymous:') { $anonymousAllowed = $true; break }
            }
        }
        $pass = -not $anonymousAllowed

        return @{
            pass                = $pass
            total_policies      = ($policies | Measure-Object).Count
            default_policy_name = $defaultPolicy.Name
            anonymous_sharing   = $anonymousAllowed
            recent              = @($policies | Select-Object -First 10)
            detail              = "Default sharing policy: $($defaultPolicy.Name), anonymous: $anonymousAllowed"
        }
    } finally {
        Disconnect-Exo
    }
}
