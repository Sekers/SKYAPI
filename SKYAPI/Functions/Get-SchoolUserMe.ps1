function Get-SchoolUserMe
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersMeGet
        
        .SYNOPSIS
        Education Management School API - Returns information about the caller.

        .DESCRIPTION
        Education Management School API - Returns information about the caller.

        .EXAMPLE
        Get-SchoolUserMe
    #>
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/me'

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile
    $response
}