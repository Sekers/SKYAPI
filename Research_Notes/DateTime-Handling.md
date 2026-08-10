# SKY API date and time handling: measured behavior

Central research notes for this module. Everything below was **measured against a live tenant**, not inferred
from documentation or from how other endpoints behave.

- Tenant: `SKY Developer Cohort` (development)
- School time zone (`Get-SchoolTimeZone`): `Eastern Daylight Time`, `utc_offset -04:00`, `is_daylight_savings_time True`
  (note that this name is not a Windows time zone `Id`; see §3g)
- Client running the tests: `Central Standard Time`
- Dates measured: 2026-07-28 (original survey), 2026-08-03 (fractional-second follow-up, §3f),
  2026-08-06 (time zone name, §3g)
- Primary test record: user `3294459` (Mikey Davis)

> **Do not generalize from one endpoint to another.** The single most important finding here is that the same
> logical value is encoded differently depending on which endpoint returned it. Any new date handling must be
> verified per endpoint with `-ReturnRaw`.

## 1. The headline: the same field, two encodings

The same user's birth date, read on the same day, from two endpoints:

| Endpoint | Field | Raw wire value |
|---|---|---|
| `Get-SchoolUser` | `dob` | `2005-03-17T00:00:00+00:00` |
| `Get-SchoolUserExtended` | `birth_date` | `2005-03-17T00:00:00-05:00` |

One is midnight UTC, the other is midnight in the school's time zone. Both mean 17 March 2005.

## 2. The stored data is correct

The web GUI displays exactly what was written, so this is a client-side parsing problem and not data
corruption. Verified by writing distinctive values and reading them back in the GUI:

| Written | GUI shows | Module returns |
|---|---|---|
| `dob = 2005-03-17` | `3/17/2005` | `2005-03-17` (correct) |
| `in_state.from_date = 2033-11-25` | `11/25/2033` | `2033-11-24` (**wrong**) |

## 3. Wire formats observed, by shape

Survey of 32 endpoints, classifying every `"field":"<ISO-8601>"` value found:

| Shape | Field/endpoint combinations |
|---|---|
| negative offset, midnight | 27 |
| negative offset, with a real time | 9 |
| positive offset, midnight | 8 |
| positive offset, with a real time | 6 |

### 3a. Date-only fields (midnight, school-time-zone offset)

These carry no meaningful time. The offset is the **school's**, and it is DST-aware for the date in question,
so the same field varies across the year (`-05:00` in winter, `-04:00` in summer for an Eastern school).

```
birth_date    2005-03-17T00:00:00-05:00     expire_date   2031-02-23T00:00:00-05:00
enroll_date   2019-08-01T00:00:00-04:00     from_date     2033-11-25T00:00:00-05:00
begin_date    2025-08-01T00:00:00-04:00     issue_date    2024-01-10T00:00:00-05:00
end_date      2026-07-31T00:00:00-04:00     depart_date   2025-12-31T00:00:00-05:00
```

Endpoints: `Get-SchoolUserExtended`, `Get-SchoolYear`, `Get-SchoolTerm`, `Get-SchoolAthleticRoster`,
`Get-SchoolActivityRoster`, `Get-SchoolAdvisoryRoster`, `Get-SchoolRoster`.

### 3b. Empty-date sentinel

An unset date is **not** blank and **not** null. It is:

```
0001-01-01T00:00:00+00:00
```

Seen on `deceased_date`, `depart_date`, `retire_date`, `last_sync_date`, `date_appointed`, and on
`Get-SchoolTerm`'s `begin_date`/`end_date` for some records. Note the offset is `+00:00` here even on
endpoints whose populated values use the school's negative offset.

### 3c. Occupation dates: midnight school-time expressed as UTC

`Get-SchoolUserOccupation` and the `occupations` array inside `Get-SchoolUserExtended` use a third encoding.
The time component is 04:00 or 05:00 with a `+00:00` offset, which is midnight Eastern converted to UTC:

```
begin_date    1923-01-25T05:00:00+00:00     (midnight EST)
end_date      2022-03-15T04:00:00+00:00     (midnight EDT)
```

This matches the long-standing note in `New-SchoolUserOccupation.ps1` and `Get-SchoolUserExtended.ps1` about
occupation dates displaying incorrectly on the website. **Status of that Blackbaud support request is still
unconfirmed**; the encoding is still unusual as of this measurement.

