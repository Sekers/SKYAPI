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

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

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

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'
    
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
        [ValidateSet('','EdgeWebView2')] # Allows null to be passed
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
        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" # HKLM Apps
        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" #HKCU Apps
        if ([System.Environment]::Is64BitProcess)
        {
            $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # x86 Apps when on 64-bit
        }
        
        # Get EdgeWebView2 Installed Version (only pull the 1st entry in case more than one comes up)
        $EdgeWebViewVersionInstalled = $InstalledApplicationsFromRegistry | Where-Object {$_.DisplayName -match $SourceProductName}
        if ([string]::IsNullOrEmpty($EdgeWebViewVersionInstalled))
        {
            $EdgeWebViewVersionInstalled = "0.0.0.0" # Good idea to set something in case it's not installed due to casting later on.
        }
        else
        {
            $EdgeWebViewVersionInstalled = $([array]($InstalledApplicationsFromRegistry | Where-Object {$_.DisplayName -match $SourceProductName})[0]).Version
        }

        while ((-not ($InstalledApplicationsFromRegistry | Where-Object {$_.DisplayName -match $SourceProductName})) -and ($null -eq $AuthenticationMethod -or "" -eq $AuthenticationMethod -or $AuthenticationMethod -eq "EdgeWebView2") )
        {
            Write-Warning "Microsoft Edge WebView2 Runtime is not installed and is required for browser-based authentication. Please install the runtime and try again."
            $PromptNoWebView2Runtime_Title = "Options"
            $PromptNoWebView2Runtime_Message = "Enter your choice:"
            $PromptNoWebView2Runtime_Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Download & install the Edge WebView2 runtime", "&Cancel & exit")
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
                        $DownloadContent = Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL
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
                        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" # HKLM Apps
                        $InstalledApplicationsFromRegistry += Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" #HKCU Apps
                        if ([System.Environment]::Is64BitProcess)
                        {
                            $InstalledApplicationsFromRegistry += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # x86 Apps when on 64-bit
                        }

                        # Retry Opening Authentication Window
                        Write-Host "Retrying Authentication...`n"
                    }
                1   {
                        Write-Host "Exiting..."
                        Exit
                    }
            }
        }
    }
    
    switch ($AuthenticationMethod)
    {
        default # EdgeWebView2
        {            
            # Set EdgeWebView2 Control Version to Use
            $EdgeWebView2Control_VersionNumber = '1.0.2792.45'
            switch ($PSVersionTable.PSEdition)
            {
                Desktop {$EdgeWebView2Control_DotNETVersion = "net462"}
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

            # Unpack the nupkg and grab the following two DLLs out of the /lib /lib_manual folders.
            # - Microsoft.Web.WebView2.WinForms.dll (there's a different version for each .NET type, but the same file for x86 & x64)
            # - Microsoft.Web.WebView2.Core.dll (while there's a copy for each .NET type, so far they have been the same exact file; same file for x86 & x64 too)
            # In addition, get the following file from the /runtimes folder and put it in the same locations.
            # - WebView2Loader.dll (different for x86 & x64, but same for .NET Core & .NET 45)
            Add-Type -Path "$PSScriptRoot\Dependencies\Microsoft.Web.WebView2\$EdgeWebView2Control_VersionNumber\$EdgeWebView2Control_DotNETVersion\$EdgeWebView2Control_OSArchitecture\Microsoft.Web.WebView2.WinForms.dll"

            $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=600;Height=800}
            $WebView2 = New-Object -TypeName Microsoft.Web.WebView2.WinForms.WebView2

            $WebView2.CreationProperties = New-Object -TypeName 'Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties'
            $WebView2.CreationProperties.UserDataFolder = $sky_api_user_data_path

            # Clear WebView2 cache in the previously specified UserDataFolder, if requested.
            # Using the WebView2 SDK to clear the browsing data is best, but wasn't released until version 1.0.1245.22 of the control.
            # This version of the SDK requires EdgeWebView2 version 102.0.1245.22 to be installed for full API compatibility.
            # So, we only clear the cache using the SDK if this version or higher of the WebView2 runtime is installed.
            # Otherwise, we just hardcode deleting the folder.
            # Note that we have to delete the folder before the control is loaded,
            # but we can't call the clear until it is initialized (so that code is further down).
            if ($ClearBrowserControlCache -and [System.Version]$EdgeWebViewVersionInstalled -lt [System.Version]'102.0.1245.22')
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

            # Set Event Handler for Clearing the Browser Data, if requested.
            # We can't actually clear the browser data until the CoreWebView2 property is created, so that's why it's down here as an event action.
            # More info: https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.winforms.webview2
            # This event is triggered when the control's CoreWebView2 has finished being initialized
            # (regardless of how initialization was triggered) but before it is used for anything.
            # More info: https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.wpf.webview2.corewebview2initializationcompleted
            if ($ClearBrowserControlCache -and [System.Version]$EdgeWebViewVersionInstalled -ge [System.Version]'102.0.1245.22')
            {
                $WebView2_CoreWebView2InitializationCompleted = {
                    $WebView2.CoreWebView2.Profile.ClearBrowsingDataAsync()
                }
                $WebView2.add_CoreWebView2InitializationCompleted($WebView2_CoreWebView2InitializationCompleted)
                $ClearBrowserControlCache = $false
            }
            
            # Add WebView2 Control to the Form and Show It
            $form.Controls.Add($WebView2)
            $form.Add_Shown({$form.Activate()})
            $form.TopMost = $true # Make's the dialog coming up above the PowerShell console more consistent (though not 100% it seems).
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
        [ValidateSet('','EdgeWebView2')] # Allows null to be passed
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
        $null = New-Item -ItemType Directory -Force -Path $sky_api_tokens_file_path_ParentDir
    }

    # Save credentials to file
    $Authorization | ConvertTo-Json `
        | ConvertTo-SecureString -AsPlainText -Force `
        | ConvertFrom-SecureString `
        | Out-File -FilePath $sky_api_tokens_file_path -Force
}

# Function to calculate the exponential backoff delay when dealing with errors that we retry because they may be transient issues.
# Exponential backoff is a standard error handling strategy for network applications in which a client periodically retries a failed request with increasing delays between requests.
function Get-ExponentialBackoffDelay
{
    [CmdletBinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$InitialDelay,
        
        [parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$InvokeCount 
    )

    # Return the delay time.
    return ($InitialDelay * [Math]::Pow(2, $InvokeCount - 1)) # Initial delay times 2 to the power of $InvokeCount minus 1.
}

# Handle Common Errors > https://developer.blackbaud.com/skyapi/docs/in-depth-topics/handle-common-errors
function SKYAPICatchInvokeErrors
{
    [CmdletBinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        $InvokeErrorMessageRaw,
        
        [parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$InvokeCount,

        [parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$MaxInvokeCount
    )

    # Convert From JSON
    try
    {
        $InvokeErrorMessage = $InvokeErrorMessageRaw.ErrorDetails.Message | ConvertFrom-Json
    }
    catch
    {
        throw $InvokeErrorMessageRaw
    }
    
    # Get Status Code (preferred), or Error if Code is blank. Blackbaud sends error messages at least 5 different ways so we need to account for that. Yay for no consistency.
    If ($InvokeErrorMessage.statusCode)
    {
        $StatusCodeorError = $InvokeErrorMessage.statusCode
    }
    elseif ($InvokeErrorMessage.ErrorCode)
    {
        $StatusCodeorError = $InvokeErrorMessage.ErrorCode
    }
    elseif ($InvokeErrorMessage.error) # TODO: I'm not sure if this is correct (guessed when correcting bug). Look for examples of this format.
    {
        $StatusCodeorError = If($InvokeErrorMessage.error.statuscode) {$InvokeErrorMessage.error.statuscode} else {$InvokeErrorMessage.error}
    }
    elseif ($InvokeErrorMessage.errors) {
        $StatusCodeorError = If($InvokeErrorMessage.errors.error_code) {$InvokeErrorMessage.errors.error_code} else {$InvokeErrorMessage.errors}
    }
    elseif ($InvokeErrorMessage.message) {
        $StatusCodeorError = $InvokeErrorMessage.message
    }
    else
    {
        # If it's not in a format the module recognizes, then just collect the error directly.
        $StatusCodeorError = $InvokeErrorMessage
    }

    # Try and handle the error message.
    Switch ($StatusCodeorError)
    {
        invalid_client # You usually, but not always, see this error when providing an invalid client id.
        {
            # We will display the error, try again and handle the issue later.
            Write-Warning $InvokeErrorMessageRaw

            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            'retry'
        }
        invalid_grant # You usually, but not always, see this error when providing an invalid, expired, or previously used authorization code.
        {
            # We will display the error, try again and handle the issue later.
            Write-Warning $InvokeErrorMessageRaw

            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            'retry'
        }
        400 # Bad Request. Usually means that data in the initial request is invalid or improperly formatted.
        {
            throw $InvokeErrorMessageRaw
        }
        401 # Unauthorized. Could mean that the authenticated user does not have rights to access the requested data or does not have permission to edit a given record or record type. An unauthorized request also occurs if the authorization token expires or if the authorization header is not supplied.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }
            
            # This can happens if the token has expired so we will try to refresh and then run the invoke again.
            Connect-SKYAPI -ForceRefresh
            'retry'
        }
        403 # Forbidden. The request failed because the user in whose context the API is being called either does not have permission to perform the operation itself, or does not have permission to access the data being requested. You may also see this response when the API quota associated with your subscription has been met.
        {
            # In addition to 429 rate limits (per second limit), SKY API also employs a quota limit to manage API traffic over a broader period of time. If this this limit is reached, requests return the 403 (Forbidden) status code with retry-after headers that indicate how long to wait before retrying an API request. Similar to the 429 responses, it is recommended to wait and retry after the time period in the retry-after header.
            # TODO: Check for '403 - Quota Exceeded' response from the API because this is a different type of 403 error and means the broad period (as opposed to per-second) quota is exceeded and not a real "Forbidden" error.
            throw $InvokeErrorMessageRaw
        }
        404 # Not Found. The requested resource could not be found. You may be trying to access a record that does not exist, or you may have supplied an invalid URL.
        {
            throw $InvokeErrorMessageRaw
        }
        415 # Unsupported Media Type. The request failed because the correct Content-Type header was not provided on the request. For endpoints that accept JSON in the request body, you must use the Content-Type header application/json.
        {
            throw $InvokeErrorMessageRaw
        }
        429 # Too Many Requests. Rate limit is exceeded. Try again in 1 seconds. Technically, the number of seconds is returned in the 'Retry-After' header, but the standard throttle is 10 calls per second. See: https://developer.blackbaud.com/skyapi/docs/in-depth-topics/api-request-throttling
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Sleep for 1 second and return the retry action command.
            Start-Sleep -Seconds 1
            'retry'
        }
        500 # Internal Server Error. An unexpected error has occurred on the SKY API side. You should never receive this response, but if you do let Blackbaud Support know.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
            'retry'
        }
        503 # Service Unavailable. The service is currently unavailable. One or more API services are not available. This is usually a temporary condition caused by an unexpected outage or due to planned downtime. Check the Issues page (https://status.blackbaud.com/?svcid=skydev) for more information.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
            'retry'
        }
        504 # Gateway Time-out.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
            'retry'
        }
        'An exception occurred. Please contact Support.' # Random exception. Often transient.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
            'retry'
        }
        {$_ -match 'The HTTP status code of the response was not expected \(500\)'} # Random exception. Often transient.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
            'retry'
        }
        'no healthy upstream' # Random exception. Often transient.
        {
            # Check if we've hit the max invoke count and if so, throw the error.
            if ($InvokeCount -ge $MaxInvokeCount)
            {
                throw $InvokeErrorMessageRaw
            }

            # Exponential backoff
            $SleepTime = Get-ExponentialBackoffDelay -InitialDelay 5 -InvokeCount $InvokeCount
            Start-Sleep -Seconds $SleepTime
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
    
    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 7
    do
    {      
        $InvokeCount += 1
        $NextAction = $null
        try
        {
            if ($ReturnRaw)
            {
                $apiCallResult =
                Invoke-WebRequest   -UseBasicParsing `
                                    -Method Get `
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
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

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
    Param(
        $uid,
        $url,
        $endUrl,
        $api_key,
        $authorisation,
        $params,
        $response_field,
        $response_limit,
        $page_limit,
        [MarkerType]$marker_type)

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

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 7
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
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

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

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 7
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
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

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
    $PostRequest = ConvertTo-Json $params

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 7
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
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

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
    $PatchRequest = ConvertTo-Json $params

    # Disable Progress Bar in Function Scope When Calling Invoke-WebRequest or Invoke-RestMethod.
    # This improves performance due to a bug in some versions of PowerShell. It was eventually fixed in Core (v6.0.0-alpha.13) but still is around in Desktop.
    # More Information: https://github.com/PowerShell/PowerShell/pull/2640
    $ProgressPreference = 'SilentlyContinue'

    # Run Invoke Command and Catch Responses
    [int]$InvokeCount = 0
    [int]$MaxInvokeCount = 7
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
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

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
    # Alternative way to do the same thing? # $Date = $Date.ToUniversalTime() -Format "yyyy-MM-dd"
    $Date
}

# Iterates through an object replacing all or part of matching string values
# with the specified value using regular expressions.
function Set-PSObjectText
{
    param (
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        $InputObject,

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$OldValue, # Regex

        [Parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$NewValue # Regex
    )

    if ($null -eq $InputObject)
    {
        return
    }

    switch ($InputObject.GetType().Name)
    {
        String
        {
            $InputObject = $InputObject -replace $OldValue, $NewValue
        }
        PSCustomObject
        {
            foreach ($item in $InputObject.PSObject.Properties | Where-Object -Property MemberType -EQ 'NoteProperty')
            {
                $ItemName = $item.Name
                $InputObject.$ItemName = Set-PSObjectText -InputObject $($InputObject.$ItemName) -OldValue $OldValue -NewValue $NewValue
            }
        }
        'Object[]' # Array
        {
            $InputObject = foreach ($item in $InputObject)
            {
                Set-PSObjectText -InputObject $item -OldValue $OldValue -NewValue $NewValue
            }
        }
        Int64
        {
            # Do nothing to the Object.
        }
        Boolean
        {
            # Do nothing to the Object.
        }
        Default
        {
            # Do nothing to the Object.
        }
    }

    return $InputObject
}

# Converts From JSON Without Deserializing DateTime Strings
# Dates must be in the roundtrip format and specify the offset (DateTimeKind.Local or DateTimeKind.Utc).
# Examples:
#  - 2009-06-15T13:45:30.0000000Z
#  - 2009-06-15T13:45:30.0000000-07:00
#  - 2009-06-15T13:45:00-07:00
# More Information: Since PowerShell v6, ConvertTo-Json automatically deserializes strings that contain
# an "o"-formatted (roundtrip format) date/time string (e.g., "2023-06-15T13:45:00.123Z")
# or a prefix of it that includes at least everything up to the seconds part as [datetime] instances.
function ConvertFrom-JsonWithoutDateTimeDeserialization
{
    param (
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$InputObject
    )

    # Set the regular expression patterns.
    $DateTimeRegex = '"(\d+-\d+.\d+T\d+:\d+:\d+\.?\d+(\+|\-)\d+:\d+)"'
    $DateTimeRegexWithHash = '(#)(\d+-\d+.\d+T\d+:\d+:\d+\.?\d+(\+|\-)\d+:\d+)'

    # Prepend the hash sign to round-trip date/time pattern strings.
    [string]$JsonWithPrefix = $InputObject -replace $DateTimeRegex, '"#$1"'

    # Convert to a PSCustomObject object.
    [pscustomobject]$PSObjectWithPrefix = $JsonWithPrefix | ConvertFrom-Json

    # Remove the added hash signs.
    Set-PSObjectText -InputObject $PSObjectWithPrefix -OldValue $DateTimeRegexWithHash -NewValue '$2'

    # return $InputObject
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
