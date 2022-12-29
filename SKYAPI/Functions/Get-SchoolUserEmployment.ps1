function Get-SchoolUserEmployment
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idEmploymentGet
        
        .SYNOPSIS
        Education Management School API - Returns the employment details for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Returns the employment details for one or more user IDs.

        Requires at least one of the following roles in the Education Management system:
          - SKY API Data Sync

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolUserEmployment -User_ID 3154032,5942642
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
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
    $endUrl = '/employment'

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile
        $response
    }
}
