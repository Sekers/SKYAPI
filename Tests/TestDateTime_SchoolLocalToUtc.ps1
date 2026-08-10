# Offline tests for ConvertTo-SKYAPIUtcFromSchoolLocal. No API calls are made.
#
# This helper exists because a wall-clock reading is not always a single instant. On the two days a year a
# zone changes offset, one reading never happened and another happened twice, and [TimeZoneInfo]::ConvertTimeToUtc
# alone either throws or silently picks for you. The rules under test:
#
#   1. Ordinary readings convert exactly as ConvertTimeToUtc would. The helper must not disturb the 99.99%.
#   2. Spring forward (invalid reading): shift forward by the amount the clock jumped, and never throw.
#   3. Fall back (ambiguous reading): take the DAYLIGHT occurrence, the earlier of the two instants. This
#      matches the offset the API itself reports for that day (Research_Notes/DateTime-Handling.md section 3h).
#   4. The jump is read from the zone, not assumed to be an hour, so a 30-minute-delta zone works.
#   5. Southern-hemisphere zones work, where the transition dates and direction are reversed.
#
# Results must be identical on Windows PowerShell 5.1 and PowerShell 7.x; run this file under both.
# US 2026/2027 transitions: forward 2026-03-08 and 2027-03-14, back 2026-11-01. Both at 02:00 local.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-Equal { param([string]$Name,$Expected,$Actual)
        if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

    $Eastern  = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
    $Aus      = [System.TimeZoneInfo]::FindSystemTimeZoneById('AUS Eastern Standard Time')
    $LordHowe = try { [System.TimeZoneInfo]::FindSystemTimeZoneById('Lord Howe Standard Time') } catch { $null }

    function Conv { param($Text,$Zone)
        (ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime ([datetime]::Parse($Text,[System.Globalization.CultureInfo]::InvariantCulture)) -SchoolTimeZone $Zone).ToString('yyyy-MM-ddTHH:mm:ssZ') }

    "--- ordinary readings: unchanged from plain ConvertTimeToUtc"
    foreach ($c in @(
        @{ N = 'summer school hours (EDT, -04:00)'; V = '2026-09-01T08:30:00'; E = '2026-09-01T12:30:00Z' }
        @{ N = 'winter school hours (EST, -05:00)'; V = '2027-01-15T08:30:00'; E = '2027-01-15T13:30:00Z' }
        @{ N = 'just before fall back'           ; V = '2026-11-01T00:30:00'; E = '2026-11-01T04:30:00Z' }
        @{ N = 'just after fall back'            ; V = '2026-11-01T03:00:00'; E = '2026-11-01T08:00:00Z' }
        @{ N = 'just before spring forward'      ; V = '2027-03-14T01:30:00'; E = '2027-03-14T06:30:00Z' }
        @{ N = 'just after spring forward'       ; V = '2027-03-14T03:30:00'; E = '2027-03-14T07:30:00Z' }
        @{ N = 'midnight activity start (00:01)' ; V = '2026-11-01T00:01:00'; E = '2026-11-01T04:01:00Z' }
    ))
    {
        Assert-Equal $c.N $c.E (Conv $c.V $Eastern)
        # And prove the helper agrees with the built-in wherever the built-in has an answer.
        $Builtin = [System.TimeZoneInfo]::ConvertTimeToUtc([datetime]::Parse($c.V,[System.Globalization.CultureInfo]::InvariantCulture), $Eastern)
        Assert-Equal "$($c.N) [matches ConvertTimeToUtc]" $Builtin.ToString('yyyy-MM-ddTHH:mm:ssZ') (Conv $c.V $Eastern)
    }

    "--- spring forward: the reading never happened, must not throw"
    # 2027-03-14 02:00 jumps to 03:00, so 02:00-03:00 does not exist. Shift by the jump: 02:30 -> 03:30 EDT.
    Assert-Equal 'invalid 02:30 shifts to 03:30 EDT' '2027-03-14T07:30:00Z' (Conv '2027-03-14T02:30:00' $Eastern)
    Assert-Equal 'invalid 02:00 (gap start)'          '2027-03-14T07:00:00Z' (Conv '2027-03-14T02:00:00' $Eastern)
    Assert-Equal 'invalid 02:59 (gap end)'            '2027-03-14T07:59:00Z' (Conv '2027-03-14T02:59:00' $Eastern)
    Assert-Equal 'the 2026 transition too'            '2026-03-08T07:30:00Z' (Conv '2026-03-08T02:30:00' $Eastern)
    # The built-in throws on exactly these, which is the behavior being replaced.
    $Threw = $false
    try { $null = [System.TimeZoneInfo]::ConvertTimeToUtc([datetime]'2027-03-14T02:30:00', $Eastern) } catch { $Threw = $true }
    Assert-Equal 'ConvertTimeToUtc alone would have thrown' $true $Threw

    "--- fall back: the reading happened twice, take the DAYLIGHT (earlier) instant"
    # 2026-11-01 02:00 returns to 01:00, so 01:00-02:00 occurs twice: EDT (-04:00) then EST (-05:00).
    Assert-Equal 'ambiguous 01:30 takes EDT'  '2026-11-01T05:30:00Z' (Conv '2026-11-01T01:30:00' $Eastern)
    Assert-Equal 'ambiguous 01:00 takes EDT'  '2026-11-01T05:00:00Z' (Conv '2026-11-01T01:00:00' $Eastern)
    Assert-Equal 'ambiguous 01:59 takes EDT'  '2026-11-01T05:59:00Z' (Conv '2026-11-01T01:59:00' $Eastern)
    # The built-in silently picks STANDARD, an hour later. That difference is the point of the helper.
    $Builtin = [System.TimeZoneInfo]::ConvertTimeToUtc([datetime]'2026-11-01T01:30:00', $Eastern)
    Assert-Equal 'ConvertTimeToUtc alone picks EST (an hour later)' '2026-11-01T06:30:00Z' $Builtin.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-Equal 'helper differs from the built-in here' $true ((Conv '2026-11-01T01:30:00' $Eastern) -ne $Builtin.ToString('yyyy-MM-ddTHH:mm:ssZ'))

    "--- southern hemisphere: transitions reversed"
    # AUS Eastern: forward 2026-10-04 02:00->03:00, back 2027-04-04 03:00->02:00.
    Assert-Equal 'AUS ordinary summer reading' '2026-11-02T00:30:00Z' (Conv '2026-11-02T11:30:00' $Aus)
    Assert-Equal 'AUS invalid (spring forward)' '2026-10-03T16:30:00Z' (Conv '2026-10-04T02:30:00' $Aus)
    $AusAmb = Conv '2027-04-04T02:30:00' $Aus
    Assert-Equal 'AUS ambiguous takes the daylight (earlier) instant' '2027-04-03T15:30:00Z' $AusAmb

    "--- the jump is read from the zone, not assumed to be one hour"
    if ($null -eq $LordHowe) { "  SKIP  Lord Howe zone not present on this system" }
    else {
        # Lord Howe uses a 30-minute DST delta, so its spring-forward gap is 30 minutes, not 60.
        $Jump = $LordHowe.GetAdjustmentRules() | Select-Object -First 1 -ExpandProperty DaylightDelta
        Assert-Equal 'Lord Howe delta is 30 minutes' '00:30:00' $Jump.ToString()
        # A reading inside that 30-minute gap must come back valid (shifted by 30 minutes, not an hour).
        $Gap = [datetime]'2026-10-04T02:15:00'
        if ($LordHowe.IsInvalidTime($Gap)) {
            $r = ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $Gap -SchoolTimeZone $LordHowe
            $Back = [System.TimeZoneInfo]::ConvertTimeFromUtc($r, $LordHowe)
            Assert-Equal 'Lord Howe gap reading becomes valid' $false ($LordHowe.IsInvalidTime($Back))
            Assert-Equal 'Lord Howe shifted by exactly the 30-minute delta' '02:45:00' $Back.TimeOfDay.ToString()
        } else { "  SKIP  2026-10-04 02:15 is not in Lord Howe's gap on this system's rules" }
    }

    "--- Kind handling: any input Kind is treated as school-local"
    $Unspec = [datetime]::new(2026,9,1,8,30,0,[System.DateTimeKind]::Unspecified)
    $AsLocal = [datetime]::new(2026,9,1,8,30,0,[System.DateTimeKind]::Local)
    $AsUtc   = [datetime]::new(2026,9,1,8,30,0,[System.DateTimeKind]::Utc)
    $e = (ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $Unspec -SchoolTimeZone $Eastern).ToString('o')
    Assert-Equal 'Local-kind input treated as school-local' $e (ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $AsLocal -SchoolTimeZone $Eastern).ToString('o')
    Assert-Equal 'Utc-kind input treated as school-local'   $e (ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $AsUtc   -SchoolTimeZone $Eastern).ToString('o')
    Assert-Equal 'result Kind is Utc' 'Utc' (ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $Unspec -SchoolTimeZone $Eastern).Kind

    "--- every result must be a real instant that round-trips back to a valid reading"
    foreach ($v in '2027-03-14T02:30:00','2026-11-01T01:30:00','2026-09-01T08:30:00','2026-03-08T02:01:00')
    {
        $r = ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime ([datetime]::Parse($v,[System.Globalization.CultureInfo]::InvariantCulture)) -SchoolTimeZone $Eastern
        $Back = [System.TimeZoneInfo]::ConvertTimeFromUtc($r, $Eastern)
        Assert-Equal "round-trip of $v is a valid reading" $false ($Eastern.IsInvalidTime($Back))
    }

    "--- the jump is reported by one shared helper, not recomputed per caller"
    Assert-Equal 'Eastern jump is one hour'        '01:00:00' (Get-SKYAPIDaylightJump -OnDate ([datetime]'2027-03-14T02:30:00') -TimeZone $Eastern).ToString()
    Assert-Equal 'jump is positive off-transition' '01:00:00' (Get-SKYAPIDaylightJump -OnDate ([datetime]'2027-06-01T12:00:00') -TimeZone $Eastern).ToString()
    if ($null -ne $LordHowe) {
        Assert-Equal 'Lord Howe jump is 30 minutes' '00:30:00' (Get-SKYAPIDaylightJump -OnDate ([datetime]'2026-10-04T02:15:00') -TimeZone $LordHowe).ToString()
    } else { "  SKIP  Lord Howe zone not present on this system" }

    "--- midnight crossing: the roll applied by Get-SchoolScheduleMeeting"
    # The function anchors both ends to meeting_date, then rolls an end that precedes its start.
    # Reproduced here so the rule is pinned even though the arithmetic lives in the function.
    $Start = [datetime]'2026-09-01T23:00:00'
    $End   = [datetime]'2026-09-01T00:30:00'
    if ($End -lt $Start) { $End = $End.AddDays(1) }
    $SU = ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $Start -SchoolTimeZone $Eastern
    $EU = ConvertTo-SKYAPIUtcFromSchoolLocal -SchoolLocalDateTime $End   -SchoolTimeZone $Eastern
    Assert-Equal 'rolled end is after start'    $true ($EU -gt $SU)
    Assert-Equal 'rolled end lands on the 2nd'  '2026-09-02T04:30:00Z' $EU.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-Equal 'duration is 1.5 hours'        '01:30:00' ($EU - $SU).ToString()

    "--- end to end through Get-SchoolScheduleMeeting itself"
    # The cases above exercise the helper one value at a time, which cannot catch a fault in how the function
    # PAIRS a start with its end. That is exactly how a 02:30-03:00 meeting on a transition day came back with
    # a negative duration: the start was moved out of the gap and the already-valid end was left behind.
    function Get-SKYAPIConfig { param($ConfigPath) [pscustomobject]@{ api_subscription_key = 'stub' } }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }

    function New-StubMeeting { param($Date,$Start,$End,$Off,$Name,$Id)
        '{"meeting_date":"' + $Date + 'T00:00:00+00:00","start_time":"' + $Date + 'T' + $Start + $Off +
        '","end_time":"' + $Date + 'T' + $End + $Off + '","section_id":' + $Id +
        ',"offering_type":{"id":1},"group_name":"' + $Name + '"}' }

    # 2027-03-14 spring forward (02:00->03:00), 2026-11-01 fall back (02:00->01:00).
    $script:Payload = '{"value":[' + ((@(
        (New-StubMeeting '2027-03-14' '02:30:00' '03:00:00' '-05:00' 'GapStart'  1)
        (New-StubMeeting '2027-03-14' '01:30:00' '02:30:00' '-05:00' 'GapEnd'    2)
        (New-StubMeeting '2027-03-14' '09:00:00' '10:00:00' '-04:00' 'Ordinary'  3)
        (New-StubMeeting '2026-11-01' '01:30:00' '02:30:00' '-04:00' 'Ambiguous' 4)
        (New-StubMeeting '2026-09-01' '23:00:00' '00:30:00' '-04:00' 'Midnight'  5)
    ) -join ',')) + ']}'

    function Get-SKYAPIUnpagedEntity {
        param($url,$api_key,$authorisation,$params,$response_field,[switch]$ReturnRaw)
        if ($ReturnRaw) { return $script:Payload }
        return ($script:Payload | ConvertFrom-Json).value }

    $Meetings = @(Get-SchoolScheduleMeeting -start_date '2026-09-01' -end_date '2026-09-02' -SchoolTimeZoneId 'Eastern Standard Time')
    $ById = @{}; foreach ($x in $Meetings) { $ById[[string]$x.group_name] = $x }

    Assert-Equal 'all stub meetings came back' 5 $Meetings.Count

    # The regression: the start is in the gap, the end is not. Both must move, keeping the 30-minute length.
    Assert-Equal 'GapStart start clears the gap' '2027-03-14T07:30:00Z' $ById['GapStart'].start_time.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-Equal 'GapStart end moves with it'    '2027-03-14T08:00:00Z' $ById['GapStart'].end_time.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-Equal 'GapStart keeps its length'     '00:30:00' ($ById['GapStart'].end_time - $ById['GapStart'].start_time).ToString()

    Assert-Equal 'GapEnd is unaffected'   '01:00:00' ($ById['GapEnd'].end_time - $ById['GapEnd'].start_time).ToString()
    Assert-Equal 'Ordinary is unaffected' '01:00:00' ($ById['Ordinary'].end_time - $ById['Ordinary'].start_time).ToString()
    Assert-Equal 'Ambiguous takes the daylight instant' '2026-11-01T05:30:00Z' $ById['Ambiguous'].start_time.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-Equal 'Midnight crosser rolls its end' '2026-09-02T04:30:00Z' $ById['Midnight'].end_time.ToString('yyyy-MM-ddTHH:mm:ssZ')

    # The invariant the regression broke. Cheap, and it would have caught it without anyone predicting the case.
    $Inverted = @($Meetings | Where-Object {$_.end_time -le $_.start_time})
    Assert-Equal 'no meeting ends before it starts' 0 $Inverted.Count
    Assert-Equal 'every start is Kind=Utc' 0 @($Meetings | Where-Object {$_.start_time.Kind -ne 'Utc'}).Count

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
''
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) SCHOOL-LOCAL-TO-UTC CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }
