# Offline test for the module manifest's export lists. No API calls, no network.
#
# A check is needed because the failure mode is silent in both directions. Every SKYAPI/Functions/*.ps1 is
# dot-sourced automatically, so a new public function loads fine and works when called from inside the
# module, but stays invisible to callers unless it is also named in FunctionsToExport. Nothing errors, the
# module imports cleanly, and the gap only shows up when a user reports that the function does not exist.
# The reverse is just as quiet: a name left in the manifest after its file is renamed or removed exports
# nothing at all.
#
# Aliases work the same way through AliasesToExport, so they are checked the same way.
#
# Three functions are declared without a file of their own because they are defined directly in
# SKYAPI/SKYAPI.psm1 rather than under Functions/. That is why the manifest is compared against what the
# module ACTUALLY exports rather than against the file listing alone; a file-only comparison would report
# those three as phantom entries forever.

$ModuleRoot   = [System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI')
$ManifestPath = [System.IO.Path]::Combine($ModuleRoot, 'SKYAPI.psd1')

Import-Module $ManifestPath -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
function Assert-Equal { param([string]$Name,$Expected,$Actual)
    if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
    else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

$Module    = Get-Module SKYAPI
$Manifest  = Import-PowerShellDataFile -Path $ManifestPath
$Declared  = @($Manifest.FunctionsToExport)
$Exported  = @($Module.ExportedFunctions.Keys)
$Aliases   = @($Manifest.AliasesToExport)
$ExpAlias  = @($Module.ExportedAliases.Keys)
$FileNames = @(Get-ChildItem -Path ([System.IO.Path]::Combine($ModuleRoot, 'Functions', '*.ps1')) | ForEach-Object BaseName)

"--- every public function file is reachable by a caller ($($FileNames.Count) files, $($Declared.Count) declared)"
# The AGENTS.md trap: the file loads, the function works inside the module, and callers cannot see it.
$Unlisted = @($FileNames | Where-Object { $Declared -notcontains $_ } | Sort-Object)
Assert-Equal 'every Functions/*.ps1 is named in FunctionsToExport' '' ($Unlisted -join ', ')

$NotExported = @($FileNames | Where-Object { $Exported -notcontains $_ } | Sort-Object)
Assert-Equal 'every Functions/*.ps1 is actually exported' '' ($NotExported -join ', ')

"--- the manifest declares nothing it cannot deliver"
# A name that survives a rename or deletion exports nothing, and the module still imports without complaint.
$Phantom = @($Declared | Where-Object { $Exported -notcontains $_ } | Sort-Object)
Assert-Equal 'every declared function is exported' '' ($Phantom -join ', ')

$Undeclared = @($Exported | Where-Object { $Declared -notcontains $_ } | Sort-Object)
Assert-Equal 'nothing is exported that the manifest does not declare' '' ($Undeclared -join ', ')

"--- aliases follow the same rule"
$PhantomAlias = @($Aliases | Where-Object { $ExpAlias -notcontains $_ } | Sort-Object)
Assert-Equal 'every declared alias is exported' '' ($PhantomAlias -join ', ')

$UndeclaredAlias = @($ExpAlias | Where-Object { $Aliases -notcontains $_ } | Sort-Object)
Assert-Equal 'nothing is exported as an alias that the manifest does not declare' '' ($UndeclaredAlias -join ', ')

"--- the export lists stay explicit"
# A wildcard would make every check above vacuous, and it costs callers real time: PowerShell has to load the
# module to answer "does it have this command" instead of reading the manifest.
$Wildcarded = @(($Declared + $Aliases) | Where-Object { $_ -match '[\*\?]' })
Assert-Equal 'no wildcard in FunctionsToExport or AliasesToExport' '' ($Wildcarded -join ', ')

"--- the manifest itself is valid"
$ManifestError = ''
try { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop | Out-Null }
catch { $ManifestError = $_.Exception.Message }
Assert-Equal 'Test-ModuleManifest accepts the manifest' '' $ManifestError

# A guard that silently checks nothing is worse than no guard, so prove the enumeration found something.
"--- the scan actually reached the module"
Assert-Equal 'function files were found' $true ($FileNames.Count -gt 50)

$Total = $Stats.Pass + $Stats.Fail.Count

''
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total MANIFEST-EXPORT CASES PASSED" }
else
{
    "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"
    ''
    'A new public function needs its own entry in FunctionsToExport in SKYAPI/SKYAPI.psd1.'
    exit 1
}
