function Get-SchoolTypeTableValue
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1TypesTablevaluesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of table values.

        .DESCRIPTION
        Education Management School API - Returns a collection of table values.
        Either tableId or tableName parameter is required, but not both. For example, If a tableId is provided, then any value provided for tableName will be ignored.
        In the case that the calling user does not have permissions to view the data being requested no results will be returned.

        .PARAMETER tableId
        The ID of the table type. The tableId is returned by Types table types (Get-SchoolTypeTable) or from the settings area for the table within Blackbaud Education Management.
        Either tableId or tableName parameter is required, but not both. For example, If a tableId is provided, then any value provided for tableName will be ignored.
        In the case that the calling user does not have permissions to view the data being requested no results will be returned.
        .PARAMETER tableId
        The name of the table type. The name is returned by Types table types (Get-SchoolTypeTable) or from the settings area for the table within Blackbaud Education Management.
        Either tableId or tableName parameter is required, but not both. For example, If a tableId is provided, then any value provided for tableName will be ignored.
        In the case that the calling user does not have permissions to view the data being requested no results will be returned.
        .PARAMETER includeInactive
        If set to true, returns inactive items for the table. Defaults to false.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolTypeTableValue -tableID 4
        .EXAMPLE
        Get-SchoolTypeTableValue -tableName 'Citizenship'
        .EXAMPLE
        Get-SchoolTypeTableValue -tableName 'Citizenship' -includeInactive $true
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'tableId',
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$tableId,

        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'tableName',
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$tableName,

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$includeInactive,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/types/tablevalues'

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
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
        return $response
    }
    
    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    $response
}
