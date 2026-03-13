function Connect-SchoolUserBBID
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=afe-edcor&operation=V1UsersBbidConnectPatch
        
        .SYNOPSIS
        Education Management Education Core API - Connects a set of Blackbaud ID (BBID) accounts.

        .DESCRIPTION
        Education Management Education Core API - Connects a set of Blackbaud ID (BBID) accounts.
        If an Education Management account is already connected to a BBID account, it will reconnect with the submitted email if it is different than the currently connected email.

        Requires at least one of the following roles in the Education Management system:
          - Platform Manager
          - Admissions Manager

        .PARAMETER id
        Used for a SINGLE connection request when providing parameters directly.
        The user ID to connect to a BBID account. Required when not using the 'ConnectionRequest' parameter.
        .PARAMETER email
        Used for a SINGLE connection request when providing parameters directly.
        The email to use for the BBID. If not specified, the contact email will be used if present (if not, an error is returned).
        .PARAMETER send_invite
        Used for a SINGLE connection request when providing parameters directly.
        Specifies whether to send an invite email to the user. If not specified, the default behavior is to not send an invite.
        .PARAMETER ConnectionRequest
        Used to submit one or more connection requests as Hashtable/PSCustomObject(s).
        - Each request must contain an id (int) and may include email (string) and send_invite (bool).
        - If passed as an array via -ConnectionRequest, all requests are sent in one API call.
        - If provided via the pipeline, each piped object is processed as it is received (one API call per object).
        .EXAMPLE
        # Single example: use user's already existing email address.
        Connect-SchoolUserBBID -id 5809872
        .EXAMPLE
        # Single example: specify an email address and choose to send an invitation.
        Connect-SchoolUserBBID -id 5809872 -email 'example@school.edu' -send_invite $true
        .EXAMPLE
        # Multi example: array of hashtables using 'ConnectionRequest' parameter.
        $UsersHashtable = @(
            @{
                id          = 101101
            },
            @{
                id          = 103103
                email       = 'carol@school.edu'
                send_invite = $true
            }
        )
        Connect-SchoolUserBBID -ConnectionRequest $UsersHashtable
        .EXAMPLE
        # Multi example: array of hashtables using pipeline.
        $UsersHashtable = @(
            @{
                id          = 101101
            },
            @{
                id          = 103103
                email       = 'carol@school.edu'
                send_invite = $true
            }
        )
        $UsersHashtable | Connect-SchoolUserBBID
        .EXAMPLE
        # Multi example: array of PSCustomObjects using 'ConnectionRequest' parameter.
        $UsersPSObject = @(
            [PSCustomObject]@{
                id          = 101101
            },
            [PSCustomObject]@{
                id          = 103103
                email       = 'carol@school.edu'
                send_invite = $true
            }
        )
        Connect-SchoolUserBBID -ConnectionRequest $UsersPSObject
        .EXAMPLE
        # Multi example: array of PSCustomObjects using pipeline.
        $UsersPSObject = @(
            [PSCustomObject]@{
                id          = 101101
            },
            [PSCustomObject]@{
                id          = 103103
                email       = 'carol@school.edu'
                send_invite = $true
            }
        )
        $UsersPSObject | Connect-SchoolUserBBID
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        ParameterSetName = 'SingleConnectionRequest',
        Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Int]$id,

        [Parameter(
        Position=1,
        ParameterSetName = 'SingleConnectionRequest',
        Mandatory=$false)]
        [string]$email,

        [Parameter(
        Position=2,
        ParameterSetName = 'SingleConnectionRequest',
        Mandatory=$false)]
        [bool]$send_invite,

        [Parameter(
        Position=3,
        ParameterSetName = 'ConnectionRequestObject',
        Mandatory=$true,
        ValueFromPipeline=$true)]
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
    
    begin
    {
        # Set the endpoint
        $endpoint = 'https://api.sky.blackbaud.com/afe-edcor/v1/users/bbid/connect'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Create the ConnectionRequest Object
        # https://developer.sky.blackbaud.com/api#api=afe-edcor&operation=V1UsersBbidConnectPatch&definition=ConnectionRequest
        if ($PSCmdlet.ParameterSetName -eq 'SingleConnectionRequest')
        {
            # Set the parameters
            [array]$Parameters = ,([ordered]@{ id = $id; email = $email; send_invite = $send_invite })
        }
        else
        {
            [array]$Parameters = foreach ($conRequest in $ConnectionRequest)
            {
                switch ($conRequest.GetType().Name)
                {
                    Hashtable { $SingleConnectionParametersHashtable = $conRequest }
                    PSCustomObject { # Convert the PSCustomObject to a hashtable.
                        $SingleConnectionParametersHashtable = @{} # Just in case the following errors out.
                        $SingleConnectionParametersHashtable = [ordered]@{id = $conRequest.id; email = $conRequest.email; send_invite = $conRequest.send_invite }
                    }
                    Default { throw "Unexpected error processing ConnectionRequest object of type $($conRequest.GetType().Name). All elements in the array must be either a hashtable or a PSCustomObject."}
                }

                # Output to the $Parameters array.
                $SingleConnectionParametersHashtable
            }
        }
        
        # Send the API request.
        $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $Parameters
        $response
    }

    end {}
}
