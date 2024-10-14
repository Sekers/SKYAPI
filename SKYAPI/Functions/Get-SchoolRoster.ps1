function Get-SchoolRoster
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsRostersGet
        
        .SYNOPSIS
        Education Management School API - Returns the academic rosters for a selected year.

        .DESCRIPTION
        Education Management School API - Returns the academic rosters for a selected year.
        Requires the following role in the Education Management system:
          - Academic Group Manager
          - Schedule Manager

        .PARAMETER school_year
        The school year to get academic sections for. You can specify either the ID or label of the school year (Get-SchoolYear). Defaults to the current school year if not specified.

        .PARAMETER school_level
        Limits rosters returned to the school level specified.

        .PARAMETER section_ids
        Limits roters returned to the sections specified. Provide comma-delimited list of section_id values.

        .PARAMETER last_modified
        Limits rosters returned to sections that were modified on or after the date provided. Use ISO-8601 date format (e.g., 2022-04-01).

        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolRoster
        .EXAMPLE
        Get-SchoolRoster -school_year '2022-2023'
        .EXAMPLE
        Get-SchoolRoster -school_year '11843' -school_level 228 -section_ids '97835764, 97835765, 97835766' -last_modified '2024-08-01'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$school_level,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$section_ids,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_modified,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/rosters'

    # Set the response field
    $ResponseField = $null

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the $ReturnRaw parameter since we don't pass it on to the API.
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        return $response
    }

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
