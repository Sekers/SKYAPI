function Get-ReConstituentSuffix
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=56b76470069a0509c8f1c5b3&operation=ListSuffixes
        
        .SYNOPSIS
        Raiser's Edge Constituent API - Returns a list of available constituent suffix types.

        .DESCRIPTION
        Raiser's Edge Constituent API - Returns a list of available constituent suffix types.

        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-ReConstituentSuffix
    #>

    [cmdletbinding()]
    param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/constituent/v1/suffixes'
    
    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        return $response
    }
    
    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    $response
}
