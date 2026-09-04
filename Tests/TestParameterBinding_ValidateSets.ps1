# Offline tests for parameter binding and function control flow. No API calls are made; the HTTP helper is
# stubbed inside the module scope.
#
# Unrelated classes of bug, each about a function doing something the caller cannot see:
#
#   1. -ReturnRaw ending its branch with 'continue' in a function that owns no loop. PowerShell resolves an
#      unmatched loop-control keyword against the CALLER's loop, so the raw branch skipped the rest of the
#      caller's iteration AND aborted the caller's assignment mid-statement - the raw response escaped to the
#      output stream instead of landing in the caller's variable. Measured identically on 7 and 5.1.
#
#   2. living_status accepting only a subset of the real values. 'Remarried' is offered by the web GUI but is
#      missing from the endpoint's published field description, so the accepted list is worth pinning down in
#      a test rather than left to whichever source someone reads next.
#
#   3. A filter declared as the wrong kind of parameter. The rosters take include_inactive and courses take
#      exclude_inactive; each is a [bool] API field rather than a [switch], and having the wrong one of the
#      pair would silently invert the result.
#
#   4. More than one parameter per set taking pipeline input by value, which lets a piped record land in the
#      parameters it has no property for. See the cases at the bottom for what that put on the wire.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    # Mutate a hashtable rather than assigning to $script: vars - inside "& (Get-Module ...) {}" the $script:
    # scope is the MODULE's, so counters assigned there vanish and failures would go uncounted.
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }

    function Assert-Equal { param([string]$Name,$Expected,$Actual)
        if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

    # --- stubs (child scope shadows the real module functions) ---
    function Get-SKYAPIConfig { param($ConfigPath) [pscustomobject]@{ api_subscription_key = 'stub' } }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }
    function Get-SKYAPIUnpagedEntity {
        param($uid,$url,$end,$api_key,$authorisation,$params,$response_field,[switch]$ReturnRaw)
        if ($ReturnRaw) { return '{"value":[{"id":1}]}' }
        return @([pscustomobject]@{ id = 1 })
    }

    "--- -ReturnRaw must not touch the caller's loop"
    # The regression: these two functions own no loop, so a bare 'continue' in their raw branch resolves
    # against whatever loop the CALLER is in.
    foreach ($FunctionName in 'Get-SchoolSession','Get-SchoolAdmissionCandidate')
    {
        $Reached  = 0
        $Captured = @()

        foreach ($Iteration in 1,2,3)
        {
            $Raw = & $FunctionName -ReturnRaw
            # Neither of these lines runs if the function leaks a 'continue' into this loop.
            $Captured += "$Raw"
            $Reached++
        }

        Assert-Equal "$FunctionName -ReturnRaw leaves the caller's loop intact" 3 $Reached
        Assert-Equal "$FunctionName -ReturnRaw assigns into the caller's variable" '{"value":[{"id":1}]}' $Captured[0]
        Assert-Equal "$FunctionName -ReturnRaw returns the raw response every iteration" 3 @($Captured | Where-Object { $_ -eq '{"value":[{"id":1}]}' }).Count
    }

    # A statement after the call must run at top level too, not just inside a loop.
    $AfterCall = 'not-set'
    $null = Get-SchoolSession -ReturnRaw
    $AfterCall = 'set'
    Assert-Equal 'a statement after a raw call still runs outside a loop' 'set' $AfterCall

    "--- parsed output is unchanged by the fix"
    foreach ($FunctionName in 'Get-SchoolSession','Get-SchoolAdmissionCandidate')
    {
        $Parsed = & $FunctionName
        Assert-Equal "$FunctionName parsed output still returns records" 1 @($Parsed).Count
        Assert-Equal "$FunctionName parsed output is not the raw string" $false ($Parsed -is [string])
    }

    # And the normal path was never the broken one; confirm it too, so a future edit cannot quietly swap them.
    $Reached = 0
    foreach ($Iteration in 1,2,3) { $null = Get-SchoolSession; $Reached++ }
    Assert-Equal 'parsed calls leave the caller loop intact' 3 $Reached

    "--- living_status accepts every real value, and nothing else"
    $LivingStatusSet = ((Get-Command Update-SchoolUser).Parameters['living_status'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues

    foreach ($Value in 'Single','Married','Separated','Divorced','Widowed','Partner','Remarried')
    {
        Assert-Equal "'$Value' is an accepted living_status" $true ($LivingStatusSet -contains $Value)
    }
    Assert-Equal 'no extra living_status values crept in' 7 $LivingStatusSet.Count

    # A misspelling must be caught here, at bind time, rather than sent.
    $Rejected = $false
    try   { $null = Update-SchoolUser -User_ID 1 -living_status 'Marrieed' -ErrorAction Stop }
    catch { $Rejected = $true }
    Assert-Equal "a misspelled living_status is rejected by the binder" $true $Rejected

    "--- the roster and course inactive filters are declared as API fields, not control switches"
    # [bool] rather than [switch] is the repo convention for a real query field: Get-SKYAPIRequestParameter
    # sends whatever is bound, and a [switch] would put 'True'/'False' on the wire for the shorthand -Name form
    # while reading as a client-side control everywhere else in the module. A caller writes -include_inactive $true.
    foreach ($Function in 'Get-SchoolAcademicRoster','Get-SchoolActivityRoster','Get-SchoolAdvisoryRoster','Get-SchoolAthleticRoster')
    {
        $Parameter = (Get-Command $Function).Parameters['include_inactive']
        Assert-Equal "$Function declares include_inactive"     $true             ($null -ne $Parameter)
        Assert-Equal "$Function types include_inactive [bool]" 'System.Boolean'  $Parameter.ParameterType.FullName
    }

    $ExcludeInactive = (Get-Command Get-SchoolCourse).Parameters['exclude_inactive']
    Assert-Equal 'Get-SchoolCourse declares exclude_inactive'     $true             ($null -ne $ExcludeInactive)
    Assert-Equal 'Get-SchoolCourse types exclude_inactive [bool]' 'System.Boolean'  $ExcludeInactive.ParameterType.FullName

    # The rosters filter sections in; courses filter them out. Getting these backwards silently inverts the
    # result, so pin that each function has only the one the API actually accepts.
    Assert-Equal 'Get-SchoolCourse has no include_inactive' $true ($null -eq (Get-Command Get-SchoolCourse).Parameters['include_inactive'])
    Assert-Equal 'Get-SchoolAcademicRoster has no exclude_inactive' $true ($null -eq (Get-Command Get-SchoolAcademicRoster).Parameters['exclude_inactive'])

    "--- at most one parameter per set may take pipeline input by value"
    # PowerShell offers a piped record to EVERY ValueFromPipeline parameter, and one that is not bound some
    # other way takes the WHOLE record, string-coerced. With several of them, piping
    # [pscustomobject]@{school_year='2022-2023'} into a roster function also sent last_modified and
    # section_ids as the literal text '@{school_year=2022-2023}', and piping a plain string set all three at
    # once. Get-SchoolUserAuditByRole states the rule in a comment on its own parameter; this pins it for
    # every function, because the way it spread in the first place was a copied parameter block.
    $ByValueOffenders = foreach ($Command in (Get-Module SKYAPI).ExportedFunctions.Values)
    {
        foreach ($Set in $Command.ParameterSets)
        {
            $ByValue = @($Set.Parameters | Where-Object { $_.ValueFromPipeline })
            if ($ByValue.Count -gt 1) { "$($Command.Name)[$($Set.Name)]: $($ByValue.Name -join '+')" }
        }
    }
    Assert-Equal 'no function takes pipeline input by value on more than one parameter per set' '' ($ByValueOffenders -join ' | ')

    # The other direction: the identity parameter must KEEP it, or '3294459 | Get-SchoolUser' stops working.
    foreach ($Keeper in @(
        @{ Function = 'Get-SchoolUser';                Parameter = 'User_ID' }
        @{ Function = 'Get-SchoolAssignmentByStudent'; Parameter = 'Student_ID' }
        @{ Function = 'Get-SchoolUserByRole';          Parameter = 'roles' }
        @{ Function = 'Get-SchoolTypeTableValue';      Parameter = 'tableName' }   # one per set, so both sets keep one
    ))
    {
        $Attribute = (Get-Command $Keeper.Function).Parameters[$Keeper.Parameter].Attributes |
                         Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline }
        Assert-Equal "$($Keeper.Function) still binds $($Keeper.Parameter) by value" $true ($null -ne $Attribute)
    }

    # A filter-only function has no identity parameter, so nothing should bind by value at all.
    foreach ($FilterOnly in 'Get-SchoolAcademicRoster','Get-SchoolActivityRoster','Get-SchoolAdvisoryRoster','Get-SchoolAthleticRoster','Get-SchoolCourse')
    {
        $ByValue = @((Get-Command $FilterOnly).Parameters.Values | Where-Object {
                         $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline } })
        Assert-Equal "$FilterOnly binds nothing by value" 0 $ByValue.Count
    }

    [pscustomobject]@{ Pass = $Stats.Pass; Fail = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] }
$Stats = $Result | Where-Object { $_ -isnot [string] } | Select-Object -Last 1
$Total = $Stats.Pass + $Stats.Fail.Count

""
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total BINDING/CONTROL-FLOW CASES PASSED" }
else { "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"; exit 1 }
