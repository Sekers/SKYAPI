# Offline tests for per-record request isolation across a pipeline. No API calls are made; the HTTP helpers
# and the reads they use are stubbed inside the module scope.
#
# Covers the class of bug where a pipeline record inherited a field from the record before it. PowerShell
# rebinds parameter VARIABLES on every record (an optional parameter the new record omits goes back to its
# type default) but leaves the previous record's entry in $PSBoundParameters, and the write functions build
# their request from $PSBoundParameters. Piping two users where only the first set middle_name therefore
# wrote that middle name to both. Reproduces on PowerShell 7 and Windows PowerShell 5.1 alike, so these
# cases are worth running on both.
#
# The three things every write function must get right:
#   1. A field one record supplies must not appear in the next record's request.
#   2. A field given on the COMMAND LINE applies to every record and must survive.
#   3. A value the record really did supply must be sent, including an explicit empty string.
#
# Also covered here, because it produces the same visible symptom by a different mechanism: a function that
# declares ValueFromPipeline on more than one parameter. The binder offers the record to every one of them,
# so a parameter the record has no property for can be bound to the WHOLE record instead. See the
# New-SchoolEventCategory cases below.

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
    # Every request body/query is recorded so each record's request can be inspected separately.
    $script:Sent = New-Object System.Collections.ArrayList

    function Add-Sent { param($params)
        $Copy = @{}
        foreach ($k in $params.Keys) { $Copy[$k] = $params[$k] }
        [void]$script:Sent.Add($Copy) }

    function Get-SKYAPIConfig { param($ConfigPath) [pscustomobject]@{ api_subscription_key = 'stub' } }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end,$endUrl) Add-Sent $params; return $params['id'] }
    function Submit-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end) Add-Sent $params; return $params }
    function Remove-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end) Add-Sent $params; return $null }
    # Type table lookups must never veto a value in these tests; an empty table means "unreadable", which
    # Confirm-SKYAPITypeTableValue treats as "skip validation".
    function Get-SchoolTypeTableValue { param($tableName,$includeInactive) return @() }
    function Get-SchoolUserAddress { param($User_ID) return @() }
    function Get-SchoolUserPhone { param($User_ID) return @() }

    function Reset-Sent { $script:Sent = New-Object System.Collections.ArrayList }
    # Field as sent for record $Index, or '<absent>'. Distinguishing absent from empty is the whole point.
    function Get-SentField { param([int]$Index,[string]$Field)
        if ($Index -ge $script:Sent.Count) { return '<no such request>' }
        $Body = $script:Sent[$Index]
        if (-not $Body.ContainsKey($Field)) { return '<absent>' }
        return "$($Body[$Field])" }

    "--- Update-SchoolUser: a field from one record must not leak into the next"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 101; middle_name = 'Alpha' }
        [pscustomobject]@{ User_ID = 102; first_name  = 'Bob'   }
    ) | Update-SchoolUser

    Assert-Equal 'both records were sent'            2         $script:Sent.Count
    Assert-Equal 'record 1 sends its own middle_name' 'Alpha'  (Get-SentField 0 'middle_name')
    Assert-Equal 'record 2 does NOT inherit middle_name' '<absent>' (Get-SentField 1 'middle_name')
    Assert-Equal 'record 2 sends its own first_name'  'Bob'     (Get-SentField 1 'first_name')
    Assert-Equal 'record 1 has no first_name'         '<absent>' (Get-SentField 0 'first_name')
    Assert-Equal 'record 1 id'                        '101'     (Get-SentField 0 'id')
    Assert-Equal 'record 2 id'                        '102'     (Get-SentField 1 'id')

    "--- a command-line value applies to every record"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 201; middle_name = 'Alpha' }
        [pscustomobject]@{ User_ID = 202 }
    ) | Update-SchoolUser -greeting 'Hi'

    Assert-Equal 'command-line field on record 1' 'Hi'        (Get-SentField 0 'greeting')
    Assert-Equal 'command-line field on record 2' 'Hi'        (Get-SentField 1 'greeting')
    Assert-Equal 'record 2 still does not inherit middle_name' '<absent>' (Get-SentField 1 'middle_name')

    "--- a value the record really supplied is sent, empty string included"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 301; middle_name = 'Alpha' }
        [pscustomobject]@{ User_ID = 302; middle_name = ''      }
    ) | Update-SchoolUser
    # '' is a legitimate value the API may reject on its own terms; the module must not silently drop it,
    # and it must not be confused with the previous record's value.
    Assert-Equal 'explicit empty string is still sent' '' (Get-SentField 1 'middle_name')
    Assert-Equal 'and the key is present'              $true ($script:Sent[1].ContainsKey('middle_name'))

    "--- non-pipeline calls are unaffected"
    Reset-Sent
    $null = Update-SchoolUser -User_ID 401 -middle_name 'Alpha' -first_name 'Bob'
    Assert-Equal 'direct call keeps every field' 'first_name,id,middle_name' (($script:Sent[0].Keys | Sort-Object) -join ',')

    Reset-Sent
    $null = Update-SchoolUser -User_ID 402,403 -middle_name 'Alpha'
    Assert-Equal 'an ID array is still one request per ID' 2 $script:Sent.Count
    Assert-Equal 'and each request carries its own ID' '402,403' "$(Get-SentField 0 'id'),$(Get-SentField 1 'id')"
    Assert-Equal 'and both carry the field' 'Alpha,Alpha' "$(Get-SentField 0 'middle_name'),$(Get-SentField 1 'middle_name')"

    "--- Update-SchoolUserAddress: required IDs are mapped and optional fields stay isolated"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 410; Address_ID = 510; type_id = 610; line_one = 'First'; region = 'North' }
        [pscustomobject]@{ User_ID = 420; Address_ID = 520; type_id = 620; line_one = 'Second' }
    ) | Update-SchoolUserAddress
    Assert-Equal 'both address records were sent' 2 $script:Sent.Count
    Assert-Equal 'address IDs map to body id' '510,520' "$(Get-SentField 0 'id'),$(Get-SentField 1 'id')"
    Assert-Equal 'user IDs remain in the body' '410,420' "$(Get-SentField 0 'user_id'),$(Get-SentField 1 'user_id')"
    Assert-Equal 'record 2 keeps its required type_id' '620' (Get-SentField 1 'type_id')
    Assert-Equal 'record 2 keeps its required line_one' 'Second' (Get-SentField 1 'line_one')
    Assert-Equal 'record 2 does not inherit region' '<absent>' (Get-SentField 1 'region')
    Assert-Equal 'Address_ID is not sent under its parameter name' '<absent>' (Get-SentField 0 'Address_ID')
    Assert-Equal 'Validate is not sent to the API' '<absent>' (Get-SentField 0 'Validate')

    "--- array and nested-object fields do not leak either"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 501; races = @('White'); locker = '1234' }
        [pscustomobject]@{ User_ID = 502 }
    ) | Update-SchoolUser
    # races used to be doubly wrong: the stale key survived, and the wrapper then rebuilt it from the RESET
    # variable, so record 2 was sent an empty array rather than nothing at all.
    Assert-Equal 'record 2 does not inherit races'  '<absent>' (Get-SentField 1 'races')
    Assert-Equal 'record 2 does not inherit locker' '<absent>' (Get-SentField 1 'locker')
    Assert-Equal 'record 1 still wraps races'       1          @($script:Sent[0]['races']).Count
    Assert-Equal 'record 1 races is wrapped as an object' 'White' $script:Sent[0]['races'][0]['race_type']
    Assert-Equal 'record 1 locker string became an object' '1234' $script:Sent[0]['locker']['number']

    "--- New-SchoolEventCategory: by-value pipeline binding must survive the filter"
    # -description binds ValueFromPipeline, so a bare-string record exposes no property for the
    # by-property-name rule to see. Dropping it would send a request with no description at all.
    # -public is mandatory here (and gates the dynamic -roles parameter), so it is supplied on the command
    # line, which also exercises the command-line rule alongside the by-value one.
    Reset-Sent
    $null = 'Category A','Category B' | New-SchoolEventCategory -public $true
    Assert-Equal 'both bare-string records were sent' 2 $script:Sent.Count
    Assert-Equal 'record 1 keeps its by-value description' 'Category A' (Get-SentField 0 'description')
    Assert-Equal 'record 2 keeps its by-value description' 'Category B' (Get-SentField 1 'description')
    Assert-Equal 'record 2 keeps the command-line public' 'True' (Get-SentField 1 'public')

    Reset-Sent
    $null = @(
        [pscustomobject]@{ description = 'Category C'; calendar_url = 'https://example.test/c' }
        [pscustomobject]@{ description = 'Category D' }
    ) | New-SchoolEventCategory -public $true
    Assert-Equal 'record 1 kept calendar_url' 'https://example.test/c' (Get-SentField 0 'calendar_url')
    Assert-Equal 'record 2 kept its own description' 'Category D' (Get-SentField 1 'description')

    # Regression for the multi-ValueFromPipeline defect. This function used to declare ValueFromPipeline on
    # description, calendar_url, public and its three dynamic parameters. With several parameters accepting
    # by value, the binder tried them all against the same record: a record with no calendar_url property
    # bound description by property name and then handed the WHOLE record to calendar_url by value,
    # stringified as '@{description=Category D}' and sent to the API as the calendar URL. Only description
    # takes ValueFromPipeline now, so an absent property stays absent.
    Assert-Equal 'record 2 does not get the whole record as calendar_url' '<absent>' (Get-SentField 1 'calendar_url')

    "--- New-SchoolUserPhone: the same isolation on a POST body"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 601; number = '555-0100'; type_id = 1 }
        [pscustomobject]@{ User_ID = 602; number = '555-0200'; type_id = 1 }
    ) | New-SchoolUserPhone
    Assert-Equal 'record 2 sends its own number' '555-0200' (Get-SentField 1 'number')

    "--- Remove-SchoolUserRelationship: the same isolation on a DELETE query string"
    Reset-Sent
    $null = @(
        [pscustomobject]@{ User_ID = 701; Left_User_ID = 801; relationship_type = 'Parent' }
        [pscustomobject]@{ User_ID = 702; Left_User_ID = 802; relationship_type = 'Parent' }
    ) | Remove-SchoolUserRelationship
    Assert-Equal 'both DELETE requests were sent' 2 $script:Sent.Count
    Assert-Equal 'record 2 carries its own relationship_type' 'Parent' (Get-SentField 1 'relationship_type')

    [pscustomobject]@{ Pass = $Stats.Pass; Fail = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] }
$Stats = $Result | Where-Object { $_ -isnot [string] } | Select-Object -Last 1
$Total = $Stats.Pass + $Stats.Fail.Count

""
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total PIPELINE-ISOLATION CASES PASSED" }
else { "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"; exit 1 }
