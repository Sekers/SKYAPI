function Get-SchoolSectionBySchoolLevel
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of academic sections based on school level.

        .DESCRIPTION
        Education Management School API - Returns a collection of academic sections based on school level.

        .PARAMETER Level_Number
        Required. Array of school level IDs for each school level you want sections for returned.
        Use Get-SchoolLevel to get a list of school levels.
        .PARAMETER school_year
        The school year to get sections for. Defaults to the current school year if not specified.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolSectionBySchoolLevel -Level_Number 228,229
        .EXAMPLE
        Get-SchoolSectionBySchoolLevel -Level_Number 229 -school_year "2019-2020"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Level_Number, # Array as we loop through submitted IDs

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/sections'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove parameters since we don't pass them on this way
    $parameters.Remove('Level_Number') | Out-Null
    $parameters.Remove('ReturnRaw') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more school levels
    foreach ($level_num in $Level_Number)
    {
        # Clear out old school level parameter and add in new
        $parameters.Remove('level_num') | Out-Null
        $parameters.Add('level_num',$level_num) 
        
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
