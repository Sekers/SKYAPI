function Get-SchoolSession
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1SessionsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of sessions for a higher education institution.

        .DESCRIPTION
        Education Management School API - Returns a collection of sessions for a higher education institution.
        Accessible by any authorized user.

        .PARAMETER level_num
        Filter for a specific level number.
        Use Get-SchoolLevel to get a list of school levels.
        .PARAMETER school_year
        Filter for a specific school year.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolSession
        .EXAMPLE
        Get-SchoolSession -level_num 229 -school_year "2019-2020"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$level_num,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/sessions'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove parameters since we don't pass them on this way
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more school levels       
    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        $response
        continue
    }

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
