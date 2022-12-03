function Get-SchoolUserGenderType
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersGendertypesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of gender types.

        .DESCRIPTION
        Education Management School API - Returns a collection of gender types.
        Requires at least one of the following roles in the Education Management system:
          - SKY API Data Sync

        .PARAMETER 
        Required. 

        .EXAMPLE
        Get-SchoolUserGenderType
    #>
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/gendertypes'

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
