# https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsTeachersByTeacher_idSectionsGet
# Returns a list of sections for one or more teachers.

# Parameter,Required,Type,Description
# Teacher_ID,yes,integer,Comma delimited list of user IDs for each teacher you want returned..
# school_year,no,string,The school year to get sections for. Defaults to the current school year.

function Get-SchoolSectionListByTeacher
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Teacher_ID, # Array as we loop through submitted IDs

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/teachers/'
    $endUrl = '/sections'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the $Teacher_ID parameter since we don't pass that on
    $parameters.Remove('Teacher_ID') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile

    # Get data for one or more school levels
    foreach ($uid in $Teacher_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
