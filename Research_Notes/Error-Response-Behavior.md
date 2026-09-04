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

| Checked in order | Line | Status |
| --- | --- | --- |
| `statusCode` | 631 | Confirmed observed |
| `ErrorCode` | 635 | Confirmed observed |
| `error`, else `error.statuscode` | 639 | **Guessed**, never observed; see below |
| `errors`, else `errors.error_code` | 643 | Confirmed observed |
| `message` | 646 | Confirmed observed (prose, no code) |
| the raw parsed body, if none of the above matched | 652 | Catch-all |

Line 626 short-circuits ahead of all of these: if the body was missing or unparseable, the status code from
`Get-SKYAPIErrorStatusCode` is used and the body is never consulted.

**How this list came to exist.** It was not designed up front. The author added each branch after hitting the
response in real testing, and extended it over time as more endpoints and more kinds of failure turned up new
shapes (confirmed 2026-08-10). Every branch except one is therefore a record of something actually returned by
the API, not defensive padding, which makes `SKYAPICatchInvokeErrors` the closest thing this repo has to a
catalogue of SKY API error formats.

The one exception is the `error` branch at line 639, which was written speculatively while fixing an unrelated
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
sleeps one second; 401 refreshes the token and retries without sleeping; and `invalid_client` and
`invalid_grant` retry without sleeping.

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

## 5. Diagnosing a failing call

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

## 6. Open questions worth measuring

Each would turn something currently unrecorded or unverified in this file into a checkable fact.

- Does a missing role on a `school/v1` endpoint return 403, or also 500?
- Do other `afe-edcor` endpoints match §1?
- Capture one real payload per confirmed shape in §2 and paste it in. The shapes are confirmed; the bodies are
  not written down anywhere, so the knowledge currently lives only in the author's head and in the branch list.
- Record which endpoint and error type produced each shape. §2 establishes that both axes matter, but the
  mapping itself is unrecorded, so today the only safe assumption is that any shape can appear anywhere.
- What headers does SKY API return on a failure, and do they carry a correlation or request ID?
- Does a data-level permission failure differ from a role-level one?
