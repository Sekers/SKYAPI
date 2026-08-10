function Remove-SchoolUserRelationship
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki

        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idRelationshipsDelete

        .SYNOPSIS
        Education Management School API - Removes relationship records from one or more user IDs.

        .DESCRIPTION
        Education Management School API - Removes relationship records from one or more IDs.
        If the related individual is also a user, the user profile of that user is preserved. Individuals may need to review or update their emergency contacts.
        Requires at least one of the following roles in the Education Management system:
          - Payment Services Manager
          - Integration Manager
          - Contact Card Manager
          - Platform Manager

        .PARAMETER User_ID
        Required. Array of the user IDs you want to remove the relationship from. These would be the "right" users.
        .PARAMETER Left_User_ID
        Required. Array of the user IDs of the other individuals in the relationship with the person(s) specified in User_ID. These would be the "left" users.
        .PARAMETER relationship_type
        Required. The nature of the relationship; modeled where left_user 'is a' relationship to this individual.

        .EXAMPLE
        Remove-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 1574374 -relationship_type Sibling_Sibling
        .EXAMPLE
        Remove-SchoolUserRelationship -User_ID 1574497, 1574374 -Left_User_ID 3294373,3294382 -relationship_type Parent_Child
    #>

    [cmdletbinding()]
    Param(
        [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$User_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=1,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Left_User_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        # [ValidateSet(
        #     'Associate_Associate',
        #     'AuntUncle_NieceNephew',
        #     'Caretaker_Charge',
        #     'Consultant_Student',
        #     'Cousin_Cousin',
        #     'Custodian_Student',
        #     'ExHusband_ExWife',
        #     'Friend_Friend',
        #     'Grandparent_Grandchild',
        #     'GrGrandParent_GrGrandChild',
        #     'Guardian_Ward',
        #     'HalfSibling_HalfSibling',
        #     'Husband_Wife',
        #     'Parent_Child',
        #     'Sibling_Sibling',
        #     'Spouse_Spouse',
        #     'SpousePartner_SpousePartner',
        #     'StepParent_StepChild',
        #     'StepSibling_StepSibling'
        # )]
        [string]$relationship_type
    )

    begin
    {
        # Set the endpoints
        $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
        $endUrl = '/relationships'

        # Get the SKY API subscription key
        $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
        $sky_api_subscription_key = $sky_api_config.api_subscription_key

        # Capture the command-line arguments while $PSBoundParameters still holds only those.
        $CommandLineBoundParameter = @($PSBoundParameters.Keys)
    }

    process
    {
        # Grab the security tokens
        $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile

        # Set the parameters. This endpoint is a DELETE, so the values travel in the query string rather than a
        # JSON body. User_ID & Left_User_ID are excluded since we don't pass them on. -SuppliedNames keeps
        # fields from one pipeline record out of the next; see Get-SKYAPISuppliedParameterName.
        $SuppliedParameter = Get-SKYAPISuppliedParameterName -BoundParameters $PSBoundParameters `
                             -CommandLineBound $CommandLineBoundParameter -PipelineItem $PSItem -Invocation $MyInvocation
        $parameters = Get-SKYAPIRequestParameter -BoundParameters $PSBoundParameters -Exclude 'User_ID','Left_User_ID' `
                      -SuppliedNames $SuppliedParameter

        # Remove relationship(s) for one or more IDs
        foreach ($uid in $User_ID)
        {
            foreach ($left_user in $Left_User_ID)
            {
                # Clear out old left_user parameter and add in new.
                $parameters.Remove('left_user') | Out-Null
                $parameters.Add('left_user',$left_user)

                $null = Remove-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            }
        }
    }

    end {}
}
