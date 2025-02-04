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

    # The API endpoint returns begin_date & end_date in datetime format.
    # This wouldn't be a big issue except that there is a bug and the timezone provided is wrong (it doesn't match the Blackbaud School timezone).
    # So we just end up returning the date as a string instead so whether it's fixed or not it's consistent and we only really care about the date not the time.
    # Note that PS Core will automatically deserialize the [incorrect] datetime string so we need to use the 'ConvertFrom-JsonWithoutDateTimeDeserialization' function to prevent this.
    if ($PSVersionTable.PSEdition -EQ 'Desktop')
    {
        $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    }
    else
    {
        $response_raw = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -ReturnRaw
        $response = (ConvertFrom-JsonWithoutDateTimeDeserialization -InputObject $response_raw).$ResponseField
    }

    # Massage dates in $response because PowerShell automatically converts API calls to date time...
    $response = foreach ($schoolyear in $response)
    {
        # Strip the incorrect time information from the dates.
        $begin_date = ($schoolyear.begin_date -split "T")[0]
        $end_date = ($schoolyear.end_date -split "T")[0]
   
        # Replace values in array
        $schoolyear.begin_date = $begin_date
        $schoolyear.end_date = $end_date

        # Return the array
        $schoolyear
    }

    return $response
}
