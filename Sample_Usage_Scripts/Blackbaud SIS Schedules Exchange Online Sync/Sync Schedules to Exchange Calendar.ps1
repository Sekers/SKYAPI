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

#################
# PREREQUISITES #
#################

# SKYAPI PowerShell Module (for connecting to the SIS - https://github.com/Sekers/SKYAPI)
# Microsoft Graph PowerShell SDK (for connecting to Microsoft Graph - https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)
# - You only need Microsoft.Graph.Authentication, Microsoft.Graph.Calendar & Microsoft.Graph.Users if you want to minimize the installation footprint.
# OPTIONAL: PSFramework (only needed if logging - https://github.com/PowershellFrameworkCollective/psframework)
# OPTIONAL: ScriptMessage (only needing if sending alerts from the script - https://github.com/Sekers/ScriptMessage)
# - Using MgGraph as messaging service so this requires: 
# -- Microsoft.Graph.Authentication (Mail & Chat)
# -- Microsoft.Graph.Users.Actions (Mail Only)
# -- Microsoft.Graph.Teams (Chat Only)
# -- Microsoft.Graph.Files (Mail & Chat - Only if OneDrive Uploads Are Needed)

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

    $ExistingCategories = Get-MgUserOutlookMasterCategory -UserId $UserId -All

    [array]$ExistingCategoriesColorCount = foreach ($outlookCategoryColor in $OutlookCategoryColors)
    {
        $CategoryColor = [PSCustomObject]@{
            Index = $($outlookCategoryColor.Index)
            Color = $($outlookCategoryColor.Color)
            DisplayName   = $($outlookCategoryColor.DisplayName)
            Count   = ($ExistingCategories | Where-Object -Property Color -EQ $outlookCategoryColor.Color).Count
        }
        $CategoryColor
    }
    $NextCategoryColor = ($ExistingCategoriesColorCount | Sort-Object -Property Count, Index)[0]

    return $NextCategoryColor
}

function Write-RunSummary
{
    <#
        .SYNOPSIS
        Writes the end-of-run tally of what the script did.

        .DESCRIPTION
        Written to the log when logging is enabled and to the host when it isn't, so that an unattended run
        always leaves a record of its outcome even with logging & email alerts turned off.
    #>

    param (
        [Parameter(Mandatory=$true)][string]$Outcome, # E.g., 'Success', 'Completed With Errors', 'Failed'.
        [Parameter(Mandatory=$true)][System.Collections.Specialized.OrderedDictionary]$Counters,
        [bool]$LoggingEnabled = $false,
        [string]$Detail
    )

    $CounterText = ($Counters.GetEnumerator() | ForEach-Object {"$($_.Key)=$($_.Value)"}) -join ', '
    $SummaryText = "Run Summary [$($Outcome)]: $CounterText"
    if (-not [string]::IsNullOrWhiteSpace($Detail)) { $SummaryText += " | $Detail" }

    # When logging is on the logging provider already writes this to the console, so only write it directly
    # when it isn't. That way the summary is always seen once, however the script is configured.
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message $SummaryText}
    else {Write-Host $SummaryText}

    return $SummaryText
}

function Write-UserSyncHistory
{
    <#
        .SYNOPSIS
        Appends one user's synchronization result to the users synchronization history file.

        .DESCRIPTION
        Called once a user's calendar work has finished (successfully or not) so that the row reflects what
        actually happened rather than what was about to be attempted. Does nothing when no history path is set.
    #>

    param (
        [string]$Path,
        [Parameter(Mandatory=$true)]$User,
        [int32]$MeetingsCount,
        [int32]$Created,
        [int32]$Updated,
        [int32]$Deleted,
        [Parameter(Mandatory=$true)][ValidateSet('Success','Failed','DeleteGuardTripped')][string]$Status
    )

    if ([string]::IsNullOrEmpty($Path)) { return }

    $UserSyncHistoryLine = [PSCustomObject]@{
        Timestamp     = $([DateTime]::UtcNow.ToString('u'))
        ID            = $($User.id)
        Name          = $($User.display)
        Email         = $($User.email)
        MeetingsCount = $MeetingsCount
        Created       = $Created
        Updated       = $Updated
        Deleted       = $Deleted
        Status        = $Status
    }

    # The history is a record of the sync, not part of it, so a problem writing the file (e.g. it is open in
    # another program) is reported rather than allowed to interrupt the calendar work.
    try
    {
        if ($PSVersionTable.PSEdition.ToString() -eq 'Desktop') # Hack because Windows PowerShell 5.1 adds the Byte order mark (BOM) to the beginning of the export (which we don't want). In Windows PowerShell, any Unicode encoding, except UTF7, always creates a BOM. PowerShell (v6 and higher) defaults to utf8NoBOM for all text output.
        {
            $UserSyncHistoryLine | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-String | ForEach-Object {[Text.Encoding]::UTF8.GetBytes($_)} | Add-Content -Encoding Byte -Path $Path -NoNewline
        }
        else # PowerShell Core Exports without the BOM
        {
            $UserSyncHistoryLine | Export-Csv -Encoding UTF8 -Path $Path -NoTypeInformation -Append
        }
    }
    catch
    {
        Write-Warning "Unable to write the users synchronization history row for [$($User.email)]: $_"
    }
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
[int32[]]$TeacherRoleIDs = $Config.General.TeacherRoleIDs # May be empty/absent (e.g. a student-only sync).
[int32[]]$StudentRoleIDs = $Config.General.StudentRoleIDs # May be empty/absent. Rosters are only pulled when there are student roles.
[string]$MySchoolAppDomain = $Config.General.MySchoolAppDomain
[string]$Meetings_DateSelection = $Config.General.Meetings.DateSelection # 'Year' or 'Term' or 'Range'
[int32]$Meetings_DaysToAppearBefore = $Config.General.Meetings.DaysToAppearBefore
[Nullable[int32]]$Meetings_MaxPastDaysToSync = $Config.General.Meetings.MaxPastDaysToSync # Needs to be nullable in case we don't want a limit
[string]$Meetings_StartDate = $Config.General.Meetings.StartDate # Only used when 'DateSelection' is 'Range'.
[string]$Meetings_EndDate = $Config.General.Meetings.EndDate # Only used when 'DateSelection' is 'Range'.
[array]$Meetings_OfferingTypes = $Config.General.Meetings.OfferingTypes
[string]$DefaultShowAs = $Config.General.EventDefaults.ShowAs
[bool]$DefaultIsReminderOn = $Config.General.EventDefaults.IsReminderOn
[int32]$DefaultReminderMinutesBeforeStart = $Config.General.EventDefaults.ReminderMinutesBeforeStart
[string]$EventsAppIdentifier_GUID = $Config.General.EventsAppIdentifier.GUID
[string]$EventsAppIdentifier_Name = $Config.General.EventsAppIdentifier.Name
[string]$EventsAppIdentifier_Value = $Config.General.EventsAppIdentifier.Value

# Parse the event tag GUID here because the single-instance lock further below is named after it and needs its
# canonical form. Whether it is actually usable is reported by the configuration checks inside the main
# try/catch (so a bad value still gets the normal logging & alerting); this only records what it parsed to.
$EventsAppIdentifier_GUID_Parsed = [guid]::Empty
$EventsAppIdentifier_GUID_IsValid = [guid]::TryParse($EventsAppIdentifier_GUID, [ref]$EventsAppIdentifier_GUID_Parsed)

# Deletion Safety Settings.
# The sync removes any of its own tagged events that no longer match a SIS meeting, so a wrongly-empty or
# unexpectedly small SIS result would otherwise clear calendars. These limits stop that from happening silently.
[bool]$AllowEmptySourceSync = $Config.General.DeleteSafety.AllowEmptySourceSync # Allow a run where the SIS returned no meetings at all (this deletes every synced event in range and overrides the per-user percentage limit for that run).
[int32]$MaxDeletePercentPerUser = $Config.General.DeleteSafety.MaxDeletePercentPerUser # Hold back creations & deletions for a user when MORE than this percentage of their existing synced events would be removed (100 = never hold back).
[int32]$MinDeletesBeforeCheck = $Config.General.DeleteSafety.MinDeletesBeforeCheck # Only apply the percentage check once at least this many deletions are queued (keeps small calendars from tripping it).

# Users Synchronization History Settings
[string]$SaveUsersSyncHistoryPath = $ExecutionContext.InvokeCommand.ExpandString($Config.General.UsersSyncHistory.Path)
[int32]$UsersSyncHistoryRetentionTimeInDays = $Config.General.UsersSyncHistory.RetentionTimeInDays

# Configure SKYAPI and Verify Type
[string]$SKYAPIConfigFilePath = $ExecutionContext.InvokeCommand.ExpandString($Config.SKYAPI.ConfigFilePath) # The location where you placed your Blackbaud SKY API configuration file. Can accept PowerShell variables.
[string]$SKYAPITokensFilePath = $ExecutionContext.InvokeCommand.ExpandString($Config.SKYAPI.TokensFilePath) # The location where you want the access and refresh tokens to be stored. Can accept PowerShell variables.

# Configure Microsoft Graph and Verify Type
# The script uses Application permissions only (see the Microsoft Graph connection section below for why).
[bool]$MgDisconnectWhenDone = $Config.MSGraph.MgDisconnectWhenDone # Recommended.
[string]$MgClientID = $Config.MSGraph.MgClientID
[string]$MgTenantID = $Config.MSGraph.MgTenantID
[string]$MgApp_AuthenticationType = $Config.MSGraph.MgApp_AuthenticationType
[string]$MgApp_CertificatePath = $ExecutionContext.InvokeCommand.ExpandString($Config.MSGraph.MgApp_CertificatePath)
[string]$MgApp_CertificateName = $Config.MSGraph.MgApp_CertificateName
[string]$MgApp_CertificateThumbprint = $Config.MSGraph.MgApp_CertificateThumbprint
[string]$MgApp_EncryptedCertificatePassword = $Config.MSGraph.MgApp_EncryptedCertificatePassword
[string]$MgApp_EncryptedSecret = $Config.MSGraph.MgApp_EncryptedSecret

# Configure Logging (See https://psframework.org/documentation/documents/psframework/logging/loggingto/logfile.html)
# The PSFramework module (and all logging calls) are only used when logging is enabled in the config.
[bool]$LoggingEnabled = $Config.Logging.Enabled
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

    $CustomWarningMessage = $null # Reset Message
}

# 'Import Meetings To Ignore' & 'User Preferences' Settings
$MeetingsToIgnore = Get-Content -Path "$PSScriptRoot\Config\config_meetings_to_ignore.json" | ConvertFrom-Json
$UserPreferencesFromConfig = Get-Content -Path "$PSScriptRoot\Config\config_user_preferences.json" | ConvertFrom-Json
[array]$UserPreferences = @($UserPreferencesFromConfig | Where-Object {$null -ne $_})

# Create List of Custom Preferences to Compare
$UserPreferencesToVerify = @('ShowAs','IsReminderOn','ReminderMinutesBeforeStart')

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
   exit 1
}

