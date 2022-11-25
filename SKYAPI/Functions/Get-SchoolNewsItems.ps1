# https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentNewsItemsGet
# Returns a collection of Content News Items.
# Requires the 'Parent', 'Faculty' or 'Student' role in the K12 system.

# Parameter,Required,Type,Description
# categories,no,string,comma-separated string of category IDs


function Get-SchoolNewsItems
{ 
    [cmdletbinding()]
    param(
        [parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$categories # This doesn't need to be an array since the parameter takes comma-separated values by default.
    )

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/content/news/items'

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
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-UnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}