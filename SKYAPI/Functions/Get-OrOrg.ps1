function Get-OrOrg
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint (All Orgs): https://developer.sky.blackbaud.com/api#api=afe-rostr&operation=getAllOrgs

        .LINK
        Endpoint (Specific Org): https://developer.sky.blackbaud.com/api#api=afe-rostr&operation=getOrg
        
        .SYNOPSIS
        Education Management OneRoster API - Returns a collection of organizations.

        .DESCRIPTION
        Education Management OneRoster API - Returns a collection of organizations.
        If you do not specify any organization sourceIds, all organizations will be returned.

        .PARAMETER Org_ID
        Optional. Single organization sourceId or array of sourceIds for each organization you want returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-OrOrg
        .EXAMPLE
        Get-OrOrg -Org_ID 'org-sch-55-851', 'org-dpt-55-18704'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$Org_ID, # Array as we loop through submitted IDs

        [parameter(
        Position=1,
        Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    begin
    {
        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/afe-rostr/ims/oneroster/v1p1/orgs/'

        # Set the response fields
        $ResponseField_All = "orgs"
        $ResponseField_Single = "org"
    }

    process
    {
        # Get Data
        if ($null -eq $Org_ID)
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
            foreach ($uid in $Org_ID)
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

    end {}
}
