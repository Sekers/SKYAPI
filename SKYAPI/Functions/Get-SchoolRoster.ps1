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
        Limits rosters returned to the sections specified. Provide comma-delimited list of section_id values.

        .PARAMETER last_modified
        Limits rosters returned to sections that were modified on or after the date provided. Use ISO-8601 date format (e.g., 2022-04-01).

        .PARAMETER include_dropped
        Set to True to include dropped students in the rosters. Defaults to false, if omitted.

        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolRoster
        .EXAMPLE
        Get-SchoolRoster -school_year '2022-2023'
        .EXAMPLE
        Get-SchoolRoster -school_year '2197' -school_level 228 -section_ids '97835764, 97835765, 97835766' -last_modified '2024-08-01' -include_dropped $true
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
        [bool]$include_dropped,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/rosters'

    # Set the response field
    $ResponseField = $null

    # Set the parameters
    $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'ReturnRaw'

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        return $response
    }

    # Parse with date/time values left as strings so the calendar date the API wrote stays readable, then
    # normalize. Taking the written date is what keeps these correct for a client in any time zone.
    # enroll_date is left to shape on purpose: it appears both as a date-only value and as a real timestamp
    # within the same payload, so its name proves nothing and is deliberately absent from the reader's
    # date-only and timestamp lists alike.
    # See Research_Notes/DateTime-Handling.md.
    $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
    $response_parsed = ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw
    $response = if ([string]::IsNullOrEmpty($ResponseField)) {$response_parsed} else {Resolve-SKYAPIMemberChain -InputObject $response_parsed -MemberPath $ResponseField -Delimiter "."}
    $null = Repair-SKYAPIResponseDateTime -InputObject $response
    $response
}
