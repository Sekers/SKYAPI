############
# OVERVIEW #
############

# Creates importable Google Calendar schedules for faculty from the Blackbaud School Envirionment.
# Outputs CSV files, one for each teacher.
# Teachers can manually import as needed. Throw them in a shared Google Drive folder or somewhere else for easy access.

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

# Set Destination Folder for CSV Files
$DestinationFolder = "$([Environment]::GetFolderPath("Desktop"))\Faculty Calendar CSV Files"

# Set Meeting Parameters
$DesiredTimeZoneId = "Central Standard Time" # Specify the timezone your Google Calendars are on. Use the following cmdlet to get a list > Get-TimeZone -ListAvailable
$StartDate = '2023-01-01' # Format as YYYY-MM-DD.
$EndDate = '2023-06-30' # Format as YYYY-MM-DD.
$OfferingTypes = '1,3' # Defaults to 1 (Academics) if not specified. Use 'Get-SchoolOfferingType' to get a list of offering types.

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

# Create Events CSV for Each Returned Teacher 
foreach ($teacher in $Teachers)
{
    $TeacherMeetings = $Meetings | Where-Object -Property 'faculty_user_id' -eq $teacher.faculty_user_id | Sort-Object -Property start_time, group_name

    $csvContents = foreach ($teacherMeeting in $TeacherMeetings)
    {
        # Convert Start & End Time From UTC to Desired Time Zone
        $teacherMeeting.start_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($teacherMeeting.start_time, $DesiredTimeZoneId)
        $teacherMeeting.end_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($teacherMeeting.end_time, $DesiredTimeZoneId)

        # Headers Should Match: https://support.google.com/calendar/answer/37118
        [PSCustomObject]@{
            "Subject" = $teacherMeeting.group_name
            "Start Date" = get-date $teacherMeeting.start_time -Format "MM/dd/yyyy" 
            "End Date" = get-date $teacherMeeting.end_time -Format "MM/dd/yyyy" 
            "Start Time" = get-date $teacherMeeting.start_time -Format "h:mm tt"
            "End Time" = get-date $teacherMeeting.end_time -Format "h:mm tt"
            "Location" = $teacherMeeting.room_name
            "Private" = 'False'
        }
    }

    # Create CSV File
    $OutputCSVFile = $DestinationFolder + "\" + $($teacher.faculty_name) + ".csv" 
    $csvContents | Export-Csv -Path $OutputCSVFile -NoTypeInformation
}
