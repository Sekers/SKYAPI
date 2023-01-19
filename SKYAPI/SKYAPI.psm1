# Configure script to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set Global User Data Path Variable
New-Variable -Name 'sky_api_user_data_path' -Value "$([Environment]::GetEnvironmentVariable('LOCALAPPDATA'))\SKYAPI PowerShell" -Scope Global -Force

# Aliases
Set-Alias -Name Get-SchoolLegacyList -Value Get-SchoolList
Set-Alias -Name Get-SchoolSchedulesMeetings -Value Get-SchoolScheduleMeeting
Set-Alias -Name Get-SchoolActivityListBySchoolLevel -Value Get-SchoolActivityBySchoolLevel
Set-Alias -Name Get-SchoolAdvisoryListBySchoolLevel -Value Get-SchoolAdvisoryBySchoolLevel
Set-Alias -Name Get-SchoolCourseList -Value Get-SchoolCourse
Set-Alias -Name Get-SchoolDepartmentList -Value Get-SchoolDepartment
Set-Alias -Name Get-SchoolEducationList -Value Get-SchoolUserEducation
Set-Alias -Name Get-SchoolGradeLevelList -Value Get-SchoolGradeLevel
Set-Alias -Name Get-SchoolLevelList -Value Get-SchoolLevel
Set-Alias -Name Get-SchoolNewsCategories -Value Get-SchoolNewsCategory
Set-Alias -Name Get-SchoolNewsItems -Value Get-SchoolNewsItem
Set-Alias -Name Get-SchoolOfferingTypeList -Value Get-SchoolOfferingType
Set-Alias -Name Get-SchoolRoleList  -Value Get-SchoolRole
Set-Alias -Name Get-SchoolSectionListBySchoolLevel -Value Get-SchoolSectionBySchoolLevel
Set-Alias -Name Get-SchoolSectionListByStudent -Value Get-SchoolSectionByStudent
Set-Alias -Name Get-SchoolSectionListByTeacher -Value Get-SchoolSectionByTeacher
Set-Alias -Name Get-SchoolStudentEnrollmentList -Value Get-SchoolStudentEnrollment
Set-Alias -Name Get-SchoolStudentListBySection -Value Get-SchoolStudentBySection
Set-Alias -Name Get-SchoolTermList -Value Get-SchoolTerm
Set-Alias -Name Get-SchoolUserExtendedList -Value Get-SchoolUserExtendedByBaseRole
Set-Alias -Name Get-SchoolUserList -Value Get-SchoolUserByRole
Set-Alias -Name Get-SchoolUserPhoneList -Value Get-SchoolUserPhone
Set-Alias -Name Get-SchoolUserPhoneTypeList -Value Get-SchoolUserPhoneType
Set-Alias -Name Get-SchoolYearList -Value Get-SchoolYear
Set-Alias -Name New-SchoolEventsCategory -Value New-SchoolEventCategory

# Type Definitions

# Public Enum
# Name: MarkerType
# Value: NEXT_RECORD_NUMBER - Use the record number as the marker value to return the next set of results. For example: marker=101 will return the second set of results.
# Value: OFFSET - The record to start the next collection on.
# Value: LAST_USER_ID - Use the last user's ID as the marker value to return the next set of results.
# Value: NEXT_PAGE - Use the page number as the marker value to return the next set of results. For example: page=2 will return the second set of results.

# Check to see if the MarkerType Type is already loading to prevent the "Cannot add type. The type name 'MarkerType' already exists." error message. 
if ("MarkerType" -as [type]) {} else {
Add-Type -TypeDefinition @"
public enum MarkerType {
    NEXT_RECORD_NUMBER,
    OFFSET,
    LAST_USER_ID,
    NEXT_PAGE
}
"@
}

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
    Param($grant_type,$client_id,$redirect_uri,$client_secret,$authCode,$token_uri)

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
    Get-SKYAPIAccessToken: Uses the long life (365 days) refresh_token to get a new access_token.
    When you use a refresh token, you'll receive a new short-lived access token (60 minutes)
    that you can use when making subsequent calls to the SKY API.
    Using a refresh token also exchanges the current refresh token for a new one to reset the token life.
