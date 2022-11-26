# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost
# Creates a new phone record for the specified user_id and returns the ID of the phone number created.

# Parameter,Required,Type,Description
# User_ID,yes,int,Comma delimited list of the user IDs.
# number,yes,string,The phone number.
# type_id,yes,int,The type ID of the specified phone number. The type ID corresponds with the type of phone number (ex. Cell, Work, Home).
# links,no,array of objects,Each PSObject should match the PhoneTypeLink Model (https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost#PhoneTypeLink).
# Schema:
#    "links": [
#        {
#        "id": 0,
#        "shared": true,
#        "shared_relationship": "string",
#        "shared_user": "string",
#        "type_id": "string",
#        "user_id": 0
#        }
#    ]

function New-SchoolUserPhone
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        #Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$number,

        [Parameter(
        #Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$type_id,

        [Parameter(
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
        $response = Submit-Entity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
