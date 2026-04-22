# Support

## Before Opening an Issue

- Check the [existing issues](https://github.com/recepzgrmh/Mac-Developer-Cleaner/issues) — your problem may already be reported or resolved.
- Make sure you are on the [latest release](https://github.com/recepzgrmh/Mac-Developer-Cleaner/releases/latest).

## Reporting a Bug

Open a [bug report](https://github.com/recepzgrmh/Mac-Developer-Cleaner/issues/new?template=bug_report.md) and include:

- macOS version
- DevReclaim version
- Steps to reproduce
- Expected vs actual behavior

## Requesting a Feature

Open a [feature request](https://github.com/recepzgrmh/Mac-Developer-Cleaner/issues/new?template=feature_request.md) describing the use case and what problem it solves.

## App Won't Open (Gatekeeper)

DevReclaim is ad-hoc signed. If macOS blocks the app:

1. Right-click `DevReclaim.app` → **Open** → **Open**
2. Or run in Terminal: `xattr -cr /Applications/DevReclaim.app`

This is a one-time step and is safe for apps you trust.
