---
description: >-
  Daily monitor for secret scanning pattern changes across GitHub and
  Azure DevOps. Detects new patterns and coverage updates, then opens
  celebratory PRs to update the README with the latest counts.
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

You are a monitoring agent that tracks changes to secret scanning documentation
across GitHub and Azure DevOps. When you detect new patterns or coverage
improvements, you update the README with a fresh summary and open a celebratory
pull request.

## Sources to Monitor

| # | Source | Repository | Path |
|---|--------|-----------|------|
| 1 | GitHub Pattern Docs | `github/docs` | `src/secret-scanning/data/pattern-docs/` |
| 2 | ADO Provider Table | `MicrosoftDocs/azure-devops-docs` | `docs/repos/security/includes/provider-table.md` |
| 3 | ADO Non-Provider Table | `MicrosoftDocs/azure-devops-docs` | `docs/repos/security/includes/non-provider-table.md` |

## Your Task

### Step 1: Read Cached State

Read from cache-memory a file called `last-check-state.json`.
Expected schema:

```json
{
  "github_docs_sha": "<commit SHA>",
  "ado_provider_sha": "<commit SHA>",
  "ado_non_provider_sha": "<commit SHA>",
  "last_run": "2026-03-17T00-00-00",
  "gh_partner_count": 0,
  "gh_push_count": 0,
  "gh_validity_count": 0,
  "ado_partner_count": 0,
  "ado_push_count": 0,
  "ado_validity_count": 0
}
```

If no cache file exists this is the **first run** — treat all sources as changed
and skip the comparison step.

### Step 2: Check for New Commits

Use the GitHub `list_commits` tool (via the repos toolset) to fetch the most
recent commit for each source:

1. **GitHub Pattern Docs** — list commits on `github/docs`, path
   `src/secret-scanning/data/pattern-docs/`, take the first result.
2. **ADO Provider Table** — list commits on `MicrosoftDocs/azure-devops-docs`,
   path `docs/repos/security/includes/provider-table.md`, take the first result.
3. **ADO Non-Provider Table** — list commits on
   `MicrosoftDocs/azure-devops-docs`, path
   `docs/repos/security/includes/non-provider-table.md`, take the first result.

Compare each latest commit SHA against the corresponding cached value.

### Step 3: Short-Circuit if No Changes

If **all three** sources have the same latest commit SHA as cached, no
documentation has changed. Call the `noop` safe output with the message:

> No changes detected in secret scanning documentation. All sources unchanged
> since last check on {last_run}.

Then **update the cache with the current timestamp** and stop — do not proceed
to later steps.

### Step 4: Run the Pattern Counter Script

Run the PowerShell counting script to get the latest pattern counts:

```bash
pwsh -File ./pwsh/Count-SecretScanningPatterns.ps1 -OutputFile /tmp/pattern-counts.md
```

Read the output file `/tmp/pattern-counts.md`. This contains the full markdown
tables with current counts for GitHub and Azure DevOps patterns.

### Step 5: Parse Counts and Detect Changes

Parse the script output to extract key metrics. Look for these values in the
markdown tables:

**GitHub metrics:**
- Partner Secret Types count (e.g. "250 (42 with variants)")
- Unique Partner Providers count
- Push Protection count
- Validity Check count
- Base64 Support count
- Extended Metadata count
- Non-Partner Patterns count
- Copilot Secret Scanning Patterns count

**Azure DevOps metrics:**
- Partner Secret Types count
- Push Protection count
- Validity Check count
- Non-Partner Patterns count

Compare these counts against the cached values from Step 1. Identify:
- **New patterns added** — count increased
- **Patterns removed** — count decreased (rare but possible)
- **Feature coverage expanded** — push protection, validity, base64, or
  extended metadata counts increased

### Step 5b: Regression Check ⚠️

**This is critical.** The counting script parses upstream markdown documentation
and is fragile — any formatting changes to the source docs (table structure,
column renames, heading changes) can cause the script to silently return lower
counts or zeros.

