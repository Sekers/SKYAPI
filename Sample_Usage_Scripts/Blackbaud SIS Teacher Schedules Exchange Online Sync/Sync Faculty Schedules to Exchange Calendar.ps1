############
# OVERVIEW #
############

# Creates Exchange Online events for users (faculty, students, etc.) from the Blackbaud School Environment.

##############
# TODO ITEMS #
##############

# TODO: Since the Graph SDK doesn't support batching the regular cmdlets, look into using Invoke-MgGraphRequest to batch items.
# https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/invoke-mggraphrequest
# https://nonodename.com/post/graphapibatchcalls/
# https://manima.de/2023/09/microsoft-graph-json-batching-using-powershell/
# https://learn.microsoft.com/en-us/graph/sdks/batch-requests
# https://learn.microsoft.com/en-us/graph/json-batching

# TODO: Disconnect MG When Done Option > MgDisconnectWhenDone

# TODO: Add support for multiple terms lengths by level_id. Right now, even if term is selected the entire year is synced due to one term being that length of 1 instead of 2 semesters.

# TODO: Add support for non-teachers (students, etc.).

#################
# PREREQUISITES #
#################

# SKYAPI PowerShell Module (for connecting to the SIS - https://github.com/Sekers/SKYAPI)
# Microsoft Graph PowerShell SDK (for connecting to Microsoft Graph - https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)

#############
# FUNCTIONS #
#############
function ConvertTo-GraphDateTimeTimeZone
{
    <#
        .SYNOPSIS
        Converts a DateTime object along with time zone to dateTimeTimeZone resource type array.
        https://learn.microsoft.com/en-us/graph/api/resources/datetimetimezone
    #>

    param (
        [dateTime]$DateTime,
        [TimeZoneInfo]$TimeZone
    )
    
    @{
        dateTime = $DateTime.ToString('yyyy-MM-ddTHH:mm:ss')
        timeZone = $TimeZone.Id
    }
}

function Test-Write
{
    <#
        .SYNOPSIS
        Verifies that a file path is writable.
    #>

    [CmdletBinding()]
    param (
        [parameter()] [ValidateScript({[IO.Directory]::Exists($_.FullName)})]
        [IO.DirectoryInfo] $Path
    )
    try {
        $testPath = Join-Path $Path ([IO.Path]::GetRandomFileName())
        [IO.File]::Create($testPath, 1, 'DeleteOnClose') > $null
        # Or...
        <# New-Item -Path $testPath -ItemType File -ErrorAction Stop > $null #>
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item $testPath -ErrorAction SilentlyContinue
    }
}

function Get-NextOutlookCategoryColor
{
    <#
        .SYNOPSIS
        Finds the next least-used color for a specified user's Outlook categories.
        Useful for creating a new Outlook category and not over using certain colors.
    #>

    param (
        [string]$UserId
    )
    
    # Set Preset Outlook Category Colors
    # See: https://learn.microsoft.com/en-us/graph/api/resources/outlookcategory#properties
    [array]$OutlookCategoryColors = @(
        [PSCustomObject] @{
            "Index"       = 0
            "Color"       = "Preset0"
            "DisplayName" = "Red"
        },
        [PSCustomObject] @{
            "Index"       = 1
            "Color"       = "Preset1"
            "DisplayName" = "Orange"
        },
        [PSCustomObject] @{
            "Index"       = 2
            "Color"       = "Preset2"
            "DisplayName" = "Brown"
        },
        [PSCustomObject] @{
            "Index"       = 3
            "Color"       = "Preset3"
            "DisplayName" = "Yellow"
        },
        [PSCustomObject] @{
            "Index"       = 4
            "Color"       = "Preset4"
            "DisplayName" = "Green"
        },
        [PSCustomObject] @{
            "Index"       = 5
            "Color"       = "Preset5"
            "DisplayName" = "Teal"
        },
        [PSCustomObject] @{
            "Index"       = 6
            "Color"       = "Preset6"
            "DisplayName" = "Olive"
        },
        [PSCustomObject] @{
            "Index"       = 7
            "Color"       = "Preset7"
            "DisplayName" = "Blue"
        },
        [PSCustomObject] @{
            "Index"       = 8
            "Color"       = "Preset8"
            "DisplayName" = "Purple"
        },
        [PSCustomObject] @{
            "Index"       = 9
            "Color"       = "Preset9"
            "DisplayName" = "Cranberry"
        },
        [PSCustomObject] @{
            "Index"       = 10
            "Color"       = "Preset10"
            "DisplayName" = "Steel"
        },
        [PSCustomObject] @{
            "Index"       = 11
            "Color"       = "Preset11"
            "DisplayName" = "DarkSteel"
        },
        [PSCustomObject] @{
            "Index"       = 12
            "Color"       = "Preset12"
            "DisplayName" = "Gray"
        },
        [PSCustomObject] @{
            "Index"       = 13
            "Color"       = "Preset13"
            "DisplayName" = "DarkGray"
        },
        [PSCustomObject] @{
            "Index"       = 14
            "Color"       = "Preset14"
            "DisplayName" = "Black"
        },
        [PSCustomObject] @{
            "Index"       = 15
            "Color"       = "Preset15"
            "DisplayName" = "DarkRed"
        },
        [PSCustomObject] @{
            "Index"       = 16
            "Color"       = "Preset16"
            "DisplayName" = "DarkOrange"
        },
        [PSCustomObject] @{
            "Index"       = 17
            "Color"       = "Preset17"
            "DisplayName" = "DarkBrown"
        },
        [PSCustomObject] @{
            "Index"       = 18
            "Color"       = "Preset18"
            "DisplayName" = "DarkYellow"
        },
        [PSCustomObject] @{
            "Index"       = 19
            "Color"       = "Preset19"
            "DisplayName" = "DarkGreen"
        },
        [PSCustomObject] @{
            "Index"       = 20
            "Color"       = "Preset20"
            "DisplayName" = "DarkTeal"
        },
        [PSCustomObject] @{
            "Index"       = 21
            "Color"       = "Preset21"
            "DisplayName" = "DarkOlive"
        },
        [PSCustomObject] @{
            "Index"       = 22
            "Color"       = "Preset22"
            "DisplayName" = "DarkBlue"
        },
        [PSCustomObject] @{
            "Index"       = 23
            "Color"       = "Preset23"
            "DisplayName" = "DarkPurple"
        },
        [PSCustomObject] @{
            "Index"       = 24
            "Color"       = "Preset24"
            "DisplayName" = "DarkCranberry"
        }
    )

    $ExistingTeacherCategories = Get-MgUserOutlookMasterCategory -UserId $UserId

    [array]$ExistingTeacherCategoriesColorCount = foreach ($outlookCategoryColor in $OutlookCategoryColors)
    {
        $CategoryColor = [PSCustomObject]@{
            Index = $($outlookCategoryColor.Index)
            Color = $($outlookCategoryColor.Color)
            DisplayName   = $($outlookCategoryColor.DisplayName)
            Count   = ($ExistingTeacherCategories | Where-Object -Property Color -EQ $outlookCategoryColor.Color).Count
        }
        $CategoryColor
    }
    $NextTeacherCategoryColor = ($ExistingTeacherCategoriesColorCount | Sort-Object -Property Count, Index)[0]

    return $NextTeacherCategoryColor
}

