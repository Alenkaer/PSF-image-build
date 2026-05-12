# Connect to a tenant's Exchange Online / Security & Compliance via app-only client secret auth.
# Uses the same App Registration already configured for Graph API scanning.
# Flow: Client credentials grant (MSAL) → access token → Connect-ExchangeOnline / Connect-IPPSSession.

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
        -CommandName 'Get-QuarantinePolicy','Get-SharingPolicy','Get-OrganizationConfig','Get-ExternalInOutlook','Get-OutboundConnector','Get-DlpCompliancePolicy','Get-DlpComplianceRule','Get-DlpSensitiveInformationType','Get-RetentionCompliancePolicy','Get-RetentionComplianceRule'
}

# Security & Compliance session for S&C-only cmdlets
function Connect-SccForTenant {
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

    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $AppId
        client_secret = $ClientSecret
        scope         = 'https://ps.compliance.protection.outlook.com/.default'
    }

    $tokenResponse = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method POST `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body `
        -ErrorAction Stop

    if (-not $tokenResponse.access_token) {
        throw "Failed to acquire Security & Compliance access token"
    }

    Connect-IPPSSession `
        -AccessToken $tokenResponse.access_token `
        -Organization $TenantDomain `
        -ShowBanner:$false `
        -CommandName 'Get-ComplianceRetentionEvent','Get-SupervisoryReviewPolicyV2','Get-AttackSimulationTrainingCampaign','Get-Label','Get-LabelPolicy','Get-InformationBarrierPolicy','Get-OrganizationSegment','Get-ComplianceCase'
}

function Disconnect-Exo {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}
