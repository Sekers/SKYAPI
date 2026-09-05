# Set Global User Data Path Variable
New-Variable -Name 'sky_api_user_data_path' -Value "$([Environment]::GetEnvironmentVariable('LOCALAPPDATA'))\SKYAPI PowerShell" -Scope Global -Force

# Aliases
Set-Alias -Name Get-SchoolLegacyList -Value Get-SchoolList
Set-Alias -Name Get-SchoolSchedulesMeetings -Value Get-SchoolScheduleMeeting
Set-Alias -Name Get-SchoolActivityBySchoolLevel -Value Get-SchoolActivitySectionBySchoolLevel
Set-Alias -Name Get-SchoolActivityListBySchoolLevel -Value Get-SchoolActivitySectionBySchoolLevel
Set-Alias -Name Get-SchoolAdvisoryBySchoolLevel -Value Get-SchoolAdvisorySectionBySchoolLevel
Set-Alias -Name Get-SchoolAdvisoryListBySchoolLevel -Value Get-SchoolAdvisorySectionBySchoolLevel
Set-Alias -Name Get-SchoolCourseList -Value Get-SchoolCourse
Set-Alias -Name Get-SchoolDepartmentList -Value Get-SchoolDepartment
Set-Alias -Name Get-SchoolEducationList -Value Get-SchoolUserEducation
Set-Alias -Name Get-SchoolGradeLevelList -Value Get-SchoolGradeLevel
Set-Alias -Name Get-SchoolLevelList -Value Get-SchoolLevel
Set-Alias -Name Get-SchoolNewsCategories -Value Get-SchoolNewsCategory
Set-Alias -Name Get-SchoolNewsItems -Value Get-SchoolNewsItem
Set-Alias -Name Get-SchoolOfferingTypeList -Value Get-SchoolOfferingType
Set-Alias -Name Get-SchoolRoleList  -Value Get-SchoolRole
Set-Alias -Name Get-SchoolRoster -Value Get-SchoolAcademicRoster
Set-Alias -Name Get-SchoolSectionBySchoolLevel -Value Get-SchoolAcademicSectionBySchoolLevel
Set-Alias -Name Get-SchoolSectionListBySchoolLevel -Value Get-SchoolAcademicSectionBySchoolLevel
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

# Assembly Dependencies

# [System.Web.HttpUtility] builds every request's query string (see Get-SKYAPIRequestParameter) and encodes
# the authentication URIs. Windows PowerShell 5.1 does not resolve that type on its own, so it is loaded at
# import: any exported function can be the first one called, and each must work without a particular call
# having run before it. PowerShell Core carries HttpUtility in the shared framework and resolves it itself.
if ($PSVersionTable.PSEdition -eq 'Desktop')
{
    Add-Type -AssemblyName System.Web -ErrorAction Stop
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
            $EdgeWebView2Control_VersionNumber = '1.0.4078.44'
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

            # TODO: Consider arm64 support in the future.
            # Download the WebView2 control: https://www.nuget.org/packages/Microsoft.Web.WebView2/
            # Release Notes for the WebView2 SDK: https://learn.microsoft.com/en-us/microsoft-edge/webview2/release-notes/
            # Unpack the nupkg and grab the following two DLLs out of the '/lib/net462' and '/lib_manual/netcoreapp3.0' folders.
            # - Microsoft.Web.WebView2.Core.dll (while there's a copy for each .NET type, so far they have been the same exact file; same file for x86 & x64)
            # - Microsoft.Web.WebView2.WinForms.dll (there's a different version for each .NET type; same file for x86 & x64)
            # In addition, get the following file from the '/runtimes' folder and put it in the same locations.
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
        | Out-File -FilePath $sky_api_tokens_file_path -Force -Encoding utf8
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

# Pull the HTTP status code off a failed web request, or return $null when there isn't one.
#
# This is the fallback for responses whose body cannot be classified: an edge or gateway failure often carries
# an HTML page (or nothing at all) rather than the JSON error object the API itself returns, and without this
# a transient 502/503 from the gateway would be thrown immediately instead of retried.
#
# The property is read duck-typed rather than through a cast because the exception type differs by edition:
# System.Net.WebException on Windows PowerShell 5.1, Microsoft.PowerShell.Commands.HttpResponseException on
# PowerShell 7. Both expose .Response.StatusCode as an [HttpStatusCode] enum, which casts to [int] the same way.
# A transport-level failure (DNS, timeout, connection reset) has no response at all, hence the try/catch and
# the null checks: those must keep throwing, since there is no status to act on.
function Get-SKYAPIErrorStatusCode
{
    [CmdletBinding()]
    Param(
        [parameter(Position=0, Mandatory=$true)]
        [AllowNull()]
        $InvokeErrorMessageRaw
    )

    try
    {
        $Response = $InvokeErrorMessageRaw.Exception.Response
        if ($null -eq $Response) { return $null }

        $StatusCode = $Response.StatusCode
        if ($null -eq $StatusCode) { return $null }

        return [int]$StatusCode
    }
    catch
    {
        return $null
    }
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
    # Not every failure carries a parseable body: transport-level errors and some API responses have no
    # ErrorDetails at all. Check for that first, because piping $null to ConvertFrom-Json raises a
    # NON-TERMINATING error, which the catch below would not see. That left $InvokeErrorMessage holding the
    # "empty pipeline" value, which compares equal to $null but enumerates as zero elements, so the Switch
    # further down matched nothing (not even its default) and this function returned without throwing. The
    # caller then treated a failed call as a success.
    #
    # An unusable body is not the same as an unusable response, though. A gateway 502 or 503 typically returns
    # an HTML page, or no body at all, and classifying those purely by body content meant they threw
    # immediately while the identical failure carrying a JSON body retried. So before giving up on either
    # path below, fall back to the response's own status code and dispatch on that through the same Switch.
    # Only when there is no status code either (a genuine transport failure) does this still throw, which is
    # what keeps a failed call from ever looking like a successful one.
    #
    # Both are initialized explicitly: an unassigned variable read inside a function falls through to the
    # parent scope, so a same-named variable in a caller could otherwise leak in and be dispatched on.
    $InvokeErrorMessage = $null
    $FallbackStatusCode = $null
    $ErrorBody = $InvokeErrorMessageRaw.ErrorDetails.Message

    if ([string]::IsNullOrWhiteSpace($ErrorBody))
    {
        $FallbackStatusCode = Get-SKYAPIErrorStatusCode $InvokeErrorMessageRaw
        if ($null -eq $FallbackStatusCode)
        {
            throw $InvokeErrorMessageRaw
        }
    }
    else
    {
        try
        {
            # -ErrorAction Stop is required to make the catch reachable; without it a malformed body is a
            # non-terminating error and execution continues with nothing parsed.
            $InvokeErrorMessage = $ErrorBody | ConvertFrom-Json -ErrorAction Stop
        }
        catch
        {
            $FallbackStatusCode = Get-SKYAPIErrorStatusCode $InvokeErrorMessageRaw
            if ($null -eq $FallbackStatusCode)
            {
                throw $InvokeErrorMessageRaw
            }
        }
    }

    # Get Status Code (preferred), or Error if Code is blank. Blackbaud sends error messages at least 5 different ways so we need to account for that. Yay for no consistency.
    If ($null -ne $FallbackStatusCode)
    {
        # The body told us nothing; the response's own status code is all there is to go on.
        $StatusCodeorError = $FallbackStatusCode
    }
    elseif ($InvokeErrorMessage.statusCode)
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

    # Switch enumerates its input, so a value that enumerates to nothing skips every case INCLUDING default,
    # and this function would fall through and return nothing. A plain $null does dispatch to default, so
    # testing the enumerated count is what catches the empty-pipeline case as well.
    if (@($StatusCodeorError).Count -eq 0)
    {
        throw $InvokeErrorMessageRaw
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
        502 # Bad Gateway. An upstream service returned an invalid response. Transient, like its 500/503/504 neighbors.
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
        $authorisation = Get-SKYAPIAuthTokensFromFile
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

            # Just in case the token was refreshed by the error catcher, update $authorisation
            $authorisation = Get-SKYAPIAuthTokensFromFile
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    # A successful call returns from inside the try above, so reaching here always means the call failed.
    # Never fall through silently: returning nothing would make a failed call look like a successful one that
    # simply had no data to return.
    if ($null -ne $LastCaughtError)
    {
        throw $LastCaughtError
    }

    throw "The SKY API request failed but did not report a specific error. Retry attempts: $InvokeCount of $MaxInvokeCount."
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
        [MarkerType]$marker_type,

        # Fields that are date-only despite not arriving at midnight (see ConvertTo-SKYAPIDateTimeValue).
        [string[]]$date_only_fields = @())

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $authorisation = Get-SKYAPIAuthTokensFromFile
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
                # Fetch as text and parse with date/time values left as strings, then normalize them. Going
                # through Invoke-RestMethod would let ConvertFrom-Json deserialize dates into the CLIENT's
                # local time on PowerShell 7, which loses the calendar date the API actually wrote and put
                # every date-only field a day out for anyone west of the school. Windows PowerShell 5.1 left
                # them as raw strings instead, so this also makes the two editions agree.
                # See Research_Notes/DateTime-Handling.md.
                $apiResponse =
                Invoke-WebRequest   -UseBasicParsing `
                                    -Method Get `
                                    -ContentType application/json `
                                    -Headers @{
                                            'Authorization' = ("Bearer "+ $authorisation.access_token)
                                            'bb-api-subscription-key' = ($api_key)} `
                                    -Uri $($Request.Uri.AbsoluteUri)

                $apiItems = ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $apiResponse.Content
                $null = Repair-SKYAPIResponseDateTime -InputObject $apiItems -DateOnlyFields $date_only_fields

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

            # Return rather than just emitting, to match the other entity functions: the code after the retry
            # loop now treats "execution reached here" as failure, and a success that happened to land on the
            # final retry attempt would otherwise emit its records and then raise an error.
            return $allRecords
        }
        catch
        {
            # Process Invoke Error
            $LastCaughtError = ($_)
            $NextAction = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $_ -InvokeCount $InvokeCount -MaxInvokeCount $MaxInvokeCount

            # Just in case the token was refreshed by the error catcher, update $authorisation
            $authorisation = Get-SKYAPIAuthTokensFromFile
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    # A successful call returns from inside the try above, so reaching here always means the call failed.
    # Never fall through silently: returning nothing would make a failed call look like a successful one that
    # simply had no data to return.
    if ($null -ne $LastCaughtError)
    {
        throw $LastCaughtError
    }

    throw "The SKY API request failed but did not report a specific error. Retry attempts: $InvokeCount of $MaxInvokeCount."
}

Function Remove-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $authorisation = Get-SKYAPIAuthTokensFromFile
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

            # Just in case the token was refreshed by the error catcher, update $authorisation
            $authorisation = Get-SKYAPIAuthTokensFromFile
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    # A successful call returns from inside the try above, so reaching here always means the call failed.
    # Never fall through silently: returning nothing would make a failed call look like a successful one that
    # simply had no data to return.
    if ($null -ne $LastCaughtError)
    {
        throw $LastCaughtError
    }

    throw "The SKY API request failed but did not report a specific error. Retry attempts: $InvokeCount of $MaxInvokeCount."
}

