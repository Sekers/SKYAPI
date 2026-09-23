# Pipeline binding behavior

Notes on how this module's functions bind pipeline input, and on the two ways a value used to cross from one
piped record into the next.

Measured on **2026-09-05** against the working copy, with the HTTP helpers stubbed inside the module scope.
**No tenant was involved and no request left the machine**, so nothing here describes the API; it describes
this module. Both editions were checked: Windows PowerShell 5.1 (5.1.26100.9168) and PowerShell 7.6.5, which
agreed on every result below.

**Claims are labelled with their evidence.** Read the label before relying on a statement.

- **Measured** means observed by stubbing `Get-SKYAPIUnpagedEntity` / `Get-SKYAPIPagedEntity` / the write
  helpers and recording what each would have sent, on the date above.
- **From source** means read out of `SKYAPI/SKYAPI.psm1` or a function file.

> **The read functions now stream per record, as the write functions have since 0.5.0.** The 0.5.0 refactor
> covered the write side only; the read side was measured on 2026-09-04 still producing **one** request from a
> piped collection, built from the last record plus whatever earlier records left behind. That is fixed. The
> tables below are the post-fix measurements, and the pre-fix numbers are kept alongside them because the
> difference is the point.

## 1. From source: what makes a function stream correctly

Three things have to line up.

| Piece | Where | What it does |
| --- | --- | --- |
| a real `process` block | the function | runs the body once per record; without one the whole body is an implicit `end` block that runs once |
| `Get-SKYAPISuppliedParameterName` | `SKYAPI.psm1` | the names the *current* record actually supplied |
| `-SuppliedNames` on `Get-SKYAPIRequestParameter` | `SKYAPI.psm1` | drops bound values left over from an earlier record |

There is a fourth thing that no helper can do for you, because it never goes near `$PSBoundParameters`: a
body that computes a default must not assign it back to the parameter variable. See section 5.

## 2. From source: which functions have each piece

Counted over the 77 files in `SKYAPI/Functions`:

| Group | Files | `process` block | `-SuppliedNames` |
| --- | --- | --- | --- |
| Build a request from `$PSBoundParameters` via `Get-SKYAPIRequestParameter` | 36 | yes | yes |
| `Get-SchoolUserAuditByRole`, which builds its query by hand | 1 | yes | not needed |
| Per-record values travel in the URL only | 35 | yes | not needed |
| Local configuration and session functions | 4 | no | not needed |
| `Get-SKYAPIContext`, which takes no pipeline input at all | 1 | no | not applicable |

So 72 of 77 files have a `process` block, and all 36 call sites of `Get-SKYAPIRequestParameter` pass
`-SuppliedNames`. Counted over exported functions instead, 77 of 80 declare pipeline binding and 71 of those
have a `process` block.

`Get-SchoolUserAuditByRole` reads its parameter variables directly instead of `$PSBoundParameters`, which
PowerShell rebinds per record, so it needs no filter. Its own comment says so.

Six exported functions are exempt: `Disconnect-SKYAPI`, `Get-SKYAPIConfig`, `Remove-SKYAPIConfig` and
`Set-SKYAPIConfig` from the third row, plus `Set-SKYAPIConfigFilePath` and `Set-SKYAPITokensFilePath`, which
live in `SKYAPI.psm1` rather than in a file of their own and so are easy to miss when surveying the directory.
None makes an API call, none reads `$PSBoundParameters`, and each acts on a single local file or path
variable, so the last record winning is the only sensible outcome and a `process` block would not change what
any of them does. `Tests/TestParameterBinding_ValidateSets.ps1` holds that list as the exemption to a blanket
rule, so a new function without a `process` block fails a test rather than being noticed later.

The functions in the middle row read their parameter *variables*, which PowerShell rebinds correctly on every
record, so they need the `process` block and nothing else. `Connect-SKYAPI`, `Get-OrOrg`, `Get-OrSchool` and
`Connect-SchoolUserBBID` are in that group for the same reason.

## 3. Measured: a piped collection now reaches every record

| Call | Requests, 0.5.0 | Requests now | For |
| --- | --- | --- | --- |
| `Get-SchoolUser -User_ID 111,222,333` | 3 | 3 | 111, 222, 333 |
| `111,222,333 \| Get-SchoolUser` | **1** | **3** | 111, 222, 333 |
| `@({User_ID=111}, {User_ID=222}) \| Get-SchoolUser` | **1** | **2** | 111, 222 |
| `"11","22","33" \| Get-SchoolUserAuditByRole -start_date ...` | 3 | 3 | 11, 22, 33 |

The last row was the control before the fix: it was the one read function with a `process` block, and it
already streamed correctly.

