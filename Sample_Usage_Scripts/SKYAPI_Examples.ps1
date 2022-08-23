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

<#
    Get-SchoolRoleList Example
#>
# $RoleList = Get-SchoolRoleList
# $RoleList.Count

<#
    Get-SchoolLevelList Example
#>
# Get-SchoolLevelList

<#
    Get-SchoolDepartmentList Example
    (Use Get-SchoolLevelList to get a list of levels to filter by)
#>
#  Get-SchoolDepartmentList
#  Get-SchoolDepartmentList -level_id 229

<#
    Get-SchoolGradeLevelList Example
#>
# Get-SchoolGradeLevelList

<#
    Get-SchoolOfferingTypeList Example
#>
# Get-SchoolOfferingTypeList

<#
    Get-SchoolTermList Example
    Offering_type 1 is Academics (Use Get-SchoolOfferingTypeList to get a list)
#>
# Get-SchoolTermList | Where-Object {($_.offering_type -eq 1)} | Select-Object description

<#
    Get-SchoolYearList Example
#>
# Get-SchoolYearList | Where-Object current_year -Match "True" | Select-Object -ExpandProperty school_year_label

<#
    Get-SchoolUser Example
#>
# Get-SchoolUser -User_Id 2230332,3243114

<#
    Get-SchoolUserBBIDStatus Example
    (Use Get-SchoolRoleList to get a list)
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
# Get-SchoolUserExtended -User_Id 2230332,3243114

<#
    Get-SchoolUserList Example
    (Use Get-SchoolRoleList to get a list)
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
 # $list = Get-SchoolUserList -Roles "15434,15426"
 # [array]$list = Get-SchoolUserList -Roles '15475'
 # $list.Count

<#
    Get-SchoolUserExtendedList Example
    (Use Get-SchoolRoleList to get a list)
    Note that this takes BASE ROLE IDs and not roles. So a person might show up in the Staff list even if they are not in the Staff role
    because they are in the "Admin Team" role which has the same base_role_id as Staff.
    Suggest making the variable an array if you expect a single item in the list response and you need to use the .Count
    The .Count function will NOT work if you only a single response and are using Windows Powershell (5.1)
    because the returned object type is a PSCustomObject and not an array in those cases. 
    PowerShell Core (6+) WILL count correctly even if only a single PSCustomObject is returned.
#>
# [array]$list = Get-SchoolUserExtendedList -Base_Role_Ids "332,15,14"
# $list.Count
# # Get students in grades 4-8. Roll ID 14 is Student.
# $GoogleClassroomStudents = Get-SchoolUserExtendedList -Base_Role_Ids "14" | Where-Object {@('4','5','6','7','8') -Contains $_.student_info.grade_level} | Select-Object -Property id, email, student_info

<#
    Get-SchoolStudentEnrollmentList Example
#>
# $StudentEnrollmentList = Get-SchoolStudentEnrollmentList -User_ID 3243114
# $StudentEnrollmentList.Count

<#
    Get-SchoolActivityListBySchoolLevel Example
    (Use Get-SchoolLevelList to get a list of levels to filter by)
#>
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityListBySchoolLevel -Level_Number 228,229
#  $SchoolActivityListBySchoolLevel.Count
#  $SchoolActivityListBySchoolLevel[0]
#  $SchoolActivityListBySchoolLevel[1]
#  [array]$SchoolActivityListBySchoolLevel = Get-SchoolActivityListBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolAdvisoryListBySchoolLevel Example
    (Use Get-SchoolLevelList to get a list of levels to filter by)
#>
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryListBySchoolLevel -Level_Number 228,229
#  $SchoolAdvisoryListBySchoolLevel.Count
#  $SchoolAdvisoryListBySchoolLevel[0]
#  $SchoolAdvisoryListBySchoolLevel[1]
#  [array]$SchoolAdvisoryListBySchoolLevel = Get-SchoolAdvisoryListBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionListBySchoolLevel Example
    (Use Get-SchoolLevelList to get a list of levels to filter by)
#>
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionListBySchoolLevel -Level_Number 228,229
#  $SchoolSectionListBySchoolLevel.Count
#  $SchoolSectionListBySchoolLevel[0]
#  $SchoolSectionListBySchoolLevel[1]
#  [array]$SchoolSectionListBySchoolLevel = Get-SchoolSectionListBySchoolLevel -Level_Number 229 -school_year "2019-2020"

<#
    Get-SchoolSectionListByStudent Example
#>
# [array]$SectionListByStudent = Get-SchoolSectionListByStudent -Student_ID 6111769,2772870
# $SectionListByStudent.Count

<#
    Get-SchoolSectionListByTeacher Example
#>
# [array]$SectionListByTeacher = Get-SchoolSectionListByTeacher -Teacher_ID 1757293,2878846
# $SectionListByTeacher.Count

<#
    Get-SchoolCourseList Example
#>
# $courseList = Get-SchoolCourseList -level_id 229 | Where-Object inactive -Match "false"
# $courseList 

<#
    Get-SchoolEducationList Example
#>
# Get-SchoolEducationList -User_ID 1757293,1757293

<#
    Get-SchoolStudentListBySection Example
    (Use Get-SchoolSectionListBySchoolLevel to get a list)
#>
# Get-SchoolStudentListBySection -Section_ID "93054528"

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
    Get-SchoolNewsCategories Example
#>
# Get-SchoolNewsCategories

<#
    Get-SchoolNewsItems Example
#>
# Get-SchoolNewsItems
# Get-SchoolNewsItems -categories '12027,3154'