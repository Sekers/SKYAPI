# CODE FOR TESTING BLACKBAUD API RATE LIMITING

$ErrorActionPreference = "Stop"

# Import the module
# Normally this module would be installed and your command would simply be:
# Import-Module SKYAPI
Import-Module "$PSScriptRoot\..\SKYAPI\SKYAPI.psd1"

# Set custom properties
Set-SKYAPIConfigFilePath -Path "$PSScriptRoot\sky_api_config.json" # The location where you placed your Blackbaud SKY API configuration file.
Set-SKYAPITokensFilePath -Path "$env:USERPROFILE\SKYAPI\skyapi_key.json" # The location where you want the access and refresh tokens to be stored.

# Connect to Blackbaud SKY API
Connect-SKYAPI

do{
    # Unpaged Test
    # $Student = Get-SchoolUser -User_IDs 4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481,4254481

    # Paged Test
    [array]$list = Get-SchoolUserExtendedByBaseRole -Base_Role_Ids "332,15,14"
}
while (1 -eq 1)
