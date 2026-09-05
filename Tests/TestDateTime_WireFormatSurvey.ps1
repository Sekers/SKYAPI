# TestRequires: Live
#
# Surveys how each endpoint expresses date and time values ON THE WIRE, using -ReturnRaw so nothing has been
# deserialized yet. Read the results into Research_Notes/DateTime-Handling.md.
#
# This makes NO assumption that endpoints are consistent with one another. They are not: the same user's birth
# date comes back as "...T00:00:00+00:00" from Get-SchoolUser and "...T00:00:00-05:00" from
# Get-SchoolUserExtended. Re-run this after any Blackbaud change, or before adding date handling to a new
# endpoint.
#
# WHAT THIS INSTRUMENT ANSWERS, AND WHAT IT DOES NOT. It answers "which fields arrive, carrying which bytes",
# and for that it is the highest authority available; nothing outranks a live call. It does NOT answer "is this
# field a calendar date or a real instant". The wire is actively misleading about that: occupation dates arrive
# with a real 05:00 clock reading and mean midnight, while a timestamp whose milliseconds are exactly zero
# arrives at midnight and means an instant. The 'midnight' / 'has time' classification below is therefore a
# description of the bytes, never of the meaning. See the evidence hierarchy in
# Research_Notes/DateTime-Handling.md before acting on anything printed here.
#
# EVERY ENDPOINT REPORTS ONE OF FOUR STATES, and the distinction is the point: an endpoint that errored or
# returned nothing has NOT been measured, and must never be read as one that carries no dates. Conflating those
# is how Get-SchoolStudentEnrollment stayed absent from the notes while sitting in this list.
#
# LIVE CALLS: read-only, but it does hit the API. Point it at a test tenant.

param(
    # Any user id on the tenant that has dates populated (birth date, passport/visa, in-state, occupations).
    # Leave at 0 to discover a student that actually has data, which is what makes this runnable against a
    # tenant other than the one the default id belongs to.
    [int]$User_ID = 0,

    # Defaults match the layout of this repo; override for a different setup.
    [string]$ConfigPath = [System.IO.Path]::Combine($PSScriptRoot, '..', '@Local Only', 'sky_api_config.json'),
    [string]$TokensPath = [System.IO.Path]::Combine($env:USERPROFILE, 'API_Tokens', 'SKYAPI_Development_sky_api_key.json')
)

# Stop on error so a non-terminating failure inside an endpoint call cannot look like an empty response. Every
# call below is individually wrapped, so nothing here aborts the run.
$ErrorActionPreference = 'Stop'

# Normalize the '..' segments away rather than handing them to the provider, which resolves them against the
# caller's current location and not against the script. This decides which tenant's credentials get loaded, so
# it is worth being exact about.
$ModuleManifest = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1'))
$ConfigPath     = [System.IO.Path]::GetFullPath($ConfigPath)
$TokensPath     = [System.IO.Path]::GetFullPath($TokensPath)
foreach ($p in $ModuleManifest, $ConfigPath, $TokensPath)
{
    if (-not (Test-Path -LiteralPath $p)) { throw "required path not found: $p" }
}

Import-Module $ModuleManifest -Force
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting.' }

"CONFIG           : $ConfigPath"
"TOKENS           : $TokensPath"
Set-SKYAPIConfigFilePath -Path $ConfigPath
Set-SKYAPITokensFilePath -Path $TokensPath
Connect-SKYAPI | Out-Null

$SchoolTz = Get-SchoolTimeZone
"SCHOOL TIME ZONE : $($SchoolTz.timezone_name)  utc_offset=$($SchoolTz.utc_offset)  dst=$($SchoolTz.is_daylight_savings_time)"
"CLIENT TIME ZONE : $([System.TimeZoneInfo]::Local.Id)"
''

# ---------------------------------------------------------------------------------------------------------
# Test context.
#
# Hardcoding ids ties the survey to one tenant. A wrong id is indistinguishable from an endpoint with no data,
# which is exactly the failure this script now exists to expose, so ids are discovered and the results printed.
# ---------------------------------------------------------------------------------------------------------
$Ctx = [ordered]@{}
$CtxWhy = [ordered]@{}

function Set-Ctx
{
    param([string]$Key, [scriptblock]$Discover)

    if ($Ctx[$Key]) { return }
    try
    {
        $Value = & $Discover
        if ($Value) { $Ctx[$Key] = $Value; $CtxWhy[$Key] = 'discovered' }
        else { $Ctx[$Key] = $null; $CtxWhy[$Key] = 'nothing found on this tenant' }
    }
    catch
    {
        $Ctx[$Key] = $null
        $CtxWhy[$Key] = "discovery failed: $($_.Exception.Message)"
    }
}

