# Inactive section and course filtering

Notes on the SKY API change of 2026-08-31, which added an inactive filter to the roster endpoints and to
academic courses, and on what the affected endpoints actually return.

Measured against a live tenant on **2026-09-04**:

- Development: `SKY Developer Cohort`, environment `SKY Developer Cohort Environment 1`.
- Every call was a GET. Nothing here required a write.

**Claims are labelled with their evidence.** Read the label before relying on a statement.

- **Measured** means observed against the tenant above, on the date given.
- **From source** means read out of `SKYAPI/SKYAPI.psm1` or a function file. It describes what this module
  does, which is not the same as what the API does.
- **From schema** means read from the developer portal's APIM backend on 2026-09-04. That is *documented*
  behavior, not observed behavior, and §4 shows three places where the two disagree.
- **Unverified** means nobody has tested it.

> **The roster endpoints changed their default; academic courses did not.** Rosters now omit inactive sections
> unless `include_inactive=true` is sent, so every already-released version of this module has been returning
> incomplete rosters since the change. Courses still include inactive courses by default and gained an opt-in
> `exclude_inactive` instead, so course responses are unchanged for callers who ignore it.

## 1. From schema: the parameters that were added

| Endpoint | Parameter | Type | Default |
| --- | --- | --- | --- |
| `/v1/academics/rosters` | `include_inactive` | boolean | `false` |
| `/v1/activities/rosters` | `include_inactive` | boolean | `false` |
| `/v1/advisories/rosters` | `include_inactive` | boolean | `false` |
| `/v1/athletics/rosters` | `include_inactive` | boolean | `false` |
| `/v1/communitygroups/rosters` | `include_inactive` | boolean | `false` |
| `/v1/academics/courses` | `exclude_inactive` | boolean | `false` |
| `/v1/academics/courserequests` | `include_recommendations` | boolean | `false` |

`/v1/dorms/rosters` did **not** get the parameter. The module has no function for community group rosters,
dorm rosters or course requests, so only the first four rosters and courses are reachable from here.

## 2. Measured: the filter changes what comes back, but only where inactive data exists

Sweeping all 32 school years on the development tenant, comparing each roster function's default result
against the same call with `-include_inactive $true`, counting distinct `section.id` values:

| School year | Endpoint | Default | With `include_inactive` | Hidden by default |
| --- | --- | --- | --- | --- |
| 2005-2006 | `Get-SchoolAcademicRoster` | 115 | 171 | 56 |
| 2006-2007 | `Get-SchoolAcademicRoster` | 98 | 184 | 86 |
| 2007-2008 | `Get-SchoolAcademicRoster` | 165 | 189 | 24 |
| 2008-2009 | `Get-SchoolAcademicRoster` | 158 | 182 | 24 |
| 2009-2010 | `Get-SchoolAcademicRoster` | 212 | 250 | 38 |
| 2010-2011 | `Get-SchoolAcademicRoster` | 263 | 324 | 61 |
| 2011-2012 | `Get-SchoolAcademicRoster` | 287 | 344 | 57 |
| 2012-2013 | `Get-SchoolAcademicRoster` | 207 | 245 | 38 |
| 2013-2014 | `Get-SchoolAcademicRoster` | 191 | 214 | 23 |
| 2014-2015 | `Get-SchoolAcademicRoster` | 190 | 204 | 14 |
| 2015-2016 | `Get-SchoolAcademicRoster` | 218 | 222 | 4 |
| 2024-2025 | `Get-SchoolAcademicRoster` | 408 | 410 | 2 |
| 2006-2007 | `Get-SchoolAthleticRoster` | 3 | 4 | 1 |
| 2007-2008 | `Get-SchoolAthleticRoster` | 1 | 3 | 2 |
| 2008-2009 | `Get-SchoolAthleticRoster` | 2 | 4 | 2 |
| 2009-2010 | `Get-SchoolAthleticRoster` | 5 | 7 | 2 |

Every hidden section carried `section.offering.status` of `Inactive`, so the filter keys off the offering's
status rather than anything section-specific.

`Get-SchoolActivityRoster` and `Get-SchoolAdvisoryRoster` returned identical counts in every year. **That is
absence of evidence, not evidence of absence**: this tenant has no inactive activity or advisory sections, so
the parameter could not be exercised there. Do not read those rows as the parameter being ignored.

The current year, 2026-2027, also shows no difference. An endpoint can therefore look completely unaffected on
a tenant that simply has not deactivated anything yet, which is how this change can go unnoticed until an
older year is queried.

## 3. Measured: the meetings endpoint still returns meetings for inactive sections

This is the part that broke `Get-SchoolScheduleMeeting -IncludeRosters`.

`/v1/schedules/meetings` has no active/inactive filter, its description never mentions section status, and its
`Meeting` model carries no status field, so the schema cannot answer the question. Asking it directly for the
inactive section IDs found in §2 does:

