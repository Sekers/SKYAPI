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
        .PARAMETER affiliation
        The affiliation of a user.
        .PARAMETER birth_place
        The birthplace of the user.
        .PARAMETER boarding_or_day
        The boarding or day status. Accepted values: boarding, day, B, D.
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
        The living status of a user. Allowed values: Single, Married, Separated, Divorced, Widowed, Partner.
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
        [ValidateSet('Single','Married','Separated','Divorced','Widowed','Partner')]
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
        [object]$visa

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
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the parameters
        $parameters = @{}
        foreach ($parameter in $PSBoundParameters.GetEnumerator())
        {
            $parameters.Add($parameter.Key,$parameter.Value)
        }

        # Remove the $User_ID parameter since we don't pass that on (it's added per-user as 'id' in the request body below).
        $parameters.Remove('User_ID') | Out-Null

        # Normalize nested object parameters: a bare string sets the object's primary field.
        foreach ($objectParam in $ObjectPrimaryFields.GetEnumerator())
        {
            if ($parameters.ContainsKey($objectParam.Key) -and $parameters[$objectParam.Key] -is [string])
            {
                $parameters[$objectParam.Key] = @{ $objectParam.Value = $parameters[$objectParam.Key] }
            }
        }

        # Wrap the Types-table array parameters into the object shape the API expects.
        if ($parameters.ContainsKey('home_languages'))
        {
            $parameters['home_languages'] = @($home_languages | ForEach-Object { @{ language = $_ } })
        }
        if ($parameters.ContainsKey('races'))
        {
            $parameters['races'] = @($races | ForEach-Object { @{ race_type = $_ } })
        }

        # Validate Types-table-backed scalar fields (descriptor or ID). Skipped automatically if the caller can't read the table.
        if ($parameters.ContainsKey('citizenship'))      { Confirm-SKYAPITypeTableValue -Value $citizenship      -TableName 'Citizenship'    -Cache $TypeTableCache -ParameterName 'citizenship' }
        if ($parameters.ContainsKey('ethnicity'))        { Confirm-SKYAPITypeTableValue -Value $ethnicity        -TableName 'Ethnicity'      -Cache $TypeTableCache -ParameterName 'ethnicity' }
        if ($parameters.ContainsKey('religion'))         { Confirm-SKYAPITypeTableValue -Value $religion         -TableName 'Religion'       -Cache $TypeTableCache -ParameterName 'religion' }
        if ($parameters.ContainsKey('pronouns'))         { Confirm-SKYAPITypeTableValue -Value $pronouns         -TableName 'Pronouns'       -Cache $TypeTableCache -ParameterName 'pronouns' }
        if ($parameters.ContainsKey('primary_language')) { Confirm-SKYAPITypeTableValue -Value $primary_language -TableName 'Language'       -Cache $TypeTableCache -ParameterName 'primary_language' }
        if ($parameters.ContainsKey('school_program'))   { Confirm-SKYAPITypeTableValue -Value $school_program   -TableName 'School Program' -Cache $TypeTableCache -ParameterName 'school_program' }

        # Validate the Types-table array fields (one entry at a time).
        if ($parameters.ContainsKey('home_languages'))
        {
            foreach ($language in $home_languages) { Confirm-SKYAPITypeTableValue -Value $language -TableName 'Language' -Cache $TypeTableCache -ParameterName 'home_languages' }
        }
        if ($parameters.ContainsKey('races'))
        {
            foreach ($race in $races) { Confirm-SKYAPITypeTableValue -Value $race -TableName 'Race' -Cache $TypeTableCache -ParameterName 'races' }
        }

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

        # Set data for one or more IDs
        foreach ($uid in $User_ID)
        {
            # Clear out any previous 'id' and add the current one. The endpoint expects the user ID in the request body.
            $parameters.Remove('id') | Out-Null
            $parameters.Add('id',$uid)

            $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            $response
        }
    }

    end {}
}
