# Changelog for SKYAPI PowerShell Module

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
