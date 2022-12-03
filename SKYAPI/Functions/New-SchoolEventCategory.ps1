function New-SchoolEventCategory
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/docs/services/school/operations/V1EventsCategoriesPost
        
        .SYNOPSIS
        Education Management School API - Creates a new Events Category & returns its ID.

        .DESCRIPTION
        Education Management School API - Creates a new Events Category & returns its ID.
        Requires the 'Content Manager' or 'Platform Manager' role in the Education Management system.

        .PARAMETER description
        Required. The name of the event category.
        .PARAMETER calendar_url
        The URL of the ICS feed used to populate the event category.
        .PARAMETER include_brief_description
        Only accepted if calendar_url is not provided. If set to True, brief description is included in events in the category.
        .PARAMETER include_long_description
        Only accepted if calendar_url is not provided. If set to True, long description is included in events in the category.
        .PARAMETER public
        Required. If set to True the event category is public. If set to False it is secure and only users with the allowed list of roles can see the events in the category.
        .PARAMETER roles
        Potentially Required. Array of integer. Only accepted if the 'public' parameter is set to false. If that is the case, it is a required parameter.

        .EXAMPLE
        New-SchoolEventCategory -description "My Events Category" -public $true -include_brief_description $true -include_long_description $true
        .EXAMPLE
        New-SchoolEventCategory -description "My Events Category" -public $false -roles 12342,19302
        .EXAMPLE
        New-SchoolEventCategory -description "My Events Category" -public $true "http://www.example.com/calendar/test_calendar.ics"
 
    #>
    
    [cmdletbinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$description,

        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$calendar_url,

        [parameter(
        Position=2,
        ParameterSetName = 'EventSecurity',
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$public
    )

    DynamicParam
    {
        # Initialize Parameter Dictionary
        $ParameterDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        
        # Make -roles parameter only appear if public is $false.
        # DynamicParameter1: roles
        if ($public -eq $false)
        { 
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ParameterSetName = "EventSecurity"
                Mandatory = $true
                ValueFromPipeline = $true
                ValueFromPipelineByPropertyName = $true
            }

            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $AttributeCollection.Add($ParameterAttributes)

            $DynamicParameter1 = [System.Management.Automation.RuntimeDefinedParameter]::new(
                'roles', [int[]], $AttributeCollection) # Array of roles accepted

            $ParameterDictionary.Add('roles', $DynamicParameter1)
        }

        # Make -include_brief_description & -include_long_description parameters only appear if calendar_url is $null or empty.
        # DynamicParameter2: include_brief_description & DynamicParameter3: include_long_description
        if ([string]::IsNullOrEmpty($calendar_url))
        {
            # include_brief_description parameter
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ValueFromPipeline = $true
                ValueFromPipelineByPropertyName = $true
            }

            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $AttributeCollection.Add($ParameterAttributes)

            $DynamicParameter2 = [System.Management.Automation.RuntimeDefinedParameter]::new(
                'include_brief_description', [bool], $AttributeCollection)

            $ParameterDictionary.Add('include_brief_description', $DynamicParameter2)

            # include_long_description parameter
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ValueFromPipeline = $true
                ValueFromPipelineByPropertyName = $true
            }

            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $AttributeCollection.Add($ParameterAttributes)

            $DynamicParameter3 = [System.Management.Automation.RuntimeDefinedParameter]::new(
                'include_long_description', [bool], $AttributeCollection)

            $ParameterDictionary.Add('include_long_description', $DynamicParameter3)
        }

        return $ParameterDictionary
    }
    
    process
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/events/categories'

        # Set the parameters
        $parameters = @{}
        foreach ($parameter in $PSBoundParameters.GetEnumerator())
        {
            $parameters.Add($parameter.Key,$parameter.Value) 
        }

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        $response = Submit-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
