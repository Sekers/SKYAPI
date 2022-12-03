function Get-SchoolCourse
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsCoursesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of academic courses, optionally filtered by department and/or school level.

        .DESCRIPTION
        Education Management School API - Returns a collection of academic courses, optionally filtered by department and/or school level.
        Requires at least one of the following roles in the Education Management system:
          - Academic Group Manager
          - Platform Manager

        .PARAMETER department_id
        Identifier for a specific academic department to optionally filter by.
        Use Get-SchoolDepartment to get a list of academic departments.
        .PARAMETER level_id
        Identifier for a specific school level to optionally filter by.
        Use Get-SchoolLevel to get a list of school levels.

        .EXAMPLE
        Get-SchoolCourse
        .EXAMPLE
        Get-SchoolCourse -department_id 8706 -level_id 453
        .EXAMPLE
        Get-SchoolCourse -level_id 229 | Where-Object -Property "inactive" -Match "false"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$department_id,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$level_id
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/courses'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIUnpagedEntity -uid $teacher_id -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