### 3d. True timestamps: leave alone

These carry a real time and must **not** be date-normalized:

```
audit_date          2026-07-28T16:26:54.233-04:00
created_date        2020-02-26T12:38:58.703-05:00
last_modified_date  2026-07-28T16:26:54.233-04:00
modified            2025-08-12T16:03:14.403-04:00
created             2026-02-13T16:44:23.38+00:00      (Get-SchoolListOfLists, UTC)
last_modified       2026-02-13T17:47:28.457+00:00     (Get-SchoolListOfLists, UTC)
```

The existing "DO NOT FIX ... audit_date" comment in `Get-SchoolUserExtended.ps1` is correct.

Note the `.38` on that `created` value: **trailing zeros are stripped**. That detail turns out to matter a
great deal; see §3f.

### 3e. A field name can mean different things in one payload

In `Get-SchoolAthleticRoster`, `enroll_date` appears both as a date-only value
(`2025-08-01T00:00:00-04:00`) and as a real timestamp (`2025-08-24T15:28:50.327-04:00`). Field name alone is
not a safe classifier for this field; the shape has to be inspected. Compare §3f, which shows the converse:
for some fields the shape is not sufficient either, and the name is the only evidence available.

### 3f. A timestamp can lose its fractional second entirely (measured 2026-08-03)

Because trailing zeros are stripped (§3d), a timestamp whose milliseconds are exactly zero is serialized with
**no fractional part at all**, making it indistinguishable in shape from a date-only value. Scanning 245
date/time values across 12 endpoints:

```
created   2007-07-30T10:42:37+00:00      1 of 49 values, no fractional second
created   2026-02-13T16:44:23.38+00:00   the other 48, fraction present
```

This is why classification cannot rest on shape alone. The two shapes below are byte-identical apart from the
date, yet mean different things, and nothing in the value says which is which:

```
birth_date  1980-01-23T00:00:00-05:00    a date
created     2026-01-01T00:00:00-05:00    an instant whose milliseconds happened to be zero
```

Reading that shape as an instant would put every date-only field back a day for clients west of the school,
the original bug in §4. Reading it as a date silently discards a real timestamp. Only the field name resolves
it, which is what `-TimestampFields` is for (§10).

Fields observed carrying a real time but no fractional second: `created`. (`begin_date` and `end_date` also
appear this way, but those are the §3c occupations encoding (school midnight expressed as UTC) and are
date-only despite the non-midnight clock reading.)

### 3g. The school time zone name is not a Windows time zone `Id` (measured 2026-08-06)

Every offset above is described as "the school's time zone", which presumes that zone can be resolved from
what the API reports. It cannot be resolved the obvious way. `Get-SchoolTimeZone` returns a display name, not
an identifier:

```json
{"timezone_name":"Eastern Daylight Time","is_daylight_savings_time":true,"utc_offset":"-04:00:00"}
```

`Eastern Daylight Time` matches no `TimeZoneInfo.Id` and no `StandardName` on Windows. It resolves only as the
**`DaylightName`** of the `Eastern Standard Time` zone. Mapping the value to a `TimeZoneInfo` therefore has to
check `Id`, then `StandardName`, then `DaylightName`; matching on `Id` alone fails outright against this tenant.

**Confirmed on a second, unrelated tenant.** This is the API's behavior, not a quirk of the developer cohort.
Read-only check against a live production tenant, a Central-time school, on the same day:

```json
{"timezone_name":"Central Daylight Time","is_daylight_savings_time":true,"utc_offset":"-05:00:00"}
```

Same shape, same outcome: no `Id` match, no `StandardName` match, resolves only as the `DaylightName` of
`Central Standard Time`. Two of two tenants surveyed report a `DaylightName` rather than an `Id`.

**The ordered three-step lookup in `Get-SchoolScheduleMeeting` was written deliberately for this**, because
the reported name was observed landing on `Get-TimeZone`'s `DaylightName` often enough to matter. The
measurements above are the confirmation, and the order is the right one: `Id` and `StandardName` are exact
identity matches and are tried first, with `DaylightName` last as the loosest.

