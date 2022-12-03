function Get-SchoolUserBBIDStatus
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersBbidstatusGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of users of the specified base role(s) with their Education Management Blackbaud ID (BBID) status.

        .DESCRIPTION
        Education Management School API - Returns a collection of users of the specified base role(s) with their Education Management Blackbaud ID (BBID) status.
        Note that this takes BASE ROLE IDs and not roles. So a person might show up in the Staff list even if they are not in the Staff role
        because they are in the "Admin Team" roll which has the same base_roll_id as Staff.
        Use Get-SchoolRole to get a list of base roles.

        .PARAMETER base_role_ids
        Required. Comma delimited list of base role IDs to get user BBID status for.
        Note: This parameter is passed on directly to the API endpoint and should be a string, not an array.
        .PARAMETER marker
        Results will start with the user AFTER the specified user's ID in the result set.
        .PARAMETER ResponseLimit
        Limits response to this number of results.

        .EXAMPLE
        Get-SchoolUserBBIDStatus -Base_Role_Ids "332,15,14"
        .EXAMPLE
        Get-SchoolUserBBIDStatus -Base_Role_Ids "332,15,14" | Where-Object {@('0','0') -Contains $_.status_id} | Select-Object -Property id, name, username, email, status
    #>
    
    [cmdletbinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$base_role_ids, # This doesn't need to be an array since the parameter takes comma-separated values by default.
       
        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$marker,

        [parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    $PageLimit = 1000

    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::LAST_USER_ID

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/bbidstatus?base_role_ids='

    # Set the response field
    $ResponseField = "value"
    
    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the ResponseLimit parameter since it is handled differently.
    $parameters.Remove('ResponseLimit') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-SKYAPIPagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
    $response
}