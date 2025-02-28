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

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile
    
        # Fix date-only fields since the API returns dates with improper time values.
        # NOTE: DO NOT FIX THE FOLLOWING AS THEY HAVE PROPER TIMES:
        #  - audit_date
        if (-not [string]::IsNullOrEmpty($response.deceased_date)){$response.deceased_date = Repair-SkyApiDate -Date $response.deceased_date}
        if (-not [string]::IsNullOrEmpty($response.birth_date)){$response.birth_date = Repair-SkyApiDate -Date $response.birth_date}
        if (-not [string]::IsNullOrEmpty($response.depart_date)){$response.depart_date = Repair-SkyApiDate -Date $response.depart_date}
        if (-not [string]::IsNullOrEmpty($response.enroll_date)){$response.enroll_date = Repair-SkyApiDate -Date $response.enroll_date}
        # Not 100% sure if I need to fix last_sync_date since it might actually be storing time information (I don't have a record with this set properly to test). However, I don't think this stores time so we are probably good.
        if (-not [string]::IsNullOrEmpty($response.last_sync_date)){$response.last_sync_date = Repair-SkyApiDate -Date $response.last_sync_date}

        # TODO - There is a bug with the dates not appearing correctly on the website when submitting occupations on this endpoint. I have a support request open with Blackbaud
        #        They were able to replicate the issue and have passed it on to the product development team for further review.
        #        The below code fixes the dates issue.
        foreach ($occupation in $response.occupations)
        {
            $index = $response.occupations.IndexOf($occupation)
            
            if (-not [string]::IsNullOrEmpty($occupation.begin_date)){$response.occupations[$index].begin_date = Repair-SkyApiDate -Date $occupation.begin_date}
            if (-not [string]::IsNullOrEmpty($occupation.end_date)){$response.occupations[$index].end_date = Repair-SkyApiDate -Date $occupation.end_date}
        }

        if (-not [string]::IsNullOrEmpty($response.retire_date)){$response.retire_date = Repair-SkyApiDate -Date $response.retire_date}

        $response 
    }
}
