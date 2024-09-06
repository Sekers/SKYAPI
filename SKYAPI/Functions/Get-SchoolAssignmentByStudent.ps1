function Get-SchoolAssignmentByStudent
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsByStudent_idAssignmentsGet
        
        .SYNOPSIS
        Education Management School API - Returns assignments for the specified student ID(s) that are assigned or due within the date range specified.

        .DESCRIPTION
        Education Management School API - Returns assignments for the specified student ID(s) that are assigned or due within the date range specified.
        Requires at least one of the following roles in the Education Management system:
          - Student
          - Parent

        .PARAMETER Student_ID
        Required. Array of user IDs for each student you want sections for returned.
        .PARAMETER start_date
        Required. Start date of assignments you want returned. Use RFC 3339 date format (e.g., 2022-04-01).
        .PARAMETER end_date
        End date of assignments you want returned. Use RFC 3339 date format (e.g., 2022-04-01). If no end_date is supplied, it defaults to 31 days past the start_date.
        .PARAMETER section_ids
        Comma-separated string of section IDs to optionally filter by.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolAssignmentByStudent -Student_ID 3294459,3300981 -start_date "2022-11-07"
        .EXAMPLE
        Get-SchoolAssignmentByStudent -Student_ID 3294459 -start_date "2022-11-07" -end_date "2022-11-13" -section_ids "82426521,93054528"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Student_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$start_date,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$section_ids,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/'
    $endUrl = '/assignments'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value)
    }

    # Remove parameters since we don't pass them on to the API.
    $parameters.Remove('Student_ID') | Out-Null
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more IDs
    foreach ($uid in $Student_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
