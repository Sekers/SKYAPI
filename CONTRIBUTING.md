# Contributing to SKYAPI

Thank you for helping improve SKYAPI. This guide covers the everyday workflow.
[RELEASING.md](./RELEASING.md) covers versioning, branches, and releases in full.

## Workflow

1. Fork the repository, or create a branch in it if you have write access.
2. Branch from `develop` as `feature/<short-name>`. Urgent fixes to the released version go on a
   `hotfix/<version>` branch from `main` instead; check with a maintainer first.
3. Make your change, following the conventions of the surrounding code. A new public function also needs an
   entry in `FunctionsToExport` in `SKYAPI/SKYAPI.psd1`, or callers cannot see it.
4. Run the offline tests under both PowerShell editions (Windows PowerShell 5.1 and PowerShell 7):

   ```powershell
   .\Tests\Invoke-Tests.ps1
   ```

   If you added or changed a link to the SKY API documentation, add `-Network` to also check every link against
   the Blackbaud developer portal. That needs no credentials.

5. If users will notice the change, add an entry to `CHANGELOG.md` under `[Unreleased]`. If that section is not
   there yet, as right after a release, add it at the top ([RELEASING.md](./RELEASING.md#changelog) shows the
   heading).
6. Open a pull request into `develop` (or into `main` for a hotfix) and complete the pull request template,
   including the release classification.

## Rules

- **Never commit a real configuration file, tokens file, or secret.** Never name a real school, tenant, or email
  domain in code, help examples, tests, sample scripts, or commit messages; use an RFC 2606 reserved domain
  instead, such as `example.com`. Those can never be registered, so a placeholder that gets run unedited reaches
  nobody.
- **The automated tests never connect to a tenant.** A test that needs more than an offline run says so with a
  `# TestRequires: Live` or `# TestRequires: Network` line in its header, and `Invoke-Tests.ps1` skips it unless
  asked. Run live tests only against a development environment, never against a school's production data, and
  describe what you tested in the pull request.
- **Tests are plain scripts, not Pester.** Name a new one `Test<Category>_<Name>.ps1` and follow the existing
  ones: `PASS`/`FAIL` lines, a final summary, and a non-zero exit code on failure.
- **Text files use LF line endings and no byte order mark.** `.gitattributes` handles line endings, the test
  suite checks both rules, and [AGENTS.md](./AGENTS.md) explains them.
- **Rebase only your own branch, and only before it merges.** Never force-push `develop` or `main`.

AI assistants working in this repository follow [AGENTS.md](./AGENTS.md), which also holds the detailed rules
for writing changelog entries.
