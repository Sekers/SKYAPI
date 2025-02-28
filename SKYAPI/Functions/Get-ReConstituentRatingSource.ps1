function Get-ReConstituentRatingSource
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=56b76470069a0509c8f1c5b3&operation=ListRatingSources
        
        .SYNOPSIS
        Raiser's Edge Constituent API - Returns a list of all available rating sources.

        .DESCRIPTION
        Raiser's Edge Constituent API - Returns a list of all available rating sources.

        .PARAMETER include_inactive
        Set this parameter to True to include inactive sources in the response. Defaults to False if not specified.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-ReConstituentRatingSource
        .EXAMPLE
        Get-ReConstituentRatingSource -include_inactive $true
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$include_inactive,

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
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

    # Remove the $ReturnRaw parameter since we don't pass it on to the API.
    $parameters.Remove('ReturnRaw') | Out-Null
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        return $response
    }

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
