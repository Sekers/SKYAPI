################################################
# Sample Blackbaud SKY API Module Usage Script #
################################################

# Below are examples on how to use the available cmdlets & functions.
# Note: Most endpoints also support the 'ReturnRaw' switch parameter to return the original JSON response from the Blackbaud SKY API.
#       Otherwise, they will usually return the data in a custom PSObject or Hashtable object that has a property for each field in the JSON string.

###################################
# General Use Cmdlets & Functions #
###################################

<#
    Import the Module.
#>
# Import-Module SKYAPI
# Import-Module "$PSScriptRoot\..\SKYAPI\SKYAPI.psm1"

<#
    Retrieve and Create/Update the SKY API Module Configuration File.
#>
# Get-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json'
# Set-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json' -Silent -api_subscription_key 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

<#
    Set the Necessary File Paths.
    Both These *MUST* Be Set Prior to Running Commands.
#>
# Set-SKYAPIConfigFilePath -Path "$PSScriptRoot\Config\sky_api_config.json" # The location where you placed your Blackbaud SKY API configuration file.
# Set-SKYAPITokensFilePath -Path "$env:USERPROFILE\SKYAPI\skyapi_key.json" # The location where you want the access and refresh tokens to be stored.

<#
    Verify cached tokens exist and are not expired using Connect-SKYAPI.
    Connect-SKYAPI will automatically refresh tokens or reauthenticate to the SKY API service, if necessary.
    You can specify the return of the connection information using the 'ReturnConnectionInfo' switch parameter.
    Optional Parameters Can Force Reauthentication or Token Refresh.
    "AuthenticationMethod" parameter let's you specify how you want to authenticate if authentication is necessary:
    - EdgeWebView2 (default): Opens a web browser window using Microsoft Edge WebView2 for authentication.
                              Requires the WebView2 Runtime to be installed. If not installed, will prompt for automatic installation.
    - LegacyIEControl: Opens a web browser window using the old Internet Explorer control. This is no longer supported by Blackbaud.
    - MiniHTTPServer: Alternate method of capturing the authentication using your user account's default web browser
                      and listening for the authentication response using a temporary HTTP server hosted by the module.
#>
# Connect-SKYAPI
# Connect-SKYAPI -ForceReauthentication
# Connect-SKYAPI -ForceReauthentication -ClearBrowserControlCache
# Connect-SKYAPI -ForceReauthentication -AuthenticationMethod MiniHTTPServer
# Connect-SKYAPI -ForceRefresh
# Connect-SKYAPI -ReturnConnectionInfo

<#
    Retrieve the Session Context Information.
#>
# Get-SKYAPIContext

########################
# School API Endpoints #
########################

<#
    Get-SchoolUserMe
#>
# Get-SchoolUserMe

<#
    Get-SchoolRole
#>
# $RoleList = Get-SchoolRole
# $RoleList.Count

<#
    Get-SchoolLevel
#>
# Get-SchoolLevel

<#
    Get-SchoolDepartment
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  Get-SchoolDepartment
#  Get-SchoolDepartment -level_id 229

<#
    Get-SchoolGradeLevel
#>
# Get-SchoolGradeLevel

<#
    Get-SchoolOfferingType
#>
# Get-SchoolOfferingType

<#
    Get-SchoolTerm
    offering_type 1 is Academics (Use Get-SchoolOfferingType to get a list)
#>
# Get-SchoolTerm
# Get-SchoolTerm -school_year '2021-2022'
# Get-SchoolTerm -offering_type 1 | Select-Object description

<#
    Get-SchoolYear
#>
# Get-SchoolYear
# Get-SchoolYear | Where-Object current_year -Match "True" | Select-Object -ExpandProperty school_year_label

<#
    Get-SchoolCycleBySection
    (Use Get-SchoolTerm to get a list of term/duration IDs)
#>
# Get-SchoolCycleBySection -Section_ID 82426521,93054528
# Get-SchoolCycleBySection -Section_ID 82426521 -duration_id 142312 -group_type 1

<#
    Get-SchoolUser
#>
# Get-SchoolUser -User_ID 2230332,3243114

<#
    Get-SchoolUserBBIDStatus
    (Use Get-SchoolRole to get a list of school roles)
    Note that this takes BASE ROLE IDs and not roles. So a person might show up in the Staff list even if they are not in the Staff role
    because they are in the "Admin Team" role which has the same base_role_id as Staff.
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
# [array]$StudentBBIDStatus = Get-SchoolUserBBIDStatus -Base_Role_Ids "332,15,14" | Where-Object {@('0','0') -Contains $_.status_id} | Select-Object -Property id, name, username, email, status
# $StudentBBIDStatus.Count

<#
    Get-SchoolUserExtended
#>
# Get-SchoolUserExtended -User_ID 2230332,3243114

<#
    Get-SchoolUserByRole
    (Use Get-SchoolRole to get a list of school roles)
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
 # $list = Get-SchoolUserByRole -Roles "15434,15426"
 # [array]$list = Get-SchoolUserByRole -Roles '15475'
 # $list.Count

