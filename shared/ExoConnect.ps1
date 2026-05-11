# Connect to a tenant's Exchange Online via app-only client secret auth.
# Uses the same App Registration already configured for Graph API scanning.
# Flow: Client credentials grant (MSAL) → access token → Connect-ExchangeOnline.

function Connect-ExoForTenant {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9\.\-]+$')]
        [string] $TenantDomain,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F\-]{36}$')]
        [string] $AppId,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F\-]{36}$')]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $ClientSecret
    )

    # Client credentials grant for Exchange Online scope
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $AppId
        client_secret = $ClientSecret
        scope         = 'https://outlook.office365.com/.default'
    }

    $tokenResponse = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method POST `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body `
        -ErrorAction Stop

    if (-not $tokenResponse.access_token) {
        throw "Failed to acquire Exchange Online access token"
    }

    Connect-ExchangeOnline `
        -AccessToken $tokenResponse.access_token `
        -Organization $TenantDomain `
        -ShowBanner:$false `
        -CommandName 'Get-QuarantinePolicy','Get-SharingPolicy','Get-OrganizationConfig','Get-ExternalInOutlook','Get-OutboundConnector','Get-DlpCompliancePolicy','Get-DlpComplianceRule','Get-DlpSensitiveInformationType','Get-RetentionCompliancePolicy','Get-ComplianceRetentionEvent','Get-SupervisoryReviewPolicyV2','Get-AttackSimulationTrainingCampaign'
}

function Disconnect-Exo {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}
