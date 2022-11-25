# Changelog for SKYAPI PowerShell Module

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
- New Endpoint (Beta): [Get-SchoolSchedulesMeetings](https://developer.sky.blackbaud.com/docs/services/school/operations/V1SchedulesMeetingsGet)
- New Endpoint: [New-SchoolEventsCategory](https://developer.sky.blackbaud.com/docs/services/school/operations/V1EventsCategoriesPost)
- New Endpoint: [New-SchoolUserPhone](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersByUser_idPhonesPost)
- New Endpoint: [Update-SchoolUser](https://developer.sky.blackbaud.com/docs/services/school/operations/V1UsersPatch)

### Other
- Renamed a backend function to prevent possible conflicts with other modules.
- Removed the prerelease string fromm the module manifest.
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
- Added the "AuthenticationMethod" paramameter to the "Connect-SKYAPI" cmdlet which let's you specify how you want to authenticate if authentication is necessary:
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
