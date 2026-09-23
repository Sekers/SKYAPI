# SKY API error-response behavior

Notes on what the SKY API returns when a request fails, and what that does and does not tell you about the
cause.

**Every claim below is labelled with its evidence.** Read the label before relying on a statement.

- **Measured** means observed against a live tenant, with the tenant and date given.
- **Author-confirmed** means the module's author has seen it in the wild across endpoints over time, without a
  payload captured here. Weaker than a recorded measurement, stronger than an inference.
- **From source** means read out of `SKYAPI/SKYAPI.psm1`; it describes what this module does, which is not
  the same as what the API does.
- **Unverified** means nobody has tested it. Several things that look like established API behavior are in
  this category.

> **Do not classify a SKY API failure by its status code, or assume a shape for its body.** On at least one
> endpoint a missing role is reported as a 500 (§1), and the error body arrives in several mutually
> incompatible JSON shapes depending on the endpoint (§2). The status code is unusable as proof of a cause,
> and any code reading an error body has to handle every shape or fall back.

## 1. Measured: `Connect-SchoolUserBBID` returned 500 for a missing role

Production tenant, 2026-08-10.
[`PATCH /afe-edcor/v1/users/bbid/connect`](https://developer.sky.blackbaud.com/api#api=afe-edcor&operation=V1UsersBbidConnectPatch)
failed with **HTTP 500 Internal Server Error**. The endpoint is satisfied by **either** Admissions Manager or
Platform Manager, and the Blackbaud account that authorized the token held **neither**. Granting it
Admissions Manager made the same call succeed, with no change to the request.

| Aspect | Observed |
| --- | --- |
| Request | Identical body, user ID and email across every attempt |
| Before | Account held neither qualifying role. 500 Internal Server Error, every attempt |
| After | Account granted Admissions Manager (one of the two suffices). Success |
| Evidence type | Before and after on one changed variable, n=1 |

The endpoint's own comment-based help states it requires at least one of Platform Manager or Admissions
Manager, so the role requirement is documented. Being told about it as a 500 is what cost the diagnosis time.

### What this does **not** establish

All of the following are **unverified**. Do not infer them from §1:

- That any other endpoint reports a missing role as 500. Only this one was tested.
- That other `afe-edcor` endpoints behave like this one.
- That **Platform Manager** alone would have resolved it. The account was granted Admissions Manager, so only
  that role was shown to satisfy the endpoint. The help says either role suffices, but that is documentation,
  not a measurement.
- That a data-level permission failure (a record the user may not see) behaves like a role-level one.
- That SKY API ever returns a correct 403, or what Blackbaud's documentation promises for either code. The
  developer portal renders through JavaScript and could not be fetched to check, so this file makes no claim
  about what the docs say.
- Any mechanism for *why* the 500 occurs. Nothing here observed the server's internals.

There is also a **confounder specific to this endpoint** that was never ruled out. Its help states that an
account already connected to a BBID will reconnect if the submitted email differs from the connected one, so an
earlier successful attempt may change what a later attempt is actually doing. Whether that alters the result is
untested; when comparing a working run against a failing one here, assume the record's state may have moved.

## 2. Author-confirmed: the error body has no single shape

**The API is wildly inconsistent about how it reports an error**, and this is the single most important thing
in this file after §1. The body's JSON shape varies with both the endpoint and the kind of failure, so the same
logical error can come back looking entirely different from one call to the next.
`SKYAPICatchInvokeErrors` therefore reads a failure's code or message from any of these locations, in this
order, before dispatching on it:

| Checked in order | The test in `SKYAPICatchInvokeErrors` | Status |
| --- | --- | --- |
| `statusCode` | `elseif ($InvokeErrorMessage.statusCode)` | Confirmed observed |
| `ErrorCode` | `elseif ($InvokeErrorMessage.ErrorCode)` | Confirmed observed |
| `error`, else `error.statuscode` | `elseif ($InvokeErrorMessage.error)` | **Guessed**, never observed; see below |
| `errors`, else `errors.error_code` | `elseif ($InvokeErrorMessage.errors)` | Confirmed observed |
| `message` | `elseif ($InvokeErrorMessage.message)` | Confirmed observed (prose, no code) |
| `status`, if it is a plausible HTTP code | `elseif ($null -ne $InvokeErrorMessage.status ...)` | Confirmed observed; added in 0.5.1, see §8 |
| the raw parsed body, if none of the above matched | the trailing `else` | Catch-all |

The `$FallbackStatusCode` test short-circuits ahead of all of these: if the body was missing or unparseable,
the status code from
`Get-SKYAPIErrorStatusCode` is used and the body is never consulted.

**How this list came to exist.** It was not designed up front. The author added each branch after hitting the
response in real testing, and extended it over time as more endpoints and more kinds of failure turned up new
shapes (confirmed 2026-08-10). Every branch except one is therefore a record of something actually returned by
the API, not defensive padding, which makes `SKYAPICatchInvokeErrors` the closest thing this repo has to a
catalogue of SKY API error formats.

The one exception is the `error` branch, which was written speculatively while fixing an unrelated
bug and carries the comment
`# TODO: I'm not sure if this is correct (guessed when correcting bug). Look for examples of this format.`
Leave that TODO in place until a real payload turns up.

Two consequences follow. First, the list is a floor, not a ceiling: it covers the shapes seen so far, and new
endpoints have repeatedly produced new ones. Second, **when you hit a shape that is not handled, the fix is two
edits, not one**: add the branch, and record the payload here. What is missing from this file is not the
observation but the **captured payloads**; no example body is written down for any shape, so the detail
currently survives only in the author's memory and in the branch list.

The same provenance covers the non-numeric cases. Beyond numeric codes (400, 401, 403, 404, 415, 429, 500, 502,
503, 504) the switch matches bare strings, each one likewise added after it was seen: `invalid_client`,
`invalid_grant`, `An exception occurred. Please contact Support.`, `no healthy upstream`, and a regex for
`The HTTP status code of the response was not expected (500)`. A failure can therefore arrive as prose with no
status code anywhere in it.

**What the shape varies with.** Both the **endpoint** and the **type of error**, per the author. So neither
"this endpoint returns shape X" nor "this class of failure returns shape X" is safe on its own; the pairing
matters, and the mapping has never been written down.

When the body is missing or will not parse, `Get-SKYAPIErrorStatusCode` falls back to
`.Exception.Response.StatusCode`, read duck-typed because the exception type differs by PowerShell edition. A
failure with no response at all is rethrown, since there is nothing to dispatch on.

### Measured: four captured payloads, and a fourth shape the list above does not name

Development environment, 2026-09-08, four deliberate failures in one run. **These are captured bodies**, which
is what the rest of §2 says is missing, so they are labelled Measured rather than Author-confirmed.

**`errors[]`**, from a 403 on `school/v1/academics/{id}/assignments` and from a 400 on a nonexistent user.
Matches the `errors`/`errors.error_code` branch:

```json
{ "errors": [ { "error_code": 400, "error_name": "Bad Request",
                "raw_message": "{Message:no user found with the requested user_id.}" } ] }
```

**`application/problem+json`**, from a 404 on an unknown path and from the 429 in §7. Matches the `statusCode`
branch:

```json
{ "statusCode": 404, "message": "Resource not found", "status": 404, "title": "Resource not found" }
```

**A validation shape none of the branches name**, from `school/v1/users/audit?start_date=notadate`:

```json
{ "type": "urn:blackbaud:model-validation-error",
  "title": "One or more validation errors occurred.", "status": 400,
  "detail": "The value 'notadate' is not valid.",
  "instance": "urn:blackbaud:afe-proxy:start_date", "values": { "start_date": "notadate" },
  "trace_id": "86ac11ebd919418fbfe41a6873f399d5", "span_id": "d250a0ca47951c9b" }
```

It carries `status`, not `statusCode`, and has no `message`, `error`, `errors` or `ErrorCode`. Until 0.5.1 no
branch looked at `status`, so it reached the catch-all and was thrown. For this 400 that was accidentally
right; for the **500** the same family returns from `afe-edcor` it was wrong, and it is the bug §8 describes.
A `status` branch now classifies the whole family.

**Two things worth knowing regardless of shape:**

- **A nonexistent user is a `400`, not a `404`.** `school/v1/users/999999999` answers
  `"no user found with the requested user_id"` with status 400, while an unknown *path* answers 404. So a 400
  from this API does not reliably mean "your request was malformed".
- **`trace_id` and `span_id` live in the body, and only in this one shape.** No failure observed carried a
  correlation id in its *headers*: the 403 and both 400s returned only `Cache-Control`,
  `X-Content-Type-Options`, `Strict-Transport-Security`, `Date`, `Content-Length` and `Content-Type`; the 404
  and the 429 returned even fewer. So when opening a support case, the id to quote is in the body if the
  failure is a validation error, and otherwise there is nothing to quote but a timestamp.

## 3. From source: a failure that is retried costs about five minutes

Every request helper (`Get-SKYAPIUnpagedEntity`, `Get-SKYAPIPagedEntity`, `Remove-SKYAPIEntity`,
`Submit-SKYAPIEntity`, `Update-SKYAPIEntity`) sets `MaxInvokeCount = 7`. The 500, 502, 503 and 504 branches, and
three of the string cases (`An exception occurred. Please contact Support.`, the regex 500, and
`no healthy upstream`), sleep via `Get-ExponentialBackoffDelay -InitialDelay 5`, which computes
`5 * 2^(InvokeCount - 1)`:

| Attempt | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sleep after failure (s) | 5 | 10 | 20 | 40 | 80 | 160 | throws |

Total sleep: **315 seconds**, plus seven round trips. By contrast 400, 403, 404 and 415 throw immediately; 429
sleeps for whatever its `Retry-After` header asks, falling back to one second when the header is absent or
unusable and capped at 300 seconds so a server controlled value cannot park a script; 401 refreshes the token
and retries without sleeping; and `invalid_client` and `invalid_grant` retry without sleeping.

**What elapsed time tells you.** A call that fails after roughly five minutes failed seven consecutive times,
each time in a way the module classified as retryable. So the condition is reproducible rather than a one-off.
It does **not** tell you the seven responses were identical, nor what the failure was. Whether a genuinely
transient SKY API fault typically clears inside this window is **unverified**; no outage has been measured
against it.

## 4. Measured: where the response body actually is

Both editions, against a live non-2xx response carrying a 135-character body (2026-08-10):

| Access path | Windows PowerShell 5.1 | PowerShell 7 |
| --- | --- | --- |
| `$_.ErrorDetails.Message` | full body | full body |
| `$_.Exception.Response` type | `HttpWebResponse` | `HttpResponseMessage` |
| `.GetResponseStream()` re-read | returns 0 chars, already drained | method does not exist |

Also measured: `throw $ErrorRecord` preserves `ErrorDetails`, so the body survives the module's rethrow into a
caller's `catch`.

**Use `ErrorDetails.Message`, and nothing else.** The `GetResponseStream()` pattern common in older SKY API
examples is dead code in both editions. An empty `ErrorDetails` means the response carried no body; it is not
hiding elsewhere. A caller logging only `$_.Exception.Message` records just the status text and discards
whatever the API said.

## 5. Measured: a `school/v1` endpoint returned 403 for a missing role

Development environment, 2026-09-08, during a `Tests/TestDateTime_WireFormatSurvey.ps1` run.

`Get-SchoolAssignmentByStudent` returned `403 (Forbidden)` while the other 45 endpoints in the same run
succeeded or returned empty. That endpoint documents the **Student** or **Parent** role as its requirement,
which the API user does not hold; the rest of the run needs administrative roles, which it does.

This is the counterpart to §1 and partly answers a question that section left open. A missing role produced a
`500` on `Connect-SchoolUserBBID` (`afe-edcor`) and a `403` here (`school/v1`), so the status code for a
missing role is **not consistent across APIs**. §1's wider point stands: a status code alone proves nothing
about the cause.

It is not consistent **within** `school/v1` either, and this endpoint is the unusual one. §9 samples eight
more endpoints from an account holding only the Student role: the six that enforce all answer `401`, not
`403`. So `403` here is the exception, `401` is the usual reply to a missing role, and two of the eight do
not enforce their documented role at all.

**It is role level, not data level** (measured the same day, by asking for a student that does not exist).
A refusal tied to the record would have to look the record up first, so a nonexistent id would come back
`404` or similar; a refusal tied to the route is decided before any lookup, so the id cannot matter.

| Request | Status | Body length |
| --- | --- | --- |
| assignments for a real student | 403 | 279 |
| assignments for student `999999999`, which does not exist | 403 | 279 |
| control: `users/999999999`, an endpoint the caller may use | 400, "no user found with the requested user_id" | 126 |

Identical responses for a real and an imaginary student, while an endpoint the caller *is* entitled to use
answers the imaginary id on its merits. The body says so outright: `"Returned when the user does not have
permission to the route."` **Route, not record.**

**Confirmed from the other direction**, 2026-09-08, against the production tenant, read only. Authenticating
as a test account whose only role is **Student** and calling the same endpoint for that account's own id
returned **200**, not 403. `Get-SchoolUserMe` on that account lists exactly one role, so the account really is
role limited rather than broadly privileged.

| Caller | Endpoint | Result |
| --- | --- | --- |
| administrative roles, no Student or Parent | `academics/{id}/assignments` | 403 |
| Student role only, own id | `academics/{id}/assignments` | 200, zero assignments in the window |

Zero rows is not a failure here; the account simply had no assignments in the thirty days queried. What
matters is that the request was answered rather than refused.

**The confound, which stops this being a clean single-variable test.** The two rows are different tenants and
therefore different app registrations as well as different roles, so strictly the experiment changed more than
one thing. It is still the strongest evidence available without granting an administrative account the Student
role, and it agrees with both of the other observations: the refusal happens before any record lookup, and the
body names the route rather than the record. Treat "missing Student or Parent role" as the cause, and the
cross-tenant comparison as supporting rather than proving it.

**A control that turned out to be a finding.** `Get-SchoolRole` was called from the Student account expecting
a refusal, and it **succeeded**. The published operation for
[`GET /school/v1/roles`](https://developer.sky.blackbaud.com/api#api=school&operation=v1rolesget) states it
requires SKY API Data Sync or any Manager role, and this account holds neither: its only persona is Student,
with the All School role. **So a documented role requirement went unenforced.**

That is worth more than the control was: enforcement is inconsistent *within* `school/v1`, not merely between
`school/v1` and `afe-edcor`. One endpoint in the same API refuses a caller lacking its documented role with a
403, and another admits a caller lacking its documented role. Neither the documentation nor an observation of
one endpoint predicts the next. It also means "the docs say this needs a role" is not evidence that a call
will fail, and a call succeeding is not evidence the caller holds the role.

That leaves data-level refusals still unmeasured; nothing here shows what one looks like, only that this is
not one. One endpoint on one tenant is also still not a rule for `school/v1` generally.

**It is not a module defect**, which is worth writing down because the survey reports it as `ERROR`. The URL
the function builds matches the documented operation, and the same 403 was recorded on an earlier run in
`DateTime-Handling.md` before any of the 0.5.1 changes.

## 6. Measured: the request rate is capped by SKY API's own response time, not by this module

Development environment, 2026-09-08, PowerShell 7.6.5, from one workstation. Absolute numbers will differ
elsewhere, but the split between network and server time is the part that matters and is unlikely to.

SKY API throttles at roughly 10 calls per second. A single-threaded client issues one request at a time, so
its ceiling is `1000 / round-trip milliseconds` requests per second. Measured here, 15 calls each to
`/school/v1/users/{id}` after a warm-up call:

| Path | Avg | Min | Max | Ceiling |
| --- | --- | --- | --- | --- |
| `Invoke-WebRequest` directly, module bypassed | 417 ms | 226 ms | 794 ms | 2.4/s |
| `Get-SchoolUser` through the module | 558 ms | 298 ms | 1405 ms | 1.8/s |

The first row is the one that matters: **even with the module removed entirely, this machine tops out around
2.4 requests per second**, well under the throttle. The module adds about 140 ms per request (a configuration
file read, a token file read and decrypt, JSON parsing and date repair), which lowers the ceiling further but
is not what puts it out of reach.

**The latency is server side, not network side, and not payload size.** Same machine and date, decomposed:
a TCP connect to `api.sky.blackbaud.com:443` averaged 46 ms and the local gateway 0 ms, so roughly 370 ms of
that 417 ms is Blackbaud's own processing. Ten calls each to seven endpoints, raw, with the module bypassed:

| Endpoint | Avg | Min | Response bytes | Ceiling |
| --- | --- | --- | --- | --- |
| `offeringtypes` | 264 ms | 127 ms | 487 | 3.8/s |
| `venues/buildings` | 295 ms | 233 ms | 13719 | 3.4/s |
| `roles` | 336 ms | 220 ms | 9008 | 3.0/s |
| `users/{id}` | 363 ms | 234 ms | 707 | 2.8/s |
| `years` | 388 ms | 200 ms | 5206 | 2.6/s |
| `levels` | 398 ms | 213 ms | 909 | 2.5/s |
| `gradelevels` | 553 ms | 300 ms | 3437 | 1.8/s |

Response size does not predict the time: the 13.7 KB endpoint is faster than the 909 byte one. So there is no
"cheap endpoint" that a sequential loop could hammer fast enough, and a faster local link cannot buy back
370 ms of server time. **Tripping the throttle from one machine needs concurrent requests, which this module
never issues.** §7 does exactly that and confirms the limit is real and near 10 per second.

So a report that this test tripped rate limiting on another occasion is **not** explained by a faster link:
with 370 ms of server time, even a zero latency network leaves a sequential ceiling near 2.7 requests per
second. Something else has to account for it, and the candidates worth checking are concurrent use of the
same subscription key, a period when the API was materially faster, or a throttle that counts a short burst
rather than a sustained rate. The minimums above, 127 ms to 300 ms, are two to three times better than the
averages, so a lucky burst runs well ahead of the steady state.

Worth keeping in mind when a 429 does appear: the throttle applies to the subscription key, so anything else
using the same key at the same time counts toward it. A 429 does not prove that the script observing it was
itself going fast.

Two bounded runs of the loop in `Tests/TestAPICallErrors_RateLimit.ps1` on this machine, neither tripping it:

| Workload | Requests | Elapsed | Rate | 429 retries |
| --- | --- | --- | --- | --- |
| `Get-SchoolUserExtendedByBaseRole`, 485 records per call | 8 | 75 s | 0.1/s | 0 |
| `Get-SchoolUser` with 40 IDs, back to back | 200 | 83 s | 2.4/s | 0 |

The paged row is slow for a second reason worth separating out: the development tenant returns 485 users for
those roles against a page limit of 1000, so the whole call is a single request. On a tenant large enough to
page, that loop issues its pages back to back and gets much closer.

The module's 429 HANDLING is covered offline regardless, by
`Tests/TestAPICallErrors_ErrorClassification.ps1`, which asserts that a 429 retries whether it arrives as
JSON, as HTML, or with no body at all. What only the live script can show is what the API itself sends.

Retries were counted by shadowing `Start-Sleep` inside the module scope, because the 429 branch sleeps
without emitting anything a caller could observe.

## 7. Measured: what a real 429 looks like

Development environment, 2026-09-08, by `Tests/TestAPICallErrors_RateLimit.ps1`. Confirmed identically on
Windows PowerShell 5.1 and PowerShell 7.6.5. **This is a captured payload, not a reconstruction.**

Twelve concurrent raw requests to `school/v1/offeringtypes` reached about 23 requests per second and tripped
the limit inside one second, on the second batch: 12 responses came back `200` and the next 12 came back
`429`. That also pins the limit itself at roughly 10 per second, which had only been documented from
Blackbaud's own pages before.

```text
HTTP/1.1 429
Retry-After: 1
Content-Type: application/problem+json
Content-Length: 149
Date: Tue, 08 Sep 2026 17:11:27 GMT

{"statusCode":429,"message":"Rate limit is exceeded. Try again in 1 seconds.","status":429,"title":"Rate limit is exceeded. Try again in 1 seconds."}
```

Four things in that are worth keeping:

- **`Retry-After: 1` is present**, and the module now reads it, falling back to one second only when the
  header is absent or unusable. That fallback is where the original hardcoded value went. Until 0.5.1 the
  module always slept one second and would not have noticed the API asking for longer; the two happened to
  agree, so nothing a caller could write was affected. See `Get-SKYAPIRetryAfterDelay`.
- **`Content-Type: application/problem+json`** is RFC 7807. That explains the doubled body in §2: `status`
  and `title` are the RFC's fields, and `statusCode` and `message` are Blackbaud's own, carrying the same
  text twice. This is one of the shapes §2 describes, now with a real payload attached.
- **No correlation or request id header**, which answers one of the questions §8 used to ask. There is
  nothing here to quote to Blackbaud support beyond the timestamp.
- **The header set differs by edition unless you look in two places.** On PowerShell 7 `Content-Type` and
  `Content-Length` sit on `.Content.Headers`, a separate collection from `.Headers`, while Windows PowerShell
  5.1 exposes one `WebHeaderCollection` holding all of them. A reader that only enumerates `.Headers` on 7
  silently reports fewer headers than 5.1 for the same response.

A `WebHeaderCollection` also enumerates as header **names**, not as key/value pairs, so code written for the
7 shape appears to work against 5.1 and yields a list of empty `": "` entries. That failure looks exactly
like a response that carried no `Retry-After`, which is why the test discriminates on the type rather than
trying one shape and falling back.

## 8. Measured: which endpoint and error type produce which body shape

Development environment, 2026-09-08, fifteen deliberate GET failures in one run, administrative roles.
This is the endpoint-to-shape mapping §2 says is unrecorded. It is a sample, not a census.

| Request | Status | Body shape | Correlation id |
| --- | --- | --- | --- |
| `afe-edcor/v1/lists` | 200 | | |
| `afe-edcor/v1/lists/jobs` | 200 | | |
| `afe-edcor/v1/lists/jobs/999999999` | **500** | `urn:blackbaud:unexpected` | body `trace_id` |
| `afe-edcor/v1/attachments?type=Application` | **500** | `urn:blackbaud:unexpected` | body `trace_id` |
| `school/v1/notarealendpoint` | 404 | `statusCode` | none |
| `school/v1/users/999999999` | **400** | `errors[]` | none |
| `school/v1/users/abc` | 404 | not JSON | none |
| `school/v1/users/audit?start_date=notadate` | 400 | `urn:blackbaud:model-validation-error` | body `trace_id` |
| `school/v1/users/audit` without `role_id` | 404 | `statusCode` | none |
| `school/v1/academics/rosters?school_year=NOPE` | **200** | | |
| `school/v1/academics/sections?level_num=abc` | 400 | `errors[]` | none |
| `school/v1/academics/{id}/assignments` (§5) | 403 | `errors[]` | none |
| `school/v1/lists/advanced/999999999` | **200** | | |
| `school/v9/users/999999999` | 404 | `statusCode` | none |

Four things in that are worth carrying away:

- **Two endpoints answer an invalid request with `200`.** A school year that does not exist and a list id
  that does not exist both return success. Combined with `users/999999999` returning **400** rather than 404,
  the status code tells you even less than §1 already warned: a bad identifier can produce 200, 400 or 404
  depending only on which endpoint you asked.
- **`afe-edcor` returns 500 for things that are not server faults.** A nonexistent job id and a plain
  `attachments` query both produced 500. That is the same behavior §1 recorded for a missing role on the
  PATCH, and it now looks like a property of that API rather than of that one operation. Whether these two
  are permission failures in disguise is unmeasured; the body says only "An error has occurred."
- **`urn:blackbaud:*` is one shape family with several `type` values.** `model-validation-error` for a
  validation failure and `unexpected` for a server fault, sharing `type`, `title`, `status`, `trace_id` and
  `span_id`. Treat the family by its `status` field, not by its `type`.
- **Only that family carries a correlation id, and only in the body.** No response in this run put one in a
  header. So `trace_id` is available for exactly the failures that use problem+json, and for everything else
  there is still nothing to quote to support but a timestamp.

### The bug this survey found

The `urn:blackbaud:*` family puts its code in **`status`**, not `statusCode`, and until 0.5.1 no branch in
`SKYAPICatchInvokeErrors` looked at `status`. Such a body therefore reached the catch-all, matched no case in
the switch, and was thrown.

For the `400` validation shape that was accidentally correct, since a 400 should not be retried. For the
**500** shape it was wrong: a transient server fault that the module should have retried seven times with
backoff failed on the first attempt instead. Confirmed by replaying the captured payload against the 0.5.0
module, which throws. A `status` branch was added, guarded on the value being a plausible HTTP code so an
unrelated field named `status` cannot be mistaken for one, and placed last so no shape that already
classified moves. `Tests/TestAPICallErrors_ErrorClassification.ps1` pins it with both captured payloads.

This is the answer to two questions this file used to ask: whether the shape ever arrives with a retryable
status (it does, as a 500 from `afe-edcor`), and whether a 500 carries `trace_id` (it does, in the body).

## 9. Measured: what a caller holding only the Student role sees

Production tenant, 2026-09-08, read only, every request a GET. The account's sole role is Student. Twenty
requests in one pass. This exists because a second account with a genuinely different role set answers
several questions that no amount of testing from an administrative account can.

### Role enforcement is inconsistent, and when it happens it is a 401

| Endpoint | Documented requirement | Result for a Student |
| --- | --- | --- |
| `roles` | SKY API Data Sync or any Manager | **200**, 110 rows |
| `years` | (documented as restricted) | **200**, 37 rows |
| `users/extended` | Platform Manager | 401 |
| `users/audit` | Platform Manager | 401 |
| `lists` | several manager roles | 401 |
| `admissions/candidates` | administrative | 401 |
| `users/customfields` | administrative | 401 |
| `venues/buildings` | administrative | 401 |

Two things fall out, and the second one costs real time:

- **Two endpoints admit a caller who does not hold their documented role**, so the documentation does not
  predict enforcement. §5 already showed the reverse case, an endpoint that does enforce. Neither the docs nor
  an observation of one endpoint tells you about the next.
- **When an endpoint does enforce, it answers `401`, not `403`.** That matters to this module more than it
  looks. `401` is the "your token expired" branch: `SKYAPICatchInvokeErrors` calls
  `Connect-SKYAPI -ForceRefresh` and retries, up to `MaxInvokeCount`. A permission failure can never be fixed
  by a fresh token, so the whole budget is spent on a certainty. Measured with the helper stubbed: **7 API
  requests and 6 forced token refreshes**, about thirteen round trips, before the error finally surfaces.
  The outcome is correct, the cost is not. A caller sees a slow failure rather than an immediate one.

`Get-SchoolAssignmentByStudent` is the odd one out in returning `403` (§5), which is why §5 read as a clean
role-level refusal. On this evidence `403` is the exception and `401` is the usual reply to a missing role.

### A 401 is ambiguous by status, but not by body

The retry cost above exists because the module dispatches on the status code alone, and `401` covers at least
three unrelated conditions. The bodies are not ambiguous at all. Development tenant and production tenant,
2026-09-08:

| Condition | Top-level properties | Where the code is | Message |
| --- | --- | --- | --- |
| garbage token | `statusCode`, `message`, `status`, `title` | `statusCode` | `The required Authorization header was missing or invalid, or the token has expired` |
| truncated token | same | `statusCode` | identical to the above |
| no `Authorization` header at all | same | `statusCode` | identical to the above |
| valid token, bad subscription key | same | `statusCode` | `Access denied due to invalid subscription key. Make sure to provide a valid key for an active subscription.` |
| valid token, caller lacks the role | **`errors` only** | `errors[0].error_code` | `You do not have access to this route.` |

Both captured directly, not inferred. The permission body in full, identical across four endpoints and
173 bytes each time:

```json
{ "errors": [ { "message": "You do not have access to this route.",
                "error_code": 401, "error_name": "ServiceClientException",
                "raw_message": "You do not have access to this route." } ] }
```

**The two are separated by which property carries the code**, which is stronger than separating them by
message text. A token or subscription problem arrives in the gateway's `statusCode` form; a permission
refusal arrives in the backend's `errors[]` form and has no top-level `statusCode`, `status` or `message` at
all. The three token cases are indistinguishable from each other, but they share one remedy, so that does not
matter.

Note what this means for the module: `SKYAPICatchInvokeErrors` **already** tells these apart, because they
take different branches of its chain, and until 0.5.1 threw that knowledge away by reducing both to the
integer 401 before the switch. The information needed to avoid the wasted retries was already in hand at the
point the decision was made.

**This is now acted on.** The branch that supplied the code is recorded, and the 401 handler uses it: a code
that came from `errors[]` is a permission refusal and throws on the first attempt, while anything else is
assumed to be the token and gets **one** refresh, never more. Measured cost per condition, both editions:

| Condition | Before | After |
| --- | --- | --- |
| caller lacks the role | 7 requests, 6 refreshes | **1 request, 0 refreshes** |
| expired or malformed token | 7 requests, 6 refreshes | 2 requests, 1 refresh |
| wrong subscription key | 7 requests, 6 refreshes | 2 requests, 1 refresh |
| 401 in any unfamiliar shape | 7 requests, 6 refreshes | 2 requests, 1 refresh |

The single refresh is the cap rather than a retry budget because a second refresh has no mechanism by which
it could succeed where the first failed: it mints the same credential from the same refresh token against the
same clock. The cases where retrying further might have mattered, such as the wrong subscription key, are
precisely the ones no refresh can fix. The subscription-key row is why the cap earns its place even though
the body already identifies the permission case: that failure wears the token shape and is equally hopeless,
and the cap bounds it without anyone having to parse a message string.

So a `401` that a forced refresh cannot fix is **recognisable before the refresh is attempted**, which makes
the seven requests and six refreshes avoidable rather than inherent. Nothing has been changed on the strength
of this: it is one tenant pair on one day, and narrowing the 401 retry is a behavioural change that deserves
its own decision. Recorded so that decision can be made from evidence.

The subscription-key case is worth separating out for a different reason: no amount of token refreshing fixes
it either, and unlike the permission case it means the module is misconfigured rather than under-privileged.

### A data-level refusal looks exactly like a route-level one

The Student may call `academics/{id}/assignments` for their own id. Asking the same endpoint for someone
else's:

| Request | Result |
| --- | --- |
| `academics/{own id}/assignments` | 200, zero rows |
| `academics/1/assignments` | **403**, `errors[]` |

Same caller, same route, different record, and the refusal is a `403` carrying the same `errors[]` shape as
the route-level refusal in §5. **The two are indistinguishable from outside**, so a 403 tells you a request
was refused and nothing about which of the two reasons applied.

One caveat: user `1` may simply not exist, in which case this is "a record you cannot see or that is not
there" rather than strictly a permission decision. A classmate's id would have separated those, but the
account could not enumerate one; `Get-SchoolSectionByStudent` for its own id was itself refused.

### The `afe-edcor` 500s are not permission failures

The two 500s in §8 return identically for the Student and for the administrative account, byte for byte
apart from the `trace_id`. Whatever `afe-edcor` is unhappy about when asked for a nonexistent job id or for
attachments, it is not the caller's role. §1's missing-role 500 on the PATCH remains a separate observation.

### `200` on invalid input is not consistent, and one more shape turned up

`sections?level_num=abc` answers `400`, while §8 recorded `rosters?school_year=NOPE` and
`lists/advanced/999999999` answering `200` for an administrative caller. So the earlier finding holds: an
invalid value may be rejected or silently ignored, per endpoint.

`lists/advanced/999999999` produced something not seen before, a **JSON string rather than an object**:

```text
"One or more errors occurred. (The HTTP status code of the response was not expected (401).
Status: 401
Response:
{\"Message\":\"You do not have access to this route.\"})"
```

Sent with HTTP **500**, wrapping an inner **401**. It has no properties for any branch to read, so it reaches
the catch-all, matches no case in the switch, and throws. Throwing is right here, since the underlying
condition is a permission failure that will not clear, but note the module has a regex case for the same
sentence ending `(500)` and this one ends `(401)`, so the resemblance is close enough to be worth knowing.

Validation also runs **before** authorization on at least one endpoint: `users/audit` answers `401` for a
Student with a valid date, and `400` for the same Student with a malformed one.

### Still no sighting of `ErrorCode` or `error`

Roughly forty deliberate failures across two APIs, two tenants and two role sets have produced neither shape.
The `error` branch's own TODO calling itself a guess still stands.

## 10. Diagnosing a failing call

Method, not API behavior:

1. **Log `$_.ErrorDetails.Message`**, per §4.
2. **Capture the response headers** into the log as well. What SKY API puts in them has not been recorded here,
   so capture them rather than looking for a specific one, and include them if you open a support case.
3. **Bypass the retry loop while iterating**, so a failure costs a second instead of five minutes. Call the
   endpoint once with `Invoke-WebRequest`, using the exported `Get-SKYAPIAuthTokensFromFile` and
   `Get-SKYAPIConfig` for the token and subscription key, and the two headers the helpers send
   (`Authorization: Bearer ...` and `bb-api-subscription-key`).
4. **Compare identity and environment across machines.** The call runs as whoever authorized the token on that
   machine, so a scheduled job on a server is often a different Blackbaud account than an interactive test.
   `Get-SKYAPIContext` reports `user_id`, `email`, `environment_id` and `environment_name`. This is what §1
   turned out to be.
5. **Change one variable at a time.** A failing server run and a working workstation run usually differ in
   several ways at once (machine, identity, argument values, record state). Re-run the failing arguments on the
   working machine before investigating either.

## 11. Open questions worth measuring

Each would turn something currently unrecorded or unverified in this file into a checkable fact.

- Whether a data-level refusal can be told apart from a route-level one at all. §9 shows both answering `403`
  with the same body shape, but its data-level case used a user id that may not exist. A classmate's id would
  settle it, and needs an account that can enumerate one.
- A real payload for the `ErrorCode` branch and for the speculative `error` branch. Around forty deliberate
  failures across two APIs, two tenants and two role sets have produced neither, so the `error` branch remains
  a guess, as its own TODO says. At some point "never observed" becomes reason to delete it.
- Whether a `401` in the `errors[]` shape is ever worth retrying after all. 0.5.1 stopped retrying it on the
  strength of one day's observation across two tenants, and this file otherwise warns against generalizing
  from that much evidence. If some endpoint ever returns that shape for a transient condition, the module
  will now give up on the first attempt where it used to try seven times. Nothing seen so far suggests it
  does, and the one refresh cap limits the damage in the other direction.
- Which `school/v1` endpoints enforce their documented role and which do not. §9 samples eight and finds two
  that do not; the mapping across the rest is unrecorded, so the documentation cannot be trusted either way.
- Whether any endpoint besides `lists/advanced` answers with a JSON **string** rather than an object, and
  whether the inner status it quotes is ever a retryable one. Today's example wraps a `401` in a `500`.
