# https://developer.sky.blackbaud.com/docs/services/school/operations/V1LegacyListsByList_idGet
# Returns the results from a legacy basic or advanced list.
# Note: List must have access permissions enabled for the SKY API role or the user giving OAuth consent.Requires the 'Page Manager', 'Content Editor', 'Teacher', 'Coach', 'Community Group Manager', 'Mentor Manager', 'Alumni Group Manager', 'Athletic Group Manager', 'Academic Group Manager', 'System Group Manager', 'Content Manager', 'Community Group Owner', 'Dorm Group Manager', 'Activity Group Manager', 'Advisory Group Manager', 'Advisor', 'Dorm Supervisor', 'Activity Leader', 'Pending Teacher', 'Pending Advisor', 'Pending Dorm Supervisor' or 'Pending Activity Leader' role in the K12 system.

# Parameter,Required,Type,Description
# List_ID,yes,string,Comma delimited list of user IDs for each user you want returned.

function Get-SchoolLegacyList
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$List_ID # Array as we loop through submitted IDs. Enpoint only takes one item and cannot handle comma-separated values.
    )
    
    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-AuthTokensFromFile

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/legacy/lists/'

    # Set the response field
    $ResponseField = "rows"

    # Get data for one or more IDs
    foreach ($uid in $List_ID)
    {
        $response = Get-UnpagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
        $response
    }
}
