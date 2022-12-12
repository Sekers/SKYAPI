function Get-SchoolUser
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idGet
        
        .SYNOPSIS
        Education Management School API - Get basic user information for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Get basic user information for one or more user IDs.

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want returned.

        .EXAMPLE
        Get-SchoolUser -User_ID 2230332,3243114
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile

        # Fix date-only fields since the API returns dates with improper time values.
        $response.dob = Repair-SkyApiDate -Date $response.dob

        $response
    }
}
