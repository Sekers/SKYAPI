function Get-SchoolAdmissionCandidate
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AdmissionsCandidatesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of admissions candidates.

        .DESCRIPTION
        Education Management School API - Returns a collection of admissions candidates.
        Requires at least one of the following roles in the Education Management system:
          - Admissions Manager
          - Platform Manager
          - SKY API Data Sync

        .PARAMETER school_year
        Filter for a specific school year. Default is current year.
        .PARAMETER status_ids
        One or more comma delimited Status ID(s) to filter results on. Default is no status Id filter.
        Use Get-SchoolAdmissionStatus to get a collection of admissions statuses.
        .PARAMETER modified_date
        The date last modified to filter results to on or after. Use ISO-8601 date format: 2003-04-21. Default is no modified date filter.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolAdmissionCandidate
        .EXAMPLE
        Get-SchoolAdmissionCandidate -school_year '2023-2024' -status_ids '158,275,278' -modified_date '2023-07-01'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$status_ids,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$modified_date,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/admissions/candidates'

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
