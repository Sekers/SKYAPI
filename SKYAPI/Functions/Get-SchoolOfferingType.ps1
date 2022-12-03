function Get-SchoolOfferingType
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/v1offeringtypesget
        
        .SYNOPSIS
        Education Management School API - Returns a list of offering types.

        .DESCRIPTION
        Education Management School API - Returns a list of offering types.
        Requires the 'Academic Group Manager', 'Schedule Manager' or 'Platform Manager' role in the Education Management system.

        .EXAMPLE
        Get-SchoolOfferingType
    #>
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/offeringtypes'

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
