# Helper: connect to a tenant's Exchange Online via app-only certificate auth.
# The cert is stored in Key Vault. SP credentials are in container env vars.
#
# Flow: Authenticate to Azure (client secret from env) → fetch cert from Key Vault → Connect-ExchangeOnline with cert.

function Connect-ExoForTenant {
    param(
        [Parameter(Mandatory)] [string] $TenantDomain,
        [Parameter(Mandatory)] [string] $AppId,
        [Parameter()] [string] $CertName = $env:DEFAULT_CERT_NAME
    )

    if ([string]::IsNullOrWhiteSpace($env:KEYVAULT_URI)) {
        throw "KEYVAULT_URI environment variable not set"
    }
    if ([string]::IsNullOrWhiteSpace($env:SP_CLIENT_SECRET)) {
        throw "SP_CLIENT_SECRET environment variable not set"
    }

    # Authenticate to Azure using SP credentials from env
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
        throw "Certificate '$CertName' not found in Key Vault '$vaultName'"
    }

    # Load the cert with its private key
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