What did not match that intent was the function's old `ValidateScript` on `-SchoolTimeZoneId`, which accepted
`Id`s only. Explicitly passing the exact value this API reports was rejected at parameter binding, while the
automatic default kept working because PowerShell does not run validation attributes on default values. That
attribute has been removed; the three-step lookup, which now throws when all three miss, is the single
validator for both the explicit and default paths.

Because `is_daylight_savings_time` is reported alongside it, the name is very likely the **current DST state**
rather than a stable zone identity. If so, an Eastern school reports `Eastern Standard Time` in winter, which
*is* a valid `Id` and matches at the first step, meaning which step succeeds varies by season and `Id`-only
matching would pass testing for half the year. Not yet measured across a DST boundary; see §9.

### 3h. schedules/meetings sends a PER-DAY offset, wrong for part of every DST transition day (measured 2026-08-06)

The clearest defect found so far, and a clean reproduction for a support request. `Get-SchoolScheduleMeeting`'s
underlying endpoint sends the **correct school-local wall-clock time with an offset that contradicts it**.

The offset is applied **per day, not per instant**. On the two days a year when the correct offset changes at
02:00 local, one value is stamped on every meeting that day. Measured on the dev tenant (Eastern school), all
offering types, reading raw with `-ReturnRaw`:

```
2026-11-01  fall-back day      every meeting: -04:00     correct only BEFORE 02:00
2027-03-14  spring-forward day every meeting: -04:00     correct only AFTER  02:00
```

Per-meeting detail for the fall-back day, showing the offset does not vary with the time it is attached to:

```
local 00:01  offset -04:00  x5     correct   (EDT, before the change)
local 08:30  offset -04:00  x3     WRONG     (should be -05:00)
local 11:50  offset -04:00  x5     WRONG
local 23:00  offset -04:00  x3     WRONG
distinct offsets that day: -04:00
```

On ordinary days the offset is right, DST-aware for the date (`-04:00` in summer, `-05:00` in winter, verified
across 7 sample dates). It fails only where an offset genuinely has to change mid-day, which is exactly where
it matters.

**Consequence for a naive consumer.** Parsing `start_time` directly is an hour off for most of a transition day:

```
API sent                   2026-11-01T08:30:00-04:00
DateTimeOffset.Parse ->    2026-11-01T12:30:00Z
actual instant             2026-11-01T13:30:00Z        error: 1 hour
```

**This module is immune**, because the re-anchoring in §5 discards the offset and re-derives it from
`meeting_date` in the school zone. A full-year scan of 16,000 meetings had 0 failing to round-trip back to
their own `meeting_date`, including all 19 meetings on the fall-back day.

**It is also the root cause of the one edge case that cannot be fixed locally.** A wall-clock time in the
repeated 01:00-02:00 hour maps to two real instants, and only the offset distinguishes them:

```
2026-11-01T01:30:00-04:00  ->  05:30Z
2026-11-01T01:30:00-05:00  ->  06:30Z
```

Because the offset cannot be trusted on precisely that day, the reading has to be chosen by convention. A
correct per-instant offset would make this case, and the spring-forward invalid-hour case, disappear entirely.
No meeting currently falls in that window on this tenant (the earliest activities start 00:01), so the
exposure is real but unrealized.

**How the module now resolves both**, in `ConvertTo-SKYAPIUtcFromSchoolLocal` (`SKYAPI.psm1`), rather than
throwing or accepting a silent default:

| Case | `TimeZoneInfo.ConvertTimeToUtc` alone | What the module does |
|---|---|---|
| Spring forward, reading never happened | **throws**, failing the whole request over one record | shifts forward by the amount the clock jumped, so 02:30 becomes 03:30 |
| Fall back, reading happened twice | silently picks **standard** time, the later instant | picks **daylight**, the earlier instant, matching the offset the API reports for that day |

The jump is read from the zone (`GetUtcOffset` across the day) rather than assumed to be an hour, so a
30-minute-delta zone such as Lord Howe Island works. Neither choice is provably correct, since the payload
does not contain the information; they are documented conventions chosen to fail softly and to stay
consistent with the API's own belief about that day. Verified identical on Windows PowerShell 5.1 and
PowerShell 7.x. Tests: `Tests/TestDateTime_SchoolLocalToUtc.ps1` (53 offline cases, both editions).

Note also that `meeting_date` arrives as `2026-11-01T00:00:00+00:00`, a date-only value stamped UTC. That is a
third encoding in one payload, matching neither §3a nor the `start_time` convention above.

