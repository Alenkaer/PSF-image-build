function Invoke-CustomerLockbox {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $certName     = $Body.certName     ?? $env:DEFAULT_CERT_NAME

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId)) {
        throw "tenantDomain and appId required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -CertName $certName

        $cfg = Get-OrganizationConfig -ErrorAction Stop
        $enabled = [bool]($cfg.CustomerLockBoxEnabled)
        $pass = $enabled

        return @{
            pass    = $pass
            enabled = $enabled
            detail  = "Customer Lockbox: $(if($enabled){'ENABLED'}else{'DISABLED - Microsoft support kan tilgå data uden jeres godkendelse'})"
        }
    } finally {
        Disconnect-Exo
    }
}
