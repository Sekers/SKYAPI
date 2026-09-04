function Get-SchoolCycleBySection
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsSectionsBySection_idCyclesGet
        
        .SYNOPSIS
        Education Management School API - Returns a collection of cycles for the specified section(s).

        .DESCRIPTION
        Education Management School API - Returns a collection of cycles for the specified section(s).
        Requires at least one of the following roles in the Education Management system:
          - Academic Group Manager

        .PARAMETER Section_ID
        Required. Array of section IDs to get cycles for.
        Use Get-SchoolAcademicSectionBySchoolLevel to get a list of section IDs for a school level.
        .PARAMETER duration_id
        The ID of the term for which you want to return cycles. Defaults to the current term for the section provided.
        Use Get-SchoolTerm to get a list of term/duration IDs.
        .PARAMETER group_type
        The Group Type ID for the section specified. If not specified, defaults to 'Academics' (1).
        I believe these match the IDs provided by Get-SchoolOfferingType, but for scheduling typically only the following are used:
          - Academics (1)
          - Activities (2)
          - Advisory (3)
          - Dorms (4)
          - Athletics (9)
        TODO For some reason this doesn't seem to filter. It will only take up to 13 (highest offering type ID) and will error if you go above that and it will take 0 as well.
        But no matter what we specify it always seems to return information (at least when providing an academic section ID, need to try advisory or something else.)
        A support request has been submitted to Blackbaud and they are looking into it.
        RETESTED 2026-07-28: NOT fixed. On an academic section (a free period), group_type 1, 2, 3, 4, 9 and
        13 each returned exactly the same single cycle as passing no group_type at all. Values that should
        clearly exclude an academic section, such as 4 (Dorms) and 9 (Athletics), still returned it, so the
        parameter is being accepted and ignored. Caveat: the test section had only one cycle, so this shows
        the filter does not EXCLUDE; it does not rule out some other partial behavior on richer sections.
        .PARAMETER ReturnRaw
        Returns the raw JSON content of the API call.

        .EXAMPLE
        Get-SchoolCycleBySection -Section_ID 82426521,93054528
        .EXAMPLE
        Get-SchoolCycleBySection -Section_ID 82426521 -duration_id 142312 -group_type 1
    #>
    
    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Section_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        ValueFromPipelineByPropertyName=$true)]
        [int]$duration_id,

        [Parameter(
        Position=2,
        ValueFromPipelineByPropertyName=$true)]
        [int]$group_type,

        [Parameter(
        Position=3,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRaw
    )
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/academics/sections/'
    $endUrl = '/cycles'

    # Set the parameters
    $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'Section_ID','ReturnRaw'

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

    # Get data for one or more section IDs
    foreach ($uid in $Section_ID)
    {
        if ($ReturnRaw)
        {
            $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters -ReturnRaw
            $response
            continue
        }

        $response = Get-SKYAPIUnpagedEntity -uid $uid -url $endpoint -endUrl $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
        $response
    }
}
