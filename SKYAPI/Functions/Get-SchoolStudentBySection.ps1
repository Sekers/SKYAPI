function Get-SchoolStudentBySection
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsBySection_idStudentsGet
        
        .SYNOPSIS
        Education Management School API - Returns a list of students in the provided section(s).

        .DESCRIPTION
        Education Management School API - Returns a list of students in the provided section(s).

        .PARAMETER Section_ID
        Required. Array of section IDs to get students of.
        Use Get-SchoolSectionBySchoolLevel to get a list of section IDs for a school level.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolStudentBySection -Section_ID 93054528,92486528
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
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/sections/'
    $endUrl = '/students'

    # Set the response field
    $ResponseField = "value"

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
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
