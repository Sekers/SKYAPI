# https://developer.sky.blackbaud.com/docs/services/school/operations/v1gradelevelsget
# Returns a list of grade levels.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-SchoolGradeLevelList
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/gradelevels'

    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile

    $response = Get-UnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    $response
}
