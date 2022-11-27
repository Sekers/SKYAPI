Function Connect-SKYAPI
{
    [CmdletBinding(DefaultParameterSetName='NoParameters')]
    param(
        [parameter(
        Position=0,
        ParameterSetName = 'ForceReauthentication',
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$ForceReauthentication,

        [parameter(
        Position=1,
        ParameterSetName = 'ForceRefresh',
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$ForceRefresh,

        [parameter(
        Position=2,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('EdgeWebView2','MiniHTTPServer',"LegacyIEControl")]
        [string]$AuthenticationMethod,

        [parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$ReturnConnectionInfo
    )

    DynamicParam
    {
        # Initialize Parameter Dictionary
        $ParameterDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        
        # Make -ClearBrowserControlCache Parameter Only Appear if ForceReauthentication is Used
        # DynamicParameter1: ClearBrowserControlCache
        if ($ForceReauthentication)
        { 
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ParameterSetName = "ForceReauthentication"
                Mandatory = $false
                ValueFromPipeline = $true
                ValueFromPipelineByPropertyName = $true
            }

            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $AttributeCollection.Add($ParameterAttributes)

            $DynamicParameter1 = [System.Management.Automation.RuntimeDefinedParameter]::new(
                'ClearBrowserControlCache', [switch], $AttributeCollection)

            $ParameterDictionary.Add('ClearBrowserControlCache', $DynamicParameter1)
        }

        return $ParameterDictionary
    }
    
    begin
    {
        $ClearBrowserControlCache = $PSBoundParameters['ClearBrowserControlCache']
    }

    process
    {
        # Set the Necesasary Configuration Variables
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $client_id = $sky_api_config.client_id
        $client_secret = $sky_api_config.client_secret
        $redirect_uri = $sky_api_config.redirect_uri
        $token_uri = $sky_api_config.token_uri

        # If Key File Does Not Exist or the -ForceReauthentication Parameter is Set, Ask User to Reauthenticate
        if ((-not (Test-Path $sky_api_tokens_file_path)) -or ($ForceReauthentication))
        {
            Get-SKYAPINewTokens -sky_api_tokens_file_path $sky_api_tokens_file_path -AuthenticationMethod $AuthenticationMethod -ClearBrowserControlCache:$ClearBrowserControlCache
        }

        # Get Tokens & Set Creation Times
        try
        {
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $refresh_token_creation = $AuthTokensFromFile.refresh_token_creation
            $access_token_creation = $AuthTokensFromFile.access_token_creation    
        }
        catch
        {
            throw "Key JSON tokens file is corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
        }

        # If Refresh Token Has Expired Because it Hasn't Been Used for Max Refresh Token Timespan, Ask User to Reauthenticate
        if (-not (Confirm-SKYAPITokenIsFresh -TokenCreation $refresh_token_creation -TokenType Refresh))
        {
            Get-SKYAPINewTokens -sky_api_tokens_file_path $sky_api_tokens_file_path -AuthenticationMethod $AuthenticationMethod -ClearBrowserControlCache:$ClearBrowserControlCache

            # Get Tokens & Set Creation Times
            try
            {
                $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
                $refresh_token_creation = $AuthTokensFromFile.refresh_token_creation
                $access_token_creation = $AuthTokensFromFile.access_token_creation    
            }
            catch
            {
                throw "Key JSON tokens file is corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
            }
        }

        # If the Access Token Expired OR the -ForceRefresh Parameter is Set, Then Refresh Access Token      
        if ((-not (Confirm-SKYAPITokenIsFresh -TokenCreation $access_token_creation -TokenType Access)) -or ($ForceRefresh))
        {
            # Run Invoke Command and Catch Responses
            [int]$InvokeCount = 0
            [int]$MaxInvokeCount = 5
            do
            {      
                $InvokeCount += 1
                $NextAction = $null
                try
                {
                    # Swap Refresh token for an Access token (which when requested returns both refresh and access tokens)
                    $Authorization = Get-SKYAPIAccessToken -grant_type 'refresh_token' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $($AuthTokensFromFile.refresh_token) -token_uri $token_uri
                }
                catch
                {
                    # Process Invoke Error
                    $LastCaughtError = ($_)
                    $NextAction = SKYAPICatchInvokeErrors($_)

                    # Just in case the token was refreshed by the error catcher, update the $AuthTokensFromFile variable
                    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
                }
            }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

            if ($InvokeCount -ge $MaxInvokeCount)
            {
                Write-Warning $("Invoke tried running $InvokeCount times, but failed each time. " `
                + "It is possible that the Key JSON tokens file is corrupted or invalid. Try running Connect-SKYAPI with the -ForceReauthentication parameter to recreate it.")
                throw $LastCaughtError
            }
                
                # Save credentials to file
                $Authorization | ConvertTo-Json `
                    | ConvertTo-SecureString -AsPlainText -Force `
                    | ConvertFrom-SecureString `
                    | Out-File -FilePath $sky_api_tokens_file_path -Force
        }

        # Return the connection information, if requested.
        if ($ReturnConnectionInfo)
        {  
            # Collect the non-sensitive session information.
            # More info on these items here: https://developer.blackbaud.com/skyapi/docs/authorization/auth-code-flow/tutorial
            $ObjectPropertyNames = @(
                'environment_id'
                'environment_name'
                'legal_entity_id'
                'legal_entity_name'
                'user_id'
                'email'
                'family_name'
                'given_name'
                'mode'
                'refresh_token_creation'
                'access_token_creation'
            )
            Get-SKYAPIAuthTokensFromFile | Select-Object $ObjectPropertyNames
        }
    }
}