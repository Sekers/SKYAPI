function Update-SchoolUserAddress
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idAddressesByAddress_idPatch

        .SYNOPSIS
        Updates an address record for a user and returns the ID of the address updated.

        .DESCRIPTION
        Updates an address record for a user and returns the ID of the address updated.

        The API requires user_id, address_id, type_id, and line_one in every request. Deleting or clearing an
        optional field requires fields_to_delete.

        This endpoint merges rather than replaces: fields you do not supply keep their current values.
        Confirmed by test against a developer tenant - an update sending only type_id and line_one left
        city, state, postal_code, country and the remaining fields untouched.

        Requires at least one of the following roles in the Education Management system:
          - SKY API Data Sync
          - Platform Manager
          - Contact Card Manager

        .PARAMETER user_id
        Required. The ID of the user whose address is being updated.
        .PARAMETER address_id
        Required. The ID of the address to update.
        .PARAMETER type_id
        Required. The type ID of the specified address. The type ID corresponds with the type of address
        (ex. Business/College, Home, Summer). Use Get-SchoolUserAddressType to get a list of address types.
        .PARAMETER line_one
        Required. The first address line.
        .PARAMETER city
        The city for the address.
        .PARAMETER country
        The full country name.
        .PARAMETER line_two
        The second address line.
        .PARAMETER line_three
        The third address line.
        .PARAMETER mailing_address
        Set to true if the user accepts mail at this address.
        .PARAMETER postal_code
        The postal code for the address.
        .PARAMETER primary
        Set to true if this is the user's primary address.
        .PARAMETER province
        The province for the address.
        .PARAMETER region
        The region for the address.
        .PARAMETER state
        The state for the address.
        .PARAMETER links
        Address type links for relationships to the user. Each item may contain type_id, primary, shared,
        shared_relationship, shared_user, type, and user_id.
        .PARAMETER salutations
        Address salutations. Provide a hashtable or PSCustomObject containing informal, formal, or household.
        Note: salutations can be set but not cleared through this API. Supplying an empty value is ignored, and
        neither 'salutations' nor 'salutations.informal' works in fields_to_delete - the API accepts both and
        returns success without changing anything (confirmed by test against a developer tenant). Use -Validate
        if you need that silent no-op reported rather than assumed to have worked; clear them in the web UI.
        .PARAMETER fields_to_delete
        Field names to clear. A cleared field overrides a value supplied for the same field. Required fields,
        Boolean fields, and fields without a blank option are ignored by the API. Verified working on the
        top-level string fields (e.g. 'line_two', 'line_three'); see -salutations for the one known exception.
        .PARAMETER Validate
        Re-read the address after the update and confirm that every supplied field took effect. The read-back requires
        one additional API call per updated address. If IncludeUpdatedObject is also specified, both switches use that
        same call, so together they still make only one additional API call. The function throws if the address cannot
        be read or a supplied value does not match.

        Validation stops at the first address that fails, so later addresses piped into the same call are not updated.
        Addresses processed BEFORE the failure have already been updated at the API and are NOT rolled back; the error
        names them ("Already updated before this failure: ...") so you can tell where the batch stopped. Addresses still
        upstream in the pipeline cannot be listed, because this function does not know what is coming. If the update
        request itself fails, the error also says what that means for the address it was attempting. An HTTP 4xx is a
        definite rejection: the API evaluated the request and refused it, so that address was not changed. Anything
        else, a 5xx or no response at all, leaves the outcome unknown, because the API may have applied the change
        before failing, so that address is reported as neither updated nor untouched and should be checked before
        retrying.
        Note that the failure is terminating, so assigning the result (e.g. $r = ... | Update-SchoolUserAddress) discards
        the responses for the addresses that did succeed. Stream the output instead if you need to keep them.
        .PARAMETER IncludeUpdatedObject
        Re-read the updated address and attach it to the returned address ID as an UpdatedObject property. This can be
        used with or without Validate. The read-back requires one additional API call per updated address. If Validate
        is also specified, both switches use that same call, so together they still make only one additional API call.
        The function throws if the address cannot be read.

        .EXAMPLE
        Update-SchoolUserAddress -user_id 3156271 -address_id 4708014 -type_id 1005 `
            -line_one '129 Huntington Drive' -city 'Chicago' -state 'IL' -postal_code '60601'

        .EXAMPLE
        Update-SchoolUserAddress -user_id 3156271 -address_id 4708014 -type_id 1005 `
            -line_one '129 Huntington Drive' -fields_to_delete 'line_two','line_three' -Validate

        .EXAMPLE
        Update-SchoolUserAddress -user_id 3156271 -address_id 4708014 -type_id 1005 `
            -line_one '129 Huntington Drive' -city 'Chicago' -Validate -IncludeUpdatedObject

        .OUTPUTS
        Returns the address ID from the update endpoint. With IncludeUpdatedObject, the same ID gains an
        UpdatedObject property containing the address returned by Get-SchoolUserAddress.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$user_id,

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$address_id,

        [Parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$type_id,

        [Parameter(
        Position=3,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$line_one,

        [Parameter(
        Position=4,
        ValueFromPipelineByPropertyName=$true)]
        [string]$city,

        [Parameter(
        Position=5,
        ValueFromPipelineByPropertyName=$true)]
        [string]$country,

        [Parameter(
        Position=6,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_two,

        [Parameter(
        Position=7,
        ValueFromPipelineByPropertyName=$true)]
        [string]$line_three,

        [Parameter(
        Position=8,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$mailing_address,

        [Parameter(
        Position=9,
        ValueFromPipelineByPropertyName=$true)]
        [string]$postal_code,

        [Parameter(
        Position=10,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$primary,

        [Parameter(
        Position=11,
        ValueFromPipelineByPropertyName=$true)]
        [string]$province,

        [Parameter(
        Position=12,
        ValueFromPipelineByPropertyName=$true)]
        [string]$region,

        [Parameter(
        Position=13,
        ValueFromPipelineByPropertyName=$true)]
        [string]$state,

        [Parameter(
        Position=14,
        ValueFromPipelineByPropertyName=$true)]
        [object[]]$links,

        [Parameter(
        Position=15,
        ValueFromPipelineByPropertyName=$true)]
        [object]$salutations,

        [Parameter(
        Position=16,
        ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyCollection()]
        [string[]]$fields_to_delete,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [switch]$Validate,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [switch]$IncludeUpdatedObject
    )

    begin
    {
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'

        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # How -Validate compares each request field against the re-read address. Only used when -Validate is passed.
        # Deliberately absent: 'id' and 'user_id'. Both are added to every request body below because the API requires
        # them, but neither is caller-supplied content, so validating them is at best redundant and at worst wrong.
        # 'id' is already how the read-back is selected, and an address can be shared between users (see AddressShare
        # and the shared_user/shared_relationship link fields), so a shared address can legitimately read back a
        # different user_id than the one the update was addressed to - which would fail a write that actually worked.
        $ValidationFieldSpec = [ordered]@{
            type_id         = @{Kind = 'Scalar'}
            line_one        = @{Kind = 'Scalar'}
            city            = @{Kind = 'Scalar'}
            country         = @{Kind = 'Scalar'}
            line_two        = @{Kind = 'Scalar'}
            line_three      = @{Kind = 'Scalar'}
            mailing_address = @{Kind = 'Scalar'}
            postal_code     = @{Kind = 'Scalar'}
            primary         = @{Kind = 'Scalar'}
            province        = @{Kind = 'Scalar'}
            region          = @{Kind = 'Scalar'}
            state           = @{Kind = 'Scalar'}
            # Only the writable link fields are compared. 'shared' is documented Read Only, and 'type',
            # 'shared_user' and 'shared_relationship' are server-derived display values. Since -links binds by
            # property name, the natural round-trip (Get-SchoolUserAddress | Update-SchoolUserAddress) sends all
            # of them straight back, and comparing them would report the server's own values as a failed update.
            links           = @{Kind = 'ObjectArray'; MatchFields = @('user_id','type_id'); SubFields = [ordered]@{
                type_id             = @{Kind = 'Scalar'}
                primary             = @{Kind = 'Scalar'}
                user_id             = @{Kind = 'Scalar'}}}
            salutations     = @{Kind = 'Object'; SubFields = [ordered]@{
                informal  = @{Kind = 'Scalar'}
                formal    = @{Kind = 'Scalar'}
                household = @{Kind = 'Scalar'}}}
        }

        # Pipeline binding has not happened yet, so these are the parameters supplied on the command line.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)

        # Every address this invocation has successfully updated. This function takes one address per call,
        # so a batch is always a pipeline, which is why this lives in begin{} rather than process{}. A
        # failure is terminating, so without this the addresses already committed go unreported. There is no
        # matching "not processed" list: records still upstream in a pipeline are unknowable from here.
        $CompletedAddresses = [System.Collections.Generic.List[string]]::new()
    }

    process
    {
        # Appended to every failure below. Computed here because nothing in this record has completed yet, so
        # the list is exactly what was committed before it. Empty on the first record, where it says nothing.
        $BatchBoundary = if ($CompletedAddresses.Count -gt 0)
        {
            [Environment]::NewLine + "Already updated before this failure: $($CompletedAddresses -join '; ')."
        }
        else {''}

        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Build a body using only fields supplied by this pipeline record. The two URL/body IDs are added with
        # the names required by the API. Validate and IncludeUpdatedObject are local control switches rather than
        # request fields.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters `
                      -Exclude 'user_id','address_id','Validate','IncludeUpdatedObject' `
                      -SuppliedNames $SuppliedParameter -As Body
        $parameters['id'] = $address_id
        $parameters['user_id'] = $user_id

        $endUrl = "/addresses/$address_id"

        # The write itself. Wrapped because this is the only failure whose effect on the record cannot be read
        # off the code path: every other failure below happens after a successful write, whereas here it
        # depends on what came back. The catch classifies it, since a refused request and a lost one need
        # opposite advice.
        try
        {
            $response = Update-SKYAPIEntity -uid $user_id -url $endpoint -endUrl $endUrl `
                        -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        }
        catch
        {
            # Only a 4xx is a definite "nothing happened": the server evaluated the request and refused it. A
            # 5xx means the server accepted the request and then failed, which says nothing about whether the
            # write landed first, and 502/504 in particular mean a proxy lost the upstream answer, no
            # different from getting no response at all. Those are retried with backoff before surfacing
            # here, so the write may have been attempted several times. Anything that is not a 4xx is
            # therefore reported as uncertain, which is also the safe default for a status this code did not
            # anticipate. Get-SKYAPIErrorStatusCode returns $null when no response arrived.
            $WriteStatusCode = Get-SKYAPIErrorStatusCode $_
            $WriteOutcome = if ($null -ne $WriteStatusCode -and $WriteStatusCode -ge 400 -and $WriteStatusCode -lt 500)
            {
                "The API rejected the update to address $address_id for user $user_id (HTTP $WriteStatusCode), so that address was not changed."
            }
            elseif ($null -ne $WriteStatusCode)
            {
                "The update to address $address_id for user $user_id failed with HTTP $WriteStatusCode, so whether the API applied it before failing is unknown; check that address before retrying."
            }
            else
            {
                "The update to address $address_id for user $user_id did not complete and no response was received, so whether the API applied it is unknown; check that address before retrying."
            }

            # The outcome line is always worth having, even for the first record: it names the address and says
            # whether anything happened to it. $BatchBoundary is appended only once something has been
            # committed. The original exception is kept as InnerException so nothing about it is lost.
            throw (New-Object System.Exception(
                ($_.Exception.Message + [Environment]::NewLine + $WriteOutcome + $BatchBoundary), $_.Exception))
        }

        $ReadBackRecord = $null
        if ($Validate -or $IncludeUpdatedObject)
        {
            try
            {
                $ReadBackRecord = @(Get-SchoolUserAddress -User_ID $user_id -ErrorAction Stop) |
                                  Where-Object {[string]$_.id -eq [string]$address_id} |
                                  Select-Object -First 1
            }
            catch
            {
                if ($Validate)
                {
                    throw "Update-SchoolUserAddress: address $address_id for user $user_id was updated, but the update could not be verified because Get-SchoolUserAddress failed: $($_.Exception.Message)$BatchBoundary"
                }

                throw "Update-SchoolUserAddress: address $address_id for user $user_id was updated, but the updated object could not be returned because Get-SchoolUserAddress failed: $($_.Exception.Message)$BatchBoundary"
            }

            if ($null -eq $ReadBackRecord -and -not $Validate)
            {
                throw "Update-SchoolUserAddress: address $address_id for user $user_id was updated, but the updated object could not be returned because the address could not be read back.$BatchBoundary"
            }
        }

        if ($Validate)
        {
            $ClearedFieldList = if ($parameters.ContainsKey('fields_to_delete')) { @($parameters['fields_to_delete']) } else { @() }
            $ValidationFindings = @(Confirm-SKYAPIWriteResult -Actual $ReadBackRecord -Expected $parameters `
                -FieldSpec $ValidationFieldSpec -ClearedFields $ClearedFieldList `
                -RecordDescription "address $address_id for user $user_id")

            if ($ValidationFindings.Count -gt 0)
            {
                $Mismatches = @($ValidationFindings | Where-Object {$_.Kind -eq 'Mismatch'})
                $Detail = ($ValidationFindings | ForEach-Object {"  - $($_.Field): $($_.Reason)"}) -join [Environment]::NewLine

                if ($Mismatches.Count -gt 0)
                {
                    throw ("Update-SchoolUserAddress: address $address_id for user $user_id was updated, but validating it found $($ValidationFindings.Count) problem(s):" +
                        [Environment]::NewLine + $Detail + [Environment]::NewLine +
                        'Either the API ignored these values, or the fields are not visible to your account.' + $BatchBoundary)
                }

                throw ("Update-SchoolUserAddress: address $address_id for user $user_id was updated, but $($ValidationFindings.Count) field(s) could not be verified:" +
                    [Environment]::NewLine + $Detail + $BatchBoundary)
            }

            Write-Verbose "Validated address $address_id for user $user_id."
        }

        if ($IncludeUpdatedObject)
        {
            $response | Add-Member -MemberType NoteProperty -Name UpdatedObject -Value $ReadBackRecord
        }

        # This address is done. Recorded before emitting so a later record's failure can name it as committed.
        $CompletedAddresses.Add("address $address_id for user $user_id")

        $response
    }

    end {}
}