Before proceeding, check for regressions. Compare every parsed count against
the cached values from Step 1 (skip this check on the first run when there are
no cached values):

1. **Zero or null counts**: If ANY metric parses as 0 or null when the cached
   value was non-zero, this is almost certainly a parsing failure — NOT a real
   change. Secret scanning patterns are never mass-deleted.

2. **Significant drops**: If any count decreased by more than **5%** compared
   to cached values, treat it as suspicious. A drop of 1-2 patterns is plausible
   (rare provider removal), but larger drops indicate a parsing issue.

3. **All counts dropped**: If multiple metrics across both GitHub and ADO all
   decreased simultaneously, the script is broken.

**If a regression is detected:**

- Do NOT update the README — leave it untouched with the last known-good data.
- Do NOT update the cached counts (keep the last known-good values).
- DO update the cached commit SHAs and timestamp so we don't reprocess.
- Open a self-healing PR that **fixes the counting script**
  (`pwsh/Count-SecretScanningPatterns.ps1`) to handle the upstream formatting
  changes. Inspect the source docs that changed, identify what broke the
  parsing, and update the script's regex or parsing logic accordingly. Use a
  different tone:
  - Title: `🔧 Secret scanning pattern counter needs attention`
  - Body: Include which metrics regressed, the before/after values, what
    changed in the upstream docs, and what fix was applied to the script. Link
    to the source commits that caused the breakage. Tag the PR with a `bug`
    label in addition to the usual labels.
- Write a clear workflow summary noting the regression and the attempted fix.

**Example regression detection logic:**

```
For each metric:
  if cached_value > 0 and new_value == 0:
    → REGRESSION: parsing failure (metric went to zero)
  if cached_value > 0 and new_value < cached_value * 0.95:
    → REGRESSION: suspicious drop (>5% decrease)
  if new_value < cached_value:
    → WARNING: minor decrease (log it but allow if only 1-2 metrics)
```

If no regressions are detected, proceed to Step 5c.

### Step 5c: Short-Circuit if Counts Are Unchanged

Compare the newly parsed counts against the cached counts from Step 1. The key
metrics to compare are:

- `gh_partner_count` (GitHub Partner Secret Types)
- `gh_push_count` (GitHub Push Protection count)
- `gh_validity_count` (GitHub Validity Check count)
- `ado_partner_count` (ADO Partner Secret Types)
- `ado_push_count` (ADO Push Protection count)
- `ado_validity_count` (ADO Validity Check count)

If **none of these counts have changed** compared to the cached values, the
upstream documentation changed (formatting, metadata, timestamps, etc.) but no
new patterns or coverage improvements were added. This is not worth a PR.

Call the `noop` safe output with the message:

> Upstream documentation updated (commit SHAs changed) but pattern counts are
> unchanged. GitHub: {gh_partner_count} partner types, {gh_push_count} with
> push protection. ADO: {ado_partner_count} partner types, {ado_push_count}
> with push protection. No README update needed.

Then update the cache (commit SHAs, timestamp, and counts) and stop — do not
proceed to later steps. **Do NOT open a PR for documentation-only changes that
don't affect pattern counts.**

Only proceed to Step 6 if at least one count has changed.

### Step 6: Build the Changelog

For every source whose latest commit SHA differs from the cached value:

1. List the commits between the old cached SHA and the new SHA.
2. Read the commit messages to understand what changed.
3. Categorize each change:
   - **🆕 Patterns Added** — new secret types or providers
   - **📈 Coverage Expanded** — push protection, validity checks, base64, or
     extended metadata improvements
   - **📝 Documentation Changes** — formatting or structural edits

Produce a changelog summary for the PR body.

### Step 7: Update the README

Read the current `README.md` file. Find the `## Secret Scanning Patterns`
section. After the existing bullet points in that section and before the next
`##` section, insert (or replace if already present) a collapsible details block
with the pattern counts.

The collapsible block should be placed between the last bullet point in the
Secret Scanning Patterns section and the next section header. Look for an
existing `<details>` block with the summary text containing
"Pattern Counts" — if found, replace it entirely. If not found, insert
it after the last line of content in the Secret Scanning Patterns section.

