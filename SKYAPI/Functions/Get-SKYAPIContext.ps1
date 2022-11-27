####################
# Helper Functions #
####################

# None at this time.

###################
# Return Function #
###################
function Get-SKYAPIContext
{
    # Create the context object to return.
    $SKYAPIContext = New-Object System.Object

    # Collect the non-sensitive session information.
    # More info on these items here: https://developer.blackbaud.com/skyapi/docs/authorization/auth-code-flow/tutorial
    $ObjectPropertyNames = @(
        'environment_id'
        'environment_name'
        'legal_entity_id'
        'legal_entity_name'
        'user_id'
        'email'
        'family_name'
        'given_name'
        'mode'
        'refresh_token_creation'
        'access_token_creation'
    )
    $NonSensitiveSessionInfo = Get-SKYAPIAuthTokensFromFile | Select-Object $ObjectPropertyNames
    foreach ($infoItem in $($NonSensitiveSessionInfo.Psobject.Properties))
    {
        $SKYAPIContext | Add-Member -MemberType NoteProperty -Name "$($infoItem.Name)" -Value $($infoItem.Value)
    }

    # EXAMPLE: Add in the School API caller information.
    # $SKYAPIContext | Add-Member -MemberType NoteProperty -Name 'caller' -Value $(Get-SchoolUserMe)

    $SKYAPIContext
}
