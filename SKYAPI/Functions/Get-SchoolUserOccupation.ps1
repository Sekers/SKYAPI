function Get-SchoolUserOccupation
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idOccupationsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of a relationships for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Returns a collection of a relationships for one or more user IDs.
        Requires at least one of the following roles in the Education Management system:
          - SKY API Data Sync

        .PARAMETER User_ID
        Required. Array of user IDs you want occupations of.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolUserOccupation -User_ID 3154032,5942642
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
    $endUrl = '/occupations'

    # Set the response field
    $ResponseField = "value"

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        # Occupation begin_date/end_date are date-only but do NOT arrive at midnight: the API stores school
        # midnight converted to UTC ("1923-01-25T05:00:00+00:00"). Shape alone cannot tell, so they are named
        # explicitly. This is the long-standing occupations date bug raised with Blackbaud; the encoding was
        # still unchanged as of 2026-07-28. See Research_Notes/DateTime-Handling.md.
        $response_raw = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        $response = Resolve-SKYAPIMemberChain -InputObject (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw) -MemberPath $ResponseField -Delimiter "."
        $null = Repair-SKYAPIResponseDateTime -InputObject $response -DateOnlyFields @('begin_date','end_date')
        $response
    }
}
