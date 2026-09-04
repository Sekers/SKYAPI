# SKY API pagination behavior

Notes on how this module pages through a collection endpoint, what the API offers that the module does not
use, and where the two disagree.

Page sizes were **measured against live tenants** on 2026-08-11:

- Development: `SKY Developer Cohort`, environment `SKY Developer Cohort Environment 1`. Population used for
  the user endpoints: `base_role_ids=14,16,15,17,332,562,565,566,22,23,43,554,563,558,1,2`, 2998 users.
- The production tenant, used only to size the enrollment collections that the development tenant is too small
  to exercise.
- Every call was a GET. Nothing here required a write.

**Claims are labelled with their evidence.** Read the label before relying on a statement.

- **Measured** means observed against one of the tenants above, on the date given.
- **From source** means read out of `SKYAPI/SKYAPI.psm1` or a function file. It describes what this module
  does, which is not the same as what the API does.
- **From schema** means read from the developer portal's APIM backend on 2026-08-11. That is *documented*
  behavior, not observed behavior, and §6 shows a place where the two disagree outright.
- **Unverified** means nobody has tested it.

> **The module detects the end of a result set only by seeing a short page**, comparing the record count
> against a `$PageLimit` each function hardcodes. It never reads `count` or `next_link`, and it never tells the
> API what page size it expects. Five of the six paged endpoints were measured and agree with their
> `$PageLimit`. **`Get-SchoolEnrollment` does not** (§3): its `$PageLimit` is 5000 while the endpoint's
> documented default is 1000, so a school year holding more than 1000 enrollments is silently truncated.

## 1. From source: how paging terminates

Every paged endpoint routes through `Get-SKYAPIPagedEntity` (`SKYAPI/SKYAPI.psm1`, line 932). It requests a
page, appends the records, advances a marker, and loops on a single condition (line 1054):

```powershell
while ($pageRecordCount -eq $page_limit)   # Loop to the next page if the current page is full
```

A full page means "there is probably more"; anything short means "stop". `$page_limit` is the `$PageLimit` the
calling function hardcodes, and `$pageRecordCount` is the number of records the API actually returned. The
test is equality against a value the module chose for itself, not against anything the response reports.

How the next marker is computed depends on the endpoint's paging style (lines 1017 to 1040):

| `MarkerType` | Next page is requested by |
| --- | --- |
| `NEXT_RECORD_NUMBER` | `marker` advanced by `$page_limit` |
| `OFFSET` | `offset` advanced by `$page_limit` |
| `LAST_USER_ID` | `marker` set to `$allRecords[-1].id`, the last record seen |
| `NEXT_PAGE` | `page` incremented by 1 |

`NEXT_RECORD_NUMBER` and `OFFSET` step by `$page_limit`, so a mismatch there would not merely stop the loop
early; it would skip or repeat records if the loop continued.

Records come from `$response_field`, which is `value` on the user endpoints and `results.rows` on
`Get-SchoolList`. Nothing else in the envelope is examined.

This is the technique Blackbaud staff recommended in the community thread in §7, and it is why the `next_link`
regression described there never touched this module. The cost is that correctness rests entirely on
`$PageLimit` matching the server.

## 2. Measured: the real page size of every paged endpoint

Method: request page 1 with no paging parameter and count the records, then advance the marker by hand and
request again, to distinguish "the page size is N" from "the collection only holds N".

| Function | `$PageLimit` | `MarkerType` | Measured page | Verdict |
| --- | --- | --- | --- | --- |
| `Get-SchoolUserExtendedByBaseRole` | 1000 | `LAST_USER_ID` | **1000** | Matches |
| `Get-SchoolUserByRole` | 100 | `NEXT_RECORD_NUMBER` | **100** | Matches |
| `Get-SchoolUserCustomFieldsByBaseRole` | 100 | `LAST_USER_ID` | **100** | Matches, but see §5 |
| `Get-SchoolUserBBIDStatus` | 1000 | `LAST_USER_ID` | **1000** | Matches |
| `Get-SchoolList` | 1000 | `NEXT_PAGE` | **1000** on lists that page | Matches, but see §6 |
| `Get-SchoolEnrollment` | 5000 | `OFFSET` | Documented **1000**, unobservable | **Mismatch, see §3** |

## 3. `Get-SchoolEnrollment` truncates a school year larger than 1000 enrollments

**From schema.** [`V1UsersEnrollmentsGet`](https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersEnrollmentsGet)
takes a page-size parameter named **`limit`**, not `page_size`:

> `limit` : The number of records to return. Defaults to 1000. Maximum is 5000.

**From source.** `Get-SchoolEnrollment` sets `$PageLimit = 5000` and does send `limit`, but **only when the
caller supplied `-ResponseLimit`** (`SKYAPI/Functions/Get-SchoolEnrollment.ps1`, lines 98 to 109):

