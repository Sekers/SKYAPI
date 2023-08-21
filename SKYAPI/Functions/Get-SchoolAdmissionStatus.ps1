function Get-SchoolAdmissionStatus
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1AdmissionsStatusGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of admissions statuses.

        .DESCRIPTION
        Education Management School API - Returns a collection of admissions statuses.
        Requires at least one of the following roles in the Education Management system:
          - Admissions Manager
          - Platform Manager
          - SKY API Data Sync

        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolAdmissionStatus
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
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/admissions/status'

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

    $response = Get-SKYAPIUnpagedEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -response_field $ResponseField
    $response
}
