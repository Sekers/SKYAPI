# https://developer.sky.blackbaud.com/docs/services/school/operations/V1SchedulesMeetingsGet
# Returns a list of section meetings for a given date. When end_date is supplied a range of meetings between the given dates is returned.

# Parameter,Required,Type,Description
# start_date,yes,string,Use ISO-8601 date format: 2022-04-01.
# end_date,no,string,Use ISO-8601 date format: 2022-04-08.
# offering_types,no,string,Can take a single or multiple values as a comma delimited string of integers (defaults to 1)

function Get-SchoolSchedulesMeetings
{
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$start_date,

        [parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$end_date,

        [parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [string]$offering_types
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

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # If the 'end_date' parameter doesn't exist, then set it to 30 days ahead (the max allowed per call).
    # It is supposed to default to 30 days, but it doesn't work correctly unless you specify an end date (at least in the beta).
    # Also, if you put in a larger time limit than 30 days, it sometimes does 31 days or something like that. It's really dumb.
    if ($null -eq $end_date -or $end_date -eq '' -or $end_date -eq 0)
    {
        $end_date = (([DateTime]$start_date).AddDays(30)).ToString('yyyy-MM-dd')
    }

    # Initialize Variables
    [int]$IterationRangeInDays = 30
    $response = $null
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

        # Get data
        $response += Get-UnpagedEntity -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField
    
        # Increase Iteration Range
        $DateIterationStart = $DateIterationStart.AddDays($IterationRangeInDays)
        $DateIterationEnd = $DateIterationEnd.AddDays($IterationRangeInDays)
    }
    until($FinalIteration -eq $true)

    # Massage dates in $response because PowerShell automatically converts API calls to date time...
    # But Blackbaud includes a generic date of '1900-01-01' when returning time which throws off Daylight Saving Time.
    # Blackbaud also includes a generic time of 'T00:00:00+00:00' when returning dates which throws off stuff too.
    # Example Output from the API that PowerShell automatically pareses:
    #     "start_time": "1900-01-01T09:36:00-05:00"
    #     "end_time": "1900-01-01T10:26:00-05:00"
    #     "meeting_date": "2022-09-06T00:00:00+00:00"

    $response = foreach ($meeting in $response)
    {
        # Pull the date and convert to UTC to get the right date!
        $meeting_date = Get-Date $meeting.meeting_date
        $meeting_date = Get-Date $meeting_date.ToUniversalTime() -Format "yyyy-MM-dd"

        # Pull the time and combine with the correct date so that daylight saving time is calculated correctly
        $start_time = Get-Date $meeting.start_time
        $start_time = (($start_time.ToString('o')) -split "T")[1]
        $start_time = [System.String]::Concat($meeting_date,"T",$start_time)
        $end_time = Get-Date $meeting.end_time
        $end_time = (($end_time.ToString('o')) -split "T")[1]
        $end_time = [System.String]::Concat($meeting_date,"T",$end_time)

        # Convert back to time only (NOT USED)
        # $start_time = Get-Date $start_time -Format "HH:mm"
        # $end_time = Get-Date $end_time -Format "HH:mm"

        # Replace values in array
        $meeting.start_time = Get-Date $start_time
        $meeting.end_time = Get-Date $end_time
        $meeting.meeting_date = Get-Date $meeting_date

        # Return the array
        $meeting
    }
    return $response
}
