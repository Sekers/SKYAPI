# https://developer.sky.blackbaud.com/docs/services/school/operations/v1usersget
# Returns a paginated list of users, limited to 100 users per page.
# Requires the 'Platform Manager', 'Billing Clerk', 'Password Manager' or'Contact Card Manager' role in the K12 system.

# Parameter,Required,Type,Description
# roles,yes,string,Comma delimited list of base role IDs to get users for.
# first_name,no,string,Filter results by first name.
# last_name,no,string,Filter results by last name.
# email,no,string,Filter results by e-mail.
# maiden_name,no,string,Filter results by maiden name.
# grad_year,no,string,The beginning date in a school year (ex. 2017).
# end_grad_year,no,string,The end date in a school year (ex. 2018). Enter a grad_year and end_grad_year to find matching results in the date range.
# Marker,no,integer,Use the record number as the marker value to start the data results at a specific spot. For example: marker=101 will return results beginning at that record.
# ResponseLimit,no,integer,Limits response to this number of results.

function Get-SchoolUserList
{
    [cmdletbinding()]
    param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$roles, # This doesn't need to be an array since the parameter takes comma-separated values by default.
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$first_name,
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_name,
       
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$email,
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$maiden_name,
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$grad_year,
        
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_grad_year,
       
        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$Marker,

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit
    )
    
    # Set API responses per page limit.
    $PageLimit = 100

    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::NEXT_RECORD_NUMBER
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users'

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Set/Replace Marker parameter to 1 if not set or 0. That way it can do pagination properly.
    if ($null -eq $Marker -or $Marker -eq '' -or $Marker -eq 0)
    {
        $parameters.Remove('Marker') | Out-Null
        $Marker = 1
        $parameters.Add('Marker',$Marker)
    }

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    $response = Get-PagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
    $response
}
