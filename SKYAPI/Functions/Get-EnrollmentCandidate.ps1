function Get-EnrollmentCandidate
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=afe-edems&operation=V1CandidatesByCandidate_idGet
        
        .SYNOPSIS
        Education Management Enrollment Management API - Returns a candidate's information for a specific year. Defaults to the current admissions year.

        .DESCRIPTION
        Education Management Enrollment Management API - Returns a candidate's information for a specific year. Defaults to the current admissions year.
        Requires the following role in the Education Management system:
          - Admissions Manager
          - Admissions Staff

        .PARAMETER Candidate_ID
        Required. Array of user IDs for each candidate you want returned.
        .PARAMETER school_year
        The ID or description for the school year. Defaults to the current admissions year. Corresponds to school_year_label in the Year list (Get-SchoolYear).
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-EnrollmentCandidate -Candidate_ID 4924925, 7934925
        .EXAMPLE
        Get-EnrollmentCandidate -Candidate_ID 4924925, 7934925 -school_year '2025-2026'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Candidate_ID, # Array as we loop through submitted IDs

        [parameter(
        Position=1,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [Parameter(
        Position=2,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/afe-edems/v1/candidates/'

    # Set the parameters
    $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'Candidate_ID','ReturnRaw'

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more IDs
    foreach ($uid in $Candidate_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
            $response
            continue
        }

        # Parse with date/time values left as strings so the calendar date the API wrote stays readable, then
        # normalize every date/time in the response. See Research_Notes/DateTime-Handling.md.
        $response_raw = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        $response = ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw
        $null = Repair-SKYAPIResponseDateTime -InputObject $response

        $response
    }
}
