# https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsBySection_idStudentsGet
# Returns a list of students in the provided section(s)

# Parameter,Required,Type,Description
# Section_ID,yes,integer,Comma-delimited list of user IDs for each user you want returned.

function Get-SchoolStudentListBySection
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Section_ID # Array as we loop through submitted IDs
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
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
