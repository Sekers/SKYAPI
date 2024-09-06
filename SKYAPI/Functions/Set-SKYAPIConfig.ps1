# TODO Encrypted option sky API config
function Set-SKYAPIConfig
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .SYNOPSIS
        Set the configurations and secrets to connect to your Blackbaud SKY API application.

        .DESCRIPTION
        Set the configurations and secrets to connect to your Blackbaud SKY API application.

        .PARAMETER api_subscription_key
        Blackbaud requires you to have an approved subscription key to a specific API before you can use the
        SKY API console. This subscription key is associated with your Blackbaud developer account.
        .PARAMETER client_id
        The Application ID, also known as the OAuth client_id, is the unique identifier for the application
        and connects the application to customer environments. The value is not sensitive.
        .PARAMETER client_secret
        The Application secret, also known as the OAuth client_secret, is a sensitive value that is used when
        requesting an access token to call SKY API during the authorization process for the authorization code
        grant type. As with subscription keys, the Application secret should be kept secure and treated like a password.
        .PARAMETER redirect_uri
        Location where the authorization server sends the user once the app has been successfully authorized.
        Default is http://localhost:5000/auth/callback
        .PARAMETER authorize_uri
        OAuth 2.0 endpoint for Authorization.
        Default is https://app.blackbaud.com/oauth/authorize
        .PARAMETER token_uri
        OAuth 2.0 endpoint for Token refreshes.
        Default is https://oauth2.sky.blackbaud.com/token

        .EXAMPLE
        Set-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        .EXAMPLE
        Set-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json' -api_subscription_key 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
        .EXAMPLE
        Set-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json' -Silent -api_subscription_key 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath = $sky_api_config_file_path, # If not entered will try to pull path from this variable.

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$Silent, # Only update configuration values passed to the function. Do not prompt for manual entry.

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$api_subscription_key,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$client_id,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$client_secret,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$redirect_uri,

        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$authorize_uri,

        [Parameter(
        Position=7,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$token_uri
    )

    # Get Parameters for Later Use
    $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
    [array]$ParameterVariables = foreach ($ParameterObject in $ParameterList)
    {
        Get-Variable -Name $ParameterObject.Values.Name -ErrorAction SilentlyContinue;
    }

    # Make Sure Requested Path Isn't Null or Empty
    if ([string]::IsNullOrEmpty($ConfigPath))
    {
        throw "Cannot validate argument on parameter `'ConfigPath`'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
    }

    # Test If Config File Already Exists. If Not, Create it.
    try
    {
        $sky_api_config = Get-Content -Path $ConfigPath -ErrorAction 'Stop' |
            ConvertFrom-Json
        Write-Host "An existing `'sky_api_config.json`' file already exists in this location."
    }
    catch
    {
        Write-Host "An existing `'sky_api_config.json`' file does not exist in this location or file is improperly formatted. Creating new configuration file."
        
        $ConfigTemplate = [PSCustomObject]@{
            api_subscription_key    = ''
            client_id               = ''
            client_secret           = ''
            redirect_uri            = 'http://localhost:5000/auth/callback'
            authorize_uri           = 'https://app.blackbaud.com/oauth/authorize'
            token_uri               = 'https://oauth2.sky.blackbaud.com/token'
        }
              
        $ConfigTemplate | Select-Object api_subscription_key, client_id, client_secret, redirect_uri, authorize_uri, token_uri `
        | ConvertTo-Json `
        | Out-File -FilePath $ConfigPath -Force

        $sky_api_config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    }

    # Update Variables From File If Nothing Passed By the Parameter.
    if ([string]::IsNullOrEmpty($api_subscription_key))
    {
        $api_subscription_key = $sky_api_config.api_subscription_key
    }
    if ([string]::IsNullOrEmpty($client_id))
    {
        $client_id = $sky_api_config.client_id
    }
    if ([string]::IsNullOrEmpty($client_secret))
    {
        $client_secret = $sky_api_config.client_secret
    }
    if ([string]::IsNullOrEmpty($redirect_uri))
    {
        $redirect_uri = $sky_api_config.redirect_uri
    }
    if ([string]::IsNullOrEmpty($authorize_uri))
    {
        $authorize_uri = $sky_api_config.authorize_uri
    }
    if ([string]::IsNullOrEmpty($token_uri))
    {
        $token_uri = $sky_api_config.token_uri
    }


    if (-not $Silent)
    {
        # Grab All the Parameters Used in the JSON File (All parameters Except Silent & ConfigPath) and Prompt For New Values.
        foreach ($Variable in ($ParameterVariables).Where({($_.Name -ne 'Silent') -and ($_.Name -ne 'ConfigPath')}))
        {
            ## DEBUG LINE
            # Write-Host "$($Variable.Name) is $($Variable.Value)"

            # Prompt for Value Changes
            if ([string]::IsNullOrEmpty($Variable.Value))
            {
                $PromptValue = Read-Host -Prompt "Enter value for `'$($Variable.Name)`'"
            }
            else
            {
                $PromptValue = Read-Host -Prompt "Enter value for `'$($Variable.Name)`' or leave blank to keep current value [$($Variable.Value)]"
            }

            # If Not Empty Update Variable Value
            if (-not [string]::IsNullOrEmpty($PromptValue))
            {
                $Variable.Value = $PromptValue
            } 
        }
        
    }

    $updated_sky_api_config = [PSCustomObject]@{
        api_subscription_key    = $api_subscription_key
        client_id               = $client_id
        client_secret           = $client_secret
        redirect_uri            = $redirect_uri
        authorize_uri           = $authorize_uri
        token_uri               = $token_uri
    }

    # Write New Config File
    $updated_sky_api_config | Select-Object api_subscription_key, client_id, client_secret, redirect_uri, authorize_uri, token_uri `
    | ConvertTo-Json `
    | Out-File -FilePath $ConfigPath -Force
}