#>
Function Get-SKYAPIAccessToken
{
    [CmdletBinding()]
    Param($grant_type,$client_id,$redirect_uri,$client_secret,$authCode,$token_uri)

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
    
    # Add in creation timestamps for the tokens (NOTE THIS IS UTC).
    $Timestamp = $((Get-Date).ToUniversalTime().ToString("o"))
    $Authorization | Add-Member -MemberType NoteProperty -Name "refresh_token_creation" -Value $Timestamp -Force
    $Authorization | Add-Member -MemberType NoteProperty -Name "access_token_creation" -Value $Timestamp -Force

    $Authorization
}


# Helper function to get a specified nested member property of an object.
# From: https://stackoverflow.com/questions/69368564/powershell-get-value-from-json-using-string-from-array
# This will take an array with each item as the next property in the path, or you can use a string with a delimiter (e.g., "results.rows")
function Resolve-SKYAPIMemberChain
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]$InputObject,

        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$MemberPath,

        [Parameter(Mandatory = $false)]
        [string]$Delimiter
    )

    begin
    {
        if($PSBoundParameters.ContainsKey('Delimiter'))
        {
            $MemberPath = $MemberPath.Split([string[]]@($Delimiter))
        }
    }

    process
    {
        foreach($obj in $InputObject)
        {
            $cursor = $obj
            foreach($member in $MemberPath)
            {
                $cursor = $cursor.$member
            }
    
            $cursor
        }
    }
}

# Helper to make sure Browser Emulation/Compatibility Mode is Off When Using the WebBrowser Control.
# This function will set the Internet Explorer emulation mode for the running executable. This allows the WebBrowser control to support newer html features and improves compatibility with modern websites.
# Modified from https://www.sapien.com/blog/2020/11/05/a-simple-fix-for-problems-with-windows-forms-webbrowser/ (see also https://bchallis.wordpress.com/2020/10/17/problems-with-the-windows-forms-webbrowser-control-and-a-simple-way-to-fix-it/)
function Set-SKYAPIWebBrowserEmulation
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

