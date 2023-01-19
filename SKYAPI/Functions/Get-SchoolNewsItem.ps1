function Get-SchoolNewsItem
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentNewsItemsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of Content News Items.

        .DESCRIPTION
        Education Management School API - Returns a collection of Content News Items.
        Requires the 'Parent', 'Faculty' or 'Student' role in the Education Management system.

        .PARAMETER categories
        Comma-separated string of category IDs to optionally filter by.
        Use Get-SchoolNewsCategory to get a list of news categories to filter by.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolNewsItem
        .EXAMPLE
        Get-SchoolNewsItem -categories '12027,3154'
        
    #>
    
    [cmdletbinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$categories, # This doesn't need to be an array since the parameter takes comma-separated values by default.

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
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

    # Remove the $ReturnRaw parameter since we don't pass it on to the API.
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        return $response
    }

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}