**This is the cost side of the change.** N piped records now issue N requests where there was one, which is
correct but counts against the rate limit for anyone piping large collections. A caller who wants a single
request should pass the values by name, which is what the first row does.

## 4. Measured: each record now carries only its own values

```powershell
@(
    [pscustomobject]@{ school_year = '2022-2023'; section_ids = '111' }
    [pscustomobject]@{ school_year = '2023-2024' }
) | Get-SchoolAcademicRoster
```

| Module | Requests | Query sent |
| --- | --- | --- |
| 0.5.0 | 1 | `last_modified=@{school_year=2023-2024}&section_ids=@{school_year=2023-2024}&school_year=2023-2024` |
| 0.5.1 mid-development | 1 | `section_ids=111&school_year=2023-2024` |
| now | 2 | `school_year=2022-2023&section_ids=111` then `school_year=2023-2024` |

The middle row is what the multiple-`ValueFromPipeline` fix alone produced: it removed the stringified-record
half, leaving the record-to-record leak. `section_ids=111` on the second record asked for a section the
caller never named, on a year it does not belong to, and a `section_ids` that matches no section returns an
empty result rather than an error, so it read as "that year has no rosters" instead of as a fault.

## 5. Measured: the second leak, which `-SuppliedNames` cannot catch

A body that computes a default and assigns it **back to the parameter variable** leaks it into the next
record. The variable keeps what the body put there, so the next record's guard sees a value already set and
skips the default entirely. `$PSBoundParameters` is not involved, so `-SuppliedNames` never sees it.

Measured on `Get-SchoolUserByRole` while converting it: piping two records sent `marker=1` on the first and
**no marker at all** on the second. Four functions had the shape (`Get-SchoolList` on `page`,
`Get-SchoolUserByRole` on `marker`, `Get-SchoolScheduleMeeting` and `Get-SchoolUserAuditByRole` on
`end_date`). `Get-SchoolUserAuditByRole` had it since 0.5.0, where it already streamed, so that one was
reachable before this release. All four now compute into a local, and both leaks have cases in
`Tests/TestRequestParameters_PipelineIsolation.ps1`.

`Get-SchoolEnrollment` has the same shape on `offset` and was left alone, because it does not leak: the only
value its body ever writes back is `0`, which is identical to the `[int]` default a record that omits the
parameter would be rebound to, so the next record's guard reaches the same answer either way. Measured to be
sure: piping a record with `offset=50` followed by one without it sends `offset=50` then `offset=0`.

That is a narrow escape rather than a safe pattern, and the reasoning is easy to get wrong. Its guard is
`$null -eq $offset -or $offset -eq ''`, which looks like it cannot fire for an `[int]`, but `0 -eq ''` is
**True** on both editions, since `''` converts to `0` for the comparison. The guard fires on every record;
it is the value written back, not the guard, that makes this one harmless.

## 6. Measured: two binder details worth knowing before changing a parameter block

Both came up while giving each function at most one by-value parameter, and neither is obvious from the
declaration.

**A `[switch]` is never bound positionally or by value.** Several functions declared `ValueFromPipeline` on
`ReturnRaw`, `IncludeRosters` and `Silent`. The binder ignores it: a switch binds only by name, and a
`Position` on one is inert. Those declarations were noise, and removing them changed nothing a caller can
observe. It also means inserting a parameter ahead of a switch does not shift anything positionally.

**`InputObjectNotBound` is non-terminating, so the error alone does not stop the call.** When nothing accepts
a piped value, PowerShell writes an error with `FullyQualifiedErrorId` `InputObjectNotBound,<FunctionName>`
and category `InvalidArgument`. What stops the call now is the `process` block: a record that never bound is
a record `process` never runs for, so `'2022-2023' | Get-SchoolAcademicRoster` reports the error and makes
**no request** (measured: 0). Before the read functions had one, the body was an implicit `end` block and ran
anyway, so the same call also issued an unfiltered request and returned every roster in the school.

The two facts above combine on 21 parameterless lookup functions (`Get-SchoolRole`, `Get-SchoolYear`,
`Get-SchoolLevel` and so on): their only pipeline-declaring parameter is `-ReturnRaw`, and a `[switch]` never
binds by value, so **nothing** can bind from a pipeline. Piping anything into one of them now reports the
error and makes no request, where it used to report the error and fetch the whole list anyway. A direct call
is unaffected and still makes exactly one request, measured on both editions, and nothing inside the module
pipes into any of them.

## 7. Unverified

- Whether any caller relied on the old single-request behavior. It looks unlikely to have been deliberate,
  since the result was a filter the caller never asked for, but nothing here proves it.
- Whether any endpoint rate limits differently for many small requests than for one large one. Section 3's
  cost is counted in requests, not in what the API does about them.
