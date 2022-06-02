# https://developer.sky.blackbaud.com/docs/services/school/operations/V1ListsGet
# Returns a list of basic or advanced lists the authorized user has access to.
# Requires the 'Platform Manager' role in the Education Management system.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-SchoolListOfLists
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/lists'

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
