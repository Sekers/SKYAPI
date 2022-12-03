function New-SchoolUserPhone
{ 
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost
        
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
        .PARAMETER links
        Optional array of PhoneTypeLink objects for linking. Each PSObject should match the PhoneTypeLink Model.
        More Info: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost#PhoneTypeLink
        Schema:
           "links": [
               {
               "id": 0,
               "shared": true,
               "shared_relationship": "string",
               "shared_user": "string",
               "type_id": "string",
               "user_id": 0
               }
           ]

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
        [int]$type_id,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [array]$links # Optional array of PhoneTypeLink objects for linking.
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

    # Build PhoneTypeLink Model
    if ($links.Count -ge 1)
    {
        #TODO Verify PhoneTypeLinks Format (this functionality isn't working yet so I don't know what needs to be done to verify)
        foreach ($PhoneTypeLink in $links)
        {
            # $($PhoneTypeLink | Get-Member -MemberType NoteProperty).count
            throw "Sorry. Using SKY API to link phone numbers between users doesn't currently work. Blackbaud is aware of the issue with this endpoint and is looking into it."
        }
    }
    else # No related users to link so create array with one empty object (otherwise the API returns an error).
    {
        $PhoneTypeLink = [PSCustomObject]@{}
        [array]$PhoneTypeLinks = @($PhoneTypeLink)
        $parameters.Add('links',$PhoneTypeLinks) 
    }

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
