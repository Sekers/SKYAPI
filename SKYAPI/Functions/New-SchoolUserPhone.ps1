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
        ValueFromPipelineByPropertyName=$true)]
        [string]$number,

        [Parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$type_id
    )

    begin
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
        $endUrl = '/phones'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Capture the command-line arguments while $PSBoundParameters still holds only those.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the parameters. User_ID is excluded since we don't pass that on. -SuppliedNames keeps fields
        # from one pipeline record out of the next; see Get-SKYAPISuppliedParameterName.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'User_ID' `
                      -SuppliedNames $SuppliedParameter -As Body

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

    end {}
}
