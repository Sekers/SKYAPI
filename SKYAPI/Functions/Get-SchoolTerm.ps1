function Get-SchoolTerm
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=v1termsget
        
        .SYNOPSIS
        Education Management School API - Returns a list of terms.

        .DESCRIPTION
        Education Management School API - Returns a list of terms.

        .PARAMETER school_year
        The school year to get terms for. Defaults to the current school year if not specified.
        .PARAMETER offering_type
        The offering type ID to filter terms by.
        Use Get-SchoolOfferingType to get a list of offering type IDs.
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
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [parameter(
        Position=1,
        ValueFromPipelineByPropertyName=$true)]
        [int]$offering_type,

        [Parameter(
        Position=2,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/terms'

    # Set the response field
    $ResponseField = "value"

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
    # normalize. begin_date/end_date here are date-only in the school's zone, and unset ones arrive as
    # 0001-01-01. See Research_Notes/DateTime-Handling.md.
    $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
    $response = Resolve-SKYAPIMemberChain -InputObject (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw) -MemberPath $ResponseField -Delimiter "."
    $null = Repair-SKYAPIResponseDateTime -InputObject $response
    $response
}