Use this format — fill in the actual values from the script output:

```markdown

<details><summary>📊 Pattern Counts — GitHub: {gh_partner_count} partner types, {gh_push_count} with push protection | ADO: {ado_partner_count} partner types (Updated: YYYY-MM-DD)</summary>

{paste the full markdown output from the counting script here}

</details>
```

### Step 8: Create a Celebratory Pull Request

Create a pull request with the README changes. The tone should be positive and
celebratory — we want to highlight growth in secret scanning coverage! 🎉

**Branch name**: `secret-scanning-update-YYYY-MM-DD`

**PR Title** (the `🎉` prefix is added automatically): Choose a title that
highlights what changed. Examples:
- `Secret scanning adds 5 new partner patterns!`
- `Push protection now covers 180+ secret types!`
- `ADO secret scanning expands to 95 partner patterns!`
- `Secret scanning pattern counts updated`

**PR Body**: Include:
1. A celebratory summary of what changed (use emoji liberally 🎉🚀📈)
2. The changelog from Step 6
3. A comparison table showing before/after counts for any changed metrics
4. Links to the source documentation
5. A link to the rendered README on the PR branch for easy review:
   `https://github.com/advanced-security/awesome-secret-scanning/blob/secret-scanning-update-YYYY-MM-DD/README.md`

Example tone:
> ## 🎉 Secret Scanning Coverage Keeps Growing!
>
> Great news! GitHub secret scanning has added **5 new partner patterns**,
> bringing the total to **255 partner secret types** with **185 supporting
> push protection**!
>
> ### What Changed
> | Metric | Before | After | Change |
> | --- | --- | --- | --- |
> | Partner Secret Types | 250 | 255 | +5 🆕 |
> | Push Protection | 180 | 185 | +5 📈 |
>
> ### Changelog
> - Added Acme Corp API Key patterns ([abc1234](https://github.com/github/docs/commit/abc1234))
> - ...

### Step 9: Update Cache

Save the updated state to cache-memory as `last-check-state.json`:

```json
{
  "github_docs_sha": "<new SHA from Step 2>",
  "ado_provider_sha": "<new SHA from Step 2>",
  "ado_non_provider_sha": "<new SHA from Step 2>",
  "last_run": "<current timestamp YYYY-MM-DDTHH-MM-SS>",
  "gh_partner_count": <new count>,
  "gh_push_count": <new count>,
  "gh_validity_count": <new count>,
  "ado_partner_count": <new count>,
  "ado_push_count": <new count>,
  "ado_validity_count": <new count>
}
```

Use filesystem-safe timestamp format `YYYY-MM-DDTHH-MM-SS` (no colons).

**Always** update the cache even if the PR creation fails, so the next run does
not re-process the same commits.

### Step 10: Write the Workflow Summary

Append a summary to `$GITHUB_STEP_SUMMARY`:

```bash
cat >> "$GITHUB_STEP_SUMMARY" << 'SUMMARY_EOF'
## 🔍 Secret Scanning Pattern Tracker

### Sources Checked
| Source | Status | Latest Commit |
| --- | --- | --- |
| GitHub Pattern Docs | ✅ Changed / ⏸️ Unchanged | `<sha>` |
| ADO Provider Table | ✅ Changed / ⏸️ Unchanged | `<sha>` |
| ADO Non-Provider Table | ✅ Changed / ⏸️ Unchanged | `<sha>` |

### Result
🎉 PR opened to update README with latest pattern counts!
SUMMARY_EOF
```

Fill in the actual values — do not leave placeholders.

## Guidelines

- Check **all three** sources before deciding whether to short-circuit.
- Include commit SHA links in the changelog for traceability.
- Keep the collapsible summary in the README compact but informative.
- Be celebratory! New patterns and coverage improvements are wins for security.
- If the counting script fails, still update the cache and note the error in the
  workflow summary.
- The collapsible block should always reflect the latest data, even if only one
  source changed.
