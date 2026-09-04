# Offline tests for the private Get-SKYAPIRequestParameter helper. No API calls are made.
#
# The helper is the single place request parameters are built from a function's $PSBoundParameters, so these
# cases pin down the three things call sites depend on:
#   1. Common parameters (-Verbose, -ErrorAction, ...) and named exclusions never reach the API.
#   2. -As picks the collection type, and a Query collection stringifies to a real query string. This is not
#      cosmetic: Get-SKYAPIUnpagedEntity builds the URL with $params.ToString().
#   3. The returned collection is still mutable, because callers add paging and per-iteration values to it.
#
# Also covers the two bugs that motivated the helper (see CHANGELOG 0.4.5):
#   - Get-ReConstituentRatingSource built a hashtable for a query string, so every call sent the literal
#     'System.Collections.Hashtable' and dropped include_inactive.
#   - Get-SchoolCycleBySection never excluded -ReturnRaw, so it was sent to the API as a query value.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-Equal { param([string]$Name,$Expected,$Actual)
        if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

    "--- common parameters never reach the API"
    # Ask the runtime for the list so this stays correct across versions (-ProgressAction is 7.4+ only).
    $Common = [System.Management.Automation.PSCmdlet]::CommonParameters
    $Bound  = @{ level_num = '3' }
    foreach ($c in $Common) { $Bound[$c] = 'polluted' }

    $Query = Get-SKYAPIRequestParameter -BoundParameters $Bound
    Assert-Equal "all $($Common.Count) common parameters filtered (Query)" 'level_num=3' $Query.ToString()

    $Body = Get-SKYAPIRequestParameter -BoundParameters $Bound -As Body
    Assert-Equal 'all common parameters filtered (Body)' 'level_num' (($Body.Keys | Sort-Object) -join ',')

    # -ErrorAction Stop is the realistic case: routine in production scripts, and it bound as an integer,
    # which is how 'ErrorAction=1' ended up in request URLs.
    Assert-Equal 'ErrorAction Stop does not leak' 'limit=5' `
        (Get-SKYAPIRequestParameter -BoundParameters @{ limit = 5; ErrorAction = 'Stop' }).ToString()

    "--- named exclusions"
    Assert-Equal 'excluded name is dropped' 'duration_id=2' `
        (Get-SKYAPIRequestParameter -BoundParameters @{ duration_id = 2; Section_ID = 9 } -Exclude 'Section_ID').ToString()
    Assert-Equal 'exclusion matching is case-insensitive' 'duration_id=2' `
        (Get-SKYAPIRequestParameter -BoundParameters @{ duration_id = 2; ReturnRaw = $true } -Exclude 'returnraw').ToString()
    Assert-Equal 'unknown exclusion name is harmless' 'duration_id=2' `
        (Get-SKYAPIRequestParameter -BoundParameters @{ duration_id = 2 } -Exclude 'NotAParameter').ToString()
    # Compared as a sorted set: hashtable enumeration order is not guaranteed, and order is irrelevant in a query string.
    Assert-Equal 'no -Exclude keeps every non-common value' 'a=1,b=2' `
        (((Get-SKYAPIRequestParameter -BoundParameters @{ a = 1; b = 2 }).ToString() -split '&' | Sort-Object) -join ',')

    "--- -SuppliedNames drops what the current pipeline record did not supply"
    # End-to-end coverage of the pipeline bug this feeds is in TestRequestParameters_PipelineIsolation.ps1;
    # these pin the helper's own contract.
    $Stale = @{ middle_name = 'Alpha'; first_name = 'Bob'; User_ID = 102 }
    Assert-Equal 'only the supplied name survives (Body)' 'first_name' `
        ((Get-SKYAPIRequestParameter -BoundParameters $Stale -Exclude 'User_ID' -SuppliedNames @('first_name','User_ID') -As Body).Keys -join ',')
    Assert-Equal 'only the supplied name survives (Query)' 'first_name=Bob' `
        (Get-SKYAPIRequestParameter -BoundParameters $Stale -Exclude 'User_ID' -SuppliedNames @('first_name','User_ID')).ToString()

    # Omitting the parameter must behave exactly as before it existed, which is what every non-pipeline
    # caller relies on.
    Assert-Equal 'omitting -SuppliedNames keeps everything' 'first_name,middle_name' `
        (((Get-SKYAPIRequestParameter -BoundParameters $Stale -Exclude 'User_ID' -As Body).Keys | Sort-Object) -join ',')

    # An empty set is a real answer ("this record supplied nothing"), not the same as omitting the parameter.
    Assert-Equal 'an empty supplied set drops everything' '' `
        ((Get-SKYAPIRequestParameter -BoundParameters $Stale -SuppliedNames @() -As Body).Keys -join ',')

    Assert-Equal 'supplied-name matching is case-insensitive' 'first_name' `
        ((Get-SKYAPIRequestParameter -BoundParameters $Stale -Exclude 'User_ID' -SuppliedNames @('FIRST_NAME') -As Body).Keys -join ',')

    # Exclusion still wins: a name the record supplied but the caller excluded must not reach the API.
    Assert-Equal 'exclusion beats supplied' 'first_name' `
        ((Get-SKYAPIRequestParameter -BoundParameters $Stale -Exclude 'User_ID','middle_name' -SuppliedNames @('first_name','middle_name','User_ID') -As Body).Keys -join ',')

    "--- collection type per -As"
    $Q = Get-SKYAPIRequestParameter -BoundParameters @{ a = 1 }
    $B = Get-SKYAPIRequestParameter -BoundParameters @{ a = 1 } -As Body
    Assert-Equal 'Query is a NameValueCollection' $true ($Q -is [System.Collections.Specialized.NameValueCollection])
    Assert-Equal 'Body is a hashtable'             $true ($B -is [hashtable])
    # The bare 'return $collection' trap: a NameValueCollection is enumerable, so PowerShell unrolls it into an
    # Object[] of keys unless the helper wraps it. ToString() on that gives 'System.Object[]'.
    Assert-Equal 'Query is not unrolled into an array' $false ($Q -is [array])
    Assert-Equal 'Query stringifies to a query string' 'a=1' $Q.ToString()
    # Get-SKYAPIUnpagedEntity guards with "$params -ne ''", so an empty set must stringify to empty.
    Assert-Equal 'empty parameter set stringifies to empty' '' (Get-SKYAPIRequestParameter -BoundParameters @{}).ToString()

    "--- the returned collection stays mutable (paging and per-iteration values)"
    $M = Get-SKYAPIRequestParameter -BoundParameters @{ marker = 0 } -Exclude 'ResponseLimit'
    $M.Remove('marker'); $M.Add('marker', 1); $M.Add('limit', 100)
    Assert-Equal 'caller can remove and re-add after return' 'marker=1&limit=100' $M.ToString()

    $MB = Get-SKYAPIRequestParameter -BoundParameters @{ first_name = 'A' } -As Body
    $MB.Add('id', 123)
    Assert-Equal 'Body hashtable accepts added keys' 'first_name,id' (($MB.Keys | Sort-Object) -join ',')

    "--- regression: the two bugs this helper replaced"
    # Get-ReConstituentRatingSource used @{} for a query string; every call sent 'System.Collections.Hashtable'.
    $Rating = Get-SKYAPIRequestParameter -BoundParameters @{ include_inactive = $true; ReturnRaw = $true } -Exclude 'ReturnRaw'
    Assert-Equal 'Get-ReConstituentRatingSource sends a real query' 'include_inactive=True' $Rating.ToString()
    Assert-Equal 'and never the hashtable literal' $false ($Rating.ToString() -like '*System.Collections*')

    # Get-SchoolCycleBySection excluded Section_ID but not the -ReturnRaw control switch.
    $Cycle = Get-SKYAPIRequestParameter -BoundParameters @{ Section_ID = 1; duration_id = 2; ReturnRaw = $true } `
                                        -Exclude 'Section_ID','ReturnRaw'
    Assert-Equal 'Get-SchoolCycleBySection does not send ReturnRaw' 'duration_id=2' $Cycle.ToString()

    "--- the roster and course inactive filters"
    # These endpoints changed their server-side default: rosters now return only active sections unless asked,
    # so a supplied value has to reach the wire. A [bool] serializes as the literal 'True', which the API takes.
    $Roster = Get-SKYAPIRequestParameter -BoundParameters @{ include_inactive = $true; ReturnRaw = $true } -Exclude 'ReturnRaw'
    Assert-Equal 'roster include_inactive reaches the query' 'include_inactive=True' $Roster.ToString()

    # Sorted, because a hashtable does not guarantee enumeration order and the helper preserves whatever it gets.
    $Course = Get-SKYAPIRequestParameter -BoundParameters @{ level_id = 229; exclude_inactive = $true } -Exclude 'ReturnRaw'
    Assert-Equal 'Get-SchoolCourse exclude_inactive reaches the query' 'exclude_inactive=True,level_id=229' `
        ((($Course.ToString() -split '&') | Sort-Object) -join ',')

    # An omitted optional [bool] is never in $PSBoundParameters, so it must not appear at all. Sending
    # 'include_inactive=False' would be harmless today but would pin a default the API is free to change.
    $Omitted = Get-SKYAPIRequestParameter -BoundParameters @{ school_year = '2022-2023' } -Exclude 'ReturnRaw'
    Assert-Equal 'an omitted include_inactive sends nothing' 'school_year=2022-2023' $Omitted.ToString()

    # $false is a supplied value and must survive, so a caller can pin the default explicitly.
    $Explicit = Get-SKYAPIRequestParameter -BoundParameters @{ include_inactive = $false } -Exclude 'ReturnRaw'
    Assert-Equal 'an explicit $false is still sent' 'include_inactive=False' $Explicit.ToString()

    [pscustomobject]@{ Output = $Stats; Pass = $Stats.Pass; Fail = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] }
$Stats = $Result | Where-Object { $_ -isnot [string] } | Select-Object -Last 1
$Total = $Stats.Pass + $Stats.Fail.Count

""
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total REQUEST-PARAMETER CASES PASSED" }
else { "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"; exit 1 }
