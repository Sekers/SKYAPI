function Update-SchoolUser # TODO: WOrking on this one still. Citizenship parameter in help last done.
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

        Requires at least one of the following roles in the Education Management system:
          - Platform Manager
          - Page Manager
          - Content Editor

        .PARAMETER User_ID
        Required. Array of user IDs for each user you want to update.
        .PARAMETER affiliation
        The affiliation of a user.
        .PARAMETER birth_place
        The birthplace of the user.
        .PARAMETER boarding_or_day
        The boarding or day status. Accepted values: boarding, day, "B" and "D".
        .PARAMETER cc_email
        The cc email address of a user.
        .PARAMETER cc_email_active
        Set to true if CCEmail is usable. Allowed value: true, false.
        .PARAMETER citizenship
        The descriptor or ID of the citizenship. Descriptors are not case sensitive, but otherwise must match the table value exactly. These values are returned by the command Get-SchoolTypeTable.
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
        .PARAMETER custom_field_ten,
        A custom field on the user profile (ten of ten).
        .PARAMETER dob
        The birthday of a user (e.g., 1980-01-23).
        .PARAMETER deceased
        Set to true if user is deceased.
        .PARAMETER email
        The email address of a user. If the email address is marked as 'Bad' and this parameter value is different than the existing value, it will no longer be marked as a 'Bad' email address.
        .PARAMETER email_active
        Set to true if the user's e-mail is OK to send to or false if it should be marked BAD.
        .PARAMETER first_name
        The first name of a user.
        .PARAMETER gender
        The gender of a user.
        .PARAMETER greeting
        The greeting of a user.
        .PARAMETER host_id
        The HostId of a user.
        .PARAMETER last_name
        The last name of a user.
        .PARAMETER lost
        Set to true to mark user as being lost.
        .PARAMETER maiden_name
        The maiden name of a user.
        .PARAMETER middle_name
        The middle name of a user.
        .PARAMETER preferred_name
        The preferred name of the user.
        .PARAMETER prefix
        The prefix of a user.
        .PARAMETER suffix
        The suffix of a user.

        .EXAMPLE
        Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
        .EXAMPLE
        Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"
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
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$affiliation,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$birth_place,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$boarding_or_day,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$cc_email,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$cc_email_active,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$citizenship,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [string]$custom_field_one,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_two,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_three,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_four,
        
        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_five,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_six,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_seven,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_eight,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_nine,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_ten,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$dob,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$deceased,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$email_active,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$first_name,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$gender,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$greeting,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$host_id,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_name,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$lost,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$maiden_name,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$middle_name,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$preferred_name,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$prefix,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$suffix
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users'

    # Set the parameters
    $parameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the $User_ID parameter since we don't pass that on
    $parameters.Remove('User_ID') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Set data for one or more IDs
    foreach ($uid in $User_ID)
    {
        [hashtable]$uid_parameters = $parameters.Clone()
        $uid_parameters.Add('id',$uid)
        $response = Update-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $uid_parameters
        $response
    }
}
