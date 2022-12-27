# TODO THIS ONE IS NOT READY DUE TO SOME WORK NEEDED AS WELL AS BUGS IN THE ENDPOINT WITH DATES.
function New-SchoolUserOccupation # TODO or Set-*
{ 
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idOccupationsPost
        
        .SYNOPSIS
        Education Management School API - Creates an occupation record for the specified user IDs and returns the ID of the occupation created.

        .DESCRIPTION
        Education Management School API - Creates an occupation record for the specified user IDs and returns the ID of the occupation created.

        .PARAMETER User_ID,
        Required. Array of the user IDs.
        .PARAMETER business_name
        Name of the employing business.
        .PARAMETER job_title
        Employed individual's job title.
        .PARAMETER business_url
        URL of the employing business.
        .PARAMETER industry
        Industry of the employing business.
        .PARAMETER organization
        Maps to the employee's 'Organization' field.
        .PARAMETER occupation
        Maps to the employee's 'Profession' field.
        .PARAMETER matching_gift
        Indicates if employer matches employee donations.
        .PARAMETER begin_date
        Employees start date at this business.
        .PARAMETER end_date
        Employees end date at this business.
        .PARAMETER specialty
        Maps to the employee's 'Specialty' field.
        .PARAMETER parent_company
        Parent company of employing business.
        .PARAMETER job_function
        Description of the work done by the employee.
        .PARAMETER years_employed
        Number of years employee has been at this business.
        .PARAMETER current
        Indicates if this is the individuals current employer.
        
        .EXAMPLE
        
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
        [string]$job_title,

        [Parameter( 
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$business_url,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$industry,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$organization,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$occupation,

        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$matching_gift,

        [Parameter(
        Position=7,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$begin_date,

        [Parameter(
        Position=8,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [Parameter(
        Position=9,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$specialty,

        [Parameter(
        Position=10,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$parent_company,

        [Parameter(
        Position=11,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$job_function,

        [Parameter(
        Position=12,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$years_employed,

        [Parameter(
        Position=13,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$current                                         
    )

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/occupations'

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

    # Verify the phone number type doesn't already exists for any of the users.
    foreach ($uid in $User_ID)
    {
        # $UserPhoneNumbers = Get-SchoolUserPhone -User_ID $uid
        # if ($UserPhoneNumbers.type_id -contains $type_id)
        # {
        #     throw "User $uid already has phone number of type id $type_id"
        # }


    }
    
    # Set data for one or more IDs
    foreach ($uid in $User_ID)
    {      
        $response = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