Related but **not** the same defect as `show_time_for_current_date` (§3i): that flag stamps *today's* offset,
whereas the defect above is per-day and appears even with the flag absent.

### 3i. `show_time_for_current_date` stamps today's offset on the meeting's wall clock (measured 2026-08-06)

The endpoint accepts a `show_time_for_current_date` query parameter, documented as: *"Set to true to calculate
the start_time and end_time of meetings based on the current day instead of the meeting day. Defaults to
false."*

`Get-SchoolScheduleMeeting` has never supported it, on the grounds that it "just completely gives incorrect
time zone information" (recorded 2025-02-19, commit `57e6c93`). That claim is now measured and **confirmed**.

Read-only comparison, all three states, on a day when the school was in EDT (`utc_offset -04:00`):

```
=== 2027-01-15  (winter, school is EST) ===
  omitted   2027-01-15T08:30:00-05:00     correct
  false     2027-01-15T08:30:00-05:00     correct
  true      2027-01-15T08:30:00-04:00     wall clock unchanged, TODAY'S offset stamped on

=== 2026-09-15  (summer, matches today's offset) ===
  omitted / false / true    all 2026-09-15T08:00:00-04:00      no difference

=== 2026-11-01  (fall-back day, already reports -04:00 per §3h) ===
  omitted / false / true    all 2026-11-01T08:30:00-04:00      no difference
```

**The mechanism**: the flag does not recalculate the time at all. It preserves the meeting's wall clock and
replaces the offset with whatever DST state is in effect *today*. That is why only the out-of-season date
differs; the other two already share today's offset. The result is seasonal, so re-running this in January
would show the discrepancy on the *summer* date instead.

**Consequence.** A January class genuinely at 08:30 EST is labeled `08:30-04:00`:

```
reported with true    2027-01-15T08:30:00-04:00  ->  12:30Z
actual instant                                       13:30Z      error: 1 hour
```

**Why the parameter stays unsupported.** Two reasons, and the second is the decisive one:

1. It provides strictly less correct information than the default, so it cannot help with any of the DST
   handling in §3h.
2. It would change **nothing** in this module's output. The normalization keeps the wall clock and discards
   the offset (§5), and the wall clock is byte-identical under `true` and `false`. Exposing the parameter
   would therefore alter no normalized result while handing `-ReturnRaw` callers a field that looks
   authoritative and is wrong out of season.

## 4. Why values come back on the wrong day

`ConvertFrom-Json` deserializes an offset-bearing string into a local `[datetime]`, discarding the written
wall-clock value. Midnight in the school's zone becomes the previous day for any client west of the school:

```
raw      2031-02-23T00:00:00-05:00
client   Central (-06:00 in February)
parsed   2031-02-22 23:00   (Kind=Local)
```

A client *in* the school's zone sees nothing wrong, which is likely why this went unnoticed. A client east of
the school (for example in Europe) also sees nothing wrong, because midnight Eastern is mid-morning there on
the same day.

## 5. The three existing workarounds

| Approach | Where | Method | Assessment |
|---|---|---|---|
| `Repair-SkyApiDate` | `Get-SchoolUser`, `Get-SchoolUserExtended`, `Get-EnrollmentCandidate` | `$Date.ToUniversalTime().Date` | Works for every offset observed here, but is wrong for a school at a **positive** offset: midnight at `+10:00` is the previous day in UTC. |
| String split | `Get-SchoolYear` | avoids deserialization, splits on `T` | Most robust. Takes the written date, so the offset never matters. Returns a string. |
| Re-anchoring | `Get-SchoolScheduleMeeting` | treats time-of-day as school-local, re-anchors to the date in the school zone, throws if the format changes | Best engineered. Handles both offset signs and fails loudly if Blackbaud changes the format. |

`Repair-SkyApiDate` is idempotent on values it has already fixed (they come back `Kind=Utc` at midnight),
which makes it safe to apply more than once.

The re-anchoring approach is not merely the tidiest of the three, it is **required**: §3h shows the offset it
discards is genuinely wrong for most of every DST transition day, so any approach that trusted that offset
would return those meetings an hour off.

