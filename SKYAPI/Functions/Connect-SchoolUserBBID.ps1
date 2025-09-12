function Connect-SchoolUserBBID
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=afe-edcor&operation=V1UsersBbidConnectPatch
        
        .SYNOPSIS
        Education Management Education Core API - Connects a set of BBID accounts.

        .DESCRIPTION
        Education Management Education Core API - Connects a set of BBID accounts.

        Requires at least one of the following roles in the Education Management system:
          - Platform Manager
          - Admissions Manager

        .PARAMETER id
        Used for a SINGLE connection request. The user ID to connect to a BBID account.
        .PARAMETER email
        Used for a SINGLE connection request. The email to use for the BBID. If blank, the contact email will be used, if present. If not, an error is returned.
        .PARAMETER ConnectionRequest
        Used to submit MULTIPLE connection requests at the same time. Must be an array of hashtables and/or PSCustomObjects, each containing an 'id' property (int) and optionally an 'email' property (string).
        If 'email' is not provided for a given object, the contact email will be used, if present. If not, an error is returned.

        .EXAMPLE
        Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
        .EXAMPLE
        Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ParameterSetName = 'SingleConnectionRequest',
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Int]$id,

        [Parameter(
        Position=1,
        ParameterSetName = 'SingleConnectionRequest',
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,

        [Parameter(
        Position=2,
        ParameterSetName = 'ConnectionRequestObject',
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            # Check if the current object is a Hashtable or a PSCustomObject.
            if (-not ($_.GetType().Name -eq 'Hashtable' -or $_.GetType().Name -eq 'PSCustomObject'))
            {
                throw [System.Management.Automation.ValidationMetadataException]::new("All elements in the array must be either a Hashtable or a PSCustomObject.")
            }
            # Check if the current object has an 'id' property (will check each array item independently).
            if (($null -eq $_.id) -or ($_.id -isnot [int]))
            {
                throw [System.Management.Automation.ValidationMetadataException]::new("All elements in the array must have a valid [Int32]id property.")
            }
            return $true
        })]
        [object[]]$ConnectionRequest # Array of ConnectionRequest objects (will accept either hashtables or PSCustomObjects).
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/afe-edcor/v1/users/bbid/connect'

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Create the ConnectionRequest Object
    # https://developer.sky.blackbaud.com/api#api=afe-edcor&operation=V1UsersBbidConnectPatch&definition=ConnectionRequest
    if ($PSCmdlet.ParameterSetName -eq 'SingleConnectionRequest')
    {
        # Set the parameters
        [array]$Parameters = @{id = $id; email = $email }
    }
    else
    {
        [array]$Parameters = foreach ($conRequest in $ConnectionRequest)
        {
            switch ($conRequest.GetType().Name)
            {
                Hashtable { $conRequest }
                PSCustomObject { # Convert the PSCustomObject to a hashtable.
                    $HashtableOutput = @{}
                    $HashtableOutput = @{id = $conRequest.id; email = $conRequest.email }
                    $HashtableOutput
                }
                Default { throw "Unexpected error processing ConnectionRequest object of type $($conRequest.GetType().Name). All elements in the array must be either a hashtable or a PSCustomObject."}
            }
        }
    }

    $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $Parameters
    $response
}
