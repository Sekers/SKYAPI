# TODO - There is a bug with the dates not appearing correctly on the website when submitting occupations on this endpoint. I have a support request open with Blackbaud
#        They were able to replicate the issue and have passed it on to the product development team for further review.
#
#        RETESTED 2026-07-28: NOT fixed. Occupation dates still come back in an encoding used by no other
#        endpoint - school midnight converted to UTC, so the time component is 04:00 or 05:00 rather than
#        00:00, e.g. "1923-01-25T05:00:00+00:00" (midnight EST) and "2022-03-15T04:00:00+00:00" (midnight
#        EDT). Every other date-only field on the user endpoints arrives at midnight with the school's own
#        offset. Because the shape alone cannot be told apart from a real timestamp, Get-SchoolUserOccupation
#        and Get-SchoolUserExtended name begin_date/end_date explicitly when normalizing (see
#        Research_Notes/DateTime-Handling.md), so reads now return the correct calendar date regardless.
#        What was NOT retested is how the website renders them, which is what the support request was about.

function New-SchoolUserOccupation
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idOccupationsPost

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
        New-SchoolUserOccupation -User_ID 3156271, 3294459 -business_name "Don's Auto" -job_title "Director of Shiny Things" -current $true
        .EXAMPLE
        $params = @{
            'User_ID'           = 3156271
            'business_name'     = "Don's Auto"
            'job_title'         = "Director of Shiny Things"
            'business_url'      = "https://donsauto.com"
            'industry'          = "Automotive"
            'organization'      = "Don's Group"
            'occupation'        = "Mechanical Technician"
            'matching_gift'     = $true
            'begin_date'        = "2020-07-01"
            'end_date'          = "2023-06-30"
            'specialty'         = "Classic Cars"
            'parent_company'    = "Don's Group"
            'job_function'      = "Rebuilds classic cars into shiny new beasts."
            'years_employed'    = 3
            'current'           = $false
        }
        New-SchoolUserOccupation @params
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
        ValueFromPipelineByPropertyName=$true)]
        [string]$business_name,

        [Parameter(
        Position=2,
        ValueFromPipelineByPropertyName=$true)]
        [string]$job_title,

        [Parameter(
        Position=3,
        ValueFromPipelineByPropertyName=$true)]
        [string]$business_url,

        [Parameter(
        Position=4,
        ValueFromPipelineByPropertyName=$true)]
        [string]$industry,

        [Parameter(
        Position=5,
        ValueFromPipelineByPropertyName=$true)]
        [string]$organization,

        [Parameter(
        Position=6,
        ValueFromPipelineByPropertyName=$true)]
        [string]$occupation,

        [Parameter(
        Position=7,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$matching_gift,

        [Parameter(
        Position=8,
        ValueFromPipelineByPropertyName=$true)]
        [string]$begin_date,

        [Parameter(
        Position=9,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [Parameter(
        Position=10,
        ValueFromPipelineByPropertyName=$true)]
        [string]$specialty,

        [Parameter(
        Position=11,
        ValueFromPipelineByPropertyName=$true)]
        [string]$parent_company,

        [Parameter(
        Position=12,
        ValueFromPipelineByPropertyName=$true)]
        [string]$job_function,

        [Parameter(
        Position=13,
        ValueFromPipelineByPropertyName=$true)]
        [int]$years_employed,

        [Parameter(
        Position=14,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$current
    )

    begin
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
        $endUrl = '/occupations'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Capture the command-line arguments while $PSBoundParameters still holds only those.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the parameters. User_ID is excluded since we don't pass that on. -SuppliedNames keeps fields
        # from one pipeline record out of the next; see Get-SKYAPISuppliedParameterName.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'User_ID' `
                      -SuppliedNames $SuppliedParameter -As Body

        # Set data for one or more IDs
        foreach ($uid in $User_ID)
        {
            $response = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            $response
        }
    }

    end {}
}