# Check For Microsoft.Graph Module.
# Don't import the entire 'Microsoft.Graph' module because of some issues with doing it that way. Only import the needed modules.
Import-Module 'Microsoft.Graph.Authentication' -ErrorAction SilentlyContinue
Import-Module 'Microsoft.Graph.Calendar' -ErrorAction SilentlyContinue
Import-Module 'Microsoft.Graph.Users' -ErrorAction SilentlyContinue
if (!(Get-Module -Name "Microsoft.Graph.Calendar") -or !(Get-Module -Name "Microsoft.Graph.Users"))
{
    # Module is not available.
    Write-Error "Please First Install the Microsoft.Graph Module (or just the 'Microsoft.Graph.Calendar' & 'Microsoft.Graph.Users' submodules) from https://www.powershellgallery.com/packages/Microsoft.Graph/ "
    exit 1
}

# Check For PowerShell Framework Module (Only Required If Logging Is Enabled)
if ($LoggingEnabled)
{
    Import-Module PSFramework -ErrorAction SilentlyContinue
    if (!(Get-Module -Name "PSFramework"))
    {
        # Module is not loaded
        Write-Error "Please First Install the PowerShell Framework Module from https://psframework.org."
        exit 1
    }
}

# Check For ScriptMessage PowerShell Module (Only Required If Email Alerts Are Enabled)
if ($EmailonError -or $EmailonWarning)
{
    Import-Module ScriptMessage -ErrorAction SilentlyContinue
    if (!(Get-Module -Name "ScriptMessage"))
    {
        # Module is not loaded
        Write-Error "Please First Install the ScriptMessage Module from https://github.com/Sekers/ScriptMessage."
        exit 1
    }
}

################
# PERFORM WORK #
################

# If Logging Is Enabled, Set Logging Data & Log PowerShell & Module Version Information.
if ($LoggingEnabled)
{
    Set-PSFLoggingProvider @paramSetPSFLoggingProvider
    Write-PSFMessage -Level Important -Message "---SCRIPT BEGIN---"
    Write-PSFMessage -Level Verbose -Message "PowerShell Version: $($PSVersionTable.PSVersion.ToString()), $($PSVersionTable.PSEdition.ToString())$(if([Environment]::Is64BitProcess){$(", 64Bit")}else{$(", 32Bit")})"
    foreach ($moduleInfo in Get-Module)
    {
        Write-PSFMessage -Level Verbose -Message "$($moduleInfo.Name) Module Version: $($moduleInfo.Version)"
    }
}

# Tally of what the run did. Reported in the end-of-run summary (& the alert emails) and used to pick the
# script's exit code so that a scheduled task can tell a clean run from a partial or failed one.
$RunCounters = [ordered]@{
    UsersProcessed   = 0
    UsersSkipped     = 0
    UsersFailed      = 0
    EventsCreated    = 0
    EventsUpdated    = 0
    EventsDeleted    = 0
    DeleteGuardTrips = 0
}

# Only allow one copy of this deployment of the script to run at a time.
# A run can take a while, so a scheduled interval that is shorter than the run time (or a manual run started
# during a scheduled one) would otherwise have two copies working the same calendars: both would see the same
# missing events and both would create them, leaving duplicates behind.
# The lock is named after the deployment's own event tag GUID rather than being a single fixed name, because
# that GUID is what decides which events a deployment manages: two deployments installed on the same computer
# with different tags (e.g. a test install alongside the live one, or separate teacher & student syncs) never
# touch the same events and so are free to run at the same time, while two that share a tag do work on the same
# events and still take turns.
# The GUID is used in its parsed, canonical 'N' form (32 hex digits, no braces or hyphens, lower case) rather
# than as it was typed. Mutex names are case-sensitive and a GUID can be written in several equally valid ways,
# so the same tag entered as "{A1B2...}" in one deployment's configuration file and "a1b2..." in another's would
# otherwise produce two different locks for what the calendar sees as one and the same tag. The canonical form
# is also always a legal mutex name (a name cannot contain a backslash other than the 'Global\' prefix, and is
# length limited), which matters because this runs before the main try/catch below can report a bad value.
$SingleInstanceMutexScope = if ($EventsAppIdentifier_GUID_IsValid) {$EventsAppIdentifier_GUID_Parsed.ToString('N')} else {'unparsable-guid'} # An unusable GUID is reported by the configuration checks inside the try/catch below, which stops the run moments from now; this just needs a placeholder to build a name from until then.
$SingleInstanceMutexName = "Global\SISSchedulesExchangeSync-$SingleInstanceMutexScope"
$SingleInstanceMutex = [System.Threading.Mutex]::new($false, $SingleInstanceMutexName)
$SingleInstanceMutexAcquired = $false
try
{
    $SingleInstanceMutexAcquired = $SingleInstanceMutex.WaitOne([TimeSpan]::FromSeconds(10))
}
catch [System.Threading.AbandonedMutexException]
{
    # The previous holder ended without releasing it (e.g. the process was killed). The lock is ours now.
    $SingleInstanceMutexAcquired = $true
    $NewMessage = "The previous run of this script ended without releasing its single-instance lock. Continuing."
    if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
}