<#
    Get-SchoolUserExtendedByBaseRole
    (Use Get-SchoolRole to get a list of base roles)
    Note that this takes BASE ROLE IDs and not roles. So a person might show up in the Staff list even if they are not in the Staff role
    because they are in the "Admin Team" role which has the same base_role_id as Staff. This parameter is passed on directly to the
    API endpoint and should be a string, not an array.
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
# [array]$list = Get-SchoolUserExtendedByBaseRole -base_role_ids "332,15,14"
# $list.Count
# # Get students in grades 4-8. Roll ID 14 is the 'Student' base role in this case.
# Get-SchoolUserExtendedByBaseRole -base_role_ids "14" | Where-Object {@('4','5','6','7','8') -Contains $_.student_info.grade_level} | Select-Object -Property id, email, student_info

<#
    Get-SchoolStudentEnrollment
#>
# Get-SchoolStudentEnrollment -User_ID 3294459,3300981
# Get-SchoolStudentEnrollment -User_ID 3294459 -school_year "2021-2022"

<#
    Get-SchoolActivityBySchoolLevel
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityBySchoolLevel -Level_Number 228,229
#  $SchoolActivityListBySchoolLevel.Count
#  $SchoolActivityListBySchoolLevel[0]
#  $SchoolActivityListBySchoolLevel[1]
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolAdvisoryBySchoolLevel
    (Use Get-SchoolLevel to get a list of school level IDs to specify)
#>
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryBySchoolLevel -Level_Number 228,229
#  $SchoolAdvisoryListBySchoolLevel.Count
#  $SchoolAdvisoryListBySchoolLevel[0]
#  $SchoolAdvisoryListBySchoolLevel[1]
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionBySchoolLevel
    (Use Get-SchoolLevel to get a list of school levels)
#>
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionBySchoolLevel -Level_Number 228,229
#  $SchoolSectionListBySchoolLevel.Count
#  $SchoolSectionListBySchoolLevel[0]
#  $SchoolSectionListBySchoolLevel[1]
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionByStudent
#>
# [array]$SectionListByStudent = Get-SchoolSectionByStudent -Student_ID 6111769,2772870
# $SectionListByStudent.Count

<#
    Get-SchoolSectionByTeacher
#>
# Get-SchoolSectionByTeacher -Teacher_ID 1757293,2878846
# Get-SchoolSectionByTeacher -Teacher_ID 1757293 -school_year '2021-2022'

<#
    Get-SchoolCourse
    (Use Get-SchoolDepartment to get a list of academic departments)
    (Use Get-SchoolLevel to get a list of school levels)
#>
# Get-SchoolCourse
# Get-SchoolCourse -department_id 8706 -level_id 453
# Get-SchoolCourse -level_id 229 | Where-Object -Property "inactive" -Match "false"

<#
    Get-SchoolUserEducation
#>
# Get-SchoolUserEducation -User_ID 1757293,2878846

<#
    Get-SchoolStudentBySection
    (Use Get-SchoolSectionBySchoolLevel to get a list of section IDs for a school level)
#>
# Get-SchoolStudentBySection -Section_ID 93054528,92486528

<#
    Get-SchoolAssignmentBySection
    (To get a list of assignment type IDs, create an Advanced List from the web app using Academic Group > Assignment Type)
#>
# Get-SchoolAssignmentBySection -Section_ID 82426521,93054528
# Get-SchoolAssignmentBySection -Section_ID 82426521 -types '293,294' -filter 'future' -search 'Final'

<#
    Get-SchoolAssignmentByStudent
    (Requires at least one of the following roles in the Education Management system: Student, Parent)
#>
# Get-SchoolAssignmentByStudent -Student_ID 3294459,3300981 -start_date "2022-11-07"
# Get-SchoolAssignmentByStudent -Student_ID 3294459 -start_date "2022-11-07" -end_date "2022-11-13" -section_ids "82426521,93054528"

<#
    Get-SchoolList
    Note: this replaces 'Get-SchoolLegacyList' which was deprecated 2023-01-01
    (Use Get-SchoolListOfLists to get a collection of basic and advanced lists the authorized user has access to)
    Tip: The resulting collection of list results can be hard to work with.
         For more complex examples, use the comment-based help: Get-Help Get-SchoolList -Examples 
#>
# [array]$SchoolList = Get-SchoolList -List_ID 30631,52631
# $SchoolList = Get-SchoolList -List_ID 30631 -ConvertTo Array
# Get-SchoolList -List_ID 30631 -ConvertTo Array | Export-Csv -Path "C:\ScriptExports\school_list.csv" -NoTypeInformation

<#
    Get-SchoolListOfLists
#>
# Get-SchoolListOfLists

<#
    Get-SchoolNewsCategory
#>
# Get-SchoolNewsCategory

<#
    Get-SchoolNewsItem
    (Use Get-SchoolNewsCategory to get a list of news categories to filter by)
#>
# Get-SchoolNewsItem
# Get-SchoolNewsItem -categories '12027,3154'

<#
    Get-SchoolScheduleMeeting
    (Use Get-SchoolOfferingType to get a list of offering types)
    Note: offering_types defaults to 1 (Academics) if not specified.
