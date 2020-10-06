# SKYAPI PowerShell Module <!-- omit in toc -->

## Table of Contents  <!-- omit in toc -->

- [Overview](#overview)
- [What's New](#whats-new)
- [Current API Support](#current-api-support)
- [Documentation](#documentation)
- [Developing and Contributing](#developing-and-contributing)

---

## Overview

PowerShell Module for the [Blackbaud SKY API](https://developer.blackbaud.com/skyapi/).

---

## What's New

See [CHANGELOG.md](./CHANGELOG.md) for information on the latest updates, as well as past releases.

---

## Current API Support

At present, this module is focused on retrieving information from the Blackbaud SKY API [School API](https://developer.blackbaud.com/skyapi/apis/school). However, it has been built so that other SKY API endpoints can easily be added in.

Future releases will add support for data creation, updates, and deletions.

See the [SKYAPI Wiki](https://github.com/Sekers/SKYAPI/wiki) for a list of the [endpoints currently supported](https://github.com/Sekers/SKYAPI/wiki#api-endpoints).

---

## Documentation

The SKYAPI module documentation is hosted in the [SKYAPI Wiki](https://github.com/Sekers/SKYAPI/wiki). Examples are included in the [Sample Usage Scripts folder](./Sample_Usage_Scripts).

---

## Developing and Contributing

Contact us on the [Grimadmin.com SKYAPI PowerShell Module Forum](https://www.grimadmin.com/forum/index.php?forum=7) if you would like to contribute.

After serious consideration, this project will be using a [simplified Gitflow workflow](https://www.grimadmin.com/article.php/simple-modified-gitflow-workflow) that cuts out the release branches, which are unnecessary when maintaining a single version in production workflow. The Master/Main branch will always be the latest stable version released and tagged with an updated version number anytime the Develop branch is merged into it. [Rebasing](https://www.atlassian.com/git/tutorials/merging-vs-rebasing) will occur if we need to streamline complex history.

You are also welcome to [fork](https://guides.github.com/activities/forking/) the project and then offer your changes back using a [pull request](https://guides.github.com/activities/forking/#making-a-pull-request).
