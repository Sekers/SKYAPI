# Offline tests for SKY API error handling. No API calls are made; failures are synthesized.
#
# Covers the class of bug where a failed call looked like a successful one: an error response carrying no
# parseable body left the status-code Switch with nothing to dispatch on, so SKYAPICatchInvokeErrors
# returned without throwing and the entity functions fell through returning nothing.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    # Mutate a hashtable rather than assigning to $script:/$global: vars - inside "& (Get-Module ...) {}" the
    # $script: scope is the MODULE's, so counters assigned there silently vanish and failures go uncounted.
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-True { param([string]$Name,[bool]$Condition,[string]$Detail)
        if ($Condition) { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- $Detail" } }

    # Build an ErrorRecord whose ErrorDetails.Message is whatever we want (or absent entirely), optionally
    # carrying an HTTP response so the status-code fallback has something to read.
    #
    # The response is a stub rather than a real one because the exception type differs by edition
    # (WebException on 5.1, HttpResponseException on 7) and neither is convenient to fabricate. The module
    # reads .Exception.Response.StatusCode duck-typed for exactly this reason, so a stub exercises the same
    # path on both. Attached with Add-Member since ErrorRecord.Exception is read-only.
    function New-FakeError {
        param([string]$Body,[int]$StatusCode)
        $Err = try { throw 'synthetic transport failure' } catch { $_ }
        if ($PSBoundParameters.ContainsKey('Body')) { $Err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body) }
        if ($PSBoundParameters.ContainsKey('StatusCode')) {
            # [Enum]::ToObject, not a cast. PowerShell's int-to-enum CAST validates against the named members,
            # and .NET Framework 4.x has no name for 429, so [System.Net.HttpStatusCode]429 throws on Windows
            # PowerShell 5.1 and the stub would silently carry a null status. The CLR itself has no such
            # restriction, so a real 5.1 response does hand back an unnamed 429 - which is what this builds.
            $Response  = [pscustomobject]@{ StatusCode = [Enum]::ToObject([System.Net.HttpStatusCode], $StatusCode) }
            $Exception = [pscustomobject]@{ Response = $Response; Message = 'synthetic http failure' }
            $Err | Add-Member -MemberType NoteProperty -Name Exception -Value $Exception -Force
        }
        return $Err
    }

    function Invoke-Catcher {
        param($Err)
        try { $r = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 1 -MaxInvokeCount 7
              return [pscustomobject]@{ Threw = $false; Value = $r } }
        catch { return [pscustomobject]@{ Threw = $true; Value = $_.Exception.Message } }
    }

    "--- SKYAPICatchInvokeErrors must never return silently on failure"
    $r = Invoke-Catcher (New-FakeError)
    Assert-True 'no ErrorDetails at all -> throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body $null)
    Assert-True 'null ErrorDetails.Message -> throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '')
    Assert-True 'empty ErrorDetails.Message -> throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '   ')
    Assert-True 'whitespace ErrorDetails.Message -> throws' $r.Threw "returned '$($r.Value)'"

    # No HTTP response on this one, so there is no status code to fall back to and nothing to classify.
    $r = Invoke-Catcher (New-FakeError -Body '<html>502 Bad Gateway</html>')
    Assert-True 'non-JSON body with no response -> throws (catch is reachable)' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '"just a json string"')
    Assert-True 'JSON that is not an error object -> throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{}')
    Assert-True 'empty JSON object -> throws' $r.Threw "returned '$($r.Value)'"

    "--- an unusable body still classifies when the response carries a status code"
    # A gateway failure typically returns an HTML page (or nothing) rather than the API's JSON error object.
    # Classifying purely on the body meant these threw immediately, so a transient 502 from the edge was
    # never retried while the identical failure carrying a JSON body was.
    foreach ($Transient in 429,500,502,503,504)
    {
        $r = Invoke-Catcher (New-FakeError -Body "<html>$Transient</html>" -StatusCode $Transient)
        Assert-True "HTML $Transient retries via the status code" ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

        $r = Invoke-Catcher (New-FakeError -StatusCode $Transient)
        Assert-True "bodiless $Transient retries via the status code" ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"
    }

    # Permanent failures must not start retrying just because the fallback can now read them.
    foreach ($Permanent in 400,401,403,404)
    {
        $r = Invoke-Catcher (New-FakeError -Body "<html>$Permanent</html>" -StatusCode $Permanent)
        Assert-True "HTML $Permanent still throws" $r.Threw "returned '$($r.Value)'"
    }

    # The fallback must not override a body the module can already classify.
    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":404,"message":"Not Found"}' -StatusCode 502)
    Assert-True 'a parseable body wins over the response status code' $r.Threw "returned '$($r.Value)'"

    # And the budget still applies on the fallback path.
    $Err = New-FakeError -Body '<html>502</html>' -StatusCode 502
    $Threw = $false
    try { SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 7 -MaxInvokeCount 7 | Out-Null } catch { $Threw = $true }
    Assert-True 'HTML 502 throws once the retry budget is exhausted' $Threw 'kept retrying past MaxInvokeCount'

    "--- existing classification behavior must be unchanged"
    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":400,"message":"Bad Request"}')
    Assert-True '400 still throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":403,"message":"Forbidden"}')
    Assert-True '403 still throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":404,"message":"Not Found"}')
    Assert-True '404 still throws' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":429,"message":"Too Many Requests"}')
    Assert-True '429 still retries (transient handling intact)' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

    foreach ($Transient in 500,502,503,504)
    {
        $r = Invoke-Catcher (New-FakeError -Body "{`"statusCode`":$Transient,`"message`":`"transient`"}")
        Assert-True "$Transient retries" ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"
    }

    # Transient codes must still give up rather than retry forever once the attempt budget is spent.
    foreach ($Transient in 429,500,502,503,504)
    {
        $Err = New-FakeError -Body "{`"statusCode`":$Transient,`"message`":`"transient`"}"
        $Threw = $false
        try { SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 7 -MaxInvokeCount 7 | Out-Null } catch { $Threw = $true }
        Assert-True "$Transient throws once the retry budget is exhausted" $Threw 'kept retrying past MaxInvokeCount'
    }

    "--- entity functions must throw rather than return nothing"
    # Stub the HTTP call so it fails with an opaque error (no ErrorDetails), the case that used to go silent.
    function Invoke-RestMethod { throw 'synthetic transport failure' }
    function Invoke-WebRequest { throw 'synthetic transport failure' }
    function Confirm-SKYAPITokenIsFresh { param($TokenCreation,$TokenType) return $true }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }

    $Auth = [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) }
    $Params = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

    foreach ($Fn in 'Get-SKYAPIUnpagedEntity','Get-SKYAPIPagedEntity','Remove-SKYAPIEntity','Submit-SKYAPIEntity','Update-SKYAPIEntity')
    {
        $Threw = $false; $Returned = 'n/a'
        try {
            $Out = switch ($Fn) {
                'Get-SKYAPIPagedEntity' { & $Fn -uid 1 -url 'https://x/' -api_key 'k' -authorisation $Auth -params $Params -page_limit 100 -marker_type NEXT_RECORD_NUMBER }
                default                 { & $Fn -uid 1 -url 'https://x/' -api_key 'k' -authorisation $Auth -params $Params }
            }
            $Returned = if ($null -eq $Out) { '<null>' } else { "$Out" }
        } catch { $Threw = $true }
        Assert-True "$Fn throws on an opaque failure" $Threw "returned $Returned instead of throwing"
    }

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
""
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { "NO CASES RAN - treating as failure"; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) ERROR-PATH CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }

