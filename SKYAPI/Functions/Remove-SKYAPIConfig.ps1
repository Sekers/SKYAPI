function Remove-SKYAPIConfig
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .SYNOPSIS
        Removes the configurations and secrets file used to connect to your Blackbaud SKY API application.

        .DESCRIPTION
        Removes the configurations and secrets file used to connect to your Blackbaud SKY API application.

        .PARAMETER ConfigPath
        The path to the configuration file to remove. Default is the value set by the Set-SKYAPIConfigFilePath cmdlet.
   
        .EXAMPLE
        Remove-SKYAPIConfig
        .EXAMPLE
        Remove-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        .EXAMPLE
        Remove-SKYAPIConfig -Confirm:$false
        .EXAMPLE
        Remove-SKYAPIConfig -WhatIf
    #>

    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath = $sky_api_config_file_path # If not entered will try to pull path from this variable.
    )

    # Make Sure Requested Path Isn't Null or Empty
    if ([string]::IsNullOrEmpty($ConfigPath))
    {
        throw "Cannot validate argument on parameter `'ConfigPath`'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
    }

    # Test If Config File Exists. If not, nothing to remove.
    # Also use ShouldProcess to confirm removal.
    if ((Test-Path -PathType Leaf -Path $ConfigPath) -and ($PSCmdlet.ShouldProcess($ConfigPath)))
    {
        Remove-Item -Path $ConfigPath -Force -Confirm:$false 
    }
}