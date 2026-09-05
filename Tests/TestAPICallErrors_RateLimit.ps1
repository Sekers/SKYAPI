# TestRequires: Live
#
# CODE FOR TESTING BLACKBAUD API RATE LIMITING
#
# Live on purpose. The point is to trip the API's real rate limiting and see what comes back: which status
# code it returns under load, whether a Retry-After header is present, and the shape of the body. A local
# stub can only confirm what the handler already assumes, so do not convert this to an offline test.
#
# It loops until rate limited and does not terminate on its own.

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
