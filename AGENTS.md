# Guidance for AI Assistants Working in This Repository

This is the single source of truth for AI assistant guidance. `CLAUDE.md` at the repository root is a pointer
to this file, so Claude Code and Codex both pick up the same rules. Edit this file, not the pointer.

**What this repository is:** `SKYAPI`, a PowerShell module wrapping Blackbaud's SKY API (mainly the Education
Management "school" API). Public functions live one-per-file in `SKYAPI/Functions/`; shared private helpers
live in `SKYAPI/SKYAPI.psm1`. Work happens on `develop`; `main` is the released branch.
[RELEASING.md](./RELEASING.md) holds the versioning rules and the release process, and
[CONTRIBUTING.md](./CONTRIBUTING.md) the everyday workflow. The GitHub wiki is a separate repository
(`Sekers/SKYAPI.wiki`), not part of this one.

## Safety rules that override convenience

- **Never name the production tenant in any file.** No school name, abbreviation, or email domain, in code,
  comments, notes, tests or commit messages. Write "the production tenant". Naming the development
  environment (`SKY Developer Cohort`) is fine.
- **Never write to the production tenant without explicit permission.** Reads are fine. Test and sample
  scripts can be pointed at either a throwaway development environment or the live production tenant, and the
  target is set by whichever `Set-SKYAPIConfigFilePath` / `Set-SKYAPITokensFilePath` lines are uncommented. Read
  those lines before running anything that authenticates.
