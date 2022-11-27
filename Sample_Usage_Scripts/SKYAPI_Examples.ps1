# Sample Blackbaud SKY API Module Usage Script

<#
    Import the Module
#>
# Import-Module SKYAPI
# Import-Module "$PSScriptRoot\..\SKYAPI\SKYAPI.psm1"

<#
    Retrieve and Create/Update the SKY API Module Configuration File
#>
# Get-SKYAPIConfig -ConfigPath '.\Sample_Usage_Scripts\Config\sky_api_config.json'
# Set-SKYAPIConfig -ConfigPath '.\Sample_Usage_Scripts\Config\sky_api_config.json' -Silent -api_subscription_key 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

<#
    Set the Necessary File Paths.
    Both These *MUST* Be Set Prior to Running Commands.
#>
# Set-SKYAPIConfigFilePath -Path "$PSScriptRoot\Config\sky_api_config.json" # The location where you placed your Blackbaud SKY API configuration file.
# Set-SKYAPITokensFilePath -Path "$env:USERPROFILE\SKYAPI\skyapi_key.json" # The location where you want the access and refresh tokens to be stored.

<#
    Optionally, Test Connecting to the SKY API Service.
    Optional Parameters Can Force Reauthentication or Token Refresh.
    When forcing a token refresh, you can additionally specify the return of the connection information using the 'ReturnConnectionInfo' switch parameter.
    "AuthenticationMethod" paramameter let's you specify how you want to authenticate if authentication is necessary:
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
# Connect-SKYAPI -ForceRefresh -ReturnConnectionInfo

<#
    Get-SchoolRole Example
#>
# $RoleList = Get-SchoolRole
# $RoleList.Count

<#
    Get-SchoolLevel Example
#>
# Get-SchoolLevel

<#
    Get-SchoolDepartment Example
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  Get-SchoolDepartment
#  Get-SchoolDepartment -level_id 229

<#
    Get-SchoolGradeLevel Example
#>
# Get-SchoolGradeLevel

<#
    Get-SchoolOfferingType Example
#>
# Get-SchoolOfferingType

<#
    Get-SchoolTerm Example
    Offering_type 1 is Academics (Use Get-SchoolOfferingType to get a list)
#>
# Get-SchoolTerm | Where-Object {($_.offering_type -eq 1)} | Select-Object description

<#
    Get-SchoolYear Example
#>
# Get-SchoolYear | Where-Object current_year -Match "True" | Select-Object -ExpandProperty school_year_label

<#
    Get-SchoolUser Example
#>
# Get-SchoolUser -User_ID 2230332,3243114

<#
    Get-SchoolUserBBIDStatus Example
    (Use Get-SchoolRole to get a list)
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
    Get-SchoolUserExtended Example
#>
# Get-SchoolUserExtended -User_ID 2230332,3243114

<#
    Get-SchoolUserByRole Example
    (Use Get-SchoolRole to get a list)
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
 # $list = Get-SchoolUserByRole -Roles "15434,15426"
 # [array]$list = Get-SchoolUserByRole -Roles '15475'
 # $list.Count

<#
    Get-SchoolUserExtendedByBaseRole Example
    (Use Get-SchoolRole to get a list)
    Note that this takes BASE ROLE IDs and not roles. So a person might show up in the Staff list even if they are not in the Staff role
    because they are in the "Admin Team" role which has the same base_role_id as Staff.
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
# [array]$list = Get-SchoolUserExtendedByBaseRole -Base_Role_Ids "332,15,14"
# $list.Count
# # Get students in grades 4-8. Roll ID 14 is Student.
# $GoogleClassroomStudents = Get-SchoolUserExtendedByBaseRole -Base_Role_Ids "14" | Where-Object {@('4','5','6','7','8') -Contains $_.student_info.grade_level} | Select-Object -Property id, email, student_info

<#
    Get-SchoolStudentEnrollment Example
#>
# $StudentEnrollmentList = Get-SchoolStudentEnrollment -User_ID 3243114
# $StudentEnrollmentList.Count

