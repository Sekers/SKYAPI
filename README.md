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

At present, this module is focused on working with the Blackbaud SKY API [Education Management School API](https://developer.blackbaud.com/skyapi/apis/school). However, it has been built so that other SKY API endpoints can easily be added in (Raiser's Edge NXT, Financial Edge NXT, Church Management, etc.).

See the [SKYAPI Wiki](https://github.com/Sekers/SKYAPI/wiki) for a list of the [endpoints currently supported](https://github.com/Sekers/SKYAPI/wiki#api-endpoints).

---

## Documentation

The SKYAPI module documentation is hosted in the [SKYAPI Wiki](https://github.com/Sekers/SKYAPI/wiki). Examples are included in the [Sample Usage Scripts folder](./Sample_Usage_Scripts).

---

## Developing and Contributing

This project is developed using a [simplified Gitflow workflow](https://www.grimadmin.com/article.php/simple-modified-gitflow-workflow) that cuts out the release branches, which are unnecessary when maintaining only a single version for production. The Master/Main branch will always be the latest stable version released and tagged with an updated version number anytime the Develop branch is merged into it. [Rebasing](https://www.atlassian.com/git/tutorials/merging-vs-rebasing) will occur if we need to streamline complex history.

You are welcome to [fork](https://guides.github.com/activities/forking/) the project and then offer your changes back using a [pull request](https://guides.github.com/activities/forking/#making-a-pull-request).
