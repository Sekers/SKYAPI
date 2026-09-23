## Summary

<!-- What changes for someone using the module, and why? Link any related issue. -->

## Release classification

<!-- Check one. RELEASING.md explains what counts as part of the public contract and which version each kind of change produces. -->

- [ ] Breaking: an existing script, configuration file, or tokens file can stop working
- [ ] Addition: new backward-compatible functionality, such as a new endpoint or parameter
- [ ] Fix: a backward-compatible fix
- [ ] None: no user-visible change (tests, CI, research notes, or contributor documentation only)

## Checklist

- [ ] Targets `develop`, or `main` for a hotfix
- [ ] `CHANGELOG.md` has an entry in the right section under `[Unreleased]` (added if missing), or the change is not user-visible
- [ ] `.\Tests\Invoke-Tests.ps1` passes, with `-Network` as well if a SKY API documentation link was added or changed
- [ ] Any new public function is listed in `FunctionsToExport` in `SKYAPI/SKYAPI.psd1`
- [ ] Contains no real school or tenant names, email domains, secrets, or configuration or tokens files
- [ ] Any live SKY API testing was done against a development environment and is described above
