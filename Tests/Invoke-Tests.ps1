# Runs the test suite and reports one result, so validating a change is one command instead of two dozen.
#
# Offline tests run by default, under both PowerShell editions, because that is what the repository requires
# before a change is considered done. Network and live tests are opt in.
#
# A script declares what it needs with a "# TestRequires: Live" or "# TestRequires: Network" line. A script
# that declares nothing but authenticates anyway is still treated as live, so forgetting the marker keeps a
# new script OUT of the default run rather than letting it reach a real tenant unattended.
#
#   .\Tests\Invoke-Tests.ps1                       # offline, both editions
#   .\Tests\Invoke-Tests.ps1 -Edition Core          # offline, PowerShell 7 only
#   .\Tests\Invoke-Tests.ps1 -Network               # offline plus the portal checks
#   .\Tests\Invoke-Tests.ps1 -Name '*DateTime*'     # one family
#
# Runs under both Windows PowerShell 5.1 and PowerShell 7.x itself, so it can be invoked from either.

[CmdletBinding()]
param(
    # Also run scripts that reach the public Blackbaud portal. No credentials involved; safe anytime.
    [switch]$Network,

    # Also run scripts that authenticate against a real tenant. Read which tenant they point at first.
    [switch]$Live,

    [ValidateSet('Both','Desktop','Core')]
    [string]$Edition = 'Both',

    # Print every script's output, not just that of the ones that failed.
    [switch]$ShowOutput,

    # Wildcard against the script's base name.
    [string]$Name = '*'
)

$ErrorActionPreference = 'Stop'

function Get-TestRequirement
{
    param([string]$Path)

    $Text = Get-Content -LiteralPath $Path -Raw

    if ($Text -match '(?m)^#\s*TestRequires:\s*Live')    { return 'Live' }
    if ($Text -match '(?m)^#\s*TestRequires:\s*Network') { return 'Network' }

    # The backstop, and it only ever escalates: a script that authenticates is live whether it says so or not.
    if ($Text -match '(?m)^\s*(Set-SKYAPITokensFilePath|Connect-SKYAPI)\b') { return 'Live' }

    return 'Offline'
}

function Get-TestHost
{
    param([string]$Edition)

    if ($Edition -eq 'Core')
    {
        $Pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($null -eq $Pwsh) { return $null }
        return [pscustomobject]@{
            Label = 'PowerShell 7'
            Path  = $Pwsh.Source
            Args  = @('-NoProfile','-File')
        }
    }

    # Windows PowerShell exists only on Windows. -ExecutionPolicy Bypass is not optional here: a default
    # Restricted or AllSigned policy refuses -File outright when the run is started from a non-PowerShell
    # shell, and the failure looks like a test failure rather than a policy one.
    if (-not $env:SystemRoot) { return $null }
    $WinPS = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $WinPS)) { return $null }
    return [pscustomobject]@{
        Label = 'Windows PowerShell 5.1'
        Path  = $WinPS
        Args  = @('-NoProfile','-ExecutionPolicy','Bypass','-File')
    }
}

# Only Test<Category>_<Name>.ps1 is a test, which is also what keeps this runner from finding itself.
$Files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test*_*.ps1' -File |
           Where-Object { $_.BaseName -like $Name } | Sort-Object Name)

$Wanted = @('Offline')
if ($Network) { $Wanted += 'Network' }
if ($Live)    { $Wanted += 'Live' }

$Hosts = @()
foreach ($Candidate in 'Desktop','Core')
{
    if ($Edition -ne 'Both' -and $Edition -ne $Candidate) { continue }
    $Found = Get-TestHost -Edition $Candidate
    if ($Found) { $Hosts += $Found }
    else { Write-Warning "$Candidate not available on this machine; skipping that edition." }
}

if ($Hosts.Count -eq 0) { 'NO POWERSHELL EDITION AVAILABLE TO RUN TESTS'; exit 1 }

$Selected = @()
$Skipped  = @()
foreach ($File in $Files)
{
    $Requirement = Get-TestRequirement -Path $File.FullName
    if ($Wanted -contains $Requirement) { $Selected += [pscustomobject]@{ File = $File; Requirement = $Requirement } }
    else { $Skipped += [pscustomobject]@{ File = $File; Requirement = $Requirement } }
}

"Editions: $(($Hosts | ForEach-Object { $_.Label }) -join ', ')"
"Selected: $($Selected.Count) of $($Files.Count) scripts ($($Wanted -join ', '))"
""

$Results = New-Object System.Collections.ArrayList
foreach ($Entry in $Selected)
{
    foreach ($TestHost in $Hosts)
    {
        $Watch = [System.Diagnostics.Stopwatch]::StartNew()
        $ArgList = $TestHost.Args + $Entry.File.FullName

        # Windows PowerShell 5.1 wraps a native command's stderr in a NativeCommandError, which
        # $ErrorActionPreference = 'Stop' then promotes to a terminating error. One test writing anything to
        # stderr would kill the whole run: no FAIL line, no summary, and every later test skipped silently.
        # The child's exit code is the verdict here, so its stderr is output to capture, not an error to act on.
        $PreviousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try     { $Output = & $TestHost.Path @ArgList 2>&1; $Code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $PreviousPreference }
        $Watch.Stop()

        $Passed = ($Code -eq 0)
        [void]$Results.Add([pscustomobject]@{
            Name = $Entry.File.BaseName; Edition = $TestHost.Label
            Passed = $Passed; Seconds = $Watch.Elapsed.TotalSeconds; Output = $Output })

        $Verdict = if ($Passed) { 'PASS' } else { 'FAIL' }
        "  $Verdict  {0,-22} {1,-46} {2,6:N1}s" -f $TestHost.Label, $Entry.File.BaseName, $Watch.Elapsed.TotalSeconds

        if ($ShowOutput -or -not $Passed)
        {
            $Output | ForEach-Object { "         $_" }
        }
    }
}

""
foreach ($Entry in $Skipped)
{
    # Named rather than counted: a silently skipped test is how a suite starts reporting false confidence.
    "  SKIP  $($Entry.File.BaseName) (requires $($Entry.Requirement))"
}

$Failed = @($Results | Where-Object { -not $_.Passed })
$Total  = [math]::Round((($Results | Measure-Object -Property Seconds -Sum).Sum), 1)

""
if ($Results.Count -eq 0)
{
    # Still a failure, because a run that executed nothing must never look like a pass. But naming a script
    # that needs more than an offline run is a mismatch rather than a mystery, so say which switch runs it.
    if ($Skipped.Count)
    {
        $Switches = @($Skipped | ForEach-Object { "-$($_.Requirement)" } | Sort-Object -Unique) -join ' '
        "NO TESTS RAN - $($Skipped.Count) matched but were skipped. Re-run with $Switches to include them."
    }
    else { "NO TESTS RAN - nothing matched -Name '$Name'" }
    exit 1
}
if ($Failed.Count -eq 0) { "ALL $($Results.Count) TEST RUNS PASSED in ${Total}s"; exit 0 }

"$($Failed.Count) of $($Results.Count) TEST RUNS FAILED in ${Total}s:"
$Failed | ForEach-Object { "  $($_.Name) [$($_.Edition)]" }
exit 1