Function Show-SKYAPIOAuthWindow
{
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [System.Uri]$Url,

        [parameter(
        Position=1,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('','EdgeWebView2','MiniHTTPServer','LegacyIEControl')] # Allows null to be passed
        [string]$AuthenticationMethod,

        [parameter(
            Position=2,
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [switch]$ClearBrowserControlCache
    )

    # If Edge WebView 2 is the Authentication Method & the runtime not installed - https://developer.microsoft.com/en-us/microsoft-edge/webview2/
    # If you run the following command from an elevated process or command prompt, it triggers a per-machine install.
    # If you don't run the command from an elevated process or command prompt, a per-user install will take place.
    #However, a per-user install is automatically replaced by a per-machine install, if a per-machine Microsoft Edge Updater is in place.
    #A per-machine Microsoft Edge Updater is provided as part of Microsoft Edge, except for the Canary preview channel of Microsoft Edge.
    #For more information, see https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution#installing-the-runtime-as-per-machine-or-per-user.
    if ($null -eq $AuthenticationMethod -or "" -eq $AuthenticationMethod -or $AuthenticationMethod -eq "EdgeWebView2")
    {
        # Check if WebView2 is installed
        $SourceProductName = 'Microsoft Edge WebView2 Runtime' # Partial Name is Fine as Long as it is Unique enough for a match

        # Get a Listing of Installed Applications From the Registry
        $InstalledApplicationsFromRegistry = @()
        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # x86 Apps
        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" # x64 Apps
        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" #HKCU Apps

        while ((-not ($InstalledApplicationsFromRegistry | Where-Object {$_.DisplayName -match $SourceProductName})) -and ($null -eq $AuthenticationMethod -or "" -eq $AuthenticationMethod -or $AuthenticationMethod -eq "EdgeWebView2") )
        {
            Write-Warning "Microsoft Edge WebView2 Runtime is not installed and is required for browser-based authentication. Please install the runtime and try again."
            $PromptNoWebView2Runtime_Title = "Options"
            $PromptNoWebView2Runtime_Message = "Enter your choice:"
            $PromptNoWebView2Runtime_Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Download & install the Edge WebView2 runtime", "&Try alternative method (beta)", "&Cancel & exit")
            $PromptNoWebView2Runtime_Default = 0
            $PromptNoWebView2Runtime_Selection = $host.UI.PromptForChoice($PromptNoWebView2Runtime_Title,$PromptNoWebView2Runtime_Message,$PromptNoWebView2Runtime_Choices,$PromptNoWebView2Runtime_Default)

            switch($PromptNoWebView2Runtime_Selection)
            {
                0   {
                        Write-Host "Attempting to download & install the Microsoft Edge WebView2 runtime"
                        # Create Download Folder If It Doesn't Already Exist
                        $DownloadPath = "$sky_api_user_data_path\Downloads"
                        $null = New-Item -ItemType Directory -Path $DownloadPath -Force

                        # Download WebView2 Evergreen Bootstrapper
                        $DownloadURL = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
                        $DownloadContent = Invoke-WebRequest -Uri $DownloadURL
                        $DownloadFileName = "Microsoft Edge WebView2 Runtime Installer.exe"

                        # Create the file (this will overwrite any existing file with the same name)
                        $WebView2Installer = [System.IO.FileStream]::new("$DownloadPath\$DownloadFileName", [System.IO.FileMode]::Create)
                        $WebView2Installer.Write($DownloadContent.Content, 0, $DownloadContent.RawContentLength)
                        $WebView2Installer.Close()

                        # Install
                        Write-Host "File Downloaded. Attempting to run installer."
                        Start-Process -Filepath "$DownloadPath\$DownloadFileName" -Wait

                        # Get a Listing of Installed Applications From the Registry
                        $InstalledApplicationsFromRegistry = @()
                        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # x86 Apps
                        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" # x64 Apps
                        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" #HKCU Apps

                        # Retry Opening Authentication Window
                        Write-Host "Retrying Authentication...`n"
                    }
                1   {
                        $AuthenticationMethod = "MiniHTTPServer"
                    }
                2   {
                        Write-Host "Exiting..."
                        Exit
                    }
            }
            
        }
    }
    
    switch ($AuthenticationMethod)
    {
        MiniHTTPServer # TODO
        {
            Write-Host "`nUsing this option will attempt to authenticate using an alternate method by building a mini webserver in PowerShell. Continue?"
            $PromptMiniWebserver_Title = "Options"
            $PromptMiniWebserver_Message = "Enter your choice:"
            $PromptMiniWebserver_Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Load temporary HTTP server", "&Cancel & exit")
            $PromptMiniWebserver_Default = 0
            $PromptMiniWebserver_Selection = $host.UI.PromptForChoice($PromptMiniWebserver_Title,$PromptMiniWebserver_Message,$PromptMiniWebserver_Choices,$PromptMiniWebserver_Default)

            switch($PromptMiniWebserver_Selection)
            {
                0   {
                        Write-Warning "Sorry. The mini webserver authentication feature is not yet implemented."
                        Write-Host "Exiting..."
                        Exit
                    }
                1   {
                        Write-Host "Exiting..."
                        Exit
                    }
            }
        }
        LegacyIEControl
        {
            Set-SKYAPIWebBrowserEmulation

            if ($ClearBrowserControlCache)
            {
                # Try to clear IE cache
                # More info: https://superuser.com/questions/450014/clearmytracksbyprocess-all-options
                # Using 4351 (0x10FF) to clear all + files and settings stored by add-ons. Convert Hex to Decimal.
                # // This magic value is the combination of the following bitflags:
                # // #define CLEAR_HISTORY         0x0001 // Clears history
                # // #define CLEAR_COOKIES         0x0002 // Clears cookies
                # // #define CLEAR_CACHE           0x0004 // Clears Temporary Internet Files folder
                # // #define CLEAR_CACHE_ALL       0x0008 // Clears offline favorites and download history
                # // #define CLEAR_FORM_DATA       0x0010 // Clears saved form data for form auto-fill-in
                # // #define CLEAR_PASSWORDS       0x0020 // Clears passwords saved for websites
                # // #define CLEAR_PHISHING_FILTER 0x0040 // Clears phishing filter data
                # // #define CLEAR_RECOVERY_DATA   0x0080 // Clears webpage recovery data
                # // #define CLEAR_PRIVACY_ADVISOR 0x0800 // Clears tracking data
                # // #define CLEAR_SHOW_NO_GUI     0x0100 // Do not show a GUI when running the cache clearing
                # //
                # // Bitflags available but not used in this magic value are as follows:
                # // #define CLEAR_USE_NO_THREAD      0x0200 // Do not use multithreading for deletion
                # // #define CLEAR_PRIVATE_CACHE      0x0400 // Valid only when browser is in private browsing mode
                # // #define CLEAR_DELETE_ALL         0x1000 // Deletes data stored by add-ons
                # // #define CLEAR_PRESERVE_FAVORITES 0x2000 // Preserves cached data for "favorite" websites
                Write-Warning "Note: You may have to close PowerShell and start a new session for clearing the IE cache to take effect."
                Start-Process -FilePath 'RunDll32.exe' -ArgumentList 'InetCpl.cpl, ClearMyTracksByProcess 4351' -Wait
                $ClearBrowserControlCache = $false
            }

            Add-Type -AssemblyName System.Windows.Forms
        
            $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=600;Height=800}
            $web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=584;Height=760;Url=($url)}
            $DocComp = {
                $Global:uri = $web.Url.AbsoluteUri
                if ($Global:Uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
            }
            $web.ScriptErrorsSuppressed = $true
            $web.Add_DocumentCompleted($DocComp)

            $form.Controls.Add($web)
            $form.Add_Shown({$form.Activate()})
            $form.ShowDialog() | Out-Null

            # Parse Return URL
            $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
            $output = @{}
            foreach($key in $queryOutput.Keys){
                $output["$key"] = $queryOutput[$key]
            }

            # Dispose Form & IE WebBrowser Control
            $web.Dispose()
            $form.Dispose()
        }
        default # EdgeWebView2
        {            
            # Set EdgeWebView2 Control Version to Use
            $EdgeWebView2Control_VersionNumber = '1.0.1210.39'
            switch ($PSVersionTable.PSEdition)
            {
                Desktop {$EdgeWebView2Control_DotNETVersion = "net45"}
                Core {$EdgeWebView2Control_DotNETVersion = "netcoreapp3.0"}
                Default {$EdgeWebView2Control_DotNETVersion = "netcoreapp3.0"}
            }
            switch ([System.Environment]::Is64BitProcess)
            {
                $true {$EdgeWebView2Control_OSArchitecture = "win-x64"}
                $false {$EdgeWebView2Control_OSArchitecture = "win-x86"}
                Default {$EdgeWebView2Control_OSArchitecture = "win-x64"}
            }
            
            # Update $AuthenticationMethod Variable (not currently needed but is useful to have in a variable)
            $AuthenticationMethod = "EdgeWebView2"
            
            # Load Assemblies
            Add-Type -AssemblyName System.Windows.Forms

            # Note, you also need the following two files in the same folder as "Microsoft.Web.WebView2.WinForms.dll":
            # - Microsoft.Web.WebView2.Core.dll
            # - WebView2Loader.dll
            Add-Type -Path "$PSScriptRoot\Dependencies\Microsoft.Web.WebView2\$EdgeWebView2Control_VersionNumber\$EdgeWebView2Control_DotNETVersion\$EdgeWebView2Control_OSArchitecture\Microsoft.Web.WebView2.WinForms.dll"

            $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=600;Height=800}
            $WebView2 = New-Object -TypeName Microsoft.Web.WebView2.WinForms.WebView2

            $WebView2.CreationProperties = New-Object -TypeName 'Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties'
            $WebView2.CreationProperties.UserDataFolder = $sky_api_user_data_path

            # Clear WebView2 cache in the previously specified UserDataFolder
            # TODO For now this is just hardcoded as deleting the folder... Need to figure out how to clear the user data folder using the WebView2 Control (newer version possibly required)
            if ($ClearBrowserControlCache)
            {
                Remove-Item "$($WebView2.CreationProperties.UserDataFolder)\EBWebView\Default" -Force -Recurse -ErrorAction Ignore
                $ClearBrowserControlCache = $false
            }

            $WebView2.Source = $Url
            $WebView2.Size = New-Object System.Drawing.Size(584, 760)

            # Set Event Handlers. See APIs here: https://github.com/MicrosoftEdge/WebView2Browser#webview2-apis
            $WebView2_NavigationCompleted = {
                # Write-Host $($WebView2.Source.AbsoluteUri) # DEBUG LINE
                if ($WebView2.Source.AbsoluteUri -match "error=[^&]*|$([regex]::escape($redirect_uri))*")
                {
                    $form.Close()
                }
            }
            $WebView2.add_NavigationCompleted($WebView2_NavigationCompleted)
            
            # Add WebView2 Control to the Form and Show It
            $form.Controls.Add($WebView2)
            $form.Add_Shown({$form.Activate()})
            $form.ShowDialog() | Out-Null

            # Parse Return URL
            $queryOutput = [System.Web.HttpUtility]::ParseQueryString($WebView2.Source.Query)
            $output = @{}
            foreach($key in $queryOutput.Keys){
                $output["$key"] = $queryOutput[$key]
            }

            # Dispose Form & Webview2 Control
            $WebView2.Dispose()
            $form.Dispose()
        }
    }

    # Validate the $output variable before returning
    if ($null -eq $output["code"]) {
        Write-Warning "Authentication or authorization failed. Try again?"
        $PromptNoAuthCode_Title = "Options"
        $PromptNoAuthCode_Message = "Enter your choice:"
        $PromptNoAuthCode_Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Yes", "&No; exit the script")
        $PromptNoAuthCode_Default = 0
        $PromptNoAuthCode_Selection = $host.UI.PromptForChoice($PromptNoAuthCode_Title,$PromptNoAuthCode_Message,$PromptNoAuthCode_Choices,$PromptNoAuthCode_Default)

        switch($PromptNoAuthCode_Selection)
        {
            0   { # Retry authenticating & authorizing
                    $authOutput = Show-SKYAPIOAuthWindow -url $Url -AuthenticationMethod $AuthenticationMethod -ClearBrowserControlCache:$ClearBrowserControlCache
                    return $authOutput
                }
            1   {
                    throw "Authentication or authorization failed. Exiting..."
                }
        }
    }

    Return $output
}

