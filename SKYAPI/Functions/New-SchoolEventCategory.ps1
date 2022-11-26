# https://developer.sky.blackbaud.com/docs/services/school/operations/V1EventsCategoriesPost
# Creates a new Events Category & returns its ID.
# Requires the 'Content Manager' or 'Platform Manager' role in the K12 system.

# Parameter,Required,Type,Description
# description,yes,string,The name of the event category.
# calendar_url,no,string,The URL of the ICS feed used to populate the event category.
# include_brief_description,no,boolean,Only accepted if calendar_url is not provided. If set to True, brief description is included in events in the category.
# include_long_description,no,boolean,Only accepted if calendar_url is not provided. If set to True, long description is included in events in the category.
# public,yes,boolean,If set to True the event category is public. If set to False it is secure and only users with the allowed list of roles can see the events in the category.
# roles,maybe,array of integer,Only accepted if public is set to false. If that is the case, it is a required parameter.

function New-SchoolEventCategory
{
    [cmdletbinding()]
    Param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$description,

        [parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [string]$calendar_url,

        [parameter(
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

        $response = Submit-Entity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
