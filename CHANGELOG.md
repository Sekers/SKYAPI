# Changelog for SKYAPI PowerShell Module

## [0.3.11](https://github.com/Sekers/SKYAPI/tree/0.3.11) - (2024-10-14)

### Features

- BREAKING CHANGE: Updated the included [Microsoft Edge WebView2 control](https://www.nuget.org/packages/Microsoft.Web.WebView2) to version [1.0.2792.45](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.2792.45). Note that the minimum .NET Framework version requirement for .NET WebView2 has been updated from .NET Framework 4.5 to .NET Framework 4.6.2 (this affects Windows PowerShell Desktop only, not PowerShell Core).
- New Endpoint: [Get-SchoolAdmissionCandidate](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AdmissionsCandidatesGet)
- New Endpoint: [Get-SchoolAdmissionStatus](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AdmissionsStatusGet)
- New Endpoint (Currently Beta): [Get-SchoolActivityRoster](https://developer.sky.blackbaud.com/api#api=school&operation=V1ActivitiesRostersGet)
- New Endpoint (Currently Beta): [Get-SchoolAdvisoryRoster](https://developer.sky.blackbaud.com/api#api=school&operation=V1AdvisoriesRostersGet)
- New Endpoint (Currently Beta): [Get-SchoolRoster](https://developer.sky.blackbaud.com/api#api=school&operation=V1AcademicsRostersGet)
- Added new parameters to Set-SchoolUserRelationship: resides_with, do_not_contact, primary, & comments
- Updates to error handling as the Blackbaud SKY API now returns at least 4 different types of error message formats.
- New sample script: Blackbaud SIS Teacher Schedules to ICS

### Other
- Updated links for built-in help to new endpoint documentation URLs. 
- Updated authorize URI in various places due to updates on the API end (the old URI still works since it is forwarded to the new one).
- Minor example and built-in help updates, clarifications, and typo fixes.
- Removed references to resolved Blackbaud API DATETIME bug.
- Removed temporary fix for now resolved bad email bug in the endpoint for Update-SchoolUser.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.10](https://github.com/Sekers/SKYAPI/tree/0.3.10) - (2023-03-21)

### Fixes

- Resolved bug where Get-SchoolScheduleMeeting returned an error after DST begins in timezones that practice advancing clocks during warmer months.

### Features

- New Endpoint: [Get-SchoolUserAddressType](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersAddresstypesGet)
- New Endpoint: [Get-SchoolUserAddress](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idAddressesGet)
- New Endpoint: [New-SchoolUserAddress](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idAddressesPost)

### Other
- Updated links in README to Blackbaud API documentation as the documentation website had slightly changed structure.
- A few minor example and built-in help updates, clarifications, and typo fixes.
- Removed the 'links' parameter from New-SchoolUserPhone as Blackbaud never actually implemented this feature in the endpoint and updated their documentation. See the [February 28, 2023 Education Management API changelog](https://developer.blackbaud.com/skyapi/support/changelog/bbem) for further information.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.9](https://github.com/Sekers/SKYAPI/tree/0.3.9) - (2023-03-06)

### Features

- New Endpoint: [Get-SchoolSession](https://developer.sky.blackbaud.com/docs/services/school/operations/V1SessionsGet)
- New Endpoint: [Get-SchoolResourceBoard](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentResourcesGet)
- 'Get-SchoolAssignmentBySection' & 'Get-SchoolScheduleMeeting' now allow spaces in the types/offering_types parameters.
- New Example Script: [Blackbaud SIS Teacher Schedules to Google Calendar CSVs](https://github.com/Sekers/SKYAPI/tree/master/Sample_Usage_Scripts/Blackbaud%20SIS%20Teacher%20Schedules%20to%20Google%20Calendar%20CSVs). Creates importable Google Calendar schedules for faculty from the Blackbaud School Envirionment.

### Other
- Built-in help updates regarding necessary permissions to access some endpoints (Blackbaud [loosened the requirements](https://developer.blackbaud.com/skyapi/support/changelog/bbem?_ga=2.83020246.1587108373.1678131781-1653312318.1663684217) on a bunch of general information ones).

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.8](https://github.com/Sekers/SKYAPI/tree/0.3.8) - (2023-02-13)

### Fixes

- Resolved bug where Get-SchoolScheduleMeeting returned duplicate events every 30th day of the requested range.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.7](https://github.com/Sekers/SKYAPI/tree/0.3.7) - (2023-02-02)

### Breaking Changes

- Beta cmdlet/function Get-SchoolScheduleMeeting now returns meeting start/end times in UTC so that there are no time zone issues. See the built-in help or examples file to see ways to convert to the local time or a specific timezone.

### Fixes

- Worked around a time zone bug in the [beta API endpoint](https://developer.sky.blackbaud.com/docs/services/school/operations/V1SchedulesMeetingsGet) used by Get-SchoolScheduleMeeting so that the cmdlet/function always correctly handles Daylight Saving Time adjustments.

### Features

- New Endpoint: [Get-SchoolTimeZone](https://developer.sky.blackbaud.com/docs/services/school/operations/V1TimezoneGet)
- Get-SchoolScheduleMeeting now accepts the following new option parameter values: section_ids & last_modified.
- Updated the included [Microsoft Edge WebView2 control](https://www.nuget.org/packages/Microsoft.Web.WebView2) to version [1.0.1518.46](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.1518.46).
- With this new version of the WebView2 control, we can now use the control to natively clear the browser cache. If the version of the [Edge WebView2 runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) installed on the computer (this is different than the WebView2 control included with the module) is too old, the SKYAPI PowerShell module will use the old method of deleteing the entire WebView2 control's profile for the user account used by the process.

### Other

- Minor fixes, such as the ability to handle certain transient errors returned by the API servers.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.6](https://github.com/Sekers/SKYAPI/tree/0.3.6) - (2023-01-19)

### Fixes

- HOTFIX: Resolved issue where error was presented on some endpoints when DateTime fields are returned empty.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.5](https://github.com/Sekers/SKYAPI/tree/0.3.5) - (2023-01-19)

### Fixes

- Resolved issue with the 'dob' parameter in the Update-SchoolUser function so it accepts a string.
- Fixed a format issue with the response of Get-SchoolSectionByStudent.

### Features

- Most endpoints now support the optional 'ReturnRaw' switch parameter to return the original JSON response from the Blackbaud SKY API. Otherwise, they will usually return the data in a custom PSObject or Hashtable object that has a property for each field in the JSON string.
- New optional 'ConvertTo' parameter for Get-SchoolList that tells the function to instead return the list collection results as an Array of PowerShell objects rather than the wonky, hard-to-work-with, way the API returns list results collections.
- New Endpoint: [Get-SchoolAssignmentBySection](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsBySection_idAssignmentsGet)
- New Endpoint: [Get-SchoolAssignmentByStudent](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsByStudent_idAssignmentsGet)
- New Endpoint: [Get-SchoolCycleBySection](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsSectionsBySection_idCyclesGet)
- New Endpoint: [New-SchoolUserOccupation](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idOccupationsPost)

### Other

- Created an internal function to try and correct issues with the way DateTime fields are improperly handled by the API until Blackbaud resolves the problems.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.4](https://github.com/Sekers/SKYAPI/tree/0.3.4) - (2022-12-05)

### Fixes

- Stopped sending an erroneously sent parameter to the Get-SchoolList Blackbaud SKY API endpoint. It doesn't affect anything but is unnecessary.
- Made the 'number' & 'type_id' parameters of the New-SchoolUserPhone function mandatory as the API endpoint requires them.

### Features

- Module now works with DELETE endpoints, thus allowing for REMOVE-* PowerShell functions against the SKY API.
- All functions/cmdlets have [comment-based help](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help) (i.e., Get-Help [FunctionName]).
- All functions/cmdlets now have consistent [positional parameter values](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/types-of-cmdlet-parameters#positional-and-named-parameters) for all non-dynamic parameters.
- New Endpoint: [Get-ReConstituentRatingSource](https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListRatingSources)
- New Endpoint: [Get-ReConstituentRelationshipType](https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListRelationshipTypes)
- New Endpoint: [Get-ReConstituentSuffix](https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListSuffixes)
- New Endpoint: [Get-ReConstituentTitle](https://developer.sky.blackbaud.com/docs/services/56b76470069a0509c8f1c5b3/operations/ListTitles)
- New Endpoint: [Get-SchoolEnrollment](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersEnrollmentsGet)
- New Endpoint: [Get-SchoolUserEmployment](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idEmploymentGet)
- New Endpoint: [Get-SchoolUserGenderType](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersGendertypesGet)
- New Endpoint: [Remove-SchoolUserRelationship](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idRelationshipsDelete)
- New Endpoint: [Set-SchoolUserRelationship](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idRelationshipsPost)

### Other

- Fixed the casing of some passed/passthru parameters to the Blackbaud SKY API lowercase to match the API documentation as they had accidentally been made camelcase like non-API passed parameters.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.3](https://github.com/Sekers/SKYAPI/tree/0.3.3) - (2022-11-26)

### Features

- Module now works with POST & PATCH endpoints, thus allowing for NEW-* & UPDATE-* PowerShell functions against the SKY API.
- New Endpoint (Beta): [Get-SchoolUserMe](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersMeGet)
- New Endpoint: [Get-SchoolUserOccupation](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idOccupationsGet)
- New Endpoint: [Get-SchoolUserRelationship](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idRelationshipsGet)
- New Endpoint: [Get-SchoolVenueBuilding](https://developer.sky.blackbaud.com/docs/services/school/operations/V1VenuesBuildingsGet)
- New Endpoint: Get-SKYAPIContext > Returns cached information about the current connection to the Blackbaud SKY API.
- New Connect-SKYAPI Parameter: ReturnConnectionInfo. Returns values when verifying the cached SKY API connection information.

### Other

- Made all function/cmdlet names consistent as singular (and some other adjustments) & removed the 'List' keyword from function names (as Blackbaud has moved away from using that descriptor and it's also unnecessary). The old function names are kept as aliases so there are no breaking changes due to these renames.
- Finished renaming all internal functions to prevent any naming conflicts with other modules.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.1](https://github.com/Sekers/SKYAPI/tree/0.3.1) - (2022-11-24)

### Fixes

- Resolved erroneous error message that sometimes appears when using New-SchoolUserPhone.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.3.0](https://github.com/Sekers/SKYAPI/tree/0.3.0) - (2022-11-24)

### Fixes

- Made the Connect-SKYAPI ClearBrowserControlCache parameter available only if ForceReathentication is used.
- When the Connect-SKYAPI ClearBrowserControlCache parameter is used, it will no longer return an error if the WebView folder doesn't exist.
- Removed Write-Verbose message from the Get-SKYAPIConfig function that was accidentally left in the code.

### Features

- Module now works with POST & PATCH endpoints, thus allowing for NEW-* & UPDATE-* PowerShell functions against the SKY API.
- New Endpoint: [Get-SchoolUserPhoneList](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesGet)
- New Endpoint: [Get-SchoolUserPhoneTypeList](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersPhonetypesGet)
- New Endpoint (Beta): [Get-SchoolScheduleMeetings](https://developer.sky.blackbaud.com/docs/services/school/operations/V1SchedulesMeetingsGet)
- New Endpoint: [New-SchoolEventsCategory](https://developer.sky.blackbaud.com/docs/services/school/operations/V1EventsCategoriesPost)
- New Endpoint: [New-SchoolUserPhone](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost)
- New Endpoint: [Update-SchoolUser](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersPatch)

### Other

- Renamed a backend function to prevent possible conflicts with other modules.
- Removed the prerelease string from the module manifest.
- Minor updates to the SKYAPI_Example.ps1 script.
- Module will wait and then try again a few times if a 503 (The service is currently unavailable) is returned to allow for transient issues with the API service.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.2.6b](https://github.com/Sekers/SKYAPI/tree/0.2.6b) - (2022-08-11)

### Fixes

- Updated Minimum PS Version to 5.1 to resolve GitHub action issue when publishing to the PowerShell Gallery.

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.2.6](https://github.com/Sekers/SKYAPI/tree/0.2.6) - (2022-08-11)

### Features

- First Release Published to the PowerShell Gallery
- New Endpoint (Beta): [Get-SchoolNewsCategories](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentNewsCategoriesGet)
- New Endpoint (Beta): [Get-SchoolNewsItems](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ContentNewsItemsGet)

Author: [**@Sekers**](https://github.com/Sekers)

---
## [0.2.5](https://github.com/Sekers/SKYAPI/tree/0.2.5) - (2022-07-28)

### Fixes

- Module now cleans up unused memory allocated to the Microsoft Edge WebView2 form when no longer needed

### Features

- Added ClearBrowserControlCache switch parameter to "Connect-SKYAPI"
- New Endpoint: [Get-SchoolDepartmentList](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsDepartmentsGet)
- New Endpoint (Beta): [Get-SchoolSectionListByStudent](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AcademicsStudentByStudent_idSectionsGet)
- New Endpoint: [Get-SchoolAdvisoryListBySchoolLevel](https://developer.sky.blackbaud.com/docs/services/school/operations/V1AdvisoriesSectionsGet)
- New Endpoint: [Get-SchoolActivityListBySchoolLevel](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ActivitiesSectionsGet)

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.2.4](https://github.com/Sekers/SKYAPI/tree/0.2.4) - (2022-06-08)

### Fixes

- Attempted to prevent the MarkerType type error message if it is somehow preloaded (e.g., your IDE preloading it for some reason)

### Features

- Replaced the soon to be deprecated WebBrowser Class (IE popup window for authentication & authorization) with the Microsoft Edge WebView2 control. See [Issue #7](https://github.com/Sekers/SKYAPI/issues/7).
- Added the "AuthenticationMethod" parameter to the "Connect-SKYAPI" cmdlet which let's you specify how you want to authenticate if authentication is necessary:
    - EdgeWebView2 (default): Opens a web browser window using Microsoft Edge WebView2 for authentication.
                              Requires the WebView2 Runtime to be installed. If not installed, will prompt for automatic installation.
    - LegacyIEControl: Opens a web browser window using the old Internet Explorer control. This is no longer supported by Blackbaud.
    - MiniHTTPServer (coming soon as a beta feature): Alternate method of capturing the authentication using your user account's default web browser
                      and listening for the authentication response using a temporary HTTP server hosted by the module.

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.2.3](https://github.com/Sekers/SKYAPI/tree/0.2.3) - (2022-06-02)

### Fixes

- Resolved pagination issues when 1,000 or more records were returned using Get-SchoolList or Get-SchoolUserExtendedList

### Features

- New Endpoint: [Get-SchoolUserExtended](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersExtendedByUser_idGet)
- New Endpoint: [Get-SchoolListOfLists](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ListsGet)
- New Endpoint: [Get-SchoolUserBBIDStatus](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersBbidstatusGet)

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.2.2](https://github.com/Sekers/SKYAPI/tree/0.2.2) - (2022-06-02)

### Fixes

- Fixed issue with manifest file (typo preventing module from loading)

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.2.1](https://github.com/Sekers/SKYAPI/tree/0.2.1) - (2022-06-01)

### Fixes

- Fixed rare bug on a couple of endpoints that use the Marker parameter

### Features

- Improved Invoke Error Handling
- New Endpoint: [Get-SchoolList](https://developer.sky.blackbaud.com/docs/services/school/operations/V1ListsAdvancedByList_idGet) - Replaces the soon to be deprecated [Legacy List](https://developer.sky.blackbaud.com/docs/services/school/operations/V1LegacyListsByList_idGet) endpoint. The 'Get-SchoolLegacyList" cmdlet will continue to work as expected using this new endpoint.

### Other

- Cleaned up unused variables
- Removed helper functions from module manifest as they don't need to be called manually
- Reduced wait time before retrying (500) internal server errors

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.2.0](https://github.com/Sekers/SKYAPI/tree/0.2.0) - (2021-11-15)

### Fixes

- [Issue 1](https://github.com/Sekers/SKYAPI/issues/1) - Updated Web Control Browser Emulation to be more compatible with authentication authorization pages that don't like IE 7 emulation mode (e.g., when using Google SSO).

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.1.1](https://github.com/Sekers/SKYAPI/tree/0.1.1) - (2020-10-05)

### Features

- Initial documentation release

Author: [**@Sekers**](https://github.com/Sekers)

---

## [0.1.0](https://github.com/Sekers/SKYAPI/tree/0.1.0) - (2020-10-05)

### Features

- Initial public release

Author: [**@Sekers**](https://github.com/Sekers)
