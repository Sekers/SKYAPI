function New-SchoolEventCategory
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1EventsCategoriesPost
        
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
    
    # Only 'description' takes ValueFromPipeline (by VALUE), so that a bare list of strings can be piped in.
    # The others are ValueFromPipelineByPropertyName only, deliberately. When several parameters accept by
    # value, the binder tries them all against the same incoming object: piping
    # [pscustomobject]@{description='X'} used to bind description by property name and then hand the WHOLE
    # record to calendar_url by value, stringified as '@{description=X}', which was sent to the API as the
    # category's calendar URL. The bool parameters were worse, since almost any object coerces to a bool.
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
        ValueFromPipelineByPropertyName=$true)]
        [string]$calendar_url,

        [parameter(
        Position=2,
        ParameterSetName = 'EventSecurity',
        Mandatory=$true,
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
            # ValueFromPipelineByPropertyName only - see the note on the static parameters above.
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ParameterSetName = "EventSecurity"
                Mandatory = $true
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
            # ValueFromPipelineByPropertyName only - see the note on the static parameters above. This one
            # matters most: [bool] accepts almost any object by value, so a piped record bound here as $true.
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
                ValueFromPipelineByPropertyName = $true
            }

            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $AttributeCollection.Add($ParameterAttributes)

            $DynamicParameter2 = [System.Management.Automation.RuntimeDefinedParameter]::new(
                'include_brief_description', [bool], $AttributeCollection)

            $ParameterDictionary.Add('include_brief_description', $DynamicParameter2)

            # include_long_description parameter
            # ValueFromPipelineByPropertyName only - see the note on the static parameters above.
            $ParameterAttributes = [System.Management.Automation.ParameterAttribute]@{
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
    
    begin
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/events/categories'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Capture the command-line arguments while $PSBoundParameters still holds only those.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)
    }

    process
    {
        # Set the parameters. -SuppliedNames keeps fields from one pipeline record out of the next; see
        # Get-SKYAPISuppliedParameterName.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -SuppliedNames $SuppliedParameter -As Body

        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        $response = Submit-SKYAPIEntity -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
