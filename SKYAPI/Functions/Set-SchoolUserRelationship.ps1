# https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idRelationshipsPost
# Creates relationship records for the specified user IDs.
# Note that this endpoint will also update optional relationship parameters, other than relationship type, if the relationship already exists.
# Requires at least one of the following roles in the Education Management system:
#   - Payment Services Manager
#   - Integration Manager
#   - Contact Card Manager
#   - Platform Manager

# Parameter,Required,Type,Description
# User_ID,yes,int,Comma delimited list of the user IDs you want to create the relationship for. These would be the "right" users.
# Left_User_ID,yes,int,Comma delimited list of the user IDs the other individuals in the relationship with the persons specified in User_ID. These would be the "left" users.
# relationship_type,yes,string,The nature of the relationship; modeled where left_user 'is a' relationship to this individual.
# give_parental_access,no,boolean,Sets 'Give Parental Access' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).
# list_as_parent,no,boolean,Sets 'List as a Parent' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).
# tuition_responsible_signer,no,boolean,Sets 'Responsible for Signing Contract' option. CAUTION: This setting can be set using the API on a relationship that the web-interface doesn't allow the addition/removal of it for (e.g., Associate, Spouse, etc.).

function Set-SchoolUserRelationship
{
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
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$give_parental_access,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$list_as_parent,

        [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [bool]$tuition_responsible_signer
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
                   
            $null = Submit-SKYAPIEntity -uid $uid -url $endpoint -end $endUrl -api_key $sky_api_subscription_key -authorisation $AuthTokensFromFile -params $parameters
            
            Get-SchoolUserRelationship -User_ID $uid | Where-Object {($_.user_one_id -eq $left_user) -and ($_.user_two_id -eq $uid) -and ($_.user_one_role -eq $($RelationshipTypeCodeMapping_Left.$relationship_type))} # Note: 'user one' is the "left" relationship and 'user two' is the "right" relationship.
        }
    }
}
