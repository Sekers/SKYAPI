# https://developer.sky.blackbaud.com/docs/services/school/operations/v1levelsget
# Returns a list of school levels.
# Requires the 'Academic Group Manager', 'Schedule Manager' or 'Platform Manager' role in the K12 system.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-SchoolLevelList
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/levels'

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
