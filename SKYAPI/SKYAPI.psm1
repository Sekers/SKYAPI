# Configure script to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Functions
function Set-SKYAPIConfigFilePath
{
    param (
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$Path
    )
   
    New-Variable -Name 'sky_api_config_file_path' -Value $Path -Scope Global -Force
}

function Set-SKYAPITokensFilePath
{
    param (
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$Path
    )
   
    New-Variable -Name 'sky_api_tokens_file_path' -Value $Path -Scope Global -Force
}

Function Get-SKYAPIAuthToken
{
    [CmdletBinding()]
    param($grant_type,$client_id,$redirect_uri,$client_secret,$authCode,$token_uri)

    #Build token request
    $AuthorizationPostRequest = 'grant_type=' + $grant_type + '&' +
    'redirect_uri=' + [System.Web.HttpUtility]::UrlEncode($redirect_uri) + '&' +
    'client_id=' + $client_id + '&' +
    'client_secret=' + [System.Web.HttpUtility]::UrlEncode($client_secret) + '&' +
    'code=' + $authCode

    $Authorization =
        Invoke-RestMethod   -Method Post `
                            -ContentType application/x-www-form-urlencoded `
                            -Uri $token_uri `
                            -Body $AuthorizationPostRequest
    $Authorization
}

<#
    Get-RefreshToken: Uses the long life (365 days) refresh_token to get a new access_token.
    When you use a refresh token, you'll receive a new short-lived access token (60 minutes)
    that you can use when making subsequent calls to the SKY API.
    Using a refresh token also exchanges the current refresh token for a new one to reset the token life.
#>
Function Get-RefreshToken
{
    [CmdletBinding()]
    param($grant_type,$client_id,$redirect_uri,$client_secret,$authCode,$token_uri)

    #Build token request
    $AuthorizationPostRequest = 'grant_type=' + $grant_type + '&' +
    'redirect_uri=' + [System.Web.HttpUtility]::UrlEncode($redirect_uri) + '&' +
    'client_id=' + $client_id + '&' +
    'client_secret=' + [System.Web.HttpUtility]::UrlEncode($client_secret) + '&' +
    'refresh_token=' + $authCode

    $Authorization =
        Invoke-RestMethod   -Method Post `
                            -ContentType application/x-www-form-urlencoded `
                            -Uri $token_uri `
                            -Body $AuthorizationPostRequest
    $Authorization
}

# Helper to make sure Browser Emulation/Compatibility Mode is Off When Using the WebBrowser Control.
# This function will set the Internet Explorer emulation mode for the running executable. This allows the WebBrowser control to support newer html features and improves compatibility with modern websites.
# Modified from https://www.sapien.com/blog/2020/11/05/a-simple-fix-for-problems-with-windows-forms-webbrowser/ (see also https://bchallis.wordpress.com/2020/10/17/problems-with-the-windows-forms-webbrowser-control-and-a-simple-way-to-fix-it/)
function Set-WebBrowserEmulation
{
	param
	(
		[ValidateNotNullOrEmpty()]
		[string]
		$ExecutableName = [System.IO.Path]::GetFileName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
	)
 
	#region Get IE Version
	$valueNames = 'svcVersion', 'svcUpdateVersion', 'Version', 'W2kVersion'
 
	$version = 0;
	for ($i = 0; $i -lt $valueNames.Length; $i++)
	{
		$objVal = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer', $valueNames[$i], '0')
		$strVal = [System.Convert]::ToString($objVal)
		if ($strVal)
		{
			$iPos = $strVal.IndexOf('.')
			if ($iPos -gt 0)
			{
				$strVal = $strVal.Substring(0, $iPos)
			}
 
			$res = 0;
			if ([int]::TryParse($strVal, [ref]$res))
			{
				$version = [Math]::Max($version, $res)
			}
		}
	}
 
	if ($version -lt 7)
	{
		$version = 7000
	}
	else
	{
		$version = $version * 1000
	}
	#endregion
 
	[Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION', $ExecutableName, $version)
}

Function Show-OAuthWindow
{
    param(
        [System.Uri]$Url
    )

    Set-WebBrowserEmulation

    Add-Type -AssemblyName System.Windows.Forms

    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=440;Height=640}
    $web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=420;Height=600;Url=($url ) }
    $DocComp  = {
        $Global:uri = $web.Url.AbsoluteUri
        if ($Global:Uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
    }
    $web.ScriptErrorsSuppressed = $true
    $web.Add_DocumentCompleted($DocComp)
    $form.Controls.Add($web)
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() | Out-Null

    $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
    $output = @{}
    foreach($key in $queryOutput.Keys){
        $output["$key"] = $queryOutput[$key]
    }

    $output
}

