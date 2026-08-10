# Offline tests for Update-SchoolUserAddress, -Validate, and -IncludeUpdatedObject. No API calls are made;
# the read and write helpers are stubbed inside the module scope.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }

    function Assert-True { param([string]$Name,[bool]$Condition,[string]$Detail)
        if ($Condition) { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- $Detail" } }

    $script:SentBody = $null
    $script:SentUid = $null
    $script:SentEndUrl = $null
    $script:ReadCount = 0
    $script:ReadThrows = $false
    $script:ReadRecords = @()

    function Get-SKYAPIConfig { param($ConfigPath) [pscustomobject]@{ api_subscription_key = 'stub' } }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$endUrl)
        $script:SentBody = @{}; foreach ($k in $params.Keys) { $script:SentBody[$k] = $params[$k] }
        $script:SentUid = $uid; $script:SentEndUrl = $endUrl
        return $params['id'] }
    function Get-SchoolUserAddress { param($User_ID)
        $script:ReadCount++
        if ($script:ReadThrows) { throw '403 Forbidden' }
        return $script:ReadRecords }

    function Reset-State
    {
        $script:SentBody = $null
        $script:SentUid = $null
        $script:SentEndUrl = $null
        $script:ReadCount = 0
        $script:ReadThrows = $false
        $script:ReadRecords = @()
    }

    "--- required parameters and pipeline binding"
    $Command = Get-Command Update-SchoolUserAddress
    foreach ($Name in 'user_id','address_id','type_id','line_one')
    {
        $Mandatory = @($Command.Parameters[$Name].Attributes | Where-Object {$_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory}).Count -gt 0
        Assert-True "$Name is mandatory" $Mandatory 'parameter is not mandatory'
    }
    # The IDs are scalar here (an address belongs to exactly one user), so they go to the endpoint directly
    # rather than being looped into $uid, and therefore carry the endpoint's own lowercase naming.
    foreach ($Name in 'user_id','address_id')
    {
        Assert-True "$Name uses the endpoint's parameter name" ($Command.Parameters[$Name].Name -ceq $Name) "declared as: $($Command.Parameters[$Name].Name)"
    }
    $UserByValue = @($Command.Parameters['user_id'].Attributes | Where-Object {$_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline}).Count -gt 0
    Assert-True 'user_id accepts pipeline input by value' $UserByValue 'ValueFromPipeline is false'
    foreach ($Name in 'address_id','type_id','line_one','city','mailing_address','links','salutations','fields_to_delete','Validate','IncludeUpdatedObject')
    {
        $ByValue = @($Command.Parameters[$Name].Attributes | Where-Object {$_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline}).Count -gt 0
        Assert-True "$Name does not accept the whole record by value" (-not $ByValue) 'ValueFromPipeline is true'
    }

    # Sibling create function: its required set must track the AddressAdd model, which requires
    # city/line_one/type_id/user_id and leaves country optional. The function used to have those two backwards.
    "--- New-SchoolUserAddress required set (AddressAdd model)"
    $NewCommand = Get-Command New-SchoolUserAddress
    function Test-Mandatory { param($Command,[string]$Name)
        @($Command.Parameters[$Name].Attributes | Where-Object {$_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory}).Count -gt 0 }
    foreach ($Name in 'User_ID','type_id','line_one','city')
    {
        Assert-True "New-SchoolUserAddress $Name is mandatory" (Test-Mandatory $NewCommand $Name) 'parameter is not mandatory'
    }
    Assert-True 'New-SchoolUserAddress country is optional' (-not (Test-Mandatory $NewCommand 'country')) 'country is still mandatory'
    Assert-True 'New-SchoolUserAddress exposes salutations' ($NewCommand.Parameters.ContainsKey('salutations')) 'salutations parameter is missing'

    "--- request shape"
    Reset-State
    $Out = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Verbose:$false -ErrorAction Stop
    Assert-True 'returns the address ID' ($Out -eq 20) "returned: $Out"
    Assert-True 'URL user ID is correct' ($SentUid -eq 10) "uid: $SentUid"
    Assert-True 'address URL segment is correct' ($SentEndUrl -eq '/addresses/20') "endUrl: $SentEndUrl"
    Assert-True 'body contains API-required fields' (($SentBody.Keys | Sort-Object) -join ',' -eq 'id,line_one,type_id,user_id') "keys: $(($SentBody.Keys | Sort-Object) -join ',')"
    Assert-True 'body IDs use API field names' ($SentBody['id'] -eq 20 -and $SentBody['user_id'] -eq 10) "id=$($SentBody['id']) user_id=$($SentBody['user_id'])"
    Assert-True 'control parameters are not leaked' (-not $SentBody.ContainsKey('Validate') -and -not $SentBody.ContainsKey('IncludeUpdatedObject')) "keys: $($SentBody.Keys -join ',')"
    Assert-True 'address_id is sent as id, not under its own name' (-not $SentBody.ContainsKey('address_id')) "keys: $($SentBody.Keys -join ',')"
    Assert-True 'no read occurs without either read-back switch' ($ReadCount -eq 0) "reads: $ReadCount"

    "--- matching validation"
    Reset-State
    $script:ReadRecords = @(
        [pscustomobject]@{ id = 99; user_id = 10; type_id = 30; line_one = 'Other' },
        [pscustomobject]@{
            id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Chicago'
            mailing_address = $false
            links = @([pscustomobject]@{ user_id = 10; type_id = 30; primary = $true; shared = $false })
            salutations = [pscustomobject]@{ informal = 'Friends'; formal = ''; household = '' }
        })
    $Out = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' `
        -city 'Chicago' -mailing_address $false -links @(@{ user_id = 10; type_id = 30; primary = $true }) `
        -salutations @{ informal = 'Friends' } -Validate
    Assert-True 'matching validation returns the normal response' ($Out -eq 20) "returned: $Out"
    Assert-True 'Validate performs one address read' ($ReadCount -eq 1) "reads: $ReadCount"
    Assert-True 'Validate is excluded from the body' (-not $SentBody.ContainsKey('Validate')) "keys: $($SentBody.Keys -join ',')"
    Assert-True 'explicit false Boolean remains in the body' ($SentBody.ContainsKey('mailing_address') -and $SentBody['mailing_address'] -eq $false) "mailing_address=$($SentBody['mailing_address'])"

    "--- included updated object"
    Reset-State
    $script:ReadRecords = @(
        [pscustomobject]@{ id = 99; user_id = 10; type_id = 30; line_one = 'Other' },
        [pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Chicago' })
    $Out = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' `
        -city 'Chicago' -IncludeUpdatedObject
    Assert-True 'IncludeUpdatedObject alone keeps the numeric response at the root' ($Out -is [int] -and $Out -eq 20) "type=$($Out.GetType().FullName) returned=$Out"
    Assert-True 'IncludeUpdatedObject alone attaches the matching address' ($Out.UpdatedObject.id -eq 20 -and $Out.UpdatedObject.city -eq 'Chicago') "updated id=$($Out.UpdatedObject.id) city=$($Out.UpdatedObject.city)"
    Assert-True 'IncludeUpdatedObject alone performs one address read' ($ReadCount -eq 1) "reads: $ReadCount"
    Assert-True 'IncludeUpdatedObject is excluded from the body' (-not $SentBody.ContainsKey('IncludeUpdatedObject')) "keys: $($SentBody.Keys -join ',')"
    Assert-True 'IncludeUpdatedObject does not add a Response wrapper' ($Out.PSObject.Properties.Name -notcontains 'Response') "properties=$($Out.PSObject.Properties.Name -join ',')"

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Chicago' })
    $Out = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' `
        -city 'Chicago' -Validate -IncludeUpdatedObject
    Assert-True 'combined mode returns one numeric response' (@($Out).Count -eq 1 -and $Out -is [int] -and $Out -eq 20) "count=$(@($Out).Count) type=$($Out.GetType().FullName) returned=$Out"
    Assert-True 'combined mode attaches the validated address' ($Out.UpdatedObject.id -eq 20 -and $Out.UpdatedObject.city -eq 'Chicago') "updated id=$($Out.UpdatedObject.id) city=$($Out.UpdatedObject.city)"
    Assert-True 'combined mode shares one read' ($ReadCount -eq 1) "reads: $ReadCount"

    Reset-State
    $script:ReadRecords = @(
        [pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' },
        [pscustomobject]@{ id = 21; user_id = 11; type_id = 31; line_one = 'Second' })
    $Out = @(
        [pscustomobject]@{ User_ID = 10; Address_ID = 20; type_id = 30; line_one = 'First' },
        [pscustomobject]@{ User_ID = 11; Address_ID = 21; type_id = 31; line_one = 'Second' }
    ) | Update-SchoolUserAddress -Validate -IncludeUpdatedObject
    Assert-True 'pipeline output emits one numeric response per update' (@($Out).Count -eq 2 -and $Out[0] -is [int] -and $Out[1] -is [int] -and $Out[0] -eq 20 -and $Out[1] -eq 21) "responses: $(@($Out) -join ',')"
    Assert-True 'pipeline responses contain the validated addresses' ($Out[0].UpdatedObject.id -eq 20 -and $Out[1].UpdatedObject.id -eq 21) "updated ids: $(@($Out.UpdatedObject.id) -join ',')"
    Assert-True 'pipeline validation performs one read per update' ($ReadCount -eq 2) "reads: $ReadCount"

    "--- fields_to_delete"
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; line_two = '' })
    $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' `
        -line_two 'ignored because clear wins' -fields_to_delete 'line_two' -Validate
    Assert-True 'a successfully cleared address field validates' ($ReadCount -eq 1) "reads: $ReadCount"

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; line_two = 'Still set' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -fields_to_delete 'line_two' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a failed clear throws' ($Err -like '*line_two*' -and $Err -like '*asked to clear*') "$Err"

    "--- record-identity and read-only fields are not validated"
    # A shared address can read back a different user_id than the update was addressed to, and the API owns
    # the read-only link fields. Neither is caller-supplied content, so neither may fail a good update.
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{
        id = 20; user_id = 77; type_id = 30; line_one = 'First'
        links = @([pscustomobject]@{
            user_id = 10; type_id = 30; primary = $true
            shared = $true; shared_user = 'Pat Doe'; shared_relationship = 'Spouse'; type = 'Home' })
    })
    $Err = $null
    try {
        $Out = Update-SchoolUserAddress -user_id 10 -address_id 20 -type_id 30 -line_one 'First' `
            -links @(@{ user_id = 10; type_id = 30; primary = $true
                        shared = $false; shared_user = ''; shared_relationship = ''; type = 'Home Address' }) -Validate
    } catch { $Err = $_.Exception.Message }
    Assert-True 'a shared address reading back a different user_id still validates' ($null -eq $Err) "$Err"
    Assert-True 'server-owned link fields do not fail validation' ($Out -eq 20) "returned: $Out"

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Chicago' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -user_id 10 -address_id 20 -type_id 30 -line_one 'First' -city 'Chicago' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a writable field is still compared' ($null -eq $Err) "$Err"

    "--- validation failures"
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Wrong' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -city 'Chicago' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a mismatched field throws' ($Err -like '*city*' -and $Err -like "*sent 'Chicago'*" -and $Err -like "*read back 'Wrong'*") "$Err"
    Assert-True 'mismatch says the update already happened' ($Err -like '*was updated*') "$Err"

    Reset-State
    $script:ReadThrows = $true
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a failed read-back throws' ($Err -like '*was updated*' -and $Err -like '*Get-SchoolUserAddress failed*' -and $Err -like '*403 Forbidden*') "$Err"

    Reset-State
    $script:ReadThrows = $true
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -IncludeUpdatedObject } catch { $Err = $_.Exception.Message }
    Assert-True 'a failed include-only read throws' ($Err -like '*was updated*' -and $Err -like '*updated object could not be returned*' -and $Err -like '*403 Forbidden*') "$Err"

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 99; user_id = 10; type_id = 30; line_one = 'Other' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a missing address is reported as unverifiable' ($Err -like '*could not be verified*' -and $Err -like '*could not be read back*') "$Err"

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 99; user_id = 10; type_id = 30; line_one = 'Other' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -IncludeUpdatedObject } catch { $Err = $_.Exception.Message }
    Assert-True 'a missing include-only address throws' ($Err -like '*updated object could not be returned*' -and $Err -like '*could not be read back*') "$Err"

    "--- a failure part way through a piped batch names what was already committed"
    # This function takes one address per call, so a batch is always a pipeline. The failure is terminating,
    # so without this the addresses already written would go unreported entirely.
    Reset-State
    $script:ReadRecords = @(
        [pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Chicago' }
        [pscustomobject]@{ id = 21; user_id = 10; type_id = 30; line_one = 'First'; city = 'Wrong' }
    )
    $Err = $null
    try {
        @([pscustomobject]@{User_ID = 10; Address_ID = 20}, [pscustomobject]@{User_ID = 10; Address_ID = 21}) |
            Update-SchoolUserAddress -type_id 30 -line_one 'First' -city 'Chicago' -Validate | Out-Null
    } catch { $Err = $_.Exception.Message }
    Assert-True 'piped batch fails on the offending address' ($Err -like '*address 21 for user 10*') "$Err"
    Assert-True 'piped batch names the address already committed' ($Err -like '*Already updated before this failure: address 20 for user 10.*') "$Err"

    # The first record in a pipeline has nothing before it, so the boundary must stay silent rather than
    # printing an empty or "none" list on what is effectively a single-address call.
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First'; city = 'Wrong' })
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -city 'Chicago' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a first/only address omits the boundary' ($Err -notlike '*Already updated before this failure*') "$Err"

    "--- a failing PATCH reports the boundary AND what became of the address it was attempting"
    # Every other failure path happens after a successful write, so it knows the address was changed. Here the
    # effect depends on what came back, which is why the catch classifies it. This first case has no response
    # at all, the clearest uncertain outcome; the 4xx and 5xx cases follow. Defined last in the file so the
    # throwing stub cannot leak upward into earlier cases.
    Reset-State
    $script:ReadRecords = @(
        [pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' }
        [pscustomobject]@{ id = 21; user_id = 10; type_id = 30; line_one = 'First' }
    )
    $script:PatchWritten = New-Object System.Collections.ArrayList
    $script:PatchFailsOn = 21
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$endUrl)
        if ($params['id'] -eq $script:PatchFailsOn) { throw 'PATCH exploded' }
        [void]$script:PatchWritten.Add($params['id']); return $params['id'] }

    $Err = $null
    try {
        @([pscustomobject]@{User_ID = 10; Address_ID = 20}, [pscustomobject]@{User_ID = 10; Address_ID = 21}) |
            Update-SchoolUserAddress -type_id 30 -line_one 'First' -Validate | Out-Null
    } catch { $Err = $_.Exception.Message }
    Assert-True 'PATCH failure stops the pipeline there' (($script:PatchWritten -join ',') -eq '20') "written: $($script:PatchWritten -join ',')"
    Assert-True 'PATCH failure keeps the underlying error' ($Err -like '*PATCH exploded*') "$Err"
    Assert-True 'PATCH failure names the attempted address' ($Err -like '*update to address 21 for user 10 did not complete*') "$Err"
    Assert-True 'PATCH failure says the outcome is unknown' ($Err -like '*whether the API applied it is unknown*') "$Err"
    Assert-True 'PATCH failure lists what was committed' ($Err -like '*Already updated before this failure: address 20 for user 10.*') "$Err"
    Assert-True 'the failing address is NOT claimed as updated' ($Err -notlike '*address 21 for user 10.*Already updated*') "$Err"

    # The first record has nothing before it, but must still name the address and say what happened to it.
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' })
    $script:PatchWritten = New-Object System.Collections.ArrayList
    $script:PatchFailsOn = 20
    $Err = $null
    $Inner = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message; $Inner = $_.Exception.InnerException }
    Assert-True 'lone PATCH failure keeps the underlying error' ($Err -like '*PATCH exploded*') "$Err"
    Assert-True 'lone PATCH failure still names the address' ($Err -like '*address 20 for user 10*') "$Err"
    Assert-True 'lone PATCH failure omits the empty boundary' ($Err -notlike '*Already updated*') "$Err"
    Assert-True 'lone PATCH failure preserves the original as InnerException' ($null -ne $Inner -and $Inner.Message -eq 'PATCH exploded') "inner=$($Inner.Message)"

    "--- a rejected write is reported as rejected, not as 'outcome unknown'"
    Add-Type -TypeDefinition 'namespace SkyTestAddr { public class Resp { public int StatusCode { get; set; } }
        public class HttpEx : System.Exception { public Resp Response { get; set; }
        public HttpEx(string m, int c) : base(m) { Response = new Resp { StatusCode = c }; } } }' -ErrorAction SilentlyContinue

    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' })
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$endUrl)
        try { throw [SkyTestAddr.HttpEx]::new('403 Forbidden',403) } catch { throw $_ } }
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a 403 is reported as rejected' ($Err -like '*API rejected the update to address 20 for user 10*') "$Err"
    Assert-True 'a 403 reports its status code' ($Err -like '*HTTP 403*') "$Err"
    Assert-True 'a 403 states the address was NOT changed' ($Err -like '*was not changed*') "$Err"
    Assert-True 'a 403 does not claim the outcome is unknown' ($Err -notlike '*unknown*') "$Err"

    "--- a 5xx is NOT a definite rejection: the server may have applied the write before failing"
    # Defined the same way as every other stub in this file. An earlier attempt used
    # 'Set-Item function:script:Update-SKYAPIEntity', which did NOT override the function the module resolves,
    # so the previous 403 stub stayed live and every case below passed against the wrong error. Drive the
    # status through a variable instead, and assert the stubbed message actually appears.
    $script:PatchHttpStatus = 500
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$endUrl)
        try { throw [SkyTestAddr.HttpEx]::new("$script:PatchHttpStatus oh dear", $script:PatchHttpStatus) } catch { throw $_ } }

    foreach ($Status in 500,502,503,504)
    {
        Reset-State
        $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' })
        $script:PatchHttpStatus = $Status
        $Err = $null
        try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message }
        Assert-True "HTTP $Status really used the stubbed status" ($Err -like "*$Status oh dear*") "$Err"
        Assert-True "HTTP $Status is not called a rejection" ($Err -notlike '*API rejected*') "$Err"
        Assert-True "HTTP $Status reports an unknown outcome" ($Err -like '*is unknown*') "$Err"
        Assert-True "HTTP $Status never claims the address was unchanged" ($Err -notlike '*was not changed*') "$Err"
    }

    # The other side of the boundary, proving the split is real and not an artifact of a stale stub.
    Reset-State
    $script:ReadRecords = @([pscustomobject]@{ id = 20; user_id = 10; type_id = 30; line_one = 'First' })
    $script:PatchHttpStatus = 400
    $Err = $null
    try { $null = Update-SchoolUserAddress -User_ID 10 -Address_ID 20 -type_id 30 -line_one 'First' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'HTTP 400 is a rejection (lower edge)' ($Err -like '*API rejected*' -and $Err -like '*HTTP 400*' -and $Err -like '*was not changed*') "$Err"

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
""
$Final = if ($Result) { $Result[-1] } else { $null }
if (-not $Final -or $Final.Passes -eq 0) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Final.Failures.Count -eq 0) { "ALL $($Final.Passes) ADDRESS-UPDATE CASES PASSED" }
else { "$($Final.Failures.Count) FAILED: $($Final.Failures -join '; ')"; exit 1 }
