# https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsStudentByStudent_idSectionsGet
# Returns a collection of sections for the specified student_id(s).
# Note: Academic Group Managers cannot use this endpoint. The user requesting the information must be the student, parent of the student or faculty member associated with the student.

# Parameter,Required,Type,Description
# Student_ID,yes,int,Comma delimited list of user IDs for each user you want returned.

function Get-SchoolSectionByStudent
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Student_ID # Array as we loop through submitted IDs
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/student/'
    $endUrl = '/sections'

    # Get data for one or more IDs
    foreach ($uid in $Student_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile
        $response
    }
}
