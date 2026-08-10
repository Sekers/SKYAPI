# Offline tests for the private Confirm-SKYAPIWriteResult comparator used by -Validate. No API calls are made.
#
# One case per comparison Kind (Scalar, Rename, Date, TypeTable, TypeTableArray, ObjectArray, Object), plus the
# false-positive guards: values sent by ID but read back as descriptors, arrays returned out of order,
# dates differing only in time of day, and aliases that the API echoes in a different spelling.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Failures = 0
function Assert-Case
{
    param([string]$Name,[object[]]$Findings,[string]$ExpectKind,[string]$ExpectFieldLike)

    $script:Total++
    if ([string]::IsNullOrEmpty($ExpectKind))
    {
        if ($Findings.Count -eq 0) { "  PASS  $Name"; return }
        "  FAIL  $Name -- expected clean, got: $($Findings | ForEach-Object { "$($_.Kind) $($_.Field): $($_.Reason)" })"
        $script:Failures++
        return
    }

    $Match = $Findings | Where-Object { $_.Kind -eq $ExpectKind -and $_.Field -like $ExpectFieldLike }
    if ($Match) { "  PASS  $Name  [$($Match[0].Reason)]"; return }
    "  FAIL  $Name -- expected $ExpectKind on '$ExpectFieldLike', got: $(if ($Findings.Count) { $Findings | ForEach-Object { "$($_.Kind) $($_.Field): $($_.Reason)" } } else { '(clean)' })"
    $script:Failures++
}

# A miniature spec exercising every Kind.
$Spec = [ordered]@{
    middle_name        = @{ Kind = 'Scalar'; Read = 'middle_name'; BasicRead = 'middle_name' }
    student_id         = @{ Kind = 'Scalar'; Read = 'student_id' }
    is_abroad          = @{ Kind = 'Scalar'; Read = 'abroad' }
    boarding_or_day    = @{ Kind = 'Scalar'; Read = 'boarding_or_day'; Aliases = @{ B = 'boarding'; D = 'day' } }
    summary_note       = @{ Kind = 'Scalar'; Read = 'misc_bio'; Unmapped = $true }
    dob                = @{ Kind = 'Date';   Read = 'birth_date'; BasicRead = 'dob' }
    citizenship        = @{ Kind = 'TypeTable'; Read = 'citizenship'; Table = 'Citizenship' }
    races              = @{ Kind = 'TypeTableArray'; Read = 'races'; Table = 'Race'; ItemKey = 'race_type'; ReadItemKey = 'race_type_id' }
    international      = @{ Kind = 'Scalar'; Read = 'international' }
    visa               = @{ Kind = 'Object'; Read = 'visa'; SubFields = @{
                                number = @{ Kind = 'Scalar' }
                                status = @{ Kind = 'TypeTable'; Table = 'Visa Status' }
                                expire_date = @{ Kind = 'Date' } } }
    links              = @{ Kind = 'ObjectArray'; Read = 'links'; MatchFields = @('user_id','type_id'); SubFields = @{
                                user_id = @{ Kind = 'Scalar' }
                                type_id = @{ Kind = 'Scalar' }
                                primary = @{ Kind = 'Scalar' }
                                shared  = @{ Kind = 'Scalar' } } }
}

$Cache = @{
    'Citizenship' = @([pscustomobject]@{ id = 3; name = 'United States' }, [pscustomobject]@{ id = 4; name = 'Canada' })
    'Race'        = @([pscustomobject]@{ id = 10; name = 'White' }, [pscustomobject]@{ id = 11; name = 'Asian' })
    'Visa Status' = @([pscustomobject]@{ id = 7; name = 'Current' })
}