Function Get-SKYAPINewTokens
{
    [CmdletBinding()]
    Param(
        [parameter(
            Position=0,
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [string]$sky_api_tokens_file_path,
        
        [parameter(
            Position=1,
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateSet('','EdgeWebView2','MiniHTTPServer','LegacyIEControl')] # Allows null to be passed
            [string]$AuthenticationMethod,

        [parameter(
            Position=2,
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [switch]$ClearBrowserControlCache
    )

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

    $authOutput = Show-SKYAPIOAuthWindow -Url $strUri -AuthenticationMethod $AuthenticationMethod -ClearBrowserControlCache:$ClearBrowserControlCache

    # Get auth token
    $Authorization = Get-SKYAPIAuthToken -grant_type 'authorization_code' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $authOutput["code"] -token_uri $token_uri

    # Swap Refresh token for an Access token (which when requested returns both refresh and access tokens)
    $Authorization = Get-SKYAPIAccessToken -grant_type 'refresh_token' -client_id $client_id -redirect_uri $redirect_uri -client_secret $client_secret -authCode $authorization.refresh_token -token_uri $token_uri

    # Make sure path to credentials file parent folder exists and if it doesn't, create it
    $sky_api_tokens_file_path_ParentDir = Split-Path -Path $sky_api_tokens_file_path
    If(-not (Test-Path $sky_api_tokens_file_path_ParentDir))
    {
        New-Item -ItemType Directory -Force -Path $sky_api_tokens_file_path_ParentDir
    }

    # Save credentials to file
    $Authorization | ConvertTo-Json `
        | ConvertTo-SecureString -AsPlainText -Force `
        | ConvertFrom-SecureString `
        | Out-File -FilePath $sky_api_tokens_file_path -Force
}

# Handle Common Errors > https://developer.blackbaud.com/skyapi/docs/resources/in-depth-topics/handle-common-errors
function SKYAPICatchInvokeErrors($InvokeErrorMessageRaw)
{
    # Convert From JSON
    $InvokeErrorMessage = $InvokeErrorMessageRaw.ErrorDetails.Message | ConvertFrom-Json

    # Get Status Code, or Error if Code is blank. Blackbaud sends error messages at least 3 different ways so we need to account for that. Yay for no consistency.
    If ($InvokeErrorMessage.statusCode)
    {
        $StatusCodeorError = $InvokeErrorMessage.statusCode
    }
    elseif ($InvokeErrorMessage.error)
    {
        $StatusCodeorError = If($InvokeErrorMessage.statusCode) {$InvokeErrorMessage.statusCode} else {$InvokeErrorMessage.error}
    }
    elseif ($InvokeErrorMessage.errors) {
        $StatusCodeorError = If($InvokeErrorMessage.errors.error_code) {$InvokeErrorMessage.errors.error_code} else {$InvokeErrorMessage.errors}
    }
    else
    {
        # If it's not in a format the module recognizes, then just throw the raw message.
        throw $InvokeErrorMessageRaw
    }

    # Try and handle the error message.
    Switch ($StatusCodeorError)
    {
        invalid_client # You usually see this error when providing an invalid .
        {
            # We will display the error, try again and handle the issue later.
            Write-Warning $InvokeErrorMessageRaw
            'retry'
        }
        invalid_grant # You usually, but not always, see this error when providing an invalid, expired, or previously used authorization code.
        {
            # We will display the error, try again and handle the issue later.
            Write-Warning $InvokeErrorMessageRaw
            'retry'
        }
        400 # Bad request. Usually means that data in the initial request is invalid or improperly formatted.
        {
            throw $InvokeErrorMessageRaw
        }
        401 # Unauthorized Request. Could mean that the authenticated user does not have rights to access the requested data or does not have permission to edit a given record or record type. An unauthorized request also occurs if the authorization token expires or if the authorization header is not supplied.
        {
            # This can happens if the token has expired so we will try to refresh and then run the invoke again.
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
            # Sleep for 5 seconds and return the try command. I don't know if this is a good length, but it seems reasonable since we try 5 times before failing.
            # The other option would be to use the exponential backoff method where You can periodically retry a failed request over an increasing amount of time to handle errors
            # related to rate limits, network volume, or response time. For example, you might retry a failed request after one second, then after two seconds, and then after four seconds.
            Start-Sleep -Seconds 5
            'retry'
        }
        503 # The service is currently unavailable.
        {
            # Sleep for 5 seconds and return the try command. I don't know if this is a good length, but it seems reasonable since we try 5 times before failing.
            # The other option would be to use the exponential backoff method where You can periodically retry a failed request over an increasing amount of time to handle errors
            # related to rate limits, network volume, or response time. For example, you might retry a failed request after one second, then after two seconds, and then after four seconds.
            Start-Sleep -Seconds 5
            'retry'
        }
        default
        {
            throw $InvokeErrorMessageRaw
        }
    }    
}

Function Get-SKYAPIUnpagedEntity
{
    [CmdletBinding()]
    Param(
        $uid,
        $url,
        $endUrl,
        $api_key,
        $authorisation,
        $params,
        $response_field,
        [switch]$ReturnRaw)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }
    
    # Create Request Uri
    $uid = [uri]::EscapeDataString($uid)
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
            if ($ReturnRaw)
            {
                $apiCallResult =
                Invoke-WebRequest   -Method Get `
                                    -ContentType application/json `
                                    -Headers @{
                                            'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                            'bb-api-subscription-key' = ($api_key)} `
                                    -Uri $($Request.Uri.AbsoluteUri)
                
                return $apiCallResult.Content
            }
            else
            {
                $apiCallResult =
                Invoke-RestMethod   -Method Get `
                                    -ContentType application/json `
                                    -Headers @{
                                            'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                            'bb-api-subscription-key' = ($api_key)} `
                                    -Uri $($Request.Uri.AbsoluteUri)
            
                # If there is a response field set for the endpoint cmdlet, return that.
                if ($null -ne $response_field -and "" -ne $response_field)
                {
                    # return $apiCallResult.$response_field
                    return Resolve-SKYAPIMemberChain -InputObject $apiCallResult -MemberPath $response_field -Delimiter "."
                }
                else # else return the entire API call result
                {
                    return $apiCallResult
                }
            }
        }
        catch
        {
            # Process Invoke Error
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw $LastCaughtError
    }
}

Function Get-SKYAPIPagedEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field, $response_limit, $page_limit, [MarkerType]$marker_type)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }

    # Create Request Uri
    $uid = [uri]::EscapeDataString($uid)
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
                
                # If there is a response field set for the endpoint cmdlet, return that.
                if ($null -ne $response_field -and "" -ne $response_field)
                {
                    $recordsThisIteration = Resolve-SKYAPIMemberChain -InputObject $apiItems -MemberPath $response_field -Delimiter "."
                    $allRecords += $recordsThisIteration
                    $pageRecordCount = $recordsThisIteration.count
                    
                }
                else # No response field
                {
                    $allRecords += $apiItems
                    $pageRecordCount = $apiItems.count
                }
                
                $totalRecordCount = $allRecords.count

                # Update marker location for next page
                switch ($marker_type)
                {
                    NEXT_RECORD_NUMBER
                    {
                        [int]$params['marker'] += $page_limit
                        $Request.Query = $params.ToString()
                    }
                    OFFSET
                    {
                        [int]$params['offset'] += $page_limit
                        $Request.Query = $params.ToString()
                    }
                    LAST_USER_ID
                    {
                        [int]$params['marker'] = $allRecords[-1].id
                        $Request.Query = $params.ToString()
                    }
                    NEXT_PAGE
                    {
                        [int]$params['page'] += 1
                        $Request.Query = $params.ToString()
                    }
                }

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
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw $LastCaughtError
    }
}

Function Remove-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }
    
    # Create Request Uri
    $uid = [uri]::EscapeDataString($uid)
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
            Invoke-RestMethod   -Method Delete `
                                -ContentType application/json `
                                -Headers @{
                                        'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                        'bb-api-subscription-key' = ($api_key)} `
                                -Uri $($Request.Uri.AbsoluteUri)
        
            # If there is a response field set for the endpoint cmdlet, return that.
            if ($null -ne $response_field -and "" -ne $response_field)
            {
                # return $apiCallResult.$response_field
                return Resolve-SKYAPIMemberChain -InputObject $apiCallResult -MemberPath $response_field -Delimiter "."
            }
            else # else return the entire API call result
            {
                return $apiCallResult
            }
        }
        catch
        {
            # Process Invoke Error
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw $LastCaughtError
    }
}

function Submit-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }

    # Create Request Uri
    $uid = [uri]::EscapeDataString($uid)
    $fullUri = $url + $uid + $endUrl
    $Request = [System.UriBuilder]$fullUri

    # Build Body
    $PostRequest = $params | ConvertTo-Json

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
            Invoke-RestMethod   -Method Post `
                                -ContentType application/json `
                                -Headers @{
                                        'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                        'bb-api-subscription-key' = ($api_key)} `
                                -Uri $($Request.Uri.AbsoluteUri) `
                                -Body $PostRequest
        
            # If there is a response field set for the endpoint cmdlet, return that.
            if ($null -ne $response_field -and "" -ne $response_field)
            {
                # return $apiCallResult.$response_field
                return Resolve-SKYAPIMemberChain -InputObject $apiCallResult -MemberPath $response_field -Delimiter "."
            }
            else # else return the entire API call result
            {
                return $apiCallResult
            }
        }
        catch
        {
            # Process Invoke Error
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw $LastCaughtError
    }
}

function Update-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
        $authorisation.access_token = $($AuthTokensFromFile.access_token)
        $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
        $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
        $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
    }

    # Create Request Uri
    $uid = [uri]::EscapeDataString($uid)
    $fullUri = $url + $uid + $endUrl
    $Request = [System.UriBuilder]$fullUri

    # Build Body
    $PatchRequest = $params | ConvertTo-Json

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
            Invoke-RestMethod   -Method Patch `
                                -ContentType application/json `
                                -Headers @{
                                        'Authorization' = ("Bearer "+ $($authorisation.access_token))
                                        'bb-api-subscription-key' = ($api_key)} `
                                -Uri $($Request.Uri.AbsoluteUri) `
                                -Body $PatchRequest
        
            # If there is a response field set for the endpoint cmdlet, return that.
            if ($null -ne $response_field -and "" -ne $response_field)
            {
                # return $apiCallResult.$response_field
                return Resolve-SKYAPIMemberChain -InputObject $apiCallResult -MemberPath $response_field -Delimiter "."
            }
            else # else return the entire API call result
            {
                return $apiCallResult
            }
        }
        catch
        {
            # Process Invoke Error
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors($_)

            # Just in case the token was refreshed by the error catcher, update these
            $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
            $authorisation.access_token = $($AuthTokensFromFile.access_token)
            $authorisation.refresh_token = $($AuthTokensFromFile.refresh_token)
            $authorisation.refresh_token_creation = $($AuthTokensFromFile.refresh_token_creation)
            $authorisation.access_token_creation = $($AuthTokensFromFile.access_token_creation)
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    if ($InvokeCount -ge $MaxInvokeCount)
    {
        throw $LastCaughtError
    }
}

# Check to See if Refresh Token or Access Token is Expired
function Confirm-SKYAPITokenIsFresh
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

function Get-SKYAPIAuthTokensFromFile
{
    param (
    )

    # Make Sure Requested Path Isn't Null or Empty
    if ([string]::IsNullOrEmpty($sky_api_tokens_file_path))
    {
        throw "`'`$sky_api_tokens_file_path`' is not specified. Don't forget to first use the `'Set-SKYAPIConfigFilePath`' & `'Set-SKYAPITokensFilePath`' cmdlets!"
    }

    try
    {   
        $apiTokens = Get-Content $sky_api_tokens_file_path -ErrorAction Stop
        $SecureString = $apiTokens | ConvertTo-SecureString -ErrorAction Stop
        $AuthTokensFromFile = ((New-Object PSCredential "user",$SecureString).GetNetworkCredential().Password) | ConvertFrom-Json
    }
    catch
    {
        throw "Key JSON tokens file is missing, corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
    }
    
    $AuthTokensFromFile
}

# Fix date-only fields since the API returns dates with improper time values (sends it as -05:00 or sometimes -04:00).
# Converting to UTC should resolve the issue (though it makes the unused time portion 5 AM or 4AM, the date is accurate).
function Repair-SkyApiDate
{
    param ([DateTime]$Date)
    $Date = (($(Get-Date($Date).ToUniversalTime()).ToString('o')) -split "T")[0] # Can't use -AsUTC since that's PS Core only (not Windows PS 5.1).
    $Date
}

# Import the functions
$SKYAPIFunctions = @(Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1)

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
