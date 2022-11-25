# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesGet
# Returns a collection phone numbers for one or more user IDs.

# Parameter,Required,Type,Description
# User_ID,yes,int,Comma delimited list of user IDs for each user you want returned.

function Get-SchoolUserPhoneList
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID # Array as we loop through submitted IDs
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/phones'

    # Set the response field
    $ResponseField = "value"

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