| School year | Inactive sections queried | Meetings returned | Inactive sections having meetings |
| --- | --- | --- | --- |
| 2024-2025 | 2 | 183 | 2 |
| 2015-2016 | 4 | 149 | 1 |
| 2009-2010 (athletics) | 2 | 3 | 1 |
| 2008-2009 (athletics) | 2 | 3 | 1 |

So a meeting can be returned for a section whose roster the roster endpoint now withholds. Confirmed against
the exact call `-IncludeRosters` used to make, for the two inactive sections that meet in 2024-2025:

```powershell
Get-SchoolAcademicRoster -school_year $Year -section_ids '1515052,1515053'                     # 0 rosters
Get-SchoolAcademicRoster -school_year $Year -section_ids '1515052,1515053' -include_inactive $true   # 2 rosters
```

`Get-SchoolScheduleMeeting` now passes `-include_inactive $true` on that internal lookup. This widens nothing:
the section IDs are harvested from the meetings already returned, so the only effect is that a meeting which
was returned no longer arrives without its roster.

The years with inactive sections but **zero** meetings (2005-2006 through 2014-2015 academics) are not a
counterexample. Those sections have no schedule at all, so nothing was lost for them either way.

## 4. Measured: the response fields the announcement described do not all match the wire

Blackbaud's announcement, the published schema and the actual response disagree. Field names below are what a
live response carried.

### 4a. Roster offerings

The announcement named the new fields `status`, `attendance_taken` and `publish_to_website`. On the wire,
`section.offering` carries:

```json
{
  "id": 49681,
  "name": "Algebra II",
  "type": { "id": 1, "description": "Academics" },
  "course_code": "4125",
  "length": 2,
  "credits": 1.0,
  "status": "Active",
  "publish_to_website": true,
  "record_attendance": true,
  "school_level": { "id": 453, "name": "Upper School" },
  "school_year": "2026 - 2027"
}
```

The attendance field is **`record_attendance`**, not `attendance_taken`. The schema agrees with the wire here,
so the announcement is the odd one out. `attendance_taken` does exist elsewhere, on the `Meeting` model, where
it means whether attendance was taken for that one meeting.

### 4b. Academic courses

The announcement said courses gain `publish_to_website`, `status` and `notes`. Of those, only
`publish_to_website` actually arrives. Checked across all 205 courses on the tenant:

| Field | Present on |
| --- | --- |
| `publish_to_website` | 205 of 205 |
| `records_attendance` | 205 of 205 (pre-existing) |
| `inactive` | 205 of 205 (pre-existing) |
| `status` | **0 of 205** |
| `notes` | **0 of 205** |

The published schema is wrong in the same direction: it lists `notes` on the `Course` model, which never
arrived, and does not list `status`, which also never arrived. Active and inactive courses alike are
distinguished only by the pre-existing `inactive` boolean. An inactive course reads `inactive=True` with no
`status` property at all.

Note the spelling difference between the two models, which is easy to trip over: a roster offering says
`record_attendance` while a course says `records_attendance`.

### 4c. `exclude_inactive` on courses works as documented

Measured: 205 courses by default, 142 with `-exclude_inactive $true`, so 63 inactive courses are filtered out
on request and returned otherwise.

## 5. Measured: the meetings endpoint cannot filter inactive sections, and neither can its caller

§3 establishes that meetings come back for inactive sections. This section is the other half of that: there is
no cheap way to do anything about it. The question was whether `Get-SchoolScheduleMeeting` could suppress those
meetings without pulling rosters and without extra requests. It cannot.

### 5a. Nothing in the response identifies an inactive section

The `Meeting` model carries 28 fields and not one of them reflects section or offering state:

```text
section_id, section_identifier, course_title, group_name, block_id, block_name, room_id, room_name,
room_number, room_capacity, room_code, faculty_user_id, faculty_name, faculty_firstname, faculty_lastname,
start_time, end_time, meeting_date, attendance_required, attendance_taken, num_absent, attendance_id,
level_number, offering_type, created_date, modified_date, last_modified_user_id, teachers
```

Compared directly on 2025-01-01, a meeting on inactive section 1515053 and one on active section 1514107 are
indistinguishable: same fields, and nothing in the values marks one as inactive. Note that `attendance_taken`
here means attendance was taken for that one meeting, which is unrelated to the offering field of the same
name discussed in §4a.

The endpoint has no filter of its own either. Its only query parameters are `end_date`, `offering_types`,
`section_ids`, `last_modified` and `show_time_for_current_date`.

`/v1/academics/sections` does not help as a shortcut: it returned all 410 sections for 2024-2025 with both
inactive ones present, and it carries `offering_id` but no status.

### 5b. The cost of resolving status is round trips, not bytes

Payload size is not the objection. The heaviest option measured was 207 KB, which is nothing. What costs is
requests, because they come out of a shared rate limit and cannot be cached against anything in the meetings
response.

| Approach | Extra requests | Covers |
| --- | --- | --- |
| Scoped roster call | 1 per offering type, per school year, per section batch | all four offering types |
| Sections by level plus courses | 1 per school level, plus 1 | academics only |
| `/v1/athletics/teams` | 1 | athletics only, no module function |

