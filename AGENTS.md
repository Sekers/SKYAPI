# Guidance for AI Assistants Working in This Repository

This is the single source of truth for AI assistant guidance. `CLAUDE.md` at the repository root is a pointer
to this file, so Claude Code and Codex both pick up the same rules. Edit this file, not the pointer.

## CHANGELOG.md

### The baseline is the latest RELEASE, never the development branch

An entry describes what changed for someone **upgrading from the last released version**. Before writing any
"Fixed ..." entry, verify the bug actually existed in that release.

- Latest release: **0.4.4**, tag `0.4.4`, commit `d60e585dc879e10ffe115927ba4610727ad73e65`. This is also
  `origin/master`.
- Releases are listed at <https://github.com/Sekers/SKYAPI/releases>. Check there for the current one rather
  than assuming 0.4.4 is still latest.
- The **local `master` branch is stale**; the online repo is newer. Compare against the tag or
  `origin/master`, never local `master`, and never against `HEAD` or `develop`.

Verify before claiming a fix:

```
git cat-file -e 0.4.4:SKYAPI/Functions/<Name>.ps1    # did the function even exist in the release?
git show     0.4.4:SKYAPI/Functions/<Name>.ps1 | grep ...   # did the bug exist there?
git show     0.4.4:SKYAPI/SKYAPI.psm1 | grep ...
```

**A bug introduced on `develop` and fixed before release is not a changelog entry.** It never reached a user.
This is easy to get wrong while a release is in progress, because a lot of churn happens on `develop`. Watch
especially for fixes to other in-flight `develop` work, such as the write-function begin/process/end refactor
and the request-parameter helper, which introduced and then fixed their own bugs.

**A function that does not exist in the last release** belongs under **Features** as a new endpoint only. It
can never also appear as a "Fixed" entry, and it should not be listed among the functions a fix "affects."

### Style

- **No em dashes.** Use a semicolon, colon, parentheses, comma, or a new sentence. This applies to every file
  in the repo, not just the changelog.
- Write "**time zone**" as two words in prose. Code identifiers keep their own spelling (`TimeZoneInfo`,
  `SchoolTimeZoneId`, `timezone_name`).
- Put code identifiers in backticks in Markdown, including .NET property names such as `Id`, `StandardName`,
  and `DaylightName`, so a bare `Id` does not read as a typo. In PowerShell comment-based help, do **not** use
  backticks; `Get-Help` renders them literally.
- Link endpoints to the SKY API docs, matching the style of surrounding entries.
- Prefix small items with `Minor:` within the **Fixes** list.
- Sections in order: `### Fixes`, `### Features`, `### Other`.

## Testing

- Tests in `Tests/` are plain scripts, not Pester. They print `PASS`/`FAIL` lines and a final summary, and
  exit non-zero on failure. Offline tests must pass under **both** Windows PowerShell 5.1 and PowerShell 7.x.
- `Tests/TestDateTime_WireFormatSurvey.ps1` is a live *survey*, not a pass/fail suite. A missing summary line
  is not a failure.
- Measured API behavior belongs in `Research_Notes/`. For example, DateTime handling is in
  `Research_Notes/DateTime-Handling.md`. Create new research files for different API behavior categories.
