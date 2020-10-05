# https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsGet
# Returns a collection of sections based on school level.

# Parameter,Required,Type,Description
# Level_Number,yes,integer,Level number.
# school_year,no,string,The school year to get sections for. Defaults to the current school year.

function Get-SchoolSectionListBySchoolLevel
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Level_Number, # Array as we loop through submitted IDs

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_year
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

    # Remove the $Level_Number parameters since we don't pass them on this way
    $parameters.Remove('Level_Number') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path

    # Get data for one or more school levels
    foreach ($level_num in $Level_Number)
    {
        # Clear out old school level parameter and add in new
        $parameters.Remove('level_num') | Out-Null
        $parameters.Add('level_num',$level_num) 
        
        $response = Get-UnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        $response
    }
}