$Total = 0
& (Get-Module SKYAPI) {
    param($Spec,$Cache,$AssertFn)
    Set-Item function:Assert-Case $AssertFn

    "--- scalars"
    Assert-Case 'matching scalar' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'Alpha' }) -Expected @{ middle_name = 'Alpha' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'scalar case/whitespace insensitive' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'alpha' }) -Expected @{ middle_name = ' Alpha ' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'mismatched scalar' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'Beta' }) -Expected @{ middle_name = 'Alpha' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'middle_name'
    Assert-Case 'rename is_abroad->abroad matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ abroad = $true }) -Expected @{ is_abroad = $true } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'alias B->boarding matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'Boarding' }) -Expected @{ boarding_or_day = 'B' } -FieldSpec $Spec -Cache $Cache) '' ''
    # Regression: the live API returns the SHORT code, so aliases must fold both sides, not just the sent value.
    Assert-Case 'alias sent B, read back B' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'B' }) -Expected @{ boarding_or_day = 'B' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'alias sent boarding, read back B' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'B' }) -Expected @{ boarding_or_day = 'boarding' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'alias still catches a real mismatch (D vs B)' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'B' }) -Expected @{ boarding_or_day = 'D' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'boarding_or_day'
    # Measured read-back forms: the field returns a single-letter code in the case it was sent, so the long
    # spellings come back lowercase ('day' -> 'd', 'boarding' -> 'b'). The alias fold is case-insensitive and
    # therefore already covers it, but pin the real wire forms so a future change to the folding cannot
    # silently start failing every long-form write.
    Assert-Case 'sent day, read back lowercase d' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'd' }) -Expected @{ boarding_or_day = 'day' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'sent boarding, read back lowercase b' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'b' }) -Expected @{ boarding_or_day = 'boarding' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'lowercase read-back still catches a mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ boarding_or_day = 'd' }) -Expected @{ boarding_or_day = 'boarding' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'boarding_or_day'
    Assert-Case 'control keys ignored' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'Alpha' }) -Expected @{ middle_name = 'Alpha'; id = 99; fields_to_delete = @('x') } -FieldSpec $Spec -Cache $Cache) '' ''

    "--- empty vs absent must behave identically (regression guard)"
    Assert-Case 'present but empty -> Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ student_id = '' }) -Expected @{ student_id = 'A12345' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'student_id'
    Assert-Case 'absent entirely -> Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ other = 1 }) -Expected @{ student_id = 'A12345' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'student_id'

    "--- dates"
    Assert-Case 'date differing only by time matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = '1980-01-23T05:00:00' }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'date differing by day mismatches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = '1980-01-24T00:00:00' }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'dob'

    "--- type tables"
    Assert-Case 'type table sent by id, read as descriptor' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = 'United States' }) -Expected @{ citizenship = '3' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'type table sent by descriptor' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = 'United States' }) -Expected @{ citizenship = 'united states' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'type table wrong value' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = 'Canada' }) -Expected @{ citizenship = 'United States' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'citizenship'
    Assert-Case 'unreadable table -> Unverifiable, not silent pass' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = 'United States' }) -Expected @{ citizenship = 'United States' } -FieldSpec $Spec -Cache @{ 'Citizenship' = @() }) 'Unverifiable' 'citizenship'

    "--- type table arrays (order-insensitive)"
    $ActualRaces = [pscustomobject]@{ races = @([pscustomobject]@{ race_type_id = 11; description = 'Asian' },[pscustomobject]@{ race_type_id = 10; description = 'White' }) }
    Assert-Case 'races out of order matches' @(Confirm-SKYAPIWriteResult -Actual $ActualRaces -Expected @{ races = @(@{ race_type = 'White' },@{ race_type = 'Asian' }) } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'races missing one mismatches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ races = @([pscustomobject]@{ race_type_id = 10; description = 'White' }) }) -Expected @{ races = @(@{ race_type = 'White' },@{ race_type = 'Asian' }) } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'races'

    "--- blank sent values compare as blank for every Kind (not 'unverifiable')"
    Assert-Case 'blank scalar vs blank actual matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ student_id = '' }) -Expected @{ student_id = '' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'blank type table vs populated -> Mismatch not Unverifiable' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = 'United States' }) -Expected @{ citizenship = '' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'citizenship'
    Assert-Case 'blank date vs populated -> Mismatch not Unverifiable' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = '1980-01-23T00:00:00' }) -Expected @{ dob = '' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'dob'
    Assert-Case 'blank type table vs blank actual matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ citizenship = '' }) -Expected @{ citizenship = '' } -FieldSpec $Spec -Cache $Cache) '' ''
    # This is the live -races '' case: the API ignores blank, so the still-populated array must be a Mismatch.
    Assert-Case 'blank races vs populated -> Mismatch' @(Confirm-SKYAPIWriteResult -Actual $ActualRaces -Expected @{ races = @(@{ race_type = '' }) } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'races'
    Assert-Case 'blank races vs empty actual matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ races = @() }) -Expected @{ races = @(@{ race_type = '' }) } -FieldSpec $Spec -Cache $Cache) '' ''

    "--- unset dates: the API returns 0001-01-01, not an empty value (regression: this false-positived live)"
    $MinDate = [datetime]::MinValue
    Assert-Case 'cleared date field reading back 0001-01-01 counts as cleared' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = $MinDate }) -Expected @{} -FieldSpec $Spec -ClearedFields @('dob') -Cache $Cache) '' ''
    Assert-Case 'cleared date as raw 0001-01-01 string counts as cleared' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = '0001-01-01T00:00:00+00:00' }) -Expected @{} -FieldSpec $Spec -ClearedFields @('dob') -Cache $Cache) '' ''
    Assert-Case 'sending a date that reads back 0001-01-01 is still a Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = $MinDate }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'dob'
    Assert-Case 'blank sent vs 0001-01-01 read back matches' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = $MinDate }) -Expected @{ dob = '' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'a real date still compares normally' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = [datetime]'1980-01-23' }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'cleared date that is still populated is a Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = [datetime]'1980-01-23' }) -Expected @{} -FieldSpec $Spec -ClearedFields @('dob') -Cache $Cache) 'Mismatch' 'dob'

    "--- dates must compare as written, not as an instant (regression: off-by-one across time zones)"
    # The API mixes offsets on date-only fields and does not repair the nested ones, so converting to local
    # time moved the calendar date a day. Every offset below is the SAME calendar day and must match.
    foreach ($Offset in '+00:00','-05:00','-08:00','+13:00','Z')
    {
        $Suffix = if ($Offset -eq 'Z') { 'Z' } else { $Offset }
        Assert-Case "date with offset $Offset compares as the written day" @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = "1980-01-23T00:00:00$Suffix" }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) '' ''
    }
    Assert-Case 'a genuinely different day still mismatches (offset form)' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = '1980-01-24T00:00:00+00:00' }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'dob'
    Assert-Case 'nested date with an offset compares as written' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ visa = [pscustomobject]@{ expire_date = '2031-02-03T00:00:00+00:00' } }) -Expected @{ visa = @{ expire_date = '2031-02-03' } } -FieldSpec $Spec -Cache $Cache) '' ''

    # The read functions hand back [datetime] objects, already normalized to midnight on the day the API wrote,
    # so these cases pin that the comparator takes that day as written. It must not re-derive the day through
    # UTC: midnight converts to the previous day for any client at or east of UTC, which would report a
    # correctly written date as a mismatch everywhere from the UK eastward.
    $Normalized = [datetime]::new(2031,2,3,0,0,0,[System.DateTimeKind]::Unspecified)   # what a read hands back
    Assert-Case 'normalized date-only [datetime] matches the written day' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ visa = [pscustomobject]@{ expire_date = $Normalized } }) -Expected @{ visa = @{ expire_date = '2031-02-03' } } -FieldSpec $Spec -Cache $Cache) '' ''
    $AsUtc = [datetime]::new(2031,2,3,0,0,0,[System.DateTimeKind]::Utc)                # same day, Kind=Utc
    Assert-Case 'UTC midnight resolves to the same day' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = $AsUtc }) -Expected @{ dob = '2031-02-03' } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'a genuinely wrong day still mismatches as a [datetime]' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ birth_date = $Normalized }) -Expected @{ dob = '2031-02-04' } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'dob'

    "--- array comparison is a set in BOTH directions (PATCH replaces, so removals must be caught)"
    Assert-Case 'failed removal detected (sent White, still has both)' @(Confirm-SKYAPIWriteResult -Actual $ActualRaces -Expected @{ races = @(@{ race_type = 'White' }) } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'races'

    "--- nested objects"
    $ActualVisa = [pscustomobject]@{ visa = [pscustomobject]@{ number = '12345678'; status = [pscustomobject]@{ id = 7; description = 'Current' }; expire_date = '2025-09-28T00:00:00' } }
    Assert-Case 'visa all sub-fields match' @(Confirm-SKYAPIWriteResult -Actual $ActualVisa -Expected @{ visa = @{ number = '12345678'; status = 'Current'; expire_date = '2025-09-28' } } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'visa.status wrong' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ visa = [pscustomobject]@{ status = [pscustomobject]@{ id = 99; description = 'Expired' } } }) -Expected @{ visa = @{ status = 'Current' } } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'visa.status'

    "--- object arrays"
    $ActualLinks = [pscustomobject]@{ links = @(
        [pscustomobject]@{ user_id = 2; type_id = 20; primary = $false; shared = $true }
        [pscustomobject]@{ user_id = 1; type_id = 10; primary = $true; shared = $false }) }
    Assert-Case 'links match by identity when returned out of order' @(Confirm-SKYAPIWriteResult -Actual $ActualLinks -Expected @{ links = @(
        @{ user_id = 1; type_id = 10; primary = $true }
        @{ user_id = 2; type_id = 20; shared = $true }) } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'links compare every supplied sub-field' @(Confirm-SKYAPIWriteResult -Actual $ActualLinks -Expected @{ links = @(
        @{ user_id = 1; type_id = 10; primary = $false }) } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'links*primary'
    Assert-Case 'missing link is a mismatch' @(Confirm-SKYAPIWriteResult -Actual $ActualLinks -Expected @{ links = @(
        @{ user_id = 3; type_id = 30; primary = $true }) } -FieldSpec $Spec -Cache $Cache) 'Mismatch' 'links*'
    Assert-Case 'single link without identity can be compared' @(Confirm-SKYAPIWriteResult `
        -Actual ([pscustomobject]@{ links = @([pscustomobject]@{ primary = $true }) }) `
        -Expected @{ links = @(@{ primary = $true }) } -FieldSpec $Spec -Cache $Cache) '' ''
    Assert-Case 'multiple links without identity are unverifiable' @(Confirm-SKYAPIWriteResult -Actual $ActualLinks `
        -Expected @{ links = @(@{ primary = $true },@{ primary = $false }) } -FieldSpec $Spec -Cache $Cache) 'Unverifiable' 'links*'

    "--- fields_to_delete"
    Assert-Case 'cleared field blank -> ok' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = '' }) -Expected @{} -FieldSpec $Spec -ClearedFields @('middle_name') -Cache $Cache) '' ''
    Assert-Case 'cleared tri-state No answer -> ok' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ international = 'No answer' }) -Expected @{} -FieldSpec $Spec -ClearedFields @('international') -Cache $Cache) '' ''
    Assert-Case 'cleared but still set -> Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'Alpha' }) -Expected @{} -FieldSpec $Spec -ClearedFields @('middle_name') -Cache $Cache) 'Mismatch' 'middle_name'
    Assert-Case 'cleared wins over sent value' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = '' }) -Expected @{ middle_name = 'Alpha' } -FieldSpec $Spec -ClearedFields @('middle_name') -Cache $Cache) '' ''
    Assert-Case 'cleared dotted path' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ visa = [pscustomobject]@{ number = 'STILLHERE' } }) -Expected @{} -FieldSpec $Spec -ClearedFields @('visa.number') -Cache $Cache) 'Mismatch' 'visa.number'

    "--- unmapped / unreadable / basic-model gaps"
    Assert-Case 'unmapped field -> Unverifiable' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ misc_bio = 'x' }) -Expected @{ summary_note = 'x' } -FieldSpec $Spec -Cache $Cache) 'Unverifiable' 'summary_note'
    Assert-Case 'record unreadable -> Unverifiable' @(Confirm-SKYAPIWriteResult -Actual $null -Expected @{ middle_name = 'Alpha' } -FieldSpec $Spec -Cache $Cache) 'Unverifiable' '(record)'
    Assert-Case 'extended-only field under Basic model -> Unverifiable' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ middle_name = 'Alpha' }) -Expected @{ student_id = 'A1' } -FieldSpec $Spec -ReadModel Basic -Cache $Cache) 'Unverifiable' 'student_id'
    Assert-Case 'basic model uses BasicRead name (dob not birth_date)' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ dob = '1980-01-23T00:00:00' }) -Expected @{ dob = '1980-01-23' } -FieldSpec $Spec -ReadModel Basic -Cache $Cache) '' ''

    "--- ExpectAbsent (DELETE)"
    Assert-Case 'record gone -> ok' @(Confirm-SKYAPIWriteResult -Actual $null -Expected @{} -FieldSpec $Spec -ExpectAbsent -Cache $Cache) '' ''
    Assert-Case 'record still present -> Mismatch' @(Confirm-SKYAPIWriteResult -Actual ([pscustomobject]@{ id = 1 }) -Expected @{} -FieldSpec $Spec -ExpectAbsent -Cache $Cache) 'Mismatch' '(record)'
} $Spec $Cache (Get-Item function:Assert-Case).ScriptBlock

""
if (-not $Total) { "NO CASES RAN - treating as failure"; exit 1 }
if ($Failures -eq 0) { "ALL $Total COMPARATOR CASES PASSED" } else { "$Failures of $Total CASES FAILED"; exit 1 }