# A context value that could not be discovered must make its endpoints report ERROR, not vanish from the run.
function Get-Ctx
{
    param([string]$Key)

    if (-not $Ctx[$Key]) { throw "test context '$Key' unavailable ($($CtxWhy[$Key]))" }
    $Ctx[$Key]
}

$Roles = @()
try { $Roles = @(Get-SchoolRole) } catch { }
$StudentRoleId = ($Roles | Where-Object { $_.name -eq 'Student' }   | Select-Object -First 1).id
$TeacherRoleId = ($Roles | Where-Object { $_.name -eq 'Teacher' }   | Select-Object -First 1).id

# The user id drives five endpoints. Probe for one that actually returns enrollments rather than trusting that
# any given student has them; an arbitrary student very often does not.
Set-Ctx User_ID {
    if ($User_ID) { return $User_ID }
    if (-not $StudentRoleId) { throw 'no role named Student' }
    $Students = @(Get-SchoolUserByRole -roles "$StudentRoleId" -ResponseLimit 25)
    foreach ($s in $Students)
    {
        try { if (@(Get-SchoolStudentEnrollment -User_ID $s.id)) { return $s.id } } catch { }
    }
    ($Students | Select-Object -First 1).id   # fall back to any student; endpoints will report EMPTY honestly
}

Set-Ctx Role_ID    { if ($StudentRoleId) { $StudentRoleId } else { ($Roles | Select-Object -First 1).id } }
Set-Ctx Teacher_ID { if (-not $TeacherRoleId) { throw 'no role named Teacher' }
                     (@(Get-SchoolUserByRole -roles "$TeacherRoleId" -ResponseLimit 5) | Select-Object -First 1).id }
Set-Ctx Level_ID   { (@(Get-SchoolLevel) | Select-Object -First 1).id }
Set-Ctx Section_ID { (@(Get-SchoolAcademicSectionBySchoolLevel -Level_Number (Get-Ctx Level_ID)) | Select-Object -First 1).id }

# A window recent enough to hold data and short enough to stay cheap. Get-SchoolUserAuditByRole rejects a range
# wider than a year (notes section 8), so this stays well inside it.
$Ctx.Start_Date = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
$Ctx.End_Date   = (Get-Date).ToString('yyyy-MM-dd')
$CtxWhy.Start_Date = 'computed'; $CtxWhy.End_Date = 'computed'

'TEST CONTEXT'
foreach ($k in $Ctx.Keys)
{
    '  {0,-12} {1,-12} {2}' -f $k, $(if ($null -ne $Ctx[$k]) { $Ctx[$k] } else { '(none)' }), $CtxWhy[$k]
}
''

