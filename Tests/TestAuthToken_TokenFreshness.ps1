# Offline tests for auth token freshness and the token file round trip. No API calls are made.
#
# Token creation stamps are written in UTC (Get-SKYAPIAccessToken uses (Get-Date).ToUniversalTime().ToString("o")),
# so every reading of them has to happen in UTC too. The rules under test:
#
#   1. Confirm-SKYAPITokenIsFresh gives the same verdict for the same instant however it is expressed:
#      as a Kind=Utc [datetime], as a Kind=Local [datetime], or as a round-trip string. The editions
#      disagree on which of those Get-SKYAPIAuthTokensFromFile hands over, so the verdict must not.
#   2. Get-SKYAPIAuthTokensFromFile returns both creation stamps as a Kind=Utc [datetime] on Windows
#      PowerShell 5.1 and on PowerShell 7 alike. 5.1 leaves JSON date strings alone while 7 deserializes
#      them, so the reader normalizes rather than inheriting whatever the edition happened to produce.
#   3. A stamp carrying a numeric offset instead of 'Z' still lands on the same UTC instant on both
#      editions. The current writer only ever emits 'Z', so this pins the contract rather than a live path.
#   4. A token file that cannot be read is reported, never returned as $null. The two ways it can fail
#      (undecryptable blob, unreadable timestamp) stop at different stages and are asserted separately.
#
# The age cases sit well clear of the limits. Testing exactly at 59 minutes or 364 days would let the
# milliseconds spent between building the value and comparing it decide the result.
#
# Results must be identical on Windows PowerShell 5.1 and PowerShell 7.x; run this file under both.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI', 'SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
    function Assert-Equal { param([string]$Name,$Expected,$Actual)
        if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

    # Render a stamp without assuming it is already a [datetime]. A bare .ToString('o') throws on a
    # [string], which would abort the run at the first type regression and hide every later case.
    function Format-Stamp { param($Value)
        if ($Value -is [datetime]) { $Value.ToString('o') } else { [string]$Value } }

    # One instant, expressed the three ways a caller can reach Confirm-SKYAPITokenIsFresh. The string is
    # what 5.1 reads out of the file, the Kind=Utc value is what 7 reads, and Kind=Local is what the
    # [datetime] parameter cast produces from the string.
    function Get-AgeForms { param([timespan]$Age)
        $Instant = [datetime]::UtcNow - $Age
        [ordered]@{
            'Kind=Utc'   = $Instant
            'Kind=Local' = $Instant.ToLocalTime()
            'string'     = $Instant.ToString('o')
        } }

    "--- access token: 59 minute limit, every input form must agree"
    foreach ($Case in @(
        @{ Label = 'brand new'    ; Age = (New-TimeSpan -Minutes 0)  ; Fresh = $true  }
        @{ Label = '58 min old'   ; Age = (New-TimeSpan -Minutes 58) ; Fresh = $true  }
        @{ Label = '61 min old'   ; Age = (New-TimeSpan -Minutes 61) ; Fresh = $false }
    ))
    {
        foreach ($Form in (Get-AgeForms $Case.Age).GetEnumerator())
        {
            Assert-Equal "access, $($Case.Label), $($Form.Key)" $Case.Fresh `
                (Confirm-SKYAPITokenIsFresh -TokenCreation $Form.Value -TokenType Access)
        }
    }

    "--- refresh token: 364 day limit, tested at 363 and 365 to stay clear of the boundary"
    foreach ($Case in @(
        @{ Label = '363 days old' ; Age = (New-TimeSpan -Days 363) ; Fresh = $true  }
        @{ Label = '365 days old' ; Age = (New-TimeSpan -Days 365) ; Fresh = $false }
    ))
    {
        foreach ($Form in (Get-AgeForms $Case.Age).GetEnumerator())
        {
            Assert-Equal "refresh, $($Case.Label), $($Form.Key)" $Case.Fresh `
                (Confirm-SKYAPITokenIsFresh -TokenCreation $Form.Value -TokenType Refresh)
        }
    }

    # The token path is a Global variable (Set-SKYAPITokensFilePath uses New-Variable -Scope Global), so
    # capture whether it existed at all, not just its value, and put it back exactly as found.
    $PreviousVar   = Get-Variable -Name 'sky_api_tokens_file_path' -Scope Global -ErrorAction SilentlyContinue
    $HadPrevious   = $null -ne $PreviousVar
    $PreviousValue = if ($HadPrevious) { $PreviousVar.Value } else { $null }

    $TempDir = Join-Path $env:TEMP ('SKYAPI_TokenFreshness_' + [guid]::NewGuid().ToString('N'))

    try
    {
        $null = New-Item -ItemType Directory -Path $TempDir -Force
        Set-Variable -Name 'sky_api_tokens_file_path' -Value (Join-Path $TempDir 'tokens.json') -Scope Global -Force

        # Exactly the pipeline Get-SKYAPINewTokens and Connect-SKYAPI use to persist tokens.
        function Write-TestTokenFile { param($Object)
            $Object | ConvertTo-Json `
                | ConvertTo-SecureString -AsPlainText -Force `
                | ConvertFrom-SecureString `
                | Out-File -FilePath $global:sky_api_tokens_file_path -Force }

        function New-TestTokenObject { param($AccessCreation,$RefreshCreation)
            $Object = [pscustomobject]@{ access_token = 'stub-access'; refresh_token = 'stub-refresh' }
            if ($PSBoundParameters.ContainsKey('AccessCreation'))  { $Object | Add-Member NoteProperty access_token_creation  $AccessCreation }
            if ($PSBoundParameters.ContainsKey('RefreshCreation')) { $Object | Add-Member NoteProperty refresh_token_creation $RefreshCreation }
            $Object }

        function Get-ThrownMessage { param([scriptblock]$Action)
            try { $null = & $Action; '' } catch { $_.Exception.Message } }

        "--- token file round trip: a 'Z' stamp survives as the same UTC instant on both editions"
        $Written = [datetime]::UtcNow.ToString('o')
        Write-TestTokenFile (New-TestTokenObject -AccessCreation $Written -RefreshCreation $Written)
        $Read = Get-SKYAPIAuthTokensFromFile
        foreach ($Field in 'access_token_creation','refresh_token_creation')
        {
            Assert-Equal "$Field is [datetime]"     'DateTime' $Read.$Field.GetType().Name
            Assert-Equal "$Field is Kind=Utc"       'Utc'      $Read.$Field.Kind
            Assert-Equal "$Field keeps its instant" $Written   (Format-Stamp $Read.$Field)
        }
        Assert-Equal 'the tokens themselves are untouched' 'stub-access' $Read.access_token

        "--- a numeric-offset stamp converts to the same UTC instant on both editions"
        # Only 'Z' is ever written today, so this pins the stated contract rather than a live path.
        Write-TestTokenFile (New-TestTokenObject -AccessCreation '2026-08-25T15:35:46.2256813+02:00' `
                                                 -RefreshCreation '2026-08-25T15:35:46.2256813+02:00')
        $Read = Get-SKYAPIAuthTokensFromFile
        Assert-Equal '+02:00 stamp is Kind=Utc'       'Utc'                          $Read.access_token_creation.Kind
        Assert-Equal '+02:00 stamp converted to UTC'  '2026-08-25T13:35:46.2256813Z' (Format-Stamp $Read.access_token_creation)
        Assert-Equal '+02:00 refresh stamp converted' '2026-08-25T13:35:46.2256813Z' (Format-Stamp $Read.refresh_token_creation)

        "--- a file with no creation stamps still reads, leaving them null"
        Write-TestTokenFile (New-TestTokenObject)
        $Read = Get-SKYAPIAuthTokensFromFile
        Assert-Equal 'read succeeds without stamps'   'stub-access' $Read.access_token
        Assert-Equal 'access_token_creation is null'  $true ($null -eq $Read.access_token_creation)
        Assert-Equal 'refresh_token_creation is null' $true ($null -eq $Read.refresh_token_creation)

        "--- an unreadable file is reported, never returned as null"
        # Fails at ConvertTo-SecureString, before any JSON or date parsing.
        'this is not an encrypted blob' | Out-File -FilePath $global:sky_api_tokens_file_path -Force
        $Message = Get-ThrownMessage { Get-SKYAPIAuthTokensFromFile }
        Assert-Equal 'undecryptable file throws' $true ($Message -like '*missing, corrupted or invalid*')

        # Fails at the timestamp parse instead, which the case above never reaches.
        foreach ($Field in 'access_token_creation','refresh_token_creation')
        {
            $Object = New-TestTokenObject -AccessCreation $Written -RefreshCreation $Written
            $Object.$Field = 'not-a-date'
            Write-TestTokenFile $Object
            $Message = Get-ThrownMessage { Get-SKYAPIAuthTokensFromFile }
            Assert-Equal "unreadable $Field throws" $true ($Message -like '*missing, corrupted or invalid*')
        }
    }
    finally
    {
        if ($HadPrevious) { Set-Variable -Name 'sky_api_tokens_file_path' -Value $PreviousValue -Scope Global -Force }
        else { Remove-Variable -Name 'sky_api_tokens_file_path' -Scope Global -Force -ErrorAction SilentlyContinue }
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
''
$Summary = if ($Result) { $Result[-1] } else { $null }
if (-not $Summary -or $Summary.Passes -eq 0) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Summary.Failures.Count -eq 0) { "ALL $($Summary.Passes) AUTH TOKEN FRESHNESS CASES PASSED" }
else { "$($Summary.Failures.Count) FAILED: $($Summary.Failures -join '; ')"; exit 1 }
