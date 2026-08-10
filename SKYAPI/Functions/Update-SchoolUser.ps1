function Update-SchoolUser
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersPatch

        .SYNOPSIS
        Education Management School API - Updates the record of a single user. Returns the ID of the user just updated upon success.

        .DESCRIPTION
        Education Management School API - Updates the record of a single user. Returns the ID of the user just updated upon success.

        Note: Deleting/clearing data from a field requires the use of the 'fields_to_delete' parameter (described below).

        Requires at least one of the following roles in the Education Management system:
          - Platform Manager
          - Contact Card Manager

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want to update.
        .PARAMETER Validate
        Optional. After each user is updated, re-read that user and confirm every field you supplied actually took effect,
        throwing if any did not. This endpoint returns success without validating the payload, so an unsupported value can
        report as updated while silently changing nothing; this switch catches that. Disabled by default because it costs
        one additional API call per updated user. If IncludeUpdatedObject is also specified, both switches use that same
        call, so together they still make only one additional API call.

        Validation stops at the first user that fails, so later users in the same call are not updated. Users processed
        BEFORE the failure have already been updated at the API and are NOT rolled back. When more than one user ID was
        supplied, the error names both groups ("Already updated before this failure: ..." and "Not processed: ...") so
        you can tell exactly where the batch stopped. If the update request itself fails, the error also says what
        that means for the user it was attempting. An HTTP 4xx is a definite rejection: the API evaluated the request
        and refused it, so that user was not changed. Anything else, a 5xx or no response at all, leaves the outcome
        unknown, because the API may have applied the change before failing, so that user is reported as neither
        updated nor untouched and should be checked before retrying.
        Note that the failure is terminating, so assigning the result (e.g. $r = Update-SchoolUser ...) discards the
        responses for the users that did succeed. Stream the output instead (e.g. Update-SchoolUser ... | ForEach-Object
        {...}) inside a try/catch if you need to keep them.

        Most fields are validated using Get-SchoolUser, which needs no role beyond what this update already requires.
        Validating any of the extended-only fields (birth_place, boarding_or_day, cc_email, cc_email_active, citizenship,
        deceased_date, ethnicity, in_state, international, is_abroad, is_responsible_signer, latino_hispanic, living_status,
        locker, mailbox, passport, personal_bio, primary_language, pronouns, public_bio, races, religion, school_program,
        state_id, student_id, summary_note, visa) uses Get-SchoolUserExtended instead, which may additionally require the
        'SKY API Data Sync' role. If that read is denied, the update still succeeded and an error says it could not be verified.

        One exception: 'summary_note' cannot be validated at all, because no read endpoint returns it. Supplying it together
        with -Validate reports it as unverifiable; the update itself is unaffected.
        .PARAMETER IncludeUpdatedObject
        Re-read each updated user and attach that record to the returned user ID as an UpdatedObject property. This can
        be used with or without Validate. The read-back requires one additional API call per updated user. If Validate
        is also specified, both switches use that same call, so together they still make only one additional API call.
        Depending on the supplied update fields, UpdatedObject comes from either Get-SchoolUser or Get-SchoolUserExtended.
        The function throws if the selected user read fails.
        .PARAMETER affiliation
        The affiliation of a user.
        .PARAMETER birth_place
        The birthplace of the user.
        .PARAMETER boarding_or_day
        The boarding or day status. Accepted values: boarding, day, B, D.
        Note: this field reads back as a single-letter code, so 'boarding' returns 'b' and 'day' returns 'd'.
        .PARAMETER cc_email
        The cc email address of a user.
        .PARAMETER cc_email_active
        Set to true if the cc email is usable. Allowed values: true, false.
        .PARAMETER citizenship
        The descriptor or ID of the citizenship. Get valid values from Get-SchoolTypeTableValue -tableName 'Citizenship'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER custom_field_one
        A custom field on the user profile (one of ten).
        .PARAMETER custom_field_two
        A custom field on the user profile (two of ten).
        .PARAMETER custom_field_three
        A custom field on the user profile (three of ten).
        .PARAMETER custom_field_four
        A custom field on the user profile (four of ten).
        .PARAMETER custom_field_five
        A custom field on the user profile (five of ten).
        .PARAMETER custom_field_six
        A custom field on the user profile (six of ten).
        .PARAMETER custom_field_seven
        A custom field on the user profile (seven of ten).
        .PARAMETER custom_field_eight
        A custom field on the user profile (eight of ten).
        .PARAMETER custom_field_nine
        A custom field on the user profile (nine of ten).
        .PARAMETER custom_field_ten
        A custom field on the user profile (ten of ten).
        .PARAMETER deceased
        Set to true if the user is deceased. Allowed values: true, false. Defaults to false.
        .PARAMETER deceased_date
        The deceased date of the user (e.g., 2022-04-08).
        .PARAMETER dob
        The birthday of a user (e.g., 1980-01-23).
        .PARAMETER email
        The email address of a user. If the email address is marked as 'Bad' and this parameter value is different than the existing value, it will no longer be marked as a 'Bad' email address.
        .PARAMETER email_active
        Set to true if the user's email is OK to send to or false if it should be marked BAD. Allowed values: true, false.
        .PARAMETER ethnicity
        The descriptor or ID of the ethnicity. Get valid values from Get-SchoolTypeTableValue -tableName 'Ethnicity'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER fields_to_delete
        An array of field names to clear/delete. This is the only way to blank a field via this endpoint. Due to an inherent
        check against deleting data only accessible through the UI, this step is necessary to clear a field (such as middle_name
        or living_status). If a field is included in this array, its data will be deleted and this overrides any other value set
        for that field in the same request. Use the request-body field name (e.g., 'middle_name'); for fields within an object,
        use object.field notation (e.g., 'passport.number' or 'locker.number'). Fields that cannot be cleared (required fields,
        Booleans, or fields with no blank option) are ignored.
        .PARAMETER first_name
        The first name of a user.
        .PARAMETER gender
        The gender of a user.
        .PARAMETER greeting
        The greeting of a user.
        .PARAMETER home_languages
        One or more languages. Each entry is the descriptor or ID of a language. Get valid values from Get-SchoolTypeTableValue -tableName 'Language'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER host_id
        The HostId of a user.
        .PARAMETER in_state
        The user's In-State residency information. Provide a hashtable/PSCustomObject with any of: resident (Yes or No), county, from_date.
        Alternatively, provide a single string, which sets 'resident'.
        To clear a field, use -fields_to_delete (e.g. -fields_to_delete 'in_state.resident').
        .PARAMETER international
        Whether the user is an international user. Allowed values: Yes, No. To clear the field, use -fields_to_delete 'international'.
        .PARAMETER is_abroad
        Set to true if the user is currently abroad. Allowed values: true, false. Defaults to false.
        .PARAMETER is_responsible_signer
        Set to true if the user is a responsible signer. Allowed values: true, false. Defaults to false.
        .PARAMETER last_name
        The last name of a user.
        .PARAMETER latino_hispanic
        Whether the user is Latino/Hispanic. Allowed values: Yes, No. To clear the field, use -fields_to_delete 'latino_hispanic'.
        .PARAMETER living_status
        The living status of a user. Allowed values: Single, Married, Remarried, Separated, Divorced, Widowed, Partner.
        .PARAMETER locker
        The user's locker information. Provide a hashtable/PSCustomObject with any of: number, combo.
        Alternatively, provide a single string, which sets 'number'.
        .PARAMETER lost
        Set to true to mark the user as being lost.
        .PARAMETER maiden_name
        The maiden name of a user.
        .PARAMETER mailbox
        The user's mailbox information. Provide a hashtable/PSCustomObject with any of: number, combo.
        Alternatively, provide a single string, which sets 'number'.
        .PARAMETER middle_name
        The middle name of a user.
        .PARAMETER passport
        The user's passport information. Provide a hashtable/PSCustomObject with any of: number, expire_date.
        Alternatively, provide a single string, which sets 'number'.
        .PARAMETER personal_bio
        The personal bio of the user.
        .PARAMETER preferred_lastname
        The preferred last name of a user.
        .PARAMETER preferred_name
        The preferred name of the user.
        .PARAMETER primary_language
        The descriptor or ID of the primary language. Get valid values from Get-SchoolTypeTableValue -tableName 'Language'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER prefix
        The prefix of a user.
        .PARAMETER pronouns
        The descriptor or ID of the pronouns. Get valid values from Get-SchoolTypeTableValue -tableName 'Pronouns'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER public_bio
        The public bio of the user.
        .PARAMETER races
        One or more races. Each entry is the descriptor or ID of a race. Get valid values from Get-SchoolTypeTableValue -tableName 'Race'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER religion
        The descriptor or ID of the religion. Get valid values from Get-SchoolTypeTableValue -tableName 'Religion'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER school_program
        The descriptor or ID of the school program. Get valid values from Get-SchoolTypeTableValue -tableName 'School Program'.
        Descriptors are not case sensitive, but otherwise must match the table value exactly.
        .PARAMETER state_id
        The state assigned ID of the user.
        .PARAMETER student_id
        The school assigned ID of the user.
        .PARAMETER suffix
        The suffix of a user.
        .PARAMETER summary_note
        The summary note of the user.
        .PARAMETER visa
        The user's visa information. Provide a hashtable/PSCustomObject with any of: number, status, type, issue_date, expire_date.
        Alternatively, provide a single string, which sets 'number'. The 'status' and 'type' values are the descriptor or ID from the
        'Visa Status' and 'Visa Type' tables (see Get-SchoolTypeTableValue).

        .EXAMPLE
        Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
        .EXAMPLE
        Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"
        .EXAMPLE
        # Bare-string shortcut for an object field (sets locker.number) alongside a validated Types-table field.
        Update-SchoolUser -User_ID 1757293 -locker '1234' -citizenship 'United States'
        .EXAMPLE
        # Full nested objects and multi-value Types-table arrays.
        $params = @{
            User_ID        = 1757293
            visa           = @{ number = '12345678'; status = 'Current'; type = 'Student'; expire_date = '2025-09-28' }
            in_state       = @{ resident = 'Yes'; county = 'Merrimack'; from_date = '1987-02-14' }
            home_languages = 'English','French'
            races          = 'American Indian or Alaska Native'
        }
        Update-SchoolUser @params
        .EXAMPLE
        # Clear/blank fields (the only way to delete data via this endpoint).
        Update-SchoolUser -User_ID 1757293 -fields_to_delete 'middle_name','passport.number'
        .EXAMPLE
        # Confirm the change actually applied instead of trusting the API's success response.
        Update-SchoolUser -User_ID 1757293 -middle_name 'Alpha' -Validate

        .EXAMPLE
        # Validate the change and retain both the user ID response and the user record used for validation.
        Update-SchoolUser -User_ID 1757293 -middle_name 'Alpha' -Validate -IncludeUpdatedObject

        .OUTPUTS
        Returns each user ID from the update endpoint. With IncludeUpdatedObject, each ID gains an UpdatedObject
        property containing the basic or extended user record selected for the read-back.
    #>

    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$affiliation,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$birth_place,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('boarding','day','B','D')]
        [string]$boarding_or_day,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$cc_email,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$cc_email_active,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$citizenship,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_one,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_two,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_three,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_four,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_five,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_six,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_seven,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_eight,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_nine,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_ten,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$deceased,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$deceased_date,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$dob,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$email_active,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$ethnicity,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$fields_to_delete,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$first_name,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$gender,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$greeting,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$home_languages,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$host_id,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [object]$in_state,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('Yes','No')]
        [string]$international,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$is_abroad,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$is_responsible_signer,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_name,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('Yes','No')]
        [string]$latino_hispanic,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        # 'Remarried' is absent from the endpoint's published field description but is offered by the web GUI
        # and reads back correctly; confirmed by test against the developer tenant.
        [ValidateSet('Single','Married','Remarried','Separated','Divorced','Widowed','Partner')]
        [string]$living_status,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [object]$locker,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [bool]$lost,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$maiden_name,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [object]$mailbox,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$middle_name,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [object]$passport,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$personal_bio,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$preferred_lastname,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$preferred_name,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$primary_language,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$prefix,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$pronouns,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$public_bio,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string[]]$races,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$religion,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$school_program,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$state_id,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$student_id,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$suffix,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [string]$summary_note,

        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [object]$visa,

        # Control switch (not a request field). It is removed from the request body in the process block below.
        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [switch]$Validate,

        # Control switch (not a request field). It is removed from the request body in the process block below.
        [Parameter(
        ValueFromPipelineByPropertyName=$true)]
        [switch]$IncludeUpdatedObject

        # TODO: Profile Photos - the 'profile_photos' field is not yet implemented. It requires a temp_name obtained from the
        #       Attachment (Create) upload endpoint, which this module does not yet support. Implement together with that endpoint.
    )

    begin
    {
        # Set the endpoint. The user ID is passed in the request body (as 'id'), not in the URL, so there is no trailing
        # segment here and Update-SKYAPIEntity is called without -uid.
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Cache for Types table lookups so each referenced table is only fetched once per command invocation.
        $TypeTableCache = @{}

        # Nested object parameters. A bare string maps to the object's primary field (below); a hashtable/PSCustomObject
        # is passed through 1:1 with the API model.
        $ObjectPrimaryFields = [ordered]@{
            locker   = 'number'
            mailbox  = 'number'
            passport = 'number'
            visa     = 'number'
            in_state = 'resident'
        }

        # How -Validate compares each request field against the re-read record. Only used when -Validate is passed.
        #  Read      - the field's name in the extended user read (Get-SchoolUserExtended).
        #  BasicRead - the field's name in the basic user read (Get-SchoolUser). Absent means the basic read doesn't
        #              return this field, which is what drives the read-source choice in the process block.
        #  Kind      - Scalar (default), Date, TypeTable, TypeTableArray, or Object.
        $ValidationFieldSpec = [ordered]@{}

        # Plain fields both reads return under the same name.
        foreach ($ValidationField in @(
            'affiliation','custom_field_one','custom_field_two','custom_field_three','custom_field_four','custom_field_five',
            'custom_field_six','custom_field_seven','custom_field_eight','custom_field_nine','custom_field_ten','deceased',
            'email','email_active','first_name','gender','greeting','host_id','last_name','lost','maiden_name','middle_name',
            'preferred_name','prefix','suffix'))
        {
            $ValidationFieldSpec[$ValidationField] = @{Kind = 'Scalar'; Read = $ValidationField; BasicRead = $ValidationField}
        }

        # Plain fields only the extended read returns.
        foreach ($ValidationField in @(
            'birth_place','cc_email','cc_email_active','international','is_responsible_signer','latino_hispanic',
            'personal_bio','public_bio','state_id','student_id'))
        {
            $ValidationFieldSpec[$ValidationField] = @{Kind = 'Scalar'; Read = $ValidationField}
        }

        # Fields the reads return under a different name than the request uses.
        $ValidationFieldSpec['preferred_lastname'] = @{Kind = 'Scalar'; Read = 'preferred_last_name'; BasicRead = 'preferred_last_name'}
        $ValidationFieldSpec['is_abroad']          = @{Kind = 'Scalar'; Read = 'abroad'}
        $ValidationFieldSpec['dob']                = @{Kind = 'Date';   Read = 'birth_date'; BasicRead = 'dob'}
        $ValidationFieldSpec['deceased_date']      = @{Kind = 'Date';   Read = 'deceased_date'}
        # boarding_or_day reads back as a single-letter code, in the case it was sent: 'day' returns 'd',
        # 'boarding' returns 'b', 'B' returns 'B'. The alias fold below is case-insensitive, so all four
        # accepted spellings validate; see the cases in Tests/TestWriteValidation_Comparator.ps1.
        $ValidationFieldSpec['boarding_or_day']    = @{Kind = 'Scalar'; Read = 'boarding_or_day'; Aliases = @{B = 'boarding'; D = 'day'}}

        # 'living_status' is returned as 'living_arrangement'. No read model in the School API returns the request name, so
        # this was confirmed by test: setting living_status changed exactly living_arrangement and nothing else.
        $ValidationFieldSpec['living_status'] = @{Kind = 'Scalar'; Read = 'living_arrangement'}

        # 'summary_note' is write-only as far as this API is concerned: it is returned by no read endpoint the module has.
        # Confirmed by test - writing a unique sentinel to it changed no property of the extended read, and the sentinel is
        # absent from the raw JSON of both the basic and extended reads (only audit_date/last_modified_date moved).
        # It is NOT 'misc_bio', despite that being the only leftover of the bio family: misc_bio mirrors 'public_bio'.
        # Marked Unmapped so -Validate reports it as unverifiable rather than failing a write that actually succeeded.
        $ValidationFieldSpec['summary_note'] = @{Kind = 'Scalar'; Unmapped = $true}

        # Types-table-backed fields. Sent as a descriptor or an ID; read back as a descriptor.
        $ValidationFieldSpec['citizenship']      = @{Kind = 'TypeTable'; Read = 'citizenship';      Table = 'Citizenship'}
        $ValidationFieldSpec['ethnicity']        = @{Kind = 'TypeTable'; Read = 'ethnicity';        Table = 'Ethnicity'}
        $ValidationFieldSpec['religion']         = @{Kind = 'TypeTable'; Read = 'religion';         Table = 'Religion'}
        $ValidationFieldSpec['pronouns']         = @{Kind = 'TypeTable'; Read = 'pronouns';         Table = 'Pronouns'}
        $ValidationFieldSpec['primary_language'] = @{Kind = 'TypeTable'; Read = 'primary_language'; Table = 'Language'}
        $ValidationFieldSpec['school_program']   = @{Kind = 'TypeTable'; Read = 'school_program';   Table = 'School Program'}

        # Types-table arrays. The read side returns different property names than the request, so these compare as an
        # order-insensitive set of resolved table IDs.
        $ValidationFieldSpec['races'] = @{
            Kind = 'TypeTableArray'; Read = 'races'; Table = 'Race'
            ItemKey = 'race_type'; ReadItemKey = 'race_type_id'
        }
        $ValidationFieldSpec['home_languages'] = @{
            Kind = 'TypeTableArray'; Read = 'home_languages'; BasicRead = 'home_languages'; Table = 'Language'
            ItemKey = 'language'; ReadItemKey = 'id'
        }

        # Nested objects. Only the sub-fields actually supplied are compared.
        $ValidationFieldSpec['locker']   = @{Kind = 'Object'; Read = 'locker';   SubFields = @{number = @{Kind = 'Scalar'}; combo = @{Kind = 'Scalar'}}}
        $ValidationFieldSpec['mailbox']  = @{Kind = 'Object'; Read = 'mailbox';  SubFields = @{number = @{Kind = 'Scalar'}; combo = @{Kind = 'Scalar'}}}
        $ValidationFieldSpec['passport'] = @{Kind = 'Object'; Read = 'passport'; SubFields = @{number = @{Kind = 'Scalar'}; expire_date = @{Kind = 'Date'}}}
        $ValidationFieldSpec['in_state'] = @{Kind = 'Object'; Read = 'in_state'; SubFields = @{
            resident = @{Kind = 'Scalar'}; county = @{Kind = 'Scalar'}; from_date = @{Kind = 'Date'}}}
        # visa is sent with plain-string status/type but read back with those as {id, description} objects.
        $ValidationFieldSpec['visa'] = @{Kind = 'Object'; Read = 'visa'; SubFields = @{
            number      = @{Kind = 'Scalar'}
            status      = @{Kind = 'TypeTable'; Table = 'Visa Status'}
            type        = @{Kind = 'TypeTable'; Table = 'Visa Type'}
            issue_date  = @{Kind = 'Date'}
            expire_date = @{Kind = 'Date'}}}

        # Capture the command-line arguments while $PSBoundParameters still holds only those. See
        # Get-SKYAPISuppliedParameterName: they apply to every record, whereas anything added later belongs
        # to one record and must not leak into the next.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)

        # Every user this invocation has successfully updated, across ALL pipeline records. It lives here
        # rather than in process{} so that a failure on a later record still reports the users an earlier
        # record committed; scoping it per record would report "none" while updates had in fact been made.
        $CompletedUserIds = [System.Collections.Generic.List[int]]::new()
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the parameters. User_ID isn't passed on (it's added per-user as 'id' in the request body below), and
        # Validate and IncludeUpdatedObject direct this function's behavior rather than the API request body.
        # -SuppliedNames drops fields left over from an earlier pipeline record; without it, piping users where
        # only the first sets a field wrote that field's value to all of them.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters `
                      -Exclude 'User_ID','Validate','IncludeUpdatedObject' `
                      -SuppliedNames $SuppliedParameter -As Body

        # Normalize nested object parameters: a bare string sets the object's primary field.
        foreach ($objectParam in $ObjectPrimaryFields.GetEnumerator())
        {
            if ($parameters.ContainsKey($objectParam.Key) -and $parameters[$objectParam.Key] -is [string])
            {
                $parameters[$objectParam.Key] = @{ $objectParam.Value = $parameters[$objectParam.Key] }
            }
        }

        # Everything below reads its value out of $parameters rather than out of the like-named parameter
        # variable. The two are not interchangeable across a pipeline: PowerShell resets the variables per
        # record but not $PSBoundParameters, so gating on one while reading the other used to send an empty
        # array for a field a later record never supplied. $parameters is now the single source of truth.

        # Pre-flight validation, all of which runs BEFORE anything is sent for this record. Wrapped so that a
        # failure here still names the users an earlier pipeline record already committed. Those writes are
        # done and are not rolled back, and without this the caller sees only a bare "Invalid 'races' value"
        # with no hint that anything had been written. The in-loop failures below carry their own boundary.
        try
        {
            # Validate the Types-table array fields (one entry at a time), then wrap them into the object shape
            # the API expects. Validation comes first so it sees the plain values.
            if ($parameters.ContainsKey('home_languages'))
            {
                foreach ($language in $parameters['home_languages']) { Confirm-SKYAPITypeTableValue -Value $language -TableName 'Language' -Cache $TypeTableCache -ParameterName 'home_languages' }
                $parameters['home_languages'] = @($parameters['home_languages'] | ForEach-Object { @{ language = $_ } })
            }
            if ($parameters.ContainsKey('races'))
            {
                foreach ($race in $parameters['races']) { Confirm-SKYAPITypeTableValue -Value $race -TableName 'Race' -Cache $TypeTableCache -ParameterName 'races' }
                $parameters['races'] = @($parameters['races'] | ForEach-Object { @{ race_type = $_ } })
            }

            # Validate Types-table-backed scalar fields (descriptor or ID). Skipped automatically if the caller can't read the table.
            if ($parameters.ContainsKey('citizenship'))      { Confirm-SKYAPITypeTableValue -Value $parameters['citizenship']      -TableName 'Citizenship'    -Cache $TypeTableCache -ParameterName 'citizenship' }
            if ($parameters.ContainsKey('ethnicity'))        { Confirm-SKYAPITypeTableValue -Value $parameters['ethnicity']        -TableName 'Ethnicity'      -Cache $TypeTableCache -ParameterName 'ethnicity' }
            if ($parameters.ContainsKey('religion'))         { Confirm-SKYAPITypeTableValue -Value $parameters['religion']         -TableName 'Religion'       -Cache $TypeTableCache -ParameterName 'religion' }
            if ($parameters.ContainsKey('pronouns'))         { Confirm-SKYAPITypeTableValue -Value $parameters['pronouns']         -TableName 'Pronouns'       -Cache $TypeTableCache -ParameterName 'pronouns' }
            if ($parameters.ContainsKey('primary_language')) { Confirm-SKYAPITypeTableValue -Value $parameters['primary_language'] -TableName 'Language'       -Cache $TypeTableCache -ParameterName 'primary_language' }
            if ($parameters.ContainsKey('school_program'))   { Confirm-SKYAPITypeTableValue -Value $parameters['school_program']   -TableName 'School Program' -Cache $TypeTableCache -ParameterName 'school_program' }

            # Validate the Types-table sub-fields of the visa object.
            if ($parameters.ContainsKey('visa'))
            {
                $visaObject = $parameters['visa']
                if ($visaObject -is [System.Collections.IDictionary])
                {
                    $visaStatus = $visaObject['status']
                    $visaType   = $visaObject['type']
                }
                else
                {
                    $visaStatus = $visaObject.status
                    $visaType   = $visaObject.type
                }
                Confirm-SKYAPITypeTableValue -Value $visaStatus -TableName 'Visa Status' -Cache $TypeTableCache -ParameterName 'visa.status'
                Confirm-SKYAPITypeTableValue -Value $visaType   -TableName 'Visa Type'   -Cache $TypeTableCache -ParameterName 'visa.type'
            }

            # Validate the fixed-list in_state.resident sub-field (not a Types table).
            if ($parameters.ContainsKey('in_state'))
            {
                $inStateObject = $parameters['in_state']
                if ($inStateObject -is [System.Collections.IDictionary])
                {
                    $resident = $inStateObject['resident']
                }
                else
                {
                    $resident = $inStateObject.resident
                }
                if (-not [string]::IsNullOrWhiteSpace($resident) -and $resident -notin @('Yes','No'))
                {
                    throw "Invalid 'in_state.resident' value '$resident'. Allowed values: Yes, No. To clear the field, use -fields_to_delete 'in_state.resident'."
                }
            }
        }
        catch
        {
            # Nothing has been committed yet in this invocation, so the original error already tells the whole
            # story. Rethrow it untouched, which also preserves its exception type.
            if ($CompletedUserIds.Count -eq 0) { throw }

            # Nothing in THIS record was sent either, so its entire ID list is unprocessed.
            throw ($_.Exception.Message + [Environment]::NewLine +
                "Already updated before this failure: $($CompletedUserIds -join ', ')." + [Environment]::NewLine +
                "Not processed: $($User_ID -join ', ').")
        }

        # Work out which read the requested read-back needs. The basic read requires no role beyond the update itself,
        # so prefer it and only fall back to the extended read when a field needs it.
        if ($Validate -or $IncludeUpdatedObject)
        {
            # From $parameters, not $fields_to_delete, for the per-record reason given above. Test the key
            # rather than wrapping the lookup: @($parameters['missing']) is an array holding one $null, not
            # an empty one, and the loop below would then call .Split() on $null.
            $ClearedFieldList = if ($parameters.ContainsKey('fields_to_delete')) { @($parameters['fields_to_delete']) } else { @() }

            $ReadBackFields = @($parameters.Keys | Where-Object {$ValidationFieldSpec.Contains($_)})
            foreach ($ClearedField in $ClearedFieldList)
            {
                $ReadBackFields += $ClearedField.Split('.')[0]
            }

            $ValidationReadModel = 'Basic'
            foreach ($ReadBackField in $ReadBackFields)
            {
                if (-not $ValidationFieldSpec.Contains($ReadBackField) -or -not $ValidationFieldSpec[$ReadBackField].Contains('BasicRead'))
                {
                    $ValidationReadModel = 'Extended'
                    break
                }
            }
        }

        # How far through THIS record's ID array we are. Unlike $CompletedUserIds (invocation-wide, set in
        # begin), this is per record, because it indexes into this record's own $User_ID.
        $UserIndex = -1

        # Set data for one or more IDs
        foreach ($uid in $User_ID)
        {
            $UserIndex++

            # Appended to every failure in this loop. Left empty only when there is genuinely nothing to
            # report: a single ID with no earlier successes, where the boundary would be pure noise. Note
            # 'Not processed' can only cover the rest of THIS record's array; records still upstream in a
            # pipeline are unknowable from here.
            $BatchBoundary = ''
            if ($User_ID.Count -gt 1 -or $CompletedUserIds.Count -gt 0)
            {
                $NotProcessed = if ($UserIndex -lt $User_ID.Count - 1) {$User_ID[($UserIndex + 1)..($User_ID.Count - 1)]} else {@()}
                $BatchBoundary = [Environment]::NewLine +
                    "Already updated before this failure: $(if ($CompletedUserIds.Count) {$CompletedUserIds -join ', '} else {'none'})." +
                    [Environment]::NewLine +
                    "Not processed: $(if ($NotProcessed.Count) {$NotProcessed -join ', '} else {'none'})."
            }

            # Clear out any previous 'id' and add the current one. The endpoint expects the user ID in the request body.
            $parameters.Remove('id') | Out-Null
            $parameters.Add('id',$uid)

            # The write itself. Wrapped because this is the only failure whose effect on the record cannot be
            # read off the code path: every other failure below happens after a successful write, whereas here
            # it depends on what came back. The catch classifies it, since a refused request and a lost one
            # need opposite advice.
            try
            {
                $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            }
            catch
            {
                # Only a 4xx is a definite "nothing happened": the server evaluated the request and refused it.
                # A 5xx means the server accepted the request and then failed, which says nothing about
                # whether the write landed first, and 502/504 in particular mean a proxy lost the upstream
                # answer, no different from getting no response at all. Those are retried with backoff before
                # surfacing here, so the write may have been attempted several times. Anything that is not a
                # 4xx is therefore reported as uncertain, which is also the safe default for a status this
                # code did not anticipate. Get-SKYAPIErrorStatusCode returns $null when no response arrived.
                $WriteStatusCode = Get-SKYAPIErrorStatusCode $_
                $WriteOutcome = if ($null -ne $WriteStatusCode -and $WriteStatusCode -ge 400 -and $WriteStatusCode -lt 500)
                {
                    "The API rejected the update to user $uid (HTTP $WriteStatusCode), so that user was not changed."
                }
                elseif ($null -ne $WriteStatusCode)
                {
                    "The update to user $uid failed with HTTP $WriteStatusCode, so whether the API applied it before failing is unknown; check that user before retrying."
                }
                else
                {
                    "The update to user $uid did not complete and no response was received, so whether the API applied it is unknown; check that user before retrying."
                }

                # The outcome line is always worth having, even for a lone record: it names the user and says
                # whether anything happened to it. $BatchBoundary is appended only when there is a batch to
                # describe, so a single-user call is not padded with two 'none' lines. The original exception
                # is kept as InnerException so nothing about it is lost.
                throw (New-Object System.Exception(
                    ($_.Exception.Message + [Environment]::NewLine + $WriteOutcome + $BatchBoundary), $_.Exception))
            }

            $ReadBackRecord = $null
            if ($Validate -or $IncludeUpdatedObject)
            {
                if ($Validate)
                {
                    Write-Verbose "Validating the update to user $uid using the $($ValidationReadModel.ToLower()) user read."
                }
                else
                {
                    Write-Verbose "Reading back the updated user $uid using the $($ValidationReadModel.ToLower()) user read."
                }

                try
                {
                    if ($ValidationReadModel -eq 'Basic')
                    {
                        $ReadBackRecord = Get-SchoolUser -User_ID $uid -ErrorAction Stop
                    }
                    else
                    {
                        $ReadBackRecord = Get-SchoolUserExtended -User_ID $uid -ErrorAction Stop
                    }
                }
                catch
                {
                    $ReadFunction = if ($ValidationReadModel -eq 'Basic') {'Get-SchoolUser'} else {'Get-SchoolUserExtended'}
                    $RoleHint = if ($ValidationReadModel -eq 'Basic') {''} else {" This read uses $ReadFunction, which may require the 'SKY API Data Sync' role in addition to the roles this update needs."}
                    if ($Validate)
                    {
                        throw "Update-SchoolUser: user $uid was updated, but the update could not be verified because $ReadFunction failed: $($_.Exception.Message)$RoleHint$BatchBoundary"
                    }

                    throw "Update-SchoolUser: user $uid was updated, but the updated object could not be returned because $ReadFunction failed: $($_.Exception.Message)$RoleHint$BatchBoundary"
                }

                if ($null -eq $ReadBackRecord -and -not $Validate)
                {
                    throw "Update-SchoolUser: user $uid was updated, but the updated object could not be returned because the user could not be read back.$BatchBoundary"
                }
            }

            # Confirm the update actually took effect. The endpoint reports success without validating the payload, so an
            # unsupported value can come back "updated" having silently changed nothing.
            if ($Validate)
            {
                $ValidationFindings = @(Confirm-SKYAPIWriteResult -Actual $ReadBackRecord -Expected $parameters -FieldSpec $ValidationFieldSpec `
                    -ReadModel $ValidationReadModel -ClearedFields $ClearedFieldList -Cache $TypeTableCache -RecordDescription "user $uid")

                if ($ValidationFindings.Count -gt 0)
                {
                    # The update has already been sent and is not rolled back, so say so, and don't claim the API ignored a
                    # field when a value we couldn't read back is equally consistent with the field not being visible.
                    $Mismatches = @($ValidationFindings | Where-Object {$_.Kind -eq 'Mismatch'})
                    $Detail = ($ValidationFindings | ForEach-Object {"  - $($_.Field): $($_.Reason)"}) -join [Environment]::NewLine

                    if ($Mismatches.Count -gt 0)
                    {
                        throw ("Update-SchoolUser: the update to user $uid was sent successfully, but validating it found $($ValidationFindings.Count) problem(s):" +
                            [Environment]::NewLine + $Detail + [Environment]::NewLine +
                            'Either the API ignored these values, or the fields are not visible to your account.' + $BatchBoundary)
                    }

                    throw ("Update-SchoolUser: user $uid was updated, but $($ValidationFindings.Count) field(s) could not be verified:" +
                        [Environment]::NewLine + $Detail + $BatchBoundary)
                }

                Write-Verbose "Validated the update to user $uid."
            }

            if ($IncludeUpdatedObject)
            {
                $response | Add-Member -MemberType NoteProperty -Name UpdatedObject -Value $ReadBackRecord
            }

            # This user is done. Recorded before emitting so a later user's failure can name it as committed.
            $CompletedUserIds.Add($uid)

            $response
        }
    }

    end {}
}
