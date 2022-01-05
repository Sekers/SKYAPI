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
        [Switch]$ForceRefresh
    )
    
    # Set the Necesasary Configuration Variables
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $client_id = $sky_api_config.client_id
    $client_secret = $sky_api_config.client_secret
    $redirect_uri = $sky_api_config.redirect_uri
    $token_uri = $sky_api_config.token_uri

    # If Key File Does Not Exist or the -ForceReauthentication Parameter is Set, Ask User to Reauthenticate
    if ((-not (Test-Path $sky_api_tokens_file_path)) -or ($ForceReauthentication))
    {
        Get-NewTokens -sky_api_tokens_file_path $sky_api_tokens_file_path
    }

    # Get Tokens & Set Creation Times
    try
    {
        $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
        $refresh_token_creation = $AuthTokensFromFile.refresh_token_creation
        $access_token_creation = $AuthTokensFromFile.access_token_creation    
    }
    catch
    {
        throw "`'Key.json`' token file is corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
    }

    # If Refresh Token Has Expired Because it Hasn't Been Used for Max Refresh Token Timespan, Ask User to Reauthenticate
    if (-not (Confirm-TokenIsFresh -TokenCreation $refresh_token_creation -TokenType Refresh))
    {
        Get-NewTokens -sky_api_tokens_file_path $sky_api_tokens_file_path

        # Get Tokens & Set Creation Times
        try
        {
            $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
            $refresh_token_creation = $AuthTokensFromFile.refresh_token_creation
            $access_token_creation = $AuthTokensFromFile.access_token_creation    
        }
        catch
        {
            throw "`'Key.json`' token file is corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
        }
    }

    # If the Access Token Expired OR the -ForceRefresh Parameter is Set, Then Refresh Access Token      
     if ((-not (Confirm-TokenIsFresh -TokenCreation $access_token_creation -TokenType Access)) -or ($ForceRefresh))
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
                $Authorization = Get-AccessToken -grant_type 'refresh_token' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $($AuthTokensFromFile.refresh_token) -token_uri $token_uri
            }
            catch
            {
                # Process Invoke Error
                $NextAction = CatchInvokeErrors($_)

                # Just in case the token was refreshed by the error catcher, update the $AuthTokensFromFile variable
                $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
            }
        }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

        if ($InvokeCount -ge $MaxInvokeCount)
        {
            throw "Invoke tried running $InvokeCount times, but failed each time.`n" `
            + "It is possible that the `'Key.json`' token file is corrupted or invalid. Try running Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."
        }
            
            # Add Refresh & Access Token expirys to PSCustomObject and Save credentials to file
            $Authorization | Add-Member -MemberType NoteProperty -Name "refresh_token_creation" -Value $((Get-Date).ToUniversalTime().ToString("o")) -Force
            $Authorization | Add-Member -MemberType NoteProperty -Name "access_token_creation" -Value $((Get-Date).ToUniversalTime().ToString("o")) -Force
            $Authorization | Select-Object access_token, refresh_token, refresh_token_creation, access_token_creation | ConvertTo-Json `
                | ConvertTo-SecureString -AsPlainText -Force `
                | ConvertFrom-SecureString `
                | Out-File -FilePath $sky_api_tokens_file_path -Force
    }
}