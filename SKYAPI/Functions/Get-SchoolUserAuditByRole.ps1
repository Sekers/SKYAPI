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
        .PARAMETER start_date
        The date to begin looking for changes. Must be greater than 01/01/1990. Use ISO-8601 date format (2022-04-08).
        #TODO: ???? If not specified, defaults to 30 days from start_date.
        
        .PARAMETER end_date
        The date to end looking for changes. Must be within 1 year of start_date. Use ISO-8601 date format (2022-04-08).
        If not specified, returns start_date + 7 days.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolTerm
        .EXAMPLE
        Get-SchoolTerm -school_year '2021-2022'
        .EXAMPLE
        Note: offering_type 1 is Academics
        Get-SchoolTerm -offering_type 1 | Select-Object description
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
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
    }

    process
    {
        # Set the parameters
        $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        foreach ($parameter in $PSBoundParameters.GetEnumerator())
        {
            $parameters.Add($parameter.Key,$parameter.Value) 
        }

        # Remove the $ReturnRaw & $Role_ID parameters since we don't pass them on to the API.
        $parameters.Remove('ReturnRaw') | Out-Null
        $parameters.Remove('Role_ID') | Out-Null

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

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
                return $response
            }

            $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
            $response
        }
    }

    end {}
}
