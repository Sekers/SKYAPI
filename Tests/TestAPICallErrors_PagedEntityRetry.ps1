# Offline tests for Get-SKYAPIPagedEntity's success and retry paths. No API calls are made.
#
# Guards the paging behavior (single page, multi-page accumulation, response_limit early return, empty
# results) and the case where a request succeeds on its final permitted retry attempt.

if (-not ('System.Web.HttpUtility' -as [type])) { Add-Type -AssemblyName System.Web }   # needed on 5.1, resolves natively on 7
Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

# Proves the "$allRecords" -> "return $allRecords" change in Get-SKYAPIPagedEntity is behavior-preserving on
# every success path, and fixes the one path where the old form was wrong (success on the final retry attempt).
$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-True { param([string]$Name,[bool]$Condition,[string]$Detail)
        if ($Condition) { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- $Detail" } }

    function Confirm-SKYAPITokenIsFresh { param($TokenCreation,$TokenType) return $true }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }
    function Start-Sleep { param($Seconds) }   # keep backoff instant

    $Auth = [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) }
    # Comma operator required: an EMPTY NameValueCollection enumerates to zero items on output, so returning it
    # bare yields nothing. (Same enumeration quirk that caused the swallowed-error bug being fixed here.)
    function New-Params { return ,([System.Web.HttpUtility]::ParseQueryString([String]::Empty)) }

    function Invoke-Paged { param($PageLimit = 100,$ResponseLimit)
        $p = New-Params; $p['marker'] = '0'
        Get-SKYAPIPagedEntity -uid 1 -url 'https://x/' -api_key 'k' -authorisation $Auth -params $p `
            -response_field 'value' -page_limit $PageLimit -response_limit $ResponseLimit -marker_type NEXT_RECORD_NUMBER
    }

    "--- single page (fewer records than the page limit, so the page loop ends immediately)"
    function Invoke-WebRequest { [pscustomobject]@{ Content = '{"value":[1,2,3]}' } }
    $r = @(Invoke-Paged -PageLimit 100)
    Assert-True 'returns all records from one page' ($r.Count -eq 3 -and ($r -join ',') -eq '1,2,3') "got $($r.Count): $($r -join ',')"

    "--- multiple pages (full page then a short page)"
    $script:Call = 0
    function Invoke-WebRequest {
        $script:Call++
        if ($script:Call -eq 1) { return [pscustomobject]@{ Content = '{"value":[1,2]}' } }
        return [pscustomobject]@{ Content = '{"value":[3]}' }
    }
    $r = @(Invoke-Paged -PageLimit 2)
    Assert-True 'accumulates across pages' ($r.Count -eq 3 -and ($r -join ',') -eq '1,2,3') "got $($r.Count): $($r -join ',')"

    "--- response_limit early-return path (pre-existing 'return', untouched)"
    $script:Call = 0
    function Invoke-WebRequest { $script:Call++; return [pscustomobject]@{ Content = '{"value":[1,2]}' } }
    $r = @(Invoke-Paged -PageLimit 2 -ResponseLimit 3)
    Assert-True 'honors response_limit and truncates' ($r.Count -eq 3) "got $($r.Count): $($r -join ',')"

    "--- empty result set"
    function Invoke-WebRequest { [pscustomobject]@{ Content = '{"value":[]}' } }
    $r = @(Invoke-Paged -PageLimit 100)
    Assert-True 'empty page returns nothing and does NOT throw' ($r.Count -eq 0) "got $($r.Count)"

    "--- THE CASE THE CHANGE FIXES: success on the final allowed attempt"
    # Fail 6 times with a transient 503, succeed on attempt 7 (== MaxInvokeCount). With the old bare '$allRecords'
    # the records were emitted and then the post-loop MaxInvokeCount check threw anyway.
    $script:Attempt = 0
    function Invoke-WebRequest {
        $script:Attempt++
        if ($script:Attempt -lt 7) {
            $e = try { throw 'transient' } catch { $_ }
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"statusCode":503,"message":"Service Unavailable"}')
            throw $e
        }
        return [pscustomobject]@{ Content = '{"value":["recovered"]}' }
    }
    $Threw = $false; $Out = $null
    try { $Out = @(Invoke-Paged -PageLimit 100) } catch { $Threw = $true; $Out = @() }
    Assert-True 'success on the final retry returns data without throwing' ((-not $Threw) -and $Out.Count -eq 1 -and $Out[0] -eq 'recovered') "threw=$Threw got=$($Out -join ',')"
    Assert-True 'it really did exhaust the retry budget (7 attempts)' ($script:Attempt -eq 7) "attempts=$($script:Attempt)"

    "--- genuine exhaustion still throws"
    $script:Attempt = 0
    function Invoke-WebRequest {
        $script:Attempt++
        $e = try { throw 'transient' } catch { $_ }
        $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"statusCode":503,"message":"Service Unavailable"}')
        throw $e
    }
    $Threw = $false
    try { Invoke-Paged -PageLimit 100 | Out-Null } catch { $Threw = $true }
    Assert-True 'all attempts failing still throws' $Threw 'returned instead of throwing'

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
""
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { "NO CASES RAN - treating as failure"; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) PAGED-RETURN CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }

