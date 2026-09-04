function Get-SchoolUserExtended
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersExtendedByUser_idGet
        
        .SYNOPSIS
        Education Management School API - Get extended user details (telephones, occupations, relationships, etc.) for one or more user IDs.

        .DESCRIPTION
        Education Management School API - Get extended user details (telephones, occupations, relationships, etc.) for one or more user IDs.

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolUserExtended -User_ID 2230332,3243114
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
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/extended/'

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        # Parse with date/time values left as strings so the calendar date the API actually wrote is still
        # readable, then normalize every date/time in the response, including the ones nested inside visa,
        # passport, in_state and occupations. Real timestamps such as audit_date, created_date and
        # last_modified_date keep their time: the reader classifies by an explicitly named field first, then
        # by a fractional second, then by the clock reading. Those three names are in the reader's default
        # timestamp list, which is what keeps them intact if one ever lands on exact midnight with zero
        # milliseconds - a shape that is otherwise indistinguishable from a date.
        # See Research_Notes/DateTime-Handling.md.
        #
        # occupations' begin_date/end_date are date-only despite carrying a 04:00/05:00 time: the API stores
        # school-midnight converted to UTC for those. This is the long-standing occupations bug Blackbaud were
        # asked about; as of 2026-07-28 the encoding is unchanged, so naming them here is still required.
        $response_raw = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        $response = ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw
        $null = Repair-SKYAPIResponseDateTime -InputObject $response -DateOnlyFields @('begin_date','end_date')

        $response
    }
}
