# https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListSuffixes
# Raiser's Edge Constituent API
# Returns a list of available constituent suffix types.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-ReConstituentSuffix
{ 
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/constituent/v1/suffixes'

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
