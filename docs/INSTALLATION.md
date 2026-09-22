# Installation Guide

## Prerequisites

Install PowerShell 7 or later on Windows 10/11. No PowerShell Gallery package is required; SQLite is accessed through the operating system SQLite library.

## Install

From the repository root:

```powershell
pwsh -NoProfile -File ./src/Local/ResearchAutomation.Local/Install.ps1
```

The installer creates runtime folders, creates `config/config.json` only when absent, initializes `queue/queue.db`, writes an installation log, runs all self-tests, and prints a summary. Re-running it is safe.

## Run and verify

```powershell
pwsh -NoProfile -File ./src/Local/ResearchAutomation.Local/Run-Agent.ps1 -SelfTest
```

A healthy installation reports every health row as `PASS` and exits with code 0. The dashboard also displays the platform version, build number, and capability registry. `DISABLED` capabilities are intentional scope boundaries and do not represent health failures. Inspect the current date's files in `logs` when a check fails.

## Configuration

Paths in `config/config.json` must be relative and remain inside the application directory. The version must be valid SemVer, the build must use `YYYYMMDD.NNN`, and every required capability must be Boolean. Log level accepts `Debug`, `Information`, `Warning`, or `Error`. Do not place secrets in this file.

### Zotero read-only connector

Set `zotero.preferredConnector` to `SQLite` or `WebApi`.

- SQLite: set `databasePath` to the absolute `zotero.sqlite` path and optionally set `storageRoot` to the Zotero data directory. The connector opens the database read-only.
- Web API: set `libraryType` to `users` or `groups`, provide `libraryId`, and retain the HTTPS API base URL. Put the API key in the environment variable named by `apiKeyEnvironmentVariable`; never store the key in `config.json`.

The default empty library paths and IDs are safe placeholders. The health dashboard validates connector availability; use `Test-RapZoteroConnection` to verify a configured library.
