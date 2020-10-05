# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersExtendedGet
# Returns a paginated list of users, limited to 1000 users per page.
# Note that this takes BASE ROLE IDs and not roles. So a persson might show up in the Staff list even if they are not in the Staff role
# because they are in the "Admin Team" roll which has the same base_roll_id as Staff.

# Parameter,Required,Type,Description
# base_role_ids,yes,string,Comma delimited list of base role IDs to get users for.
# Marker,no,integer,Results will start with this user in the result set.
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

    # Set Marker parameter to 1 if not set. That way it can do pagination properly.
    if ($null -eq $Marker -or $Marker -eq '' -or $Marker -eq 0)
    {
        $Marker = 1
        $parameters.Add('Marker',$Marker)
    }

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path

    $response = Get-PagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit
    $response
}