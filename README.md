# Awesome GitHub secret scanning  [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

> A curated list of awesome GitHub Advanced Security Secret Protection resources.
> We acknoledge that there are many secret scanners out there that are pretty awesome, but this repo will keep the list directly related to Advanced Security features.

## Secret Scanning Patterns
- [GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/code-security/reference/secret-security/supported-secret-scanning-patterns) - Supported secret scanning patterns
- [advanced-security/advanced-security-material](https://github.com/advanced-security/advanced-security-material/blob/main/GHAS-on-GHES-feature-matrix.md#secret-scanning) - GitHub Enterprise Server Version/Feature Matrix

<details><summary>📊 Pattern Counts — GitHub: 522 partner types, 463 with push protection | ADO: 332 partner types (Updated: 2026-09-01)</summary>

# GitHub

| [Secret Protection Inventory](https://docs.github.com/en/enterprise-cloud@latest/code-security/reference/secret-security/supported-secret-scanning-patterns) |2026-09-01 03:47:14Z |
| --- | --- |
| Number of Partner Secret Types | 522 (62 with variants) |
| Number of Unique Partner Providers | 202 |
| Number of Secret Types with Push Protection | 463 |
| Number of Secret Types with Validity Check | 165 |
| Number of Secret Types with Base64 Support | 21 |
| Number of Secret Types with Extended Metadata | 70 |
| Non-Partner Patterns | [10](https://docs.github.com/en/enterprise-cloud@latest/code-security/secret-scanning/secret-scanning-patterns#non-provider-patterns) (0 with validity checks) |
| Copilot Secret Scanning Patterns | [1](https://docs.github.com/en/enterprise-cloud@latest/code-security/secret-scanning/introduction/supported-secret-scanning-patterns#copilot-secret-scanning) |
| Inventory Commit History | [Docs](https://github.com/github/docs/blob/main/src/secret-scanning/data/pattern-docs/ghec/public-docs.yml)
| Secret Scanning Changelog | [Changelog](https://github.blog/changelog/?label=application-security) |

<details><summary>GHES Versions / Count</summary>
<p>

| GHES Version | Count | Push Protection | Validity Check | Base64 | Extended Metadata |
| --- | --- | --- | --- | --- | --- |
| [3.14](https://docs.github.com/en/enterprise-server@3.14/code-security/reference/secret-security/supported-secret-scanning-patterns) | 318 | 190 | 9 | 0 | 0 |
| [3.15](https://docs.github.com/en/enterprise-server@3.15/code-security/reference/secret-security/supported-secret-scanning-patterns) | 284 | 181 | 5 | 0 | 0 |
| [3.16](https://docs.github.com/en/enterprise-server@3.16/code-security/reference/secret-security/supported-secret-scanning-patterns) | 311 | 192 | 5 | 0 | 0 |
| [3.17](https://docs.github.com/en/enterprise-server@3.17/code-security/reference/secret-security/supported-secret-scanning-patterns) | 338 | 198 | 5 | 0 | 0 |
| [3.18](https://docs.github.com/en/enterprise-server@3.18/code-security/reference/secret-security/supported-secret-scanning-patterns) | 361 | 242 | 5 | 0 | 0 |
| [3.19](https://docs.github.com/en/enterprise-server@3.19/code-security/reference/secret-security/supported-secret-scanning-patterns) | 448 | 341 | 5 | 4 | 0 |
| [3.20](https://docs.github.com/en/enterprise-server@3.20/code-security/reference/secret-security/supported-secret-scanning-patterns) | 478 | 365 | 122 | 20 | 0 |
| [3.21](https://docs.github.com/en/enterprise-server@3.21/code-security/reference/secret-security/supported-secret-scanning-patterns) | 501 | 417 | 127 | 20 | 5 |
| [3.22](https://docs.github.com/en/enterprise-server@3.22/code-security/reference/secret-security/supported-secret-scanning-patterns) | 519 | 458 | 131 | 21 | 5 |


</p>
</details>

# Azure DevOps
| Secret Scanning Inventory |2026-09-01 03:47:14Z |
| --- | --- |
| Number of Partner Secret Types | [332](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#partner-provider-patterns) |
| Number of Secret Types with Push Protection | 171 |
| Number of Secret Types with Validity Check | 231 |
| Non-Partner Patterns | [18](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#non-provider-patterns) ( 6 with validity checks) |
| Copilot Secret Scanning Patterns | 0 |
| Inventory Commit History | [Docs](https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/provider-table.md) [Docs NonPartner](https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/non-provider-table.md)
| Secret Scanning Changes | [Commits](https://github.com/MicrosoftDocs/azure-devops-docs/commits/main/docs/repos/security/includes/provider-table.md) [Commits Non-Partner](https://github.com/MicrosoftDocs/azure-devops-docs/commits/main/docs/repos/security/includes/non-provider-table.md)|

</details>

## Secret Scanning Custom Patterns

- [advanced-security/secret-scanning-custom-patterns](https://github.com/advanced-security/secret-scanning-custom-patterns) - Examples of Custom Secret Scanning Patterns
- [advanced-security/secret-scanning-tools](https://github.com/advanced-security/secret-scanning-tools) - Testing Suite for GitHub Secret Scanning Custom Patterns
- [advanced-security/secret-protection-custom-pattern-automation](https://github.com/advanced-security/secret-protection-custom-pattern-automation) - Automate GitHub secret protection custom patterns

## Notifications
- [advanced-security/secret-scanning-review-action](https://github.com/advanced-security/secret-scanning-review-action) - Action to detect if a secret is initially detected in a PR commit
- [advanced-security/secret-scanning-notifications](https://github.com/advanced-security/secret-scanning-notifications) - A GitHub Action framework to send notifications to security manager team for any new or resolved secret scanning alerts based on a set frequency
- [advanced-security/teams-secret-scanning-notifier-azure-function](https://github.com/advanced-security/teams-secret-scanning-notifier-azure-function) - Microsoft Teams notifier for Secret Scanning alerts from GitHub Advanced Security, using a GitHub App and Azure Function
- [advanced-security/slack-secret-scanning-notifier-azure-function](https://github.com/advanced-security/slack-secret-scanning-notifier-azure-function) - Slack notifier for Secret Scanning alerts from GitHub Advanced Security, using a GitHub App and Azure Function
  
## Policy
- [advanced-security/policy-as-code](https://github.com/advanced-security/policy-as-code) - GitHub Advanced Security Policy as Code designed to allow users to configure their Risk threshold for security issues reported by GitHub Code Scanning, Secret Scanning and Dependabot Security.
- [advanced-security/probot-security-alerts](https://github.com/advanced-security/probot-security-alerts) - Sample GitHub App which monitors and enforces rules for code scanning, Dependabot, and secret scanning alerts

## Tools
- [nicolaswill/ghes-secret-scanning-automation-tools](https://github.com/nicolaswill/ghes-secret-scanning-automation-tools) - enable automatic resolution and reopening of Secret Scanning alerts on GitHub Enterprise Server
- [cisco-open/gitguardian-to-ghas-importer](https://github.com/cisco-open/gitguardian-to-ghas-importer) - A Python tool that automatically closes GitHub Advanced Security (GHAS) secret scanning alerts by matching them with previously triaged false positives from GitGuardian exports.

## Secret Remediation
- [advanced-security/GSSAR](https://github.com/advanced-security/GSSAR) - GitHub Secret Scanning Auto Remediator (GSSAR)
- [rtyley/bfg-repo-cleaner](https://rtyley.github.io/bfg-repo-cleaner/) - tool that's built and maintained by the open source community. It provides a faster, simpler alternative to git filter-repo for removing unwanted data.
- [newren/git-filter-repo](https://github.com/newren/git-filter-repo) - Quickly rewrite git repository history (filter-branch replacement)

# Contribute

Contributions welcome! Read the [contribution guidelines](CONTRIBUTING.md) first.

# Why

[What is an awesome list?](https://github.com/sindresorhus/awesome/blob/main/awesome.md)