**Update: `Repair-SkyApiDate` no longer exists.** It was superseded by the §10 helpers and has since been
removed from the module, so the row above is a record of what was measured rather than a description of live
code. The other two survive: the string split in `Get-SchoolYear`, and the re-anchoring in
`Get-SchoolScheduleMeeting`. Note the consequence for consumers, since it is easy to miss: date-only fields
used to come back `Kind=Utc` from those three functions and now come back `Kind=Unspecified`, which is the
honest encoding for a calendar date but changes what `.ToLocalTime()`, `.ToUniversalTime()` and the two-argument
`TimeZoneInfo.ConvertTimeBySystemTimeZoneId` do with them. `Unspecified` is also the only Kind that
`TimeZoneInfo.ConvertTimeToUtc(value, schoolZone)` accepts with an arbitrary source zone, so anchoring a
date-only value in the school's zone is now expressible and previously threw.

## 6. Coverage gaps found (all fixed 2026-07-28, see section 10)

| Function | Top-level date fields | Nested / array date fields |
|---|---|---|
| `Get-SchoolUser` | repaired | n/a |
| `Get-SchoolUserExtended` | repaired | **`visa.*`, `passport.*`, `in_state.*` not repaired** |
| `Get-SchoolUserExtendedByBaseRole` | **nothing repaired** | nothing repaired |
| `Get-SchoolAthleticRoster` | **not repaired** | n/a |
| `Get-SchoolActivityRoster` | **not repaired** | n/a |
| `Get-SchoolAdvisoryRoster` | **not repaired** | n/a |
| `Get-SchoolRoster` | **not repaired** | n/a |
| `Get-SchoolTerm` | **not repaired** | n/a |

Confirmed for `Get-SchoolUserExtendedByBaseRole` on 3 of 3 sampled users. Example, user 1574462:

```
raw                              1969-12-22T00:00:00-05:00
Get-SchoolUserExtended           1969-12-22   (Kind=Utc, correct)
Get-SchoolUserExtendedByBaseRole 1969-12-21   (Kind=Local, wrong)
```

Anyone running a bulk sync from west of the school gets every birthday a day early.

## 7. Recommended direction

Take the calendar date **as written**, the way `Get-SchoolYear` already does, rather than converting an
instant. That is correct regardless of offset sign, so it also fixes positive-offset (non-US) schools, which
`.ToUniversalTime().Date` does not.

The obstacle is that `ConvertFrom-Json` discards the offset before any module code sees the value. The module
already has `ConvertFrom-JsonWithoutDateTimeDeserialization` for exactly this, used by `Get-SchoolYear` and
`Get-SchoolScheduleMeeting`.

Classification is primarily by **shape**: midnight plus an offset means date-only; a real time component means
a timestamp to leave alone; `0001-01-01` means unset. Field name alone is not safe, because one name can carry
both kinds in a single payload (§3e).

**Shape alone is not sufficient either**, which §3f established after this section was first written. A
timestamp with exactly zero milliseconds arrives with no fractional part and is byte-identical to a date-only
value. The final rule is therefore ordered: an explicitly named field first (`-DateOnlyFields` /
`-TimestampFields`), then a fractional second, then the clock reading. Naming stays reserved for fields proven
to be *always* one kind, which is why `enroll_date` is named in neither list.

## 8. Status of the bugs recorded in module comments

All retested against the dev tenant on 2026-07-28.

| Recorded in | Claim | Status |
|---|---|---|
| `Get-SchoolYear.ps1` | "the time zone provided is wrong (it doesn't match the Blackbaud School time zone)" | **Appears FIXED.** 6 of 6 sampled values carried the school's own offset, DST-correct for their date (`-04:00` for a September date). |
| `New-SchoolUserOccupation.ps1` | occupation dates display incorrectly on the website | **Wire encoding NOT fixed.** Still school midnight expressed as UTC (`05:00`/`04:00`), unique among the endpoints surveyed. Website rendering was not retested; that is the part the support request covers. |
| `Get-SchoolCycleBySection.ps1` | the offering/group type filter does not filter | **NOT fixed.** `group_type` 1, 2, 3, 4, 9 and 13 each returned the identical single cycle for an academic free period, as did passing nothing. Values that should exclude it (4 Dorms, 9 Athletics) still returned it. Caveat: the test section had one cycle, so this proves it does not exclude, not that it does nothing at all. |
| `Get-SchoolUserAuditByRole.ps1` | `end_date` does not default to `start_date + 7 days` | **NOT fixed.** Omitting `end_date` with a `start_date` a year back returns `400 "end_date can be no later than 1 year after start_date"`, so the API defaults it to more than a year out and then rejects its own default. The same call with an explicit `end_date` succeeded (13 records). |
| `Get-SchoolScheduleMeeting.ps1` | `show_time_for_current_date` returns incorrect time zone information | **CONFIRMED** (measured 2026-08-06, §3i). The flag keeps the meeting's wall clock and stamps *today's* UTC offset on it, so an out-of-season meeting is reported an hour off. The parameter stays unsupported, and §3i records why exposing it would change nothing anyway. Note this is a separate defect from the per-day offset in §3h, which occurs with the flag absent. |

