# https://developer.sky.blackbaud.com/docs/services/school/operations/v1rolesget
# Returns a list of user roles.
# Requires the 'Academic Group Manager', 'Schedule Manager' or 'Platform Manager' role in the K12 system.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-SchoolRoleList
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/roles'

    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path

    $response = Get-UnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    $response
}
