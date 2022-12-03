function Get-SchoolVenueBuilding
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1VenuesBuildingsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of buildings.

        .DESCRIPTION
        Education Management School API - Returns a collection of buildings.
        Requires the 'Team Schedule Manager', 'Coach', 'Athletic Group Manager' or 'Pending Coach' role in the Education Management system.  

        .EXAMPLE
        Get-SchoolVenueBuilding
    #>
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/venues/buildings'

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
