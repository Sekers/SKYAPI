# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersExtendedByUser_idGet
# Get extended user details for one or more user IDs.

# Parameter,Required,Type,Description
# User_ID,yes,int,Comma delimited list of user IDs for each user you want returned.

function Get-SchoolUserExtended
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
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/extended/'

    # Get data for one or more IDs
    foreach ($uid in $User_ID)
    {
        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile
        $response
    }
}