- **Every placeholder email address uses a domain reserved by [RFC 2606](https://www.rfc-editor.org/rfc/rfc2606)**:
  `example.com`, `example.net`, or `example.org`. None of them can ever be registered, so a placeholder copied
  out of a help example and run unedited cannot reach a real person. Help examples are exactly what readers copy
  and run, and some of them write to the tenant: `Connect-SchoolUserBBID -send_invite $true` emails the address
  it is given. Prefer `example.com` for anything new, but all three are equally correct: never rename existing
  placeholders to match that preference.

## CHANGELOG.md

**The changelog is the release notes.** Its entries are what users actually read when a version ships, so it
is the destination for user-facing change, not a staging area for it. Never move that content into
`README.md`. If something genuinely needs more room than an entry allows, it goes in the wiki, and only when
it is a big enough issue that people need to be warned about it.

### The baseline is the latest RELEASE, never the development branch

An entry describes what changed for someone **upgrading from the last released version**. Before writing any
"Fixed ..." entry, verify the bug actually existed in that release.

**Derive the release. Do not trust a version number written down anywhere, including here or in
`SKYAPI/SKYAPI.psd1`.** A release is a tag on `main` ([RELEASING.md](./RELEASING.md) describes the process).
`origin/main` can sit past the last tag, so ask for the nearest tag rather than an exact match:

```powershell
git fetch origin --tags --quiet                        # only if the local copy might be behind
$Release = git describe --tags --abbrev=0 origin/main
```

- Work happens on `develop`. The **local `main` branch is stale**, so compare against `$Release` or
  `origin/main`, never local `main`, and never against `HEAD` or `develop`.
- <https://github.com/Sekers/SKYAPI/releases> has been seen serving a stale "Latest" label, so trust the tag
  over the page.

Verify before claiming a fix:

```powershell
git cat-file -e "${Release}:SKYAPI/Functions/<Name>.ps1"   # nonzero exit = did not exist in the release
git show     "${Release}:SKYAPI/Functions/<Name>.ps1" | Select-String '<pattern>'   # was the bug there?
git show     "${Release}:SKYAPI/SKYAPI.psm1"          | Select-String '<pattern>'
git tag --contains <commit>   # no output = the commit that introduced the bug never shipped
```

**A bug introduced on `develop` and fixed before release is not a changelog entry.** It never reached a user.
This is easy to get wrong while a release is in progress, because a lot of churn happens on `develop`, and a
fix to something that itself landed after the last tag is invisible to users. The checks above settle it.

**A function that does not exist in the last release** belongs under **Added** as a new endpoint only. It can
never also appear as a "Fixed" entry, and it should not be listed among the functions a fix "affects."

**An API change the module adapted to is not a fix.** "Fixed" claims a defect in this module. If the code was
never wrong and Blackbaud changed something underneath it, the entry belongs in **Changed**, written as
`Updated Endpoint:` when a public function's behavior changed, or in **Added** when it gives callers something
new, such as a parameter that restores the old results. The giveaway is that the change in behavior already
reached users on the last release, since it happened server side rather than in this repository.

### Write for the end user, never for the module developer

An entry answers one question: **what changes for someone using this module?** Anything that does not help a
caller decide "does this affect me, and do I need to do something?" belongs in the commit message, a code
comment, or `Research_Notes/`, not here.

Include:

- What went wrong from the caller's side, described in terms of what they saw.
- What the behavior is now.
- The public functions and parameters affected, and any action the user has to take.

**Verify the symptom, not just the bug.** A real defect still produces a false entry if the impact is
overstated. Trace what a caller actually experienced before describing it: retries, fallbacks and defaults
often mean a genuine bug never surfaced as a failure. "Fixed tokens not being refreshed" was wrong for exactly
this reason, because the `401` handler refreshed them anyway; the real symptom was an extra round trip.

Leave out:

- **Root cause and mechanism.** Why the bug happened is developer information. "The value defaulted to the
  boolean `$false` alongside the neighboring true/false options" tells a user nothing they can act on.
- **Private helpers, internal variables and code paths.** Only name things a caller can actually invoke; check
  `FunctionsToExport` in `SKYAPI/SKYAPI.psd1` before naming a function.
- **How it was found, measured or diagnosed**, including pointers to `Research_Notes/`. Those notes are for
  contributors, so link them from the commit or the code, not from a user-facing entry.
- **Anything with no observable effect on a caller.** If no script a user could reasonably write would have
  hit the bug, there is nothing to log.

Two or three sentences is a normal entry. Length is not thoroughness: someone scanning a release to see
whether it affects them should get the answer in the first line.

**One entry, one audience.** If a single change produces two facts aimed at different readers, write two
entries. A fix that applied only to PowerShell 7 alongside a breaking type change that applied only to
Windows PowerShell 5.1 reads as a contradiction in one bullet; as two bullets, each reader finds their half
immediately.

### Structure and style

The format is [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). [RELEASING.md](./RELEASING.md)
covers when `[Unreleased]` becomes a version and how that version is chosen.

- **New entries go under `## [Unreleased]`** at the top of the file. Never invent a version number for them;
  the release-prep pull request turns `[Unreleased]` into a dated version heading.
- **Add the `[Unreleased]` section only with an entry.** Right after a release there is none, so the first new
  entry also adds `## [Unreleased](https://github.com/Sekers/SKYAPI/compare/<release>...develop)` at the top,
  where `<release>` is `$Release` from the baseline commands above. Never add an empty one, and never leave one
  in a release: the Release workflow refuses to publish while it is there.
- Newest version first. A released version uses this heading shape, and a `---` line, with a blank line on each
  side of it, separates it from the next (older) version:

  ```markdown
  ---

  ## [0.6.0](https://github.com/Sekers/SKYAPI/tree/0.6.0) - 2026-10-01

  ### Fixed

  - ...
  ```

- Sections in order: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`.
  Omit a section that has no entries.
- Versions 0.5.0 and earlier use `### Fixes`, `### Features`, and `### Other`, with an author line and the date
  in parentheses. Leave them as they are.
- Prefix an entry with `Minor:` inside **Fixed** when a user probably never noticed it: help text wording, a
  message, an edge case needing unusual conditions to hit, or a cost the module absorbed itself such as a
  wasted request. List the `Minor:` entries after the rest of the Fixed entries.
- Prefix an entry with `**BREAKING CHANGE:**` when it breaks the public contract as
  [RELEASING.md](./RELEASING.md) defines it, so an existing script, configuration file, or tokens file can stop
  working, and say what the user has to change. Qualify it when the break is limited, as in
  `**BREAKING CHANGE (Windows PowerShell 5.1 only):**`. Such an entry usually belongs under **Changed** or
  **Removed**.
- A new endpoint goes under **Added** and reads `- New Endpoint: [Function-Name](<docs link>)`.
- A change to an existing endpoint function with several parts reads
  `- Updated Endpoint: [Function-Name](<docs link>)`, with the details as nested bullets.
- Link every endpoint to the SKY API docs in this exact shape:
  `https://developer.sky.blackbaud.com/api#api=<api>&operation=<OperationId>`
  - `<api>` is `school` for Education Management. For Raiser's Edge NXT Constituent it is the service id
    `56b76470069a0509c8f1c5b3`; the friendly-looking `constituent` returns 404.
  - Most operation ids are PascalCase (`V1UsersPatch`). Exactly seven are lowercase on the portal
    (`v1usersget`, `v1yearsget`, `v1rolesget`, `v1termsget`, `v1levelsget`, `v1gradelevelsget`,
    `v1offeringtypesget`). Write each id the way the portal reports it and do not "fix" those seven to
    PascalCase. Casing is verified against the portal's own spelling, so a mismatch fails the test below.
  - The older `developer.sky.blackbaud.com/docs/services/...` shape is retired and 404s everywhere.
  - After adding or editing a link, run `Tests/TestDocLinks_EndpointReferences.ps1`, which checks every link
    in the repo against the portal and catches all of the above.
- **No em dashes.** Use a semicolon, colon, parentheses, comma, or a new sentence. This applies to every file
  in the repo, not just the changelog.
- Write "**time zone**" as two words in prose. Code identifiers keep their own spelling (`TimeZoneInfo`,
  `SchoolTimeZoneId`, `timezone_name`).
- Put code identifiers in backticks in Markdown, including .NET property names such as `Id`, `StandardName`,
  and `DaylightName`, so a bare `Id` does not read as a typo. In PowerShell comment-based help, do **not** use
  backticks; `Get-Help` renders them literally.

## File encoding and line endings

**This is already decided. Do not re-derive it, and do not "tidy" files to match a different opinion.**
`.gitattributes` is the authority and explains its own reasoning; this section exists so you know the answer
without going to look.

- **LF everywhere.** Every text type is pinned `eol=lf`, which is what Git stores anyway, so a checked-out
  file is byte for byte the repository's copy on any platform and under any `core.autocrlf`.
- **No byte order mark in the repository.** Every text file here is BOM-free.
- **PowerShell files contain only ASCII.** This covers `.ps1`, `.psm1`, `.psd1`, `.ps1xml`, `.psrc`, and
  `.pssc`. Windows PowerShell 5.1 reads a script that has no BOM in the system's ANSI code page, so a single
  non-ASCII character (a curly quote or an em dash pasted into a message string, for example) is silently
  misread there while PowerShell 7 reads it correctly. In code, write a non-ASCII character as an escape such as
  `[char]0x00E9`. `Research_Notes/File-Encoding-And-Line-Endings.md` section 8 has the measurement.
- **Other text files may contain non-ASCII characters**, such as the `§` the research notes use for section
  references. The no-em-dash rule in the changelog's "Structure and style" section still applies to every file.
- **The files the module writes at runtime are a separate question, and it is already answered.** The
  configuration file and the cached tokens file are written with `Out-File -Encoding utf8`, which is BOM-free
  on PowerShell 7 and carries a BOM on Windows PowerShell 5.1. **That BOM is accepted.** Do not "fix" those
  calls to `[System.IO.File]::WriteAllText`, and do not read the repository rule above as covering them.
  Windows PowerShell 5.1 has no `utf8NoBOM`; that value arrived in PowerShell 6, so no single `Out-File`
  spelling is BOM-free on both editions. The move to UTF-8 was about getting off UTF-16, which halved the file
  size and removed the NUL bytes that made Git treat it as binary, not about the last three bytes.
  `Get-Content` honors a BOM, so the module reads either form, and `Out-File -Force` truncates before
  writing, so the BOM clears itself the next time PowerShell 7 writes the file. The only thing that would
  reopen this is a consumer outside PowerShell reading those files, which
  `Research_Notes/File-Encoding-And-Line-Endings.md` section 9 lists as unverified.
- **Skip anything containing a NUL byte**, which is Git's own binary test. Git reports such a file as
  `-text`, so no line-ending rule applies to it, and a bulk "read text, write text" pass over one re-encodes
  it and can halve its size.

Git will not show you a line-ending mistake: it normalizes before diffing, so a wrong file produces no diff
and leaves `git status` clean. Use this instead, which wants `w/lf` on every row:

```powershell
git ls-files --eol -- '*.ps1' '*.psm1' '*.psd1' '*.md'
```

Most editors and tools create new files with LF, so writing a new file is normally correct here and needs no
follow-up. Never change the line endings of a file you are not otherwise editing. To fix one that is wrong:

```powershell
$Text = [System.IO.File]::ReadAllText($Path)
[System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n","`n"))
```

`Tests/TestRepoHygiene_FileEncoding.ps1` enforces all of the above and is part of the offline suite, so a
violation fails a test run rather than being noticed by hand three commits later.

## Code

- **A new public function needs an explicit entry in `FunctionsToExport` in `SKYAPI/SKYAPI.psd1`.** Every
  `SKYAPI/Functions/*.ps1` is dot-sourced automatically, so a function with no manifest entry loads but stays
  invisible to callers. Aliases work the same way through `AliasesToExport`.
- **Comments describe the code as it is now**, never what it used to do or what a fix changed. Change history
  belongs in the commit message and the changelog.
- Match the surrounding function's shape when adding one. The GET functions are near-identical in layout, and
  the write functions follow a `begin`/`process`/`end` convention that builds request parameters with the
  shared `Get-SKYAPIRequestParameter` helper rather than hand-rolling a copy loop.

## Testing

Tests in `Tests/` are plain scripts, not Pester. They print `PASS`/`FAIL` lines and a final summary, and exit
non-zero on failure. `Tests/Invoke-Tests.ps1` runs them:

```powershell
.\Tests\Invoke-Tests.ps1                      # offline tests, BOTH editions, one summary and exit code
.\Tests\Invoke-Tests.ps1 -Edition Core        # PowerShell 7 only, while iterating
.\Tests\Invoke-Tests.ps1 -Name '*DateTime*'   # one family
.\Tests\Invoke-Tests.ps1 -Network             # add the portal checks
```

This is the pre-commit check: it is the whole offline suite across both editions in about a minute, which is
the entire point of it existing. Run a single script directly when you are working on that script:

```powershell
pwsh       -NoProfile -File Tests\TestRequestParameters_CommonParameterFilter.ps1   # PowerShell 7.x
powershell -NoProfile -File Tests\TestRequestParameters_CommonParameterFilter.ps1   # Windows PowerShell 5.1
```

They import the working copy (`SKYAPI/SKYAPI.psd1`), not an installed module, so they test your edits.

**A test that needs more than an offline run must say so**, with a `# TestRequires: Live` or
`# TestRequires: Network` line in its header. The runner reads that and skips those by default, naming every
script it skipped rather than counting them. Behind that line is a backstop: a script that declares nothing
but calls `Connect-SKYAPI` or `Set-SKYAPITokensFilePath` is classified live anyway, so forgetting the marker
keeps a new script out of the default run instead of letting it reach a real tenant unattended. The backstop
parses the script, so it sees those calls however they are written and ignores mentions in comments, but it
catches a direct call only: the module authenticates inside its own request helpers, so a script that calls a
public function without stubbing them reaches a tenant without naming either command. Write the marker.

**A script that cannot run where it is** (under the wrong edition, or without an optional tool) prints a line
starting `SKIPPED:` and exits `77`. The runner reports that run as `SKIP`, by name and with the reason, and never
counts it as a pass, so exit `0` always means the checks actually ran.

`TestRepoHygiene_ScriptAnalyzer` runs PSScriptAnalyzer over the module and fails on any `Error` or `ParseError`
finding. It runs under PowerShell 7 only, and skips where the analyzer is not installed, except in CI, where it
fails. The Tests workflow pins the analyzer version through `PSSCRIPTANALYZER_VERSION`, which the test honors
because the runner image ships its own copy. When a finding is intended, suppress it on its function with a
`SuppressMessageAttribute` that carries a `Justification`, as `Connect-SKYAPI` does. Never exclude the rule in
the test instead; the test also fails a suppression that gives no reason.

CI runs the same thing. `.github/workflows/Tests.yml` runs the offline suite on every branch push and pull
request, and `Release.yml` calls that workflow as a gate, so a release cannot publish a build that fails its
own tests. The tests need no credentials; only the Release workflow's publish job uses the PowerShell Gallery
key.

**Every test is offline and safe to run with no setup except the four named below.** The offline ones must
pass under **both** Windows PowerShell 5.1 and PowerShell 7.x, so run both editions before calling a change
done. The exceptions:

- **Network, no credentials**, still safe to run anytime: `TestDocLinks_EndpointReferences` (validates every
  docs link against the portal) and `TestDateTime_SchemaCoverage` (compares published schema claims against
  what the module does; it reports leads, not verdicts).
- **Live, authenticates against a real tenant.** Identify these rather than trusting a list, since a comment
  mentioning the call is not the same as making it:

  ```powershell
  Select-String -Path Tests\*.ps1 -Pattern '^\s*(Set-SKYAPITokensFilePath|Connect-SKYAPI)\b' |
      Select-Object -ExpandProperty Filename -Unique
  ```

  Read which tenant such a script points at before running it; see the safety rules above. One of them,
  `TestDateTime_WireFormatSurvey`, is a *survey* rather than a pass/fail suite, so a missing summary line is
  not a failure. `TestAPICallErrors_RateLimit` is live **on purpose**: the point is to trip the API's real
  rate limiting and see what it returns, which no local stub can tell you, so do not "fix" it by
  converting it to an offline test.

### Pester was evaluated and declined (2026-09-04)

Pester 6.1.0 was measured against this repo and does work here: it imports under both Windows PowerShell 5.1
and PowerShell 7.x, `InModuleScope SKYAPI` reaches the private helpers, and `Mock -ModuleName SKYAPI`
intercepts calls the module makes internally. It was still declined, so do not re-derive this.

The only real draw is `Mock`, and it applies solely to the error-path scripts that are already offline by
choice, where it would replace hand-rolled function shadowing without adding coverage. Against that: a
contributor dependency where the offline suite currently needs no setup at all, a PowerShell 7.4 floor in
Pester 6, and four of the seventeen scripts that are surveys, report generators or live observation scripts
rather than pass/fail suites, so they do not fit `Describe`/`It` without changing their purpose. Running two
idioms side by side would also make "match the surrounding shape" ambiguous for every later contributor.

Revisit if one file's stub layer becomes genuinely unmanageable. That is a reason to convert that single
file, not to adopt Pester across the suite.

## Research notes

Measured or researched behavior belongs in `Research_Notes/`, one file per behavior category (error responses,
pagination, date and time handling, and so on); list the directory to see what already exists. Add to the
matching file, or create a new file for a new category rather than stretching an existing one.

- **Label every claim with its evidence:** **Measured**, **From source** (read from a file in this repository),
  **From schema** (the published OpenAPI schema), **From documentation** (with the page linked), or
  **Unverified**. An unverified assumption the module depends on is still worth recording, labelled as such.
- **Date everything that can change.** Give the date and environment (development or production tenant,
  PowerShell editions and versions) for anything measured, and the date read for anything taken from the schema
  or documentation.
- **Say what a result does not establish**, so a later reader does not stretch it past what was tested.
- **Tie each behavior to the code it affects**, by file and function name rather than line number.
- **The notes are for contributors.** Link them from commit messages and code comments, never from
  `CHANGELOG.md` or other user-facing text.
- **The safety rules above apply while gathering evidence:** reads only against the production tenant unless
  writing was explicitly permitted, and never name it in a note.
