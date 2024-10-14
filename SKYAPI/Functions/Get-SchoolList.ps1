# This function has an alias for the deprecated 'Get-SchoolLegacyList' endpoint and is backwards compatible (https://developer.sky.blackbaud.com/api#api=school&operation=V1LegacyListsByList_idGet).

function Get-SchoolList
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1ListsAdvancedByList_idGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of results from a basic or advanced list.

        .DESCRIPTION
        Education Management School API - Returns a collection of results from a basic or advanced list.
        The requested list must have access permissions enabled for a role listed below or the user requesting the list needs read permission to that list.
        Requires one of the following roles in the Education Management system:
          - Page Manager
          - Content Editor
          - Teacher
          - Coach
          - Community Group Manager
          - Mentor Manager
          - Alumni Group Manager
          - Athletic Group Manager
          - Academic Group Manager
          - System Group Manager
          - Content Manager
          - Community Group Owner
          - Dorm Group Manager
          - Activity Group Manager
          - Advisory Group Manager
          - Advisor
          - Dorm Supervisor
          - Activity Leader
          - Pending Teacher
          - Pending Advisor
          - Pending Dorm Supervisor
          - Pending Activity Leader
          - Platform Manager

        .PARAMETER List_ID
        Required. Array of list IDs to get results of.
        When multiple list IDs are specified, the function will return combined results even if lists have different headers.
        Use Get-SchoolListOfLists to get a collection of basic and advanced lists the authorized user has access to.
        .PARAMETER page
        Results will start with this page of results in the result set. Defaults to 1 if not specified.
        .PARAMETER ResponseLimit
        Limits response to this number of results.
        .PARAMETER ConvertTo
        The way list results collections are returned by the API is fairly unique and different than most other endpoints, making them difficult
        to work with at times. Use this parameter to instead return the results as an Array of PowerShell objects.

        .EXAMPLE
        Get-SchoolList -List_ID 30631,52631

        .EXAMPLE
        Get-SchoolList -List_ID 30631 -ConvertTo Array

        .EXAMPLE
        You can easily export to CSV when you use the 'ConvertTo' switch parameter.

        $SchoolList = Get-SchoolList -List_ID 30631 -ConvertTo Array
        $SchoolList | Export-Csv -Path "C:\ScriptExports\school_list.csv" -NoTypeInformation
    #>
    
    [cmdletbinding()]
    Param(
        [parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$List_ID, # Array as we loop through submitted IDs. Enpoint only takes one item and cannot handle comma-separated values.
       
        [parameter(
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$page,

        [parameter(
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int]$ResponseLimit,

        [parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Array")]
        [string]$ConvertTo
    )
    
    # Set API responses per page limit.
    $PageLimit = 1000

    # Specify Marker Type
    [MarkerType]$MarkerType = [MarkerType]::NEXT_PAGE

    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/lists/advanced/'

    # Set the response field
    $ResponseField = "results.rows"
    
    # Set the parameters
    $parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }
   
    # Set/Replace Page parameter to 1 if not set or 0. That way it can do pagination properly.
    if ($null -eq $page -or $page -eq '' -or $page -eq 0)
    {
        $parameters.Remove('page') | Out-Null
        [int]$page = 1
        $parameters.Add('page',$page)
    }

    # Remove the $List_ID & ResponseLimit parameters since they are passed on in the URL or handled differently.
    $parameters.Remove('List_ID') | Out-Null
    $parameters.Remove('ResponseLimit') | Out-Null

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get the data for one or more List IDs.
    foreach ($uid in $List_ID)
    {

        $response = Get-SKYAPIPagedEntity -uid $uid -url $endpoint -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -response_field $ResponseField -response_limit $ResponseLimit -page_limit $PageLimit -marker_type $MarkerType
        
        # Check to see if the data should be returned in a different format or as is.
        switch ($ConvertTo)
        {
            Array
            {               
                $Array = foreach ($listItem in $response)
                {
                    # Get the column headers.
                    $ColumnHeaders = $listItem | Select-Object -ExpandProperty "columns" | Select-Object -ExpandProperty name

                    # Build the list item object.
                    $ArrayItem = New-Object System.Object
                    foreach ($columnHeader in $ColumnHeaders)
                    {
                        [string]$HeaderValue = $listItem | Select-Object -ExpandProperty "columns" | Where-Object {$_.name -eq $columnHeader} | Select-Object -ExpandProperty value
                        $ArrayItem | Add-Member -MemberType NoteProperty -Name $columnHeader -Value $HeaderValue
                    }
                   
                    # Output list item object.
                    $ArrayItem
                }

                return $Array
            }
            Default # Return the result as is.
            {
                return $response
            }
        }
    }
}