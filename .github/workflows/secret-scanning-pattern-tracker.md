---
description: >-
  Daily monitor for secret scanning pattern changes across GitHub and
  Azure DevOps. Detects new patterns and coverage updates, then opens
  celebratory PRs to update the README with the latest counts.
engine:
  model: claude-sonnet-4.6
on:
  schedule: daily
permissions:
  contents: read
features:
  copilot-requests: true
tools:
  github:
    toolsets: [repos]
  cache-memory: true
network:
  allowed:
    - defaults
    - github
safe-outputs:
  create-pull-request:
    max: 1
    labels: [automation, secret-scanning]
    title-prefix: "🎉 "
    draft: false
    expires: 14
    preserve-branch-name: true
  noop:
    max: 1
steps:
  - name: Install PowerShell-yaml module
    run: pwsh -c "Install-Module -Name PowerShell-yaml -Scope CurrentUser -Force -AcceptLicense 2>/dev/null"
---

# 🔍 Secret Scanning Pattern Tracker

## ⚠️ CRITICAL RULE — Read This First

**You MUST call exactly one safe output tool before finishing — no exceptions.**

- Call `noop` if no README update is needed.
- Call `create-pull-request` if the README was updated.
- If anything fails or errors, call `noop` with an error description.
- **Never finish without calling a safe output.** Doing so files a failure issue.

## Overview

You monitor secret scanning documentation across GitHub and Azure DevOps.
When pattern counts change, you update the README and open a PR.

## Step 1 — Check for Source Changes

First, read `last-check-state.json` from cache-memory. Schema:

```json
{
  "github_docs_sha": "<SHA>",
  "ado_provider_sha": "<SHA>",
  "ado_non_provider_sha": "<SHA>",
  "last_run": "YYYY-MM-DDTHH-MM-SS"
}
```

Then fetch the latest commit SHA for each source using `list_commits` (1 result each):

1. `github/docs` — path `src/secret-scanning/data/pattern-docs/`
2. `MicrosoftDocs/azure-devops-docs` — path `docs/repos/security/includes/provider-table.md`
3. `MicrosoftDocs/azure-devops-docs` — path `docs/repos/security/includes/non-provider-table.md`

If **all three SHAs match** the cache → call `noop` with message
"No changes detected since {last_run}" → update cache timestamp → **stop**.

If cache is missing (first run), treat all sources as changed.

## Step 2 — Run the Counting Script

Run: `pwsh -File ./pwsh/Count-SecretScanningPatterns.ps1 -OutputFile /tmp/pattern-counts.md`

If the script fails or exits non-zero, call `noop` with the error message,
update the cache SHAs, and **stop**.

Read `/tmp/pattern-counts.md` — this has the full markdown output.

## Step 3 — Compare Counts Against README

Read the current `README.md` and extract the published counts from the
`<details><summary>📊 Pattern Counts` block:

- GitHub: Partner Secret Types, Push Protection count
- ADO: Partner Secret Types, Push Protection count

Parse the same counts from the script output (Step 2).

**Regression check:** If any count dropped to 0, or decreased by more than 5%
compared to the README, this is a script parsing failure — NOT a real change.
Call `noop` with a message listing the regressed metrics and their
before/after values. Update the cache SHAs and **stop**.

**No change check:** If all counts match the README, the upstream change was
cosmetic (no actual pattern count change). Call `noop` with a message like
"Counts unchanged: GitHub {N} partners, ADO {N} partners". Update the cache
SHAs and **stop**.

## Step 4 — Update README and Open PR

Only reach this step if counts actually changed and no regressions detected.

1. Read `README.md`. Find the existing `<details>` block whose summary contains
   "Pattern Counts" and replace it entirely. Use this format:

   ```
   <details><summary>📊 Pattern Counts — GitHub: {N} partner types, {N} with push protection | ADO: {N} partner types (Updated: YYYY-MM-DD)</summary>

   {full script output from /tmp/pattern-counts.md}

   </details>
   ```

2. Call `create-pull-request` with:
   - **Branch**: `secret-scanning-update-YYYY-MM-DD`
   - **Title**: A short celebratory summary (e.g. "Secret scanning adds 5 new partner patterns!")
   - **Body**: Before/after comparison table, links to source docs

3. Update cache-memory `last-check-state.json` with new SHAs and timestamp
   (format `YYYY-MM-DDTHH-MM-SS`, no colons).

## Guidelines

- **Always call a safe output before finishing** — this is the #1 priority.
- Always update the cache SHAs so we don't reprocess the same commits.
- Be celebratory in PR titles and bodies 🎉🚀📈
- Keep the collapsible README block compact but informative.
