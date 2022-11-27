# https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListRatingSources
# Raiser's Edge Constituent API
# Returns a list of all available rating sources.

# Parameter,Required,Type,Description
# No parameters accepted

function Get-ReConstituentRatingSource
{ 
[cmdletbinding()]
Param(
    [Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [bool]$include_inactive # TODO: NEED TO TEST THIS ACTUALLY WORKS IF SET TO TRUE!
)

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/constituent/v1/ratings/sources'
    
    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
