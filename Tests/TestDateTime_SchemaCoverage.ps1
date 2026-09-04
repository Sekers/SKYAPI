# Reports what each endpoint's PUBLISHED CONTRACT claims about its date fields, next to what the module
# actually does about them. Its job is to rank which endpoints are worth measuring, nothing more.
#
# THIS SCRIPT PRODUCES LEADS, NOT VERDICTS. The published schema is third-rank evidence and it is provably
# wrong about this API in two ways, both measured:
#
#   1. Silent false negatives. The four roster endpoints resolve to synthetic response models holding ZERO
#      properties, so the schema reports no date fields for them, while Research_Notes/DateTime-Handling.md
#      section 3a measured date fields on all four. A "no dates" answer is worthless whenever the model is
#      empty, which is why SCHEMA BLIND is reported separately from NO DATES DECLARED and must never be
#      merged into it.
#   2. Wrong about meaning. Every date field is declared 'date-time', including the occupation fields that
#      section 3c measured as school-midnight-expressed-as-UTC, and including enroll_date, which section 3e
#      proves arrives both as a date and as an instant inside a single payload.
#
# Only Tests/TestDateTime_WireFormatSurvey.ps1 settles what an endpoint actually sends, and only a GUI
# round-trip settles what a value means. See the evidence hierarchy in Research_Notes/DateTime-Handling.md.
#
# Needs network, but no auth, no tenant and no token file: it reads the public developer portal only.

