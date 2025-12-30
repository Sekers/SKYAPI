Function Disconnect-SKYAPI
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Documentation: https://developer.blackbaud.com/skyapi/docs/authorization

        .SYNOPSIS
        Blackbaud SKY API - Remove cached authorization tokens and optionally remove the SKY API configuration file.

        .DESCRIPTION
        Blackbaud SKY API - Remove cached authorization tokens and optionally remove the SKY API configuration file.

        .PARAMETER ReturnConnectionInfo
        Returns current connection information before performing the disconnect function.
        .PARAMETER RemoveConfig
        Using this switch parameter causes the cmdlet to also remove the SKY API configuration file used to connect to your Blackbaud SKY API application.
        When using the RemoveConfig switch, the configuration file path is determined by the value set by the Set-SKYAPIConfigFilePath cmdlet.
        Because this parameter, when enabled, calls the Remove-SKYAPIConfig function, by default a confirmation prompt will be shown before removing the configuration file. Use -Confirm:$false to suppress the confirmation prompt.
        .PARAMETER Confirm
        Use -Confirm:$false to suppress the confirmation prompt when using the RemoveConfig parameter.
        .PARAMETER WhatIf
        Note: Disconnect-SKYAPI does not support -WhatIf. Will return an error if -WhatIf is used.

        .EXAMPLE
        Disconnect-SKYAPI
        .EXAMPLE
        Disconnect-SKYAPI -ReturnConnectionInfo
        .EXAMPLE
        Disconnect-SKYAPI -RemoveConfig
        .EXAMPLE
        Disconnect-SKYAPI -RemoveConfig -Confirm:$false
    #>

    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        [parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$ReturnConnectionInfo,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$RemoveConfig
    )

    # Notify that WhatIf is not supported.
    if ($WhatIfPreference)
    {
        throw "Disconnect-SKYAPI does not support -WhatIf for this operation."
    }

    # Let user know that Set-SKYAPITokensFilePath has not been run.
    if ([string]::IsNullOrEmpty($sky_api_tokens_file_path))
    {
        throw "Disconnect-SKYAPI: No application to sign out from (Set-SKYAPITokensFilePath has not been run)."
    }

    # Return connection info if requested.
    if ($ReturnConnectionInfo)
    {
        Get-SKYAPIContext
    }

    # Remove the tokens file if it exists.
    if (Test-Path -PathType Leaf -Path $sky_api_tokens_file_path -ErrorAction SilentlyContinue)
    {
        Remove-Item -Path $sky_api_tokens_file_path -Force -Confirm:$false
    }
    else
    {    
        throw "Disconnect-SKYAPI: No application to sign out from (no SKY API tokens file found at path: $sky_api_tokens_file_path)"
    }

    # Remove the config file if requested.
    if ($RemoveConfig)
    {
        Remove-SKYAPIConfig
    }
}