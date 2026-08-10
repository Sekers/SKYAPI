# Offline tests for Update-SchoolUser's -Validate and -IncludeUpdatedObject switches. No API calls are made;
# the reads and the write helper are stubbed inside the module scope.
#
# Covers that the control switch never reaches the request body, that no read-back happens unless asked,
# read-source selection between the basic and extended user reads, fail-fast across a batch, and the
# wording of the two failure messages.

Import-Module ([System.IO.Path]::Combine($PSScriptRoot,'..','SKYAPI','SKYAPI.psd1')) -Force -ErrorAction Stop
if (-not (Get-Module SKYAPI)) { throw 'SKYAPI module failed to import; aborting so this does not report a false pass.' }

$Result = & (Get-Module SKYAPI) {
    # Mutate a hashtable rather than assigning to $script: vars - inside "& (Get-Module ...) {}" the $script:
    # scope is the MODULE's, so counters assigned there vanish and failures would go uncounted.
    $Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }

    function Assert-True { param([string]$Name,[bool]$Condition,[string]$Detail)
        if ($Condition) { $Stats.Pass++; "  PASS  $Name" }
        else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- $Detail" } }

    # --- stubs (child scope shadows the real module functions) ---
    $script:SentBody = $null
    $script:BasicReads = 0
    $script:ExtendedReads = 0
    $script:BasicThrows = $false
    $script:ExtendedThrows = $false
    $script:BasicRecordsById = $null
    $script:ExtendedRecordsById = $null
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }
    $script:ExtendedRecord = [pscustomobject]@{ id = 1; middle_name = 'X'; races = @([pscustomobject]@{ race_type_id = 10; description = 'White' }) }

    function Get-SKYAPIConfig { param($ConfigPath) [pscustomobject]@{ api_subscription_key = 'stub' } }
    function Get-SKYAPIAuthTokensFromFile { [pscustomobject]@{ access_token = 'stub'; access_token_creation = (Get-Date) } }
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        $script:SentBody = @{}; foreach ($k in $params.Keys) { $script:SentBody[$k] = $params[$k] }; return $params['id'] }
    function Get-SchoolUser { param($User_ID,[switch]$ReturnRaw)
        $script:BasicReads++
        if ($script:BasicThrows) { throw '403 Forbidden' }
        if ($null -ne $script:BasicRecordsById) { return $script:BasicRecordsById[[int]$User_ID] }
        return $script:BasicRecord }
    function Get-SchoolUserExtended { param($User_ID,[switch]$ReturnRaw)
        $script:ExtendedReads++
        if ($script:ExtendedThrows) { throw '403 Forbidden' }
        if ($null -ne $script:ExtendedRecordsById) { return $script:ExtendedRecordsById[[int]$User_ID] }
        return $script:ExtendedRecord }
    function Get-SchoolTypeTableValue { param($tableName,$includeInactive)
        if ($tableName -eq 'Race') { return @([pscustomobject]@{ id = 10; name = 'White' },[pscustomobject]@{ id = 11; name = 'Asian' }) }
        return @() }

    function Reset-Counters {
        $script:BasicReads = 0
        $script:ExtendedReads = 0
        $script:SentBody = $null
        $script:BasicThrows = $false
        $script:ExtendedThrows = $false
        $script:BasicRecordsById = $null
        $script:ExtendedRecordsById = $null
    }

    "--- the control switch must not reach the wire"
    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate
    Assert-True 'Validate absent from request body' (-not $SentBody.ContainsKey('Validate')) "body keys: $($SentBody.Keys -join ',')"
    Assert-True 'IncludeUpdatedObject absent from request body' (-not $SentBody.ContainsKey('IncludeUpdatedObject')) "body keys: $($SentBody.Keys -join ',')"
    Assert-True 'body is exactly middle_name + id' (($SentBody.Keys | Sort-Object) -join ',' -eq 'id,middle_name') "body keys: $(($SentBody.Keys | Sort-Object) -join ',')"

    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Verbose:$false -ErrorAction Stop -Validate
    Assert-True 'common params still filtered alongside Validate' (($SentBody.Keys | Sort-Object) -join ',' -eq 'id,middle_name') "body keys: $(($SentBody.Keys | Sort-Object) -join ',')"

    "--- read-back only happens when asked"
    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -middle_name 'X'
    Assert-True 'no reads without either read-back switch' (($BasicReads + $ExtendedReads) -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    "--- read-source selection"
    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate
    Assert-True 'basic-only field uses Get-SchoolUser' ($BasicReads -eq 1 -and $ExtendedReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -races 'White' -Validate
    Assert-True 'extended-only field uses Get-SchoolUserExtended' ($ExtendedReads -eq 1 -and $BasicReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -races 'White' -Validate
    Assert-True 'mixed fields make exactly one extended read, never both' ($ExtendedReads -eq 1 -and $BasicReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $null = Update-SchoolUser -User_ID 1 -fields_to_delete 'student_id' -Validate
    Assert-True 'extended-only cleared field forces the extended read' ($ExtendedReads -eq 1) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $null = Update-SchoolUser -User_ID 1,2 -middle_name 'X' -Validate
    Assert-True 'one read per user in a batch' ($BasicReads -eq 2) "basic=$BasicReads"

    "--- included updated object"
    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }
    $Out = Update-SchoolUser -User_ID 1 -middle_name 'X' -IncludeUpdatedObject
    Assert-True 'include-only returns the numeric user ID at the root' ($Out -is [int] -and $Out -eq 1) "type=$($Out.GetType().FullName) returned=$Out"
    Assert-True 'include-only attaches the basic user record' ($Out.UpdatedObject.id -eq 1 -and $Out.UpdatedObject.middle_name -eq 'X') "updated id=$($Out.UpdatedObject.id) middle_name=$($Out.UpdatedObject.middle_name)"
    Assert-True 'include-only basic field performs one basic read' ($BasicReads -eq 1 -and $ExtendedReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"
    Assert-True 'include-only does not add a Response wrapper' ($Out.PSObject.Properties.Name -notcontains 'Response') "properties=$($Out.PSObject.Properties.Name -join ',')"
    Assert-True 'IncludeUpdatedObject remains off the wire' (-not $SentBody.ContainsKey('IncludeUpdatedObject')) "body keys: $($SentBody.Keys -join ',')"

    Reset-Counters
    $script:ExtendedRecord = [pscustomobject]@{ id = 1; races = @([pscustomobject]@{ race_type_id = 10; description = 'White' }) }
    $Out = Update-SchoolUser -User_ID 1 -races 'White' -IncludeUpdatedObject
    Assert-True 'include-only extended field performs one extended read' ($ExtendedReads -eq 1 -and $BasicReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"
    Assert-True 'include-only attaches the extended user record' ($Out.UpdatedObject.id -eq 1 -and $Out.UpdatedObject.races[0].description -eq 'White') "updated id=$($Out.UpdatedObject.id)"

    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'Different' }
    $Out = Update-SchoolUser -User_ID 1 -middle_name 'X' -IncludeUpdatedObject
    Assert-True 'include-only does not perform validation comparisons' ($Out -eq 1 -and $Out.UpdatedObject.middle_name -eq 'Different') "returned=$Out read back=$($Out.UpdatedObject.middle_name)"

    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }
    $Out = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate -IncludeUpdatedObject
    Assert-True 'combined mode returns the numeric user ID at the root' (@($Out).Count -eq 1 -and $Out -is [int] -and $Out -eq 1) "count=$(@($Out).Count) type=$($Out.GetType().FullName) returned=$Out"
    Assert-True 'combined mode attaches the validated user' ($Out.UpdatedObject.id -eq 1 -and $Out.UpdatedObject.middle_name -eq 'X') "updated id=$($Out.UpdatedObject.id)"
    Assert-True 'combined mode shares one basic read' ($BasicReads -eq 1 -and $ExtendedReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $script:BasicRecordsById = @{
        1 = [pscustomobject]@{ id = 1; middle_name = 'X' }
        2 = [pscustomobject]@{ id = 2; middle_name = 'X' }
    }
    $Out = Update-SchoolUser -User_ID 1,2 -middle_name 'X' -Validate -IncludeUpdatedObject
    Assert-True 'batch output emits one numeric response per user' (@($Out).Count -eq 2 -and $Out[0] -is [int] -and $Out[1] -is [int] -and $Out[0] -eq 1 -and $Out[1] -eq 2) "responses=$(@($Out) -join ',')"
    Assert-True 'batch responses attach the matching users' ($Out[0].UpdatedObject.id -eq 1 -and $Out[1].UpdatedObject.id -eq 2) "updated ids=$(@($Out.UpdatedObject.id) -join ',')"
    Assert-True 'batch combined mode performs one read per user' ($BasicReads -eq 2 -and $ExtendedReads -eq 0) "basic=$BasicReads extended=$ExtendedReads"

    Reset-Counters
    $script:BasicThrows = $true
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -IncludeUpdatedObject } catch { $Err = $_.Exception.Message }
    Assert-True 'include-only GET failure throws' ($Err -like '*was updated*' -and $Err -like '*updated object could not be returned*' -and $Err -like '*Get-SchoolUser failed*') "$Err"

    Reset-Counters
    $script:BasicRecord = $null
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -IncludeUpdatedObject } catch { $Err = $_.Exception.Message }
    Assert-True 'include-only missing user throws' ($Err -like '*updated object could not be returned*' -and $Err -like '*could not be read back*') "$Err"
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }

    "--- denied read-back is reported as unverified, not as a mismatch"
    Reset-Counters
    $script:ExtendedThrows = $true
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -races 'White' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True '403 on read-back throws' ($null -ne $Err) 'no error thrown'
    Assert-True 'message says the update succeeded' ($Err -like '*was updated*') $Err
    Assert-True 'message names the Data Sync role' ($Err -like '*SKY API Data Sync*') $Err
    Assert-True 'message does not claim a field mismatch' ($Err -notlike '*ignored these values*') $Err

    "--- validation outcomes"
    Reset-Counters
    $Out = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate
    Assert-True 'matching write returns the normal response' ($Out -eq 1) "returned: $Out"

    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'SOMETHING ELSE' }
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'mismatch throws' ($null -ne $Err) 'no error thrown'
    Assert-True 'mismatch names the field and both values' ($Err -like '*middle_name*' -and $Err -like "*sent 'X'*" -and $Err -like '*SOMETHING ELSE*') $Err
    Assert-True 'mismatch gives both possible causes' ($Err -like '*Either the API ignored these values, or the fields are not visible*') $Err

    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = '' }
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'silent no-op (read back empty) throws' ($null -ne $Err -and $Err -like '*read back empty*') "$Err"

    "--- fail fast: later users are not written"
    Reset-Counters
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'WRONG' }
    $script:WrittenIds = New-Object System.Collections.ArrayList
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        [void]$script:WrittenIds.Add($params['id']); $script:SentBody = $params; return $params['id'] }
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { }
    Assert-True 'stopped after the first bad user' ($script:WrittenIds.Count -eq 1 -and $script:WrittenIds[0] -eq 1) "written: $($script:WrittenIds -join ',')"

    "--- a mid-batch failure names the batch boundary"
    # The failure is terminating, so users updated before it are committed at the API but their responses are
    # lost to a caller that assigned the result. The message has to say where the batch stopped.
    function Set-BatchRecords { param([int]$BadId)
        $script:BasicRecordsById = @{}
        foreach ($i in 1,2,3) {
            $script:BasicRecordsById[$i] = [pscustomobject]@{ id = $i; middle_name = $(if ($i -eq $BadId) {'WRONG'} else {'X'}) } } }

    Reset-Counters
    Set-BatchRecords -BadId 2
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'mid-batch failure throws' ($null -ne $Err) 'no error thrown'
    Assert-True 'mid-batch names the failing user' ($Err -like '*user 2*') "$Err"
    Assert-True 'mid-batch lists what was already updated' ($Err -like '*Already updated before this failure: 1.*') "$Err"
    Assert-True 'mid-batch lists what was skipped' ($Err -like '*Not processed: 3.*') "$Err"

    Reset-Counters
    Set-BatchRecords -BadId 1
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'failure on the first user reports none already updated' ($Err -like '*Already updated before this failure: none.*') "$Err"
    Assert-True 'failure on the first user skips the rest' ($Err -like '*Not processed: 2, 3.*') "$Err"

    Reset-Counters
    Set-BatchRecords -BadId 3
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'failure on the last user reports both earlier users' ($Err -like '*Already updated before this failure: 1, 2.*') "$Err"
    Assert-True 'failure on the last user skips nothing' ($Err -like '*Not processed: none.*') "$Err"

    # A single-user call must not be made noisier by boundary text that says nothing.
    Reset-Counters
    $script:BasicRecordsById = $null
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'WRONG' }
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'single-user failure omits the boundary entirely' ($Err -notlike '*Already updated*' -and $Err -notlike '*Not processed*') "$Err"

    # Tracking must ACCUMULATE across pipeline records. Scoping it per record would report "none already
    # updated" while earlier records had in fact committed updates, which is worse than saying nothing.
    Reset-Counters
    $script:BasicRecordsById = @{
        1 = [pscustomobject]@{ id = 1; middle_name = 'X' }
        2 = [pscustomobject]@{ id = 2; middle_name = 'X' }
        3 = [pscustomobject]@{ id = 3; middle_name = 'WRONG' }
        4 = [pscustomobject]@{ id = 4; middle_name = 'X' }
    }
    $Err = $null
    try {
        @([pscustomobject]@{User_ID = @(1,2)}, [pscustomobject]@{User_ID = @(3,4)}) |
            Update-SchoolUser -middle_name 'X' -Validate | Out-Null
    } catch { $Err = $_.Exception.Message }
    Assert-True 'second pipeline record fails on its own user' ($Err -like '*user 3*') "$Err"
    Assert-True 'earlier pipeline records are still reported as updated' ($Err -like '*Already updated before this failure: 1, 2.*') "$Err"
    Assert-True 'second record still reports its own remaining user' ($Err -like '*Not processed: 4.*') "$Err"

    # A piped single-ID record after earlier successes must still name them, even though its own array has
    # only one entry. This is why the boundary is not gated on $User_ID.Count alone.
    Reset-Counters
    $script:BasicRecordsById = @{
        1 = [pscustomobject]@{ id = 1; middle_name = 'X' }
        2 = [pscustomobject]@{ id = 2; middle_name = 'WRONG' }
    }
    $Err = $null
    try {
        @([pscustomobject]@{User_ID = 1}, [pscustomobject]@{User_ID = 2}) |
            Update-SchoolUser -middle_name 'X' -Validate | Out-Null
    } catch { $Err = $_.Exception.Message }
    Assert-True 'piped single-ID record reports earlier successes' ($Err -like '*Already updated before this failure: 1.*') "$Err"
    Assert-True 'piped single-ID record has nothing left in its own array' ($Err -like '*Not processed: none.*') "$Err"
    $script:BasicRecordsById = $null
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }

    "--- a PRE-FLIGHT failure also names what earlier records committed"
    # Type-table validation runs before anything is sent for the record, and throws from inside
    # Confirm-SKYAPITypeTableValue. A bad value there is ordinary user error, so it is the likelier way to
    # abandon a batch part way through.
    Reset-Counters
    $script:BasicRecordsById = $null
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }
    $Err = $null
    try {
        @([pscustomobject]@{User_ID = 1}, [pscustomobject]@{User_ID = 2; races = 'NotARealRace'}) |
            Update-SchoolUser -middle_name 'X' -Validate | Out-Null
    } catch { $Err = $_.Exception.Message }
    Assert-True 'pre-flight failure keeps the original reason' ($Err -like "*Invalid 'races' value 'NotARealRace'*") "$Err"
    Assert-True 'pre-flight failure names the committed user' ($Err -like '*Already updated before this failure: 1.*') "$Err"
    Assert-True 'pre-flight failure treats the whole record as unprocessed' ($Err -like '*Not processed: 2.*') "$Err"

    # With nothing committed yet the original error is rethrown untouched, so its type is preserved and the
    # common single-call case is not made noisier.
    Reset-Counters
    $Err = $null
    $ErrType = $null
    try { $null = Update-SchoolUser -User_ID 1,2 -races 'NotARealRace' -Validate } catch { $Err = $_.Exception.Message; $ErrType = $_.Exception.GetType().Name }
    Assert-True 'nothing committed means no boundary is added' ($Err -notlike '*Already updated*' -and $Err -notlike '*Not processed*') "$Err"
    Assert-True 'nothing committed still reports the real reason' ($Err -like "*Invalid 'races' value*") "$Err"
    Assert-True 'untouched rethrow keeps the original exception type' ($ErrType -eq 'RuntimeException') "type=$ErrType"

    "--- unmapped fields are reported, not silently skipped"
    Reset-Counters
    $script:ExtendedRecord = [pscustomobject]@{ id = 1; misc_bio = 'X' }
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1 -summary_note 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'unmapped summary_note reports unverifiable' ($null -ne $Err -and $Err -like '*could not be verified*' -and $Err -like '*summary_note*') "$Err"

    "--- a failing PATCH reports the boundary AND what became of the record it was attempting"
    # Every other failure path happens after a successful write, so it knows the record was changed. Here the
    # effect depends on what came back, which is why the catch classifies it. This first case has no response
    # at all, the clearest uncertain outcome; the 4xx and 5xx cases follow. Defined last in the file so the
    # throwing stub cannot leak upward into earlier cases.
    Reset-Counters
    $script:BasicRecordsById = $null
    $script:BasicRecord = [pscustomobject]@{ id = 1; middle_name = 'X' }
    $script:PatchWritten = New-Object System.Collections.ArrayList
    $script:PatchFailsOn = 2
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        if ($params['id'] -eq $script:PatchFailsOn) { throw 'PATCH exploded' }
        [void]$script:PatchWritten.Add($params['id']); return $params['id'] }

    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'PATCH failure stops the batch there' (($script:PatchWritten -join ',') -eq '1') "written: $($script:PatchWritten -join ',')"
    Assert-True 'PATCH failure keeps the underlying error' ($Err -like '*PATCH exploded*') "$Err"
    Assert-True 'PATCH failure names the attempted user' ($Err -like '*update to user 2 did not complete*') "$Err"
    Assert-True 'PATCH failure says the outcome is unknown' ($Err -like '*whether the API applied it is unknown*') "$Err"
    Assert-True 'PATCH failure lists what was committed' ($Err -like '*Already updated before this failure: 1.*') "$Err"
    Assert-True 'PATCH failure lists what was skipped' ($Err -like '*Not processed: 3.*') "$Err"
    Assert-True 'the failing user is NOT claimed as updated' ($Err -notlike '*Already updated before this failure: 1, 2*') "$Err"

    # A single-ID call has no batch to describe, but still must name the user and say what happened to it.
    # Only the two 'none' boundary lines are suppressed.
    Reset-Counters
    $script:PatchWritten = New-Object System.Collections.ArrayList
    $script:PatchFailsOn = 1
    $Err = $null
    $Inner = $null
    try { $null = Update-SchoolUser -User_ID 1 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message; $Inner = $_.Exception.InnerException }
    Assert-True 'lone PATCH failure keeps the underlying error' ($Err -like '*PATCH exploded*') "$Err"
    Assert-True 'lone PATCH failure still names the user' ($Err -like '*user 1*') "$Err"
    Assert-True 'lone PATCH failure omits the empty boundary' ($Err -notlike '*Already updated*' -and $Err -notlike '*Not processed*') "$Err"
    Assert-True 'lone PATCH failure preserves the original as InnerException' ($null -ne $Inner -and $Inner.Message -eq 'PATCH exploded') "inner=$($Inner.Message)"

    "--- a rejected write is reported as rejected, not as 'outcome unknown'"
    # Update-SKYAPIEntity throws for 4xx too. Those were definitively handled by the server, so telling the
    # caller the change 'might have been applied' would send them checking a record that never changed.
    Add-Type -TypeDefinition 'namespace SkyTest { public class Resp { public int StatusCode { get; set; } }
        public class HttpEx : System.Exception { public Resp Response { get; set; }
        public HttpEx(string m, int c) : base(m) { Response = new Resp { StatusCode = c }; } } }' -ErrorAction SilentlyContinue

    Reset-Counters
    $script:PatchWritten = New-Object System.Collections.ArrayList
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        if ($params['id'] -eq 2) { try { throw [SkyTest.HttpEx]::new('400 Bad Request',400) } catch { throw $_ } }
        [void]$script:PatchWritten.Add($params['id']); return $params['id'] }

    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a 400 is reported as rejected' ($Err -like '*API rejected the update to user 2*') "$Err"
    Assert-True 'a 400 reports its status code' ($Err -like '*HTTP 400*') "$Err"
    Assert-True 'a 400 states the user was NOT changed' ($Err -like '*was not changed*') "$Err"
    Assert-True 'a 400 does not claim the outcome is unknown' ($Err -notlike '*unknown*') "$Err"
    Assert-True 'a 400 still reports the batch boundary' ($Err -like '*Already updated before this failure: 1.*' -and $Err -like '*Not processed: 3.*') "$Err"

    # A failure with no response at all keeps the uncertain wording.
    Reset-Counters
    $script:PatchWritten = New-Object System.Collections.ArrayList
    $script:PatchFailsOn = 2
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        if ($params['id'] -eq $script:PatchFailsOn) { throw 'The connection was closed' }
        [void]$script:PatchWritten.Add($params['id']); return $params['id'] }
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'a responseless failure is still unknown' ($Err -like '*whether the API applied it is unknown*') "$Err"
    Assert-True 'a responseless failure is not called rejected' ($Err -notlike '*API rejected*') "$Err"

    "--- a 5xx is NOT a definite rejection: the server may have applied the write before failing"
    # 500/502/503/504 are retried with backoff, so by the time one surfaces the write has been attempted
    # several times. 502 and 504 mean a proxy lost the upstream answer, which is no different from getting no
    # response at all. Reporting any of these as "not changed" would send the caller past a record that may
    # well have been written.
    # Defined the same way as every other stub in this file. An earlier attempt used
    # 'Set-Item function:script:Update-SKYAPIEntity', which did NOT override the function the module resolves,
    # so the previous stub stayed live and these cases passed against the wrong error. Only the 4xx case
    # below, which expects the opposite wording, exposed it. Drive the status through a variable instead.
    $script:PatchHttpStatus = 500
    function Update-SKYAPIEntity { param($url,$api_key,$authorisation,$params,$uid,$end)
        if ($params['id'] -eq 2) {
            try { throw [SkyTest.HttpEx]::new("$script:PatchHttpStatus oh dear", $script:PatchHttpStatus) } catch { throw $_ } }
        return $params['id'] }

    foreach ($Status in 500,502,503,504)
    {
        Reset-Counters
        $script:PatchHttpStatus = $Status
        $Err = $null
        try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
        Assert-True "HTTP $Status really used the stubbed status" ($Err -like "*$Status oh dear*") "$Err"
        Assert-True "HTTP $Status is not called a rejection" ($Err -notlike '*API rejected*') "$Err"
        Assert-True "HTTP $Status reports an unknown outcome"  ($Err -like '*is unknown*') "$Err"
        Assert-True "HTTP $Status never claims the user was unchanged" ($Err -notlike '*was not changed*') "$Err"
        Assert-True "HTTP $Status still reports the batch boundary" ($Err -like '*Already updated before this failure: 1.*') "$Err"
    }

    # A status this code did not anticipate must fall to the safe side rather than be called a rejection.
    Reset-Counters
    $script:PatchHttpStatus = 302
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'an unanticipated status defaults to unknown' ($Err -like '*is unknown*' -and $Err -notlike '*API rejected*') "$Err"
    Assert-True 'the unanticipated case really used the stubbed status' ($Err -like '*302 oh dear*') "$Err"

    # Both sides of the 4xx boundary, which is what makes the split above meaningful rather than incidental.
    Reset-Counters
    $script:PatchHttpStatus = 499
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'HTTP 499 is still a rejection' ($Err -like '*API rejected*' -and $Err -like '*was not changed*') "$Err"

    Reset-Counters
    $script:PatchHttpStatus = 400
    $Err = $null
    try { $null = Update-SchoolUser -User_ID 1,2,3 -middle_name 'X' -Validate } catch { $Err = $_.Exception.Message }
    Assert-True 'HTTP 400 is a rejection (lower edge)' ($Err -like '*API rejected*' -and $Err -like '*HTTP 400*') "$Err"

    [pscustomobject]@{ Passes = $Stats.Pass; Failures = $Stats.Fail }
}

$Result | Where-Object { $_ -is [string] } | ForEach-Object { $_ }
""
$Fail = if ($Result) { $Result[-1] } else { $null }
if (-not $Fail -or $Fail.Passes -eq 0) { "NO CASES RAN - treating as failure"; exit 1 }
if ($Fail.Failures.Count -eq 0) { "ALL $($Fail.Passes) BEHAVIOR CASES PASSED" }
else { "$($Fail.Failures.Count) FAILED: $($Fail.Failures -join '; ')"; exit 1 }

