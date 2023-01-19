function Get-SchoolSectionByStudent
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsStudentByStudent_idSectionsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of sections for the specified student ID(s).

        .DESCRIPTION
        Education Management School API - Returns a collection of sections for the specified student ID(s).
        Note: Academic Group Managers cannot use this endpoint.
        The user requesting the information must be the student, parent of the student or faculty member associated with the student.

        .PARAMETER Student_ID
        Required. Array of user IDs for each student you want sections for returned.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolSectionByStudent -Student_ID 6111769,2772870
        
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
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/student/'
    $endUrl = '/sections'

    # Set the response field
    $ResponseField = "value"

    # Get data for one or more IDs
    foreach ($uid in $Student_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
