# TODO Encrypted option sky API config

function Get-SKYAPIConfig
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .SYNOPSIS
        Get the configuration and secrets to connect to your Blackbaud SKY API application.

        .DESCRIPTION
        Get the configuration and secrets to connect to your Blackbaud SKY API application.

        .PARAMETER ConfigPath
        Optional. If not provided, the function will use the path used in the current session (if set).

        .EXAMPLE
        Get-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json'
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$ConfigPath = $sky_api_config_file_path # If not entered will see if it can pull path from this variable.
    )
    
    # Make Sure Requested Path Isn't Null or Empty (better to catch it here than validating on the parameter of this function)
    if ([string]::IsNullOrEmpty($ConfigPath))
    {
        throw "`'`$sky_api_config_file_path`' is not specified. Don't forget to first use the `'Set-SKYAPIConfigFilePath`' & `'Set-SKYAPITokensFilePath`' cmdlets!"
    }

    try {
        # Get Config and Secrets
        # Write-Verbose -Message 'Getting content of sky_api_config.json and returning as a PSCustomObject.'
        $sky_api_config = Get-Content -Path "$ConfigPath" -ErrorAction 'Stop' | ConvertFrom-Json

        $sky_api_config = [PSCustomObject] @{
            api_subscription_key = ($sky_api_config | Select-Object -Property "api_subscription_key").api_subscription_key
            client_id = ($sky_api_config | Select-Object -Property "client_id").client_id
            client_secret = ($sky_api_config | Select-Object -Property "client_secret").client_secret
            redirect_uri = ($sky_api_config | Select-Object -Property "redirect_uri").redirect_uri
            authorize_uri = ($sky_api_config | Select-Object -Property "authorize_uri").authorize_uri
            token_uri = ($sky_api_config | Select-Object -Property "token_uri").token_uri
        }

        return $sky_api_config
    } catch {
        throw "Can't find the JSON configuration file. Use 'Set-SKYAPIConfig' to create one."
    }
}