function Submit-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $authorisation = Get-SKYAPIAuthTokensFromFile
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

            # Just in case the token was refreshed by the error catcher, update $authorisation
            $authorisation = Get-SKYAPIAuthTokensFromFile
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    # A successful call returns from inside the try above, so reaching here always means the call failed.
    # Never fall through silently: returning nothing would make a failed call look like a successful one that
    # simply had no data to return.
    if ($null -ne $LastCaughtError)
    {
        throw $LastCaughtError
    }

    throw "The SKY API request failed but did not report a specific error. Retry attempts: $InvokeCount of $MaxInvokeCount."
}

function Update-SKYAPIEntity
{
    [CmdletBinding()]
    Param($uid, $url, $endUrl, $api_key, $authorisation, $params, $response_field)

    # Reconnect If the Access Token is Expired 
    if (-NOT (Confirm-SKYAPITokenIsFresh -TokenCreation $authorisation.access_token_creation -TokenType Access))
    {
        Connect-SKYAPI -ForceRefresh
        $authorisation = Get-SKYAPIAuthTokensFromFile
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

            # Just in case the token was refreshed by the error catcher, update $authorisation
            $authorisation = Get-SKYAPIAuthTokensFromFile
        }
    }while ($NextAction -eq 'retry' -and $InvokeCount -lt $MaxInvokeCount)

    # A successful call returns from inside the try above, so reaching here always means the call failed.
    # Never fall through silently: returning nothing would make a failed call look like a successful one that
    # simply had no data to return.
    if ($null -ne $LastCaughtError)
    {
        throw $LastCaughtError
    }

    throw "The SKY API request failed but did not report a specific error. Retry attempts: $InvokeCount of $MaxInvokeCount."
}

# Validates a value against a SKY API Types table (via Get-SchoolTypeTableValue), accepting either the
# table value's descriptor (name, case-insensitive) or its ID. Fetched tables are cached in the supplied
# hashtable so each table is only retrieved once per command invocation (even across a piped batch of users).
# If the table returns no values - typically because the calling user lacks permission to read it - client-side
# validation is skipped and the value is passed through for the API to validate instead.
function Confirm-SKYAPITypeTableValue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [hashtable]$Cache,

        [Parameter(Mandatory=$false)]
        [string]$ParameterName = $TableName
    )

    # Nothing to validate for empty values (the field simply isn't being set here).
    if ([string]::IsNullOrWhiteSpace($Value))
    {
        return
    }

    $TableRow = Get-SKYAPITypeTableRow -Value $Value -TableName $TableName -Cache $Cache

    # If we couldn't read any values (e.g., insufficient permissions), skip client-side validation
    # and let the API validate the value instead. This is a best-effort pre-flight check, so a table we
    # can't read is not worth failing over.
    if ($null -eq $TableRow)
    {
        return
    }

    if ($TableRow -is [string])   # the 'NoMatch' marker; real rows are never strings
    {
        throw "Invalid '$ParameterName' value '$Value'. Use a descriptor or ID from the '$TableName' table (see Get-SchoolTypeTableValue -tableName '$TableName')."
    }
}

# Resolve a Types table value (supplied as either a descriptor or an ID) to its full table row.
# Returns $null if the table can't be read; returns 'NoMatch' if the table was read but the value isn't in it.
function Get-SKYAPITypeTableRow
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [hashtable]$Cache
    )

    # Fetch the table once and cache it for the remainder of the command invocation.
    if (-not $Cache.ContainsKey($TableName))
    {
        $Cache[$TableName] = @(Get-SchoolTypeTableValue -tableName $TableName -includeInactive $true)
    }
    $TableValues = $Cache[$TableName]

    # Unreadable table (e.g., insufficient permissions). The caller decides what that means.
    if ($null -eq $TableValues -or $TableValues.Count -eq 0)
    {
        return $null
    }

    foreach ($TableValue in $TableValues)
    {
        if ([string]::Equals([string]$TableValue.name,$Value,[System.StringComparison]::OrdinalIgnoreCase) -or ([string]$TableValue.id -eq $Value))
        {
            return $TableValue
        }
    }

    return 'NoMatch'
}