The roster endpoint is the cheapest general answer, which is counterintuitive given it returns the most data.
The sections plus courses route needs more requests and only works for academics, since `exclude_inactive`
exists only on academics courses. `/v1/athletics/teams` is genuinely tiny (403 bytes for this tenant) and
exposes `status` directly, with the team id being the section id, but it covers one offering type and the
module has no function for it.

Scaling, using this module's own constants: `Get-SchoolScheduleMeeting` iterates meetings in 30 day windows
(`$IterationRangeInDays`) and batches section IDs into an 1800 character `section_ids` value
(`$MaxSectionIdsLength`), roughly 225 seven-digit IDs per batch. So a single-day query for one offering type
goes from one request to two, a doubling. A full school year across all four offering types is about
12 meetings requests plus 4 status requests. A date range spanning two school years adds 8.

### 5c. Read the status; do not infer it from absence

Any filter has to read `section.offering.status` rather than treat "missing from the default roster response"
as inactive. On this tenant **232 of the 410 sections for 2024-2025 have an empty roster while still being
`Active`**, so presence and emptiness are independent of status. `section.offering.status` was populated on
100% of roster records across all four roster types, which makes it a safe thing to key on.

### 5d. No module-side filter was added

Deliberately. The only mechanism available is a second roster call, which is the same call `-IncludeRosters`
already makes, so a switch would have been a thin wrapper over a per-query request cost that the caller is
better off seeing and deciding about. A caller who wants the filter today can do this:

```powershell
# One extra request per offering type per school year. Reads status; never infers it from absence.
$Status = @{}
Get-SchoolAcademicRoster -school_year $Year -section_ids $SectionIdBatch -include_inactive $true |
    ForEach-Object { $Status[[string]$_.section.id] = $_.section.offering.status }
$Meetings | Where-Object { $Status[[string]$_.section_id] -ne 'Inactive' }
```

A section whose status cannot be resolved keeps its meeting, which is the right default: the filter should only
ever remove what it has positive evidence about.

## 6. Feature request sent to Blackbaud

Raised so that a future reader knows the gap was reported rather than missed. Venue:
<https://community.blackbaud.com>. Date sent: TBD. Link to the posted request: TBD.

> **Subject: Add an `include_inactive` parameter to GET /v1/schedules/meetings**
>
> Endpoint: `GET /v1/schedules/meetings`
> Documentation: <https://developer.sky.blackbaud.com/api#api=school&operation=V1SchedulesMeetingsGet>
>
> The 2026-08-31 release added an `include_inactive` parameter to the roster endpoints (academics, activities,
> advisories, athletics and community groups) and changed them to return only active sections by default. The
> meetings endpoint did not get the same treatment. It still returns meetings for sections whose offering
> status is `Inactive`, and it offers no way to filter them out.
>
> The response gives no way to filter them client side either. The `Meeting` model carries no offering or
> section status field, so a caller cannot tell from the response whether a meeting belongs to an inactive
> section. Verified against a developer tenant: a meeting on an inactive section is field for field
> indistinguishable from a meeting on an active section on the same day.
>
> The only workaround is a second request to a roster endpoint for the same sections, reading
> `section.offering.status` and filtering locally. The concern is not payload size, which is trivial. It is
> the number of round trips, and the fact that they cannot be avoided or cached away: nothing in the meetings
> response indicates status, so the lookup has to be repeated on every schedule query.
>
> That lookup costs one extra request per offering type, per school year, per batch of section IDs. A
> single-day query for one offering type goes from one request to two. Pulling a full school year across all
> four offering types is roughly 12 meetings requests plus 4 status requests, and a date range spanning two
> school years adds 8. Those requests come out of the same rate limit and daily quota as the rest of an
> integration, to answer a question the meetings response could answer at no cost.
>
> The request, in order of preference:
>
> 1. Add an `include_inactive` query parameter to `GET /v1/schedules/meetings`, using the same name as the
>    roster endpoints. Please default it to `true` so that current behavior is preserved and this does not
>    become a second breaking change for existing callers.
> 2. Failing that, add the offering `status` field to the `Meeting` model, so callers can filter client side
>    without a second request.
>
> Either option removes the extra round trip. The first also makes the meetings endpoint consistent with the
> roster endpoints it is normally used alongside.

## 7. Unverified

- Whether `include_inactive` behaves the same on `/v1/activities/rosters` and `/v1/advisories/rosters`. It is
  declared on both, but this tenant has no inactive sections of either type (§2).
- `/v1/communitygroups/rosters`, `/v1/dorms/rosters` and `/v1/academics/courserequests` have no module
  function and were not called.
- Whether `status` and `notes` appear on courses for a tenant that populates them, or whether they were
  announced ahead of the deployment. Only their absence here is measured.
- `/v1/athletics/teams` was measured as returning `status` for every team (§5b), but it has never been used as
  a filter, and the assumption that a team id is always the section id a meeting reports comes from the
  `Section` model's own description rather than from a matched pair on the wire.
