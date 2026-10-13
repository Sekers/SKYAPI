# Contributing to SKYAPI

Thank you for helping improve SKYAPI. This guide covers the everyday workflow.
[RELEASING.md](./RELEASING.md) covers versioning, branches, and releases in full.

## Getting the source

Clone with the wiki submodule included:

```powershell
git clone --recurse-submodules https://github.com/Sekers/SKYAPI.git
```

In an existing checkout, initialize the wiki, or restore the revision recorded by the current branch:

```powershell
git submodule update --init --recursive
```

Run that update after pulling or switching branches in the module repository. Save any wiki work first. The
wiki is checked out at the recorded commit, normally with a detached `HEAD`; switch to a wiki branch before
editing. GitHub's **Download ZIP** includes the module files and submodule configuration, but not the wiki
pages.

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

## Working on the wiki

`wiki/` is a checkout of the separate `Sekers/SKYAPI.wiki` repository. The module repository stores its commit
reference, not copies of its pages. The public wiki renders that repository's default branch, `master`.

1. Create a wiki branch, such as `docs/<short-name>`, from the recorded revision. Keep documentation for
   upcoming module changes on that branch so the public wiki continues to describe the latest release.
2. Edit and review the wiki pages. If endpoint links change, check both repositories from the module root:

   ```powershell
   .\Tests\TestDocLinks_EndpointReferences.ps1 -Path '.\wiki'
   ```

3. Commit and push the wiki branch first. Anyone cloning the module must be able to fetch the wiki commit it
   records. Contributors without wiki write access should arrange the wiki update with a maintainer.
4. In the module repository, stage the reference with `git add wiki` and include it in the pull request with
   the corresponding code changes. Identify the wiki commit and summarize its changes in the pull request.
5. After the module release succeeds, publish the recorded wiki revision as described in
   [RELEASING.md](./RELEASING.md#publishing-the-wiki).

Documentation corrections for released behavior can be published on the wiki's default branch independently.
Update `main`'s wiki reference through a documentation pull request, and incorporate the correction into any
upcoming wiki branch before updating `develop`'s reference.

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
- **Text files use LF line endings and no byte order mark, and PowerShell files contain only ASCII.** Windows
  PowerShell 5.1 misreads a non-ASCII character in a PowerShell file saved without a byte order mark, so write
  one as an escape such as `[char]0x00E9`. `.gitattributes` handles line endings, the test suite checks all
  three rules, and [AGENTS.md](./AGENTS.md) explains them.
- **Rebase only your own branch, and only before it merges.** Never force-push `develop` or `main`.

AI assistants working in this repository follow [AGENTS.md](./AGENTS.md), which also holds the detailed rules
for writing changelog entries.