# Build the parameter collection for an API request out of a function's bound parameters.
#
# Every request this module sends is assembled by copying $PSBoundParameters, which also holds any common
# parameters the caller passed explicitly (-Verbose, -ErrorAction, ...) along with the function's own control
# parameters (-ReturnRaw, -ResponseLimit) and any IDs that travel in the URL instead of the request. None of
# those are API fields, so every function funnels through here to drop them. Centralizing it keeps the rules
# below in one place, where they hold for all 36 callers instead of being restated at each one.
#
# The -As choice is not cosmetic; each request helper needs a specific type:
#   Query - NameValueCollection, for GET and DELETE. Get-SKYAPIUnpagedEntity, Get-SKYAPIPagedEntity and
#           Remove-SKYAPIEntity all build the URL with $params.ToString(), and only a NameValueCollection
#           stringifies to 'a=1&b=2'. Hand one of them a hashtable and ToString() yields the literal
#           'System.Collections.Hashtable', silently dropping every value.
#   Body  - hashtable, for POST and PATCH. Submit-SKYAPIEntity and Update-SKYAPIEntity serialize it with
#           ConvertTo-Json, which needs the nested objects and arrays a NameValueCollection cannot hold.
#
# The returned collection is deliberately mutable: several callers add or replace entries afterward, both
# paging values ('limit', 'offset', 'page') and per-iteration values ('level_num', 'role_id').
function Get-SKYAPIRequestParameter
{
    [CmdletBinding()]
    param (
        # The calling function's $PSBoundParameters.
        [Parameter(Mandatory=$true)]
        [hashtable]$BoundParameters,

        # Parameter names that are not API fields: IDs passed in the URL, paging controls handled
        # separately, and control switches such as -ReturnRaw.
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Exclude,

        # The names the CURRENT pipeline record actually supplied, from Get-SKYAPISuppliedParameterName.
        # Anything bound but not named here is a leftover from an earlier record and is dropped. Omit this
        # to keep every bound parameter, which is the right thing for a function with no process block.
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SuppliedNames,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Query','Body')]
        [string]$As = 'Query'
    )

    # Ask the runtime for the common parameter names rather than hardcoding them, since the list grows
    # between versions (-ProgressAction, for instance, only exists on PowerShell 7.4+).
    # Matching is case-insensitive because PowerShell itself binds parameter names that way.
    $ExcludedNames = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]([System.Management.Automation.PSCmdlet]::CommonParameters),
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($Name in $Exclude)
    {
        if (-not [string]::IsNullOrWhiteSpace($Name))
        {
            $null = $ExcludedNames.Add($Name)
        }
    }

    # When the caller told us what the current record supplied, everything else bound is stale. $null and an
    # empty set are different answers here: $null means "not filtering", an empty set means "this record
    # supplied nothing", so test whether the parameter was passed rather than whether it has contents.
    $SuppliedSet = $null
    if ($PSBoundParameters.ContainsKey('SuppliedNames') -and $null -ne $SuppliedNames)
    {
        $SuppliedSet = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]$SuppliedNames,
            [System.StringComparer]::OrdinalIgnoreCase)
    }

    if ($As -eq 'Body')
    {
        $Parameters = @{}
        foreach ($Parameter in $BoundParameters.GetEnumerator())
        {
            if (-not $ExcludedNames.Contains($Parameter.Key) -and
                ($null -eq $SuppliedSet -or $SuppliedSet.Contains($Parameter.Key)))
            {
                $Parameters.Add($Parameter.Key,$Parameter.Value)
            }
        }

        return $Parameters
    }

    $Parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($Parameter in $BoundParameters.GetEnumerator())
    {
        if (-not $ExcludedNames.Contains($Parameter.Key) -and
            ($null -eq $SuppliedSet -or $SuppliedSet.Contains($Parameter.Key)))
        {
            $Parameters.Add($Parameter.Key,$Parameter.Value)
        }
    }

    # The leading comma matters. A NameValueCollection is enumerable, so returning it bare makes PowerShell
    # unroll it into an Object[] of its keys - ToString() on that gives 'System.Object[]' and the query string
    # is quietly destroyed. Wrapping it keeps the collection itself intact.
    return ,$Parameters
}

# Work out which parameters the CURRENT pipeline record actually supplied.
#
# This exists because $PSBoundParameters is not reset between pipeline records. PowerShell rebinds the
# parameter VARIABLES on every record (an optional parameter the new record omits goes back to its type
# default), but leaves the previous record's entry sitting in $PSBoundParameters. Since every write function
# builds its request from $PSBoundParameters, a record that omitted a field inherited the previous record's
# value for it - piping two users where only the first sets middle_name wrote that middle name to both.
# Reproduced identically on PowerShell 7 and Windows PowerShell 5.1.
#
# A name counts as supplied when any of these holds:
#   1. There is no pipeline at all, so everything bound came from the command line. Nothing can be stale.
#   2. It was bound from the command line. Those apply to every record, and are captured in begin{} where
#      $PSBoundParameters still holds only command-line arguments (pipeline binding has not happened yet).
#   3. The current record carries a property of that name, which is exactly what ValueFromPipelineByPropertyName
#      binds from.
#   4. It is declared ValueFromPipeline (bound BY VALUE). Such a parameter receives the record itself, so it is
#      never stale, and rule 3 cannot see it: piping bare strings to New-SchoolEventCategory binds -description
#      by value from an object that has no matching property.
function Get-SKYAPISuppliedParameterName
{
    [OutputType([System.Collections.Generic.HashSet[string]])]
    [CmdletBinding()]
    param (
        # The calling function's $PSBoundParameters.
        [Parameter(Mandatory=$true)]
        [hashtable]$BoundParameters,

        # $PSBoundParameters.Keys as captured in the caller's begin block.
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$CommandLineBound,

        # The caller's current $PSItem.
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        $PipelineItem,

        # The caller's $MyInvocation.
        [Parameter(Mandatory=$true)]
        $Invocation
    )

    $Supplied = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Rule 1. Also the safe fallback: keeping everything is exactly today's behavior.
    if (-not $Invocation.ExpectingInput)
    {
        foreach ($Name in $BoundParameters.Keys) { $null = $Supplied.Add($Name) }
        return ,$Supplied
    }

    # Rule 2.
    foreach ($Name in $CommandLineBound)
    {
        if (-not [string]::IsNullOrWhiteSpace($Name)) { $null = $Supplied.Add($Name) }
    }

    # Rule 3. A bare scalar record has no properties to contribute, which is correct - nothing binds by
    # property name from it.
    if ($null -ne $PipelineItem)
    {
        foreach ($Property in $PipelineItem.PSObject.Properties)
        {
            $null = $Supplied.Add($Property.Name)
        }
    }

    # Rule 4.
    foreach ($Parameter in $Invocation.MyCommand.Parameters.GetEnumerator())
    {
        foreach ($Attribute in $Parameter.Value.Attributes)
        {
            if ($Attribute -is [System.Management.Automation.ParameterAttribute] -and $Attribute.ValueFromPipeline)
            {
                $null = $Supplied.Add($Parameter.Key)
                break
            }
        }
    }

    # Leading comma: a HashSet is enumerable, so returning it bare unrolls it into an Object[].
    return ,$Supplied
}