#################
# SET VARIABLES #
#################

# Stop on Errors
$ErrorActionPreference = "Stop"

# Set Encoding (PowerShell 5.1 doesn't default to UTF-8 while PowerShell Core does)
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Import General Configuration Settings
$Config = Get-Content -Path "$PSScriptRoot\Config\config_general.json" | ConvertFrom-Json

# Set General Properties and Verify Type
[bool]$EmailonError = $Config.General.EmailonError
[bool]$EmailonWarning = $Config.General.EmailonWarning
[int32[]]$TeacherRoleIDs = $Config.General.TeacherRoleIDs
[string]$Meetings_DateSelection = $Config.General.Meetings_DateSelection # 'Year' or 'Term' or 'Range'
[int32]$Meetings_DaysToAppearBefore = $Config.General.Meetings_DaysToAppearBefore
[Nullable[int32]]$Meetings_MaxPastDaysToSync = $Config.General.Meetings_MaxPastDaysToSync # Needs to be nullable in case we don't want a limit
[string]$Meetings_StartDate = $Config.General.Meetings_StartDate
[string]$Meetings_EndDate = $Config.General.Meetings_EndDate
[array]$Meetings_OfferingTypes = $Config.General.Meetings_OfferingTypes
[string]$DefaultShowAs = $Config.General.DefaultShowAs
[bool]$DefaultIsReminderOn = $Config.General.DefaultIsReminderOn
[int32]$DefaultReminderMinutesBeforeStart = $Config.General.DefaultReminderMinutesBeforeStart
[string]$EventsAppIdentifier_GUID = $Config.General.EventsAppIdentifier_GUID
[string]$EventsAppIdentifier_Name = $Config.General.EventsAppIdentifier_Name
[string]$EventsAppIdentifier_Value = $Config.General.EventsAppIdentifier_Value
[string]$MySchoolAppDomain = $Config.General.MySchoolAppDomain
[string]$SaveTeachersSyncHistoryPath = $ExecutionContext.InvokeCommand.ExpandString($Config.General.SaveTeachersSyncHistoryPath) -replace '%date%', $(Get-Date -Format 'yyyy-MM-dd')  # Optional. The location where you want a teacher sync history saved. Can accept PowerShell variables.
[string]$TeachersSyncHistoryRotateFilter = $ExecutionContext.InvokeCommand.ExpandString($Config.General.TeachersSyncHistoryRotateFilter)
[int32]$TeachersSyncHistoryRetentionTimeInDays = $Config.General.TeachersSyncHistoryRetentionTimeInDays

# Configure SKYAPI and Verify Type
[string]$SKYAPIConfigFilePath = $ExecutionContext.InvokeCommand.ExpandString($Config.SKYAPI.ConfigFilePath) # The location where you placed your Blackbaud SKY API configuration file. Can accept PowerShell variables.
[string]$SKYAPITokensFilePath = $ExecutionContext.InvokeCommand.ExpandString($Config.SKYAPI.TokensFilePath) # The location where you want the access and refresh tokens to be stored. Can accept PowerShell variables.

# Configure Microsoft Graph and Verify Type
[string]$MgPermissionType = $Config.MSGraph.MgPermissionType # Delegated or Application. See: https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent#permission-types and https://docs.microsoft.com/en-us/graph/auth/auth-concepts#delegated-and-application-permissions.
[bool]$MgDisconnectWhenDone = $Config.MSGraph.MgDisconnectWhenDone # Recommended when using the Application permission type.
[string]$MgClientID = $Config.MSGraph.MgClientID
[string]$MgTenantID = $Config.MSGraph.MgTenantID
[string]$MgApp_AuthenticationType = $Config.MSGraph.MgApp_AuthenticationType
[string]$MgApp_CertificatePath = $ExecutionContext.InvokeCommand.ExpandString($Config.General.MgApp_CertificatePath)
[string]$MgApp_CertificateName = $Config.MSGraph.MgApp_CertificateName
[string]$MgApp_CertificateThumbprint = $Config.MSGraph.MgApp_CertificateThumbprint
[string]$MgApp_EncryptedCertificatePassword = $Config.MSGraph.MgApp_EncryptedCertificatePassword
[string]$MgApp_EncryptedSecret = $Config.MSGraph.MgApp_EncryptedSecret

# Configure Logging (See https://psframework.org/documentation/documents/psframework/logging/loggingto/logfile.html)
$paramSetPSFLoggingProvider = @{
    Name             = $Config.Logging.Name
    InstanceName     = $Config.Logging.InstanceName
    FilePath         = $ExecutionContext.InvokeCommand.ExpandString($Config.Logging.FilePath)
    FileType         = $Config.Logging.FileType
    LogRotatePath    = $ExecutionContext.InvokeCommand.ExpandString($Config.Logging.LogRotatePath)
    LogRetentionTime = $Config.Logging.LogRetentionTime
    Wait             = $Config.Logging.Wait
    Enabled          = $Config.Logging.Enabled
}

# Configure Email Alerts and Verify Type
if ($EmailonError -or $EmailonWarning)
{
    # Set Messaging Properties and Verify Type
    $ScriptMessageConfigFilePath = [string]($ExecutionContext.InvokeCommand.ExpandString($Config.Messaging.ConfigFilePath)) # The location where you placed your ScriptMessage configuration file. Can accept PowerShell variables.
    $MessageArguments = [ordered]@{
        ServiceType     = @($Config.Messaging.ServiceType)
        From            = @($Config.Messaging.From)
        ReplyTo         = @($Config.Messaging.ReplyTo)
        To              = @($Config.Messaging.To)
        SaveToSentItems = [bool]$Config.Messaging.SaveToSentItems
        Sender          = [string]$Config.Messaging.SenderId
        Subject         = $null
        Body            = $null
        Attachment      = $null
    }
}

# 'Import Meetings To Ignore' & 'Teacher Preferences' Settings
$MeetingsToIgnore = Get-Content -Path "$PSScriptRoot\Config\config_meetings_to_ignore.json" | ConvertFrom-Json
$TeacherPreferences = Get-Content -Path "$PSScriptRoot\Config\config_teacher_preferences.json" | ConvertFrom-Json