## 9. Open questions

- Does a **positive-offset school** actually receive positive offsets on date-only fields? Not testable on this
  tenant. The `Get-SchoolScheduleMeeting` changelog fix implies non-US schools do hit this. The normalization
  implemented here is offset-sign independent either way.
- Do endpoints not surveyed here use yet another encoding? Verify with `-ReturnRaw` before assuming.
- What rule produces the per-day offset in §3h? Both transition days observed came back `-04:00` (daylight),
  but two samples do not determine the rule, and it does not match "offset at midnight" (2027-03-14 is EST at
  midnight yet reported `-04:00`). Sampling a southern-hemisphere or positive-offset tenant would help. This
  matters only for predicting the defect, not for handling it: the offset is discarded either way.
- Does any tenant actually schedule a meeting in the repeated 01:00-02:00 hour of a fall-back day (§3h)? The
  module now resolves this by convention (it takes the daylight, earlier instant), but the payload still does
  not say which was meant, so a real occurrence would be the only way to check the convention against
  intent. None exist on this tenant.
- Does `timezone_name` change with daylight saving (§3g)? Both tenants surveyed reported a `DaylightName` in
  August with `is_daylight_savings_time true`. If they report `Eastern Standard Time` / `Central Standard Time`
  in January, the value matches a `TimeZoneInfo.Id` for part of the year and only a `DaylightName` for the
  rest, so `Id`-only matching would pass testing in winter and fail in summer. Re-running `Get-SchoolTimeZone`
  after the next DST transition settles it, and it is the cheapest open question here to close.
- Does the occupations encoding still render wrong in the web GUI? Writing a known date and checking the
  website would settle the remaining half of that support request.
- Are there always-instant fields beyond the audit metadata now named in `-TimestampFields`? The §3f scan
  covered 12 endpoints; a field that is always a timestamp, on an endpoint not scanned, would still be
  flattened if it arrived at exact midnight with zero milliseconds. Re-running §11 over more endpoints and
  looking for values with a real time but no fractional second is the way to find them.

## 10. What was implemented (2026-07-28, extended 2026-08-03)

Four private helpers in `SKYAPI.psm1`. The first two normalize date-only values across the module; the last
two serve `Get-SchoolScheduleMeeting`'s re-anchoring only.

- `ConvertTo-SKYAPIDateTimeValue` converts one wire value, classifying by shape: midnight (any offset) or an
  explicitly named date-only field becomes the written calendar date at midnight; `0001-01-01` becomes
  `[datetime]::MinValue`; anything with a real time keeps its instant; non-date values pass through.
  A **fractional second overrides the midnight test**: `2026-01-01T00:00:00.123Z` is a timestamp, not a date.
  No date-only value in the survey above carries a fractional component and almost every real timestamp does
  (§3d). Presence is the test, not a non-zero value.

  **Shape is not sufficient on its own, and a later measurement proved it.** The API strips trailing zeros, so
  a timestamp whose milliseconds are exactly zero loses its fractional part completely. Measured on the dev
  tenant, 1 of 49 `created` values came back as `2007-07-30T10:42:37+00:00` with no fraction at all. Such a
  value landing on midnight would be byte-identical to a date-only field and flattened. The classification is
  therefore, in order: the field name (`-DateOnlyFields` / `-TimestampFields`), then a fractional second, then
  the clock reading. `-DateOnlyFields` wins a conflict, since a field in both lists is a caller error and
  date-only is the safer reading.

  `-TimestampFields` defaults to the audit metadata that is always an instant: `audit_date`, `created_date`,
  `last_modified_date`, `modified`, `created`, `last_modified`, `modified_date`. Only *midnight* values of
  those fields change behavior, so applying the list everywhere is safe. `enroll_date` is deliberately
  excluded: per §3e it arrives both ways inside a single payload, so its name proves nothing.
