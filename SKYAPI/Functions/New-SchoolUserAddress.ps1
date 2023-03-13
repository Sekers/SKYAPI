function New-SchoolUserAddress
{ 
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idAddressesPost
        
        .SYNOPSIS
        Education Management School API - Creates a new address record for the specified user IDs and returns the ID of the address created.

        .DESCRIPTION
        Education Management School API - Creates a new address record for the specified user IDs and returns the ID of the address created.

        .PARAMETER User_ID,
        Required. Array of the user IDs.
        .PARAMETER type_id
        Required. The type ID of the specified address. The type ID corresponds with the type of address (ex. Business/College, Home, Summer).
        Use Get-SchoolUserAddressType to get a list of address types.
        .PARAMETER country
        Required. Country full name (e.g., United States). Must be a full country name from the school's list of countries.
        .PARAMETER line_one
        Required. Address Line 1 (e.g., 123 Main Street).
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
        New-SchoolUserAddress -User_ID 3156271 -type_id 1005 -country 'United States' -line_one '129 Huntington Drive'
        .EXAMPLE
        $params = @{
            'User_ID'             = 3156271
            'type_id'             = 1005
            'country'             = "United States"
            'line_one'            = "129 Huntington Drive"
            'line_two'            = "Unit 406"
            'line_three'          = "Lower Level"
            'city'                = "Chicago"
            'state'               = "IL"
            'postal_code'         = "60601"
            'province'            = "Angus"
            'region'              = "North Central"
            'mailing_address'     = $true
            'primary'             = $true
        }
        New-SchoolUserAddress @params
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
        [int]$type_id,

        [Parameter( 
        Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$country,

        [Parameter( 
        Position=3,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_one,

        [Parameter( 
        Position=4,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_two,

        [Parameter( 
        Position=5,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_three,

        [Parameter( 
        Position=6,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$city,

        [Parameter( 
        Position=7,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$state,

        [Parameter( 
        Position=8,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$postal_code,

        [Parameter( 
        Position=9,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$province,

        [Parameter( 
        Position=10,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$region,

        [Parameter( 
        Position=11,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$mailing_address,

        [Parameter( 
        Position=12,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$primary
    )

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/addresses'

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

    # Verify the address type doesn't already exists for any of the users.
    foreach ($uid in $User_ID)
    {
        $UserAddresses = Get-SchoolUserAddress -User_ID $uid
        if ($UserAddresses.type_id -contains $type_id)
        {
            throw "User $uid already has address of type id $type_id"
        }
    }
    
    # Set data for one or more IDs
    foreach ($uid in $User_ID)
    {
        # Clear out old user_id parameter and add in new. NO IDEA WHY THEY NEED THIS IN THE REQUEST BODY AS IT'S PART OF THE ENDPOINT URL.
        $parameters.Remove('user_id') | Out-Null
        $parameters.Add('user_id',$uid) 

        $response = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
