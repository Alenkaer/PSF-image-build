function Invoke-QuarantinePolicy {
    param([hashtable] $Body)

    $tenantDomain = $Body.tenantDomain ?? $env:DEFAULT_TENANT_DOMAIN
    $appId        = $Body.appId        ?? $env:DEFAULT_APP_ID
    $tenantId     = $Body.tenantId     ?? $env:DEFAULT_TENANT_ID
    $clientSecret = $Body.clientSecret ?? $env:DEFAULT_CLIENT_SECRET

    if ([string]::IsNullOrWhiteSpace($tenantDomain) -or [string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        throw "tenantDomain, appId, tenantId and clientSecret required"
    }

    try {
        Connect-ExoForTenant -TenantDomain $tenantDomain -AppId $appId -TenantId $tenantId -ClientSecret $clientSecret

        $policies = Get-QuarantinePolicy -ErrorAction Stop |
            Select-Object Identity, Name, EndUserQuarantinePermissionsValue,
                          ESNEnabled, EndUserSpamNotificationFrequency,
                          QuarantineRetentionDays, IncludeMessagesFromBlockedSenderAddress

        $totalPolicies = @($policies).Count
        $hasReleaseNotification = @($policies | Where-Object { $_.ESNEnabled }).Count -gt 0
        $hasNonDefault = @($policies | Where-Object { $_.Name -notin 'AdminOnlyAccessPolicy','DefaultFullAccessPolicy','DefaultFullAccessWithNotificationPolicy','NotificationEnabledPolicy' }).Count -gt 0
        $pass = $hasReleaseNotification -and $totalPolicies -ge 2

        return @{
            pass                     = $pass
            total_policies           = $totalPolicies
            has_release_notification = $hasReleaseNotification
            has_custom_policy        = $hasNonDefault
            recent                   = @($policies | Select-Object -First 10)
            detail                   = "$totalPolicies quarantine policies, ESN: $($hasReleaseNotification), custom: $($hasNonDefault)"
        }
    } finally {
        Disconnect-Exo
    }
}