# Create List of Custom Preferences to Compare
$TeacherPreferencesToVerify = @('ShowAs','isReminderOn','ReminderMinutesBeforeStart')

# Set Fields To Match Between APIs to Compare Existence
[array]$FieldsToMatch = @(
    [PSCustomObject] @{
        "SKYAPI" = "group_name"
        "Graph"  = "Subject"
    },
    [PSCustomObject] @{
        "SKYAPI" = "start_time"
        "Graph"  = "Start"
    },
    [PSCustomObject] @{
        "SKYAPI" = "end_time"
        "Graph"  = "End"
    }
)

#############
# DEBUGGING #
#############

[string]$VerbosePreference = $Config.Debugging.VerbosePreference # Use 'Continue' to Enable Verbose Messages and Use 'SilentlyContinue' to reset back to default.
[bool]$LogDebugInfo = $Config.Debugging.LogDebugInfo # Writes Extra Information to the log if $true.

##################
# Import Modules #
##################

# Check For Blackbaud SKY API Module
Import-Module SKYAPI -ErrorAction SilentlyContinue
if (!(Get-Module -Name "SKYAPI"))
{
   # Module is not loaded
   Write-Error "Please First Install the Blackbaud SKY API Module from https://github.com/Sekers/SKYAPI."
   Return
}

# Check For Microsoft.Graph Module.
# Don't import the entire 'Microsoft.Graph' module because of some issues with doing it that way. Only import the needed modules.
Import-Module 'Microsoft.Graph.Authentication' -ErrorAction SilentlyContinue
Import-Module 'Microsoft.Graph.Calendar' -ErrorAction SilentlyContinue
if (!(Get-Module -Name "Microsoft.Graph.Calendar"))
{
    # Module is not available.
    Write-Error "Please First Install the Microsoft.Graph Module (or just the 'Microsoft.Graph.Calendar' submodule) from https://www.powershellgallery.com/packages/Microsoft.Graph/ "
    Return
}

# Check For PowerShell Framework Module
Import-Module PSFramework -ErrorAction SilentlyContinue
if (!(Get-Module -Name "PSFramework"))
{
   # Module is not loaded
   Write-Error "Please First Install the PowerShell Framework Module from https://psframework.org."
   Return
}

# Check For ScriptMessage PowerShell Module
Import-Module ScriptMessage -ErrorAction SilentlyContinue
if (!(Get-Module -Name "ScriptMessage"))
{
   # Module is not loaded
   Write-Error "Please First Install the ScriptMessage Module from https://github.com/Sekers/ScriptMessage."
   Return
}

################
# PERFORM WORK #
################

# Set Logging Data & Log PowerShell & Module Version Information.
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
Write-PSFMessage -Level Important -Message "---SCRIPT BEGIN---"
Write-PSFMessage -Level Verbose -Message "PowerShell Version: $($PSVersionTable.PSVersion.ToString()), $($PSVersionTable.PSEdition.ToString())$(if([Environment]::Is64BitProcess){$(", 64Bit")}else{$(", 32Bit")})"
foreach ($moduleInfo in Get-Module)
{
    Write-PSFMessage -Level Verbose -Message "$($moduleInfo.Name) Module Version: $($moduleInfo.Version)"
}

