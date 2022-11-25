# https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsEnrollmentsByUser_idGet
# Returns a collection of course sections in which the provided student(s) is/are enrolled.
# Requires the 'Academic Group Manager' or 'Schedule Manager' role in the K12 system.

# Parameters
# User_ID,yes,integer,Comma delimited list of user IDs for each student you want returned.
# school_year,no,string,The school year to get sections for. Defaults to the current school year.

function Get-SchoolStudentEnrollmentList
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year
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

    # Remove the $User_ID parameter since we don't pass that on in with the other parameters
    $parameters.Remove('User_ID') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