Function Get-NewTokens
{
    [CmdletBinding()]
    param($sky_api_tokens_file_path)

    # Set the Necessary Config Variables
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $client_id = $sky_api_config.client_id
    $client_secret = $sky_api_config.client_secret
    $redirect_uri = $sky_api_config.redirect_uri
    $authorize_uri = $sky_api_config.authorize_uri
    $token_uri = $sky_api_config.token_uri

    # Load Web assembly
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

    # Build authorisation URI
    $strUri = $authorize_uri +
    "?client_id=$client_id" +
    "&redirect_uri=" + [System.Web.HttpUtility]::UrlEncode($redirect_uri) +
    '&response_type=code&state=state'

    $authOutput = Show-OAuthWindow -Url $strUri

    # Get auth token
    $Authorization = Get-SKYAPIAuthToken -grant_type 'authorization_code' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $authOutput["code"] -token_uri $token_uri

    # Swap token for a Refresh token (which when requested returns both refresh and access tokens)
    $Authorization = Get-RefreshToken -grant_type 'refresh_token' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $authorization.refresh_token -token_uri $token_uri

    # Make sure path to credentials file parent folder exists and if it doesn't, create it
    $sky_api_tokens_file_path_ParentDir = Split-Path -Path $sky_api_tokens_file_path
    If(-not (Test-Path $sky_api_tokens_file_path_ParentDir))
    {
        New-Item -ItemType Directory -Force -Path $sky_api_tokens_file_path_ParentDir
    }

    # Add Refresh & Access Token expirys to PSCustomObject and Save credentials to file
    $Authorization | Add-Member -MemberType NoteProperty -Name "refresh_token_creation" -Value $((Get-Date).ToUniversalTime().ToString("o")) -Force
    $Authorization | Add-Member -MemberType NoteProperty -Name "access_token_creation" -Value $((Get-Date).ToUniversalTime().ToString("o")) -Force
    $Authorization | Select-Object access_token, refresh_token, refresh_token_creation, access_token_creation | ConvertTo-Json `
        | ConvertTo-SecureString -AsPlainText -Force `
        | ConvertFrom-SecureString `
        | Out-File -FilePath $sky_api_tokens_file_path -Force
}

# Handle Common Errors > https://developer.blackbaud.com/skyapi/docs/resources/in-depth-topics/handle-common-errors
function CatchInvokeErrors($InvokeErrorMessage)
{
    # Convert From JSON
    $InvokeErrorMessage = $InvokeErrorMessage.ErrorDetails.Message | ConvertFrom-Json

    # Get Status Code, or Error if Code is blank
    $StatusCodeorError = If($InvokeErrorMessage.statusCode) {$InvokeErrorMessage.statusCode} else {$InvokeErrorMessage.error}

    Switch ($StatusCodeorError)
    {
        invalid_grant # You usually, but not always, see this error when providing an invalid, expired, or previously used authorization code.
        {
            # We will display the error, try again and handle the issue later.
            Write-Error $InvokeErrorMessage
            'retry'
        }
        400 # Bad request. Usually means that data in the initial request is invalid or improperly formatted.
        {
            throw "Bad request: $InvokeErrorMessage"
        }
        401 # Unauthorized Request. Could mean that the authenticated user does not have rights to access the requested data or does not have permission to edit a given record or record type. An unauthorized request also occurs if the authorization token expires or if the authorization header is not supplied.
        {
            # Usually this happens if the token has expired.
            Connect-SKYAPI -ForceRefresh
            'retry'
        }
        429 # Rate limit is exceeded. Try again in 1 seconds. Technically, the number of seconds is returned in the 'Retry-After' header, but I think it's best not to wait longer. 
        {
            # Sleep for 1 second and return the try command.
            Start-Sleep -Seconds 1
            'retry'
        }
        500 # Internal Server Error. 
        {
            # Sleep for 100 second and return the try command. I don't know if this is too long, but it seems reasonable.
            Start-Sleep -Seconds 100
            'retry'
        }
        default
        {
            throw "I don't have that fruit (code). OK I need a better error message. The code/error returned is " + $StatusCodeorError + " if that helps."
        }
    }    
}

Function Get-UnpagedEntity
{
    [CmdletBinding()]
    param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-TokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }
    
    $fullUri = $url + $uid + $endUrl
    $Request = [System.UriBuilder]$fullUri
    
    if ($null -ne $params -and $params -ne '') {
        $Request.Query = $params.ToString()
    }
    
    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 5
    do
    {      
        $InvokeCount += 1
        $NextAction = $null
        try
        {
            $apiCallResult =
            Invoke-RestMethod   -Method Get `
                                -ContentType application/json `
                                -Headers @{
                                        'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                        'bb-api-subscription-key' = ($api_key)} `
                                -Uri $($Request.Uri.AbsoluteUri)
        
            # If there is a response field return that
            if ($null -ne $response_field -and $response_field -ne "")
            {
                return $apiCallResult.$response_field
            }
            else # else return the entire API call result
            {
                return $apiCallResult
            }
        }
        catch
        {
            # Process Invoke Error
            $NextAction = CatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw "Invoke tried running $InvokeCount times, but failed each time. The last error message is: `n" + $Error[0]
    }
}

