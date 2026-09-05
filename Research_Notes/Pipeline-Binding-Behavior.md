# Pipeline binding behavior

Notes on how this module's functions bind pipeline input, and on the read functions still processing only the
last piped record.

Measured on **2026-09-04** against the working copy, with the HTTP helpers stubbed inside the module scope.
**No tenant was involved and no request left the machine**, so nothing here describes the API; it describes
this module. Both editions were checked: Windows PowerShell 5.1 (5.1.26100.9168) and PowerShell 7.6.5, which
agreed on every result below.

**Claims are labelled with their evidence.** Read the label before relying on a statement.

- **Measured** means observed by stubbing `Get-SKYAPIUnpagedEntity` / `Get-SKYAPIPagedEntity` / the write
  helpers and recording what each would have sent, on the date above.
- **From source** means read out of `SKYAPI/SKYAPI.psm1` or a function file.

> **The 0.5.0 refactor fixed this for the write functions only.** Its changelog entry says "previously,
> piping multiple users processed only the last one" and names the six write functions it covered. The read
> functions were never in scope and still behave the old way: a piped collection produces **one** request,
> built from the last record plus whatever earlier records left behind.

## 1. From source: what makes a function stream correctly

Three things have to line up. All three already exist in the module.

| Piece | Where | What it does |
| --- | --- | --- |
| a real `process` block | the function | runs the body once per record; without one the whole body is an implicit `end` block that runs once |
| `Get-SKYAPISuppliedParameterName` | `SKYAPI.psm1` | the names the *current* record actually supplied |
| `-SuppliedNames` on `Get-SKYAPIRequestParameter` | `SKYAPI.psm1` | drops bound values left over from an earlier record |

`Get-SKYAPIRequestParameter` documents the gap itself, on its own parameter:

> Omit this to keep every bound parameter, which is the right thing for a function with no process block.

So the current state is deliberate and known, not an oversight; it is simply unfinished.

## 2. From source: which functions have each piece

| Group | Count | `process` block | `-SuppliedNames` |
| --- | --- | --- | --- |
| Write functions covered by the 0.5.0 refactor | 8 | yes | yes |
| `Get-SchoolUserAuditByRole` (new in 0.5.0, written this way from the start) | 1 | yes | yes |
| Everything else that declares pipeline binding | 63 | **no** | **no** |

Totals: 13 of 77 function files have a `process` block; 9 pass `-SuppliedNames`. The four with a `process`
block but no `-SuppliedNames` do not need it, because none of them builds its request from
`$PSBoundParameters`: `Connect-SKYAPI`, `Get-OrOrg` and `Get-OrSchool` send no per-record API fields at all,
and `Connect-SchoolUserBBID` builds its body explicitly from named variables inside its own process block.

## 3. Measured: a piped collection loses every record but the last

`Get-SchoolUser` takes `[int[]]$User_ID` and loops over it, so the array form is fine. The pipeline form is
not:

| Call | Requests made | For |
| --- | --- | --- |
| `Get-SchoolUser -User_ID 111,222,333` | 3 | 111, 222, 333 |
| `111,222,333 \| Get-SchoolUser` | **1** | 333 only |
| `@({User_ID=111}, {User_ID=222}) \| Get-SchoolUser` | **1** | 222 only |
| `"11","22","33" \| Get-SchoolUserAuditByRole -start_date ...` | 3 | 11, 22, 33 |

The last row is the control: it is the one read function with a `process` block, and it streams correctly.

Nothing is reported when records are dropped. The call succeeds and returns a result for the final record,
which is why this can be mistaken for a normal empty-ish response.

## 4. Measured: what the surviving record carries

The single request is not even the last record on its own. Parameter *variables* are rebound per record, so
one the last record omitted reverts to its type default, but `$PSBoundParameters` keeps the earlier record's
entry, and that is what the request is built from.

```powershell
@(
    [pscustomobject]@{ school_year = '2022-2023'; section_ids = '111' }
    [pscustomobject]@{ school_year = '2023-2024' }
) | Get-SchoolAcademicRoster
```

| Module | Requests | Query sent |
| --- | --- | --- |
| 0.5.0 | 1 | `last_modified=@{school_year=2023-2024}&section_ids=@{school_year=2023-2024}&school_year=2023-2024` |
| 0.5.1 | 1 | `section_ids=111&school_year=2023-2024` |

0.5.1 removed the stringified-record half of this (that was the multiple-`ValueFromPipeline` defect, fixed
by giving each function at most one by-value parameter per set). The record-to-record leak is the other half
and is untouched: the second record still inherits `section_ids=111` from the first.

A `section_ids` value that matches no section returns an empty result rather than an error, so this reads as
"that year has no rosters" instead of as a fault.

## 5. Measured: two binder details worth knowing before changing a parameter block

Both came up while giving each function at most one by-value parameter, and neither is obvious from the
declaration.

**A `[switch]` is never bound positionally or by value.** Several functions declared `ValueFromPipeline` on
`ReturnRaw`, `IncludeRosters` and `Silent`. The binder ignores it: a switch binds only by name, and a
`Position` on one is inert. Those declarations were noise, and removing them changed nothing a caller can
observe. It also means inserting a parameter ahead of a switch does not shift anything positionally.

**`InputObjectNotBound` is non-terminating, and the function still runs.** When nothing accepts a piped
value, PowerShell writes an error with `FullyQualifiedErrorId` `InputObjectNotBound,<FunctionName>` and
category `InvalidArgument`, and then the function body **still executes once** with none of the piped value
bound. So `'2022-2023' | Get-SchoolAcademicRoster` reports the error and also issues an unfiltered request.
The error is visible, which is what matters, but it does not stop the call.

## 6. Unverified

- Whether any caller relies on the current single-request behavior. It looks unlikely to be deliberate, since
  the result is a filter the caller never asked for, but nothing here proves it.
- The cost of the fix in requests. Streaming N records correctly means N requests where there is now 1, which
  is correct but is a real increase against the rate limit for anyone piping large collections.
