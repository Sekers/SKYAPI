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

    # Every transient case below reaches a retry branch, and those back off for real: 5 seconds each at
    # InvokeCount 1, which is over a minute of wall clock for a suite that asserts nothing about sleeping.
    function Start-Sleep { param($Seconds) }   # keep backoff instant

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

    "--- the nested errors/error_code body shape"
    # Every case above uses the statusCode body. Blackbaud also reports failures with the code nested at
    # errors.error_code and no statusCode anywhere, so that shape has to classify the same way. The body here
    # is a real one, returned when a write sends a value the API cannot coerce to the target type.
    $NestedErrors = @'
{"errors":{"Message":"Error converting value \"panda\" to type 'FuzzyDate'. Path 'birthdate' line 7, position 26.","error_code":500,"RawMessage":"Error converting value \"panda\" to type 'FuzzyDate'. Path 'birthdate' line 7, position 26."}}
'@
    $r = Invoke-Catcher (New-FakeError -Body $NestedErrors)
    Assert-True 'errors.error_code 500 retries' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{"errors":{"Message":"Bad Request","error_code":400}}')
    Assert-True 'errors.error_code 400 throws' $r.Threw "returned '$($r.Value)'"

    # With no error_code the whole errors object is what reaches the Switch, where it matches no case. The
    # default must throw, otherwise a failed call returns nothing and reads as a success.
    $r = Invoke-Catcher (New-FakeError -Body '{"errors":{"Message":"no code here"}}')
    Assert-True 'errors with no error_code throws' $r.Threw "returned '$($r.Value)'"

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




    "--- a 401 is three unrelated conditions, and only one of them is worth retrying"
    # Captured 2026-09-08 from two tenants. A token or subscription problem comes back in the gateway's shape,
    # carrying a top level statusCode; a permission refusal comes back in the backend's shape, carrying only
    # an errors[] array. Both reduce to the integer 401, so the handler has to look at which branch supplied
    # it. Retrying the permission case can never succeed and used to cost seven requests and six forced
    # re-authentications.
    $Perm401  = '{"errors":[{"message":"You do not have access to this route.","error_code":401,"error_name":"ServiceClientException","raw_message":"You do not have access to this route."}]}'
    $Token401 = '{"statusCode":401,"message":"The required Authorization header was missing or invalid, or the token has expired","status":401,"title":"The required Authorization header was missing or invalid, or the token has expired"}'
    $Sub401   = '{"statusCode":401,"message":"Access denied due to invalid subscription key. Make sure to provide a valid key for an active subscription.","status":401,"title":"Access denied due to invalid subscription key."}'

    # Count forced refreshes without performing any.
    $script:Refreshes = 0
    function Connect-SKYAPI { param([switch]$ForceRefresh,[switch]$ForceReauthentication) $script:Refreshes++ }

    function Invoke-401 { param($Body,$Counter)
        $script:Refreshes = 0
        $Err = New-FakeError -Body $Body -StatusCode 401
        try { $v = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 1 -MaxInvokeCount 7 -AuthRefreshCount $Counter
              return [pscustomobject]@{ Threw=$false; Value=$v; Refreshes=$script:Refreshes } }
        catch { return [pscustomobject]@{ Threw=$true; Value=$_.Exception.Message; Refreshes=$script:Refreshes } }
    }

    $c = 0
    $r = Invoke-401 $Perm401 ([ref]$c)
    Assert-True 'a permission 401 throws instead of retrying' $r.Threw "returned '$($r.Value)'"
    Assert-True 'and it does not spend a token refresh on it' ($r.Refreshes -eq 0) "refreshes=$($r.Refreshes)"

    $c = 0
    $r = Invoke-401 $Token401 ([ref]$c)
    Assert-True 'an expired-token 401 still retries' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"
    Assert-True 'and it refreshes exactly once' ($r.Refreshes -eq 1) "refreshes=$($r.Refreshes)"
    Assert-True 'and the counter records that refresh' ($c -eq 1) "counter=$c"

    # The cap. A second 401 on the same call must not buy a second refresh: the refresh mints the same
    # credential from the same refresh token, so it cannot succeed where the first failed.
    $r = Invoke-401 $Token401 ([ref]$c)
    Assert-True 'a second token 401 on the same call gives up' $r.Threw "returned '$($r.Value)'"
    Assert-True 'and spends no second refresh' ($r.Refreshes -eq 0) "refreshes=$($r.Refreshes)"

    # A bad subscription key wears the same shape as an expired token, so it gets one refresh and then stops.
    # That is the case the cap exists for: the body cannot tell us it is hopeless, but the budget still ends.
    $c = 0
    $r = Invoke-401 $Sub401 ([ref]$c)
    Assert-True 'a bad subscription key retries once' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw)"
    $r = Invoke-401 $Sub401 ([ref]$c)
    Assert-True 'and then gives up rather than looping' $r.Threw "returned '$($r.Value)'"

    # Shapes that are not the backend's keep the old behavior, which is to assume the token and retry.
    $c = 0
    $r = Invoke-401 '{"type":"urn:blackbaud:unexpected","title":"x","status":401}' ([ref]$c)
    Assert-True 'an unfamiliar 401 shape still retries once' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

    $c = 0
    $r = Invoke-401 '<html>401</html>' ([ref]$c)
    Assert-True 'a 401 with an unparseable body still retries once' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

    # Callers that pass no counter must behave exactly as before, since the parameter is optional.
    $script:Refreshes = 0
    $Err = New-FakeError -Body $Token401 -StatusCode 401
    $v = SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 1 -MaxInvokeCount 7
    Assert-True 'omitting the counter keeps the old refresh-every-time behavior' ($v -eq 'retry') "returned '$v'"

    # A permission 401 must throw even without a counter, since that decision does not depend on one.
    $Err = New-FakeError -Body $Perm401 -StatusCode 401
    $Threw = $false
    try { SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $Err -InvokeCount 1 -MaxInvokeCount 7 | Out-Null } catch { $Threw = $true }
    Assert-True 'a permission 401 throws with or without a counter' $Threw 'retried instead of throwing'
    "--- RFC 7807 problem+json, where the code is in 'status' rather than 'statusCode'"
    # These are payloads captured live from afe-edcor on 2026-09-08, not reconstructions. Before the 'status'
    # branch existed they reached the catch-all, matched no case, and threw, so a transient 500 that should
    # have been retried seven times failed on the first attempt instead.
    $Unexpected500 = '{"type":"urn:blackbaud:unexpected","title":"An error has occurred.","status":500,"trace_id":"c81b3f737a1c479a84e8979b61a1cd46","span_id":"eb3819731237a395"}'
    $Validation400 = '{"type":"urn:blackbaud:model-validation-error","title":"One or more validation errors occurred.","status":400,"detail":"The value is not valid.","trace_id":"86ac11ebd919418fbfe41a6873f399d5","span_id":"d250a0ca47951c9b"}'

    $r = Invoke-Catcher (New-FakeError -Body $Unexpected500 -StatusCode 500)
    Assert-True 'a 500 in problem+json retries instead of throwing' ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body $Validation400 -StatusCode 400)
    Assert-True 'a 400 in problem+json still throws' $r.Threw "returned '$($r.Value)'"

    # Every transient code, so the branch is not accidentally specific to 500.
    foreach ($Transient in 429,500,502,503,504)
    {
        $Body = '{"type":"urn:blackbaud:unexpected","title":"An error has occurred.","status":' + $Transient + '}'
        $r = Invoke-Catcher (New-FakeError -Body $Body -StatusCode $Transient)
        Assert-True "problem+json $Transient retries" ((-not $r.Threw) -and $r.Value -eq 'retry') "threw=$($r.Threw) value='$($r.Value)'"
    }
    # 401 is deliberately absent from this list. It is permanent only when the body says the caller lacks the
    # role, which is the backend's errors[] shape rather than this one; a 401 in any other shape is treated as
    # a possible token problem and gets one refresh. The 401 section above covers both paths.
    foreach ($Permanent in 400,403,404,415)
    {
        $Body = '{"type":"urn:blackbaud:unexpected","title":"An error has occurred.","status":' + $Permanent + '}'
        $r = Invoke-Catcher (New-FakeError -Body $Body -StatusCode $Permanent)
        Assert-True "problem+json $Permanent throws" $r.Threw "returned '$($r.Value)'"
    }

    # The guard: a body whose 'status' is not an HTTP code must not be mistaken for one. Both of these fall
    # through to the catch-all and throw, which is the safe outcome, rather than dispatching on nonsense.
    $r = Invoke-Catcher (New-FakeError -Body '{"status":"Active","name":"a record that happens to have a status"}')
    Assert-True 'a non-numeric status is not treated as an HTTP code' $r.Threw "returned '$($r.Value)'"

    $r = Invoke-Catcher (New-FakeError -Body '{"status":99}')
    Assert-True 'a numeric status outside 100-599 is ignored' $r.Threw "returned '$($r.Value)'"

    # Precedence: a body carrying both must still use statusCode, so nothing that already classified moves.
    $r = Invoke-Catcher (New-FakeError -Body '{"statusCode":404,"message":"Not Found","status":500}')
    Assert-True 'statusCode still wins over status' $r.Threw "returned '$($r.Value)' (retried, so status won)"
    "--- Retry-After: the header is the authority, the one second default is only a fallback"
    # Both response shapes are built by hand, because they are genuinely different objects and a reader
    # written for one silently finds nothing in the other. 5.1 gives a WebHeaderCollection, indexable by
    # name; 7 gives HttpResponseHeaders, which only enumerates as key/value pairs. A WebHeaderCollection
    # ALSO enumerates, but as header NAMES, so the 7-shaped loop appears to work against it and comes back
    # empty, which is indistinguishable from a response that carried no Retry-After.
    function New-RetryAfterError {
        param([string]$Value,[ValidateSet('Desktop','Core','None')][string]$Shape = 'Core')
        $Err = try { throw 'synthetic throttle' } catch { $_ }
        $Headers = switch ($Shape) {
            'Desktop' {
                $h = [System.Net.WebHeaderCollection]::new()
                if ($PSBoundParameters.ContainsKey('Value')) { $h.Add('Retry-After', $Value) }
                # The leading comma matters, for the same reason it does in Get-SKYAPIRequestParameter: a
                # WebHeaderCollection derives from NameValueCollection and so is enumerable, and returning it
                # bare unrolls it into its header NAMES. The fixture then hands the helper a string instead of
                # a collection, which fails the type check and silently exercises the wrong branch.
                ,$h
            }
            'Core' {
                # A list of key/value pairs is what HttpResponseHeaders enumerates as.
                if ($PSBoundParameters.ContainsKey('Value')) {
                    @([pscustomobject]@{ Key = 'Retry-After'; Value = @($Value) })
                } else { @([pscustomobject]@{ Key = 'Date'; Value = @('now') }) }
            }
            'None' { $null }
        }
        $Response  = [pscustomobject]@{ StatusCode = [Enum]::ToObject([System.Net.HttpStatusCode], 429); Headers = $Headers }
        $Exception = [pscustomobject]@{ Response = $Response; Message = 'synthetic throttle' }
        $Err | Add-Member -MemberType NoteProperty -Name Exception -Value $Exception -Force
        return $Err
    }

    foreach ($Shape in 'Desktop','Core')
    {
        Assert-True "$Shape : plain seconds are read from the header" ((Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '7' -Shape $Shape)) -eq 7) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '7' -Shape $Shape))'"

        Assert-True "$Shape : surrounding whitespace does not defeat it" ((Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '  3 ' -Shape $Shape)) -eq 3) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '  3 ' -Shape $Shape))'"

        Assert-True "$Shape : an absent header returns null so the caller can default" ($null -eq (Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Shape $Shape))) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Shape $Shape))'"

        Assert-True "$Shape : an unparseable header returns null rather than 0" ($null -eq (Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value 'soon' -Shape $Shape))) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value 'soon' -Shape $Shape))'"

        Assert-True "$Shape : a negative header returns null rather than a negative sleep" ($null -eq (Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '-5' -Shape $Shape))) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '-5' -Shape $Shape))'"

        # The value is server controlled and this runs inside a retry loop, so it must not be able to park a
        # script for hours.
        Assert-True "$Shape : an absurd header is capped" ((Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '86400' -Shape $Shape)) -eq 300) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value '86400' -Shape $Shape))'"

        # RFC 7231 allows an HTTP-date instead of seconds. SKY API sends seconds today; this pins the contract.
        $Future = ([datetime]::UtcNow.AddSeconds(30)).ToString('r')
        $FromDate = Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value $Future -Shape $Shape)
        Assert-True "$Shape : an HTTP-date is converted to a wait in seconds" ($FromDate -ge 25 -and $FromDate -le 31) "got '$FromDate'"

        # A date already gone means do not wait, which is 0 and NOT null; null means "no usable header".
        $Past = ([datetime]::UtcNow.AddSeconds(-30)).ToString('r')
        Assert-True "$Shape : an HTTP-date in the past is zero, not a negative or a null" ((Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value $Past -Shape $Shape)) -eq 0) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Value $Past -Shape $Shape))'"
    }

    Assert-True 'a response with no headers at all returns null' ($null -eq (Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Shape 'None'))) "got '$(Get-SKYAPIRetryAfterDelay (New-RetryAfterError -Shape 'None'))'"

    Assert-True 'a null error record returns null rather than throwing' ($null -eq (Get-SKYAPIRetryAfterDelay $null)) 'threw or returned a value'

    "--- the 429 branch sleeps for what the header asked, and falls back to one second"
    # Start-Sleep is shadowed so the wait is recorded instead of served.
    $script:Slept = @()
    function Start-Sleep { param([int]$Seconds,[int]$Milliseconds) $script:Slept += $Seconds }

    $script:Slept = @()
    $r = Invoke-Catcher (New-RetryAfterError -Value '4' -Shape 'Core')
    Assert-True 'a 429 carrying Retry-After still retries' ($r.Value -eq 'retry') "value='$($r.Value)'"
    Assert-True 'and it slept for the 4 seconds the header asked for' (($script:Slept -join ',') -eq '4') "slept '$($script:Slept -join ',')'"

    $script:Slept = @()
    $r = Invoke-Catcher (New-RetryAfterError -Shape 'Core')
    Assert-True 'a 429 with no Retry-After still retries' ($r.Value -eq 'retry') "value='$($r.Value)'"
    Assert-True 'and it falls back to the hardcoded one second' (($script:Slept -join ',') -eq '1') "slept '$($script:Slept -join ',')'"
    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
""
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { "NO CASES RAN - treating as failure"; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) ERROR-PATH CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }

