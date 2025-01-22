# CODE FOR TESTING SKYAPI Module Error Handling With Custom JSON

$ErrorActionPreference = "Stop"

# Import the module
# Normally this module would be installed and your command would simply be:
# Import-Module SKYAPI
Import-Module "$PSScriptRoot\..\SKYAPI\SKYAPI.psm1"

# Set custom properties
Set-SKYAPIConfigFilePath -Path "$PSScriptRoot\sky_api_config.json" # The location where you placed your Blackbaud SKY API configuration file.
Set-SKYAPITokensFilePath -Path "$env:USERPROFILE\SKYAPI\skyapi_key.json" # The location where you want the access and refresh tokens to be stored.

# Stop on Errors
$ErrorActionPreference = "Stop"

# Connect to Blackbaud SKY API
Connect-SKYAPI

$JSONError = @"
{
  "errors": {
    "Message": "Error converting value \"panda\" to type 'FuzzyDate'. Path 'birthdate' line 7, position 26.",
    "error_code": 500,
    "RawMessage": "Error converting value \"panda\" to type 'FuzzyDate'. Path 'birthdate' line 7, position 26."
  }
}
"@

# Error Testing
$InvokeErrorMessageRaw = [PSCustomObject]@{
    'KeyTesting'   = 1 # Need at least one non-null key to create a hash object.
    'ErrorDetails' = [PSCustomObject]@{ 
        'Message' = $JSONError
    }
}

# Invoke Error Testing 
SKYAPICatchInvokeErrors -InvokeErrorMessageRaw $ErrorTestRawObject -InvokeCount 1 -MaxInvokeCount 7