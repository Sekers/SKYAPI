function Set-SchoolUserRelationship
{
    <#
        .LINK
        https://github.com/Sekers/SKYAPI/wiki
        
        .LINK
        Endpoint: https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersByUser_idRelationshipsPost
        
        .SYNOPSIS
        Education Management School API - Creates relationship records for the specified user IDs.
        This endpoint will also update optional relationship parameters, other than relationship type, if the relationship already exists.

        .DESCRIPTION
        Education Management School API - Creates relationship records for the specified user IDs.
        This endpoint will also update optional relationship parameters, other than relationship type, if the relationship already exists.

        Requires at least one of the following roles in the Education Management system:
        - Payment Services Manager
        - Integration Manager
        - Contact Card Manager
        - Platform Manager

        .PARAMETER User_ID
        Required. Array of the user IDs you want to create the relationship for. These would be the "right" users.
        .PARAMETER Left_User_ID
        Required. Array of the user IDs of the other individuals in the relationship with the person(s) specified in User_ID. These would be the "left" users.
        .PARAMETER relationship_type
        Required. The nature of the relationship; modeled where left_user 'is a' relationship to this individual.
        .PARAMETER give_parental_access
        Sets 'Give Parental Access' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).
        .PARAMETER list_as_parent
        Sets 'List as a Parent' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).
        .PARAMETER tuition_responsible_signer
        Sets 'Responsible for Signing Contract' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).
        .PARAMETER resides_with
        Sets 'Resides With' option.
        .PARAMETER do_not_contact
        Sets 'No Contact' option.
        .PARAMETER primary
        Sets 'Primary' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.)
        .PARAMETER comments
        Sets 'Notes/Comments' for the relationship.
        .PARAMETER ReturnRelationshipInfo
        Returns the relationship data for any created/updated relationships. Disabled by default to allow for better performance since it requires an additional API call for each relationship.

        .EXAMPLE
        Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 1574374 -relationship_type Sibling_Sibling
        .EXAMPLE
        Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 1574374 -relationship_type Sibling_Sibling -ReturnRelationshipInfo
        .EXAMPLE
        Set-SchoolUserRelationship -User_ID 1574497, 1574374 -Left_User_ID 3294373,3294382 -relationship_type Parent_Child
        .EXAMPLE
        $RelationshipParams = @{
            User_ID  = 1574497 
            Left_User_ID = 3294373
            relationship_type = 'Parent_Child'
            give_parental_access = $true 
            list_as_parent = $true 
            tuition_responsible_signer = $true
            resides_with = $true 
            do_not_contact = $true 
            primary = $true 
            comments = 'Dad is dad.'
        }
        Set-SchoolUserRelationship @RelationshipParams
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
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [int[]]$Left_User_ID, # Array as we loop through submitted IDs

        [Parameter(
        Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet(
            'Associate_Associate',
            'AuntUncle_NieceNephew',
            'Caretaker_Charge',
            'Consultant_Student',
            'Cousin_Cousin',
            'Custodian_Student',
            'ExHusband_ExWife',
            'Friend_Friend',
            'Grandparent_Grandchild',
            'GrGrandParent_GrGrandChild',
            'Guardian_Ward',
            'HalfSibling_HalfSibling',
            'Husband_Wife',
            'Parent_Child',
            'Sibling_Sibling',
            'Spouse_Spouse',
            'SpousePartner_SpousePartner',
            'StepParent_StepChild',
            'StepSibling_StepSibling'
        )]
        [string]$relationship_type,

        [Parameter(
        Position=3,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$give_parental_access,

        [Parameter(
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$list_as_parent,

        [Parameter(
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$tuition_responsible_signer,

        [Parameter(
        Position=6,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$resides_with,

        [Parameter(
        Position=7,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$do_not_contact,

        [Parameter(
        Position=8,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$primary,

        [Parameter(
        Position=9,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [string]$comments,

        [Parameter(
        Position=10,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [switch]$ReturnRelationshipInfo
    )
  
    # Map the key code relationship types to the "left" relationship name.
    $RelationshipTypeCodeMapping_Left = [ordered]@{
        'Associate_Associate' = 'Associate'
        'AuntUncle_NieceNephew' = 'Aunt/Uncle'
        'Caretaker_Charge' = 'Caretaker'
        'Consultant_Student' = 'Consultant'
        'Cousin_Cousin' = 'Cousin'
        'Custodian_Student' = 'Consultant/Custodian'
        'ExHusband_ExWife' = 'Ex-Husband'
        'Friend_Friend' = 'Friend'
        'Grandparent_Grandchild' = 'Grandparent'
        'GrGrandParent_GrGrandChild' = 'Great Grandparent'
        'Guardian_Ward' = 'Guardian'
        'HalfSibling_HalfSibling' = 'Half-Sibling'
        'Husband_Wife' = 'Husband'
        'Parent_Child' = 'Parent'
        'Sibling_Sibling' = 'Sibling'
        'Spouse_Spouse' = 'Spouse'
        'SpousePartner_SpousePartner' = 'Spouse/Partner'
        'StepParent_StepChild' = 'Step-Parent'
        'StepSibling_StepSibling' = 'Step-Sibling'
    }
    
    # Set the endpoints
    $endpoint = 'https://api.sky.blackbaud.com/school/v1/users/'
    $endUrl = '/relationships'

    # Set the parameters
    $parameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator())
    {
        $parameters.Add($parameter.Key,$parameter.Value) 
    }

    # Remove the $User_ID & $Left_User_ID parameters since we don't pass them on.
    $parameters.Remove('User_ID') | Out-Null
    $parameters.Remove('Left_User_ID') | Out-Null

    # Save optional parameter original values. 
    $give_parental_access_orig = $parameters.give_parental_access
    $list_as_parent_orig = $parameters.list_as_parent
    $tuition_responsible_signer_orig = $parameters.tuition_responsible_signer
    $resides_with_orig = $parameters.resides_with
    $do_not_contact_orig = $parameters.do_not_contact
    $primary_orig = $parameters.primary
    $comments_orig = $parameters.comments

    # Get the SKY API subscription key
    $sky_api_config = Get-SKYAPIConfig -ConfigPath $sky_api_config_file_path
    $sky_api_subscription_key = $sky_api_config.api_subscription_key

    # Grab the security tokens
    $AuthTokensFromFile = Get-SKYAPIAuthTokensFromFile
   
    # Set data for one or more IDs
    foreach ($uid in $User_ID)
    {
        foreach ($left_user in $Left_User_ID)
        {
            # Clear out old left_user parameter and add in new.
            $parameters.Remove('left_user') | Out-Null
            $parameters.Add('left_user',$left_user)
            
            # If the relationship is a NEW relationship, make sure the optional parameters are set because of API calls failing when not set and also
            # because the API will set some of the optional values with defaults based on the relationship type, which might not be obvious.
            # When updating existing relationships of the same type between the same users, you can leave the optional parameters $null.
            # Note: Not all relationship types will have issues if you do not specify these parameters when creating a new relationship relationship type between users.
            #       However, some cause the API to spaz out so it's best not to guess which and just make sure they are set.

            $parameters.Remove('give_parental_access') | Out-Null
            $parameters.Remove('list_as_parent') | Out-Null
            $parameters.Remove('tuition_responsible_signer') | Out-Null
            $parameters.Remove('resides_with') | Out-Null
            $parameters.Remove('do_not_contact') | Out-Null
            $parameters.Remove('primary') | Out-Null
            $parameters.Remove('comments') | Out-Null

            $CurrentRelationshipOfSameType = Get-SchoolUserRelationship -User_ID $uid | Where-Object {($_.user_one_id -eq $left_user) -and ($_.user_two_id -eq $uid) -and ($_.user_one_role -eq $($RelationshipTypeCodeMapping_Left.$relationship_type))} # Note: 'user one' is the "left" relationship and 'user two' is the "right" relationship.
            
            # give_parental_access
            if ($null -eq $give_parental_access_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('give_parental_access',$false)
                }
            }
            else
            {
                $parameters.Add('give_parental_access',$give_parental_access_orig)
            }

            # list_as_parent
            if ($null -eq $list_as_parent_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('list_as_parent',$false)
                }
            }
            else
            {
                $parameters.Add('list_as_parent',$list_as_parent_orig)
            }

            # tuition_responsible_signer
            if ($null -eq $tuition_responsible_signer_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('tuition_responsible_signer',$false)
                }
            }
            else
            {
                $parameters.Add('tuition_responsible_signer',$tuition_responsible_signer_orig)
            }

            # resides_with
            if ($null -eq $resides_with_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('resides_with',$false)
                }
            }
            else
            {
                $parameters.Add('resides_with',$resides_with_orig)
            }

            # do_not_contact
            if ($null -eq $do_not_contact_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('do_not_contact',$false)
                }
            }
            else
            {
                $parameters.Add('do_not_contact',$do_not_contact_orig)
            }

            # primary
            if ($null -eq $primary_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('primary',$false)
                }
            }
            else
            {
                $parameters.Add('primary',$primary_orig)
            }

            # comments
            if ($null -eq $comments_orig)
            {
                if ($null -eq $CurrentRelationshipOfSameType)
                {
                    $parameters.Add('comments',$false)
                }
            }
            else
            {
                $parameters.Add('comments',$comments_orig)
            }
                   
            $null = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            
            # Only return created/updated relationship data if requested. Disabled by default to allow for better performance since it requires a second API call.
            if ($ReturnRelationshipInfo)
            {
                Get-SchoolUserRelationship -User_ID $uid | Where-Object {($_.user_one_id -eq $left_user) -and ($_.user_two_id -eq $uid) -and ($_.user_one_role -eq $($RelationshipTypeCodeMapping_Left.$relationship_type))} # Note: 'user one' is the "left" relationship and 'user two' is the "right" relationship.
            }
        }
    }
}
