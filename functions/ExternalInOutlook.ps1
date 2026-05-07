function Invoke-ExternalInOutlook {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $certName     = $Body.certName     ?? $env:DEFAULT_CERT_NAME

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId)) {
        throw "tenantDomain and appId required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -CertName $certName

        $cfg = Get-ExternalInOutlook -ErrorAction Stop
        $enabled = $false
        if ($cfg) { $enabled = [bool]($cfg | Select-Object -First 1 -ExpandProperty Enabled -ErrorAction SilentlyContinue) }
        $pass = $enabled

        return @{
            pass    = $pass
            enabled = $enabled
            detail  = "External sender tag in Outlook: $(if($enabled){'enabled'}else{'disabled'})"
        }
    } finally {
        Disconnect-Exo
    }
}
