# Surveys how each endpoint expresses date and time values ON THE WIRE, using -ReturnRaw so nothing has been
# deserialized yet. Read the results into Research_Notes/DateTime-Handling.md.
#
# This makes NO assumption that endpoints are consistent with one another. They are not: the same user's birth
# date comes back as "...T00:00:00+00:00" from Get-SchoolUser and "...T00:00:00-05:00" from
# Get-SchoolUserExtended. Re-run this after any Blackbaud change, or before adding date handling to a new
# endpoint.
#
# LIVE CALLS: read-only, but it does hit the API. Point it at a test tenant.

param(
    # Any user id on the tenant that has dates populated (birth date, passport/visa, in-state, occupations).
    [int]$User_ID = 3294459,

    # Defaults match the layout of this repo; override for a different setup.
    [string]$ConfigPath = [System.IO.Path]::Combine($PSScriptRoot, '..', '@Local Only', 'sky_api_config.json'),
    [string]$TokensPath = [System.IO.Path]::Combine($env:USERPROFILE, 'API_Tokens', 'SKYAPI_Development_sky_api_key.json')
)

$ErrorActionPreference = 'Continue'
Import-Module ([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting.' }

Set-SKYAPIConfigFilePath -Path $ConfigPath
Set-SKYAPITokensFilePath -Path $TokensPath
Connect-SKYAPI | Out-Null

$SchoolTz = Get-SchoolTimeZone
"SCHOOL TIME ZONE : $($SchoolTz.timezone_name)  utc_offset=$($SchoolTz.utc_offset)  dst=$($SchoolTz.is_daylight_savings_time)"
"CLIENT TIME ZONE : $([System.TimeZoneInfo]::Local.Id)"
"TEST USER        : $User_ID"
''

# Endpoints that support -ReturnRaw and are cheap/safe to call. Extend as needed.
$Calls = [ordered]@{
    'Get-SchoolYear'               = { Get-SchoolYear -ReturnRaw }
    'Get-SchoolTerm'               = { Get-SchoolTerm -ReturnRaw }
    'Get-SchoolSession'            = { Get-SchoolSession -ReturnRaw }
    'Get-SchoolLevel'              = { Get-SchoolLevel -ReturnRaw }
    'Get-SchoolGradeLevel'         = { Get-SchoolGradeLevel -ReturnRaw }
    'Get-SchoolRole'               = { Get-SchoolRole -ReturnRaw }
    'Get-SchoolCourse'             = { Get-SchoolCourse -ReturnRaw }
    'Get-SchoolDepartment'         = { Get-SchoolDepartment -ReturnRaw }
    'Get-SchoolOfferingType'       = { Get-SchoolOfferingType -ReturnRaw }
    'Get-SchoolNewsItem'           = { Get-SchoolNewsItem -ReturnRaw }
    'Get-SchoolAdmissionCandidate' = { Get-SchoolAdmissionCandidate -ReturnRaw }
    'Get-SchoolAdmissionStatus'    = { Get-SchoolAdmissionStatus -ReturnRaw }
    'Get-SchoolTimeZone'           = { Get-SchoolTimeZone -ReturnRaw }
    'Get-SchoolUserMe'             = { Get-SchoolUserMe -ReturnRaw }
    'Get-SchoolVenueBuilding'      = { Get-SchoolVenueBuilding -ReturnRaw }
    'Get-SchoolResourceBoard'      = { Get-SchoolResourceBoard -ReturnRaw }
    'Get-SchoolListOfLists'        = { Get-SchoolListOfLists -ReturnRaw }
    'Get-SchoolCustomField'        = { Get-SchoolCustomField -ReturnRaw }
    'Get-SchoolAthleticRoster'     = { Get-SchoolAthleticRoster -ReturnRaw }
    'Get-SchoolActivityRoster'     = { Get-SchoolActivityRoster -ReturnRaw }
    'Get-SchoolAdvisoryRoster'     = { Get-SchoolAdvisoryRoster -ReturnRaw }
    'Get-SchoolRoster'             = { Get-SchoolRoster -ReturnRaw }
    'Get-SchoolUser'               = { Get-SchoolUser -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserExtended'       = { Get-SchoolUserExtended -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserEducation'      = { Get-SchoolUserEducation -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserEmployment'     = { Get-SchoolUserEmployment -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserOccupation'     = { Get-SchoolUserOccupation -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserPhone'          = { Get-SchoolUserPhone -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserRelationship'   = { Get-SchoolUserRelationship -User_ID $User_ID -ReturnRaw }
    'Get-SchoolUserAddress'        = { Get-SchoolUserAddress -User_ID $User_ID -ReturnRaw }
    'Get-SchoolStudentEnrollment'  = { Get-SchoolStudentEnrollment -User_ID $User_ID -ReturnRaw }
}

$Shapes = @{}
$Rows = 0

foreach ($Name in $Calls.Keys)
{
    $Raw = $null
    try { $Raw = & $Calls[$Name] 2>$null } catch { }
    if (-not $Raw) { '{0,-30} (no data or error)' -f $Name; continue }
    $Text = if ($Raw -is [string]) { $Raw } else { $Raw | ConvertTo-Json -Depth 12 -Compress }

    $Found = [regex]::Matches($Text, '"([A-Za-z0-9_]+)"\s*:\s*"(\d{4}-\d{2}-\d{2}T[\d:.]+(?:Z|[+-]\d{2}:\d{2})?)"')
    if ($Found.Count -eq 0) { '{0,-30} (no datetime-shaped values)' -f $Name; continue }

    $PerField = @{}
    foreach ($M in $Found)
    {
        $Field = $M.Groups[1].Value
        $Value = $M.Groups[2].Value

        # Classify by SHAPE, never by field name: the same name can carry both a date-only value and a real
        # timestamp within one payload (see Get-SchoolAthleticRoster's enroll_date).
        $Offset = if ($Value -match 'Z$')                { 'Z (UTC)' }
                  elseif ($Value -match '\+\d{2}:\d{2}$') { 'positive offset' }
                  elseif ($Value -match '-\d{2}:\d{2}$')  { 'negative offset' }
                  else                                    { 'NO offset (naked)' }
        $Time = if ($Value -match 'T00:00:00(\.0+)?([Z+-]|$)') { 'midnight' } else { 'has time' }
        $Key = "$Offset / $Time"

        if (-not $PerField.ContainsKey($Field)) { $PerField[$Field] = @{} }
        if (-not $PerField[$Field].ContainsKey($Key)) { $PerField[$Field][$Key] = $Value }
    }

    '{0,-30} {1} value(s), {2} field(s)' -f $Name, $Found.Count, $PerField.Keys.Count
    foreach ($Field in ($PerField.Keys | Sort-Object))
    {
        foreach ($Key in $PerField[$Field].Keys)
        {
            '      {0,-22} {1,-32} e.g. {2}' -f $Field, $Key, $PerField[$Field][$Key]
            if (-not $Shapes.ContainsKey($Key)) { $Shapes[$Key] = 0 }
            $Shapes[$Key]++
            $Rows++
        }
    }
}

''
'================ SUMMARY: wire shapes observed ================'
$Shapes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    '  {0,-34} {1} field/endpoint combination(s)' -f $_.Key, $_.Value
}
''
if ($Rows -eq 0) { 'NO DATETIME VALUES FOUND AT ALL - the survey did not work; treat as a failure.'; exit 1 }
"Surveyed $($Calls.Keys.Count) endpoints, $Rows field/shape combinations."
'Interpretation guide is in Research_Notes/DateTime-Handling.md.'
