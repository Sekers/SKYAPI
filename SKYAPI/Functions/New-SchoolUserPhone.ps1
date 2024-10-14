function New-SchoolUserPhone
{ 
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idPhonesPost
        
        .SYNOPSIS
        Education Management School API - Creates a new phone record for the specified user IDs and returns the ID of the phone number created.

        .DESCRIPTION
        Education Management School API - Creates a new phone record for the specified user IDs and returns the ID of the phone number created.

        .PARAMETER User_ID,
        Required. Array of the user IDs.
        .PARAMETER number
        Required. The phone number.
        .PARAMETER type_id
        Required. The type ID of the specified phone number. The type ID corresponds with the type of phone number (ex. Cell, Work, Home).
        Use Get-SchoolUserPhoneType to get a list of phone types.

        .EXAMPLE
        New-SchoolUserPhone -User_ID 3154032,5942642 -number "(555) 555-5555" -type_id 331
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$number,

        [Parameter( 
        Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$type_id
    )

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/phones'

    # Set the parameters
    $parameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the $User_ID parameter since we don't pass that on
    $parameters.Remove('User_ID') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Verify the phone number type doesn't already exists for any of the users.
    foreach ($uid in $User_ID)
    {
        $UserPhoneNumbers = Get-SchoolUserPhone -User_ID $uid
        if ($UserPhoneNumbers.type_id -contains $type_id)
        {
            throw "User $uid already has phone number of type id $type_id"
        }
    }
    
    # Set data for one or more IDs
    foreach ($uid in $User_ID)
    {      
        $response = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