if (-not $SingleInstanceMutexAcquired)
{
    $NewMessage = "Another copy of this deployment of the script is still running (single-instance lock `"$SingleInstanceMutexName`"). Stopping so the two runs don't work on the same calendars at the same time."
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message $NewMessage}
    $null = Write-RunSummary -Outcome 'Already Running' -Counters $RunCounters -LoggingEnabled $LoggingEnabled -Detail $NewMessage
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "---SCRIPT END---"}
    if ($LoggingEnabled) {Wait-PSFMessage} # Make Sure Logging Is Flushed Before Terminating
    $SingleInstanceMutex.Dispose()
    exit 3
}

# Begin Program Work (Try/Catch for Error/Warning Processing & Notification)
try
{
    # Determine which roles to sync and whether rosters are needed (teachers are included in the meeting info from SKY API but students are not so we need extra api calls to get students).
    [bool]$PullRosters = ($StudentRoleIDs.Count -gt 0) # Whether to pull section rosters (needed to match students to their section meetings).
    # Combined roles to sync (teachers + students).
    [int32[]]$UserRoleIDs = @($TeacherRoleIDs) + @($StudentRoleIDs) | Where-Object {$null -ne $_}
    if ($UserRoleIDs.Count -eq 0) { throw "At least one of 'TeacherRoleIDs' or 'StudentRoleIDs' must be configured in the general configuration file; otherwise there are no users to sync." }

    # Verify the offering types are usable. A list that is empty, or that holds blank or null entries, is not
    # caught by the SIS existence check further below: a JSON null passes through 'Where-Object' as a lone $null,
    # which collapses to nothing when assigned to a typed array, so it never registers as unmatched. Such a list
    # instead reaches the SKY API as an empty 'offering_types' value, which falls back to the API's own default of
    # 'Academics' - synchronizing an offering type that was never configured AND queueing every event of the other
    # configured types for removal (in 'Term' mode nothing matches at all and the run quietly does nothing).
    # Note the '@()' wrappers below: they keep a single null entry countable instead of collapsing it away.
    [string[]]$Meetings_OfferingTypes_Usable = @($Meetings_OfferingTypes | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})
    if (@($Meetings_OfferingTypes).Count -eq 0)
    {
        throw "'Meetings.OfferingTypes' must contain at least one offering type in the general configuration file (e.g. 'Academics')."
    }
    if ($Meetings_OfferingTypes_Usable.Count -ne @($Meetings_OfferingTypes).Count)
    {
        throw "'Meetings.OfferingTypes' contains a blank or null entry in the general configuration file. Remove it, or replace it with an offering type name (e.g. 'Academics'); a blank entry narrows the meetings pulled from the SIS, which then queues the events of the missing meetings for removal."
    }

    # Verify the event tag settings. Together they are how the script recognizes the events it created: the same
    # three values build the tag written onto each new event and the filter used to read those events back. If any
    # part is missing (or the GUID isn't a GUID, which the named-property format requires) the filter stops
    # matching, so the script no longer recognizes its own events - it would neither update nor remove them and
    # would create duplicates alongside them on every run. The GUID also names this deployment's single-instance
    # lock (see the mutex above), so a blank one would additionally share that lock with every other deployment.
    if ([string]::IsNullOrWhiteSpace($EventsAppIdentifier_GUID) -or [string]::IsNullOrWhiteSpace($EventsAppIdentifier_Name) -or [string]::IsNullOrWhiteSpace($EventsAppIdentifier_Value))
    {
        throw "'EventsAppIdentifier' GUID, Name & Value must all be set in the general configuration file. They form the tag that identifies the events created by this script."
    }
    if (-not $EventsAppIdentifier_GUID_IsValid) # Parsed where the configuration values are read, since the single-instance lock above is named after it.
    {
        throw "'EventsAppIdentifier.GUID' must be a valid GUID in the general configuration file (currently '$EventsAppIdentifier_GUID'). Generate one by running 'New-Guid' in PowerShell. Note that changing this value once events exist orphans the previously created events."
    }

    # Verify the deletion safety limits. A missing 'DeleteSafety' section reads as zero, which would quietly
    # stop the script from ever removing an event, so require a usable percentage rather than assuming one.
    if (($MaxDeletePercentPerUser -le 0) -or ($MaxDeletePercentPerUser -gt 100))
    {
        throw "'DeleteSafety.MaxDeletePercentPerUser' must be between 1 and 100 in the general configuration file (currently '$MaxDeletePercentPerUser'). When removing MORE than this share of a user's synced events is queued in one run, that user's creations & removals are held back and reported instead (100 = even a full clear is allowed)."
    }
    if ($MinDeletesBeforeCheck -lt 0)
    {
        throw "'DeleteSafety.MinDeletesBeforeCheck' cannot be negative in the general configuration file (currently '$MinDeletesBeforeCheck')."
    }

    # Verify the meeting date window settings. Both are applied as AddDays() offsets, so a negative value silently
    # moves the window the opposite way from what was intended: a negative 'MaxPastDaysToSync' pushes the start
    # date into the future (inverting the range), and a negative 'DaysToAppearBefore' drops the current term(s)
    # from the term list, which then queues the meetings that went missing with them for removal. Zero is
    # meaningful for both (never look ahead / start from today), so only reject negatives.
    if ($Meetings_DaysToAppearBefore -lt 0)
    {
        throw "'Meetings.DaysToAppearBefore' cannot be negative in the general configuration file (currently '$Meetings_DaysToAppearBefore'). Use 0 to never look ahead to the next school year or term."
    }
    if (($null -ne $Meetings_MaxPastDaysToSync) -and ($Meetings_MaxPastDaysToSync -lt 0))
    {
        throw "'Meetings.MaxPastDaysToSync' cannot be negative in the general configuration file (currently '$Meetings_MaxPastDaysToSync'). It counts back from today, so a negative value would move the sync start date into the future. Use null to apply no past cutoff."
    }

    # Verify the date selection mode. An unrecognized value would otherwise fall through the switch below to its
    # empty 'Default' block, leaving the start & end dates exactly as configured (blank in the shipped template)
    # and failing much later with an unhelpful date conversion error.
    [string[]]$ValidDateSelections = @('Year','Term','Range')
    if ($Meetings_DateSelection -notin $ValidDateSelections)
    {
        throw "'Meetings.DateSelection' must be one of [$($ValidDateSelections -join ', ')] in the general configuration file (currently '$Meetings_DateSelection')."
    }

    # In 'Range' mode the configured dates are the entire sync window, so verify them here rather than letting a
    # typo surface as a date conversion error after the SIS meetings have already been pulled. The other modes
    # compute their own dates and leave these blank, so only check them when they are actually used.
    if ($Meetings_DateSelection -eq 'Range')
    {
        $Meetings_StartDate_Parsed = [datetime]::MinValue
        $Meetings_EndDate_Parsed = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($Meetings_StartDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$Meetings_StartDate_Parsed))
        {
            throw "'Meetings.StartDate' must be a date in 'yyyy-MM-dd' format (e.g. '2025-08-15') when 'Meetings.DateSelection' is 'Range' in the general configuration file (currently '$Meetings_StartDate')."
        }
        if (-not [datetime]::TryParseExact($Meetings_EndDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$Meetings_EndDate_Parsed))
        {
            throw "'Meetings.EndDate' must be a date in 'yyyy-MM-dd' format (e.g. '2026-06-05') when 'Meetings.DateSelection' is 'Range' in the general configuration file (currently '$Meetings_EndDate')."
        }
        if ($Meetings_EndDate_Parsed -lt $Meetings_StartDate_Parsed)
        {
            throw "'Meetings.EndDate' ('$Meetings_EndDate') cannot be earlier than 'Meetings.StartDate' ('$Meetings_StartDate') in the general configuration file."
        }
    }

    # Verify the event defaults. 'ShowAs' is handed to Microsoft Graph as-is, so an unrecognized value is rejected
    # on every event: every user would be marked failed, and because the update comparison would never match, the
    # script would rewrite every event on every run.
    [string[]]$ValidShowAsValues = @('Unknown','Free','Tentative','Busy','Oof','WorkingElsewhere')
    if ($DefaultShowAs -notin $ValidShowAsValues)
    {
        throw "'EventDefaults.ShowAs' must be one of [$($ValidShowAsValues -join ', ')] in the general configuration file (currently '$DefaultShowAs'). These are the Microsoft Graph 'freeBusyStatus' values."
    }
    if ($DefaultReminderMinutesBeforeStart -lt 0)
    {
        throw "'EventDefaults.ReminderMinutesBeforeStart' cannot be negative in the general configuration file (currently '$DefaultReminderMinutesBeforeStart')."
    }

    # Verify the verbose preference. It is assigned to PowerShell's own $VerbosePreference variable, so an
    # unrecognized value is not rejected until something first tries to write a verbose message.
    [string[]]$ValidVerbosePreferences = @('Stop','Inquire','Continue','SilentlyContinue')
    if ($VerbosePreference -notin $ValidVerbosePreferences)
    {
        throw "'Debugging.VerbosePreference' must be one of [$($ValidVerbosePreferences -join ', ')] in the general configuration file (currently '$VerbosePreference')."
    }

    # Verify the sync history retention. The rotation below removes files last written before 'today minus the
    # retention days', so zero or a negative value puts that cutoff at (or past) the current moment and clears
    # every history file, including the one this run is about to append to. Only applies when history is enabled.
    if ((-not [string]::IsNullOrEmpty($SaveUsersSyncHistoryPath)) -and ($UsersSyncHistoryRetentionTimeInDays -lt 1))
    {
        throw "'UsersSyncHistory.RetentionTimeInDays' must be 1 or greater in the general configuration file (currently '$UsersSyncHistoryRetentionTimeInDays') when 'UsersSyncHistory.Path' is set."
    }

    # Verify the per-user preference overrides. These are handed to Microsoft Graph the same way the event
    # defaults above are, so checking them here keeps one bad entry from failing that user midway through the run.
    foreach ($userPreference in $UserPreferences)
    {
        # Normalize every accepted representation once so a JSON integer and quoted forms such as "01757293" all
        # use the same Int64 value for duplicate detection, unmatched warnings and user matching.
        $ConfiguredUserPreferenceUserId = $userPreference.UserId
        $UserPreferenceUserIdHasSupportedType = (
            ($ConfiguredUserPreferenceUserId -is [string]) -or
            ($ConfiguredUserPreferenceUserId -is [sbyte]) -or
            ($ConfiguredUserPreferenceUserId -is [byte]) -or
            ($ConfiguredUserPreferenceUserId -is [int16]) -or
            ($ConfiguredUserPreferenceUserId -is [uint16]) -or
            ($ConfiguredUserPreferenceUserId -is [int32]) -or
            ($ConfiguredUserPreferenceUserId -is [uint32]) -or
            ($ConfiguredUserPreferenceUserId -is [int64]) -or
            ($ConfiguredUserPreferenceUserId -is [uint64])
        )
        $UserPreferenceUserIdText = [Convert]::ToString($ConfiguredUserPreferenceUserId, [cultureinfo]::InvariantCulture)
        $UserPreferenceUserId = [int64]0
        if ((-not $UserPreferenceUserIdHasSupportedType) -or
            (-not [int64]::TryParse($UserPreferenceUserIdText, [System.Globalization.NumberStyles]::Integer, [cultureinfo]::InvariantCulture, [ref]$UserPreferenceUserId)) -or
            ($UserPreferenceUserId -le 0))
        {
            throw "'UserId' must be the SIS user ID as a whole number greater than 0 in the user preferences configuration file (currently '$ConfiguredUserPreferenceUserId'$(if (-not [string]::IsNullOrWhiteSpace($userPreference.Comment)) {" for $($userPreference.Comment)"}))."
        }
        $userPreference.UserId = $UserPreferenceUserId

        # Nobody can identify a SIS user ID at a glance, so include the optional Comment in validation messages.
        # Comment never takes part in matching a user.
        $UserPreferenceLabel = "user id '$($userPreference.UserId)'"
        if (-not [string]::IsNullOrWhiteSpace($userPreference.Comment)) { $UserPreferenceLabel += " ($($userPreference.Comment))" }

        if ((-not [string]::IsNullOrEmpty($userPreference.ShowAs)) -and ($userPreference.ShowAs -notin $ValidShowAsValues))
        {
            throw "'ShowAs' for $UserPreferenceLabel must be one of [$($ValidShowAsValues -join ', ')] in the user preferences configuration file (currently '$($userPreference.ShowAs)')."
        }

        # Confirm the type as well as the range: the override is read with a null check rather than a cast, so a
        # quoted number in the configuration file would reach Graph as a string.
        if ($null -ne $userPreference.ReminderMinutesBeforeStart)
        {
            $UserPreferenceReminderMinutes = 0
            if ((-not [int32]::TryParse([string]$userPreference.ReminderMinutesBeforeStart, [ref]$UserPreferenceReminderMinutes)) -or ($UserPreferenceReminderMinutes -lt 0))
            {
                throw "'ReminderMinutesBeforeStart' for $UserPreferenceLabel must be a whole number of 0 or greater in the user preferences configuration file (currently '$($userPreference.ReminderMinutesBeforeStart)')."
            }
        }
    }

    # A repeated user ID makes the preference lookup later in the run return every matching entry instead of one,
    # which then hands Microsoft Graph an array where it expects a single value. The IDs were normalized above,
    # so equivalent numeric and quoted forms are grouped together. Warn rather than stop, since every other user
    # is unaffected.
    [int64[]]$DuplicateUserPreferenceIds = @($UserPreferences | Group-Object -Property UserId | Where-Object {$_.Count -gt 1}).Name
    if ($DuplicateUserPreferenceIds.Count -gt 0)
    {
        $NewMessage = "WARNING: The user preferences configuration file has more than one entry for user id: $($DuplicateUserPreferenceIds -join ', '). Only one entry per user is supported, so the duplicated entries will not be applied correctly."
        if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
        if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
    }

    # If set, test path to writable list of user calendar synchronizations and create file if necessary.
    if (-not [string]::IsNullOrEmpty($SaveUsersSyncHistoryPath))
    {
        # Resolve the '%date%' placeholder: a wildcard filter for rotation cleanup and today's date for the actual file path.
        [string]$UsersSyncHistoryRotateFilter = [System.IO.Path]::GetFileName($SaveUsersSyncHistoryPath) -replace '%date%', '*'
        [string]$SaveUsersSyncHistoryPath = $SaveUsersSyncHistoryPath -replace '%date%', $(Get-Date -Format 'yyyy-MM-dd')

        # Get parent folder path
        $SaveUsersSyncHistoryParentDirectory = ([System.IO.Path]::GetDirectoryName($SaveUsersSyncHistoryPath))

        # Create Destination Folder (In Case It Doesn't Already Exist)
        $null = New-Item -ItemType Directory -Path $SaveUsersSyncHistoryParentDirectory -Force
        # Verify Write Access to Destination Folder
        if (!(Test-Write -Path $SaveUsersSyncHistoryParentDirectory))
        {
            Write-Error "You do not have create & write access to the the users synchronization history parent folder: $($SaveUsersSyncHistoryParentDirectory)" -ErrorAction Stop
        }

        # Cleanup old user history files, if necessary. Remove files last written before the retention cutoff (today minus the retention days).
        $UserSyncHistoryFiles = Get-ChildItem -Path $SaveUsersSyncHistoryParentDirectory -Filter $UsersSyncHistoryRotateFilter
        $UserSyncHistoryFiles | Where-Object -Property LastWriteTime -lt (Get-Date).AddDays(-$UsersSyncHistoryRetentionTimeInDays) | Remove-Item -Force

        # Create CSV File With Headers, If Necessary
        $UserSyncHistoryHeader = '"Timestamp","ID","Name","Email","MeetingsCount","Created","Updated","Deleted","Status"'
        if (Test-Path $SaveUsersSyncHistoryPath)
        {
            # An existing file written by an older version of this script has fewer columns, which would make every
            # append fail. Set it aside so today's run starts a clean file instead of losing the older rows.
            $ExistingUserSyncHistoryHeader = Get-Content -Path $SaveUsersSyncHistoryPath -TotalCount 1
            if ($ExistingUserSyncHistoryHeader -ne $UserSyncHistoryHeader)
            {
                $ArchivedUserSyncHistoryPath = [System.IO.Path]::ChangeExtension($SaveUsersSyncHistoryPath, $null) + "(Previous Format $(Get-Date -Format 'HHmmss'))" + [System.IO.Path]::GetExtension($SaveUsersSyncHistoryPath)
                Rename-Item -Path $SaveUsersSyncHistoryPath -NewName ([System.IO.Path]::GetFileName($ArchivedUserSyncHistoryPath))
                $NewMessage = "The existing users synchronization history file has an outdated set of columns. It has been renamed to `"$([System.IO.Path]::GetFileName($ArchivedUserSyncHistoryPath))`" and a new file started."
                if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
            }
        }
        if (-not (Test-Path $SaveUsersSyncHistoryPath))
        {
            if ($PSVersionTable.PSEdition.ToString() -eq 'Desktop') # Hack because Windows PowerShell 5.1 adds the Byte order mark (BOM) to the beginning of the export (which we don't want). In Windows PowerShell, any Unicode encoding, except UTF7, always creates a BOM. PowerShell (v6 and higher) defaults to utf8NoBOM for all text output.
            {
                $UserSyncHistoryHeader | Out-String | ForEach-Object {[Text.Encoding]::UTF8.GetBytes($_)} | Set-Content -Encoding Byte -Path $SaveUsersSyncHistoryPath -NoNewline
            }
            else # PowerShell Core Exports without the BOM
            {
                $UserSyncHistoryHeader | Out-String | Set-Content -Encoding UTF8 -Path $SaveUsersSyncHistoryPath -NoNewline
            }
        }
    }

    # Set SKYAPI Paths
    Set-SKYAPIConfigFilePath -Path $SKYAPIConfigFilePath
    Set-SKYAPITokensFilePath -Path $SKYAPITokensFilePath

    # Connect to Blackbaud SKY API
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Connecting to the Blackbaud SKY API"}
    Connect-SKYAPI

    # Microsoft Graph application permissions this script requires (verified against the connection after connecting;
    # see the Graph connection block below for what each one is used for). Not configurable: these are intrinsic to what the script does.
    [string[]]$RequiredMgScopes = @('Calendars.ReadWrite', 'User.Read.All')

    # Connect to the Microsoft Graph API using Application permissions (an app registration consented by an
    # administrator and authenticated by certificate or client secret). Application permissions are required
    # because the script manages calendars for every user returned by the SIS; delegated permissions can only
    # access the signed-in user's own calendar (or calendars shared/delegated to them).
    # Grant the app registration these Microsoft Graph application permissions (admin consent required):
    #   - Calendars.ReadWrite:       To create and manage events in user calendars. Also covers reading & creating Outlook
    #                                categories: Microsoft documents the masterCategories API as requiring the MailboxSettings
    #                                permissions, but as of July 2026 Graph permits those calls with Calendars.ReadWrite alone.
    #                                If the category steps ever start failing with ErrorAccessDenied, grant MailboxSettings.ReadWrite.
    #   - User.Read.All:             To list directory users (verify a user exists before touching their calendar).
    # View the current scopes under which the PowerShell SDK is (trying to) execute cmdlets: Get-MgContext | select -ExpandProperty Scopes
    # List all the scopes granted on the service principal object (you can also do it via the Entra admin center): Get-MgServicePrincipal -Filter "appId eq '14d82eec-204b-4c2f-b7e8-296a70dab67e'" | % { Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $_.Id } | fl
    # Find Graph permission needed. More info on permissions: https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent)
    #    E.g., Find-MgGraphPermission -SearchString "Teams" -PermissionType Application
    
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Connecting to Microsoft Graph With App Authentication Type: $MgApp_AuthenticationType"}
    switch ($MgApp_AuthenticationType)
    {
        CertificateFile {
            # This is only supported using PowerShell 7.4 and later because 5.1 is missing the necessary parameters when using 'Get-PfxCertificate'.
            if ($PSVersionTable.PSVersion -lt [Version]'7.4')
            {
                $NewMessage = "Connecting to Microsoft Graph using a certificate file is only supported with PowerShell version 7.4 and later."
                if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
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
                    if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
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
            [System.Version]$GraphAuthVersion = Get-Module -Name 'Microsoft.Graph.Authentication' | Select-Object -ExpandProperty Version
            if ($GraphAuthVersion -lt [System.Version]'2.0.0')
            {
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
                $null = Connect-MgGraph -AccessToken $($Connection.access_token | ConvertTo-SecureString -AsPlainText -Force)
            }
            else # If Graph PowerShell SDK is version 2.0.0 or higher.
            {
                $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $MgClientID, $($MgApp_EncryptedSecret | ConvertTo-SecureString) # Can only be decrypted by the same AD account on the same computer.
                $null = Connect-MgGraph -TenantId $MgTenantID -ClientSecretCredential $ClientSecretCredential
            }
        }
        Default {throw "Invalid `'MgApp_AuthenticationType`' value in the configuration file."}
    }

    # Verify Scopes Granted to the App Match Needed Scopes.
    # These are the Microsoft Graph application permissions this script requires
    # (see the Graph connection block above for what each one is used for).
    $MgContext = Get-MgContext
    if ($null -eq $MgContext)
    {
        $NewMessage = "Not connected to Microsoft Graph (Get-MgContext returned nothing)."
        if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
        throw $NewMessage
    }
    [string[]]$MissingMgScopes = $RequiredMgScopes | Where-Object {$_ -notin $MgContext.Scopes}
    if ($MissingMgScopes.Count -gt 0)
    {
        $NewMessage = "The connected Microsoft Graph app is missing required permission scope(s): $($MissingMgScopes -join ', '). Grant these application permissions to the app registration (admin consent required) and try again. Currently granted: $($MgContext.Scopes -join ', ')."
        if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
        throw $NewMessage
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
    if ([string]::IsNullOrEmpty($SchoolTimeZone))
    {
        throw "Unable to match the school time zone `"$SchoolTimeZoneId`" to a time zone on this system (checked Id, StandardName & DaylightName)."
    }
    $SchoolTimeZone = @($SchoolTimeZone)[0] # A StandardName/DaylightName match can return more than one zone; use the first.

    # "Today" for every date-window decision below, as a calendar day in the SCHOOL's time zone. School year &
    # term begin/end dates are calendar days in the school's zone, so comparing them against the host's local
    # date could shift a window by a day around midnight whenever the script runs in a different time zone.
    $TodayInSchoolTimeZone = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), $SchoolTimeZone.Id)).Date

    # Get Offering School Types
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Beginning SIS School Offering Types Collection"}
    $SchoolOfferingTypes = Get-SchoolOfferingType
    $OfferingTypes = foreach ($meetings_OfferingType in $Meetings_OfferingTypes) {$SchoolOfferingTypes | Where-Object {$_.description -eq ($meetings_OfferingType)}}

    # Fail on a configured offering type that doesn't exist in the SIS (e.g. a typo). Without this the name
    # silently matches nothing, which narrows (or empties) the meetings pulled below and would then be treated
    # as "these meetings no longer exist" by the event removal pass.
    # The '@()' wrapper matters: without it a lone unmatched null would collapse to nothing on assignment and
    # slip through this check (blank & null entries are already rejected during the configuration checks above).
    [string[]]$UnmatchedOfferingTypes = @($Meetings_OfferingTypes | Where-Object {$_ -notin $SchoolOfferingTypes.description})
    if ($UnmatchedOfferingTypes.Count -gt 0)
    {
        $NewMessage = "The configured meeting offering type(s) [$($UnmatchedOfferingTypes -join ', ')] do not exist in the SIS. Available offering types: $($SchoolOfferingTypes.description -join ', ')."
        if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
        throw $NewMessage
    }

    # Get Meetings
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Beginning SIS Meetings Collection"}

    # Get the date range to sync meetings.
    # In 'Term' mode this is populated with one current-term window per (level, offering type) so that
    # meetings can later be filtered to only their own level's current term. It stays $null for the
    # 'Year' and 'Range' modes, which makes the later per-level filter a no-op for them.
    $CurrentTermWindows = $null
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
                # The next school year may not exist yet in the SIS (or today+1yr may fall in the summer gap between school years).
                $NextSchoolYear = (Get-SchoolYear | Where-Object {(([datetime]$_.begin_date) -le $TodayInSchoolTimeZone.AddYears(1)) -and (([datetime]$_.end_date) -ge $TodayInSchoolTimeZone.AddYears(1))})
                if ($NextSchoolYear -and (([datetime]$NextSchoolYear.begin_date) -le $TodayInSchoolTimeZone.AddDays($Meetings_DaysToAppearBefore)))
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
                # The next school year may not exist yet in the SIS (or today+1yr may fall in the summer gap between school years).
                $NextSchoolYear = (Get-SchoolYear | Where-Object {(([datetime]$_.begin_date) -le $TodayInSchoolTimeZone.AddYears(1)) -and (([datetime]$_.end_date) -ge $TodayInSchoolTimeZone.AddYears(1))})
                if ($NextSchoolYear)
                {
                    $SchoolTermList += Get-SchoolTerm -school_year $NextSchoolYear.school_year_label | Where-Object -Property offering_type -in $OfferingTypes.id
                    $SchoolTermList = $SchoolTermList | Sort-Object -Property begin_date
                }
            }
            
            # Filter out terms that are not within the date range.
            # Term begin & end dates are whole calendar days, so compare them against calendar days too. Comparing
            # an end date (midnight) against the current moment would drop a term on the morning of its final day.
            $SchoolTermList = $SchoolTermList | Where-Object {([datetime]$_.begin_date).Date -le $TodayInSchoolTimeZone.AddDays(($Meetings_DaysToAppearBefore))}
            $SchoolTermList = $SchoolTermList | Where-Object {([datetime]$_.end_date).Date -ge $TodayInSchoolTimeZone}

            # If no terms within the date range are found, stop script (this is common during the summer months).
            if ($SchoolTermList.Count -eq 0)
            {
                if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "No school terms found within the date range (this is common during the summer months). Stopping Script."}

                # Disconnect from Microsoft Graph API, if enabled in config.
                if ($MgDisconnectWhenDone)
                {
                    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Disconnecting From Microsoft Graph."}
                    $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
                }

                # End Logging Message
                $null = Write-RunSummary -Outcome 'Nothing To Do' -Counters $RunCounters -LoggingEnabled $LoggingEnabled -Detail 'No school terms within the date range.'
                if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "---SCRIPT END---"}
                if ($LoggingEnabled) {Wait-PSFMessage} # Make Sure Logging Is Flushed Before Terminating

                # Stop the script. This is a normal, healthy outcome, so exit successfully.
                exit 0
            }

            # Set Date Range Variables
            # Term begin & end dates are already whole calendar days in the school's own time zone, so they are
            # used as-is. Running them through a time zone conversion would interpret them in the host's time
            # zone and could shift them a day whenever the script runs somewhere other than the school's zone.
            [array]$TermBeginDates = foreach ($termBeginDate in $SchoolTermList.begin_date)
            {
                ([datetime]$termBeginDate).Date
            }
            [array]$TermEndDates = foreach ($termEndDate in $SchoolTermList.end_date)
            {
                ([datetime]$termEndDate).Date
            }
            $Meetings_StartDate = (($TermBeginDates | Sort-Object )[0]).ToString('yyyy-MM-dd')
            $Meetings_EndDate = (($TermEndDates | Sort-Object -Descending)[0]).ToString('yyyy-MM-dd')

            # Build a current-term window per (level, offering type). The global date range above spans ALL
            # current terms, so on its own it would sync every level for the widest term (e.g. a year-long
            # advisory term stretches the window across both academic semesters). These windows let us keep
            # each meeting only within its OWN level's current term (see the per-level filter after the fetch).
            # Term begin/end are School Time Zone calendar dates (.Date) so they line up with each meeting's
            # date, which the filter derives from start_time converted to the School Time Zone.
            # The *_description fields are carried for readable logging only; the filter matches on the
            # numeric level_id/offering_type.
            [array]$CurrentTermWindows = foreach ($schoolTerm in $SchoolTermList)
            {
                [PSCustomObject]@{
                    level_id                  = [string]$schoolTerm.level_id
                    level_description         = $schoolTerm.level_description
                    offering_type             = [string]$schoolTerm.offering_type
                    offering_type_description = ($OfferingTypes | Where-Object {$_.id -eq $schoolTerm.offering_type}).description
                    description               = $schoolTerm.description
                    begin_date                = ([datetime]$schoolTerm.begin_date).Date
                    end_date                  = ([datetime]$schoolTerm.end_date).Date
                }
            }
        }
        Range{
            # Nothing to do here; the start and end dates are already set.
        }
        Default {}
    }

    # Only synchronize past meetings if the number of days is less than the maximum allowed.
    if ($null -ne $Meetings_MaxPastDaysToSync)
    {
        $Meetings_StartDate_OldestAllowed = ($TodayInSchoolTimeZone.AddDays(-$Meetings_MaxPastDaysToSync)).ToString('yyyy-MM-dd')
        $Meetings_StartDate = (@([datetime]$Meetings_StartDate, [datetime]$Meetings_StartDate_OldestAllowed) | Sort-Object | Select-Object -Last 1).ToString('yyyy-MM-dd')
    }

    if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Date Selection [Type: $Meetings_DateSelection]: $Meetings_StartDate to $Meetings_EndDate"}

    # In 'Term' mode, log each level/offering-type current-term window so the per-level date ranges that
    # drive the meeting filter are visible in the log (the combined range above just spans all of them).
    if ($null -ne $CurrentTermWindows)
    {
        foreach ($currentTermWindow in $CurrentTermWindows)
        {
            $TermWindowLabel = @($currentTermWindow.level_description, $currentTermWindow.offering_type_description, $currentTermWindow.description) | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
            if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Term Window [$($TermWindowLabel -join ' / ')]: $($currentTermWindow.begin_date.ToString('yyyy-MM-dd')) to $($currentTermWindow.end_date.ToString('yyyy-MM-dd'))"}
        }
    }

    # Set Meetings Parameters & Properties
    $HashArguments = [ordered]@{
        start_date = $Meetings_StartDate
        end_date = $Meetings_EndDate
        offering_types = $OfferingTypes.id -join ','
    }
    $SISMeetingProperties = [System.Collections.Generic.List[string]]@(
        'course_title',
        'end_time',
        'faculty_name',
        'faculty_user_id',
        'group_name',
        'level_number',
        'offering_type',
        'room_name',
        'section_id',
        'start_time',
        'teachers'
    )

    # Only pull section rosters when student roles are configured. Rosters let us match students to their
    # section meetings (the meetings endpoint only returns the section's teachers/leads), but add a
    # one-time API cost, so they are opt-in. When pulled, keep the attached 'roster' property so it
    # survives the Select-Object and DateTime-massage below.
    if ($PullRosters)
    {
        $HashArguments['IncludeRosters'] = $true
        $SISMeetingProperties.Add('roster')
    }

    $MeetingsFromSIS = Get-SchoolScheduleMeeting @HashArguments | Select-Object -Property $SISMeetingProperties
    $MeetingsFromSISCount = @($MeetingsFromSIS).Count # Kept for the deletion safety check below, which reports how many meetings the SIS returned before any filtering.

    # Remove Meetings That Should Be Ignored
    [array]$MeetingsFilterProperties = ($MeetingsToIgnore | Get-Member -MemberType NoteProperty).Name
    foreach ($meetingsFilterProperty in $MeetingsFilterProperties)
    {
        $MeetingsFilterPropertyValues = $MeetingsToIgnore.($meetingsFilterProperty)
        foreach ($meetingsFilterPropertyValue in $MeetingsFilterPropertyValues)
        {
            # Skip blank values. An empty pattern matches every string, so a stray "" in the ignore
            # configuration would silently drop every meeting (and the removal pass would then clear
            # every synced event). Warn instead so the bad entry is visible and gets fixed.
            if ([string]::IsNullOrWhiteSpace($meetingsFilterPropertyValue))
            {
                $NewMessage = "WARNING: Ignoring a blank '$meetingsFilterProperty' value in the meetings to ignore configuration file. A blank value would match (and therefore skip) every meeting."
                if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
                if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
                continue
            }

            # Escape the configured value so it matches as a literal, case-insensitive substring rather than as a regular expression.
            $MeetingsFromSIS = $MeetingsFromSIS | Where-Object -Property $($meetingsFilterProperty) -NotMatch ([regex]::Escape($meetingsFilterPropertyValue))
        }
    }

    # In 'Term' mode, keep each meeting only within its OWN level's current term. A meeting is kept when a
    # current-term window matches its (level_number, offering_type) AND the meeting's date falls inside that
    # window. This prevents a long term for one level/offering (e.g. a year-long advisory term) from pulling
    # in another level's non-current term (e.g. a second academic semester). $CurrentTermWindows is only set
    # in 'Term' mode, so 'Year' and 'Range' modes skip this filter entirely.
    # The meeting's date is taken from start_time converted to the School Time Zone (the same conversion used
    # elsewhere to build events), so it lines up with the School-Time-Zone term begin/end dates.
    if ($Meetings_DateSelection -eq 'Term')
    {
        $MeetingsBeforeTermFilterCount = @($MeetingsFromSIS).Count
        $MeetingsFromSIS = $MeetingsFromSIS | Where-Object {
            $meetingToFilter = $_
            $meetingDate = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date -Date $meetingToFilter.start_time), $SchoolTimeZone.Id)).Date
            [bool]($CurrentTermWindows | Where-Object {
                ($_.level_id -eq [string]$meetingToFilter.level_number) -and
                ($_.offering_type -eq [string]$meetingToFilter.offering_type.id) -and
                ($meetingDate -ge $_.begin_date) -and ($meetingDate -le $_.end_date)
            })
        }
        $MeetingsAfterTermFilterCount = @($MeetingsFromSIS).Count
        if ($LoggingEnabled) {Write-PSFMessage -Level Verbose -Message "Term filter: kept $MeetingsAfterTermFilterCount of $MeetingsBeforeTermFilterCount meetings within their level's current term (dropped $($MeetingsBeforeTermFilterCount - $MeetingsAfterTermFilterCount))."}
    }

    # Massage SIS DateTime Events in Meetings (Convert to Round-Trip 'o' Format)
    $Meetings = [System.Collections.Generic.List[Object]]::new()
    foreach ($meetingFromSIS in $MeetingsFromSIS)
    {
        $UserMeetingObject = [PSCustomObject]@{}
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
                    # $UserMeetingObject.psobject.Properties.Add($NewPSObjectProperty)
                }
                Default
                {
                    $SKYAPIValue = $meetingFromSIS.($sISMeetingProperty)
                }
            }
            $NewPSObjectProperty = [PSNoteProperty]::new($sISMeetingProperty, $SKYAPIValue)
            $UserMeetingObject.psobject.Properties.Add($NewPSObjectProperty)
        }
        $Meetings.Add($UserMeetingObject)
    }

    # DELETION SAFETY: Stop if there are no meetings left to sync.
    # Every event this script created that no longer matches a SIS meeting gets removed further below, so an
    # empty meeting set means "delete every synced event in the date range from every user's calendar". That
    # is almost always a configuration or data problem (a typo in the meetings to ignore file, an offering type
    # with no sections, an SIS outage) rather than a real instruction, so fail loudly instead. Set the
    # 'DeleteSafety.AllowEmptySourceSync' configuration option to $true if an empty sync really is intended.
    if ($Meetings.Count -eq 0 -and -not $AllowEmptySourceSync)
    {
        $NewMessage = "No SIS meetings remain to synchronize (the SIS returned $MeetingsFromSISCount meeting(s) for $Meetings_StartDate to $Meetings_EndDate before the meetings to ignore$(if ($Meetings_DateSelection -eq 'Term'){' and current term'}) filter(s) were applied). Stopping before any calendar events are removed. Verify the configured offering types, the meetings to ignore file & the date range; set 'DeleteSafety.AllowEmptySourceSync' to true if an empty synchronization is expected."
        if ($LoggingEnabled) {Write-PSFMessage -Level Error $NewMessage}
        throw $NewMessage
    }

    # Build a lookup of each user's meetings so per-user gathering is a fast hashtable lookup instead of
    # scanning every meeting per user. A user is associated with a meeting if they are one of the meeting's
    # teachers (leads) OR, when rosters were pulled, an enrolled member of that meeting's section roster.
    #   $SectionMemberIds : section_id (string) -> string[] of member user IDs (built once per section).
    #   $MeetingsByUserId : user_id (string)    -> list of that user's meetings (teacher or member).
    # Note: teachers correspond to roster members with 'leader.is_leader' = true, so a roster member who is
    # not a lead is a student/participant. The teacher-vs-student decision for the event body link is made
    # later per meeting using the meeting's 'teachers' list.
    $SectionMemberIds = @{}
    if ($PullRosters)
    {
        foreach ($meeting in $Meetings)
        {
            $SectionIdKey = [string]$meeting.section_id
            if (-not $SectionMemberIds.ContainsKey($SectionIdKey))
            {
                [array]$MemberIds = @()
                if ($null -ne $meeting.roster -and $null -ne $meeting.roster.roster)
                {
                    $MemberIds = @($meeting.roster.roster.user.id | Where-Object {$null -ne $_} | ForEach-Object {[string]$_})
                }
                $SectionMemberIds[$SectionIdKey] = $MemberIds
            }
        }
    }

    $MeetingsByUserId = @{}
    foreach ($meeting in $Meetings)
    {
        # De-duplicate so a teacher who also appears in the roster as faculty isn't added twice.
        $UserIdsForMeeting = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($teacherId in $meeting.teachers.id) { [void]$UserIdsForMeeting.Add([string]$teacherId) }
        if ($PullRosters)
        {
            foreach ($memberId in $SectionMemberIds[[string]$meeting.section_id]) { [void]$UserIdsForMeeting.Add($memberId) }
        }

        foreach ($userIdForMeeting in $UserIdsForMeeting)
        {
            if (-not $MeetingsByUserId.ContainsKey($userIdForMeeting))
            {
                $MeetingsByUserId[$userIdForMeeting] = [System.Collections.Generic.List[Object]]::new()
            }
            $MeetingsByUserId[$userIdForMeeting].Add($meeting)
        }
    }

    if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Data summary: total meetings=$($Meetings.Count), sections=$($SectionMemberIds.Count), users with meetings=$($MeetingsByUserId.Count), PullRosters=$PullRosters"}

    # Get All Users
    [array]$SchoolRoles = Get-SchoolRole
    [array]$UserRoles = foreach ($userRoleID in $UserRoleIDs)
    {
        $SchoolRoles | Where-Object -Property id -EQ $userRoleID
    }
    [array]$Users = foreach ($userRole in $UserRoles)
    {
        Get-SchoolUserByRole -roles $userRole.id
    }
    # De-duplicate by id (users can hold multiple synced roles), then sort by display name for readable processing order.
    # Note: display names are not unique, so they must not be used as the de-duplication key.
    $Users = $Users | Sort-Object -Property id -Unique | Sort-Object -Property display
    $UsersCount = $Users.Count
    if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Users to process: $UsersCount"}

    # Report user preference entries that match nobody being synced. A user id cannot be eyeballed for
    # correctness the way an email address can, so a mistyped one would otherwise apply to no one without any
    # sign that it was meant to. Not an error: an entry kept for someone on leave is perfectly reasonable.
    [int64[]]$SyncedUserIds = @($Users | Where-Object {$null -ne $_} | ForEach-Object {[int64]$_.id})
    [array]$UnmatchedUserPreferences = @($UserPreferences | Where-Object {$_.UserId -notin $SyncedUserIds})
    if ($UnmatchedUserPreferences.Count -gt 0)
    {
        $UnmatchedUserPreferenceLabels = foreach ($unmatchedUserPreference in $UnmatchedUserPreferences)
        {
            if (-not [string]::IsNullOrWhiteSpace($unmatchedUserPreference.Comment)) {"$($unmatchedUserPreference.UserId) ($($unmatchedUserPreference.Comment))"} else {[string]$unmatchedUserPreference.UserId}
        }
        $NewMessage = "WARNING: The user preferences configuration file has entries for user id(s) that are not being synchronized: $($UnmatchedUserPreferenceLabels -join ', '). These entries have no effect. Verify the user id is correct and that the user holds one of the configured roles."
        if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
        if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
    }

    # Collect All Directory Member Users
    # Used to make sure users exist before trying to access their calendar.
    # It does not check to see if they have an Exchange Online mailbox; it only verifies that an email address is set due to the extra Graph API calls that would be needed to verify an actual mailbox exists (one per user).
    $EntraDirectoryUsers = Get-MgUser -All -Property Id, DisplayName, Mail | Where-Object {$null -ne $_.'mail'}
    if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Entra directory users with mail: $($EntraDirectoryUsers.Count)"}

    # Set Start\End Times as UTC for Graph Queries
    # https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings#Roundtrip
    # The end of the range is the start of the day after the last day to sync. Add that day to the school's
    # calendar date BEFORE converting to UTC: adding 24 hours to the converted value instead would land on the
    # wrong local time whenever a daylight saving change falls on that day.
    $Meetings_StartDateTime_UTC_ISO8601 = Get-Date ([System.TimeZoneInfo]::ConvertTimeToUtc($Meetings_StartDate, $SchoolTimeZone)) -Format 'o'
    $Meetings_EndDateTime_UTC_ISO8601 = Get-Date ([System.TimeZoneInfo]::ConvertTimeToUtc((([datetime]$Meetings_EndDate).Date.AddDays(1)), $SchoolTimeZone)) -Format 'o'

    # When an empty synchronization was explicitly allowed AND the SIS really returned no meetings, the whole
    # point of the run is to remove every synced event in range, so the per-user deletion limit below would
    # only block the requested cleanup. Note it loudly and let the removals through for this run.
    $DeleteGuardBypassed = ($AllowEmptySourceSync -and ($Meetings.Count -eq 0))
    if ($DeleteGuardBypassed)
    {
        $NewMessage = "WARNING: 'DeleteSafety.AllowEmptySourceSync' is enabled and no SIS meetings remain to synchronize. Every synced event in the date range will be removed and the per-user deletion limit ('DeleteSafety.MaxDeletePercentPerUser') will not be applied this run."
        if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
        if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
    }

    # Create Needed Events & Remove Extra Events
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Beginning Processing Meetings & Existing Calendar Events For Each User"}
    $UserIndex = 0
    foreach ($user in $Users)
    {
        $UserIndex++
        if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Working On User $UserIndex of $($UsersCount): $($user.display) [$($user.id)] [$($user.email)]"}

        # Reset this user's tally. Rolled into $RunCounters and written to the synchronization history at the
        # end of the user's processing (including when it fails part way through).
        $UserMeetingsCount = 0
        $UserEventsCreated = 0
        $UserEventsUpdated = 0
        $UserEventsDeleted = 0
        $UserDeleteGuardTripped = $false

        # Process this user inside try/catch so one broken user/mailbox (e.g. missing license, soft-deleted)
        # logs a warning and moves on instead of aborting the sync for all remaining users.
        try
        {
            # Make Sure User Exists in Directory
            # Keep the matched Entra user so Graph calls can address the account by its immutable object Id.
            # Graph resolves '/users/{x}' by Id or UserPrincipalName only; the SIS email is matched against the
            # Mail attribute, which is not guaranteed to equal the UPN.
            $EntraUser = $EntraDirectoryUsers | Where-Object -Property Mail -EQ $user.email | Select-Object -First 1
            if ($null -eq $EntraUser)
            {
                # Log Warning and Skip This User
                $NewMessage = "WARNING: Skipping user [$($user.id) - $($user.display)] because their email address [$($user.email)] cannot be found in the Entra Active Directory."
                if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
                if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
                $RunCounters.UsersSkipped++
                continue
            }

            # Gather Meetings for User (as a teacher/lead or, when rosters were pulled, an enrolled member).
            $UserMeetings = $MeetingsByUserId[[string]$user.id] | Sort-Object -Property start_time, group_name
            $UserMeetingsCount = $UserMeetings.Count
            if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Desired SIS Meetings for $($user.email) [$UserMeetingsCount]: $(@($UserMeetings.group_name) -join '; ')"}

            # Gather User Custom Preferences
            # Configuration IDs were normalized during validation; normalize the SIS ID at the comparison boundary.
            $UserPreference = $UserPreferences | Where-Object {$_.UserId -eq [int64]$user.id}
            # Null checks (not truthiness) so that overrides of 'false' or '0' are honored.
            $IsReminderOn = if ($null -ne $UserPreference.IsReminderOn) { $UserPreference.IsReminderOn } else { $DefaultIsReminderOn }
            $ReminderMinutesBeforeStart = if ($null -ne $UserPreference.ReminderMinutesBeforeStart) { $UserPreference.ReminderMinutesBeforeStart } else { $DefaultReminderMinutesBeforeStart }
            $ShowAs = if (-not [string]::IsNullOrEmpty($UserPreference.ShowAs)) { $UserPreference.ShowAs } else { $DefaultShowAs }

            # Collect Existing Events Created By The App\Script
            # (Filter By Extended Property and Date Range)
            # Note: We are using Extended Properties (https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview)
            #       Filter on the field: https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get
            #       Probably the only other option would be to use a Schema Extension. 
            #       Supposedly, Schema Extensions allow filtering (see https://learn.microsoft.com/en-us/graph/extensibility-overview?tabs=http#comparison-of-extension-types).
            #       However, there are reports where the 'event' API Graph object isn't supported with Schema Extensions: https://stackoverflow.com/questions/54205997/how-to-filter-by-value-of-an-extension-in-microsoft-graph
            if ($LoggingEnabled) {Write-PSFMessage -Level Significant "User $UserIndex of $UsersCount | Collecting Exchange Calendar Events for User: $($user.display) [$($user.id)] [$($user.email)]"}
            $Filter_ExtendedProperty = "(singleValueExtendedProperties/any(ep: ep/id eq 'String {$($EventsAppIdentifier_GUID)} Name $($EventsAppIdentifier_Name)' and ep/value eq '$($EventsAppIdentifier_Value)'))"
            $Filter_DateRange = "(Start/DateTime ge '$($Meetings_StartDateTime_UTC_ISO8601)') and (End/DateTime le '$($Meetings_EndDateTime_UTC_ISO8601)')"
            $Filter = "($Filter_ExtendedProperty) and ($Filter_DateRange)"
            if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Event filter for $($user.email): $Filter"}

            # The property names here (and in the date filter above) are capitalized to match the event objects
            # the Graph PowerShell SDK hands back, because this list does double duty: it chooses the properties
            # to retrieve AND names the properties read off those objects (and copied onto the objects assembled
            # from them) further below. Microsoft Graph documents these names starting lower case ('showAs',
            # 'isReminderOn'), which is how they must be spelled when sent as a request body (see the event
            # creation block below), but it accepts either capitalization when selecting and filtering.
            # Don't "correct" one of these to match the other; they are separate interfaces.
            $MGEventProperties = @(
                'Body',
                'BodyPreview',
                'Categories',
                'ChangeKey',
                'CreatedDateTime',
                'End',
                'ICalUId',
                'Id',
                'Importance',
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
            [array]$ExistingUserEventsFromExchange = Get-MgUserEvent -UserId $EntraUser.Id -All -Filter $Filter -Property $MGEventProperties | Sort-Object -Property {$_.Start.DateTime}

            # Massage Exchange DateTime Events (Convert to Round-Trip 'o' Format)
            $ExistingUserEvents = [System.Collections.Generic.List[Object]]::new()
            foreach ($existingUserEventFromExchange in $ExistingUserEventsFromExchange)
            {
                $UserEventObject = [PSCustomObject]@{}
                foreach ($mGEventProperty in $MGEventProperties)
                {
                    switch ($mGEventProperty)
                    {
                        {$_ -eq 'Start' -or $_ -eq 'End'}
                        {
                            $GraphTimeZone = $SystemTimeZones | Where-Object -Property Id -EQ $($existingUserEventFromExchange.($mGEventProperty).TimeZone)
                            # Convert to UTC DateTime string
                            $GraphValue = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeToUtc(($existingUserEventFromExchange.($mGEventProperty).DateTime), $GraphTimeZone)) -Format 'o'
                        }
                        Default
                        {
                            $GraphValue = $existingUserEventFromExchange.($mGEventProperty)
                        }
                    }
                    $NewPSObjectProperty = [PSNoteProperty]::new($mGEventProperty, $GraphValue)
                    $UserEventObject.psobject.Properties.Add($NewPSObjectProperty)
                }
                $ExistingUserEvents.Add($UserEventObject)
            }
            $ExistingUserEventsCount = $ExistingUserEvents.Count
            if ($LoggingEnabled -and $LogDebugInfo) {Write-PSFMessage -Level Debug -Message "Existing Exchange Events for $($user.email) [$ExistingUserEventsCount]: $(@($ExistingUserEvents.Subject) -join '; ')"}

            # Sort existing Exchange events into the ones to remove (no longer in the SIS) and the ones to keep.
            # Start with all SIS meetings and filter down.
            # Nothing is changed in this pass: the full set of removals for this user has to be known before
            # anything is created or removed, so that the deletion safety check below sees the whole picture
            # first. If replacement events were created before the check ran, the events they replace would
            # already be duplicated by the time the check held their removal back - and those replacements
            # would also dilute the removal percentage on every later run, which at some settings would leave
            # the old/new duplicates in place permanently.
            if ($LoggingEnabled) {Write-PSFMessage -Level Significant "User $UserIndex of $UsersCount | Processing [$ExistingUserEventsCount] Existing Calendar Events for User: $($user.display) [$($user.id)] [$($user.email)]"}
            $EventsToDelete = [System.Collections.Generic.List[Object]]::new()
            $EventsToUpdate = [System.Collections.Generic.List[Object]]::new()
            $ExchangeEventIndex = 0
            foreach ($existingUserEvent in $ExistingUserEvents)
            {
                $ExchangeEventIndex++
                # NOTE: Keep activity message short or the end can get cut off when displaying (on PS Core).
                Write-Progress -Activity "[$UserIndex/$UsersCount $($user.email)] | Exchange Event $($ExchangeEventIndex) of $($ExistingUserEventsCount)" -PercentComplete (($ExchangeEventIndex / $ExistingUserEventsCount) * 100)

                $ExistingEventMatchResults = $UserMeetings
                $ExistingEventMatchCount = $ExistingEventMatchResults.Count
                foreach ($fieldToMatch in $FieldsToMatch)
                {
                    # Filter Down (if necessary)
                    if ($ExistingEventMatchCount -eq 0)
                    {
                        break # Leave the foreach loop since we no longer need to check.
                    }
                    $ExistingEventMatchResults = $ExistingEventMatchResults | Where-Object {$_.($fieldToMatch.SKYAPI) -eq $existingUserEvent.($fieldToMatch.Graph)}
                    $ExistingEventMatchCount = $ExistingEventMatchResults.Count
                }

                if ($ExistingEventMatchCount -eq 0)
                {
                    $EventsToDelete.Add($existingUserEvent)
                }
                else
                {
                    $EventsToUpdate.Add($existingUserEvent)
                }
            }
            Write-Progress -Completed -Activity 'Completed'

            # DELETION SAFETY: Don't clear out a user's calendar because of a partial or bad SIS result.
            # Removing a large share of a user's synced events at once is far more likely to mean their SIS data
            # came back incomplete (a dropped roster, a section moved to another term) than that their whole
            # schedule really disappeared. When the queued removals exceed the configured limit, hold back this
            # user's removals AND creations (creating the replacement events while the events they replace are
            # held back would leave old/new duplicates behind), warn, and carry on with the rest of the users.
            # Preference updates are still applied either way. 'MinDeletesBeforeCheck' keeps the percentage from
            # tripping on calendars with only a few events, and the check is waived entirely when
            # 'AllowEmptySourceSync' let an empty SIS result through (see $DeleteGuardBypassed above).
            if ((-not $DeleteGuardBypassed) -and ($EventsToDelete.Count -ge $MinDeletesBeforeCheck) -and ($ExistingUserEventsCount -gt 0) -and
                ((($EventsToDelete.Count / $ExistingUserEventsCount) * 100) -gt $MaxDeletePercentPerUser))
            {
                $UserDeleteGuardTripped = $true
                $NewMessage = "WARNING: Holding back all event creations & removals for user [$($user.id) - $($user.display)] [$($user.email)] because removing [$($EventsToDelete.Count)] of [$ExistingUserEventsCount] synced calendar events would exceed the configured deletion limit of $MaxDeletePercentPerUser%. Preference updates are still applied. Verify the user's SIS schedule is complete, then re-run (or raise 'DeleteSafety.MaxDeletePercentPerUser'; a value of 100 allows even a full clear)."
                if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage} else {Write-Warning $NewMessage}
                if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
            }
            else
            {
                # Create Categories in Outlook, if necessary.
                $UserCourses = $UserMeetings.course_title | Sort-Object -Unique
                $ExistingUserCategories = @(Get-MgUserOutlookMasterCategory -UserId $EntraUser.Id -All)
                foreach ($userCourse in $UserCourses)
                {
                    if ($userCourse -notin $ExistingUserCategories.DisplayName)
                    {
                        $NextUserCategoryColor = Get-NextOutlookCategoryColor -UserId $EntraUser.Id

                        if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Creating Exchange Category for $($user.display) [$($user.id)] [$($user.email)]: $($userCourse) ($($NextUserCategoryColor.Color)::$($NextUserCategoryColor.DisplayName))"}
                        $NewOutlookCategoryResponse = New-MgUserOutlookMasterCategory -UserId $EntraUser.Id -DisplayName $userCourse -Color $NextUserCategoryColor.Color
                    }
                }

                # Process Meetings From SIS
                if ($LoggingEnabled) {Write-PSFMessage -Level Significant "User $UserIndex of $UsersCount | Processing [$UserMeetingsCount] SIS Meetings for User: $($user.display) [$($user.id)] [$($user.email)]"}
                $UserMeetingIndex = 0
                foreach ($userMeeting in $UserMeetings)
                {
                    $UserMeetingIndex++
                    # NOTE: Keep activity message short or the end can get cut off when displaying (on PS Core).
                    Write-Progress -Activity "[$UserIndex/$UsersCount $($user.email)] | SIS Meeting $($UserMeetingIndex) of $($UserMeetingsCount)" -PercentComplete (($UserMeetingIndex / $UserMeetingsCount) * 100)

                    # Create the event, if needed.
                    # Start with all Exchange events and filter down.
                    $ExistingEventMatchResults = $ExistingUserEvents
                    $ExistingEventMatchCount = $ExistingEventMatchResults.Count
                    foreach ($fieldToMatch in $FieldsToMatch)
                    {
                        # Filter Down (if necessary)
                        if ($ExistingEventMatchCount -eq 0)
                        {
                            break # Leave the foreach loop since we no longer need to check.
                        }
                        $ExistingEventMatchResults = $ExistingEventMatchResults | Where-Object {$_.($fieldToMatch.Graph) -eq $userMeeting.($fieldToMatch.SKYAPI)}
                        $ExistingEventMatchCount = $ExistingEventMatchResults.Count
                    }

                    # We should rarely see duplicates (unless someone manually modified an event), but adding this in to output and log when it happens.
                    if ($ExistingEventMatchCount -gt 1)
                    {
                        $NewMessage = "<c='em'>INFO: Skipping processing the following event because it exists [$ExistingEventMatchCount] times on the user's Exchange Calendar (it is possible the user manually modified the event): $($user.display) [$($user.id)] [$($user.email)] > $($userMeeting.group_name) ($($userMeeting.start_time) to $($userMeeting.end_time))</c>"
                        if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message $NewMessage}
                        continue # Skip further work on this event.
                    }

                    if ($ExistingEventMatchCount -eq 0)
                    {
                        # Collect Meeting Data
                        $Event_Subject = $userMeeting.group_name
                        $Event_Start = ConvertTo-GraphDateTimeTimeZone -DateTime ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date -Date ($userMeeting.start_time)), $SchoolTimeZone.Id)) -TimeZone $SchoolTimeZone
                        $Event_End = ConvertTo-GraphDateTimeTimeZone -DateTime ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date -Date ($userMeeting.end_time)), $SchoolTimeZone.Id)) -TimeZone $SchoolTimeZone
                        $Event_Location = @{
                            displayName = $userMeeting.room_name
                        }
                        [string[]]$Categories = @($userMeeting.course_title) # Set Categories (array of strings)

                        # Link the user to their section: teachers get the faculty Roster, students get the student
                        # Bulletin Board. For our offering types teachers and students never overlap, so a user is a
                        # teacher of this section exactly when they're in its 'teachers' list; that single check picks
                        # both the app (faculty vs student) and the destination (roster vs bulletin board). The only
                        # difference between the faculty and student URLs is the '/app/faculty' vs '/app/student' segment.
                        $UserIsTeacher = ([string]$user.id -in ($userMeeting.teachers.id | ForEach-Object {[string]$_}))
                        $LinkApp = if ($UserIsTeacher) { 'faculty' } else { 'student' }
                        $SectionId = $userMeeting.section_id
                        $SectionPath = switch ($userMeeting.offering_type.description)
                        {
                            'Academics'  { if ($UserIsTeacher) { "academicclass/$SectionId/0/roster" } else { "academicclass/$SectionId/0/bulletinboard" } }
                            'Activities' { if ($UserIsTeacher) { "activitypage/$SectionId/roster" }     else { "activitypage/$SectionId/bulletinboard" } }
                            'Advisory'   { if ($UserIsTeacher) { "advisorypage/$SectionId/advisees" }   else { "advisorypage/$SectionId/bulletinboard" } }
                            'Athletics'  { if ($UserIsTeacher) { "athleticteam/$SectionId/roster" }      else { "athleticteam/$SectionId/teampage" } }
                            Default      { if ($UserIsTeacher) { "academicclass/$SectionId/0/roster" } else { "academicclass/$SectionId/0/bulletinboard" } }
                        }
                        $SectionLinkURL = "https://$MySchoolAppDomain/app/${LinkApp}?svcid=edu#$SectionPath"
                        $SectionLinkText = if ($UserIsTeacher) { 'Click Here For Roster' } else { 'Click Here For The Bulletin Board' }
                        $Event_Body = @{
                            contentType = "HTML"
                            content = "<b>Teachers:</b> $(($userMeeting.teachers | Sort-Object -Property head -Descending).name -join '; ')<br><br><a href=""$SectionLinkURL"">$SectionLinkText</a>"
                        }

                        # These key names are sent to Microsoft Graph as the request body, so they have to be spelled
                        # the way Graph documents them (see the event resource link above). Don't capitalize them to
                        # match the '-ShowAs'/'-IsReminderOn' style parameters used on Update-MgUserEvent below; those
                        # are PowerShell SDK parameter names, which the SDK converts on its own.
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
                        if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Creating Exchange Calendar Event: $($user.display) [$($user.id)] [$($user.email)] > $($userMeeting.group_name) ($($userMeeting.start_time) to $($userMeeting.end_time))"}
                        $NewEventResponse = New-MgUserEvent -UserId $EntraUser.Id -BodyParameter $UserEventParameters
                        $UserEventsCreated++
                    }
                }
                Write-Progress -Completed -Activity 'Completed'

                # Remove extra Exchange events.
                $ExchangeEventIndex = 0
                foreach ($eventToDelete in $EventsToDelete)
                {
                    $ExchangeEventIndex++
                    # NOTE: Keep activity message short or the end can get cut off when displaying (on PS Core).
                    Write-Progress -Activity "[$UserIndex/$UsersCount $($user.email)] | Removing Event $($ExchangeEventIndex) of $($EventsToDelete.Count)" -PercentComplete (($ExchangeEventIndex / $EventsToDelete.Count) * 100)

                    if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Removing Extra Calendar Event: $($user.display) [$($user.id)] [$($user.email)] > $($eventToDelete.Subject) ($($eventToDelete.Start) to $($eventToDelete.End))"}
                    # Catch 'Status: 404 (NotFound)' errors and ignore. This might happen if an event was already removed between the events pull and this part of script.
                    try
                    {
                        $RemoveEventResponse = Remove-MgUserEvent -UserId $EntraUser.Id -EventId $eventToDelete.Id -Confirm:$false
                        $UserEventsDeleted++
                    }
                    catch
                    {
                        if (-not ($_.Exception.Message -match 'ErrorItemNotFound')) { throw $_  }
                    }
                }
                Write-Progress -Completed -Activity 'Completed'
            }

            # Update still active existing events, if necessary.
            foreach ($existingUserEvent in $EventsToUpdate)
            {
                $ExistingEventUpdated = $false
                foreach ($userPreferenceToVerify in $UserPreferencesToVerify)
                {
                    switch ($userPreferenceToVerify)
                    {
                        ShowAs
                        {
                            if ($existingUserEvent.ShowAs -ine $ShowAs)
                            {
                                if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Updating Calendar Event for user $($user.display) [$($user.id)] [$($user.email)] > $($existingUserEvent.Subject) ($($existingUserEvent.Start) to $($existingUserEvent.End)) > ShowAs from '$($existingUserEvent.ShowAs)' to '$ShowAs'"}
                                $UpdateEventResponse = Update-MgUserEvent -UserId $EntraUser.Id -EventId $existingUserEvent.Id -ShowAs $ShowAs
                                # Count the event as updated at the FIRST successful update call: if a later
                                # property update for the same event fails, the tally & history still reflect
                                # that this event was modified.
                                if (-not $ExistingEventUpdated) { $UserEventsUpdated++; $ExistingEventUpdated = $true }
                            }
                        }
                        IsReminderOn
                        {
                            if ($existingUserEvent.IsReminderOn -ine $IsReminderOn)
                            {
                                if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Updating Calendar Event for user $($user.display) [$($user.id)] [$($user.email)] > $($existingUserEvent.Subject) ($($existingUserEvent.Start) to $($existingUserEvent.End)) > IsReminderOn from '$($existingUserEvent.IsReminderOn)' to '$IsReminderOn'"}
                                $UpdateEventResponse = Update-MgUserEvent -UserId $EntraUser.Id -EventId $existingUserEvent.Id -IsReminderOn:$IsReminderOn
                                if (-not $ExistingEventUpdated) { $UserEventsUpdated++; $ExistingEventUpdated = $true }
                            }
                        }
                        ReminderMinutesBeforeStart
                        {
                            if ($existingUserEvent.ReminderMinutesBeforeStart -ine $ReminderMinutesBeforeStart)
                            {
                                if ($LoggingEnabled) {Write-PSFMessage -Level Significant -Message "Updating Calendar Event for user $($user.display) [$($user.id)] [$($user.email)] > $($existingUserEvent.Subject) ($($existingUserEvent.Start) to $($existingUserEvent.End)) > ReminderMinutesBeforeStart from '$($existingUserEvent.ReminderMinutesBeforeStart)' to '$ReminderMinutesBeforeStart'"}
                                $UpdateEventResponse = Update-MgUserEvent -UserId $EntraUser.Id -EventId $existingUserEvent.Id -ReminderMinutesBeforeStart $ReminderMinutesBeforeStart
                                if (-not $ExistingEventUpdated) { $UserEventsUpdated++; $ExistingEventUpdated = $true }
                            }
                        }
                        Default {} # Do Nothing
                    }
                }
            }

            # Roll this user's results into the run totals and record what actually happened for them.
            $RunCounters.UsersProcessed++
            $RunCounters.EventsCreated += $UserEventsCreated
            $RunCounters.EventsUpdated += $UserEventsUpdated
            $RunCounters.EventsDeleted += $UserEventsDeleted
            if ($UserDeleteGuardTripped) { $RunCounters.DeleteGuardTrips++ }
            Write-UserSyncHistory -Path $SaveUsersSyncHistoryPath -User $user -MeetingsCount $UserMeetingsCount `
                -Created $UserEventsCreated -Updated $UserEventsUpdated -Deleted $UserEventsDeleted `
                -Status $(if ($UserDeleteGuardTripped) {'DeleteGuardTripped'} else {'Success'})
        }
        catch
        {
            $NewMessage = "WARNING: Skipping user [$($user.id) - $($user.display)] [$($user.email)] due to an error during their sync (Line: $($_.InvocationInfo.ScriptLineNumber)): $_"
            if ($LoggingEnabled) {Write-PSFMessage -Level Warning -Message $NewMessage -ErrorRecord $_} else {Write-Warning $NewMessage}
            if ($EmailonWarning) { $CustomWarningMessage += "`n$NewMessage" }
            Write-Progress -Completed -Activity 'Completed'

            # Record the partial work this user received before the failure so the history isn't silently missing them.
            $RunCounters.UsersFailed++
            $RunCounters.EventsCreated += $UserEventsCreated
            $RunCounters.EventsUpdated += $UserEventsUpdated
            $RunCounters.EventsDeleted += $UserEventsDeleted
            if ($UserDeleteGuardTripped) { $RunCounters.DeleteGuardTrips++ }
            Write-UserSyncHistory -Path $SaveUsersSyncHistoryPath -User $user -MeetingsCount $UserMeetingsCount `
                -Created $UserEventsCreated -Updated $UserEventsUpdated -Deleted $UserEventsDeleted -Status 'Failed'
            continue
        }
    }

    # Disconnect from Microsoft Graph API, if enabled in config.
    if ($MgDisconnectWhenDone)
    {
        if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Disconnecting From Microsoft Graph."}
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
    }

    # Summarize what the run did. Done before the alert email so the totals can be included in it.
    # Skipped users count as a warning outcome too: every user in the configured roles was asked for, so a
    # scheduled task watching the exit code should notice when some of them silently received no sync.
    $RunOutcome = if (($RunCounters.UsersFailed -gt 0) -or ($RunCounters.UsersSkipped -gt 0) -or ($RunCounters.DeleteGuardTrips -gt 0)) {'Completed With Warnings'} else {'Success'}
    $RunSummaryText = Write-RunSummary -Outcome $RunOutcome -Counters $RunCounters -LoggingEnabled $LoggingEnabled

    # Email Warning Message, if enabled in config.
    If ($EmailonWarning -and -not [string]::IsNullOrEmpty($CustomWarningMessage))
    {
        # Get Rid of Extra Line at Beginning
        $CustomWarningMessage = $CustomWarningMessage.Trim()

        try
        {
            # Set ScriptMessage Config Path
            Set-ScriptMessageConfigFilePath -Path $ScriptMessageConfigFilePath

            # Add More Email Attributes
            $MessageArguments.Subject = "Sync Schedules to Exchange Calendar - Warning"
            $MessageArguments.Body = "The Sync Schedules to Exchange Calendar script has detected at least one non-critical issue:`n`n$CustomWarningMessage`n`n$RunSummaryText`n`nThank you,`nThe IT Team"
            $MessageArguments.Attachment = $null # No attachments because we don't want anything to accidentally prevent the alert email from being sent.

            # Send Warning Message Alert
            $SendEmailMessageResult = Send-ScriptMessage @MessageArguments
            if ($null -eq $SendEmailMessageResult.Error -or $SendEmailMessageResult.Error -eq "")
            {
                if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Email Alert (Script Warning) sent successfully to: $($SendEmailMessageResult.Recipients.All)"}
            }
            else
            {
                if ($LoggingEnabled) {Write-PSFMessage -Level Error -Message "Email Alert (Script Warning) unable to send: $($SendEmailMessageResult.Error)" -Tag 'Failure' -ErrorRecord $_}
            }
        }
        catch
        {
            if ($LoggingEnabled) {Write-PSFMessage -Level Error -Message "There has been an error emailing the Script Warning alert message: $_" -Tag 'Failure' -ErrorRecord $_}
        }
    }

    # End Logging Message
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "---SCRIPT END---"}
    if ($LoggingEnabled) {Wait-PSFMessage} # Make Sure Logging Is Flushed Before Terminating

    # Report the outcome to whatever started the script (see the exit code list in the README).
    if ($RunOutcome -eq 'Success') { exit 0 } else { exit 2 }
}
catch
{
    # Log Error Message
    if ($LoggingEnabled) {Write-PSFMessage -Level Error -Message "Error Running Script (Name: `"$($_.InvocationInfo.ScriptName)`" | Line: $($_.InvocationInfo.ScriptLineNumber))" -Tag 'Failure' -ErrorRecord $_}
    $ScriptError = $_ # Kept because $_ refers to something else inside the alert email handling below.
    $RunSummaryText = Write-RunSummary -Outcome 'Failed' -Counters $RunCounters -LoggingEnabled $LoggingEnabled -Detail "$ScriptError"

    # Disconnect from Microsoft Graph API, if enabled in config.
    if ($MgDisconnectWhenDone)
    {
        if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Disconnecting From Microsoft Graph."}
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
            $MessageArguments.Subject = "SIS Schedules Sync - Error"
            $MessageArguments.Body = "There has been an error running the SIS Schedules Sync Script (Name: `"$($ScriptError.InvocationInfo.ScriptName)`" | Line: $($ScriptError.InvocationInfo.ScriptLineNumber)):`n`n$ScriptError`n`n$RunSummaryText`n`nThank you,`nThe IT Team"
            $MessageArguments.Attachment = $null # No attachments because we don't want anything to accidentally prevent the alert email from being sent.

            # Send Error Message Alert
            $SendEmailMessageResult = Send-ScriptMessage @MessageArguments
            if ($null -eq $SendEmailMessageResult.Error -or $SendEmailMessageResult.Error -eq "")
            {
                if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "Email Alert (Script Error) sent successfully to: $($SendEmailMessageResult.Recipients.All)"}
            }
            else
            {
                if ($LoggingEnabled) {Write-PSFMessage -Level Error -Message "Email Alert (Script Error) unable to send: $($SendEmailMessageResult.Error)" -Tag 'Failure' -ErrorRecord $_}
            }
        }
        catch
        {
            if ($LoggingEnabled) {Write-PSFMessage -Level Error -Message "There has been an error emailing the Script Error alert message: $_" -Tag 'Failure' -ErrorRecord $_}
        }
    }

    # End Logging Message
    if ($LoggingEnabled) {Write-PSFMessage -Level Important -Message "---SCRIPT END---"}
    if ($LoggingEnabled) {Wait-PSFMessage} # Make Sure Logging Is Flushed Before Terminating

    # Report the failure to whatever started the script (see the exit code list in the README).
    exit 1
}
finally
{
    # Let the next run have the single-instance lock.
    if ($SingleInstanceMutexAcquired) { $SingleInstanceMutex.ReleaseMutex() }
    $SingleInstanceMutex.Dispose()
}