```powershell
# If not null, add in the limit parameter since this endpoint actually uses it.
if ($ResponseLimit)
{
    if ($ResponseLimit -lt $PageLimit) { $parameters.Add('limit',$ResponseLimit) }
    else                               { $parameters.Add('limit',$PageLimit) }
}
```

There is no `else`. A plain call sends no `limit` at all, so the server applies its own default and the loop in
§1 compares whatever comes back against 5000:

| Call | `limit` sent | Server returns | Loop compares | Outcome |
| --- | --- | --- | --- | --- |
| `Get-SchoolEnrollment -School_Year X` | **none** | 1000 (documented default) | `1000 -eq 5000` is `False` | **Stops after one page. Truncates at 1000.** |
| `-ResponseLimit 500` | 500 | 500 | early return once 500 are held | Correct |
| `-ResponseLimit 20000` | 5000 | 5000 | `5000 -eq 5000` is `True`, pages on | Correct |

So a school year with more than 1000 enrollments returns 1000 records to the default call path, with **no error
and no warning**, and every enrollment past the first 1000 is discarded silently. The counterintuitive
consequence is that passing a large `-ResponseLimit` is *safer* than passing none, because only that branch
tells the server the page size the module is expecting.

This shape is identical in tags `0.4.4` and `0.5.0`, so it is present in the latest release and is not
develop-only churn.

**Measured.** Neither available tenant can demonstrate the truncation directly, because neither has a school
year that large: the development tenant peaks at 340 enrollments (2015-2016) and the production tenant at 509
(2007-2008). Requesting `offset=509` returned 0 records, confirming those collections genuinely end rather
than being capped. So the 1000 default itself remains **unverified**; what was verified is everything the fix
depends on.

`limit` is real and honored exactly, measured against a 509-record year on the production tenant:

| `limit` sent | Records returned |
| --- | --- |
| 1, 10, 100, 500 | 1, 10, 100, 500 |
| 509 | 509 |
| 1000, 5000 | 509 (the whole collection) |
| 5001, 6000, 100000 | 509, accepted without error |

Values above the documented maximum of 5000 were accepted, but with only 509 records available it is
**unverified** whether a larger collection would clamp them or reject them.

`limit` combined with `offset` pages cleanly, with no gaps, repeats, or reordering:

| Check | Result |
| --- | --- |
| Three pages of `limit=100` | 300 records, **0 duplicates** |
| Those 300 against the first 300 of the unpaged response | Identical, in order |
| `limit=100&offset=500` on a 509-record year | 9 records, so the final page comes back short as the loop expects |

The mismatch holds regardless of the exact default: `$PageLimit = 5000` is only correct if the server's default
page size is exactly 5000, and the schema says the default is 1000 with 5000 as the *maximum*. Giving the
`if ($ResponseLimit)` block an `else` that adds `limit = $PageLimit` would make the module's expectation true by
construction on every call path instead of only on one. That change has not been made.

One further note for anyone touching this function: enrollment records carry **`user_id`, not `id`**, so the
`LAST_USER_ID` marker type would not work here even though these are user records. `OFFSET` is correct.

## 4. Measured: the response envelope the module ignores

`count` and `next_link` are **not** present everywhere, and where `count` does appear it reports the number of
records **in that response**, not the size of the whole collection:

| Endpoint | `count` on a full page | `next_link` |
| --- | --- | --- |
| `/v1/users/extended` | 1000 | Present |
| `/v1/users` | 100 | Present |
| `/v1/users/customfields` | 100 | Present |
| `/v1/users/bbidstatus` | 1000 | **Absent** |
| `/v1/users/enrollments` | Equals the records returned | **Absent** |

This matters for anything that reworks the paging loop: `count` cannot be used to compute how many pages to
fetch, and two of the five endpoints do not offer `next_link` at all. As in `DateTime-Handling.md`, do not
generalize from one endpoint to another.

## 5. Measured: `/v1/users/customfields` returns 500 on any page containing user 2208930

Development tenant. This breaks a shipped function, and it is **not** a pagination-logic bug. A single record
crashes the endpoint, and any page window that includes it returns **500 Internal Server Error**,
deterministically.

Markers taken from page 1, each tried three times:

| Marker (page-1 index) | Result |
| --- | --- |
| index 0, 50, 90 through 95 | OK, 100 records |
| index 96, 97, 98, 99 | **500, 3 times out of 3 each** |

The endpoint returns rows in ascending `id` order, and the last window that succeeds ends at id 2208929:

| Request | Result |
| --- | --- |
| `marker=2208929` (next page starts **at** 2208930) | **500** |
| `marker=2208930` (next page starts **after** 2208930) | OK, 100 records |

