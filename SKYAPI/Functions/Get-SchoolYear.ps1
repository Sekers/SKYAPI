function Get-SchoolYear
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=v1yearsget
        
        .SYNOPSIS
        Education Management School API - Returns a list of school years.

        .DESCRIPTION
        Education Management School API - Returns a list of school years.
        Accessible by any authorized user.

        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolYear
        .EXAMPLE
        Get-SchoolYear | Where-Object current_year -Match "True" | Select-Object -ExpandProperty school_year_label
 
    #>

    [cmdletbinding()]
    param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/years'

    # Set the response field
    $ResponseField = "value"

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    if ($ReturnRaw)
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        return $response
    }

    # begin_date & end_date arrive in datetime format, carrying the school's own DST-aware offset (verified on
    # the dev tenant 2026-07-28: 6 of 6 values matched the school's offset for their own date, e.g.
    # "2003-09-01T00:00:00-04:00"). Confirm this on your tenant before depending on it, using
    # Tests/TestDateTime_WireFormatSurvey.ps1.
    #
    # Only the calendar date matters here, so it is returned as a string: a string cannot be re-shifted by a
    # client time zone later, and callers comparing these values as strings keep working.
    # PS Core would otherwise deserialize the datetime string, so ConvertFrom-JsonWithoutDateTimeDeserialization
    # is used to prevent that.
    if ($PSVersionTable.PSEdition -EQ 'Desktop')
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    }
    else
    {
        $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        $response = (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw).$ResponseField
    }

    # Keep the date portion and drop the time, which carries no information for these two fields. Splitting the
    # string rather than parsing it is what makes the result independent of the client's time zone.
    $response = foreach ($schoolyear in $response)
    {
        $schoolyear.begin_date = ($schoolyear.begin_date -split "T")[0]
        $schoolyear.end_date = ($schoolyear.end_date -split "T")[0]

        $schoolyear
    }

    return $response
}
