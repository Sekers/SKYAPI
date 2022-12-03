function Update-SchoolUser
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersPatch
        
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
        The birthday of a user.
        .PARAMETER deceased
        Set to true if user is deceased.
        .PARAMETER email
        The email address of a user.
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
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$affiliation,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_one,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_two,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_three,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_four,
        
        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_five,

        [Parameter(
        Position=7,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_six,

        [Parameter(
        Position=8,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_seven,

        [Parameter(
        Position=9,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_eight,

        [Parameter(
        Position=10,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_nine,

        [Parameter(
        Position=11,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$custom_field_ten,

        [Parameter(
        Position=12,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [datetime]$dob,

        [Parameter(
        Position=13,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$deceased,

        [Parameter(
        Position=14,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,

        [Parameter(
        Position=15,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$email_active,

        [Parameter(
        Position=16,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$first_name,

        [Parameter(
        Position=17,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$gender,

        [Parameter(
        Position=18,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$greeting,

        [Parameter(
        Position=19,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$host_id,

        [Parameter(
        Position=20,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_name,

        [Parameter(
        Position=21,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$lost,

        [Parameter(
        Position=22,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$maiden_name,

        [Parameter(
        Position=23,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$middle_name,

        [Parameter(
        Position=24,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$preferred_name,

        [Parameter(
        Position=25,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$prefix,

        [Parameter(
        Position=26,
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

    # TODO TEMPORARY FIX - Set email_active to true, no matter what.
    # This is because if you don't specify an email address or if you specify the same email address that is already set, it marks it as BAD.
    # This has the downside of marking active an email address that is supposed to be marked bad.
    $parameters.Add('email_active',$true)

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
