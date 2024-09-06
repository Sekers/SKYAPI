function Get-SchoolTerm
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=v1termsget
        
        .SYNOPSIS
        Education Management School API - Returns a list of terms.

        .DESCRIPTION
        Education Management School API - Returns a list of terms.

        .PARAMETER school_year
        The school year to get terms for. Defaults to the current school year if not specified.
        .PARAMETER offering_type
        The offering type ID to filter terms by.
        Use Get-SchoolOfferingType to get a list of offering type IDs.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolTerm
        .EXAMPLE
        Get-SchoolTerm -school_year '2021-2022'
        .EXAMPLE
        Note: offering_type 1 is Academics
        Get-SchoolTerm -offering_type 1 | Select-Object description
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$offering_type,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/terms'

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