#>
# Get-SchoolScheduleMeeting "2022-11-01"
# Get-SchoolScheduleMeeting "2022-11-01" -end_date '2022-11-30' -offering_types '1,3'
# Get-SchoolScheduleMeeting "2022-11-01" | where-object faculty_user_id -eq '3154032' | Sort-Object meeting_date, start_time

<#
    New-SchoolEventCategory
#>
# New-SchoolEventCategory -description "My Events Category" -public $true -include_brief_description $true -include_long_description $true
# New-SchoolEventCategory -description "My Events Category" -public $false -roles 12342,19302
# New-SchoolEventCategory -description "My Events Category" -public $true "http://www.example.com/calendar/test_calendar.ics"

<#
    Update-SchoolUser
#>
# Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
# Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"

<#
    Get-SchoolUserPhoneType
#>
# Get-SchoolUserPhoneType

<#
    Get-SchoolUserPhone
#>
#  Get-SchoolUserPhone -User_ID 3154032,5942642

<#
    New-SchoolUserPhone
    (Use Get-SchoolUserPhoneType to get a list of phone types)
    Notes: Linking using the -links parameter doesn't currently work and Blackbaud is looking into the issue with the endpoint.
           You can specify multiple user IDs with this function but it will not link them (each user record will have the number added without them sharing it).
#>
# New-SchoolUserPhone -User_ID 3154032,5942642 -number "(555) 555-5555" -type_id 331

<#
    New-SchoolUserOccupation
#>
# New-SchoolUserOccupation -User_ID 3156271, 3294459 -business_name "Don's Auto" -job_title "Director of Shiny Things" -current $true
# $params = @{
#     '-User_ID'          = 3156271
#     'business_name'     = "Don's Auto"
#     'job_title'         = "Director of Shiny Things"
#     'business_url'      = "https://donsauto.com"
#     'industry'          = "Automotive"
#     'organization'      = "Don's Group"
#     'occupation'        = "Mechanical Technician"
#     'matching_gift'     = $true
#     'begin_date'        = "2020-07-01"
#     'end_date'          = "2023-06-30"
#     'specialty'         = "Classic Cars"
#     'parent_company'    = "Don's Group"
#     'job_function'      = "Rebuilds classic cars into shiny new beasts."
#     'years_employed'    = 3
#     'current'           = $false
# }
# New-SchoolUserOccupation @params

<#
    Get-SchoolVenueBuilding
#>
# Get-SchoolVenueBuilding

<#
    Get-SchoolUserRelationship
#>
# Get-SchoolUserRelationship -User_ID 3154032,5942642

<#
    Get-SchoolUserOccupation
#>
# Get-SchoolUserOccupation -User_ID 3154032,5942642

<#
    Get-SchoolUserGenderType
#>
# Get-SchoolUserGenderType

<#
    Get-SchoolUserEmployment
#>
# Get-SchoolUserEmployment -User_ID 3154032,5942642

<#
    Get-SchoolEnrollment
    (Use Get-SchoolLevel to get a list of school levels)
    (Use Get-SchoolGradeLevel to get a list of school grade levels)
#>
# Get-SchoolEnrollment -School_Year '2022-2023'
# Get-SchoolEnrollment -School_Year '2021-2022','2022-2023'
# Get-SchoolEnrollment -School_Year '2022-2023' -school_level_id 228
# Get-SchoolEnrollment -School_Year '2022-2023' -grade_level_id 559
# Get-SchoolEnrollment -School_Year '2022-2023' -ResponseLimit 150
# Get-SchoolEnrollment -School_Year '2022-2023' -ResponseLimit 150 -offset 50

<#
    Set-SchoolUserRelationship
    Notes: Creates relationship records for the specified user IDs.
           This endpoint will also update optional relationship parameters,
           other than relationship type, if the relationship already exists.
           Use the 'ReturnRelationshipInfo' switch to return the created/updated relationship information.
           Using 'ReturnRelationshipInfo' lowers performance a little bit.
#>
# Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 2574354 -relationship_type Sibling_Sibling
# Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 2574354 -relationship_type Sibling_Sibling -ReturnRelationshipInfo
# Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 1574374,1574389 -relationship_type Sibling_Sibling
# Set-SchoolUserRelationship -User_ID 1574497 -Left_User_ID 1574374 -relationship_type Parent_Child -give_parental_access $true -list_as_parent $false -tuition_responsible_signer $false
# Set-SchoolUserRelationship -User_ID 1574497,1574461 -Left_User_ID 1574374,1574389 -relationship_type Grandparent_Grandchild -give_parental_access $true

###############################
# Raiser's Edge API Endpoints #
###############################

<#
    Get-ReConstituentRatingSource
#>
# Get-ReConstituentRatingSource
# Get-ReConstituentRatingSource -include_inactive $true

<#
    Get-ReConstituentRelationshipType
#>
# Get-ReConstituentRelationshipType

<#
    Get-ReConstituentSuffix
#>
# Get-ReConstituentSuffix

<#
    Get-ReConstituentTitle
#>
# Get-ReConstituentTitle
