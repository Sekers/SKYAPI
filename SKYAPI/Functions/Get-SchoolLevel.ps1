# https://developer.sky.blackbaud.com/docs/services/school/operations/v1levelsget
# Returns a collection of core school levels.
# Requires at least one of the following roles in the Education Management system:
#   - Academic Group Manager
#   - Activity Group Manager
#   - Advisory Group Manager
#   - Athletic Group Manager
#   - Dorm Group Manager
#   - Dorm Supervisor
#   - Platform Manager
#   - Schedule Manager
#   - SKY API Data Sync

# Parameter,Required,Type,Description
# No parameters accepted

function Get-SchoolLevel
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/levels'

    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    $response
}
