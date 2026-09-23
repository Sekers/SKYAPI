# TestRequires: Live
#
# CODE FOR TESTING BLACKBAUD API RATE LIMITING
#
# Live on purpose, and deliberately abusive. The point is to trip the API's real rate limiting and record what
# comes back: the status code, whether a Retry-After header is present, and the shape of the body. A local
# stub can only confirm what the handler already assumes, so do not convert this to an offline test. The
# module's 429 HANDLING is covered offline by Tests/TestAPICallErrors_ErrorClassification.ps1; what only this
# script can show is what the API itself sends, and that the module recovers from a real one.
#
# IT MUST SEND REQUESTS CONCURRENTLY, WHICH IS WHY THIS IS NOT A SIMPLE LOOP. A single-threaded loop cannot
# reach the throttle: SKY API spends roughly 300-400 ms on a request whatever the endpoint and however small
# the response, so one request at a time tops out near 2-3 per second against a limit of about 10. Measured
# 2026-09-08; see section 6 of Research_Notes/Error-Response-Behavior.md. Runspaces rather than
# ForEach-Object -Parallel, so this still runs on Windows PowerShell 5.1.
#
# Phase 1 fires raw concurrent requests, bypassing the module, so the throttled response can be seen before
# the module's retry logic swallows it. Phase 2 then makes one ordinary module call while the throttle is
# still warm, which is the only way to exercise the 429 handler against a real 429 rather than a fake one.
#
# POINT IT AT A TEST TENANT. It deliberately exhausts a rate limit, and the limit belongs to the subscription
# key, so anything else using that key is affected while this runs.

[CmdletBinding()]
param(
    # Defaults match the layout of this repo and point at the DEVELOPMENT environment. Override for another.
    # ConfigPath is defaulted below rather than here, since Windows PowerShell 5.1 does not populate
    # $PSScriptRoot while it evaluates param defaults.
    [string]$ConfigPath,
    [string]$TokensPath = [System.IO.Path]::Combine($env:USERPROFILE, 'API_Tokens', 'SKYAPI_Development_sky_api_key.json'),

    # Requests in flight at once. 12 clears a 10 per second limit with room to spare.
    [int]$Concurrency = 12,

    # Give up rather than hammer forever if the throttle is never reached.
    [int]$MaxSeconds = 60,

    # The cheapest endpoint measured, so the burst is about request count rather than payload size.
    [string]$Path = 'school/v1/offeringtypes'
)

$ErrorActionPreference = 'Stop'

if (-not $ConfigPath) { $ConfigPath = [System.IO.Path]::Combine($PSScriptRoot, '..', '@Local Only', 'sky_api_config.json') }

# Normalize the '..' segments away rather than handing them to the provider, which resolves them against the
# caller's current location and not against the script. This decides which tenant gets hammered.
$ModuleManifest = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1'))
$ConfigPath     = [System.IO.Path]::GetFullPath($ConfigPath)
$TokensPath     = [System.IO.Path]::GetFullPath($TokensPath)
foreach ($RequiredPath in $ModuleManifest, $ConfigPath, $TokensPath)
{
    if (-not (Test-Path -LiteralPath $RequiredPath)) { throw "required path not found: $RequiredPath" }
}

Import-Module $ModuleManifest -Force

# Say which tenant this is about to hit, before it hits it.
"CONFIG      : $ConfigPath"
"TOKENS      : $TokensPath"
Set-SKYAPIConfigFilePath -Path $ConfigPath
Set-SKYAPITokensFilePath -Path $TokensPath
Connect-SKYAPI | Out-Null

# Borrow the module's own credentials for the raw phase, so both phases hit as the same caller.
$Credential = & (Get-Module SKYAPI) {
    $Config = Get-SKYAPIConfig -ConfigPath $global:sky_api_config_file_path
    $Tokens = Get-SKYAPIAuthTokensFromFile
    [pscustomobject]@{ AccessToken = $Tokens.access_token; SubscriptionKey = $Config.api_subscription_key }
}
$Headers = @{
    'Authorization'           = "Bearer $($Credential.AccessToken)"
    'bb-api-subscription-key' = $Credential.SubscriptionKey
}
$Uri = "https://api.sky.blackbaud.com/$Path"
"ENDPOINT    : $Uri"
"CONCURRENCY : $Concurrency in flight, giving up after $MaxSeconds seconds"
""

