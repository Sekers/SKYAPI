# Offline tests for the date/time normalization helpers. No API calls are made.
#
# The rule under test, in the order the classifier applies it:
#   1. An explicitly named field wins: -DateOnly / -Timestamp (-DateOnlyFields / -TimestampFields on the
#      walker). This is the only evidence that can settle a value whose shape is ambiguous.
#   2. A fractional second means a real instant. Presence is the test, not a non-zero value.
#   3. The clock reading: midnight means no time information.
# An unset date (0001-01-01) becomes [datetime]::MinValue regardless.
#
# Most inputs below are REAL wire values captured from the live API and recorded in
# Research_Notes/DateTime-Handling.md - including '2007-07-30T10:42:37+00:00', the zero-millisecond timestamp that
# proves rule 1 is necessary. Some are constructed edge cases that the dev tenant cannot produce: the
# positive-offset values (+10:00, +13:00) for non-US schools, and the exact-midnight timestamps. Those are
# marked where they appear.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-Equal { param([string]$Name,$Expected,$Actual)
        if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

    "--- date-only values: the written day wins, whatever the offset"
    foreach ($c in @(
        @{ N = 'school offset, winter (EST)'; V = '2031-02-23T00:00:00-05:00'; E = '2031-02-23' }
        @{ N = 'school offset, summer (EDT)'; V = '2032-07-19T00:00:00-04:00'; E = '2032-07-19' }
        @{ N = 'UTC midnight (Get-SchoolUser dob)'; V = '2005-03-17T00:00:00+00:00'; E = '2005-03-17' }
        @{ N = 'Z suffix'; V = '2005-03-17T00:00:00Z'; E = '2005-03-17' }
        @{ N = 'no offset at all'; V = '2005-03-17T00:00:00'; E = '2005-03-17' }
        # CONSTRUCTED: the dev tenant is Eastern, so a positive-offset school cannot be measured. These are
        # the case the offset-sign-independent rule exists for; converting them through UTC lands a day early.
        @{ N = 'POSITIVE offset (non-US school)'; V = '2031-02-23T00:00:00+10:00'; E = '2031-02-23' }
        @{ N = 'positive offset, far east (+13:00)'; V = '2031-02-23T00:00:00+13:00'; E = '2031-02-23' }
    ))
    {
        $r = ConvertTo-SKYAPIDateTimeValue -Value $c.V
        Assert-Equal $c.N $c.E $r.ToString('yyyy-MM-dd')
    }

    "--- the occupations encoding: midnight school-time expressed as UTC, so NOT midnight"
    # Shape alone cannot tell these are date-only, so the caller names the field.
    Assert-Equal 'occupation begin_date (05:00Z = midnight EST)' '1923-01-25' (ConvertTo-SKYAPIDateTimeValue -Value '1923-01-25T05:00:00+00:00' -DateOnly).ToString('yyyy-MM-dd')
    Assert-Equal 'occupation end_date (04:00Z = midnight EDT)'   '2022-03-15' (ConvertTo-SKYAPIDateTimeValue -Value '2022-03-15T04:00:00+00:00' -DateOnly).ToString('yyyy-MM-dd')

    "--- unset dates"
    Assert-Equal 'unset sentinel becomes MinValue' ([datetime]::MinValue) (ConvertTo-SKYAPIDateTimeValue -Value '0001-01-01T00:00:00+00:00')
    Assert-Equal 'unset sentinel, other offset'    ([datetime]::MinValue) (ConvertTo-SKYAPIDateTimeValue -Value '0001-01-01T00:00:00-05:00')

    "--- real timestamps keep their time (must NOT be flattened to a date)"
    $ts = ConvertTo-SKYAPIDateTimeValue -Value '2026-07-28T16:26:54.233-04:00'
    Assert-Equal 'timestamp is a datetime' 'DateTime' $ts.GetType().Name
    Assert-Equal 'timestamp keeps a time component' $true ($ts.TimeOfDay -ne [timespan]::Zero)
    $ts2 = ConvertTo-SKYAPIDateTimeValue -Value '2026-02-13T16:44:23.38+00:00'
    Assert-Equal 'UTC timestamp keeps a time component' $true ($ts2.TimeOfDay -ne [timespan]::Zero)

    "--- a timestamp in the midnight hour is not a date"
    # CONSTRUCTED values from here to the end of this block: a timestamp landing inside the midnight hour has
    # not been observed on the tenant, which is exactly why it needs pinning rather than waiting for one.
    # Clock value alone cannot separate 'midnight' from 'a date'; a fractional second can, because no
    # date-only value on the wire carries one. Without this, an instant that happened to land at midnight
    # lost its offset, its Kind and its milliseconds.
    $mid = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.123Z'
    Assert-Equal 'fractional second at midnight keeps its time' $true ($mid.TimeOfDay -ne [timespan]::Zero)
    Assert-Equal 'and keeps the milliseconds' 123 $mid.Millisecond
    Assert-Equal 'fractional second is not treated as Unspecified' $false ($mid.Kind -eq [System.DateTimeKind]::Unspecified)
    Assert-Equal 'fractional second just after midnight' $true `
        ((ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.001-05:00').TimeOfDay -ne [timespan]::Zero)

    # Presence of a fraction is the test, not its value. An all-zero fraction is not expected on the wire at
    # all (the API strips trailing zeros - see the two-digit '.38' timestamp above), but a serializer that
    # emitted '.000' was writing a time, so it must not be flattened either.
    # Asserted as an INSTANT, not as a written date. A timestamp is deliberately converted to the client's
    # local time, so its calendar date legitimately shifts for a client west of the offset; comparing in UTC
    # is the zone-independent way to say "the same moment came back".
    $zero = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.000-05:00'
    Assert-Equal 'all-zero fraction is treated as a timestamp' $false ($zero.Kind -eq [System.DateTimeKind]::Unspecified)
    Assert-Equal 'all-zero fraction preserves the instant' '2026-01-01 05:00:00' $zero.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')

    # Positive offset with a fraction: the non-US school case, and the one shape the issue list was missing.
    $pos = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.500+10:00'
    Assert-Equal 'positive-offset fractional midnight keeps milliseconds' 500 $pos.Millisecond
    Assert-Equal 'positive-offset fractional midnight is not Unspecified' $false ($pos.Kind -eq [System.DateTimeKind]::Unspecified)
    Assert-Equal 'positive-offset fractional midnight preserves the instant' '2025-12-31 14:00:00.500' `
        $pos.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff')

    # A bare midnight with NO fraction is read as a date when nothing else is known about the field. It has to
    # be: a real date-only value looks exactly like this ('1980-01-23T00:00:00-05:00' is a birth date), so
    # treating the shape as a timestamp would put every date back a day for clients west of the school.
    Assert-Equal 'bare midnight is date-only when the field is unknown' $true `
        ((ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00-05:00').TimeOfDay -eq [timespan]::Zero)

    "--- -Timestamp resolves the case shape cannot"
    # A timestamp with exactly zero milliseconds is serialized with no fractional part at all ('created
    # 2007-07-30T10:42:37+00:00', measured on the dev tenant), so one landing on midnight is byte-identical
    # to a date. Naming the field is the only way to keep the instant.
    $ts = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00-05:00' -Timestamp
    Assert-Equal 'named timestamp field keeps the instant' '2026-01-01 05:00:00' $ts.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    Assert-Equal 'named timestamp field is not Unspecified' $false ($ts.Kind -eq [System.DateTimeKind]::Unspecified)

    $tsz = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00Z' -Timestamp
    Assert-Equal 'named timestamp field, Z suffix' '2026-01-01 00:00:00' $tsz.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')

    $tsp = ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00+10:00' -Timestamp
    Assert-Equal 'named timestamp field, positive offset' '2025-12-31 14:00:00' $tsp.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')

    # The unset sentinel must still win, or a cleared audit field would become a real 0001-01-01 instant.
    Assert-Equal '-Timestamp does not resurrect the unset sentinel' ([datetime]::MinValue) `
        (ConvertTo-SKYAPIDateTimeValue -Value '0001-01-01T00:00:00+00:00' -Timestamp)

    # A caller naming a field in both lists is a mistake; date-only is the safer reading and wins.
    Assert-Equal '-DateOnly beats -Timestamp' $true `
        ((ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00-05:00' -DateOnly -Timestamp).TimeOfDay -eq [timespan]::Zero)

    "--- the walker applies timestamp fields by name"
    # The exact regression: audit metadata at midnight, no fraction. Read by shape it is a date; by name it is
    # the instant it really is.
    $Audit = [pscustomobject]@{
        birth_date    = '1980-01-23T00:00:00-05:00'   # genuinely date-only, same shape
        created       = '2026-01-01T00:00:00-05:00'   # a timestamp that lost its zero milliseconds
        last_modified = '2026-01-01T00:00:00-05:00'
    }
    $null = Repair-SKYAPIResponseDateTime -InputObject $Audit
    Assert-Equal 'walker keeps the instant for created'       '2026-01-01 05:00:00' $Audit.created.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    Assert-Equal 'walker keeps the instant for last_modified' '2026-01-01 05:00:00' $Audit.last_modified.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    # ...and the identically-shaped date-only field beside it is untouched. This is the pairing that makes a
    # blanket "midnight means timestamp" rule impossible.
    Assert-Equal 'walker still reads birth_date as a date' '1980-01-23' $Audit.birth_date.ToString('yyyy-MM-dd')
    Assert-Equal 'and birth_date has no time component' $true ($Audit.birth_date.TimeOfDay -eq [timespan]::Zero)

    # A named date-only field must still beat the timestamp default if a caller lists it.
    $Both = [pscustomobject]@{ created = '2026-01-01T00:00:00-05:00' }
    $null = Repair-SKYAPIResponseDateTime -InputObject $Both -DateOnlyFields @('created')
    Assert-Equal 'explicit -DateOnlyFields overrides the timestamp default' $true ($Both.created.TimeOfDay -eq [timespan]::Zero)

    # -DateOnly must still win outright: the occupations fields are date-only by decree, not by shape.
    Assert-Equal '-DateOnly overrides a fractional second' '2026-01-01' `
        (ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.123Z' -DateOnly).ToString('yyyy-MM-dd')
    Assert-Equal 'and leaves no time component' $true `
        ((ConvertTo-SKYAPIDateTimeValue -Value '2026-01-01T00:00:00.123Z' -DateOnly).TimeOfDay -eq [timespan]::Zero)

    "--- non-date values are passed through untouched"
    Assert-Equal 'plain string'  'MB-22' (ConvertTo-SKYAPIDateTimeValue -Value 'MB-22')
    Assert-Equal 'empty string'  ''      (ConvertTo-SKYAPIDateTimeValue -Value '')
    Assert-Equal 'null'          ''      (ConvertTo-SKYAPIDateTimeValue -Value $null)
    Assert-Equal 'date-like but not ISO' '3/17/2005' (ConvertTo-SKYAPIDateTimeValue -Value '3/17/2005')
    $already = [datetime]'2005-03-17'
    Assert-Equal 'an existing [datetime] is passed through' '2005-03-17' (ConvertTo-SKYAPIDateTimeValue -Value $already).ToString('yyyy-MM-dd')

    "--- the walker fixes nested objects and arrays"
    $Response = [pscustomobject]@{
        birth_date = '2005-03-17T00:00:00-05:00'
        audit_date = '2026-07-28T16:26:54.233-04:00'
        locker     = [pscustomobject]@{ number = '1234'; combo = '9-9-9' }
        passport   = [pscustomobject]@{ number = 'P999'; expire_date = '2031-02-23T00:00:00-05:00' }
        in_state   = [pscustomobject]@{ resident = 'Yes'; from_date = '2033-11-25T00:00:00-05:00' }
        visa       = [pscustomobject]@{ issue_date = '2024-01-10T00:00:00-05:00'; status = [pscustomobject]@{ id = 19; description = 'Issued' } }
        occupations = @(
            [pscustomobject]@{ begin_date = '1923-01-25T05:00:00+00:00'; end_date = '2022-03-15T04:00:00+00:00' }
        )
        retire_date = '0001-01-01T00:00:00+00:00'
    }
    $null = Repair-SKYAPIResponseDateTime -InputObject $Response -DateOnlyFields @('begin_date','end_date')

    Assert-Equal 'top-level date'            '2005-03-17' $Response.birth_date.ToString('yyyy-MM-dd')
    Assert-Equal 'nested passport date'      '2031-02-23' $Response.passport.expire_date.ToString('yyyy-MM-dd')
    Assert-Equal 'nested in_state date'      '2033-11-25' $Response.in_state.from_date.ToString('yyyy-MM-dd')
    Assert-Equal 'nested visa date'          '2024-01-10' $Response.visa.issue_date.ToString('yyyy-MM-dd')
    Assert-Equal 'date inside an array'      '1923-01-25' $Response.occupations[0].begin_date.ToString('yyyy-MM-dd')
    Assert-Equal 'second date in that array' '2022-03-15' $Response.occupations[0].end_date.ToString('yyyy-MM-dd')
    Assert-Equal 'unset date in the walk'    ([datetime]::MinValue) $Response.retire_date
    Assert-Equal 'timestamp survives the walk as a datetime' 'DateTime' $Response.audit_date.GetType().Name
    Assert-Equal 'timestamp keeps its time'  $true ($Response.audit_date.TimeOfDay -ne [timespan]::Zero)
    Assert-Equal 'non-date strings untouched' '1234' $Response.locker.number
    Assert-Equal 'nested non-date untouched'  'Issued' $Response.visa.status.description

    "--- the walker is idempotent (safe to run twice)"
    $null = Repair-SKYAPIResponseDateTime -InputObject $Response -DateOnlyFields @('begin_date','end_date')
    Assert-Equal 'second pass leaves the date alone' '2031-02-23' $Response.passport.expire_date.ToString('yyyy-MM-dd')

    "--- collections at the top level"
    $Collection = @(
        [pscustomobject]@{ begin_date = '2025-08-01T00:00:00-04:00' }
        [pscustomobject]@{ begin_date = '2025-12-31T00:00:00-05:00' }
    )
    $null = Repair-SKYAPIResponseDateTime -InputObject $Collection
    Assert-Equal 'array item 1' '2025-08-01' $Collection[0].begin_date.ToString('yyyy-MM-dd')
    Assert-Equal 'array item 2' '2025-12-31' $Collection[1].begin_date.ToString('yyyy-MM-dd')

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
''
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) DATETIME-NORMALIZATION CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }
