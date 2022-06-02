# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersExtendedGet
# Returns a paginated list of users, limited to 1000 users per page.
# Note that this takes BASE ROLE IDs and not roles. So a persson might show up in the Staff list even if they are not in the Staff role
# because they are in the "Admin Team" roll which has the same base_roll_id as Staff.

# Parameter,Required,Type,Description
# base_role_ids,yes,string,Comma delimited list of base role IDs to get users for.
# Marker,no,integer,Results will start with the user AFTER the specified user's ID in the result set.
# ResponseLimit,no,integer,Limits response to this number of results.

function Get-SchoolUserExtendedList
{
    [cmdletbinding()]
    param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$base_role_ids, # This doesn't need to be an array since the parameter takes comma-separated values by default.
       
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$Marker,

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    $PageLimit = 1000

    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::LAST_USER_ID

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/extended'

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
    $AuthTokensFromFile = Get-AuthTokensFromFile

    $response = Get-PagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
    $response
}