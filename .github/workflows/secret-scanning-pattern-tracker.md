---
description: >-
  Daily monitor for secret scanning pattern changes across GitHub and
  Azure DevOps. Detects new patterns and coverage updates, then opens
  celebratory PRs to update the README with the latest counts.
model: auto
on:
  schedule: daily
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write
tools:
  github:
    toolsets: [repos]
network:
  allowed:
    - defaults
    - github
    - learn.microsoft.com
safe-outputs:
  create-pull-request:
    max: 1
    labels: [automation, secret-scanning]
    title-prefix: "🎉 "
    draft: false
    expires: 14
    preserve-branch-name: true
    allowed-files:
      - README.md
    protected-files: allowed
  noop:
    max: 1
    report-as-issue: false
steps:
  - name: Count secret scanning patterns on the host
    shell: pwsh
    run: |
      New-Item -ItemType Directory -Path /tmp/gh-aw -Force | Out-Null
      ./pwsh/Count-SecretScanningPatterns.ps1 -OutputFile /tmp/gh-aw/pattern-counts.md
---

# 🔍 Secret Scanning Pattern Tracker

## ⚠️ CRITICAL RULE — Read This First

**You MUST call exactly one safe output tool before finishing — no exceptions.**

- Call `noop` if no README update is needed.
- Call `create-pull-request` if the README was updated.
- If anything fails or errors, call `report_incomplete` with a short reason and the error details.
- **Never finish without calling a safe output.** Doing so files a failure issue.

## Overview

You monitor secret scanning documentation across GitHub and Azure DevOps.
When pattern counts change, you update the README and open a PR.

## Step 1 — Read the Pattern Counts

The host setup step runs `pwsh/Count-SecretScanningPatterns.ps1` before the
agent starts. It installs and imports PowerShell-yaml on the host, fetches
GitHub data and the published Microsoft Learn ADO tables, and fails the job
if a required source cannot be fetched or parsed.

Read `/tmp/gh-aw/pattern-counts.md`. This shared file has the full markdown
output. If it is missing or empty, call `report_incomplete` and stop.
Do not install modules or rerun the script inside the agent sandbox.

Counts are fetched every run. Do not query or compare commit SHAs from
`MicrosoftDocs/azure-devops-docs`, which is no longer publicly accessible.

## Step 2 — Compare Counts Against README

Read the current `README.md` and extract **ALL** published counts from the
`<details><summary>📊 Pattern Counts` block. You MUST extract these fields:

**GitHub metrics:**
- Partner Secret Types (the number before "with variants")
- Push Protection count
- Unique Partner Providers
- Validity Check count
- Base64 Support count
- Extended Metadata count
- Non-Partner Patterns count (the number in brackets)
- Copilot Secret Scanning Patterns count (the number in brackets)

**ADO metrics:**
- Partner Secret Types
- Push Protection count
- Non-Partner Patterns count

Parse the **same fields** from the script output (Step 1).

**Regression check — MANDATORY before any PR:**

Compare EVERY metric above between script output and README. Flag a
regression if ANY of these are true:

1. A count dropped to 0 when the README had a non-zero value
2. A count decreased by more than 5% compared to the README
3. A count that existed in the README is missing from script output

If ANY regression is detected:
- Call `report_incomplete` with reason `Regression detected` and details
  listing EACH regressed metric with its before (README) and after (script)
  values
- **Do NOT create a PR** — this is a script parsing failure, not a real change
- Example: "Regression detected: Non-Partner Patterns 10→0, Copilot 1→0.
  Likely a docs format change breaking the parser."

**No change check:** If all counts match the README, the upstream change was
cosmetic (no actual pattern count change). Call `noop` with a message like
"Counts unchanged: GitHub {N} partners, ADO {N} partners" and **stop**.

## Step 3 — Update README and Open PR

Only reach this step if counts actually changed and no regressions detected.

1. Read `README.md`. Find the existing `<details>` block whose summary contains
   "Pattern Counts" and replace it entirely. Use this format:

   ```
   <details><summary>📊 Pattern Counts — GitHub: {N} partner types, {N} with push protection | ADO: {N} partner types (Updated: YYYY-MM-DD)</summary>

   {full script output from /tmp/gh-aw/pattern-counts.md}

   </details>
   ```

2. Call `create-pull-request` with:
   - **Branch**: `secret-scanning-update-YYYY-MM-DD`
   - **Title**: A short celebratory summary (e.g. "Secret scanning adds 5 new partner patterns!")
   - **Body**: Before/after comparison table, links to source docs

## Guidelines

- **Always call a safe output before finishing** — this is the #1 priority.
- Be celebratory in PR titles and bodies 🎉🚀📈
- Keep the collapsible README block compact but informative.