Function Get-PagedEntity
{
    [CmdletBinding()]
    param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field, $response_limit, $page_limit)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-TokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }

    # Create Request Uri
    $fullUri = $url + $uid + $endUrl
    $Request = [System.UriBuilder]$fullUri
    $Request.Query = $params.ToString()

    # Create records array
    $allRecords = @()

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 5
    do
    {      
        $InvokeCount += 1
        $NextAction = $null
        try
        {
            # Call to the API and loop unless the $page record count is reached.
            do
            {
                $apiItems =
                Invoke-RestMethod   -Method Get `
                                    -ContentType application/json `
                                    -Headers @{
                                            'Authorization' = ("Bearer "+ $authorisation.access_token)
                                            'bb-api-subscription-key' = ($api_key)} `
                                    -Uri $($Request.Uri.AbsoluteUri)
                
                # If there is a response field use that
                if ($null -ne $response_field -and $response_field -ne "")
                {
                    $allRecords += $apiItems.$response_field
                    $pageRecordCount = $apiItems.$response_field.count
                    
                }
                else # No response field
                {
                    $allRecords += $apiItems
                    $pageRecordCount = $apiItems.count
                }
                
                $totalRecordCount = $allRecords.count

                # Update marker location for next page
                [int]$params['Marker'] += $page_limit
                $Request.Query = $params.ToString()

                # If the user supplied a limit, then respect it and don't get subsequent pages
                if (($null -ne $response_limit -and $response_limit -ne 0 -and $response_limit -ne "") -and $response_limit -le $totalRecordCount)
                    {
                        # If we have too many records, remove the extra ones
                        if ($totalRecordCount -gt $response_limit)
                        {
                            $allRecords = $allRecords[0..($response_limit - 1)]
                        }
                    
                        return $allRecords
                    }
            }
            while ($pageRecordCount -eq $page_limit) # Loop to the next page if the current page is full

            $allRecords            
        }
        catch
        {
            # Process Invoke Error
            $NextAction = CatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-AuthTokensFromFile -TokensPath $sky_api_tokens_file_path
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw "Invoke tried running $InvokeCount times, but failed each time. The last error message is: `n" + $Error[0]
    }
}

# Check to See if Refresh Token or Access Token is Expired
function Confirm-TokenIsFresh
{
    param (
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [datetime]$TokenCreation,

        [parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('Refresh','Access')]
        [string]$TokenType
    )

    # For security purposes, access tokens will expire after 60 minutes.
    # Refresh tokens will also expire after a much longer period of time (currently 365 days).
    # More information available at https://developer.blackbaud.com/skyapi/docs/authorization#token-expiration
    $maxRefreshTokenTimespan = new-timespan -days 364
    $maxAccessTokenTimespan = new-timespan -minutes 59

    switch ($TokenType)
    {
        Refresh {$MaxTokenTimespan = $maxRefreshTokenTimespan}
        Access  {$MaxTokenTimespan = $maxAccessTokenTimespan}
    }

    if (((get-date) - $TokenCreation) -lt $MaxTokenTimespan)
    {
        $true
    }
    else
    {
        $false
    }
}

function Get-AuthTokensFromFile
{
    param (
        [parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$TokensPath
    )

    try
    {
        $apiTokens = Get-Content $sky_api_tokens_file_path -ErrorAction Stop
        $SecureString = $apiTokens | ConvertTo-SecureString -ErrorAction Stop
        $AuthTokensFromFile = ((New-Object PSCredential "user",$SecureString).GetNetworkCredential().Password) | ConvertFrom-Json
    }
    catch
    {
        throw "`'Key.json`' token file is missing, corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
    }
    
    $AuthTokensFromFile
}

# Import the functions
$SKYAPIFunctions  = @(Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1)

Foreach($SKYAPIFunction in $SKYAPIFunctions)
{
    Write-Verbose "Importing $SKYAPIFunction"
    Try
    {
        . $SKYAPIFunction.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($SKYAPIFunction.fullname): $_"
    }
}
