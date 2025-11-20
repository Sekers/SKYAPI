function Get-OrSchool
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint (All Schools): https://developer.sky.blackbaud.com/api#api=afe-rostr&operation=getAllSchools

        .LINK
        Endpoint (Specific Schools): https://developer.sky.blackbaud.com/api#api=afe-rostr&operation=getSchool 
        
        .SYNOPSIS
        Education Management OneRoster API - Returns a collection of schools.

        .DESCRIPTION
        Education Management OneRoster API - Returns a collection of schools.
        If you do not specify any school sourceIds, all schools will be returned.

        .PARAMETER School_ID
        Optional. Single school sourceId or array of sourceIds for each school you want returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-OrSchool
        .EXAMPLE
        Get-OrSchool -School_ID 'org-sch-55-851', 'org-sch-55-962'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$School_ID, # Array as we loop through submitted IDs

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
    $endpoint = 'https://api.sky.blackbaud.com/afe-rostr/ims/oneroster/v1p1/schools/'

    # Set the response fields
    $ResponseField_All = "orgs"
    $ResponseField_Single = "org"

    # Get Data
    if ($null -eq $School_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            return $response
        }

        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField_All
        $response
    }
    else # Get data for one or more IDs
    {
        foreach ($uid in $School_ID)
        {
            if ($ReturnRaw)
            {
                $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
                $response
                continue
            }

            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile  -response_field $ResponseField_Single
            $response
        }
    }
}