# Begin Program Work (Try/Catch for Error/Warning Processing & Notification)
try
{
    # If set, test path to writable list of teacher calendar synchronizations and create file if necessary.
    if (-not [string]::IsNullOrEmpty($SaveTeachersSyncHistoryPath))
    {
        # Get parent folder path
        $SaveTeachersSyncHistoryParentDirectory = ([System.IO.Path]::GetDirectoryName($SaveTeachersSyncHistoryPath))

        # Cleanup old teacher history files, if necessary.
        $TeacherSyncHistoryFiles = Get-ChildItem -Path $SaveTeachersSyncHistoryParentDirectory -Filter $TeachersSyncHistoryRotateFilter
        $TeacherSyncHistoryFiles | Where-Object -Property LastWriteTime -gt (Get-Date).AddDays($TeachersSyncHistoryRetentionTimeInDays) | Remove-Item -Force

        # Create Destination Folder (In Case It Doesn't Already Exist)
        $null = New-Item -ItemType Directory -Path $SaveTeachersSyncHistoryParentDirectory -Force
        # Verify Write Access to Destination Folder
        if (!(Test-Write -Path $SaveTeachersSyncHistoryParentDirectory))
        {
            Write-Error "You do not have create & write access to the the teachers synchronization history parent folder: $($SaveTeachersSyncHistoryParentDirectory)" -ErrorAction Stop
        }

        # Create CSV File With Headers, If Necessary
        if (-not (Test-Path $SaveTeachersSyncHistoryPath))
        {
            $TeacherSyncHistoryHeader = '"Timestamp","ID","Name","Email","MeetingsCount"'
            if ($PSVersionTable.PSEdition.ToString() -eq 'Desktop') # Hack because Windows PowerShell 5.1 adds the Byte order mark (BOM) to the beginning of the export (which we don't want). In Windows PowerShell, any Unicode encoding, except UTF7, always creates a BOM. PowerShell (v6 and higher) defaults to utf8NoBOM for all text output.
            {
                $TeacherSyncHistoryHeader | Out-String | ForEach-Object {[Text.Encoding]::UTF8.GetBytes($_)} | Set-Content -Encoding Byte -Path $SaveTeachersSyncHistoryPath -NoNewline
            }
            else # PowerShell Core Exports without the BOM
            {
                $TeacherSyncHistoryHeader | Out-String | Set-Content -Encoding UTF8 -Path $SaveTeachersSyncHistoryPath -NoNewline
            }
        }
    }

    # Set SKYAPI Paths
    Set-SKYAPIConfigFilePath -Path $SKYAPIConfigFilePath
    Set-SKYAPITokensFilePath -Path $SKYAPITokensFilePath

    # Connect to Blackbaud SKY API
    Write-PSFMessage -Level Important -Message "Connecting to the Blackbaud SKY API"
    Connect-SKYAPI

    # Connect to the Microsoft Graph API.
    # E.g. Connect-MgGraph -Scopes "User.Read.All","Group.ReadWrite.All"
    # You can add additional permissions by repeating the Connect-MgGraph command with the new permission scopes.
    # View the current scopes under which the PowerShell SDK is (trying to) execute cmdlets: Get-MgContext | select -ExpandProperty Scopes
    # List all the scopes granted on the service principal object (you cn also do it via the Azure AD UI): Get-MgServicePrincipal -Filter "appId eq '14d82eec-204b-4c2f-b7e8-296a70dab67e'" | % { Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $_.Id } | fl
    # Find Graph permission needed. More info on permissions: https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent)
    #    E.g., Find-MgGraphPermission -SearchString "Teams" -PermissionType Delegated
    #    E.g., Find-MgGraphPermission -SearchString "Teams" -PermissionType Application
    $MicrosoftGraphScopes = @(
        'Calendars.ReadWrite'
    )
    Write-PSFMessage -Level Important -Message "Connecting to Microsoft Graph With Permission Type: $MgPermissionType"
    switch ($MgPermissionType)
    {
        Delegated {
            $null = Connect-MgGraph -Scopes $MicrosoftGraphScopes -TenantId $MgTenantID -ClientId $MgClientID
        }
        Application {
            Write-PSFMessage -Level Important -Message "Microsoft Graph App Authentication Type: $MgApp_AuthenticationType"

            switch ($MgApp_AuthenticationType)
            {
                CertificateFile {
                    # This is only supported using PowerShell 7.4 and later because 5.1 is missing the necessary parameters when using 'Get-PfxCertificate'.
                    if ($PSVersionTable.PSVersion -lt [Version]'7.4')
                    {
                        $NewMessage = "Connecting to Microsoft Graph using a certificate file is only supported with PowerShell version 7.4 and later."
                        Write-PSFMessage -Level Error $NewMessage
                        throw $NewMessage
                    }

                    # Try accessing private key certificate without password using current process credentials.
                    [X509Certificate]$MgApp_Certificate = $null
                    try
                    {
                        [X509Certificate]$MgApp_Certificate = Get-PfxCertificate -FilePath $MgApp_CertificatePath -NoPromptForPassword
                    }
                    catch # If that doesn't work try the included credentials.
                    {
                        if ([string]::IsNullOrEmpty($MgApp_EncryptedCertificatePassword))
                        {
                            $NewMessage = "Cannot access Microsoft Graph .pfx private key certificate file and no password has been provided."
                            Write-PSFMessage -Level Error $NewMessage
                            throw $NewMessage
                        }
                        else
                        {
                            [SecureString]$MgApp_EncryptedCertificateSecureString = $MgApp_EncryptedCertificatePassword | ConvertTo-SecureString # Can only be decrypted by the same AD account on the same computer.
                            [X509Certificate]$MgApp_Certificate = Get-PfxCertificate -FilePath $MgApp_CertificatePath -NoPromptForPassword -Password $MgApp_EncryptedCertificateSecureString
                        }
                    }

                    $null = Connect-MgGraph -TenantId $MgTenantID -ClientId $MgClientID -Certificate $MgApp_Certificate
                }
                CertificateName {
                    $null = Connect-MgGraph -TenantId $MgTenantID -ClientId $MgClientID -CertificateName $MgApp_CertificateName
                }
                CertificateThumbprint {
                    $null = Connect-MgGraph -TenantId $MgTenantID -ClientId $MgClientID -CertificateThumbprint $MgApp_CertificateThumbprint
                }
                ClientSecret {
                    $MgApp_Secret = [System.Net.NetworkCredential]::new("", $($MgApp_EncryptedSecret | ConvertTo-SecureString)).Password # Can only be decrypted by the same AD account on the same computer.
                    $Body =  @{
                        Grant_Type    = "client_credentials"
                        Scope         = "https://graph.microsoft.com/.default"
                        Client_Id     = $MgClientID
                        Client_Secret = $MgApp_Secret
                    }
                    $Connection = Invoke-RestMethod `
                        -Uri https://login.microsoftonline.com/$MgTenantID/oauth2/v2.0/token `
                        -Method POST `
                        -Body $Body
                    $AccessToken = $Connection.access_token
                    $null = Connect-MgGraph -AccessToken $AccessToken
                }
                Default {throw "Invalid `'MgApp_AuthenticationType`' value in the configuration file."}
            }
        }
        Default {throw "Invalid `'MgPermissionType`' value in the configuration file."}
    }

    # Convert SchoolTimeZone to TimeZoneInfo object. Check match for ID, then StandardName, then DaylightName.
    $SchoolTimeZoneId = ((Get-SchoolTimeZone).timezone_name)
    $SystemTimeZones = Get-TimeZone -ListAvailable
    $SchoolTimeZone = $SystemTimeZones | Where-Object -Property Id -EQ $SchoolTimeZoneId
    if ([string]::IsNullOrEmpty($SchoolTimeZone))
    {
        $SchoolTimeZone = $SystemTimeZones | Where-Object -Property StandardName -EQ $SchoolTimeZoneId
    }
    if ([string]::IsNullOrEmpty($SchoolTimeZone))
    {
        $SchoolTimeZone = $SystemTimeZones | Where-Object -Property DaylightName -EQ $SchoolTimeZoneId
    }

    # Get Offering School Types
    Write-PSFMessage -Level Important -Message "Beginning SIS School Offering Types Collection"
    $SchoolOfferingTypes = Get-SchoolOfferingType
    $OfferingTypes = foreach ($meetings_OfferingType in $Meetings_OfferingTypes) {$SchoolOfferingTypes | Where-Object {$_.description -eq ($meetings_OfferingType)}}

    # Get Meetings
    Write-PSFMessage -Level Important -Message "Beginning SIS Meetings Collection"

    # Get the date range to sync meetings.
    switch ($Meetings_DateSelection)
    {
        Year {       
            # Get Current Year Lists
            $CurrentSchoolYear = Get-SchoolYear | Where-Object current_year -EQ $true

            # Set Date Range Variables
            $Meetings_StartDate = ([datetime]$CurrentSchoolYear.begin_date).ToString('yyyy-MM-dd')
            $Meetings_EndDate = ([datetime]$CurrentSchoolYear.end_date).ToString('yyyy-MM-dd')

            # May need events from the next school year.
            if ($Meetings_DaysToAppearBefore -gt 0)
            {
                $NextSchoolYear = (Get-SchoolYear | Where-Object {(([datetime]$_.begin_date) -le (Get-Date).AddYears(1)) -and (([datetime]$_.end_date) -ge (Get-Date).AddYears(1))})
                if (([datetime]$NextSchoolYear.begin_date) -le (Get-Date).AddDays($Meetings_DaysToAppearBefore))
                {
                    $Meetings_EndDate = ([datetime]$NextSchoolYear.end_date).ToString('yyyy-MM-dd')
                }
            }
        }
        Term {
            # Get Term Lists (This Year & Next Year)
            $SchoolTermList = Get-SchoolTerm | Where-Object -Property offering_type -in $OfferingTypes.id | Sort-Object -Property begin_date

            # May need events from the next school year.
            if ($Meetings_DaysToAppearBefore -gt 0)
            {
                $NextSchoolYear = (Get-SchoolYear | Where-Object {(([datetime]$_.begin_date) -le (Get-Date).AddYears(1)) -and (([datetime]$_.end_date) -ge (Get-Date).AddYears(1))})
                $SchoolTermList += Get-SchoolTerm -school_year $NextSchoolYear.school_year_label | Where-Object -Property offering_type -in $OfferingTypes.id 
                $SchoolTermList = $SchoolTermList | Sort-Object -Property begin_date
            }
            
            # Filter out terms that are not within the date range.
            $SchoolTermList = $SchoolTermList | Where-Object {([datetime]$_.begin_date) -le (Get-Date).AddDays(($Meetings_DaysToAppearBefore))}
            $SchoolTermList = $SchoolTermList | Where-Object {([datetime]$_.end_date) -ge (Get-Date)}

            # If no terms within the date range are found, stop script (this is common during the summer months).
            if ($SchoolTermList.Count -eq 0)
            {
                Write-PSFMessage -Level Important -Message "No school terms found within the date range (this is common during the summer months). Stopping Script."

                # End Logging Message
                Write-PSFMessage -Level Important -Message "---SCRIPT END---"
                Wait-PSFMessage # Make Sure Logging Is Flushed Before Terminating

                # Stop the script.
                exit
            }
            
            # Set Date Range Variables
            [array]$TermBeginDates = foreach ($termBeginDate in $SchoolTermList.begin_date)
            {
                [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(([datetime]$termBeginDate), $SchoolTimeZone.Id)
            }
            [array]$TermEndDates = foreach ($termEndDate in $SchoolTermList.end_date)
            {
                [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(([datetime]$termEndDate), $SchoolTimeZone.Id)
            }
            $Meetings_StartDate = (($TermBeginDates | Sort-Object )[0]).ToString('yyyy-MM-dd')
            $Meetings_EndDate = (($TermEndDates | Sort-Object -Descending)[0]).ToString('yyyy-MM-dd')
        }
        Range{
            # Nothing to do here; the start and end dates are already set.
        }
        Default {}
    }

    # Only synchronize past meetings if the number of days is less than the maximum allowed.
    if ($null -ne $Meetings_MaxPastDaysToSync)
    {
        $Meetings_StartDate_OldestAllowed = ((Get-Date).AddDays(-$Meetings_MaxPastDaysToSync)).ToString('yyyy-MM-dd')
        $Meetings_StartDate = (@([datetime]$Meetings_StartDate, [datetime]$Meetings_StartDate_OldestAllowed) | Sort-Object | Select-Object -Last 1).ToString('yyyy-MM-dd')
    }

    Write-PSFMessage -Level Significant -Message "Date Selection [Type: $Meetings_DateSelection]: $Meetings_StartDate to $Meetings_EndDate"

    # Set Meetings Parameters & Properties
    $HashArguments = [ordered]@{
        start_date = $Meetings_StartDate
        end_date = $Meetings_EndDate
        offering_types = $OfferingTypes.id -join ','
    }
    $SISMeetingProperties = @(
        'course_title',
        'end_time',
        'faculty_name',
        'faculty_user_id',
        'group_name',
        'offering_type',
        'room_name',
        'section_id',
        'start_time',
        'teachers'
    )
    $MeetingsFromSIS = Get-SchoolScheduleMeeting @HashArguments | Select-Object -Property $SISMeetingProperties

    # Remove Meetings That Should Be Ignored
    [array]$MeetingsFilterProperties = ($MeetingsToIgnore | Get-Member -MemberType NoteProperty).Name
    foreach ($meetingsFilterProperty in $MeetingsFilterProperties)
    {
        $MeetingsFilterPropertyValues = $MeetingsToIgnore.($meetingsFilterProperty)
        foreach ($meetingsFilterPropertyValue in $MeetingsFilterPropertyValues)
        {
            $MeetingsFromSIS = $MeetingsFromSIS | Where-Object -Property $($meetingsFilterProperty) -NotMatch $meetingsFilterPropertyValue
        }
    }

    # Massage SIS DateTime Events in Meetings (Convert to Round-Trip 'o' Format)
    $Meetings = [System.Collections.Generic.List[Object]]::new()
    foreach ($meetingFromSIS in $MeetingsFromSIS)
    {
        $TeacherMeetingObject = [PSCustomObject]@{}
        foreach ($sISMeetingProperty in $SISMeetingProperties)
        {
            switch ($sISMeetingProperty)
            {
                {$_ -eq 'start_time' -or $_ -eq 'end_time'}
                {
                    # Convert to UTC DateTime string
                    $SKYAPIValue = Get-Date -Date ($meetingFromSIS.($sISMeetingProperty)) -Format 'o'
                    # $OriginalValueName = $sISMeetingProperty + '_original'
                    # $NewPSObjectProperty = [PSNoteProperty]::new($OriginalValueName, ($meetingFromSIS.($sISMeetingProperty)))
                    # $TeacherMeetingObject.psobject.Properties.Add($NewPSObjectProperty)
                }
                Default
                {
                    $SKYAPIValue = $meetingFromSIS.($sISMeetingProperty)
                }
            }
            $NewPSObjectProperty = [PSNoteProperty]::new($sISMeetingProperty, $SKYAPIValue)
            $TeacherMeetingObject.psobject.Properties.Add($NewPSObjectProperty)
        }
        $Meetings.Add($TeacherMeetingObject)
    }

    # Get All Teachers
    [array]$SchoolRoles = Get-SchoolRole
    [array]$TeacherRoles = foreach ($teacherRoleID in $TeacherRoleIDs)
    {
        $SchoolRoles | Where-Object -Property id -EQ $teacherRoleID
    }
    [array]$Teachers = foreach ($teacherRole in $TeacherRoles)
    {
        Get-SchoolUserByRole -roles $teacherRole.id
    }
    $Teachers = $Teachers | Sort-Object -Property display -Unique
    $TeachersCount = $Teachers.Count

    # Set Start\End Times as UTC for Graph Queries
    # https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings#Roundtrip
    $Meetings_StartDateTime_UTC_ISO8601 = Get-Date ([System.TimeZoneInfo]::ConvertTimeToUtc($Meetings_StartDate, $SchoolTimeZone)) -Format 'o'
    $Meetings_EndDateTime_UTC_ISO8601 = Get-Date (([System.TimeZoneInfo]::ConvertTimeToUtc($Meetings_EndDate, $SchoolTimeZone)).AddDays(1)) -Format 'o'

    # Create Needed Events & Remove Extra Events
    Write-PSFMessage -Level Important -Message "Beginning Processing Meetings & Existing Calendar Events For Each Teacher"
    $TeacherIndex = 0
    foreach ($teacher in $Teachers)
    {
        $TeacherIndex++
        Write-PSFMessage -Level Significant -Message "Working On Teacher $TeacherIndex of $($TeachersCount): $($teacher.display) [$($teacher.id)] [$($teacher.email)]"

        # Gather Meetings for Teacher
        $TeacherMeetings = $Meetings | Where-Object {$_.teachers.id -match "(^)$($teacher.id)($)"} | Sort-Object -Property start_time, group_name
        $TeacherMeetingsCount = $TeacherMeetings.Count

        # If set, begin to create a writable list of teacher calendar synchronizations.
        if (-not [string]::IsNullOrEmpty($SaveTeachersSyncHistoryPath))
        {
            $TeacherSyncHistoryLine = [PSCustomObject]@{
                Timestamp     = $([DateTime]::UtcNow.ToString('u'))
                ID            = $($teacher.id)
                Name          = $($teacher.display)
                Email         = $($teacher.email)
                MeetingsCount = $TeacherMeetingsCount
            }

            if ($PSVersionTable.PSEdition.ToString() -eq 'Desktop') # Hack because Windows PowerShell 5.1 adds the Byte order mark (BOM) to the beginning of the export (which we don't want). In Windows PowerShell, any Unicode encoding, except UTF7, always creates a BOM. PowerShell (v6 and higher) defaults to utf8NoBOM for all text output.
            {
                $TeacherSyncHistoryLine | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-String | ForEach-Object {[Text.Encoding]::UTF8.GetBytes($_)} | Add-Content -Encoding Byte -Path $SaveTeachersSyncHistoryPath -NoNewline
            }
            else # PowerShell Core Exports without the BOM
            {
                $TeacherSyncHistoryLine | Export-Csv -Encoding UTF8 -Path $SaveTeachersSyncHistoryPath -NoTypeInformation -Append
            }
        }

        # Gather Teacher Custom Preferences
        $TeacherPreference = $TeacherPreferences | Where-Object -Property TeacherEmail -EQ $teacher.email
        $IsReminderOn = if ($TeacherPreference.IsReminderOn) { $TeacherPreference.IsReminderOn} else { $DefaultIsReminderOn }
        $ReminderMinutesBeforeStart = if ($TeacherPreference.ReminderMinutesBeforeStart) { $TeacherPreference.ReminderMinutesBeforeStart} else { $DefaultReminderMinutesBeforeStart }
        $ShowAs = if ($TeacherPreference.ShowAs) { $TeacherPreference.ShowAs} else { $DefaultShowAs }

        # Create Categories in Outlook, if necessary.
        $TeacherCourses = $TeacherMeetings.course_title | Sort-Object -Unique
        $ExistingTeacherCategories = Get-MgUserOutlookMasterCategory -UserId $teacher.email
        foreach ($teacherCourse in $TeacherCourses)
        {
            if ($teacherCourse -notin $ExistingTeacherCategories.DisplayName)
            {
                $NextTeacherCategoryColor = Get-NextOutlookCategoryColor -UserId $teacher.email

                Write-PSFMessage -Level Significant -Message "Creating Exchange Category for $($teacher.display) [$($teacher.id)] [$($teacher.email)]: $($teacherCourse) ($($NextTeacherCategoryColor.Color)::$($NextTeacherCategoryColor.DisplayName))"
                $NewOutlookCategoryResponse = New-MgUserOutlookMasterCategory -UserId $teacher.email -DisplayName $teacherCourse -Color $NextTeacherCategoryColor.Color
            }
        }

        # Collect Existing Events Created By The App\Script
        # (Filter By Extended Property and Date Range)
        # Note: We are using Extended Properties (https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview)
        #       Filter on the field: https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get
        #       Probably the only other option would be to use a Schema Extension. 
        #       Supposedly, Schema Extensions allow filtering (see https://learn.microsoft.com/en-us/graph/extensibility-overview?tabs=http#comparison-of-extension-types).
        #       However, there are reports where the 'event' API Graph object isn't supported with Schema Extensions: https://stackoverflow.com/questions/54205997/how-to-filter-by-value-of-an-extension-in-microsoft-graph
        Write-PSFMessage -Level Significant "Teacher $TeacherIndex of $TeachersCount | Collecting Exchange Calendar Events for Teacher: $($teacher.display) [$($teacher.id)] [$($teacher.email)]"
        $Filter_ExtendedProperty = "(singleValueExtendedProperties/any(ep: ep/id eq 'String {$($EventsAppIdentifier_GUID)} Name $($EventsAppIdentifier_Name)' and ep/value eq '$($EventsAppIdentifier_Value)'))"
        $Filter_DateRange = "(Start/DateTime ge '$($Meetings_StartDateTime_UTC_ISO8601)') and (End/DateTime le '$($Meetings_EndDateTime_UTC_ISO8601)')"
        $Filter = "($Filter_ExtendedProperty) and ($Filter_DateRange)"
        $MGEventProperties = @(
            'Body',
            'BodyPreview',
            'Categories',
            'ChangeKey',
            'CreatedDateTime',
            'End',
            'ICalUId',
            'Id',
            'Importance'
            'IsReminderOn',
            'LastModifiedDateTime',
            'Location',
            'Locations',
            'Organizer',
            'ReminderMinutesBeforeStart',
            'Sensitivity',
            'ShowAs',
            'Start',
            'Subject',
            'Type',
            'WebLink'
        )
        [array]$ExistingTeacherEventsFromExchange = Get-MgUserEvent -UserId $teacher.email -All -Filter $Filter -Property $MGEventProperties | Sort-Object -Property {$_.Start.DateTime}

        # Massage Exchange DateTime Events (Convert to Round-Trip 'o' Format)
        $ExistingTeacherEvents = [System.Collections.Generic.List[Object]]::new()
        foreach ($existingTeacherEventFromExchange in $ExistingTeacherEventsFromExchange)
        {
            $TeacherEventObject = [PSCustomObject]@{}
            foreach ($mGEventProperty in $MGEventProperties)
            {
                switch ($mGEventProperty)
                {
                    {$_ -eq 'Start' -or $_ -eq 'End'}
                    {
                        $GraphTimeZone = $SystemTimeZones | Where-Object -Property Id -EQ $($existingTeacherEventFromExchange.($mGEventProperty).TimeZone)
                        # Convert to UTC DateTime string
                        $GraphValue = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeToUtc(($existingTeacherEventFromExchange.($mGEventProperty).DateTime), $GraphTimeZone)) -Format 'o'
                    }
                    Default
                    {
                        $GraphValue = $existingTeacherEventFromExchange.($mGEventProperty)
                    }
                }
                $NewPSObjectProperty = [PSNoteProperty]::new($mGEventProperty, $GraphValue)
                $TeacherEventObject.psobject.Properties.Add($NewPSObjectProperty)
            }
            $ExistingTeacherEvents.Add($TeacherEventObject)
        }
        $ExistingTeacherEventsCount = $ExistingTeacherEvents.Count

        # Process Meetings From SIS
        Write-PSFMessage -Level Significant "Teacher $TeacherIndex of $TeachersCount | Processing [$TeacherMeetingsCount] SIS Meetings for Teacher: $($teacher.display) [$($teacher.id)] [$($teacher.email)]"
        $TeacherMeetingIndex = 0
        foreach ($teacherMeeting in $TeacherMeetings)
        {
            $TeacherMeetingIndex++
            # NOTE: Keep activity message short or the end can get cut off when displaying (on PS Core).
            Write-Progress -Activity "[$TeacherIndex/$TeachersCount $($teacher.email)] | SIS Meeting $($TeacherMeetingIndex) of $($TeacherMeetingsCount)" -PercentComplete (($TeacherMeetingIndex / $TeacherMeetingsCount) * 100)

            # Create the event, if needed.
            # Start with all Exchange events and filter down.
            $ExistingEventMatchResults = $ExistingTeacherEvents
            $ExistingEventMatchCount = $ExistingEventMatchResults.Count
            foreach ($fieldToMatch in $FieldsToMatch)
            {
                # Filter Down (if necessary)
                if ($ExistingEventMatchCount -eq 0)
                {
                    break # Leave the foreach loop since we no longer need to check.
                }
                $ExistingEventMatchResults = $ExistingEventMatchResults | Where-Object {$_.($fieldToMatch.Graph) -eq $teacherMeeting.($fieldToMatch.SKYAPI)}
                $ExistingEventMatchCount = $ExistingEventMatchResults.Count
            }

            # We should rarely see duplicates (unless someone manually modified an event), but adding this in to output and log when it happens.
            if ($ExistingEventMatchCount -gt 1)
            {
                $NewMessage = "<c='em'>INFO: Skipping processing the following event because it exists [$ExistingEventMatchCount] times on the user's Exchange Calendar (it is possible the user manually modified the event): $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($teacherMeeting.group_name) ($($teacherMeeting.start_time) to $($teacherMeeting.end_time))</c>"
                Write-PSFMessage -Level Significant -Message $NewMessage
                continue # Skip further work on this event.
            }

            if ($ExistingEventMatchCount -eq 0)
            {
                # Collect Meeting Data
                $Event_Subject = $teacherMeeting.group_name
                $Event_Start = ConvertTo-GraphDateTimeTimeZone -DateTime ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date -Date ($teacherMeeting.start_time)), $SchoolTimeZone.Id)) -TimeZone $SchoolTimeZone
                $Event_End = ConvertTo-GraphDateTimeTimeZone -DateTime ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date -Date ($teacherMeeting.end_time)), $SchoolTimeZone.Id)) -TimeZone $SchoolTimeZone
                $Event_Location = @{
                    displayName = $teacherMeeting.room_name
                }
                [string[]]$Categories = @($teacherMeeting.course_title) # Set Categories (array of strings)

                $SectionRosterURL = switch ($teacherMeeting.offering_type.description)
                {
                    Academics { "https://$($MySchoolAppDomain)/app/faculty#academicclass/$($teacherMeeting.section_id)/0/roster" }     
                    Advisory  { "https://$($MySchoolAppDomain)/app/faculty#advisorypage/$($teacherMeeting.section_id)/advisees" }
                    Default   { "https://$($MySchoolAppDomain)/app/faculty#academicclass/$($teacherMeeting.section_id)/0/roster" }  
                }
                $Event_Body = @{
                    contentType = "HTML"
                    content = "<b>Teachers:</b> $(($teacherMeeting.teachers | Sort-Object -Property head -Descending).name -join '; ')<br><br><a href=""$SectionRosterURL"">Click Here For Roster</a>"
                }

                $UserEventParameters = [ordered]@{
                    subject = $Event_Subject
                    body = $Event_Body
                    start = $Event_Start
                    end = $Event_End
                    location = $Event_Location
                    categories = $Categories
                    isReminderOn = $IsReminderOn
                    reminderMinutesBeforeStart = $ReminderMinutesBeforeStart
                    showAs = $ShowAs
                    singleValueExtendedProperties = @(
                        @{
                            id = "String {$($EventsAppIdentifier_GUID)} Name $($EventsAppIdentifier_Name)"
                            value = $EventsAppIdentifier_Value
                        }
                    )
                }
                Write-PSFMessage -Level Significant -Message "Creating Exchange Calendar Event: $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($teacherMeeting.group_name) ($($teacherMeeting.start_time) to $($teacherMeeting.end_time))"
                $NewEventResponse = New-MgUserEvent -UserId $teacher.email -BodyParameter $UserEventParameters
            }
        }
        Write-Progress -Completed -Activity 'Completed'
        
        # Remove extra Exchange events and update still active existing ones, if necessary.
        # Start with all SIS meetings and filter down.
        Write-PSFMessage -Level Significant "Teacher $TeacherIndex of $TeachersCount | Processing [$ExistingTeacherEventsCount] Existing Calendar Events for Teacher: $($teacher.display) [$($teacher.id)] [$($teacher.email)]"
        $ExchangeEventIndex = 0
        foreach ($existingTeacherEvent in $ExistingTeacherEvents)
        {
            $ExchangeEventIndex++
            # NOTE: Keep activity message short or the end can get cut off when displaying (on PS Core).
            Write-Progress -Activity "[$TeacherIndex/$TeachersCount $($teacher.email)] | Exchange Event $($ExchangeEventIndex) of $($ExistingTeacherEventsCount)" -PercentComplete (($ExchangeEventIndex / $ExistingTeacherEventsCount) * 100)

            $ExistingEventMatchResults = $TeacherMeetings
            $ExistingEventMatchCount = $ExistingEventMatchResults.Count
            foreach ($fieldToMatch in $FieldsToMatch)
            {
                # Filter Down (if necessary)
                if ($ExistingEventMatchCount -eq 0)
                {
                    break # Leave the foreach loop since we no longer need to check.
                }
                $ExistingEventMatchResults = $ExistingEventMatchResults | Where-Object {$_.($fieldToMatch.SKYAPI) -eq $existingTeacherEvent.($fieldToMatch.Graph)}
                $ExistingEventMatchCount = $ExistingEventMatchResults.Count
            }

            if ($ExistingEventMatchCount -eq 0) # DELETE IT
            {
                Write-PSFMessage -Level Significant -Message "Removing Extra Calendar Event: $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($existingTeacherEvent.Subject) ($($existingTeacherEvent.Start) to $($existingTeacherEvent.End))"
                # Catch 'Status: 404 (NotFound)' errors and ignore. This might happen if an event was already removed between the events pull and this part of script.
                try
                {
                    $RemoveEventResponse = Remove-MgUserEvent -UserId $teacher.email -EventId $existingTeacherEvent.Id -Confirm:$false
                }
                catch 
                {
                    if (-not ($_.Exception.Message -match 'ErrorItemNotFound')) { throw $_  }
                }
            }
            else # UPDATE IT, IF NECESSARY
            {
                foreach ($teacherPreferenceToVerify in $TeacherPreferencesToVerify)
                {
                    switch ($teacherPreferenceToVerify)
                    {
                        ShowAs
                        {
                            if ($existingTeacherEvent.ShowAs -ine $ShowAs)
                            {
                                Write-PSFMessage -Level Significant -Message "Updating Calendar Event for teacher $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($existingTeacherEvent.Subject) ($($existingTeacherEvent.Start) to $($existingTeacherEvent.End)) > ShowAs from '$($existingTeacherEvent.ShowAs)' to '$ShowAs'"
                                $UpdateEventResponse = Update-MgUserEvent -UserId $teacher.email -EventId $existingTeacherEvent.Id -ShowAs $ShowAs
                            }
                        }
                        isReminderOn
                        {
                            if ($existingTeacherEvent.isReminderOn -ine $isReminderOn)
                            {
                                Write-PSFMessage -Level Significant -Message "Updating Calendar Event for teacher $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($existingTeacherEvent.Subject) ($($existingTeacherEvent.Start) to $($existingTeacherEvent.End)) > isReminderOn from '$($existingTeacherEvent.isReminderOn)' to '$isReminderOn'"
                                $UpdateEventResponse = Update-MgUserEvent -UserId $teacher.email -EventId $existingTeacherEvent.Id -IsReminderOn:$isReminderOn
                            }
                        }
                        ReminderMinutesBeforeStart
                        {
                            if ($existingTeacherEvent.ReminderMinutesBeforeStart -ine $ReminderMinutesBeforeStart)
                            {
                                Write-PSFMessage -Level Significant -Message "Updating Calendar Event for teacher $($teacher.display) [$($teacher.id)] [$($teacher.email)] > $($existingTeacherEvent.Subject) ($($existingTeacherEvent.Start) to $($existingTeacherEvent.End)) > ReminderMinutesBeforeStart from '$($existingTeacherEvent.ReminderMinutesBeforeStart)' to '$ReminderMinutesBeforeStart'"
                                $UpdateEventResponse = Update-MgUserEvent -UserId $teacher.email -EventId $existingTeacherEvent.id -ReminderMinutesBeforeStart $ReminderMinutesBeforeStart
                            }
                        }
                        Default {} # Do Nothing
                    }
                }
            }
        }
        Write-Progress -Completed -Activity 'Completed'
    }

    # Disconnect from Microsoft Graph API, if enabled in config.
    if ($MgDisconnectWhenDone)
    {
        Write-PSFMessage -Level Important -Message "Disconnecting From Microsoft Graph."
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
    }

    # Email Warning Message, if enabled in config.
    If ($EmailonWarning -and $null -ne $CustomWarningMessage)
    {
        # Get Rid of Extra Line at Beginning
        $CustomWarningMessage = $CustomWarningMessage.Trim()

        try
        {
            # Set ScriptMessage Config Path
            Set-ScriptMessageConfigFilePath -Path $ScriptMessageConfigFilePath

            # Add More Email Attributes
            $MessageArguments.Subject = "Sync Schedules to Exchange Calendar - Warning"
            $MessageArguments.Body = "The Sync Schedules to Exchange Calendar script has detected at least one non-critical issue:`n`n$CustomWarningMessage`n`nThank you,`nThe IT Team"
            $MessageArguments.Attachment = $null # No attachments because we don't want anything to accidentally prevent the alert email from being sent.

            # Send Warning Message Alert
            $SendEmailMessageResult = Send-ScriptMessage @MessageArguments
            if ($null -eq $SendEmailMessageResult.Error -or $SendEmailMessageResult.Error -eq "")
            {
                Write-PSFMessage -Level Important -Message "Email Alert (Script Warning) sent successfully to: $($SendEmailMessageResult.Recipients.All)"
            }
            else
            {
                Write-PSFMessage -Level Error -Message "Email Alert (Script Warning) unable to send: $($SendEmailMessageResult.Error)" -Tag 'Failure' -ErrorRecord $_
            }
        }
        catch
        {
            Write-PSFMessage -Level Error -Message "There has been an error emailing the Script Warning alert message: $_" -Tag 'Failure' -ErrorRecord $_
        }
    }

    # End Logging Message
    Write-PSFMessage -Level Important -Message "---SCRIPT END---"
    Wait-PSFMessage # Make Sure Logging Is Flushed Before Terminating
}
catch
{
    # Log Error Message
    Write-PSFMessage -Level Error -Message "Error Running Script (Name: `"$($_.InvocationInfo.ScriptName)`" | Line: $($_.InvocationInfo.ScriptLineNumber))" -Tag 'Failure' -ErrorRecord $_

    # Disconnect from Microsoft Graph API, if enabled in config.
    if ($MgDisconnectWhenDone)
    {
        Write-PSFMessage -Level Important -Message "Disconnecting From Microsoft Graph."
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
    }

    # Try to Email Alert Message On Error, if enabled in config.
    if ($EmailonError)
    {
        try
        {
            # Set ScriptMessage Config Path
            Set-ScriptMessageConfigFilePath -Path $ScriptMessageConfigFilePath

            # Add More Email Attributes
            $MessageArguments.Subject = "SIS Faculty Schedules Sync - Error"
            $MessageArguments.Body = "There has been an error running the SIS Faculty Schedules Sync Script (Name: `"$($_.InvocationInfo.ScriptName)`" | Line: $($_.InvocationInfo.ScriptLineNumber)):`n`n$_`n`nThank you,`nThe IT Team"
            $MessageArguments.Attachment = $null # No attachments because we don't want anything to accidentally prevent the alert email from being sent.

            # Send Error Message Alert
            $SendEmailMessageResult = Send-ScriptMessage @MessageArguments
            if ($null -eq $SendEmailMessageResult.Error -or $SendEmailMessageResult.Error -eq "")
            {
                Write-PSFMessage -Level Important -Message "Email Alert (Script Error) sent successfully to: $($SendEmailMessageResult.Recipients.All)"
            }
            else
            {
                Write-PSFMessage -Level Error -Message "Email Alert (Script Error) unable to send: $($SendEmailMessageResult.Error)" -Tag 'Failure' -ErrorRecord $_
            }
        }
        catch
        {
            Write-PSFMessage -Level Error -Message "There has been an error emailing the Script Error alert message: $_" -Tag 'Failure' -ErrorRecord $_
        }
    }







    # End Logging Message
    Write-PSFMessage -Level Important -Message "---SCRIPT END---"
    Wait-PSFMessage # Make Sure Logging Is Flushed Before Terminating
}