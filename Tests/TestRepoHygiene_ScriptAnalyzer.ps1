# Offline test: PSScriptAnalyzer reports no Error or ParseError finding in the module. No API calls, no network,
# no module import: the analyzer reads the source without running it.
#
# The analyzer catches mistakes the parser accepts, such as a plain-text value handed to ConvertTo-SecureString.
# ParseError is its own severity, so it is named alongside Error; without it a syntax error reports nothing here.
# The warnings are style-level and many are deliberate, so they are not checked.
#
# A finding that is intended is suppressed on its function with a SuppressMessageAttribute that carries a
# Justification, never by excluding the rule in this script, so each exception sits next to the code it excuses
# and says why. This script fails a suppression that gives no reason.
#
# Runs under PowerShell 7 only. The analysis does not depend on the edition running it, and CI installs the
# analyzer for PowerShell 7 alone. Where it cannot run, it prints a "SKIPPED:" line and exits 77, which
# Invoke-Tests.ps1 reports as a named SKIP rather than a pass, so the offline suite still needs no setup.
#
# PSSCRIPTANALYZER_VERSION, when set, names the exact version to use. The Tests workflow sets it to the version
# it installs, because the runner image ships its own copy and choosing the newest would quietly let an image
# update change the rules. Without it, the newest installed version is used. In CI, where GitHub sets CI=true,
# a missing analyzer fails rather than skips, so the check cannot quietly disappear if the install step breaks.

$Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
function Assert-Equal { param([string]$Name,$Expected,$Actual)
    if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
    else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

if ($PSVersionTable.PSEdition -ne 'Core')
{
    'SKIPPED: runs under PowerShell 7 only; the analysis does not depend on the edition running it.'
    exit 77
}

$Installed = @(Get-Module -ListAvailable -Name PSScriptAnalyzer)
$Wanted = $env:PSSCRIPTANALYZER_VERSION
$Analyzer = if ($Wanted) { $Installed | Where-Object { $_.Version -eq [version]$Wanted } | Select-Object -First 1 }
            else         { $Installed | Sort-Object Version -Descending | Select-Object -First 1 }
if (-not $Analyzer)
{
    $Missing = if ($Wanted) { "PSScriptAnalyzer $Wanted is not installed" } else { 'PSScriptAnalyzer is not installed' }
    if ($env:CI -eq 'true')
    {
        "$Missing, and CI must run this check. The Tests workflow installs it."
        exit 1
    }
    "SKIPPED: $Missing. Run Install-PSResource -Name PSScriptAnalyzer to enable this check."
    exit 77
}
Import-Module -Name PSScriptAnalyzer -RequiredVersion $Analyzer.Version -ErrorAction Stop
"PSScriptAnalyzer $($Analyzer.Version)"

$ModuleRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI'))

# A guard that silently checks nothing is worse than no guard, so prove the analyzer reports the rule this
# module's suppressions exist for.
"--- the analyzer reports what it is expected to"
$Probe = @(Invoke-ScriptAnalyzer -ScriptDefinition '$Secure = ConvertTo-SecureString -String ''x'' -AsPlainText -Force' -Severity Error)
Assert-Equal 'a plain-text ConvertTo-SecureString is an Error' 'PSAvoidUsingConvertToSecureStringWithPlainText' (($Probe | ForEach-Object RuleName) -join ', ')

$Broken = @(Invoke-ScriptAnalyzer -ScriptDefinition 'function f { if ($true { } }' -Severity Error, ParseError)
Assert-Equal 'a syntax error is reported' $true ($Broken.Count -gt 0)

"--- the module has no Error or ParseError finding"
$Findings = @(Invoke-ScriptAnalyzer -Path $ModuleRoot -Recurse -Severity Error, ParseError)
Assert-Equal 'no unsuppressed Error or ParseError finding' '' (($Findings | ForEach-Object { '{0}:{1} {2}' -f $_.ScriptName, $_.Line, $_.RuleName }) -join '; ')

"--- every suppression says why"
# -SuppressedOnly also returns parse errors, which are not suppressions, so keep only the suppression records.
$Suppressed = @(Invoke-ScriptAnalyzer -Path $ModuleRoot -Recurse -SuppressedOnly |
    Where-Object { $_ -is [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.SuppressedRecord] })
$NoReason = @($Suppressed | Where-Object { @($_.Suppression | Where-Object { [string]::IsNullOrWhiteSpace($_.Justification) }).Count })
Assert-Equal 'every suppression carries a Justification' '' (($NoReason | ForEach-Object { '{0}:{1} {2}' -f $_.ScriptName, $_.Line, $_.RuleName }) -join '; ')

$Total = $Stats.Pass + $Stats.Fail.Count

''
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total SCRIPT-ANALYZER CASES PASSED ($($Suppressed.Count) suppressed, each with a reason)" }
else
{
    "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"
    ''
    'Fix the finding. If it is intended, suppress it on its function with a SuppressMessageAttribute that'
    'carries a Justification, rather than excluding the rule here.'
    exit 1
}