# One raw request, normalized. The two editions differ completely here: 5.1 hands back an HttpWebResponse
# whose headers are indexable and whose body needs the stream read, while 7 hands back an
# HttpResponseMessage whose headers enumerate as key/value pairs and whose body is already in ErrorDetails.
$Worker = {
    param($Uri, $Headers)

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    $Result = [ordered]@{ Ok = $false; Status = $null; RetryAfter = $null; Body = $null; AllHeaders = $null }
    try
    {
        $Response = Invoke-WebRequest -UseBasicParsing -Method Get -ContentType 'application/json' -Headers $Headers -Uri $Uri
        $Result.Ok = $true
        $Result.Status = [int]$Response.StatusCode
    }
    catch
    {
        $Err = $_
        $Response = $null
        try { $Response = $Err.Exception.Response } catch {}

        if ($Response)
        {
            try { $Result.Status = [int]$Response.StatusCode } catch {}

            # Discriminate on the type rather than trying one shape and falling back. A WebHeaderCollection
            # enumerates as header NAMES, so the key/value loop below "succeeds" against it and produces a
            # list of ": " with everything null, which then reads as a header set that simply has no
            # Retry-After. That is exactly what it did on 5.1 before this was split by type.
            try
            {
                $Pairs = @()
                if ($Response.Headers -is [System.Net.WebHeaderCollection])
                {
                    # Windows PowerShell 5.1.
                    foreach ($Key in $Response.Headers.AllKeys) { $Pairs += ('{0}: {1}' -f $Key, $Response.Headers[$Key]) }
                }
                else
                {
                    # PowerShell 7: HttpResponseHeaders, enumerates as key/value pairs. Content-Type and
                    # Content-Length live on the CONTENT headers, a separate collection, so both are read;
                    # without the second loop 7 reports fewer headers than 5.1 for the same response.
                    foreach ($Header in $Response.Headers) { $Pairs += ('{0}: {1}' -f $Header.Key, ($Header.Value -join ', ')) }
                    if ($Response.Content)
                    {
                        foreach ($Header in $Response.Content.Headers) { $Pairs += ('{0}: {1}' -f $Header.Key, ($Header.Value -join ', ')) }
                    }
                }
                if ($Pairs.Count) { $Result.AllHeaders = $Pairs -join "`n" }
            }
            catch {}

            if ($Result.AllHeaders)
            {
                $Found = [regex]::Match($Result.AllHeaders, '(?im)^Retry-After:\s*(.+)$')
                if ($Found.Success) { $Result.RetryAfter = $Found.Groups[1].Value.Trim() }
            }
        }

        if ($Err.ErrorDetails -and $Err.ErrorDetails.Message) { $Result.Body = $Err.ErrorDetails.Message }
        elseif ($Response -and $Response.PSObject.Methods['GetResponseStream'])
        {
            try
            {
                $Reader = [System.IO.StreamReader]::new($Response.GetResponseStream())
                $Result.Body = $Reader.ReadToEnd()
                $Reader.Dispose()
            }
            catch {}
        }
        if (-not $Result.Body) { $Result.Body = $Err.Exception.Message }
    }
    [pscustomobject]$Result
}

"--- phase 1: raw concurrent burst, module bypassed, until the API pushes back"
$Pool = [runspacefactory]::CreateRunspacePool(1, $Concurrency)
$Pool.Open()
$Deadline  = (Get-Date).AddSeconds($MaxSeconds)
$Watch     = [System.Diagnostics.Stopwatch]::StartNew()
$Total     = 0
$Throttled = $null
$Statuses  = @{}

try
{
    while ((Get-Date) -lt $Deadline -and $null -eq $Throttled)
    {
        $Batch = foreach ($Index in 1..$Concurrency)
        {
            $Shell = [powershell]::Create()
            $Shell.RunspacePool = $Pool
            $null = $Shell.AddScript($Worker).AddArgument($Uri).AddArgument($Headers)
            [pscustomobject]@{ Shell = $Shell; Handle = $Shell.BeginInvoke() }
        }

        foreach ($Item in $Batch)
        {
            $Returned = $null
            try   { $Returned = $Item.Shell.EndInvoke($Item.Handle) }
            catch { }
            finally { $Item.Shell.Dispose() }

            foreach ($Record in @($Returned))
            {
                if ($null -eq $Record) { continue }
                $Total++
                $Key = if ($Record.Status) { "$($Record.Status)" } else { 'no status' }
                if (-not $Statuses.ContainsKey($Key)) { $Statuses[$Key] = 0 }
                $Statuses[$Key]++
                if (-not $Record.Ok -and $null -eq $Throttled) { $Throttled = $Record }
            }
        }
    }
}
finally { $Pool.Close(); $Pool.Dispose() }

$Watch.Stop()
$Seconds = [math]::Max($Watch.Elapsed.TotalSeconds, 0.001)
"requests sent : {0} in {1:N1}s ({2:N1}/s)" -f $Total, $Seconds, ($Total / $Seconds)
foreach ($Key in ($Statuses.Keys | Sort-Object)) { "  status {0} : {1}" -f $Key, $Statuses[$Key] }
""

if ($null -eq $Throttled)
{
    "NOT RATE LIMITED after $Total requests. Nothing is proven either way."
    "Raise -Concurrency or -MaxSeconds, or try a different -Path."
    exit 1
}

"THROTTLED RESPONSE AS THE API SENT IT"
"  status      : $($Throttled.Status)"
"  Retry-After : $(if ($Throttled.RetryAfter) { $Throttled.RetryAfter } else { '(absent)' })"
"  body        : $($Throttled.Body)"
if ($Throttled.AllHeaders)
{
    "  headers     :"
    foreach ($Line in ($Throttled.AllHeaders -split "`n")) { "      $Line" }
}
""

"--- phase 2: an ordinary module call, made while the throttle is still warm"
# Whether this one actually receives a 429 and retries is timing dependent, so its passing does not prove the
# handler ran. What it does prove is the thing a caller cares about: rate limiting does not surface as a
# failure. Tests/TestAPICallErrors_ErrorClassification.ps1 is what pins the handler itself.
$Recovered = $true
$Message   = ''
try   { $null = Get-SchoolOfferingType }
catch { $Recovered = $false; $Message = $_.Exception.Message }

if ($Recovered) { "  PASS  a module call succeeded while the throttle was warm" }
else            { "  FAIL  a module call failed while the throttle was warm: $Message" }

""
if ($Recovered)
{
    "RATE LIMIT OBSERVED (status $($Throttled.Status)) AND THE MODULE ABSORBED IT"
    exit 0
}
"RATE LIMIT OBSERVED (status $($Throttled.Status)) BUT THE MODULE DID NOT ABSORB IT"
exit 1
