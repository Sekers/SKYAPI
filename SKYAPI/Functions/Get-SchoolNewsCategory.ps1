function Get-SchoolNewsCategory
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentNewsCategoriesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of Content News Categories.

        .DESCRIPTION
        Education Management School API - Returns a collection of Content News Categories.
        Requires the 'Parent', 'Faculty' or 'Student' role in the Education Management system.

        .EXAMPLE
        Get-SchoolNewsCategory
    #>
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/content/news/categories'

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
