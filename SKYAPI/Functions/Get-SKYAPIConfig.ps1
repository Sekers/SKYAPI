function Get-SKYAPIConfig
{
    <#
        .SYNOPSIS
        Get the configuration and secrets to connect to your Blackbaud SKY API application.
        .DESCRIPTION
        Get the configuration and secrets to connect to your Blackbaud SKY API application.
        .EXAMPLE
        Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath = $sky_api_config_file_path # If not entered will see if it can pull path from this variable.
    )
    
    # Make Sure Requested Path Isn't Null or Empty
    if ([string]::IsNullOrEmpty($ConfigPath))
    {
        throw "Cannot validate argument on parameter `'ConfigPath`'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
    }

    try {
        # Get Config and Secrets
        Write-Verbose -Message 'Getting content of sky_api_config.json and returning as a PSCustomObject.'
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