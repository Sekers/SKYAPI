function Get-SchoolUserRelationship
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idRelationshipsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of a relationships for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Returns a collection of a relationships for one or more user IDs.

        .PARAMETER User_ID
        Required. Array of user IDs you want the relationships of.
   
        .EXAMPLE
        Get-SchoolUserRelationship -User_ID 3154032,5942642
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID # Array as we loop through submitted IDs
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/relationships'

    # Set the response field
    $ResponseField = "value"

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
