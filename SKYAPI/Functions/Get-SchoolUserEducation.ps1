# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idEducationGet
# Education list 

# Parameter,Required,Type,Description
# User_ID,yes,integer,Comma-delimited list of user IDs for each user you want returned.

function Get-SchoolUserEducation
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID # Array as we loop through submitted IDs. Enpoint only takes one item and cannot handle comma-separated values.
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/education'

    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more school levels
    foreach ($uid in $User_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
