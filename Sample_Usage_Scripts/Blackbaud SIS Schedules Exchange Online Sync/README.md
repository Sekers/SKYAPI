# Blackbaud SIS User Schedules Exchange Online Sync

## Overview

A PowerShell script that uses the [SKYAPI PowerShell Module](https://github.com/Sekers/SKYAPI) to 1-way synchronize (mirror) Blackbaud SIS schedule meetings into each user's Exchange Online Outlook calendar using the [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation).

For every configured user, the script pulls their schedule meetings from the SIS, then creates, updates, and removes matching events on their Exchange Online calendar so the calendar reflects the current schedule. Each event it creates is stamped with a private [extended property](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview) tag, and the script filters on that tag when reading the calendar. As a result it **only ever reads, updates, or deletes the events it created itself** — meetings the user added manually, events from other apps, and anything outside the tag are never touched. See [How the Script Isolates Its Own Events](#how-the-script-isolates-its-own-events-extended-properties) below.

The script syncs **section leads (referred to here as "teachers")** and, optionally, **enrolled students**. Whether a person is treated as a teacher or a student is decided per meeting, so the same person can be a teacher on one section's events and a student on another's, all in a single run.

---

## Features

- Mirrors Blackbaud SIS schedule meetings to each user's Exchange Online Outlook calendar (create, update, and remove events).
- **Only manages its own events.** Every created event is tagged with a single-value extended property, and the calendar is read back through a filter on that tag, so the script never modifies or removes events it did not create (see [How the Script Isolates Its Own Events](#how-the-script-isolates-its-own-events-extended-properties)).
- **Flexible population**:
  - **Teachers only**,
  - **Students only**, or
  - **Both in the same config**.
- **"Teacher" means whoever is a lead of a section**, regardless of offering type — a classroom teacher (Academics), an advisor (Advisory), a coach (Athletics), or an activity leader (Activities). The label comes from being in a meeting's leads/teachers list. Note that most offering types restrict leads to certain Blackbaud Edu roles and the same goes for students (non-lead participants).
- **Offering-type-aware links.** Each event body lists the section's teachers and links back to the section in the school app — the faculty roster/advisees page for teachers, or the bulletin board for students — based on the meeting's offering type.
- **Automatic Outlook categories.** Creates a color-coded Outlook category per course (auto-assigning the least-used preset color) so events are visually grouped.
- **Flexible date selection** — `Year`, `Term` (keeps each meeting only within its own level's current term), or a fixed `Range`, plus a configurable look-ahead window and a limit on how far into the past to sync.
- **Ignore lists** to exclude specific groups or courses from syncing.
- **Per-user preferences** to override the default *Show As*, reminder on/off, and reminder-minutes settings for individual users.
- Authentication options for Microsoft Graph:
  - Delegated Permissions (run using a signed-in user).
  - Application Permissions (application consented by an administrator and authenticated by certificate or secret).
- Optional non-blocking logging & email alerting (requires prerequisite modules).
- Optional per-run user sync-history CSV.
- Debugging options.

---

## PREREQUISITES

- [SKYAPI PowerShell Module (Required):](https://github.com/Sekers/SKYAPI) The PowerShell module used to connect to the Blackbaud SIS via the SKY API. You will also need a [Blackbaud SKY API developer account](https://developer.blackbaud.com/skyapi/) with a registered application.
- [Microsoft.Graph PowerShell SDK (Required):](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation) Microsoft's Graph API PowerShell module, used to manage Exchange Online calendars.
  - **Note:** To minimize the installation footprint you only need the `Microsoft.Graph.Authentication` and `Microsoft.Graph.Calendar` submodules rather than the full `Microsoft.Graph` module.
- [PowerShell Framework Module (Optional):](https://psframework.org/) For modern logging. Optional and only needed if using the logging functionality.
- [ScriptMessage Module (Optional):](https://github.com/Sekers/ScriptMessage) For sending email alerts from the script. Optional and only needed if using the email alerting functionality.

---

## JSON Configuration Files Information

Make copies of the sample configuration files in the 'Config Templates' folder and place them into a 'Config' folder next to the script. Update these configuration settings using the documentation below.

The script reads its configuration from `Config\...`, **not** from `Config Templates\...`.

**Note on paths:** Any setting that takes a filesystem path is a JSON string, so each backslash must be escaped by doubling it. Write `"$PSScriptRoot\\Config\\file.json"`, not `"$PSScriptRoot\Config\file.json"` (see [JSON Escape / Unescape](https://www.freeformatter.com/json-escape.html)).

The five configuration files are:

- **config_general.json** — the primary configuration settings for the script.
- **config_sky_api.json** — your Blackbaud SKY API application credentials.
- **config_scriptmessage.json** — email/messaging settings (only used when email alerts are enabled).
- **config_meetings_to_ignore.json** — meetings to exclude from syncing.
- **config_user_preferences.json** — per-user overrides for event preferences.

---

### **config_general.json**

JSON file that contains the primary configuration settings for the script.

#### General

- **EmailonError (Boolean):** Whether to use the email functionality to email an alert on script-stopping errors.
- **EmailonWarning (Boolean):** Whether to use the email functionality to email an alert on non-critical warnings.
- **TeacherRoleIDs (Array of Integers):** The SIS role IDs whose members should be synced as section leads ("teachers"). May be left empty for a student-only sync. This list only decides *who* gets synced; whether a given meeting treats the user as a teacher is determined per-meeting from the section's leads (see [Features](#features)). At least one of `TeacherRoleIDs` or `StudentRoleIDs` must be configured.
- **StudentRoleIDs (Array of Integers):** The SIS role IDs whose members should be synced as students (non-lead participants). May be left empty for a teacher-only sync. When this is populated (i.e. not empty), this indicates to the script that it needs to pull entire section rosters which costs an extra one-time API call per run. This is because the SKY API [Get Schedules Meetings](https://developer.sky.blackbaud.com/api#api=school&operation=V1SchedulesMeetingsGet) endpoint only returns teachers (lead participants). At least one of `TeacherRoleIDs` or `StudentRoleIDs` must be configured.
- **Meetings_DateSelection (String):** Determines the date window of meetings to sync. Valid values:
  - **Year:** Syncs the current school year's meetings (optionally extending into the next school year — see `Meetings_DaysToAppearBefore`).
  - **Term:** Syncs only the current term's meetings. Because different levels and offering types can have different term structures (e.g. two academic semesters but a single year-long advisory term), the script determines the current term separately for each *level + offering type* and keeps a meeting only if its date falls inside that specific term window.
  - **Range:** Syncs a fixed date range that you specify with `Meetings_StartDate` and `Meetings_EndDate`. Great for testing.
- **Meetings_DaysToAppearBefore (Integer):** Only used when `Meetings_DateSelection` is set to 'Year' or 'Term'. Controls when the sync begins reaching into the **next** school year (`Year` mode) or the **next** term(s) (`Term` mode). Once the upcoming year's/term's start date falls within this many days of the current date, that year/term is pulled into the sync. Because it triggers at the year/term boundary rather than per meeting, crossing the threshold brings in the whole upcoming year (`Year` mode) or the whole upcoming term (`Term` mode) at once (not just the meetings within this many days). In `Term` mode the threshold is applied independently for every level and offering type (see `Meetings_DateSelection` → `Term` above). Set to `0` to never look ahead.
- **Meetings_MaxPastDaysToSync (Integer or null):** Limits how far into the past meetings are synced, counting back from today. The effective sync start is whichever is *more recent*: this cutoff, or the start the selected mode already computed (school-year start for `Year`, current-term start for `Term`, or `Meetings_StartDate` for `Range`). Because it can only move the start date forward, it never reaches earlier than the mode's own start. Use `null` to apply no extra past cutoff (i.e., the sync then goes back to the mode's start date).
- **Meetings_StartDate (String):** Only used when `Meetings_DateSelection` is set to 'Range'. The start date of the range in ISO 8601 date format (`yyyy-MM-dd`, e.g. "2025-08-15").
- **Meetings_EndDate (String):** Only used when `Meetings_DateSelection` is set to 'Range'. The end date of the range in ISO 8601 date format (`yyyy-MM-dd`, e.g. "2026-06-05").
- **Meetings_OfferingTypes (Array of Strings):** The SIS offering type descriptions to sync. Possible options are:
  - Academics
  - Advisory
  - Activities
  - Athletics
- **DefaultShowAs (String):** The default *Show As* / availability status for created events. Passed to Microsoft Graph as-is as the event's [`showAs`](https://learn.microsoft.com/en-us/graph/api/resources/event#properties) property, so the value must be one of the Graph `freeBusyStatus` values: "Unknown", "Free", "Tentative", "Busy", "Oof", "WorkingElsewhere". Can be overridden per user in `config_user_preferences.json`.
- **DefaultIsReminderOn (Boolean):** The default for whether a reminder is enabled on created events. Can be overridden per user.
- **DefaultReminderMinutesBeforeStart (Integer):** The default number of minutes before the event start that the reminder fires (when reminders are enabled). Can be overridden per user.
- **EventsAppIdentifier_GUID (String):** The GUID portion of the extended-property tag applied to every event the script creates. Give each deployment its own unique GUID so separate instances never manage each other's events — generate a fresh random one (e.g. run `New-Guid` in PowerShell) rather than reusing a GUID from elsewhere, which also avoids colliding with Outlook's own well-known property-set GUIDs. **Changing this after events exist will orphan (stop tracking) the previously created events.** See [How the Script Isolates Its Own Events](#how-the-script-isolates-its-own-events-extended-properties).
- **EventsAppIdentifier_Name (String):** The named-property name portion of the extended-property tag. Any short descriptive string works (e.g. "EventsAppIdentifier"). Matching is case-sensitive and exact, but the script builds both the create-side tag and the read-side filter from this same setting, so they always stay in sync.
- **EventsAppIdentifier_Value (String):** The value stored in the extended-property tag. Any descriptive string works (e.g. "user_schedule_sync"). The script matches on both the tag id and this value when finding its own events, so together the GUID, Name, and Value form the deployment's fingerprint.
- **MySchoolAppDomain (String):** Your school app domain (e.g. "school.myschoolapp.com"). Used to build the roster/bulletin-board deep links placed in each event body.
- **SaveUsersSyncHistoryPath (String):** Optional. The path where a per-run user sync-history CSV is written. Accepts PowerShell variables and the `%date%` token (e.g. `"$PSScriptRoot\\Logging\\User Sync History-%date%.csv"`). Leave empty to disable the sync history. The wildcard filter used to rotate old sync-history files is derived automatically from this filename by replacing the `%date%` token with `*` (e.g. `User Sync History-%date%.csv` → `User Sync History-*.csv`).
  - Note: This is **separate from the script logging**. Rather than a running diagnostic trace, the sync history is a structured CSV with one row per user processed in the run (timestamp, user ID, name, email, and meeting count). It is useful as an at-a-glance audit/reporting record of who was synced and how many meetings each user had — handy for confirming expected users were included, spotting users with zero meetings, and tracking sync coverage over time.
- **UsersSyncHistoryRetentionTimeInDays (Integer):** Only used when `SaveUsersSyncHistoryPath` is set. How many days of sync-history files to keep; older matching files are removed.

#### SKYAPI

For more information on the Blackbaud SKY API and using these settings with the SKY API PowerShell module, see the [SKYAPI PowerShell module wiki](https://github.com/Sekers/SKYAPI/wiki).

- **ConfigFilePath (String):** The location of your Blackbaud SKY API configuration file (`config_sky_api.json`). Accepts PowerShell variables (e.g. `"$PSScriptRoot\\Config\\config_sky_api.json"`).
- **TokensFilePath (String):** The location where the SKY API access and refresh tokens are stored. Accepts PowerShell variables (e.g. `"$env:USERPROFILE\\API_Tokens\\SKYAPI_UserSchedules_sky_api_key.json"`).

#### MSGraph

- **MgPermissionType (String):** Set the [type of permission](https://learn.microsoft.com/en-us/graph/auth/auth-concepts#delegated-and-application-permissions) you want to use to access the Microsoft Graph API. The script requires the `Calendars.ReadWrite` and `MailboxSettings.Read` scopes.
  - **Application:** This is the preferred option when you want the script to run or be automated without a signed-in user present. Application permissions can only be [consented by an administrator](https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-scopes#requesting-consent-for-an-entire-tenant). You will need to [register the script as an app](https://learn.microsoft.com/en-us/graph/auth-v2-service#1-register-your-app) and then [grant admin consent for the necessary scopes](https://learn.microsoft.com/en-us/graph/auth-v2-service#2-configure-permissions-for-microsoft-graph):

    | Application Permission | Display String | Admin Consent Required |
    | ---------- | -------------- | ---------------------- |
    | [Calendars.ReadWrite](https://learn.microsoft.com/en-us/graph/permissions-reference#calendarsreadwrite) | Read and write calendars in all mailboxes. | Yes |
    | [MailboxSettings.Read](https://learn.microsoft.com/en-us/graph/permissions-reference#mailboxsettingsread) | Read all user mailbox settings. | Yes |

  - **Delegated:** The delegated option will cause the script to prompt for a user to sign in and is only recommended for interactive use. Either the user or an administrator would consent to the permissions needed for the script. If you disconnect from the Graph API or if the [tokens expire](https://learn.microsoft.com/en-us/entra/identity-platform/configurable-token-lifetimes), you will need to reauthenticate. Because sign-in is interactive and uses your own app registration (the `MgClientID` app), that app registration must have a redirect URI of `http://localhost` registered — in the Entra admin center, go to **App registrations → your app → Authentication → Add a platform → Mobile and desktop applications** and add `http://localhost`. Scopes needed by this script for delegated permissions are:

    | Delegated Permission | Display String | Admin Consent Required |
    | ---------- | -------------- | ---------------------- |
    | [Calendars.ReadWrite](https://learn.microsoft.com/en-us/graph/permissions-reference#calendarsreadwrite) | Have full access to user calendars. | No |
    | [MailboxSettings.Read](https://learn.microsoft.com/en-us/graph/permissions-reference#mailboxsettingsread) | Read user mailbox settings. | No |

- **MgDisconnectWhenDone (Boolean):** Specifies whether to disconnect from the Graph API when the script finishes. Recommended when using the Application permission type. If you do not disconnect, Microsoft Graph PowerShell automatically refreshes the access token for you and sign-in persists across PowerShell sessions because Microsoft Graph PowerShell securely caches the token.
- **MgClientID (String):** This is where you would enter the [registered application ID value](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-tenant-and-app-id-values-for-signing-in).
- **MgTenantID (String):** This is where you would enter the [registered tenant ID value](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-tenant-and-app-id-values-for-signing-in).
- **MgApp_AuthenticationType (String):** Only used when 'MgPermissionType' is set to 'Application'. Authentication options include:
  - **CertificateFile:** Tells the script that you will specify a path to a certificate with a private key. The paired public certificate (without a private key) should be [added to the registered Azure app registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-a-certificate). For testing, you can [create a self-signed public certificate](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-self-signed-certificate) instead of using a Certificate Authority (CA)-signed certificate. **Note:** connecting with a certificate file is only supported on PowerShell 7.4 and later.
  - **CertificateName:** Tells the script that you will specify the Common Name (e.g. 'CN=My Test Certificate Name') of a certificate with a private key. This certificate should be in the current user certificate store of the account that the script runs under. The paired public certificate should be [added to the registered Azure app registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-a-certificate).
  - **CertificateThumbprint:** Tells the script that you will specify the thumbprint of a certificate with a private key. This certificate should be in the current user certificate store of the account that the script runs under. The paired public certificate should be [added to the registered Azure app registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-a-certificate).
  - **ClientSecret:** Tells the script that you will specify a client secret, sometimes called an *application password*. Client secrets are considered less secure than certificate credentials and are best reserved for local development; use certificate credentials for production. You can [add a client secret for the registered application](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-a-client-secret) from the Azure portal. It's recommended to use PowerShell 7 and above when using client secret credentials.
- **MgApp_CertificatePath (String):** Only used when 'MgApp_AuthenticationType' is set to 'CertificateFile'. Enter the path where the private key certificate file (.pfx) is located. You can include PowerShell code and variables (e.g., `"$PSScriptRoot\\Config\\PrivateKeyCertificate.pfx"`).
- **MgApp_CertificateName (String):** Only used when 'MgApp_AuthenticationType' is set to 'CertificateName'. Enter the Common Name of the private key certificate. E.g., "CN=My Test Certificate Name".
- **MgApp_CertificateThumbprint (String):** Only used when 'MgApp_AuthenticationType' is set to 'CertificateThumbprint'. Enter the private key certificate's thumbprint.
- **MgApp_EncryptedCertificatePassword (Encrypted Standard String):** Optionally used when 'MgApp_AuthenticationType' is set to 'CertificateFile'. If the account the process runs under cannot decrypt the private key certificate file, the script will attempt to do so using this password. An encrypted standard string can be converted back to its secure string format but **only by the same account on the same computer it was encrypted from**. You can use the [New-EncryptedPassword script](https://github.com/Sekers/Useful-Scripts/tree/main/Password%20Tools/New-EncryptedPassword) to easily convert a password to an encrypted standard string.
- **MgApp_EncryptedSecret (Encrypted Standard String):** Only used when 'MgApp_AuthenticationType' is set to 'ClientSecret'. Enter the encrypted standard string of the client secret. An encrypted standard string can be converted back to its secure string format but **only by the same account on the same computer it was encrypted from**. You can use the [New-EncryptedPassword script](https://github.com/Sekers/Useful-Scripts/tree/main/Password%20Tools/New-EncryptedPassword) to easily convert a secret to an encrypted standard string.

#### Logging

Optionally enter the logging information based on the [documentation](https://psframework.org/docs/category/logging) for the PowerShell Framework module. If you do not want to use the logging system, set the logging 'Enabled' field to false.

#### Messaging

For detailed help configuring messaging (email, chat, etc.), see the [ScriptMessage PowerShell module wiki](https://github.com/Sekers/ScriptMessage/wiki).

- **ConfigFilePath (String):** Only used when `EmailonError` or `EmailonWarning` is true. The location of your ScriptMessage configuration file (`config_scriptmessage.json`). Accepts PowerShell variables.
- **ServiceType / From / ReplyTo / To / SaveToSentItems / SenderId:** Only used when `EmailonError` or `EmailonWarning` is true. The email alert delivery settings (service, sender, reply-to, recipients, etc.). See the [ScriptMessage documentation](https://github.com/Sekers/ScriptMessage) for details.

#### Debugging

- **VerbosePreference (String):** Determines how PowerShell responds to verbose messages generated by the script. Valid values and more information are in Microsoft's [preference variables documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables#verbosepreference).
  - **Stop:** Displays the verbose message and an error message and then stops executing.
  - **Inquire:** Displays the verbose message and then prompts you whether to continue.
  - **Continue:** Displays the verbose message and then continues with execution.
  - **SilentlyContinue:** (Default) Doesn't display the verbose message. Continues executing.
- **LogDebugInfo (Boolean):** Only used when logging is enabled (the Logging section's `Enabled` field). Specifies whether to log information the script normally considers unnecessary except when troubleshooting.

---

### **config_sky_api.json**

JSON file that contains your Blackbaud SKY API application credentials, as used by the [SKYAPI PowerShell Module](https://github.com/Sekers/SKYAPI). Create these values by registering an application in the [Blackbaud developer portal](https://developer.blackbaud.com/skyapi/). For more information on the Blackbaud SKY API and using these settings with the SKY API PowerShell module, see the [SKYAPI PowerShell module wiki](https://github.com/Sekers/SKYAPI/wiki).

- **api_subscription_key (String):** Your Blackbaud SKY API subscription access key.
- **client_id (String):** Your registered application's client ID.
- **client_secret (String):** Your registered application's client secret.
- **redirect_uri (String):** The redirect URI registered for your application (e.g. `"http://localhost:5000/auth/callback"`).
- **authorize_uri (String):** The SKY API authorization endpoint (e.g. `"https://app.blackbaud.com/oauth/authorize"`).
- **token_uri (String):** The SKY API token endpoint (e.g. `"https://oauth2.sky.blackbaud.com/token"`).

---

### **config_scriptmessage.json**

JSON file that contains the messaging-service settings used by the [ScriptMessage module](https://github.com/Sekers/ScriptMessage) to send email alerts. Only needed when `EmailonError` or `EmailonWarning` is enabled in `config_general.json`. For detailed help configuring messaging (email, chat, etc.), see the [ScriptMessage PowerShell module wiki](https://github.com/Sekers/ScriptMessage/wiki).

---

### **config_meetings_to_ignore.json**

JSON file that lets you exclude specific meetings from syncing. Each property name is a SIS meeting field, and its array of values are matched against that field — any meeting matching a value is skipped.

- **group_name (Array of Strings):** Group names to exclude (matched against each meeting's group name).
- **course_title (Array of Strings):** Course titles to exclude (matched against each meeting's course title).

---

### **config_user_preferences.json**

JSON file containing an array of per-user overrides for event settings. Create an array entry for *each* user you want to customize; any omitted field falls back to the corresponding `Default*` value in `config_general.json`.

- **UserEmail (String):** The email address of the user these preferences apply to (matched against the SIS user's email).
- **ShowAs (String):** Overrides `DefaultShowAs` for this user. Same accepted values as `DefaultShowAs` — one of the Graph [`freeBusyStatus`](https://learn.microsoft.com/en-us/graph/api/resources/event#properties) values ("Unknown", "Free", "Tentative", "Busy", "Oof", "WorkingElsewhere").
- **isReminderOn (Boolean):** Overrides `DefaultIsReminderOn` for this user.
- **ReminderMinutesBeforeStart (Integer):** Overrides `DefaultReminderMinutesBeforeStart` for this user.

---

## How the Script Isolates Its Own Events (Extended Properties)

The script is designed to **only ever read, update, or delete the calendar events it created itself.** Events a user added manually, events created by other apps, and any event that does not carry the script's tag are invisible to the script and are never modified or removed. This is achieved with a Microsoft Graph [extended property](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview) that acts as a private "fingerprint" on every event the script creates.

**1. Tagging on create.** When the script creates an event, it attaches a [single-value extended property](https://learn.microsoft.com/en-us/graph/api/resources/singlevaluelegacyextendedproperty) built from the three `EventsAppIdentifier_*` settings in `config_general.json`:

```powershell
singleValueExtendedProperties = @(
    @{
        id    = "String {$($EventsAppIdentifier_GUID)} Name $($EventsAppIdentifier_Name)"
        value = $EventsAppIdentifier_Value
    }
)
```

The `id` uses Graph's [named-property format](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview#named-properties) — `String {<GUID>} Name <name>` means a `String`-typed named property, named `<name>`, that lives in the property set identified by `<GUID>`. Together the id and the `value` form a tag unique to this deployment.

**2. Filtering on read.** When the script collects a user's existing events, it queries [Get-MgUserEvent](https://learn.microsoft.com/en-us/graph/api/user-list-events) with an OData `$filter` that requires both the extended-property tag *and* a date range (see [Get singleValueLegacyExtendedProperty](https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get) for the filter syntax):

```powershell
$Filter_ExtendedProperty = "(singleValueExtendedProperties/any(ep: ep/id eq 'String {$($EventsAppIdentifier_GUID)} Name $($EventsAppIdentifier_Name)' and ep/value eq '$($EventsAppIdentifier_Value)'))"
$Filter_DateRange        = "(Start/DateTime ge '$($Meetings_StartDateTime_UTC_ISO8601)') and (End/DateTime le '$($Meetings_EndDateTime_UTC_ISO8601)')"
$Filter                  = "($Filter_ExtendedProperty) and ($Filter_DateRange)"

Get-MgUserEvent -UserId $user.email -All -Filter $Filter -Property $MGEventProperties
```

**3. The consequence.** Because the calendar is only ever read back through this filter, the "create missing events", "update preferences", and "remove extra events" passes can act on *nothing but* the script's own tagged events within the sync date window. Nothing else on the user's calendar is ever seen or changed.

**Important notes:**

- Give each deployment its **own unique `EventsAppIdentifier_GUID` and `EventsAppIdentifier_Value`**. Two instances that share a tag would treat each other's events as their own (and could remove them). A separate test run should use its own tag values.
- **Changing the `EventsAppIdentifier_*` values after events already exist will orphan the previously created events** — the script will no longer recognize them, so it will neither update nor remove them (and may create duplicates alongside them).
- Extended properties are used (rather than schema extensions) specifically because they can be reliably filtered on the `event` object, which schema extensions cannot.

Related Microsoft Graph documentation:

- [Extended properties overview](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview)
- [Get singleValueLegacyExtendedProperty](https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get)
- [singleValueLegacyExtendedProperty resource type](https://learn.microsoft.com/en-us/graph/api/resources/singlevaluelegacyextendedproperty)
- [outlookCategory resource type](https://learn.microsoft.com/en-us/graph/api/resources/outlookcategory) (used for the per-course color categories)
- [dateTimeTimeZone resource type](https://learn.microsoft.com/en-us/graph/api/resources/datetimetimezone) (used for event start/end times)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

---

## Setup & Usage

1. Copy all five files from the `Config Templates` folder into the `Config` folder:
    - `config_general.json`
    - `config_sky_api.json`
    - `config_scriptmessage.json`
    - `config_meetings_to_ignore.json`
    - `config_user_preferences.json`
2. Edit each copied file and replace the placeholder values (role IDs, tenant/client IDs, certificate details, email addresses, domain, extended-property GUID, etc.) with your own, using the documentation above.
3. Install the [prerequisite modules](#prerequisites) and run the script (`Sync Schedules to Exchange Calendar.ps1`). On the first run you will be prompted to authorize the SKY API connection; the tokens are then cached at `TokensFilePath` for subsequent runs.
4. Optionally, schedule the script to run automatically (e.g., using Windows Task Scheduler). For unattended runs, set `MgPermissionType` to 'Application' so Microsoft Graph authenticates without a signed-in user, and run the scheduled task as the same account that performed the initial SKY API authorization so it can access the cached tokens.