<#
    Get-SchoolActivityBySchoolLevel Example
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityBySchoolLevel -Level_Number 228,229
#  $SchoolActivityListBySchoolLevel.Count
#  $SchoolActivityListBySchoolLevel[0]
#  $SchoolActivityListBySchoolLevel[1]
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolAdvisoryBySchoolLevel Example
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryBySchoolLevel -Level_Number 228,229
#  $SchoolAdvisoryListBySchoolLevel.Count
#  $SchoolAdvisoryListBySchoolLevel[0]
#  $SchoolAdvisoryListBySchoolLevel[1]
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionBySchoolLevel Example
    (Use Get-SchoolLevel to get a list of levels to filter by)
#>
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionBySchoolLevel -Level_Number 228,229
#  $SchoolSectionListBySchoolLevel.Count
#  $SchoolSectionListBySchoolLevel[0]
#  $SchoolSectionListBySchoolLevel[1]
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionByStudent Example
#>
# [array]$SectionListByStudent = Get-SchoolSectionByStudent -Student_ID 6111769,2772870
# $SectionListByStudent.Count

<#
    Get-SchoolSectionByTeacher Example
#>
# [array]$SectionListByTeacher = Get-SchoolSectionByTeacher -Teacher_ID 1757293,2878846
# $SectionListByTeacher.Count

<#
    Get-SchoolCourse Example
#>
# $courseList = Get-SchoolCourse -level_id 229 | Where-Object inactive -Match "false"
# $courseList 

<#
    Get-SchoolUserEducation Example
#>
# Get-SchoolUserEducation -User_ID 1757293,2878846

<#
    Get-SchoolStudentBySection Example
    (Use Get-SchoolSectionBySchoolLevel to get a list)
#>
# Get-SchoolStudentBySection -Section_ID "93054528"

<#
    Get-SchoolList Example
    NOTE: This replaces 'Get-SchoolLegacyList' which is being deprecated 2023-01-01
#>
# [array]$SchoolList = Get-SchoolList -List_ID 105627
# foreach ($ListItem in $SchoolList)
# {
#     $GroupID = $ListItem | select-object -ExpandProperty "columns" | Where-Object {$_.name -eq "Group Identifier"} | Select-Object -ExpandProperty value  
#     write-host $GroupID
# }

<#
    Get-SchoolListOfLists Example
#>
# Get-SchoolListOfLists

<#
    Get-SchoolNewsCategory Example
#>
# Get-SchoolNewsCategory

<#
    Get-SchoolNewsItem Example
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
    New-SchoolEventCategory Example
#>
# New-SchoolEventCategory -description "My Events Category" -public $true -include_brief_description $true -include_long_description $true
# New-SchoolEventCategory -description "My Events Category" -public $false -roles 12342,19302
# New-SchoolEventCategory -description "My Events Category" -public $true "http://www.example.com/calendar/test_calendar.ics"

<#
    Update-SchoolUser Example
#>
# Update-SchoolUser -User_ID 1757293 -custom_field_one "my data" -email "useremail@domain.edu" -first_name "John" -preferred_name "Jack"
# Update-SchoolUser -User_ID 1757293,2878846 -custom_field_one "my data"

<#
    Get-SchoolUserPhoneType Example
#>
# Get-SchoolUserPhoneType

<#
    Get-SchoolUserPhone Example
#>
#  [array]$PhoneNumbersByUser = Get-SchoolUserPhone -User_ID 3154032,5942642

<#
    New-SchoolUserPhone Example
    (Use Get-SchoolUserPhoneType to get a list of phone types)
    Notes: Linking using the -links parameter doesn't currently work and Blackbaud is looking into the issue with the endpoint.
           You can specify multiple user IDs with this function but it will not link them (each user record will have the number added without them sharing it).
#>
# New-SchoolUserPhone -User_ID 3154032,5942642 -number "(555) 555-5555" -type_id 331

<#
    Get-SchoolVenueBuilding Example
#>
# Get-SchoolVenueBuilding

<#
    Get-SchoolUserRelationship Example
#>
# Get-SchoolUserRelationship -User_ID 3154032,5942642

<#
    Get-SchoolUserOccupation Example
#>
# Get-SchoolUserOccupation -User_ID 3154032,5942642
