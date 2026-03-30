# Awesome GitHub secret scanning  [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

> A curated list of awesome GitHub Advanced Security secret scanning resources.

## Secret Scanning Patterns
- [GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/code-security/reference/secret-security/supported-secret-scanning-patterns) - Supported secret scanning patterns
- [advanced-security/advanced-security-material](https://github.com/advanced-security/advanced-security-material/blob/main/GHAS-on-GHES-feature-matrix.md#secret-scanning) - GitHub Enterprise Server Version/Feature Matrix

## Secret Scanning Custom Patterns
- [advanced-security/secret-scanning-custom-patterns](https://github.com/advanced-security/secret-scanning-custom-patterns) - Examples of Custom Secret Scanning Patterns
- [advanced-security/secret-scanning-tools](https://github.com/advanced-security/secret-scanning-tools) - Testing Suite for GitHub Secret Scanning Custom Patterns

## Notifications
- [advanced-security/secret-scanning-review-action](https://github.com/advanced-security/secret-scanning-review-action) - Action to detect if a secret is initially detected in a PR commit
- [advanced-security/secret-scanning-notifications](https://github.com/advanced-security/secret-scanning-notifications) - A GitHub Action framework to send notifications to security manager team for any new or resolved secret scanning alerts based on a set frequency
- [advanced-security/teams-secret-scanning-notifier-azure-function](https://github.com/advanced-security/teams-secret-scanning-notifier-azure-function) - Microsoft Teams notifier for Secret Scanning alerts from GitHub Advanced Security, using a GitHub App and Azure Function
- [advanced-security/slack-secret-scanning-notifier-azure-function](https://github.com/advanced-security/slack-secret-scanning-notifier-azure-function) - Slack notifier for Secret Scanning alerts from GitHub Advanced Security, using a GitHub App and Azure Function
  
## Policy
- [advanced-security/policy-as-code](https://github.com/advanced-security/policy-as-code) - GitHub Advanced Security Policy as Code designed to allow users to configure their Risk threshold for security issues reported by GitHub Code Scanning, Secret Scanning and Dependabot Security.
- [advanced-security/probot-security-alerts](https://github.com/advanced-security/probot-security-alerts) - Sample GitHub App which monitors and enforces rules for code scanning, Dependabot, and secret scanning alerts

## Tools
- [kraiouchkine/ghes-secret-scanning-automation-tools](https://github.com/kraiouchkine/ghes-secret-scanning-automation-tools) - enable automatic resolution and reopening of Secret Scanning alerts on GitHub Enterprise Server
- [cisco-open/gitguardian-to-ghas-importer](https://github.com/cisco-open/gitguardian-to-ghas-importer) - A Python tool that automatically closes GitHub Advanced Security (GHAS) secret scanning alerts by matching them with previously triaged false positives from GitGuardian exports.

## Secret Remediation
- [advanced-security/GSSAR](https://github.com/advanced-security/GSSAR) - GitHub Secret Scanning Auto Remediator (GSSAR)
- [rtyley/bfg-repo-cleaner](https://rtyley.github.io/bfg-repo-cleaner/) - tool that's built and maintained by the open source community. It provides a faster, simpler alternative to git filter-repo for removing unwanted data.
- [newren/git-filter-repo](https://github.com/newren/git-filter-repo) - Quickly rewrite git repository history (filter-branch replacement)

# Contribute

Contributions welcome! Read the [contribution guidelines](CONTRIBUTING.md) first.

# Why

[What is an awesome list?](https://github.com/sindresorhus/awesome/blob/main/awesome.md)
