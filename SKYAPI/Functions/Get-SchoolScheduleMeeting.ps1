function Get-SchoolScheduleMeeting
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1SchedulesMeetingsGet
        
        .SYNOPSIS
        Education Management School API - Returns a list of section meetings for a given date.

        .DESCRIPTION
        Education Management School API - Returns a list of section meetings for a given date.
        When end_date is supplied, a range of meetings between the given dates is returned.
        If end_date is not supplied, Get-SchoolScheduleMeeting defaults to 30 days from start_date.

        Additional Notes:
          - Returned meeting start & end times are in UTC DateTime format.
          - Returned meeting date is the date of the meeting in the School Time Zone as specified at https://[school_domain_here].myschoolapp.com/app/core#demographics.

        .PARAMETER start_date
        Required. Start date of events you want returned. Use ISO-8601 date format (e.g., 2022-04-01).
        .PARAMETER end_date
        End date of events you want returned. Use ISO-8601 date format (2022-04-08).
        If not specified, defaults to 30 days from start_date.
        .PARAMETER offering_types
        Can take a single or multiple values as a comma delimited string of integers (defaults to 1 'Academics').
        Use Get-SchoolOfferingType to get a list of offering types.
        .PARAMETER section_ids
        Comma delimited list of integer values for the section identifiers to return. By default the route returns all sections.
        .PARAMETER last_modified
        Filters meetings to sections that were modified on or after the date provided. Use ISO-8601 date format (e.g., 2022-04-01).
        .PARAMETER SchoolTimeZoneId
        Indicates the School Time Zone as specified at https://[school_domain_here].myschoolapp.com/app/core#demographics.
        Get-SchoolScheduleMeeting will try to automatically pull the value from your school envirionment,
        but if you receive an error, you may have to manually override it with a valid time zone ID.
        This is required because Blackbaud does not return accurate time zone information from this endpoint.
        Use 'Get-TimeZone -ListAvailable' to get a list of valid time zone IDs.

        .EXAMPLE
        Get-SchoolScheduleMeeting -start_date '2022-11-01'
        .EXAMPLE
        Get-SchoolScheduleMeeting -start_date '2022-11-01' -end_date '2022-11-30' -offering_types '1,3'
        .EXAMPLE
        Get-SchoolScheduleMeeting -start_date '2022-11-01' | Where-Object -Property faculty_user_id -eq '3154032' | Sort-Object meeting_date, start_time
        .EXAMPLE
        $HashArguments = @{
            start_date = '2022-11-01'
            end_date = '2022-11-30'
            section_ids = '82426521, 93054528'
            last_modified = '2023-12-09'
            SchoolTimeZoneId = "Central Standard Time"
        }
        Get-SchoolScheduleMeeting @HashArguments
        .EXAMPLE
        $Meetings = Get-SchoolScheduleMeeting -start_date '2022-11-01'
        foreach ($meeting in $Meetings)
        {
            "`n--- Meeting Group ---"
            $meeting.group_name
            "--- Meeting Date (School Envirionment Time Zone) ---"
            $meeting.meeting_date
            "--- Start & End (Local Time) ---"
            $meeting.start_time.ToLocalTime().DateTime # DateTime Kind of 'Local'
            $meeting.end_time.ToLocalTime().DateTime # DateTime Kind of 'Local'
            "--- Start & End (Pacific Standard Time) ---"
            [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($meeting.start_time, 'Pacific Standard Time') # DateTime Kind of 'Unspecified'
            [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($meeting.end_time, 'Pacific Standard Time') # DateTime Kind of 'Unspecified'
        }
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$start_date,

        [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [Parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$offering_types,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$section_ids,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$last_modified,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if ((Get-TimeZone -ListAvailable).Id -contains $_)
            {
                $true
            }
            else
            {
                throw "$_ is invalid. Use 'Get-TimeZone -ListAvailable' to get a list of valid time zone IDs."
            }
        })]
        [string]$SchoolTimeZoneId = ((Get-SchoolTimeZone).timezone_name)
    )
       
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/schedules/meetings'
    $endUrl = ''

    # Set the response field
    $ResponseField = "value"

    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # IMPORTANT NOTE: NO SPACES ALLOWED BETWEEN VALUES FOR 'offering_types' STRING!!!! (e.g., "1,3" is the correct way, NOT "1, 3")
    # It will still process the query if there is a string, but only return results for the first value.
    # Remove spaces from 'offering_types' string if included in a comma-separated list.
    if ($parameters -contains 'offering_types')
    {
        $parameters.Remove('offering_types') | Out-Null
        $parameters.Add('offering_types',$($offering_types.Replace(' ','')))
    }
    
    # Remove the School Time Zone parameter since we don't pass it on to the API.
    $parameters.Remove('SchoolTimeZoneId') | Out-Null

    # Convert SchoolTimeZone to TimeZoneInfo object. Check match for ID, then StandardName, then DaylightName.
    $SchoolTimeZone = Get-TimeZone -ListAvailable | Where-Object -Property Id -EQ $SchoolTimeZoneId
    if ([string]::IsNullOrEmpty($SchoolTimeZone))
    {
        $SchoolTimeZone = Get-TimeZone -ListAvailable | Where-Object -Property StandardName -EQ $SchoolTimeZoneId
    }
    if ([string]::IsNullOrEmpty($SchoolTimeZone))
    {
        $SchoolTimeZone = Get-TimeZone -ListAvailable | Where-Object -Property DaylightName -EQ $SchoolTimeZoneId
    }

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Validate Start Date String
    try {$null = [datetime]$start_date} catch
    {
        throw $_
    }

    # If the 'end_date' parameter doesn't exist, then set it to 30 days ahead (the max allowed per call).
    # It is supposed to default to 30 days, but it doesn't work correctly unless you specify an end date (at least in the beta).
    # Also, if you put in a larger time limit than 30 days, it sometimes does 31 days or something like that. It's really dumb.
    [int]$IterationRangeInDays = 30
    if ($null -eq $end_date -or $end_date -eq '' -or $end_date -eq 0)
    {
        $end_date = (([DateTime]$start_date).AddDays($IterationRangeInDays)).ToString('yyyy-MM-dd')
    }
    
    # Validate End Date String
    try {$null = [datetime]$end_date} catch
    {
        throw $_
    }

    # Initialize Variables
    $response = $null
    $DateRangeEnd = [DateTime]$end_date
    $DateIterationStart = [DateTime]$start_date
    $DateIterationEnd = $DateIterationStart.AddDays($IterationRangeInDays)
    $FinalIteration = $false

    # Iterate
    $response += do
    {
        # Don't go beyond the final end date
        if ($DateIterationEnd -ge $DateRangeEnd)
        {
            $DateIterationEnd = $DateRangeEnd
            $FinalIteration = $true
        }
        
        # Remove the 'start_date' and 'end_date' parameters.
        $parameters.Remove('start_date') | Out-Null
        $parameters.Remove('end_date') | Out-Null

        # Add the parameters back in with the correct iteration values
        $parameters.Add('start_date',$DateIterationStart.ToString('yyyy-MM-dd'))
        $parameters.Add('end_date',$DateIterationEnd.ToString('yyyy-MM-dd'))

        # Get the Data.
        # Note: Since PowerShell v6, ConvertTo-Json automatically deserializes strings that contain
        # an "o"-formatted (roundtrip format) date/time string (e.g., "2023-06-15T13:45:00.123Z")
        # or a prefix of it that includes at least everything up to the seconds part as [datetime] instances.
        # Because Blackbaud provides incorrect timezone data we have to adjust this when running in CORE.
        # So, with PS Core, we need to get the raw JSON and create a CustomPSObject without deserialization.

        if ($PSVersionTable.PSEdition -EQ 'Desktop')
        {
            Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        }
        else
        {
            $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -ReturnRaw
            (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw).$ResponseField
        }

        # Increase Iteration Range
        $DateIterationStart = $DateIterationStart.AddDays($IterationRangeInDays + 1)
        $DateIterationEnd = $DateIterationEnd.AddDays($IterationRangeInDays + 1)
    }
    until($FinalIteration -eq $true)

    # Massage dates in $response because PowerShell automatically converts API calls to date time...
    # But Blackbaud includes a generic date of '1900-01-01' when returning time which throws off Daylight Saving Time.
    # Blackbaud also includes a generic time of 'T00:00:00+00:00' when returning dates which throws off stuff too.
    # Example Output from the API that PowerShell automatically parses:
    #     "start_time": "1900-01-01T09:36:00-05:00"
    #     "end_time": "1900-01-01T10:26:00-05:00"
    #     "meeting_date": "2022-09-06T00:00:00+00:00"
    $response = foreach ($meeting in $response)
    {
        # Strip the time information from the date.
        $meeting_date = ($meeting.meeting_date -split "T")[0]
       
        # Pull the time and combine with the correct date so that daylight saving time is calculated correctly
        $start_time = ($meeting.start_time -split "T")[1]
        $start_time = ($start_time -split "-")[0]
        $start_time = [System.String]::Concat($meeting_date,"T",$start_time)
        $start_time = ([System.TimeZoneInfo]::ConvertTimeToUtc($start_time, $SchoolTimeZone)) # Convert to UTC, specifying the time zone.

        $end_time = (($meeting.end_time) -split "T")[1]
        $end_time = ($end_time -split "-")[0]
        $end_time = [System.String]::Concat($meeting_date,"T",$end_time)
        $end_time = ([System.TimeZoneInfo]::ConvertTimeToUtc($end_time, $SchoolTimeZone)) # Convert to UTC, specifying the time zone.

        # Replace values in array
        $meeting.start_time = Get-Date $start_time
        $meeting.end_time = Get-Date $end_time
        $meeting.meeting_date = $meeting_date # Don't convert to DateTime

        # Return the array
        $meeting
    }

    return $response
}