So user id **2208930** is the poison. Any page containing it fails; every page that skips it succeeds.

What a caller experiences, measured:

| Call | Outcome |
| --- | --- |
| `Get-SchoolUserCustomFieldsByBaseRole -base_role_ids <the 16-role set>` | **Threw after 323 seconds**, after exhausting all 7 retry attempts |
| `Get-SchoolUserCustomFieldsByBaseRole -base_role_ids '14'` | 390 records, no error (that population excludes 2208930) |
| `Get-SchoolUserExtendedByBaseRole` over the identical 2998-user population | 2998 records in 20 seconds |
| `Get-SchoolUserBBIDStatus` over the identical 2998-user population | 2998 records in 4 seconds |

The failure is specific to this endpoint and this record, not to the population or to the module's paging,
since the sibling endpoints walk the same 2998 users without complaint. And a **deterministic** 500 costs a
caller five and a half minutes before it surfaces, because `Get-SKYAPIPagedEntity` retries it seven times. See
`Error-Response-Behavior.md` for the wider point that a SKY API 500 does not mean what a 500 normally means.

## 6. Measured: `/v1/lists/advanced/{list_id}` pages for some lists and not others

Development tenant. Two lists, same endpoint, opposite behavior:

| List | Rows | `page=2` | `page_size=25` |
| --- | --- | --- | --- |
| 28621 | 1000 per page | Different rows, so paging works | 25 rows, so honored |
| 30631 | 4819 in one response | **Identical rows to page 1** | **4819 rows, ignored** |

List 30631 returns its entire 4819 rows in a single response and ignores both documented parameters. This
directly contradicts the schema, which documents `page_size` as defaulting to 1000 with a maximum of 1000. It
is the same lesson recorded in `Write-Field-Behavior.md`: the schema is authoritative for **names and shapes**,
not for values or enforcement.

`Get-SchoolList` is correct on both today, measured: list 30631 returns all 4819 rows in 8 seconds, because
4819 is not equal to `$PageLimit` so the loop stops after one page holding everything; list 28621 pages
normally because its pages really are 1000.

**The latent failure is a list that does not page AND holds exactly 1000 rows.** Page 1 would return 1000,
which equals `$PageLimit`, so the module would request `page=2`, receive the identical 1000 rows, append them,
and loop again, forever, with the record count growing without bound. Both preconditions are demonstrated
above; only their combination has not been observed. Passing `-ResponseLimit` bounds the damage, since that
check returns early (`SKYAPI/SKYAPI.psm1`, line 1043), but nothing bounds the default call.

## 7. Which endpoints expose a page-size parameter at all

**From schema**, across all 177 published `school` operations, only three let the caller state a page size, and
they do not agree on what to call it:

| Operation | Parameter | Documented default |
| --- | --- | --- |
| [`V1UsersExtendedGet`](https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersExtendedGet) | `page_size` | 1000 |
| [`V1ListsAdvancedByList_idGet`](https://developer.sky.blackbaud.com/api#api=school&operation=V1ListsAdvancedByList_idGet) | `page_size` | 1000, maximum 1000 |
| [`V1UsersEnrollmentsGet`](https://developer.sky.blackbaud.com/api#api=school&operation=V1UsersEnrollmentsGet) | **`limit`** | 1000, maximum 5000 |

Searching for `page_size` alone misses the enrollments endpoint, which is exactly how the §3 mismatch went
unnoticed.

`Get-SchoolEnrollment` sends `limit` on one call path only (§3). The other two functions send nothing, and a
caller cannot supply the parameter either: request parameters are built by `Get-SKYAPIRequestParameter`
(`SKYAPI/SKYAPI.psm1`, line 1417) from the calling function's `$PSBoundParameters`, and neither
`Get-SchoolUserExtendedByBaseRole` nor `Get-SchoolList` declares a `page_size` parameter.

## 8. Source: community thread 70158

<https://community.blackbaud.com/discussion/70158>, October 2024. A developer reported that the `next_link`
output of `GET /school/v1/users/extended` had changed with nothing in the change log, breaking their
pagination. Blackbaud staff confirmed it: the `next_link` URL assignment had been corrected, and the marker
value calculation was adjusted because of the then-new `page_size` parameter. Their recommended workaround was
the count-against-page-size check this module already uses. A second fix followed for a text replacement that
had stripped `/school` out of the route definition. Other schools reported production impact, since the
endpoint drives enrollment tracking and account lifecycle work.

None of it affected this module, for the reasons in §1 and §2. The reason to keep the thread on file is the
precedent: **paging behavior on a live endpoint changed with no change-log entry, and could again.** A module
that infers the end of a collection from an assumed page size has no way to notice when that happens, and §2
is the record of what those sizes were the last time anyone looked.
