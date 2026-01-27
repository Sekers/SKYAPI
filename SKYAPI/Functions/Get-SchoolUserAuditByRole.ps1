function Get-SchoolUserAuditByRole
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersAuditGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of audit information based on the specified role_id within the dates provided.

        .DESCRIPTION
        Education Management School API - Returns a collection of audit information based on the specified role_id within the dates provided.
        .PARAMETER role_id
        Role to return audit information for.
        Use Get-SchoolRole to get a list of role IDs.
        
        Accepts pipeline input:
          - By value (e.g. "12","34" | Get-SchoolUserAuditByRole)
          - By property name (e.g. objects with a Role_ID property)

        .PARAMETER start_date
        The date to begin looking for changes. Must be greater than 01/01/1990. Use ISO-8601 date format (2022-04-08).
        #TODO: ???? If not specified, defaults to 30 days from start_date.
        Accepts pipeline input by property name only (objects with start_date).
        
        .PARAMETER end_date
        The date to end looking for changes. Must be within 1 year of start_date. Use ISO-8601 date format (2022-04-08).
        If not specified, returns start_date + 7 days.
        Accepts pipeline input by property name only (objects with end_date)
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        "15425","15427" | Get-SchoolUserAuditByRole -start_date "2025-01-01" -end_date "2025-01-08"

        .EXAMPLE
        $userAuditPSObject = @(
            [PSCustomObject]@{
                role_id    = '15425'
                start_date = '2025-01-01'
                end_date = '2025-01-08'
            },
            [PSCustomObject]@{
                role_id    = '15427'
                start_date = '2025-01-01'
            }
        )
        $userAuditPSObject | Get-SchoolUserAuditByRole

    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true, # Only have one unnamed parameter (per parameter set) accepting pipeline input by value because otherwise it gets messy.
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$Role_ID,

        [parameter(
        Position=1,
        Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [string]$start_date,

        [parameter(
        Position=2,
        Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [Parameter(
        Position=3,
        Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    begin
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/audit'

        # Set the response field
        $ResponseField = "value"

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key
    }

    process
    {
        # Set the parameters (don't use $PSBoundParameters when working with pipeline input)
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        if (-not [string]::IsNullOrWhiteSpace($start_date)) { $parameters['start_date'] = $start_date }
        if (-not [string]::IsNullOrWhiteSpace($end_date))   { $parameters['end_date']   = $end_date }

        
        # TODO: Double-check this is how the endpoint works if you can. Otherwise make this the default.
        # Default start_date to 7 days ago if not provided
        if ([string]::IsNullOrWhiteSpace($start_date))
        {
            $start_date = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
        }

        # #TODO: Temporary fix for "end_date" not actually defaulting to "start_date + 7 days" if not specified.
        if ([string]::IsNullOrWhiteSpace($end_date))
        {
            $end_date = (Get-Date -Date $start_date).AddDays(7).ToString('yyyy-MM-dd')
        }

        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        foreach ($rid in $Role_ID)
        {
            # Reset role_id parameter for each iteration
            $parameters.Remove('role_id') | Out-Null
            $parameters.Add('role_id',$rid) 

            if ($ReturnRaw)
            {
                $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
                return $response # TODO: Make this continue to not break the pipeline?
            }

            $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
            $response
        }
    }

    end {}
}
