function Get-SchoolStudentEnrollment
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsEnrollmentsByUser_idGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of course sections in which the provided student(s) is/are enrolled.

        .DESCRIPTION
        Education Management School API - Returns a collection of course sections in which the provided student(s) is/are enrolled.
        Requires the 'Academic Group Manager' or 'Schedule Manager' role in the Education Management system.

        .PARAMETER User_ID
        Required. Array of user IDs of each student's course section enrollments you want returned.
        .PARAMETER school_year
        The school year to get sections for. Defaults to the current school year if not specified.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolStudentEnrollment -User_ID 3294459,3300981
        .EXAMPLE
        Get-SchoolStudentEnrollment -User_ID 3294459 -school_year "2021-2022"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/enrollments/'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove parameters since we don't pass them on with the other parameters
    $parameters.Remove('User_ID') | Out-Null
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
