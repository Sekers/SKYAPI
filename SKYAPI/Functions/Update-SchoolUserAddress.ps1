function Update-SchoolUserAddress
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idAddressesByAddress_idPatch
        
        .SYNOPSIS
        Education Management School API - Updates the address record of a user. Returns the ID of the address just updated upon success.

        .DESCRIPTION
        Education Management School API - pdates the address record of a user. Returns the ID of the address just updated upon success.
        Requires at least one of the following roles in the Education Management system:
          - SKY API Data Sync

        .PARAMETER user_id
        Required. User ID for the user you want to update the address of.
        .PARAMETER address_id
        Required. The ID of the address to be updated.
        .PARAMETER type_id
        The type ID of the specified address. The type ID corresponds with the type of address (ex. Business/College, Home, Summer).
        Use Get-SchoolUserAddressType to get a list of address types.
        .PARAMETER country
        Country full name (e.g., United States). Must be a full country name from the school's list of countries.
        .PARAMETER line_one
        Address Line 1 (e.g., 123 Main Street).
        .PARAMETER line_two
        Address Line 2 (e.g., Suite 100).
        .PARAMETER line_three
        Address Line 3.
        .PARAMETER city
        City (e.g., Charelston).
        .PARAMETER state
        State 2-letter abbreviation (e.g., SC) or full name. Available only with country choices that use states.
        .PARAMETER postal_code
        Postal code.
        .PARAMETER province
        Province. Available only with country choices that use provinces.
        .PARAMETER region
        Region.
        .PARAMETER mailing_address
        Set to true to set this address as a mailing address. A user can have multiple mailing addresses.
        .PARAMETER primary
        Set to true to make this the primary address. A user can have only one primary address.






        .EXAMPLE
        Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
        .EXAMPLE
        Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$user_id,

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$address_id,

        [Parameter( 
        Position=2,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$type_id,

        [Parameter( 
        Position=3,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$country,

        [Parameter( 
        Position=4,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_one,

        [Parameter( 
        Position=5,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_two,

        [Parameter( 
        Position=6,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_three,

        [Parameter( 
        Position=7,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$city,

        [Parameter( 
        Position=8,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$state,

        [Parameter( 
        Position=9,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$postal_code,

        [Parameter( 
        Position=10,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$province,

        [Parameter( 
        Position=11,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$region
    )
    
    throw "Sorry, the function for this endpoint is not currently available. It will be made available in a future release."

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = "/addresses/$($address_id)"

    # Set the parameters
    $parameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the Address ID parameter since we don't pass it on this way.
    $parameters.Remove('address_id') | Out-Null



    $parameters.Remove('user_id') | Out-Null

    # # Add the Address ID in the way the endpoint wants.
    #  $parameters.Add('id',$address_id)

    # Build AddressTypeLink Model
    # No related users to link so create array with one empty object (otherwise the API returns an error).
    
        # $AddressTypeLink = [PSCustomObject]@{}
        # [array]$AddressTypeLinks = @($AddressTypeLink)
        # $parameters.Add('links',$AddressTypeLinks) 
    

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set data for one or more IDs

    # DO I REALLY NEED TO DO THIS? WHY DID I DO IT FOR THE OTHER UPDATE? THE FOREACH?
    [hashtable]$uid_parameters = $parameters.Clone()
    $uid_parameters.Add('id',$address_id)


    $response = Update-SKYAPIEntity -url $endpoint -uid $user_id -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $uid_parameters
    $response
}
