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
        Used for a SINGLE connection request or MULTIPLE connection requests from the pipeline. The user ID to connect to a BBID account.
        .PARAMETER email
        Used for a SINGLE connection request or from the pipeline. The email to use for the BBID. If blank, the contact email will be used, if present. If not, an error is returned.
        .PARAMETER ConnectionRequest
        Used to submit MULTIPLE connection requests at the same time with or without using the pipeline using an array. Must be an array of hashtables and/or PSCustomObjects, each containing an 'id' property (int) and optionally an 'email' property (string).
        If 'email' is not provided for a given object, the contact email will be used, if present. If not, an error is returned.

        .EXAMPLE
        # Single example: use user's already existing email address.
        Connect-SchoolUserBBID -id 5809872
        .EXAMPLE
        # Single example: specify an email address.
        Connect-SchoolUserBBID -id 5809872 -email 'example@school.edu'
        .EXAMPLE
        # Multi example: array of hashtables using 'ConnectionRequest' parameter.
        $UsersHashtable = @(
            @{
                id    = 101101
            },
            @{
                id    = 103103
                email = 'carol@school.edu'
            }
        )
        Connect-SchoolUserBBID -ConnectionRequest $UsersHashtable
        .EXAMPLE
        # Multi example: array of hashtables using pipeline.
        $UsersHashtable = @(
            @{
                id    = 101101
            },
            @{
                id    = 103103
                email = 'carol@school.edu'
            }
        )
        $UsersHashtable | Connect-SchoolUserBBID
        .EXAMPLE
        # Multi example: array of PSCustomObjects using 'ConnectionRequest' parameter.
        $UsersPSObject = @(
            [PSCustomObject]@{
                id    = 101101
            },
            [PSCustomObject]@{
                id    = 103103
                email = 'carol@school.edu'
            }
        )
        Connect-SchoolUserBBID -ConnectionRequest $UsersPSObject
        .EXAMPLE
        # Multi example: array of PSCustomObjects using pipeline.
        $UsersPSObject = @(
            [PSCustomObject]@{
                id    = 101101
            },
            [PSCustomObject]@{
                id    = 103103
                email = 'carol@school.edu'
            }
        )
        $UsersPSObject | Connect-SchoolUserBBID
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
            [array]$Parameters = @{id = $id; email = $email }
        }
        else
        {
            foreach ($conRequest in $ConnectionRequest)
            {
                switch ($conRequest.GetType().Name)
                {
                    Hashtable { $Parameters = $conRequest }
                    PSCustomObject { # Convert the PSCustomObject to a hashtable.
                        $Parameters = @{}
                        $Parameters = @{id = $conRequest.id; email = $conRequest.email } # TODO: Test if allowing a $null email works once the endpoint is opened up for everyone.
                    }
                    Default { throw "Unexpected error processing ConnectionRequest object of type $($conRequest.GetType().Name). All elements in the array must be either a hashtable or a PSCustomObject."}
                }

                $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $Parameters
                $response
            }
        }
    }

    end {}
}