[CmdletBinding()]
param(
    # Exit non-zero when an endpoint declares date fields, has no normalization, and has no derived reason to
    # be left alone. Off by default so the script reads as a report, matching the wire survey's behavior.
    [switch]$Strict,

    [string]$FunctionPath = [System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'Functions'),
    [string]$ModulePath   = [System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psm1')
)

$ErrorActionPreference = 'Stop'

# Normalize the '..' segments away rather than handing them to the provider, which resolves them against the
# caller's current location and not against the script. Running from inside SKYAPI/Functions is enough to send
# these paths somewhere that does not exist.
$FunctionPath = [System.IO.Path]::GetFullPath($FunctionPath)
$ModulePath   = [System.IO.Path]::GetFullPath($ModulePath)
if (-not (Test-Path -LiteralPath $FunctionPath)) { throw "function directory not found: $FunctionPath" }
if (-not (Test-Path -LiteralPath $ModulePath))   { throw "module not found: $ModulePath" }

if ($PSVersionTable.PSEdition -eq 'Desktop')
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

$ApiVersion = '2022-04-01-preview'
$OpCache    = @{}   # api slug   -> @{ operationName = operation }
$SchemaCache= @{}   # schemaId   -> components.schemas

function Get-OperationTable
{
    param([string]$Api)

    if ($OpCache.ContainsKey($Api)) { return $OpCache[$Api] }
    $Table = @{}
    try
    {
        $Url = "https://developer.sky.blackbaud.com/mapi/apis/$Api/operations?api-version=$ApiVersion&`$top=500"
        foreach ($o in (Invoke-RestMethod $Url).value) { $Table[$o.name] = $o }
    }
    catch
    {
        Write-Warning "operations list for api '$Api' failed: $($_.Exception.Message)"
    }
    $OpCache[$Api] = $Table
    $Table
}

function Get-SchemaModels
{
    param([string]$Api, [string]$SchemaId)

    # Schemas are scoped to their API. Fetching every one of them from 'school' silently 404s the four other
    # APIs this module talks to, which then look SCHEMA BLIND for a reason that has nothing to do with the API.
    $CacheKey = "$Api/$SchemaId"
    if ($SchemaCache.ContainsKey($CacheKey)) { return $SchemaCache[$CacheKey] }
    $Models = $null
    try
    {
        $Url = "https://developer.sky.blackbaud.com/mapi/apis/$Api/schemas/$SchemaId`?api-version=$ApiVersion"
        $Models = (Invoke-RestMethod $Url).properties.document.components.schemas
    }
    catch
    {
        Write-Warning "schema '$SchemaId' (api '$Api') failed: $($_.Exception.Message)"
    }
    $SchemaCache[$CacheKey] = $Models
    $Models
}

# Returns every property of a model, flattened, with nested models walked through $ref and items.$ref.
# Depth is capped because these models are mutually recursive (a section holds a teacher who holds sections).
function Get-ModelProperty
{
    param($Models, [string]$TypeName, [int]$Depth = 0, [string]$Prefix = '', $Seen = $null)

    if (-not $Models -or -not $TypeName -or $Depth -gt 3) { return @() }
    if ($null -eq $Seen) { $Seen = @{} }
    if ($Seen.ContainsKey($TypeName)) { return @() }
    $Seen[$TypeName] = $true

    $Model = $Models.PSObject.Properties[$TypeName]
    if (-not $Model) { return @() }

    $Out = @()
    foreach ($p in $Model.Value.properties.PSObject.Properties)
    {
        $Out += [pscustomobject]@{
            Path   = "$Prefix$($p.Name)"
            Leaf   = $p.Name
            Format = $p.Value.format
        }
        $Child = $p.Value.'$ref'
        if (-not $Child -and $p.Value.items) { $Child = $p.Value.items.'$ref' }
        if ($Child)
        {
            $Out += Get-ModelProperty -Models $Models -TypeName ($Child -replace '.*/','') `
                        -Depth ($Depth + 1) -Prefix "$Prefix$($p.Name)." -Seen $Seen
        }
    }
    $Seen.Remove($TypeName)
    $Out
}

# The always-instant field list is read from the module rather than copied, so this script cannot drift out of
# step with Repair-SKYAPIResponseDateTime's default.
$TimestampFields = @()
$ModuleText = Get-Content $ModulePath -Raw
$TsMatch = [regex]::Match($ModuleText, '\[string\[\]\]\$TimestampFields\s*=\s*@\(([^)]*)\)')
if ($TsMatch.Success)
{
    $TimestampFields = [regex]::Matches($TsMatch.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
}
if (-not $TimestampFields) { throw 'could not read the -TimestampFields default from the module; aborting rather than guessing' }

# Mechanism detected from source, never from a hardcoded roster, so a function that gains or loses
# normalization is reflected without editing this script.
function Get-Mechanism
{
    param([string]$Source)

    if ($Source -match 'ConvertTo-SKYAPIUtcFromSchoolLocal') { return 're-anchoring' }
    if ($Source -match 'Repair-SKYAPIResponseDateTime')      { return 'self-repair' }
    if ($Source -match 'Get-SKYAPIPagedEntity')              { return 'central paged' }
    if ($Source -match '-split\s+"T"')                       { return 'string split' }
    ''
}

$Rows = @()
foreach ($File in (Get-ChildItem -Path $FunctionPath -Filter 'Get-*.ps1' | Sort-Object Name))
{
    $Source = Get-Content $File.FullName -Raw
    $Op  = ([regex]::Match($Source, 'operation=([A-Za-z0-9_]+)')).Groups[1].Value
    if (-not $Op) { continue }   # local helpers with no endpoint, correctly skipped
    $Api = ([regex]::Match($Source, 'api=([A-Za-z0-9-]+)')).Groups[1].Value
    if (-not $Api) { $Api = 'school' }

    $Operation = (Get-OperationTable $Api)[$Op]
    $Rep = if ($Operation) { @($Operation.properties.responses.representations)[0] } else { $null }
    $Props = @()
    if ($Rep -and $Rep.schemaId) { $Props = @(Get-ModelProperty -Models (Get-SchemaModels -Api $Api -SchemaId $Rep.schemaId) -TypeName $Rep.typeName) }

    $Dates = @($Props | Where-Object { $_.Format -in 'date-time','date' })
    $Rows += [pscustomobject]@{
        Function   = $File.BaseName
        Api        = $Api
        Operation  = $Op
        Model      = if ($Rep) { $Rep.typeName } else { '' }
        Resolved   = [bool]$Operation
        PropCount  = $Props.Count
        DateFields = @($Dates.Path | Select-Object -Unique)
        DateLeaves = @($Dates.Leaf | Select-Object -Unique)
        Mechanism  = Get-Mechanism $Source
        HasRaw     = $Source -match '\$ReturnRaw'
    }
}

$Declares  = @($Rows | Where-Object { $_.Resolved -and $_.DateFields.Count -gt 0 })
$NoDates   = @($Rows | Where-Object { $_.Resolved -and $_.PropCount -gt 0 -and $_.DateFields.Count -eq 0 })
$Blind     = @($Rows | Where-Object { $_.Resolved -and $_.PropCount -eq 0 })
$Unresolved= @($Rows | Where-Object { -not $_.Resolved })

'================ DECLARES DATES ================'
'Worth measuring on the wire. Mechanism column is what the module does today.'
''
foreach ($r in ($Declares | Sort-Object { -$_.DateFields.Count }))
{
    $AllTimestamp = -not (@($r.DateLeaves | Where-Object { $TimestampFields -notcontains $_ }).Count)
    $Note = if ($r.Mechanism) { $r.Mechanism }
            elseif ($AllTimestamp) { 'none needed: every declared field is always-instant audit metadata (section 3d)' }
            else { '*** GAP: declares dates, no normalization ***' }
    '  {0,-38} {1,2} field(s)  {2}' -f $r.Function, $r.DateFields.Count, $Note
}

''
'================ SCHEMA BLIND ================'
'Model resolved but holds ZERO properties. The schema knows nothing here; a "no dates" reading would be false.'
''
if ($Blind) { foreach ($r in $Blind) { '  {0,-38} {1}' -f $r.Function, $r.Model } } else { '  (none)' }

''
'================ UNRESOLVED ================'
'Operation id not found in its API''s operation list. Also no evidence either way.'
''
if ($Unresolved) { foreach ($r in $Unresolved) { '  {0,-38} api={1} op={2}' -f $r.Function, $r.Api, $r.Operation } } else { '  (none)' }

''
'================ NO DATES DECLARED ================'
'Populated model, no date fields declared. LOW PRIORITY, NOT CLEARED: only the wire survey can clear an endpoint.'
''
'  ' + (($NoDates.Function | Sort-Object) -join "`n  ")

# ---------------------------------------------------------------------------------------------------------
# Self-calibration. The schema's known failure mode is pinned as an assertion rather than left as a footnote,
# so that if Blackbaud ever populates the roster models, or breaks a model this script depends on, the run
# says so instead of quietly changing its advice.
# ---------------------------------------------------------------------------------------------------------
''
'================ SELF-CALIBRATION ================'
'Checked against endpoints Research_Notes/DateTime-Handling.md has already measured.'
''
$CalFail = 0

# Section 3a measured date fields on all four rosters. The schema reports none. If one ever shows up under
# NO DATES DECLARED, this script is actively lying about a known date-bearing endpoint.
foreach ($n in 'Get-SchoolAthleticRoster','Get-SchoolActivityRoster','Get-SchoolAdvisoryRoster','Get-SchoolRoster')
{
    $r = $Rows | Where-Object Function -eq $n
    if (-not $r)                        { 'FAIL  {0,-38} not found at all' -f $n; $CalFail++ }
    elseif ($NoDates -contains $r)      { 'FAIL  {0,-38} reported as "no dates" but section 3a measured dates on it' -f $n; $CalFail++ }
    elseif ($Blind -contains $r)        { 'PASS  {0,-38} correctly reported SCHEMA BLIND (section 3a measured dates)' -f $n }
    elseif ($Declares -contains $r)     { 'PASS  {0,-38} schema now declares dates; the blind spot is gone, update the notes' -f $n }
}

# Endpoints whose date fields the notes measured AND the schema declares. These guard the walk itself: if the
# $ref recursion breaks, these drop to zero fields and everything downstream silently under-reports.
foreach ($n in 'Get-SchoolUserExtended','Get-SchoolYear','Get-SchoolTerm')
{
    $r = $Rows | Where-Object Function -eq $n
    if ($r -and $Declares -contains $r) { 'PASS  {0,-38} declares {1} date field(s), as measured' -f $n, $r.DateFields.Count }
    else                                { 'FAIL  {0,-38} expected declared date fields; the model walk is broken' -f $n; $CalFail++ }
}

# Nested-field guard: section 6 recorded visa/passport/in_state as nested date fields on Get-SchoolUserExtended.
$Ext = $Rows | Where-Object Function -eq 'Get-SchoolUserExtended'
if ($Ext -and @($Ext.DateFields | Where-Object { $_ -like '*.*' }).Count) { 'PASS  {0,-38} nested date fields resolved through $ref' -f 'Get-SchoolUserExtended' }
else { 'FAIL  {0,-38} no nested date fields; $ref recursion is broken' -f 'Get-SchoolUserExtended'; $CalFail++ }

''
'================ SUMMARY ================'
'  endpoints mapped        : {0}' -f $Rows.Count
'  declares dates          : {0}' -f $Declares.Count
'  no dates declared       : {0}   (unconfirmed, not cleared)' -f $NoDates.Count
'  schema blind            : {0}' -f $Blind.Count
'  unresolved              : {0}' -f $Unresolved.Count
'  not wire-surveyable     : {0}   (no -ReturnRaw, so the arbiter cannot reach them)' -f @($Rows | Where-Object { -not $_.HasRaw }).Count

$Gaps = @($Declares | Where-Object {
    -not $_.Mechanism -and @($_.DateLeaves | Where-Object { $TimestampFields -notcontains $_ }).Count
})
''
'  GAPS (declare dates, no normalization, not purely audit metadata): {0}' -f $Gaps.Count
foreach ($g in ($Gaps | Sort-Object { -$_.DateFields.Count })) { '      {0,-38} {1}' -f $g.Function, ($g.DateFields -join ', ') }

''
if ($CalFail) { "SELF-CALIBRATION FAILED ($CalFail check(s)); treat this report as unreliable."; exit 1 }
'Self-calibration passed. These are leads; confirm on the wire before acting.'
if ($Strict -and $Gaps.Count) { exit 1 }