- `Repair-SKYAPIResponseDateTime` walks a response (including nested objects and arrays) and applies it.
  `-DateOnlyFields` names the occupations-style fields that shape alone cannot classify (§3c).
  `-TimestampFields` is its mirror, for the §3f case, and defaults to the always-instant audit metadata, so
  every existing call site gets it without passing anything.
- `ConvertTo-SKYAPIUtcFromSchoolLocal` converts one School-local wall-clock reading to UTC for
  `Get-SchoolScheduleMeeting`'s re-anchoring. It exists because a wall-clock reading is not always a single
  instant, and `[System.TimeZoneInfo]::ConvertTimeToUtc` on its own either throws or silently decides. On the
  spring-forward gap it shifts forward by the amount the clock jumped, read from the zone rather than assumed
  to be an hour; on the fall-back repeated hour it takes the daylight (earlier) instant. Both conventions and
  their rationale are in the §3h table. For every reading that is not in one of those two windows it returns
  exactly what `ConvertTimeToUtc` returns, which the tests assert case by case.
- `Get-SKYAPIDaylightJump` reports how far a zone's clock moves on a spring-forward day, which is also the
  width of the gap of readings that never happened. Read from the zone rather than assumed to be an hour, so
  a 30-minute-delta zone such as Lord Howe Island works. It exists because two callers need the same number:
  `ConvertTo-SKYAPIUtcFromSchoolLocal` moves a single invalid reading past the gap, and
  `Get-SchoolScheduleMeeting` moves a whole meeting when only its start fell in the gap. Keeping it in one
  place stops those two drifting apart, which is exactly how a meeting once came back with its start after
  its end.

Affected read functions now parse via `ConvertFrom-JsonWithoutDateTimeDeserialization` first, so the written
value is still available, then normalize. `Get-SKYAPIPagedEntity` does the same for all six paged functions,
which is why it fetches with `Invoke-WebRequest` rather than `Invoke-RestMethod`.

Two invariants that were deliberately preserved:

- **`-ReturnRaw` output is never modified.** Verified: it still returns the raw JSON string with the API's
  original offsets intact.
- **Real timestamps keep their time.** They are recognized by shape where the shape is conclusive, and by name
  where it is not (§3f), so `audit_date`, `created_date`, `last_modified_date`, `modified`, `created` and
  `last_modified` are unaffected including at exact midnight.

`ConvertFrom-JsonWithoutDateTimeDeserialization` also gained a Windows PowerShell 5.1 short-circuit: 5.1
already leaves these values as strings, so the regex-rewrite fallback was wasted work there.

Both editions now return `[DateTime]` for the same fields with the same values, which was not previously
true; unrepaired fields used to come back as `[String]` on 5.1 and `[DateTime]` on 7.

Tests, both offline and both run under Windows PowerShell 5.1 and PowerShell 7.x:

- `Tests/TestDateTime_Normalization.ps1` (56 cases, including positive-offset schools, the occupations
  encoding, timestamp preservation, fractional-second handling, the §3f named-field case, and idempotency).
  The §3f regression pairs a zero-millisecond `created` with a `birth_date` of identical shape in one object
  and asserts they resolve differently, which is the pairing that makes a blanket shape rule impossible.
- `Tests/TestDateTime_SchoolLocalToUtc.ps1` (53 cases, covering `ConvertTo-SKYAPIUtcFromSchoolLocal`). It
  asserts the helper matches `ConvertTimeToUtc` exactly for every ordinary reading, so the common path is
  provably untouched, then pins both DST conventions, proves the built-in would have thrown on the invalid
  reading and chosen the later instant on the ambiguous one, covers a southern-hemisphere zone and a
  30-minute-delta zone, and round-trips every result back to a valid reading.

## 11. How to re-run this survey

`Tests/TestDateTime_WireFormatSurvey.ps1` re-runs the measurement against whatever tenant is configured and
prints the same tables. Re-run it after any Blackbaud change, or when adding an endpoint that returns dates.
