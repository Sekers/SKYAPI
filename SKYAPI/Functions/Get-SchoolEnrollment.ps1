# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersEnrollmentsGet
# Returns a collection of users and their enrollments for a single school year.
# Requires at least one of the following roles in the Education Management system:
#   - Admissions manager
#   - Platform manager
#   - SKY API Data Sync

# Parameter,Required,Type,Description
# School_Year,yes,string,Comma delimited list of school year labels to get enrollments for returned.
# school_level_id,no,int,The school level Id to return enrollments for.
# grade_level_id,no,int,The grade level Id to return enrollments for.
# offset,no,int,The record to start the next collection on. Defaults to 0.
# ResponseLimit,no,int,Limits response to this number of results for EACH school year label submitted. Note that this is in place of the 'limit' parameter of the API endpoint so we can have more than the endpoint's max limit returned using additional calls.

function Get-SchoolEnrollment
{
    [cmdletbinding()]
    param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$School_Year, # Array as we loop through submitted years.
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$school_level_id,
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$grade_level_id,
       
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$offset,

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    [int]$PageLimit = 5000
    
    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::OFFSET
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/enrollments'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # If not null, add in the limit parameter since this endpoint actually uses it.
    if ($ResponseLimit)
    {   
        if ($ResponseLimit -lt $PageLimit)
        {
            $parameters.Add('limit',$ResponseLimit)
        }
        else
        {
            $parameters.Add('limit',$PageLimit)
        }
    }

    # Set/Replace Marker parameter to 1 if not set. This shouldn't matter since 0 is the default but I like to cover all the bases.
    if ($null -eq $offset -or $offset -eq '')
    {
        $parameters.Remove('offset') | Out-Null
        $offset = 0
        $parameters.Add('offset',$offset)
    }

    # Remove the $School_Year, offset, & ResponseLimit parameters since they are passed on in the URL or adjusted later
    $SchoolYears = $School_Year
    $OriginalOffset = $offset # We do this because if you have multiple items in $SchoolYears then the offset doesn't reset on subsequent loops.
    $parameters.Remove('School_Year') | Out-Null
    $parameters.Remove('ResponseLimit') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more school years.
    foreach ($school_year in $SchoolYears)
    {
        # Clear out old school year & offset parameters and add in new
        $parameters.Remove('school_year') | Out-Null
        $parameters.Add('school_year',$school_year)
        $parameters.Remove('offset') | Out-Null
        $parameters.Add('offset',$OriginalOffset)
        
        $response = Get-SKYAPIPagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
        $response
    }
}