# ---------------------------------------------------------------------------------------------------------
# Endpoints.
#
# -ReturnRaw is required, so the seven functions that do not implement it cannot appear here at all:
# Get-SchoolScheduleMeeting and the six paged functions (Get-SchoolEnrollment, Get-SchoolList,
# Get-SchoolUserByRole, Get-SchoolUserExtendedByBaseRole, Get-SchoolUserBBIDStatus,
# Get-SchoolUserCustomFieldsByBaseRole). That is a limit of the instrument, not evidence about those endpoints.
# ---------------------------------------------------------------------------------------------------------
$Calls = [ordered]@{
    'Get-SchoolYear'                 = { Get-SchoolYear -ReturnRaw }
    'Get-SchoolTerm'                 = { Get-SchoolTerm -ReturnRaw }
    'Get-SchoolSession'              = { Get-SchoolSession -ReturnRaw }
    'Get-SchoolLevel'                = { Get-SchoolLevel -ReturnRaw }
    'Get-SchoolGradeLevel'           = { Get-SchoolGradeLevel -ReturnRaw }
    'Get-SchoolRole'                 = { Get-SchoolRole -ReturnRaw }
    'Get-SchoolCourse'               = { Get-SchoolCourse -ReturnRaw }
    'Get-SchoolDepartment'           = { Get-SchoolDepartment -ReturnRaw }
    'Get-SchoolOfferingType'         = { Get-SchoolOfferingType -ReturnRaw }
    'Get-SchoolNewsItem'             = { Get-SchoolNewsItem -ReturnRaw }
    'Get-SchoolNewsCategory'         = { Get-SchoolNewsCategory -ReturnRaw }
    'Get-SchoolAdmissionCandidate'   = { Get-SchoolAdmissionCandidate -ReturnRaw }
    'Get-SchoolAdmissionStatus'      = { Get-SchoolAdmissionStatus -ReturnRaw }
    'Get-SchoolTimeZone'             = { Get-SchoolTimeZone -ReturnRaw }
    'Get-SchoolUserMe'               = { Get-SchoolUserMe -ReturnRaw }
    'Get-SchoolVenueBuilding'        = { Get-SchoolVenueBuilding -ReturnRaw }
    'Get-SchoolResourceBoard'        = { Get-SchoolResourceBoard -ReturnRaw }
    'Get-SchoolListOfLists'          = { Get-SchoolListOfLists -ReturnRaw }
    'Get-SchoolCustomField'          = { Get-SchoolCustomField -ReturnRaw }
    'Get-SchoolTypeTable'            = { Get-SchoolTypeTable -ReturnRaw }
    'Get-SchoolUserAddressType'      = { Get-SchoolUserAddressType -ReturnRaw }
    'Get-SchoolUserPhoneType'        = { Get-SchoolUserPhoneType -ReturnRaw }
    'Get-SchoolUserGenderType'       = { Get-SchoolUserGenderType -ReturnRaw }
    'Get-SchoolAthleticRoster'       = { Get-SchoolAthleticRoster -ReturnRaw }
    'Get-SchoolActivityRoster'       = { Get-SchoolActivityRoster -ReturnRaw }
    'Get-SchoolAdvisoryRoster'       = { Get-SchoolAdvisoryRoster -ReturnRaw }
    'Get-SchoolAcademicRoster'               = { Get-SchoolAcademicRoster -ReturnRaw }
    'Get-SchoolUser'                 = { Get-SchoolUser -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserExtended'         = { Get-SchoolUserExtended -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserEducation'        = { Get-SchoolUserEducation -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserEmployment'       = { Get-SchoolUserEmployment -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserOccupation'       = { Get-SchoolUserOccupation -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserPhone'            = { Get-SchoolUserPhone -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserRelationship'     = { Get-SchoolUserRelationship -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolUserAddress'          = { Get-SchoolUserAddress -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolStudentEnrollment'    = { Get-SchoolStudentEnrollment -User_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolSectionByStudent'     = { Get-SchoolSectionByStudent -Student_ID (Get-Ctx User_ID) -ReturnRaw }
    'Get-SchoolAssignmentByStudent'  = { Get-SchoolAssignmentByStudent -Student_ID (Get-Ctx User_ID) -start_date $Ctx.Start_Date -end_date $Ctx.End_Date -ReturnRaw }
    'Get-SchoolAcademicSectionBySchoolLevel' = { Get-SchoolAcademicSectionBySchoolLevel -Level_Number (Get-Ctx Level_ID) -ReturnRaw }
    'Get-SchoolActivitySectionBySchoolLevel'= { Get-SchoolActivitySectionBySchoolLevel -Level_Number (Get-Ctx Level_ID) -ReturnRaw }
    'Get-SchoolAdvisorySectionBySchoolLevel'= { Get-SchoolAdvisorySectionBySchoolLevel -Level_Number (Get-Ctx Level_ID) -ReturnRaw }
    'Get-SchoolSectionByTeacher'     = { Get-SchoolSectionByTeacher -Teacher_ID (Get-Ctx Teacher_ID) -ReturnRaw }
    'Get-SchoolAssignmentBySection'  = { Get-SchoolAssignmentBySection -Section_ID (Get-Ctx Section_ID) -ReturnRaw }
    'Get-SchoolStudentBySection'     = { Get-SchoolStudentBySection -Section_ID (Get-Ctx Section_ID) -ReturnRaw }
    'Get-SchoolCycleBySection'       = { Get-SchoolCycleBySection -Section_ID (Get-Ctx Section_ID) -ReturnRaw }
    'Get-SchoolUserAuditByRole'      = { Get-SchoolUserAuditByRole -Role_ID (Get-Ctx Role_ID) -start_date $Ctx.Start_Date -end_date $Ctx.End_Date -ReturnRaw }
}

# An endpoint that returned no items is unmeasured, which is a different thing from one that returned items
# carrying no dates. Telling them apart is the whole reason this function exists.
function Test-EmptyResponse
{
    param($Raw)

    if ($null -eq $Raw) { return $true }

    $Obj = $Raw
    if ($Raw -is [string])
    {
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $true }
        # An unparseable body is present, not empty; let the regex below decide what is in it.
        try { $Obj = $Raw | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    }

    if ($null -eq $Obj) { return $true }
    if ($Obj -isnot [string] -and $Obj -is [System.Collections.IEnumerable]) { return (@($Obj).Count -eq 0) }
    if ($Obj.PSObject.Properties['value']) { return (@($Obj.value).Count -eq 0) }
    return $false
}

$Shapes  = @{}
$Rows    = 0
$Errored  = [ordered]@{}
$Empty    = [System.Collections.Generic.List[string]]::new()
$NoDates  = [System.Collections.Generic.List[string]]::new()
$Measured = [System.Collections.Generic.List[string]]::new()

foreach ($Name in $Calls.Keys)
{
    $Raw = $null
    $Err = $null
    try { $Raw = & $Calls[$Name] } catch { $Err = $_.Exception.Message }

    if ($Err)
    {
        'ERROR      {0,-32} {1}' -f $Name, $Err
        $Errored[$Name] = $Err
        continue
    }

    if (Test-EmptyResponse $Raw)
    {
        'EMPTY      {0,-32} call succeeded, response had no items (NOT measured)' -f $Name
        $Empty.Add($Name)
        continue
    }

    $Text = if ($Raw -is [string]) { $Raw } else { $Raw | ConvertTo-Json -Depth 12 -Compress }

    $Found = [regex]::Matches($Text, '"([A-Za-z0-9_]+)"\s*:\s*"(\d{4}-\d{2}-\d{2}T[\d:.]+(?:Z|[+-]\d{2}:\d{2})?)"')
    if ($Found.Count -eq 0)
    {
        'NO DATES   {0,-32} response had items, no datetime-shaped values' -f $Name
        $NoDates.Add($Name)
        continue
    }

    $PerField = @{}
    foreach ($M in $Found)
    {
        $Field = $M.Groups[1].Value
        $Value = $M.Groups[2].Value

        # Classify by SHAPE, never by field name: the same name can carry both a date-only value and a real
        # timestamp within one payload (see Get-SchoolAthleticRoster's enroll_date). Note that shape is not
        # sufficient to decide MEANING either; see the header comment and the notes' evidence hierarchy.
        $Offset = if ($Value -match 'Z$')                { 'Z (UTC)' }
                  elseif ($Value -match '\+\d{2}:\d{2}$') { 'positive offset' }
                  elseif ($Value -match '-\d{2}:\d{2}$')  { 'negative offset' }
                  else                                    { 'NO offset (naked)' }
        $Time = if ($Value -match 'T00:00:00(\.0+)?([Z+-]|$)') { 'midnight' } else { 'has time' }
        $Key = "$Offset / $Time"

        if (-not $PerField.ContainsKey($Field)) { $PerField[$Field] = @{} }
        if (-not $PerField[$Field].ContainsKey($Key)) { $PerField[$Field][$Key] = $Value }
    }

    '{0,-32} {1} value(s), {2} field(s)' -f $Name, $Found.Count, $PerField.Keys.Count
    $Measured.Add($Name)
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
'================ SUMMARY: coverage ================'
'  measured (dates found)     : {0}' -f $Measured.Count
'  measured (no dates)        : {0}' -f $NoDates.Count
'  NOT measured (empty)       : {0}' -f $Empty.Count
'  NOT measured (error)       : {0}' -f $Errored.Count
'  endpoints attempted        : {0}' -f $Calls.Keys.Count

# Naming these is the point. An unmeasured endpoint left as a bare count is how a real gap hides in plain sight.
if ($Empty.Count)
{
    ''
    '  NOT MEASURED, empty response. These carry no evidence either way; re-run against a tenant with data:'
    foreach ($n in $Empty) { "      $n" }
}
if ($Errored.Count)
{
    ''
    '  NOT MEASURED, call failed. These carry no evidence either way:'
    foreach ($n in $Errored.Keys) { '      {0,-32} {1}' -f $n, $Errored[$n] }
}

''
if ($Rows -eq 0) { 'NO DATETIME VALUES FOUND AT ALL - the survey did not work; treat as a failure.'; exit 1 }
"Surveyed $($Calls.Keys.Count) endpoints, $($Measured.Count + $NoDates.Count) actually measured, $Rows field/shape combinations."
'Interpretation guide, and the evidence hierarchy, are in Research_Notes/DateTime-Handling.md.'