# Compare the fields a write function sent against a re-read of the record, and report anything that didn't apply.
# Returns finding objects; returns nothing when everything checks out.
#
# This never throws on a data difference - the calling function owns that policy (Update-SchoolUser throws on any
# finding). Findings come in two kinds:
#   Mismatch     - the read-back disagrees with what was sent.
#   Unverifiable - the comparison couldn't be trusted (record unreadable, Types table unreadable, unmapped field).
# Both are reported. Deliberately NOT reported: nothing. There is no silent-skip path, because the whole point of a
# validated write is that "no news" means verified, not "we gave up quietly".
#
# Note on empty vs. absent read-back values: these are treated identically (both are a Mismatch when a value was
# sent). A field hidden by permissions and a field the API silently ignored are not distinguishable from the
# response, so the caller's error message names both possible causes rather than asserting one.
#
# Measured on a School API user read (2026-07-28, one record on one tenant):
#   Get-SchoolUserExtended  81 of 81 schema fields present - 0 omitted, 0 JSON null, 21 empty strings
#   Get-SchoolUser          33 of 33 schema fields present - 0 omitted, 0 JSON null, 13 empty strings
#   A field cleared via -fields_to_delete comes back present, as "" (e.g. "middle_name":"").
# So the API returns every schema field and represents blank as an empty string; it neither omits properties nor
# sends null. The "absent" branch below therefore does not fire against real responses - it is kept because the
# schema still permits it (no property is declared required and most are declared nullable).
#
# Do not reintroduce a rule that reads "absent" as "hidden by permissions" and "empty" as "the API ignored it".
# That was tried and removed: it is unsupported by the schema, and the measurement above shows blank fields are
# empty strings rather than nulls, so the split would misclassify ordinary blanks. Settling it needs one test that
# has not been run - whether a field the caller lacks permission to see is omitted or returned as "" - which
# requires a credential without the 'SKY API Data Sync' role. Until that is answered, treating both as a Mismatch
# is correct either way, which is why it is done that way here.
function Confirm-SKYAPIWriteResult
{
    [CmdletBinding()]
    param (
        # The re-read record. $null means the read-back returned nothing.
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Actual,

        # The fields as sent to the API (the write function's $parameters). Keys with no $FieldSpec entry are ignored,
        # which is what skips control keys like 'id' and 'fields_to_delete'.
        [Parameter(Mandatory=$true)]
        [hashtable]$Expected,

        # Per-field comparison rules. See Update-SchoolUser's $ValidationFieldSpec for the shape.
        [Parameter(Mandatory=$true)]
        [System.Collections.IDictionary]$FieldSpec,

        # Which read model $Actual came from. Selects between the spec's 'Read' and 'BasicRead' names.
        [Parameter(Mandatory=$false)]
        [ValidateSet('Basic','Extended')]
        [string]$ReadModel = 'Extended',

        # Fields the write asked to clear (e.g. -fields_to_delete). Supports 'object.field' notation.
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [string[]]$ClearedFields,

        # Shared Types table cache, so validation reuses tables the send-side checks already fetched.
        [Parameter(Mandatory=$false)]
        [hashtable]$Cache = @{},

        # For DELETE: the record is expected to be gone.
        [Parameter(Mandatory=$false)]
        [switch]$ExpectAbsent,

        [Parameter(Mandatory=$false)]
        [string]$RecordDescription = 'record'
    )

    $Findings = [System.Collections.Generic.List[object]]::new()

    function New-SKYAPIFinding
    {
        param ($Field,$Sent,$Actual,$Reason,$Kind)
        [pscustomobject]@{
            Field  = $Field
            Sent   = $Sent
            Actual = $Actual
            Reason = $Reason
            Kind   = $Kind
        }
    }

    # Read a property without caring whether it's absent or present-but-null (see the note above).
    function Get-SKYAPIMemberValue
    {
        param ($InputObject,[string]$Name)
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IDictionary])
        {
            if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
            return $null
        }
        $Property = $InputObject.PSObject.Properties[$Name]
        if ($null -eq $Property) { return $null }
        return $Property.Value
    }

    function Test-SKYAPIValueIsBlank
    {
        param ($Value)
        if ($null -eq $Value) { return $true }

        # An unset date is not returned as an empty value: the API sends 0001-01-01T00:00:00+00:00, which the
        # read functions surface as [datetime]::MinValue. Treating that as a real value made clearing a date
        # field (e.g. -fields_to_delete 'deceased_date') report a mismatch even though the clear worked.
        if ($Value -is [datetime]) { return ($Value -eq [datetime]::MinValue) }

        $Text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($Text)) { return $true }

        # Same sentinel, still in string form (e.g. from a raw response). Keep this textual check ahead of the
        # parse below; it is not redundant. Parsing a value that carries an offset converts it to local time,
        # which equals MinValue only at exactly UTC+0, so this line is what makes the sentinel recognizable in
        # every other time zone. Drop it and a cleared date field reads back as a real value, which reports a
        # successful clear as a failed one.
        if ($Text -like '0001-01-01*') { return $true }

        # Catches renderings that do not lead with the ISO date, e.g. '01/01/0001 00:00:00'. Those carry no
        # offset, so nothing is converted and comparing against MinValue is safe in any time zone. Note this
        # cannot be switched to DateTimeOffset: it requires the UTC equivalent to be representable, and at
        # year 0001 a positive local offset puts that before year 1, so the parse fails outright.
        $ParsedDate = [datetime]::MinValue
        if ($Text -match '0001' -and
            [datetime]::TryParse($Text,[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None,[ref]$ParsedDate) -and
            $ParsedDate -eq [datetime]::MinValue)
        {
            return $true
        }

        return $false
    }

    # Get the calendar date a value represents WITHOUT converting between time zones.
    # A validated write compares what was sent against what the record reads back, so the only thing that
    # matters is the calendar day each side names. Date-only fields carry meaningless times and inconsistent
    # offsets (some +00:00, others -05:00 on the same record), so converting either side into an instant and
    # taking .Date moves the answer a day depending on where the script runs, reporting a correctly written
    # date as a mismatch. Reading the wall-clock date the server wrote keeps the comparison stable everywhere.
    function ConvertTo-SKYAPICalendarDate
    {
        param ($Value)

        # The read functions normalize date-only fields to midnight on the day the API wrote, so the day is
        # taken straight off the value. Converting through UTC first would put the client's time zone back
        # into the answer: midnight is the previous day in UTC for any client at or east of UTC, which turns
        # a correctly written date into a reported mismatch everywhere from the UK eastward.
        if ($Value -is [datetime]) { return $Value.Date }
        if ($Value -is [System.DateTimeOffset]) { return $Value.DateTime.Date }

        $Text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

        $Invariant = [System.Globalization.CultureInfo]::InvariantCulture
        $Styles = [System.Globalization.DateTimeStyles]::None

        $Offset = [System.DateTimeOffset]::MinValue
        if ([System.DateTimeOffset]::TryParse($Text,$Invariant,$Styles,[ref]$Offset)) { return $Offset.DateTime.Date }

        $Plain = [datetime]::MinValue
        if ([datetime]::TryParse($Text,$Invariant,$Styles,[ref]$Plain)) { return $Plain.Date }
        if ([datetime]::TryParse($Text,[ref]$Plain)) { return $Plain.Date }

        return $null
    }

    # DELETE: the only question is whether the record is gone.
    if ($ExpectAbsent)
    {
        if ($null -ne $Actual)
        {
            $Findings.Add((New-SKYAPIFinding -Field '(record)' -Sent '(deleted)' -Actual '(still present)' `
                -Reason "the $RecordDescription still exists after the delete" -Kind 'Mismatch'))
        }
        return $Findings
    }

    if ($null -eq $Actual)
    {
        $Findings.Add((New-SKYAPIFinding -Field '(record)' -Sent '' -Actual '' `
            -Reason "the $RecordDescription could not be read back" -Kind 'Unverifiable'))
        return $Findings
    }

    # Fields being cleared are validated against blank, and they override any value sent in the same request.
    $ClearedLookup = @{}
    foreach ($ClearedField in @($ClearedFields))
    {
        if (-not [string]::IsNullOrWhiteSpace($ClearedField)) { $ClearedLookup[$ClearedField] = $true }
    }

    # Compare one leaf value (scalar, date, or Types table backed) and return $null on a match or a reason string on a
    # mismatch. Returns an 'Unverifiable:' prefixed reason when the comparison itself couldn't be trusted.
    function Compare-SKYAPILeafValue
    {
        param ($Sent,$ActualValue,[System.Collections.IDictionary]$LeafSpec,[hashtable]$TypeTableCache)

        $Kind = $LeafSpec['Kind']
        if ([string]::IsNullOrWhiteSpace($Kind)) { $Kind = 'Scalar' }

        # A blank sent value is compared as blank whatever the Kind, matching the pre-flight check's treatment of blanks.
        # Don't try to resolve '' against a Types table or parse it as a date - that would report "unverifiable" for what
        # is really an ordinary comparison. Whether an endpoint honors a blank at all is endpoint-specific (V1UsersPatch
        # ignores them and requires fields_to_delete), so just report what came back and let the caller judge.
        if (Test-SKYAPIValueIsBlank $Sent)
        {
            if (Test-SKYAPIValueIsBlank $ActualValue) { return $null }
            $ShownActual = Get-SKYAPIMemberValue -InputObject $ActualValue -Name 'description'
            if ($null -eq $ShownActual) { $ShownActual = $ActualValue }
            return "sent an empty value but read back '$ShownActual'"
        }

        switch ($Kind)
        {
            'Date'
            {
                $SentDate = ConvertTo-SKYAPICalendarDate $Sent
                if ($null -eq $SentDate)
                {
                    return "Unverifiable:the value sent ('$Sent') could not be parsed as a date"
                }
                if (Test-SKYAPIValueIsBlank $ActualValue)
                {
                    return "sent '$Sent' but read back empty"
                }

                $ActualDate = ConvertTo-SKYAPICalendarDate $ActualValue
                if ($null -eq $ActualDate)
                {
                    return "Unverifiable:the value read back ('$ActualValue') could not be parsed as a date"
                }

                if ($SentDate -ne $ActualDate)
                {
                    return "sent '$($SentDate.ToString('yyyy-MM-dd'))' but read back '$($ActualDate.ToString('yyyy-MM-dd'))'"
                }
                return $null
            }

            'TypeTable'
            {
                $TableName = $LeafSpec['Table']
                $Row = Get-SKYAPITypeTableRow -Value ([string]$Sent) -TableName $TableName -Cache $TypeTableCache
                if ($null -eq $Row)
                {
                    return "Unverifiable:the '$TableName' Types table could not be read, so the value sent ('$Sent') can't be resolved"
                }
                if ($Row -is [string])   # the 'NoMatch' marker; real rows are never strings
                {
                    return "Unverifiable:the value sent ('$Sent') is not in the '$TableName' Types table"
                }

                # The read side is either a plain descriptor string or an {id, description} object.
                $ActualId = Get-SKYAPIMemberValue -InputObject $ActualValue -Name 'id'
                $ActualDescription = Get-SKYAPIMemberValue -InputObject $ActualValue -Name 'description'
                if ($null -ne $ActualId)
                {
                    if ([string]$ActualId -eq [string]$Row.id) { return $null }
                    $Shown = if ($null -ne $ActualDescription) { $ActualDescription } else { $ActualId }
                    return "sent '$Sent' but read back '$Shown'"
                }

                if (Test-SKYAPIValueIsBlank $ActualValue)
                {
                    return "sent '$Sent' but read back empty"
                }
                if ([string]::Equals([string]$ActualValue,[string]$Row.name,[System.StringComparison]::OrdinalIgnoreCase) -or
                    ([string]$ActualValue -eq [string]$Row.id))
                {
                    return $null
                }
                return "sent '$Sent' but read back '$ActualValue'"
            }

            default # Scalar
            {
                $SentText = ([string]$Sent).Trim()

                if (Test-SKYAPIValueIsBlank $ActualValue)
                {
                    if ([string]::IsNullOrWhiteSpace($SentText)) { return $null }
                    return "sent '$Sent' but read back empty"
                }

                $ActualText = ([string]$ActualValue).Trim()

                # Aliases are an equivalence map, not a send-side translation: a field that accepts several spellings can
                # return any of them (boarding_or_day accepts 'boarding'/'B' and returns 'B'), so fold both sides.
                $Aliases = $LeafSpec['Aliases']
                if ($null -ne $Aliases)
                {
                    if ($Aliases.Contains($SentText))   { $SentText = [string]$Aliases[$SentText] }
                    if ($Aliases.Contains($ActualText)) { $ActualText = [string]$Aliases[$ActualText] }
                }

                if ([string]::Equals($SentText,$ActualText,[System.StringComparison]::OrdinalIgnoreCase)) { return $null }
                return "sent '$Sent' but read back '$ActualValue'"
            }
        }
    }

    foreach ($SentField in $Expected.Keys)
    {
        if (-not $FieldSpec.Contains($SentField)) { continue }   # control keys such as 'id' and 'fields_to_delete'
        if ($ClearedLookup.ContainsKey($SentField)) { continue } # handled by the cleared-fields pass below

        $Spec = $FieldSpec[$SentField]
        $SentValue = $Expected[$SentField]

        # Resolve the read-side name for the model this record came from.
        if ($ReadModel -eq 'Basic') { $ReadName = $Spec['BasicRead'] } else { $ReadName = $Spec['Read'] }
        if ([string]::IsNullOrWhiteSpace($ReadName)) { $ReadName = $SentField }

        if ($ReadModel -eq 'Basic' -and -not $Spec.Contains('BasicRead'))
        {
            $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual '' `
                -Reason "'$SentField' isn't returned by the basic user read, so it can't be validated from it" -Kind 'Unverifiable'))
            continue
        }

        if ($Spec['Unmapped'])
        {
            $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual '' `
                -Reason "no confirmed read-back field is known for '$SentField', so it can't be validated" -Kind 'Unverifiable'))
            continue
        }

        $ActualValue = Get-SKYAPIMemberValue -InputObject $Actual -Name $ReadName
        $Kind = $Spec['Kind']
        if ([string]::IsNullOrWhiteSpace($Kind)) { $Kind = 'Scalar' }

        switch ($Kind)
        {
            'TypeTableArray'
            {
                $ItemKey = $Spec['ItemKey']
                $ReadItemKey = $Spec['ReadItemKey']
                $TableName = $Spec['Table']

                $SentIds = [System.Collections.Generic.List[string]]::new()
                $Unresolved = $null
                foreach ($SentItem in @($SentValue))
                {
                    $RawValue = Get-SKYAPIMemberValue -InputObject $SentItem -Name $ItemKey
                    if ($null -eq $RawValue) { $RawValue = $SentItem }

                    # Blank entries contribute nothing to the expected set, so an all-blank array means "expected empty".
                    if (Test-SKYAPIValueIsBlank $RawValue) { continue }

                    $Row = Get-SKYAPITypeTableRow -Value ([string]$RawValue) -TableName $TableName -Cache $Cache
                    if ($null -eq $Row)
                    {
                        $Unresolved = "the '$TableName' Types table could not be read, so the values sent can't be resolved"
                        break
                    }
                    if ($Row -is [string])   # the 'NoMatch' marker; real rows are never strings
                    {
                        $Unresolved = "the value sent ('$RawValue') is not in the '$TableName' Types table"
                        break
                    }
                    $SentIds.Add([string]$Row.id)
                }

                if ($null -ne $Unresolved)
                {
                    $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual $ActualValue `
                        -Reason $Unresolved -Kind 'Unverifiable'))
                    continue
                }

                $ActualIds = [System.Collections.Generic.List[string]]::new()
                foreach ($ActualItem in @($ActualValue))
                {
                    if ($null -eq $ActualItem) { continue }
                    $ActualIds.Add([string](Get-SKYAPIMemberValue -InputObject $ActualItem -Name $ReadItemKey))
                }

                # Order-insensitive set comparison, in BOTH directions: the API doesn't preserve the order values were sent
                # in, and a PATCH replaces the whole array rather than appending to it (confirmed by test), so a value the
                # caller left out but that is still present means the removal didn't take.
                $Missing = @($SentIds | Where-Object { $ActualIds -notcontains $_ })
                $Extra = @($ActualIds | Where-Object { $SentIds -notcontains $_ })
                if ($Missing.Count -gt 0 -or $Extra.Count -gt 0)
                {
                    $SentShown = (@($SentValue) | ForEach-Object { [string](Get-SKYAPIMemberValue -InputObject $_ -Name $ItemKey) }) -join ', '
                    $ActualShown = (@($ActualValue) | ForEach-Object { [string](Get-SKYAPIMemberValue -InputObject $_ -Name 'description') }) -join ', '
                    if ([string]::IsNullOrWhiteSpace($SentShown)) { $SentShown = '(empty)' }
                    if ([string]::IsNullOrWhiteSpace($ActualShown)) { $ActualShown = '(empty)' }
                    $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual $ActualValue `
                        -Reason "sent '$SentShown' but read back '$ActualShown'" -Kind 'Mismatch'))
                }
            }

            'ObjectArray'
            {
                $SubFields = $Spec['SubFields']
                $MatchFields = @($Spec['MatchFields'])
                $SentItems = @($SentValue | Where-Object {$null -ne $_})
                $ActualItems = @($ActualValue | Where-Object {$null -ne $_})

                for ($SentIndex = 0; $SentIndex -lt $SentItems.Count; $SentIndex++)
                {
                    $SentItem = $SentItems[$SentIndex]
                    $Candidates = @($ActualItems)
                    $HasMatchValue = $false

                    # Match an item using every configured identity field that the caller supplied. This keeps
                    # validation stable if the API returns the array in a different order.
                    foreach ($MatchField in $MatchFields)
                    {
                        $SentMatch = Get-SKYAPIMemberValue -InputObject $SentItem -Name $MatchField
                        if ($null -eq $SentMatch) { continue }

                        $HasMatchValue = $true
                        $Candidates = @($Candidates | Where-Object {
                            $ActualMatch = Get-SKYAPIMemberValue -InputObject $_ -Name $MatchField
                            [string]::Equals([string]$SentMatch,[string]$ActualMatch,[System.StringComparison]::OrdinalIgnoreCase)
                        })
                    }

                    # With one item on each side, identity fields are unnecessary. With a larger collection,
                    # guessing by position could validate the wrong relationship.
                    if (-not $HasMatchValue)
                    {
                        if ($SentItems.Count -eq 1 -and $ActualItems.Count -eq 1)
                        {
                            $Candidates = @($ActualItems[0])
                        }
                        else
                        {
                            $Findings.Add((New-SKYAPIFinding -Field "$SentField[$SentIndex]" -Sent $SentItem -Actual $ActualValue `
                                -Reason 'no identity field was supplied, so the returned collection item cannot be selected reliably' -Kind 'Unverifiable'))
                            continue
                        }
                    }

                    if ($Candidates.Count -eq 0)
                    {
                        $Findings.Add((New-SKYAPIFinding -Field "$SentField[$SentIndex]" -Sent $SentItem -Actual $ActualValue `
                            -Reason 'no matching item was returned' -Kind 'Mismatch'))
                        continue
                    }
                    if ($Candidates.Count -gt 1)
                    {
                        $Findings.Add((New-SKYAPIFinding -Field "$SentField[$SentIndex]" -Sent $SentItem -Actual $ActualValue `
                            -Reason 'more than one returned item matched, so the comparison is ambiguous' -Kind 'Unverifiable'))
                        continue
                    }

                    $ActualItem = $Candidates[0]
                    foreach ($SubField in $SubFields.Keys)
                    {
                        $SentSub = Get-SKYAPIMemberValue -InputObject $SentItem -Name $SubField
                        if ($null -eq $SentSub) { continue }

                        $ActualSub = Get-SKYAPIMemberValue -InputObject $ActualItem -Name $SubField
                        $Reason = Compare-SKYAPILeafValue -Sent $SentSub -ActualValue $ActualSub `
                                    -LeafSpec $SubFields[$SubField] -TypeTableCache $Cache
                        if ($null -eq $Reason) { continue }

                        if ($Reason.StartsWith('Unverifiable:'))
                        {
                            $Findings.Add((New-SKYAPIFinding -Field "$SentField[$SentIndex].$SubField" -Sent $SentSub -Actual $ActualSub `
                                -Reason $Reason.Substring(13) -Kind 'Unverifiable'))
                        }
                        else
                        {
                            $Findings.Add((New-SKYAPIFinding -Field "$SentField[$SentIndex].$SubField" -Sent $SentSub -Actual $ActualSub `
                                -Reason $Reason -Kind 'Mismatch'))
                        }
                    }
                }
            }

            'Object'
            {
                $SubFields = $Spec['SubFields']
                foreach ($SubField in $SubFields.Keys)
                {
                    $SentSub = Get-SKYAPIMemberValue -InputObject $SentValue -Name $SubField
                    if ($null -eq $SentSub) { continue }                                  # sub-field wasn't supplied
                    if ($ClearedLookup.ContainsKey("$SentField.$SubField")) { continue }   # cleared instead

                    $ActualSub = Get-SKYAPIMemberValue -InputObject $ActualValue -Name $SubField
                    $Reason = Compare-SKYAPILeafValue -Sent $SentSub -ActualValue $ActualSub -LeafSpec $SubFields[$SubField] -TypeTableCache $Cache
                    if ($null -ne $Reason)
                    {
                        if ($Reason.StartsWith('Unverifiable:'))
                        {
                            $Findings.Add((New-SKYAPIFinding -Field "$SentField.$SubField" -Sent $SentSub -Actual $ActualSub `
                                -Reason $Reason.Substring(13) -Kind 'Unverifiable'))
                        }
                        else
                        {
                            $Findings.Add((New-SKYAPIFinding -Field "$SentField.$SubField" -Sent $SentSub -Actual $ActualSub `
                                -Reason $Reason -Kind 'Mismatch'))
                        }
                    }
                }
            }

            default # Scalar, Date, TypeTable
            {
                $Reason = Compare-SKYAPILeafValue -Sent $SentValue -ActualValue $ActualValue -LeafSpec $Spec -TypeTableCache $Cache
                if ($null -ne $Reason)
                {
                    if ($Reason.StartsWith('Unverifiable:'))
                    {
                        $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual $ActualValue `
                            -Reason $Reason.Substring(13) -Kind 'Unverifiable'))
                    }
                    else
                    {
                        $Findings.Add((New-SKYAPIFinding -Field $SentField -Sent $SentValue -Actual $ActualValue `
                            -Reason $Reason -Kind 'Mismatch'))
                    }
                }
            }
        }
    }

    # Cleared fields: confirm each one actually came back blank.
    foreach ($ClearedField in $ClearedLookup.Keys)
    {
        $ObjectName = $null
        $LeafName = $ClearedField
        if ($ClearedField.Contains('.'))
        {
            $Parts = $ClearedField.Split('.',2)
            $ObjectName = $Parts[0]
            $LeafName = $Parts[1]
        }

        $SpecKey = if ($null -ne $ObjectName) { $ObjectName } else { $LeafName }
        if (-not $FieldSpec.Contains($SpecKey))
        {
            $Findings.Add((New-SKYAPIFinding -Field $ClearedField -Sent '(cleared)' -Actual '' `
                -Reason "'$ClearedField' isn't a known field of this endpoint, so the clear can't be validated" -Kind 'Unverifiable'))
            continue
        }

        $Spec = $FieldSpec[$SpecKey]
        if ($ReadModel -eq 'Basic') { $ReadName = $Spec['BasicRead'] } else { $ReadName = $Spec['Read'] }
        if ([string]::IsNullOrWhiteSpace($ReadName)) { $ReadName = $SpecKey }

        if ($ReadModel -eq 'Basic' -and -not $Spec.Contains('BasicRead'))
        {
            $Findings.Add((New-SKYAPIFinding -Field $ClearedField -Sent '(cleared)' -Actual '' `
                -Reason "'$ClearedField' isn't returned by the basic user read, so the clear can't be validated from it" -Kind 'Unverifiable'))
            continue
        }

        $ActualValue = Get-SKYAPIMemberValue -InputObject $Actual -Name $ReadName
        if ($null -ne $ObjectName)
        {
            $ActualValue = Get-SKYAPIMemberValue -InputObject $ActualValue -Name $LeafName
        }

        # A cleared field reads back blank, absent, or - for the tri-state fields - as the literal 'No answer'.
        if ((Test-SKYAPIValueIsBlank $ActualValue) -or ([string]$ActualValue -eq 'No answer')) { continue }

        $Findings.Add((New-SKYAPIFinding -Field $ClearedField -Sent '(cleared)' -Actual $ActualValue `
            -Reason "asked to clear it but read back '$ActualValue'" -Kind 'Mismatch'))
    }

    return $Findings
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

    # Token creation stamps are recorded in UTC (see Get-SKYAPIAccessToken), so the age is measured in UTC.
    # ToUniversalTime() is a no-op on a value that is already UTC, converts a local one, and treats an
    # unspecified kind as local, which is what a bare local reading parses to.
    if ((([datetime]::UtcNow) - $TokenCreation.ToUniversalTime()) -lt $MaxTokenTimespan)
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
        $AuthTokensFromFile = ((New-Object PSCredential "user",$SecureString).GetNetworkCredential().Password) | ConvertFrom-Json -ErrorAction Stop

        # Token creation stamps are recorded in UTC round-trip format (see Get-SKYAPIAccessToken). Windows
        # PowerShell 5.1 hands them back as strings while PowerShell 7 deserializes them, so normalize both
        # editions to a UTC [datetime]. The trailing conversion matters for a stamp carrying a numeric offset,
        # which RoundtripKind parses to a local value rather than a UTC one.
        foreach ($CreationField in @('refresh_token_creation','access_token_creation'))
        {
            $CreationValue = $AuthTokensFromFile.$CreationField
            if ($null -eq $CreationValue)
            {
                continue
            }

            if ($CreationValue -is [datetime])
            {
                $AuthTokensFromFile.$CreationField = $CreationValue.ToUniversalTime()
            }
            else
            {
                $ParsedCreationValue = [datetime]::Parse(
                    $CreationValue,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::RoundtripKind)

                $AuthTokensFromFile.$CreationField = $ParsedCreationValue.ToUniversalTime()
            }
        }
    }
    catch
    {
        throw "Key JSON tokens file is missing, corrupted or invalid. Please run Connect-SKYAPI with the -ForceReauthentication parameter to recreate it."    
    }
    
    $AuthTokensFromFile
}

# ---------------------------------------------------------------------------------------------------------
# SKY API date/time normalization
#
# See Research_Notes/DateTime-Handling.md for the measurements these rules come from. In short, the API expresses
# the same kind of value differently depending on the endpoint, so the shape of each value has to be examined
# rather than assumed:
#
#   date-only, school time zone   2031-02-23T00:00:00-05:00   (offset is the SCHOOL's, and is DST-aware)
#   date-only, UTC                2005-03-17T00:00:00+00:00   (Get-SchoolUser's dob)
#   date-only, school midnight
#     expressed in UTC            1923-01-25T05:00:00+00:00   (occupations; NOT midnight, still date-only)
#   unset date                    0001-01-01T00:00:00+00:00
#   real timestamp                2026-07-28T16:26:54.233-04:00
#
# The written calendar date is correct in every one of those cases, so date-only values are taken as written
# rather than converted through an instant. That is also why this is offset-sign independent, which matters
# for schools outside the Americas: converting midnight at +10:00 through UTC lands on the previous day.
#
# Reading the written value requires the raw string, because ConvertFrom-Json on PowerShell 7 deserializes to
# a local [datetime] and discards the offset. Windows PowerShell 5.1 leaves these as strings, which is also
# why unrepaired fields currently come back as [String] on 5.1 and [DateTime] on 7. Both editions end up with
# [datetime] here.
# ---------------------------------------------------------------------------------------------------------

# Convert one wire value to a [datetime].
#   -DateOnly forces date-only handling for fields whose time component is not midnight but is still
#    meaningless (the occupations case above), which shape alone cannot detect.
# Values that are not date/time shaped are returned unchanged.
function ConvertTo-SKYAPIDateTimeValue
{
    [OutputType([datetime])]
    param (
        [AllowNull()]
        $Value,

        [switch]$DateOnly,

        # Forces instant handling for a field known always to carry a timestamp. Needed because a timestamp
        # whose milliseconds are exactly zero is serialized without any fractional part, making it identical
        # on the wire to a date-only value; shape cannot tell them apart, so the field name has to.
        [switch]$Timestamp
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }   # already deserialized; nothing recoverable, pass through

    $Text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Value }

    $Match = [regex]::Match($Text, '^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})?$')
    if (-not $Match.Success) { return $Value }     # not a date/time, leave it alone

    $Year  = [int]$Match.Groups[1].Value
    $Month = [int]$Match.Groups[2].Value
    $Day   = [int]$Match.Groups[3].Value
    $Hour  = [int]$Match.Groups[4].Value
    $Min   = [int]$Match.Groups[5].Value
    $Sec   = [int]$Match.Groups[6].Value

    # Unset dates come back as 0001-01-01. Preserve the existing representation for callers that test for it.
    if ($Year -eq 1 -and $Month -eq 1 -and $Day -eq 1) { return [datetime]::MinValue }

    # Classification, in order of how much the evidence is worth:
    #
    #   1. -DateOnly / -Timestamp. The field name, supplied by the caller. This is the only evidence that can
    #      settle the genuinely ambiguous case, so it outranks everything. -DateOnly wins a conflict, since a
    #      field named in both lists is a caller mistake and date-only is the safer reading.
    #   2. A fractional second. Only a time-bearing value carries one; no date-only value on the wire does.
    #      Presence is the test, not a non-zero value: the API strips trailing zeros (hence the two-digit
    #      'created 2026-02-13T16:44:23.38+00:00'), so anything that still emitted '.000' meant a time.
    #   3. The clock reading. Midnight means no time information.
    #
    # Rule 3 alone is not safe, which is why rule 1 exists. Stripping trailing zeros means a timestamp whose
    # milliseconds are exactly zero loses its fraction entirely: 'created 2007-07-30T10:42:37+00:00' was
    # measured on the dev tenant. Such a value landing on midnight is byte-identical to a date-only value, and
    # would be flattened by shape alone. Naming the field is the only defense. See Research_Notes/DateTime-Handling.md.
    $HasFraction = $Match.Groups[7].Success

    if ($DateOnly -or (-not $Timestamp -and $Hour -eq 0 -and $Min -eq 0 -and $Sec -eq 0 -and -not $HasFraction))
    {
        return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [System.DateTimeKind]::Unspecified)
    }

    # A real timestamp: keep the instant, matching what ConvertFrom-Json produces on PowerShell 7.
    $Parsed = [datetime]::MinValue
    $Styles = [System.Globalization.DateTimeStyles]::None
    if ([datetime]::TryParse($Text, [System.Globalization.CultureInfo]::InvariantCulture, $Styles, [ref]$Parsed))
    {
        return $Parsed
    }

    return $Value
}

# Walk a parsed-but-not-date-deserialized response and convert every date/time value it contains.
#   -DateOnlyFields names fields that must be treated as date-only regardless of their time component.
#   -TimestampFields names fields that must keep their instant regardless of their time component.
# Mutates and returns the object.
#
# The -TimestampFields default covers the audit metadata every endpoint attaches. These are always instants,
# and they need naming because a timestamp with exactly zero milliseconds is serialized without a fractional
# part ('created 2007-07-30T10:42:37+00:00', measured), so one landing on midnight would otherwise be read as
# a date. Only midnight values of these fields change behavior - anything with a real time was already handled
# correctly - so the list is safe to apply everywhere.
#
# Deliberately NOT in the list: enroll_date. Research_Notes/DateTime-Handling.md section 3e records it arriving both
# as a date-only value and as a real timestamp within a single Get-SchoolAthleticRoster payload, so its name
# proves nothing and shape has to decide. Only add a field here once it is known to be ALWAYS an instant.
function Repair-SKYAPIResponseDateTime
{
    param (
        [AllowNull()]
        $InputObject,

        [string[]]$DateOnlyFields = @(),

        [string[]]$TimestampFields = @('audit_date','created_date','last_modified_date','modified','created','last_modified','modified_date')
    )

    if ($null -eq $InputObject) { return $InputObject }

    # Collections: recurse per item. Strings are IEnumerable, so exclude them explicitly.
    if ($InputObject -isnot [string] -and $InputObject -is [System.Collections.IEnumerable])
    {
        foreach ($Item in $InputObject)
        {
            $null = Repair-SKYAPIResponseDateTime -InputObject $Item -DateOnlyFields $DateOnlyFields -TimestampFields $TimestampFields
        }
        return $InputObject
    }

    if ($InputObject -isnot [psobject] -or $InputObject -is [ValueType] -or $InputObject -is [string])
    {
        return $InputObject
    }

    foreach ($Property in @($InputObject.PSObject.Properties))
    {
        $Value = $Property.Value
        if ($null -eq $Value) { continue }

        if ($Value -is [string])
        {
            $Converted = ConvertTo-SKYAPIDateTimeValue -Value $Value `
                            -DateOnly:($DateOnlyFields -contains $Property.Name) `
                            -Timestamp:($TimestampFields -contains $Property.Name)
            if ($Converted -is [datetime]) { $Property.Value = $Converted }
        }
        elseif ($Value -isnot [ValueType])
        {
            $null = Repair-SKYAPIResponseDateTime -InputObject $Value -DateOnlyFields $DateOnlyFields -TimestampFields $TimestampFields
        }
    }

    return $InputObject
}

# How far a zone's clock jumps forward on a spring-forward day, which is also the width of the gap of
# readings that never happen. Read from the zone rather than assumed to be an hour, so a 30-minute-delta zone
# such as Lord Howe Island is handled. Always returns a positive TimeSpan.
#
# Callers need this in two places: to move a single invalid reading past the gap, and to move a whole meeting
# when only its start fell in the gap. Keeping it in one place stops those two drifting apart.
function Get-SKYAPIDaylightJump
{
    [OutputType([timespan])]
    param (
        # Any reading on the transition day. Only its date is used.
        [Parameter(Mandatory=$true)]
        [datetime]$OnDate,

        [Parameter(Mandatory=$true)]
        [System.TimeZoneInfo]$TimeZone
    )

    # The offset differs across a transition day, and that difference is exactly how far the clock jumped.
    $Jump = $TimeZone.GetUtcOffset($OnDate.Date.AddDays(1).AddTicks(-1)) - $TimeZone.GetUtcOffset($OnDate.Date)

    # Defensive: a gap always implies a positive jump. If a zone ever reports otherwise, fall back to the
    # near-universal one hour rather than returning something that would not clear the gap.
    if ($Jump -le [timespan]::Zero) { [timespan]::FromHours(1) } else { $Jump }
}

# Convert a School-local wall-clock time to UTC, making a best guess on the two days a year when a wall-clock
# reading is not a single instant, instead of throwing or silently taking whatever .NET defaults to.
#
# [System.TimeZoneInfo]::ConvertTimeToUtc alone is not enough:
#   - Spring forward: the reading never happened (02:30 when 02:00 jumps to 03:00). ConvertTimeToUtc THROWS,
#     which would fail an entire meetings request over one record. Best guess: shift forward by the amount the
#     clock jumped, so the event lands just past the gap, keeping its position relative to the day's schedule.
#   - Fall back: the reading happened twice (01:30 when 02:00 returns to 01:00), so it maps to two real
#     instants and nothing in the response says which. ConvertTimeToUtc silently picks STANDARD time, the
#     later one. Best guess: take the DAYLIGHT occurrence, the first one chronologically. That matches the
#     offset the API itself reports for that day (Research_Notes/DateTime-Handling.md section 3h) and keeps an event
#     from drifting later.
#
# The jump amount is read from the zone rather than assumed to be an hour, so zones with a 30-minute delta
# (e.g. Lord Howe Island) are handled. Everything used here is available on .NET Framework 4.x and .NET Core,
# and was verified to return identical results on Windows PowerShell 5.1 and PowerShell 7.
function ConvertTo-SKYAPIUtcFromSchoolLocal
{
    [OutputType([datetime])]
    param (
        # A wall-clock reading in the school's time zone. Any Kind is accepted; it is treated as school-local.
        [Parameter(Mandatory=$true)]
        [datetime]$SchoolLocalDateTime,

        [Parameter(Mandatory=$true)]
        [System.TimeZoneInfo]$SchoolTimeZone
    )

    # ConvertTimeToUtc rejects a Local- or Utc-kind value against an arbitrary source zone, so state plainly
    # that this reading is not yet anchored to any zone.
    $Local = [datetime]::new($SchoolLocalDateTime.Ticks, [System.DateTimeKind]::Unspecified)

    if ($SchoolTimeZone.IsInvalidTime($Local))
    {
        $Local = $Local.Add((Get-SKYAPIDaylightJump -OnDate $Local -TimeZone $SchoolTimeZone))
    }
    elseif ($SchoolTimeZone.IsAmbiguousTime($Local))
    {
        # Both candidate offsets for this reading. Daylight is standard plus a positive delta, so the larger
        # offset is the daylight one, which is also the earlier instant.
        $DaylightOffset = ($SchoolTimeZone.GetAmbiguousTimeOffsets($Local) | Sort-Object -Descending)[0]
        return ([System.DateTimeOffset]::new($Local, $DaylightOffset)).UtcDateTime
    }

    [System.TimeZoneInfo]::ConvertTimeToUtc($Local, $SchoolTimeZone)
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
# Dates must be in the roundtrip format and specify the offset or a 'Z' (DateTimeKind.Local or DateTimeKind.Utc).
# Examples:
#  - 2009-06-15T13:45:30.0000000Z
#  - 2009-06-15T13:45:30.0000000-07:00
#  - 2009-06-15T13:45:00-07:00
# More Information: Since PowerShell v6, ConvertFrom-Json automatically deserializes strings that contain
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

    # PowerShell 7.3+ can natively keep date/time values as strings, which is exactly what this function
    # needs - no regex or object walking required. It also covers 'Z'/UTC and offset-less date/times that
    # the fallback regex below does not. Prefer it whenever the -DateKind parameter is available.
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind'))
    {
        return ($InputObject | ConvertFrom-Json -DateKind String)
    }

    # Windows PowerShell 5.1 already leaves date/time values as strings, so the regex pass below is not just
    # unnecessary there, it is a large cost on big payloads (it rewrites the whole document and then walks
    # every property). Verified on 5.1: an unrepaired field such as passport.expire_date comes back as the
    # raw string '2031-02-23T00:00:00-05:00'.
    if ($PSVersionTable.PSEdition -eq 'Desktop')
    {
        return ($InputObject | ConvertFrom-Json)
    }

    # Fallback for PowerShell Core only:
    # hide round-trip date/time strings behind a '#' so ConvertFrom-Json won't deserialize them, then
    # strip the '#' back off afterward. The offset group also matches a trailing 'Z' (UTC) so those
    # values are kept as strings too.
    $DateTimeRegex = '"(\d+-\d+.\d+T\d+:\d+:\d+\.?\d+((\+|\-)\d+:\d+|Z))"'
    $DateTimeRegexWithHash = '(#)(\d+-\d+.\d+T\d+:\d+:\d+\.?\d+((\+|\-)\d+:\d+|Z))'

    # Prepend the hash sign to round-trip date/time pattern strings.
    [string]$JsonWithPrefix = $InputObject -replace $DateTimeRegex, '"#$1"'

    # Convert to a PSCustomObject object.
    [pscustomobject]$PSObjectWithPrefix = $JsonWithPrefix | ConvertFrom-Json

    # Remove the added hash signs and return the cleaned object.
    return (Set-PSObjectText -InputObject $PSObjectWithPrefix -OldValue $DateTimeRegexWithHash -NewValue '$2')
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
