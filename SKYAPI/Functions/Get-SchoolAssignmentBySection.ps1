function Get-SchoolAssignmentBySection
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsSectionsBySection_idAssignmentsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of assignments for the provided section(s).

        .DESCRIPTION
        Education Management School API - Returns a collection of assignments for the provided section(s).
        Requires at least one of the following roles in the Education Management system:
          - Academic Group Manager
          - Student
          - Teacher
          - Pending Teacher

        .PARAMETER Section_ID
        Required. Array of section IDs to get assignments for.
        Use Get-SchoolSectionBySchoolLevel to get a list of section IDs for a school level.
        .PARAMETER types
        Returns results that match a comma separated list of assignment type IDs.
        To get a list of assignment type IDs, create an Advanced List from the web app using Academic Group > Assignment Type.
        To indicate no assignment type, use a type ID of 0.
        .PARAMETER status
        The status of the assignment. The status corresponds with static system options.
        .PARAMETER persona_id
        The ID of the persona to get assignments. 3 = Faculty, 2 = Student. Defaults to 3.
        The 'Faculty' persona provides a few additional fields, such as enrolled student count.
        .PARAMETER filter
        Return assignments based on the entered string: expired, future, or all. All is the default sort value.
        .PARAMETER search
        Returns results with Descriptions or Titles that match search string.
        Results include partial word matches and are case insensitive.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolAssignmentBySection -Section_ID 82426521,93054528
        .EXAMPLE
        Get-SchoolAssignmentBySection -Section_ID 82426521 -types '293,294' -filter 'future' -search 'Final'
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Section_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$types,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$status,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet(1,2,3)]
        [int]$persona_id,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('expired','future',"all")]
        [string]$filter,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$search,

        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/sections/'
    $endUrl = '/assignments'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value)
    }

    # Remove spaces from 'types' string if included in a comma-separated list, as the endpoint doesn't allow spaces.
    if ($parameters -contains 'types')
    {
        $parameters.Remove('types') | Out-Null
        $parameters.Add('types',$($types.Replace(' ','')))
    }

    # Remove parameters since we don't pass them on to the API.
    $parameters.Remove('Section_ID') | Out-Null
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more school levels
    foreach ($uid in $Section_ID)
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
