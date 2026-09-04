# Guidance for AI Assistants Working in This Repository

This is the single source of truth for AI assistant guidance. `CLAUDE.md` at the repository root is a pointer
to this file, so Claude Code and Codex both pick up the same rules. Edit this file, not the pointer.

**What this repository is:** `SKYAPI`, a PowerShell module wrapping Blackbaud's SKY API (mainly the Education
Management "school" API). Public functions live one-per-file in `SKYAPI/Functions/`; shared private helpers
live in `SKYAPI/SKYAPI.psm1`. Work happens on `develop`; `master` is the released branch.

## Safety rules that override convenience

- **Never name the production tenant in any file.** No school name, abbreviation, or email domain, in code,
  comments, notes, tests or commit messages. Write "the production tenant". Naming the development
  environment (`SKY Developer Cohort`) is fine.
- **Never write to the production tenant without explicit permission.** Reads are fine. Test and sample
  scripts can be pointed at either a throwaway development environment or the live production tenant, and the
  target is set by whichever `Set-SKYAPIConfigFilePath` / `Set-SKYAPITokensFilePath` lines are uncommented. Read
  those lines before running anything that authenticates.

## CHANGELOG.md

**The changelog is the release notes.** Its entries are what users actually read when a version ships, so it
is the destination for user-facing change, not a staging area for it. Never move that content into
`README.md`. If something genuinely needs more room than an entry allows, it goes in the wiki, and only when
it is a big enough issue that people need to be warned about it.

### The baseline is the latest RELEASE, never the development branch

An entry describes what changed for someone **upgrading from the last released version**. Before writing any
"Fixed ..." entry, verify the bug actually existed in that release.

**Derive the release. Do not trust a version number written down anywhere, including here.** The released
commit is `origin/master`, and it carries the release tag:

```powershell
git fetch origin --tags --quiet                          # only if the local copy might be behind
$Release = git describe --tags --exact-match origin/master
```

- Work happens on `develop`. The **local `master` branch is stale**, so compare against `$Release` or
  `origin/master`, never local `master`, and never against `HEAD` or `develop`.
- <https://github.com/Sekers/SKYAPI/releases> has been seen serving a stale "Latest" label, so trust the tag
  over the page.

Verify before claiming a fix:

```powershell
git cat-file -e "${Release}:SKYAPI/Functions/<Name>.ps1"   # nonzero exit = did not exist in the release
git show     "${Release}:SKYAPI/Functions/<Name>.ps1" | Select-String '<pattern>'   # was the bug there?
git show     "${Release}:SKYAPI/SKYAPI.psm1"          | Select-String '<pattern>'
```

**A bug introduced on `develop` and fixed before release is not a changelog entry.** It never reached a user.
This is easy to get wrong while a release is in progress, because a lot of churn happens on `develop`, and a
fix to something that itself landed after the last tag is invisible to users. The `git show` check above is
what settles it.

**A function that does not exist in the last release** belongs under **Features** as a new endpoint only. It
can never also appear as a "Fixed" entry, and it should not be listed among the functions a fix "affects."

**An API change the module adapted to is not a fix.** "Fixed" claims a defect in this module. If the code was
never wrong and Blackbaud changed something underneath it, the entry belongs in **Features**, written as
`Updated Endpoint:` when a public function's behavior changed. The giveaway is that the change in behavior
already reached users on the last release, since it happened server side rather than in this repository.

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

- Sections in order: `### Fixes`, `### Features`, `### Other`. Omit a section that has no entries.
- Prefix an entry with `Minor:` inside **Fixes** when a user probably never noticed it: help text wording, a
  message, an edge case needing unusual conditions to hit, or a cost the module absorbed itself such as a
  wasted request. List the `Minor:` entries after the rest of the Fixes.
- A new endpoint reads `- New Endpoint: [Function-Name](<docs link>)`.
- Link every endpoint to the SKY API docs in this exact shape:
  `https://developer.sky.blackbaud.com/api#api=<api>&operation=<OperationId>`
  - `<api>` is `school` for Education Management. For Raiser's Edge NXT Constituent it is the service id
    `56b76470069a0509c8f1c5b3`; the friendly-looking `constituent` returns 404.
  - Most operation ids are PascalCase (`V1UsersPatch`). Exactly seven are lowercase on the portal
    (`v1usersget`, `v1yearsget`, `v1rolesget`, `v1termsget`, `v1levelsget`, `v1gradelevelsget`,
    `v1offeringtypesget`). Write each id the way the portal reports it and do not "fix" those seven to
    PascalCase. Nothing verifies casing, so a mismatch will not be caught for you.
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
non-zero on failure. Run one directly, for example:

```powershell
pwsh       -NoProfile -File Tests\TestRequestParameters_CommonParameterFilter.ps1   # PowerShell 7.x
powershell -NoProfile -File Tests\TestRequestParameters_CommonParameterFilter.ps1   # Windows PowerShell 5.1
```

They import the working copy (`SKYAPI/SKYAPI.psd1`), not an installed module, so they test your edits.

**Every test is offline and safe to run with no setup except the five named below.** The offline ones must
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
  not a failure.

Measured API behavior belongs in `Research_Notes/`, one file per behavior category; list the directory to see
what already exists. Label each claim with its evidence (measured, from source, from schema, or unverified)
and give the date and environment for anything measured, matching the existing notes. Create a new file for a
new category rather than stretching an existing one.
