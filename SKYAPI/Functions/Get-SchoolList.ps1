# https://developer.sky.blackbaud.com/docs/services/school/operations/V1ListsAdvancedByList_idGet
# Returns a paginated collection of results from a basic or advanced list.
# The page size is 1000 rows.
# This is an alias for the deprecated 'Get-SchoolLegacyList' endpoint and is backwards compatible (https://developer.sky.blackbaud.com/docs/services/school/operations/V1LegacyListsByList_idGet).

# Parameter,Required,Type,Description
# list_id,yes,string,Comma delimited list of base role IDs to get users for.
# Page,no,integer,Results will start with this user in the result set.
# ResponseLimit,no,integer,Limits response to this number of results.

function Get-SchoolList
{
    [cmdletbinding()]
    param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$List_ID, # Array as we loop through submitted IDs. Enpoint only takes one item and cannot handle comma-separated values.
       
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$Page,

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    $PageLimit = 1000

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/lists/advanced/'

    # Set the response field
    $ResponseField = "results.rows"
    
    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Set/Replace Page parameter to 1 if not set or 0. That way it can do pagination properly.
    if ($null -eq $Page -or $Page -eq '' -or $Page -eq 0)
    {
        $parameters.Remove('Page') | Out-Null
        [int]$Page = 1
        $parameters.Add('Page',$Page)
    }

    # Remove the $List_ID parameter since it is passed on in the URL
    $parameters.Remove('List_ID') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile

    # Get data for one or more IDs
    foreach ($id in $List_ID)
    {
        $endpointWithListID = $endpoint + $id.ToString()
        $response = Get-PagedEntity -url $endpointWithListID -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit
        $response
    }
}