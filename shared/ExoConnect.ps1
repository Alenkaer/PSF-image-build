# Connect to a tenant's Exchange Online via app-only certificate auth.
# Cert stored in Azure Key Vault. SP credentials read from container env vars (§3).
# Flow: Authenticate to Azure (client secret) → fetch cert from Key Vault → Connect-ExchangeOnline.

function Connect-ExoForTenant {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9\.\-]+$')]
        [string] $TenantDomain,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F\-]{36}$')]
        [string] $AppId,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\-]+$')]
        [string] $CertName = $env:DEFAULT_CERT_NAME
    )

    # §4: Validate each credential env var individually
    if ([string]::IsNullOrWhiteSpace($env:KEYVAULT_URI)) {
        throw "KEYVAULT_URI environment variable not set"
    }
    if ([string]::IsNullOrWhiteSpace($env:SP_APP_ID)) {
        throw "SP_APP_ID environment variable not set"
    }
    if ([string]::IsNullOrWhiteSpace($env:SP_TENANT_ID)) {
        throw "SP_TENANT_ID environment variable not set"
    }
    if ([string]::IsNullOrWhiteSpace($env:SP_CLIENT_SECRET)) {
        throw "SP_CLIENT_SECRET environment variable not set"
    }

    # §3: Authenticate to Azure using SP credentials from env (never hardcoded)
    $secureSecret = ConvertTo-SecureString $env:SP_CLIENT_SECRET -AsPlainText -Force
    $credential = [PSCredential]::new($env:SP_APP_ID, $secureSecret)
    Connect-AzAccount -ServicePrincipal `
        -Credential $credential `
        -TenantId $env:SP_TENANT_ID `
        -ErrorAction Stop | Out-Null

    $vaultName = ($env:KEYVAULT_URI -replace '^https://([^\.]+)\..*', '$1')

    # Pull the certificate from Key Vault
    $cert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $CertName
    if (-not $cert) {
        throw "Certificate not found in Key Vault"
    }

    # Load the cert with its private key (PFX bytes from Key Vault secret)
    $certSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $CertName -AsPlainText
    $certBytes = [Convert]::FromBase64String($certSecret)
    $pfxCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $certBytes,
        [securestring]::new(),
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    )

    Connect-ExchangeOnline `
        -AppId $AppId `
        -Certificate $pfxCert `
        -Organization $TenantDomain `
        -ShowBanner:$false `
        -CommandName 'Get-QuarantinePolicy','Get-SharingPolicy','Get-OrganizationConfig','Get-ExternalInOutlook','Get-OutboundConnector','Get-DlpCompliancePolicy','Get-DlpComplianceRule','Get-DlpSensitiveInformationType','Get-RetentionCompliancePolicy','Get-ComplianceRetentionEvent','Get-SupervisoryReviewPolicyV2','Get-AttackSimulationTrainingCampaign'
}

function Disconnect-Exo {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    try { Disconnect-AzAccount -ErrorAction SilentlyContinue } catch {}
}
