function Get-SchoolScheduleMeeting
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1SchedulesMeetingsGet
        
        .SYNOPSIS
        Education Management School API - Returns a list of section meetings for a given date.

        .DESCRIPTION
        Education Management School API - Returns a list of section meetings for a given date.
        When end_date is supplied, a range of meetings between the given dates is returned.
        If end_date is not supplied, Get-SchoolScheduleMeeting defaults to 30 days from start_date.

        Additional Notes:
          - Returned meeting start & end times are in UTC DateTime format.
          - Returned meeting date is the date of the meeting in the School Time Zone as specified at https://[school_domain_here].myschoolapp.com/app/core#demographics.
          - Does not support the "show_time_for_current_date" request parameter because it just completely gives incorrect timezone information. If you need to convert timezones or DST, use PowerShell.

        .PARAMETER start_date
        Required. Start date of events you want returned. Use ISO-8601 date format (e.g., 2022-04-01).
        .PARAMETER end_date
        End date of events you want returned. Use ISO-8601 date format (2022-04-08).
        If not specified, defaults to 30 days from start_date.
        .PARAMETER offering_types
        Can take a single or multiple values as a comma-delimited string of integers (defaults to 1 'Academics').
        Supports the following offering types (use Get-SchoolOfferingType to get a list of all offering types):
            Academics: 1
            Activities: 2
            Advisory: 3
            Athletics: 9
        .PARAMETER section_ids
        comma-delimited list of integer values for the section identifiers to return. By default the route returns all sections.
        .PARAMETER last_modified
        Filters meetings to sections that were modified on or after the date provided. Use ISO-8601 date format (e.g., 2022-04-01).
        .PARAMETER SchoolTimeZoneId
        Indicates the School Time Zone as specified at https://[school_domain_here].myschoolapp.com/app/core#demographics.
        Get-SchoolScheduleMeeting will try to automatically pull the value from your school environment,
        but if you receive an error, you may have to manually override it with a valid time zone ID.
        This is required because Blackbaud does not return accurate time zone information from this endpoint.
        Use 'Get-TimeZone -ListAvailable' to get a list of valid time zone IDs.
        .PARAMETER IncludeRosters
        Adds the roster information for each meeting. This is a large amount of data, and adds additional API calls, so only use it if you need it.
        Each returned meeting gains a 'roster' property containing the full section & roster object for that meeting's section.
        Dropped members are not included.

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
        # Include the roster for each meeting's section and list the enrolled members of the first meeting.
        $Meetings = Get-SchoolScheduleMeeting -start_date '2022-11-01' -end_date '2022-11-30' -offering_types '1,3' -IncludeRosters
        $Meetings[0].roster.roster |
            Select-Object -ExpandProperty user -Property @{n='is_leader';e={$_.leader.is_leader}}, @{n='is_head';e={$_.leader.is_head}}, @{n='is_faculty';e={$_.leader.is_faculty}} |
            Select-Object first_name, last_name, email, is_leader, is_head, is_faculty
        .EXAMPLE
        $Meetings = Get-SchoolScheduleMeeting -start_date '2022-11-01'
        foreach ($meeting in $Meetings)
        {
            "`n--- Meeting Group ---"
            $meeting.group_name
            "--- Meeting Date (School Environment Time Zone) ---"
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
        [string]$SchoolTimeZoneId = ((Get-SchoolTimeZone).timezone_name),

        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$IncludeRosters
    )
       
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/schedules/meetings'

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
    
    # Remove the 'School Time Zone' and 'IncludeRosters' parameters since we don't pass them on to the API.
    $parameters.Remove('SchoolTimeZoneId') | Out-Null
    $parameters.Remove('IncludeRosters') | Out-Null

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

    # If the 'end_date' parameter doesn't exist, then set it to 30 days ahead (31 days TOTAL including start date), which is the max days ahead allowed per call.
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

    # Validate that the start date is not after the end date.
    if ([datetime]$start_date -gt [datetime]$end_date)
    {
        throw "start_date ($start_date) cannot be after end_date ($end_date)."
    }

    # Initialize Variables
    $response = [System.Collections.Generic.List[Object]]::new()
    $DateRangeEnd = [DateTime]$end_date
    $DateIterationStart = [DateTime]$start_date
    $DateIterationEnd = $DateIterationStart.AddDays($IterationRangeInDays)
    $FinalIteration = $false

    # Iterate
    do
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
        # So, with PS Core, we need to get the raw JSON and create a CustomPSObject without deserialization.

        if ($PSVersionTable.PSEdition -EQ 'Desktop')
        {
            $response_objects = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
        }
        else
        {
            $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -ReturnRaw
            $response_objects = (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw).$ResponseField
        }

        # Only return a response to the list if there's data.
        if ($null -ne $response_objects)
        {
            foreach ($response_object in $response_objects)
            {
                $response.Add($response_object)
            }
        }

        # Increase Iteration Range
        $DateIterationStart = $DateIterationStart.AddDays($IterationRangeInDays + 1)
        $DateIterationEnd = $DateIterationEnd.AddDays($IterationRangeInDays + 1)
    }
    until($FinalIteration -eq $true)

    # Collect rosters if requested and build a lookup keyed by section ID.
    # Rosters are gathered after the meetings so we only pull rosters for the sections actually returned.
    # This is a large amount of data and adds additional API calls, which is why it's opt-in via -IncludeRosters.
    $RosterLookup = @{}
    if ($IncludeRosters -and $response.Count -gt 0)
    {
        # Default to Academics (1) when no offering types were specified, matching the meetings query default.
        $RosterOfferingTypes = if ([string]::IsNullOrWhiteSpace($offering_types)) { '1' } else { $offering_types }

        # Determine which school year(s) the requested date range overlaps so we pull rosters from each.
        $OverlappingSchoolYears = Get-SchoolYear | Where-Object {
            (([datetime]$_.begin_date) -le ([datetime]$end_date)) -and (([datetime]$_.end_date) -ge ([datetime]$start_date))
        }

        # Map each supported offering type to the function that retrieves its rosters.
        $RosterFunctionByOfferingType = @{
            '1' = 'Get-SchoolRoster'          # Academics
            '2' = 'Get-SchoolActivityRoster'  # Activities
            '3' = 'Get-SchoolAdvisoryRoster'  # Advisory
            '9' = 'Get-SchoolAthleticRoster'  # Athletics
        }

        foreach ($rosterOfferingType in ((($RosterOfferingTypes -replace '\s','') -split ',') | Where-Object {$_ -ne ''}))
        {
            $RosterFunction = $RosterFunctionByOfferingType[$rosterOfferingType]

            # Skip unsupported offering types.
            if ($null -eq $RosterFunction) { continue }

            # Distinct section IDs for this offering type from the returned meetings.
            [array]$SectionIdsForType = $response | Where-Object {[string]$_.offering_type.id -eq $rosterOfferingType} |
                Select-Object -ExpandProperty section_id -Unique
            if ($SectionIdsForType.Count -eq 0) { continue }

            # Batch the section IDs by URL length rather than a fixed count: pack as many IDs as
            # fit into a single 'section_ids' value, only splitting when the query would get too long.
            # In most cases this is a single batch (one API call per offering type & school year).
            # $MaxSectionIdsLength is a conservative budget for the 'section_ids' query value that keeps
            # the total request URL well under the ~2048-character limit imposed by many servers/proxies.
            [int]$MaxSectionIdsLength = 1800
            $SectionIdBatches = [System.Collections.Generic.List[string]]::new()
            $CurrentBatch = [System.Text.StringBuilder]::new()
            foreach ($SectionId in $SectionIdsForType)
            {
                $SectionIdString = [string]$SectionId

                # Start a new batch if appending this ID (plus its comma separator) would exceed the budget.
                if ($CurrentBatch.Length -gt 0 -and ($CurrentBatch.Length + 1 + $SectionIdString.Length) -gt $MaxSectionIdsLength)
                {
                    $SectionIdBatches.Add($CurrentBatch.ToString())
                    $CurrentBatch = [System.Text.StringBuilder]::new()
                }

                if ($CurrentBatch.Length -gt 0) { [void]$CurrentBatch.Append(',') }
                [void]$CurrentBatch.Append($SectionIdString)
            }
            if ($CurrentBatch.Length -gt 0) { $SectionIdBatches.Add($CurrentBatch.ToString()) }

            foreach ($SchoolYear in $OverlappingSchoolYears)
            {
                foreach ($SectionIdBatch in $SectionIdBatches)
                {
                    # Call the appropriate roster function for this offering type and school year, passing the batched section IDs.
                    $SectionRosters = & $RosterFunction -school_year $SchoolYear.id -section_ids $SectionIdBatch

                    # Add the roster objects to the lookup keyed by section ID.
                    foreach ($SectionRoster in $SectionRosters)
                    {
                        $RosterLookup[[string]$SectionRoster.section.id] = $SectionRoster
                    }
                }
            }
        }
    }

    # Massage dates in $response because PowerShell automatically converts API calls to date time...
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

        # Attach the roster (full section & roster object) for this meeting's section, if collected.
        if ($IncludeRosters)
        {
            $meeting | Add-Member -NotePropertyName 'roster' -NotePropertyValue $RosterLookup[[string]$meeting.section_id] -Force
        }

        # Return the array
        $meeting
    }

    return $response
}
