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
- Microsoft Graph authentication via Application permissions (application consented by an administrator and authenticated by certificate or client secret), so the script can run unattended and manage every synced user's calendar.
- **Deletion safety limits** so a bad or incomplete SIS result can't quietly clear calendars (see [Deletion Safety](#deletion-safety)).
- **Reports its outcome** with an end-of-run summary and a meaningful [exit code](#exit-codes), so a scheduled task can tell a clean run from a partial or failed one.
- Optional non-blocking logging & email alerting (requires prerequisite modules).
- Optional per-run user sync-history CSV.
- Debugging options.

---

## PREREQUISITES

- [SKYAPI PowerShell Module (Required):](https://github.com/Sekers/SKYAPI) The PowerShell module used to connect to the Blackbaud SIS via the SKY API. You will also need a [Blackbaud SKY API developer account](https://developer.blackbaud.com/skyapi/) with a registered application.
- [Microsoft.Graph PowerShell SDK (Required):](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation) Microsoft's Graph API PowerShell module, used to manage Exchange Online calendars.
  - **Note:** To minimize the installation footprint you only need the `Microsoft.Graph.Authentication`, `Microsoft.Graph.Calendar` & `Microsoft.Graph.Users` submodules rather than the full `Microsoft.Graph` module.
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
- **MySchoolAppDomain (String):** Your school app domain (e.g. "school.myschoolapp.com"). Used to build the roster/bulletin-board deep links placed in each event body.

##### General → Meetings

- **DateSelection (String):** Determines the date window of meetings to sync. Valid values:
  - **Year:** Syncs the current school year's meetings (optionally extending into the next school year — see `DaysToAppearBefore`).
  - **Term:** Syncs only the current term's meetings. Because different levels and offering types can have different term structures (e.g. two academic semesters but a single year-long advisory term), the script determines the current term separately for each *level + offering type* and keeps a meeting only if its date falls inside that specific term window.
  - **Range:** Syncs a fixed date range that you specify with `StartDate` and `EndDate`. Great for testing.
- **DaysToAppearBefore (Integer, 0 or greater):** Only used when `DateSelection` is set to 'Year' or 'Term'. Controls when the sync begins reaching into the **next** school year (`Year` mode) or the **next** term(s) (`Term` mode). Once the upcoming year's/term's start date falls within this many days of the current date, that year/term is pulled into the sync. Because it triggers at the year/term boundary rather than per meeting, crossing the threshold brings in the whole upcoming year (`Year` mode) or the whole upcoming term (`Term` mode) at once (not just the meetings within this many days). In `Term` mode the threshold is applied independently for every level and offering type (see `DateSelection` → `Term` above). Set to `0` to never look ahead.
- **MaxPastDaysToSync (Integer 0 or greater, or null):** Limits how far into the past meetings are synced, counting back from today. The effective sync start is whichever is *more recent*: this cutoff, or the start the selected mode already computed (school-year start for `Year`, current-term start for `Term`, or `StartDate` for `Range`). Because it can only move the start date forward, it never reaches earlier than the mode's own start. Use `null` to apply no extra past cutoff (i.e., the sync then goes back to the mode's start date).
- **StartDate (String):** Only used when `DateSelection` is set to 'Range'. The start date of the range in ISO 8601 date format (`yyyy-MM-dd`, e.g. "2025-08-15").
- **EndDate (String):** Only used when `DateSelection` is set to 'Range'. The end date of the range in ISO 8601 date format (`yyyy-MM-dd`, e.g. "2026-06-05").
- **OfferingTypes (Array of Strings):** The SIS offering type descriptions to sync. Possible options are:
  - Academics
  - Advisory
  - Activities
  - Athletics

##### General → EventDefaults

These are the defaults applied to created events. Each can be overridden per user in `config_user_preferences.json`, and they are the properties the script keeps in sync on events it has already created.

- **ShowAs (String):** The default *Show As* / availability status for created events. Passed to Microsoft Graph as-is as the event's [`showAs`](https://learn.microsoft.com/en-us/graph/api/resources/event#properties) property, so the value must be one of the Graph `freeBusyStatus` values: "Unknown", "Free", "Tentative", "Busy", "Oof", "WorkingElsewhere".
- **IsReminderOn (Boolean):** The default for whether a reminder is enabled on created events.
- **ReminderMinutesBeforeStart (Integer):** The default number of minutes before the event start that the reminder fires (when reminders are enabled).

##### General → EventsAppIdentifier

- **GUID (String):** The GUID portion of the extended-property tag applied to every event the script creates. Give each deployment its own unique GUID so separate instances never manage each other's events. Generate a fresh random one (e.g. run `New-Guid` in PowerShell) rather than reusing a GUID from elsewhere, which also avoids colliding with Outlook's own well-known property-set GUIDs. **Changing this after events exist will orphan (stop tracking) the previously created events.** See [How the Script Isolates Its Own Events](#how-the-script-isolates-its-own-events-extended-properties).
- **Name (String):** The named-property name portion of the extended-property tag. Any short descriptive string works (e.g. "EventsAppIdentifier"). Matching is case-sensitive and exact, but the script builds both the create-side tag and the read-side filter from this same setting, so they always stay in sync.
- **Value (String):** The value stored in the extended-property tag. Any descriptive string works (e.g. "user_schedule_sync"). The script matches on both the tag id and this value when finding its own events, so together the GUID, Name, and Value form the deployment's fingerprint.

##### General → DeleteSafety

The sync removes any of its own events that no longer match a SIS meeting. That is what keeps calendars accurate, but it also means a bad or incomplete SIS result would clear events that should have stayed. These settings put a ceiling on how much one run is allowed to remove. See [Deletion Safety](#deletion-safety).

- **AllowEmptySourceSync (Boolean):** Whether to continue when the SIS returns no meetings at all (after the meetings to ignore and current-term filters). Normally `false`: an empty result means "remove every synced event in range from every calendar", which is nearly always a configuration or data problem rather than a real instruction, so the script stops before touching any calendar. Set to `true` only when an empty sync is genuinely expected. Because a run like that removes 100% of every user's synced events by design, it also overrides `MaxDeletePercentPerUser` for that run (the per-user limit would otherwise block the very cleanup being asked for); the override is reported loudly as a warning.
- **MaxDeletePercentPerUser (Integer, 1-100):** If **more than** this share of a user's existing synced events would be removed in a single run, the removals **and creations** for that user are held back and reported as a warning instead. (Creations are held back too because most trip cases are schedule *changes*; creating the replacement events while their old versions are held in place would leave duplicates.) The rest of the users are still processed, and preference updates are still applied to the held-back user. Re-run after confirming the SIS data is right, or raise this value — `100` means even a complete clear of a user's synced events is allowed.
- **MinDeletesBeforeCheck (Integer):** The percentage check only applies once at least this many removals are queued for the user. Without it, a user with 3 events would trip a 50% limit on 2 legitimate removals. Note the flip side: users with fewer queued removals than this are not protected by the percentage check at all.

##### General → UsersSyncHistory

- **Path (String):** Optional. The path where a per-run user sync-history CSV is written. Accepts PowerShell variables and the `%date%` token (e.g. `"$PSScriptRoot\\Logging\\User Sync History-%date%.csv"`). Leave empty to disable the sync history. The wildcard filter used to rotate old sync-history files is derived automatically from this filename by replacing the `%date%` token with `*` (e.g. `User Sync History-%date%.csv` → `User Sync History-*.csv`).
  - Note: This is **separate from the script logging**. Rather than a running diagnostic trace, the sync history is a structured CSV with one row per user processed in the run: timestamp, user ID, name, email, meeting count, how many events were created/updated/removed for them, and a status of `Success`, `Failed`, or `DeleteGuardTripped`. Very useful for confirming expected users were included, spotting users with zero meetings, and tracking sync coverage over time.
- **RetentionTimeInDays (Integer, 1 or greater):** Only used when `Path` is set. How many days of sync-history files to keep; older matching files are removed. Note that the rotation only matches the naming `Path` currently produces, so if you change `Path` later, any files left behind under the old naming are yours to clean up.

#### SKYAPI

For more information on the Blackbaud SKY API and using these settings with the SKY API PowerShell module, see the [SKYAPI PowerShell module wiki](https://github.com/Sekers/SKYAPI/wiki).

- **ConfigFilePath (String):** The location of your Blackbaud SKY API configuration file (`config_sky_api.json`). Accepts PowerShell variables (e.g. `"$PSScriptRoot\\Config\\config_sky_api.json"`).
- **TokensFilePath (String):** The location where the SKY API access and refresh tokens are stored. Accepts PowerShell variables (e.g. `"$env:USERPROFILE\\API_Tokens\\SKYAPI_UserSchedules_sky_api_key.json"`).

#### MSGraph

The script connects to Microsoft Graph using **[Application permissions](https://learn.microsoft.com/en-us/graph/auth/auth-concepts#delegated-and-application-permissions)** (an app registration [consented by an administrator](https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-scopes#requesting-consent-for-an-entire-tenant) and authenticated by certificate or client secret). Application permissions are required because the script manages calendars for every user returned by the SIS (delegated permissions only grant access to the signed-in user's own calendar plus calendars explicitly shared or delegated to them). You will need to [register the script as an app](https://learn.microsoft.com/en-us/graph/auth-v2-service#1-register-your-app) and then [grant admin consent for the necessary scopes](https://learn.microsoft.com/en-us/graph/auth-v2-service#2-configure-permissions-for-microsoft-graph):

| Application Permission | Display String | Admin Consent Required | Why the Script Needs It |
| ---------- | -------------- | ---------------------- | ----------------------- |
| [Calendars.ReadWrite](https://learn.microsoft.com/en-us/graph/permissions-reference#calendarsreadwrite) | Read and write calendars in all mailboxes. | Yes | Create, update & remove the synced calendar events. Also currently suffices for reading & creating the per-course Outlook categories (see note below). |
| [User.Read.All](https://learn.microsoft.com/en-us/graph/permissions-reference#userreadall) | Read all users' full profiles. | Yes | List directory users to verify each SIS user exists in Entra before touching their calendar. |

> **Note (MailboxSettings & Outlook categories):** Microsoft's documentation states that the [masterCategories API](https://learn.microsoft.com/en-us/graph/api/outlookuser-list-mastercategories) requires the [MailboxSettings.Read/ReadWrite](https://learn.microsoft.com/en-us/graph/permissions-reference#mailboxsettingsreadwrite) permissions. However, in testing (July 2026), Microsoft Graph permits an app with only `Calendars.ReadWrite` to read, create & remove master categories, so this script does not require `MailboxSettings.ReadWrite`. If Microsoft begins enforcing the documented requirement and the script starts failing on the category steps with `ErrorAccessDenied`, grant the app registration the `MailboxSettings.ReadWrite` application permission.

- **MgDisconnectWhenDone (Boolean):** Specifies whether to disconnect from the Graph API when the script finishes. Recommended. If you do not disconnect, Microsoft Graph PowerShell automatically refreshes the access token for you and sign-in persists across PowerShell sessions because Microsoft Graph PowerShell securely caches the token.
- **MgClientID (String):** This is where you would enter the [registered application ID value](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-tenant-and-app-id-values-for-signing-in).
- **MgTenantID (String):** This is where you would enter the [registered tenant ID value](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-tenant-and-app-id-values-for-signing-in).
- **MgApp_AuthenticationType (String):** How the registered application authenticates to Microsoft Graph. Authentication options include:
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

JSON file that lets you exclude specific meetings from syncing. Each property name is a SIS meeting field, and its array of values are matched against that field — any meeting matching a value is skipped. Values are matched as **case-insensitive literal substrings** (no wildcards or regular expressions), so a value of "Homeroom" excludes every meeting whose field contains "Homeroom" anywhere in it.

- **course_title (Array of Strings):** Course titles to exclude. The *course* is the subject that a section belongs to (e.g. "Algebra I"). This is the level above the group/section described below and what the script uses as the event's Outlook category. Excluding a course title therefore excludes every section of that course.
- **group_name (Array of Strings):** Group names to exclude. A meeting's *group* is the individual section, advisory, activity or team it belongs to, and its name is what the script uses as the calendar event subject (e.g. "Algebra I - 03", "Homeroom"). The SIS calls this a group rather than a section because the same field covers all of the offering types, not just academic sections.

Leave an array empty (`[]`) to exclude nothing for that field.

---

### **config_user_preferences.json**

JSON file containing an array of per-user overrides for event settings. Create an array entry for *each* user you want to customize; any omitted field falls back to the corresponding `EventDefaults` value in `config_general.json`.

Entries are keyed by SIS user ID. Because an ID is not much use to a human reading the file, each entry also takes an optional `Comment` to record a name, email address or other identifying text.

- **UserId (Integer or Numeric String):** Required. The positive whole-number SIS ID of the user these preferences apply to.
- **Comment (String, Optional):** Free text to identify who the entry is for (a name, an email address, or whatever else is useful).
- **ShowAs (String):** Overrides `EventDefaults.ShowAs` for this user. Same accepted values — one of the Graph [`freeBusyStatus`](https://learn.microsoft.com/en-us/graph/api/resources/event#properties) values ("Unknown", "Free", "Tentative", "Busy", "Oof", "WorkingElsewhere").
- **IsReminderOn (Boolean):** Overrides `EventDefaults.IsReminderOn` for this user.
- **ReminderMinutesBeforeStart (Integer):** Overrides `EventDefaults.ReminderMinutesBeforeStart` for this user.

---

## How the Script Isolates Its Own Events (Extended Properties)

The script is designed to **only ever read, update, or delete the calendar events it created itself.** Events a user added manually, events created by other apps, and any event that does not carry the script's tag are invisible to the script and are never modified or removed. This is achieved with a Microsoft Graph [extended property](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview) that acts as a private "fingerprint" on every event the script creates.

**1. Tagging on create.** When the script creates an event, it attaches a [single-value extended property](https://learn.microsoft.com/en-us/graph/api/resources/singlevaluelegacyextendedproperty) built from the three `EventsAppIdentifier` settings in `config_general.json`:

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

Get-MgUserEvent -UserId $EntraUser.Id -All -Filter $Filter -Property $MGEventProperties
```

**3. The consequence.** Because the calendar is only ever read back through this filter, the "create missing events", "update preferences", and "remove extra events" passes can act on *nothing but* the script's own tagged events within the sync date window. Nothing else on the user's calendar is ever seen or changed.

**Important notes:**

- Give each deployment its **own unique `EventsAppIdentifier.GUID` and `EventsAppIdentifier.Value`**. Two instances that share a tag would treat each other's events as their own (and could remove them). A separate test run should use its own tag values.
- **Changing the `EventsAppIdentifier` values after events already exist will orphan the previously created events** — the script will no longer recognize them, so it will neither update nor remove them (and may create duplicates alongside them).
- Extended properties are used (rather than schema extensions) specifically because they can be reliably filtered on the `event` object, which schema extensions cannot.

Related Microsoft Graph documentation:

- [Extended properties overview](https://learn.microsoft.com/en-us/graph/api/resources/extended-properties-overview)
- [Get singleValueLegacyExtendedProperty](https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get)
- [singleValueLegacyExtendedProperty resource type](https://learn.microsoft.com/en-us/graph/api/resources/singlevaluelegacyextendedproperty)
- [outlookCategory resource type](https://learn.microsoft.com/en-us/graph/api/resources/outlookcategory) (used for the per-course color categories)
- [dateTimeTimeZone resource type](https://learn.microsoft.com/en-us/graph/api/resources/datetimetimezone) (used for event start/end times)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

---

## Deletion Safety

Keeping calendars accurate means removing events for meetings that are no longer in the SIS. The flip side is that anything which quietly shrinks the SIS result (a typo in a configuration file, a partially returned schedule, etc.) looks exactly like "these meetings were cancelled" and would clear events that should have stayed. The script therefore checks the shape of the data before it removes anything:

- **Configured offering types must exist.** A `Meetings.OfferingTypes` value that doesn't match an SIS offering type stops the run, instead of silently narrowing the meetings pulled. An empty list, or one holding a blank or `null` entry, is refused for the same reason.
- **Blank ignore values are refused.** An empty string in `config_meetings_to_ignore.json` would match every meeting and empty the sync. Blank values are skipped with a warning.
- **An empty result stops the run.** If no meetings remain after the ignore and current-term filters, the script stops before touching a single calendar. Override with `DeleteSafety.AllowEmptySourceSync` when an empty sync is genuinely expected. That override also waives the per-user limit below for the run, since deliberately clearing every synced event is exactly what it asks for.
- **Large per-user removals are held back (along with that user's creations).** If more than `DeleteSafety.MaxDeletePercentPerUser` of one user's synced events would be removed at once (and at least `DeleteSafety.MinDeletesBeforeCheck` removals are queued), the removals *and* the creations for that user are held back and reported. Every other user still syncs normally, and preference updates still apply to the held-back user.

A held-back run is reported as a warning, counted in the run summary as `DeleteGuardTrips`, recorded in the sync history with a `DeleteGuardTripped` status, and makes the script exit with code `2`. Once you have confirmed the SIS data is correct, re-run the script (or raise the limit: `100` allows even a complete clear of a user's synced events) to let the changes through.

---

## Exit Codes

Every run that gets past startup ends with a summary line of what it did (users processed, skipped, and failed; events created, updated, and removed; deletion guard trips). The summary is always written to the console, and to the log as well when logging is enabled. A run that fails during startup itself (a missing configuration file, a prerequisite module that isn't installed, etc.) exits with code `1` and the error (before there is a summary to write).

Below are the exit codes that might be set so a scheduled task can act on the outcome:

| Code | Meaning |
| --- | --- |
| `0` | Success. This includes a run that had nothing to do (e.g. no school terms in range, which might be normal over the summer). |
| `1` | Failed. The run stopped early (a missing prerequisite module, a configuration problem, or an unhandled error). No further users were processed. |
| `2` | Completed, but needs attention. The run finished, but at least one configured user was skipped (e.g., their email address wasn't found in Entra), failed part way through, or had their changes held back by the [deletion safety](#deletion-safety) limits. |
| `3` | Already running. Another copy of the script still held the single-instance lock, so this run stopped without making any changes. The lock is per deployment (it is named after `EventsAppIdentifier.GUID`), so separate deployments on the same computer don't block each other. |

---

## Setup & Usage

1. Copy all five files from the `Config Templates` folder into the `Config` folder:
    - `config_general.json`
    - `config_sky_api.json`
    - `config_scriptmessage.json`
    - `config_meetings_to_ignore.json`
    - `config_user_preferences.json`
2. Edit each copied file and replace the placeholder values with your own, using the documentation above.
3. Install the [prerequisite modules](#prerequisites).
4. Run the script (`Sync Schedules to Exchange Calendar.ps1`).
   - On the first run you will be prompted to authorize the SKY API connection; the tokens are then cached at `TokensFilePath` for subsequent runs. This is a one-time step unless the refresh token expires ([currently 365 days since the last refresh](https://developer.blackbaud.com/skyapi/docs/authorization#token-expiration)). As long as your application connects to the SKY API at least once within the window, you can access the SKY API data indefinitely or until you disconnect the application.
5. Optionally, schedule the script to run automatically (e.g., using Windows Task Scheduler). Microsoft Graph authenticates as the registered application without a signed-in user, so unattended runs just need the scheduled task to run as the same account that performed the initial SKY API authorization so it can access the cached tokens.
