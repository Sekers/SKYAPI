function Get-SchoolUser
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idGet
        
        .SYNOPSIS
        Education Management School API - Get basic user information for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Get basic user information for one or more user IDs.

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

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

        # Parse with date/time values left as strings so the calendar date the API wrote stays readable, then
        # normalize. Note this endpoint returns dob as UTC midnight ("2005-03-17T00:00:00+00:00") while
        # Get-SchoolUserExtended returns the same value in the school's zone; taking the written date is
        # correct for both. See Research_Notes/DateTime-Handling.md.
        $response_raw = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        $response = ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw
        $null = Repair-SKYAPIResponseDateTime -InputObject $response

        $response
    }
}
