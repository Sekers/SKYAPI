# Offline test: the module keeps its state out of the caller's global scope. No API calls, no network.
#
# The module's state (the configuration and tokens file paths, and the WebView2 user data folder) lives in
# $script: variables that SKYAPI/SKYAPI.psm1 declares. Callers can neither read nor change them, and each import
# starts them fresh. A global would outlive Remove-Module and let any script change what the module uses.
#
# Two checks, because neither covers everything alone:
#
#   1. At run time, in a fresh runspace: import the module, call Set-SKYAPIConfigFilePath, and compare the
#      global variables before and after. A new runspace has its own global scope, so nothing this script or
#      another test left behind can hide a new variable.
#
#   2. In the source: no function reads or writes $global:, and no New-Variable or Set-Variable call names the
#      global scope. This covers Set-SKYAPITokensFilePath, which check 1 does not call: calling it by name
#      would make Invoke-Tests.ps1 classify this offline script as live.

$Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
function Assert-Equal { param([string]$Name,$Expected,$Actual)
    if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
    else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

$ModuleRoot   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', 'SKYAPI'))
$ManifestPath = [System.IO.Path]::Combine($ModuleRoot, 'SKYAPI.psd1')
$ConfigPath   = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'SKYAPI_NoGlobals_config.json')

"--- importing the module and setting a path leaves the global scope alone"
# The script runs in a local scope ($true below), so its own variables are not global either.
$Probe = {
    param($ManifestPath, $ConfigPath)
    $Before = @(Get-Variable -Scope Global | ForEach-Object { $_.Name })
    Import-Module $ManifestPath -ErrorAction Stop
    Set-SKYAPIConfigFilePath -Path $ConfigPath
    [pscustomobject]@{
        NewGlobals = @(Get-Variable -Scope Global | Where-Object { $Before -notcontains $_.Name } | ForEach-Object { $_.Name })
        Exported   = @((Get-Module SKYAPI).ExportedVariables.Keys)
        Stored     = & (Get-Module SKYAPI) { $script:sky_api_config_file_path }
        Tokens     = & (Get-Module SKYAPI) { $script:sky_api_tokens_file_path }
        UserData   = & (Get-Module SKYAPI) { $script:sky_api_user_data_path }
    }
}
$PowerShell = [PowerShell]::Create()
try
{
    $null = $PowerShell.AddScript($Probe.ToString(), $true).AddArgument($ManifestPath).AddArgument($ConfigPath)
    $Seen = @($PowerShell.Invoke())[-1]
    Assert-Equal 'the probe ran without errors' '' (@($PowerShell.Streams.Error | ForEach-Object { "$_" }) -join '; ')
    Assert-Equal 'no new global variable'                    '' ($Seen.NewGlobals -join ', ')
    Assert-Equal 'the module exports no variables'           '' ($Seen.Exported -join ', ')
    Assert-Equal 'the configuration path is in module scope' $ConfigPath $Seen.Stored
    Assert-Equal 'the tokens path starts unset'              $true ($null -eq $Seen.Tokens)
    Assert-Equal 'the user data folder is in module scope'   $true ("$($Seen.UserData)" -like '*\SKYAPI PowerShell')
}
finally
{
    $PowerShell.Dispose()
}

"--- no module source touches the global scope"
function Find-GlobalScopeUse
{
    param([System.Management.Automation.Language.Ast]$Ast)

    $Found = New-Object System.Collections.ArrayList
    foreach ($Variable in $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))
    {
        if ($Variable.VariablePath.IsGlobal) { [void]$Found.Add("line $($Variable.Extent.StartLineNumber): $($Variable.Extent.Text)") }
    }
    foreach ($Command in $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
    {
        if ($Command.GetCommandName() -notmatch '^(New|Set)-Variable$') { continue }
        $Elements = $Command.CommandElements
        for ($Index = 0; $Index -lt $Elements.Count; $Index++)
        {
            $Element = $Elements[$Index]
            if ($Element -isnot [System.Management.Automation.Language.CommandParameterAst] -or $Element.ParameterName -ne 'Scope') { continue }
            $Value = if ($Element.Argument) { $Element.Argument } elseif ($Index + 1 -lt $Elements.Count) { $Elements[$Index + 1] } else { $null }
            if ($Value -and ($Value.Extent.Text.Trim('''"') -eq 'Global')) { [void]$Found.Add("line $($Command.Extent.StartLineNumber): $($Command.Extent.Text)") }
        }
    }
    , $Found
}

# A guard that silently checks nothing is worse than no guard, so prove the search finds each form it looks for.
$Sample = [System.Management.Automation.Language.Parser]::ParseInput(
    "New-Variable -Name a -Value 1 -Scope Global`nSet-Variable -Name b -Value 1 -Scope:'Global'`n`$global:c = 1`nNew-Variable -Name d -Value 1 -Scope Script",
    [ref]$null, [ref]$null)
Assert-Equal 'the search finds all three global forms and skips script scope' 3 (Find-GlobalScopeUse $Sample).Count

$Offenders = New-Object System.Collections.ArrayList
$Files = @(Get-ChildItem -Path $ModuleRoot -Recurse -Include '*.ps1', '*.psm1')
foreach ($File in $Files)
{
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$null, [ref]$null)
    foreach ($Hit in (Find-GlobalScopeUse $Ast)) { [void]$Offenders.Add("$($File.Name) $Hit") }
}
Assert-Equal 'no global variable is read or written in the module source' '' ($Offenders -join '; ')
Assert-Equal 'module source files were searched' $true ($Files.Count -gt 50)

$Total = $Stats.Pass + $Stats.Fail.Count

''
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total MODULE-STATE CASES PASSED" }
else
{
    "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"
    ''
    'Keep module state in a $script: variable declared at the top of SKYAPI/SKYAPI.psm1, never in the global scope.'
    exit 1
}
