############
# OVERVIEW #
############

# Creates importable ICS Calendar schedules for faculty from the Blackbaud School Environment.
# Outputs ICS files, one for each teacher.
# Teachers can manually import as needed. Throw them in a shared folder or somewhere else for easy access.

#################
# PREREQUISITES #
#################

# SKYAPI PowerShell Module (https://github.com/Sekers/SKYAPI)
# Create a Blackbaud app registration to enable API access. See the SKYAPI PowerShell Module Wiki for more information.

#####################
# SET CONFIG VALUES #
#####################

# Set Blackbaud SKY API Module Paths
$SKYAPIConfigFilePath = "$PSScriptRoot\sky_api_config.json" # The location where you placed your Blackbaud SKY API configuration file.
$SKYAPITokensFilePath = "$env:USERPROFILE\API_Tokens\SKYAPI_TeacherSchedules_sky_api_key.json" # The location where you want the access and refresh tokens to be stored.

# Set Destination Folder for ICS Files
$DestinationFolder = "$([Environment]::GetFolderPath("Desktop"))\Faculty Calendar ICS Files"

# Set Meeting Search Parameters
$StartDate = '2024-08-29' # Format as YYYY-MM-DD.
$EndDate = '2025-01-17' # Format as YYYY-MM-DD.
$OfferingTypes = '1,3' # Defaults to 1 (Academics) if not specified. Use 'Get-SchoolOfferingType' to get a list of offering types.

# Set Event Properties
$TimeTransparency = 'OPAQUE' # 'OPAQUE', 'TRANSPARENT'
$Classification = 'PUBLIC' # 'PRIVATE', 'PUBLIC', 'CONFIDENTIAL'
$Reminder = 15 # In minutes; can be $null.

# Create Static ICN Values
$icsBeginString = @"
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//GrimAdmin/SIStoICS//NONSGML v1.0//EN
"@

$icsEndString = 'END:VCALENDAR'

#################################
# DO NOT MODIFY BELOW THIS LINE #
#################################

Import-Module SKYAPI

Set-SKYAPIConfigFilePath -Path $SKYAPIConfigFilePath
Set-SKYAPITokensFilePath -Path $SKYAPITokensFilePath

function Test-Write {
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

# Connect to the SKY API
Connect-SKYAPI

# Set ICS Date Format
$icsDateFormat = "yyyyMMddTHHmmssZ"

# Create Destination Folder (In Case It Doesn't Already Exist)
$null = New-Item -ItemType Directory -Path $DestinationFolder -Force
# Verify Write Access to Destination Folder
if (!(Test-Write -Path $DestinationFolder))
{
    Write-Error 'You do not have create & write access to this folder.' -ErrorAction Stop
}

# Get Meetings
$HashArguments = @{
    start_date = $StartDate
    end_date = $EndDate
    offering_types = $OfferingTypes
}
$Meetings = Get-SchoolScheduleMeeting @HashArguments

[array]$Teachers = foreach ($meeting in $Meetings)
{
    [PSCustomObject]@{faculty_user_id = $meeting.faculty_user_id; faculty_name = $meeting.faculty_name}
}

$Teachers = $Teachers | Sort-Object -Property faculty_name -Unique

# Create Events ICS for Each Returned Teacher
# RFC: https://www.ietf.org/rfc/rfc2445.txt
foreach ($teacher in $Teachers)
{
    $TeacherMeetings = $Meetings | Where-Object -Property 'faculty_user_id' -eq $teacher.faculty_user_id | Sort-Object -Property start_time, group_name

    $TeacherEvents = foreach ($teacherMeeting in $TeacherMeetings)
    {
        $Alarm = if($Reminder)
        {            
"BEGIN:VALARM
TRIGGER:-PT{0}M
ACTION:DISPLAY
DESCRIPTION:$($teacherMeeting.group_name)
END:VALARM" -f $Reminder
        }
        else {$null}

        [PSCustomObject]@{
            "UID" = [guid]::NewGuid()
            "DTSTAMP" = [datetime]::Now.ToUniversalTime().ToString($icsDateFormat)
            "CREATED" = Get-Date $teacherMeeting.created_date -Format $icsDateFormat
            "LAST-MODIFIED" = Get-Date $teacherMeeting.modified_date -Format $icsDateFormat
            "SEQUENCE" = 0
            "SUMMARY" = $teacherMeeting.group_name
            "DESCRIPTION" = "Teachers: $(($teacherMeeting.teachers | Sort-Object -Property head -Descending).name -join '; ')"
            "DTSTART" = Get-Date $teacherMeeting.start_time -Format $icsDateFormat
            "DTEND" = Get-Date $teacherMeeting.end_time -Format $icsDateFormat
            "LOCATION" = $teacherMeeting.room_name
            "TRANSP" = $TimeTransparency
            "CLASS" = $Classification
            "VALARM" = $Alarm
        }
    }

    # Gather ICS File Contents 
    $icsEvents = foreach ($teacherEvent in $TeacherEvents)
    {
        Write-Output -InputObject 'BEGIN:VEVENT'
        foreach ($teacherEventProperty in ($teacherEvent.PsObject.Properties))
        {
            if ($teacherEventProperty.Name -ne 'VALARM')
            {
                Write-Output -InputObject "$($teacherEventProperty.Name):$($teacherEvent.$($teacherEventProperty.Name))"
            }
            else
            {
                Write-Output -InputObject "$($teacherEvent.$($teacherEventProperty.Name))"
            }   
        }
        Write-Output -InputObject 'END:VEVENT'
    }

    $OutputICSFileContents = @($icsBeginString, $icsEvents, $icsEndString) | Out-String

    # Create ICS File
    $OutputICSFilePath = $DestinationFolder + "\" + $($teacher.faculty_name) + ".ics" 
    Write-Host -Object "Exporting: $($teacher.faculty_name).ics"
    $OutputICSFileContents | Out-String | ForEach-Object {[Text.Encoding]::UTF8.GetBytes($_)} | Set-Content -Encoding Byte -Path $OutputICSFilePath
}
