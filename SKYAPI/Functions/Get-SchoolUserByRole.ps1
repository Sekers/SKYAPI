function Get-SchoolUserByRole
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/v1usersget
        
        .SYNOPSIS
        Education Management School API - Returns a collection of users of the specified role(s) with basic user details.
        
        .DESCRIPTION
        Education Management School API - Returns a collection of users of the specified role(s) with basic user details.
        You can specify optional parameters to filter results by name, email address and graduation year.

        Requires the 'Platform Manager', 'Billing Clerk', 'Password Manager' or'Contact Card Manager' role in the Education Management system.

        .PARAMETER roles
        Required. Comma delimited list of role IDs to get users for.
        Note: This parameter is passed on directly to the API endpoint and should be a string, not an array.
        .PARAMETER first_name
        Filter results by first name.
        .PARAMETER last_name
        Filter results by last name.
        .PARAMETER email
        Filter results by e-mail.
        .PARAMETER maiden_name
        Filter results by maiden name.
        .PARAMETER grad_year
        The beginning date in a school year (ex. 2017).
        .PARAMETER end_grad_year
        The end date in a school year (ex. 2018). Enter a grad_year and end_grad_year to find matching results in the date range.
        .PARAMETER marker
        Use the record number as the marker value to start the data results at a specific spot. For example: marker=101 will return results beginning at that record.
        .PARAMETER ResponseLimit
        Limits response to this number of results.

        .EXAMPLE
        Get-SchoolUserByRole -Roles "15434,15426"
    #>
    
    [cmdletbinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$roles, # This doesn't need to be an array since the parameter takes comma-separated values by default.
        
        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$first_name,
        
        [parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_name,
       
        [parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,
        
        [parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$maiden_name,
        
        [parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$grad_year,
        
        [parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_grad_year,
       
        [parameter(
        Position=7,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$marker,

        [parameter(
        Position=8,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    $PageLimit = 100

    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::NEXT_RECORD_NUMBER
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Set/Replace Marker parameter to 1 if not set or 0. That way it can do pagination properly.
    if ($null -eq $marker -or $marker -eq '' -or $marker -eq 0)
    {
        $parameters.Remove('marker') | Out-Null
        $marker = 1
        $parameters.Add('marker',$marker)
    }

    # Remove the ResponseLimit parameter since it is handled differently.
    $parameters.Remove('ResponseLimit') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIPagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
    $response
}
