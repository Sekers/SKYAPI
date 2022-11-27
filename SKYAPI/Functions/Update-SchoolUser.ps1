# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersPatch
# Updates the record of a single user. Returns the ID of the user just updated upon success.
# Requires at least one of the following roles in the Education Management system:
#   - Platform Manager
#   - Page Manager
#   - Content Editor

# Parameter,Required,Type,Description
# User_ID,yes,int,Comma delimited list of user IDs for each user you want to update.
# affiliation,no,string,The affiliation of a user.
# custom_field_one,no,string,A custom field on the user profile (one of ten).
# custom_field_two,no,string,A custom field on the user profile (two of ten).
# custom_field_three,no,string,A custom field on the user profile (three of ten).
# custom_field_four,no,string,A custom field on the user profile (four of ten).
# custom_field_five,no,string,A custom field on the user profile (five of ten).
# custom_field_six,no,string,A custom field on the user profile (six of ten).
# custom_field_seven,no,string,A custom field on the user profile (seven of ten).
# custom_field_eight,no,string,A custom field on the user profile (eight of ten).
# custom_field_nine,no,string,A custom field on the user profile (nine of ten).
# custom_field_ten,no,string,A custom field on the user profile (ten of ten).
# dob,no,dateTime,The birthday of a user.
# deceased,boolean,string,Set to true if user is deceased.
# email,no,string,The email address of a user.
# email_active,boolean,string,Set to true if the user's e-mail is OK to send to or false if it should be marked BAD.
# first_name,no,string,The first name of a user.
# gender,no,string,The gender of a user.
# greeting,no,string,The greeting of a user.
# host_id,no,string,The HostId of a user.
# last_name,no,string,The last name of a user.
# lost,boolean,string,Set to true to mark user as being lost.
# maiden_name,no,string,The maiden name of a user.
# middle_name,no,string,The middle name of a user.
# preferred_name,no,string,The preferred name of the user.
# prefix,no,string,The prefix of a user.
# suffix,no,string,The suffix of a user.

function Update-SchoolUser
{
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
        [datetime]$dob,

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
