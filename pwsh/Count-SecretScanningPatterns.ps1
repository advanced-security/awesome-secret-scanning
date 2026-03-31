# Count-SecretScanningPatterns.ps1
# Fetches secret scanning pattern data from GitHub and Azure DevOps documentation
# and outputs a markdown summary of pattern counts.
#
# Adapted from https://github.com/felickz/scripts/blob/main/pwsh/Count-SecretScanningPatterns.ps1

param(
    [string]$OutputFile = ""
)

$script:hasErrors = $false

# Install the PowerShell-yaml module if not already installed
if (-not (Get-Module -Name PowerShell-yaml -ListAvailable)) {
    Install-Module -Name PowerShell-yaml -Scope CurrentUser -Force
}

# Resolve Liquid ifversion templates to a boolean for a given platform (ghec, ghes, or fpt)
function Resolve-LiquidBool {
    param(
        [object]$Value,
        [string]$Platform
    )
    if ($Value -is [bool]) { return $Value }
    $s = "$Value".Trim()
    if ($s -match '\{%\s*ifversion\s+(.+?)\s*%\}(\w+)\{%\s*else\s*%\}(\w+)\{%\s*endif\s*%\}') {
        $conditions = $matches[1] -split '\s+or\s+' | ForEach-Object { $_.Trim() }
        $ifMatch = $Platform -in $conditions
        $resolved = if ($ifMatch) { $matches[2] } else { $matches[3] }
        return $resolved -eq 'true'
    }
    return $s -eq 'True' -or $s -eq 'true'
}

# --- GitHub GHEC Data ---
$url = 'https://raw.githubusercontent.com/github/docs/main/src/secret-scanning/data/pattern-docs/ghec/public-docs.yml'
try {
    $data = Invoke-RestMethod -Uri $url | ConvertFrom-Yaml
} catch {
    Write-Error "Failed to fetch GitHub GHEC data from $url : $_"
    $script:hasErrors = $true
    $data = @()
}

$inventory = @()
foreach ($node in $data) {
    $inventory += New-Object PSObject -Property @{
        'Provider'            = $node.provider
        'SecretType'          = $node.secretType
        'HasPushProtection'   = (Resolve-LiquidBool $node.hasPushProtection 'ghec')
        'HasValidityCheck'    = (Resolve-LiquidBool $node.hasValidityCheck 'ghec')
        'HasVariants'         = $node.isduplicate
        'Base64Supported'     = (Resolve-LiquidBool $node.base64Supported 'ghec')
        'HasExtendedMetadata' = (Resolve-LiquidBool $node.hasExtendedMetadata 'ghec')
    }
}

$Providers = $inventory | Select-Object -Property Provider -Unique
$Push = $inventory | Where-Object { $_.HasPushProtection -eq $true } | Measure-Object | Select-Object -Property Count
$Validity = $inventory | Where-Object { $_.HasValidityCheck -eq $true } | Measure-Object | Select-Object -Property Count
$Variants = $inventory | Where-Object { $_.HasVariants -eq $true } | Measure-Object | Select-Object -Property Count
$Base64Supported = $inventory | Where-Object { $_.Base64Supported -eq $true } | Measure-Object | Select-Object -Property Count
$ExtendedMetadata = $inventory | Where-Object { $_.HasExtendedMetadata -eq $true } | Measure-Object | Select-Object -Property Count

# --- GHES Versions ---
$GHESInventory = @()
try {
    $ghesContentsUrl = 'https://api.github.com/repos/github/docs/contents/src/secret-scanning/data/pattern-docs'
    Write-Host "Fetching GHES versions from: $ghesContentsUrl"
    $ghesContents = Invoke-RestMethod -Uri $ghesContentsUrl -Headers @{ 'User-Agent' = 'Count-SecretScanningPatterns' }
    $ghesVersions = $ghesContents | Where-Object { $_.name -match '^ghes-\d+\.\d+$' } | ForEach-Object { $_.name -replace 'ghes-', '' } | Sort-Object { [version]$_ }
    Write-Host "Found $($ghesVersions.Count) GHES versions: $($ghesVersions -join ', ')"

    foreach ($ghesVer in $ghesVersions) {
        $ghesUrl = "https://raw.githubusercontent.com/github/docs/main/src/secret-scanning/data/pattern-docs/ghes-$ghesVer/public-docs.yml"
        try {
            $ghesData = Invoke-RestMethod -Uri $ghesUrl | ConvertFrom-Yaml
            $ghesValidityCount = ($ghesData | Where-Object { Resolve-LiquidBool $_.hasValidityCheck 'ghes' } | Measure-Object).Count
            $ghesPushCount = ($ghesData | Where-Object { Resolve-LiquidBool $_.hasPushProtection 'ghes' } | Measure-Object).Count
            $ghesBase64Count = ($ghesData | Where-Object { Resolve-LiquidBool $_.base64Supported 'ghes' } | Measure-Object).Count
            $ghesExtendedMetadataCount = ($ghesData | Where-Object { Resolve-LiquidBool $_.hasExtendedMetadata 'ghes' } | Measure-Object).Count
            $GHESInventory += New-Object PSObject -Property @{
                'GHESVersion'            = $ghesVer
                'Count'                  = $ghesData.Count
                'ValidityCheckCount'     = $ghesValidityCount
                'PushProtectionCount'    = $ghesPushCount
                'Base64Count'            = $ghesBase64Count
                'ExtendedMetadataCount'  = $ghesExtendedMetadataCount
            }
        } catch {
            Write-Warning "Failed to fetch GHES $ghesVer data: $_"
        }
    }
} catch {
    Write-Error "Failed to get GHES versions list: $_"
    $script:hasErrors = $true
}

# --- Azure DevOps Provider/Non-Provider Parsing ---
function ConvertFrom-AdoProviderMarkdown {
    param(
        [string]$Markdown
    )
    $results = @()
    $lines = $Markdown -split "`n"
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line.StartsWith('|')) { continue }
        if ($line -match '^\|\s*-+\s*\|') { continue }

        $matched = $false
        if (-not $matched -and $line -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|$') {
            $rule   = ($matches[1]).Trim()
            $token  = ($matches[2]).Trim()
            $push   = ($matches[3]).Trim()
            $user   = ($matches[4]).Trim()
            $valid  = ($matches[5]).Trim()
            $matched = $true
            $isNonProvider = $false
        }
        if (-not $matched -and $line -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*)\|\s*([^|]*)\|$') {
            $rule   = ($matches[1]).Trim()
            $token  = ($matches[2]).Trim()
            $push   = ''
            $user   = ($matches[3]).Trim()
            $valid  = ($matches[4]).Trim()
            $matched = $true
            $isNonProvider = $true
        }

        if ($matched) {
            if ($rule -eq 'Rule ID') { continue }
            if (-not $rule) { continue }

            $test = { param($v) if (-not $v) { return $false } return $v -match '(?i)green|checkmark|true|yes' }
            $results += [pscustomobject]@{
                RuleID           = $rule
                TokenName        = $token
                PushProtection   = $(if ($isNonProvider) { $false } else { & $test $push })
                UserAlerts       = (& $test $user)
                ValidityChecking = (& $test $valid)
                IsNonProvider    = $isNonProvider
            }
        }
    }
    return $results
}

$ADOProviderTable = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/provider-table.md' | Out-String
$ADOProviders = ConvertFrom-AdoProviderMarkdown -Markdown $ADOProviderTable
$ADOProvidersPush = $ADOProviders | Where-Object { $_.PushProtection }
$ADOProvidersValidity = $ADOProviders | Where-Object { $_.ValidityChecking }

$ADONonProviderTable = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/non-provider-table.md' | Out-String
$ADONonProviders = ConvertFrom-AdoProviderMarkdown -Markdown $ADONonProviderTable
$ADONonProvidersPush = $ADONonProviders | Where-Object { $_.PushProtection }
$ADONonProvidersValidity = $ADONonProviders | Where-Object { $_.ValidityChecking }

# --- GitHub Non-Provider & Copilot Patterns ---
$GHNonProviderMarkdown = $null
try {
    $GHNonProviderMarkdown = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/github/docs/refs/heads/main/content/code-security/reference/secret-security/supported-secret-scanning-patterns.md' | Out-String
} catch {
    Write-Error "Failed to fetch GitHub non-provider patterns markdown: $_"
    $script:hasErrors = $true
}

$GHNonProviderPatterns = @()
$GHCopilotPatterns = @()

if ($GHNonProviderMarkdown) {
    $inNonProviderSection = $false
    $inCopilotSection = $false
    $lines = $GHNonProviderMarkdown -split "`n"

    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()

        if ($trimmedLine -match '^###\s+Non-provider patterns') {
            $inNonProviderSection = $true
            $inCopilotSection = $false
            continue
        }
        if ($trimmedLine -match '^\{\%\s*data variables\.secret-scanning\.copilot-secret-scanning' -or $trimmedLine -match '^###.*copilot.*secret.*scanning') {
            $inCopilotSection = $true
            $inNonProviderSection = $false
            continue
        }
        if (($inNonProviderSection -or $inCopilotSection) -and $trimmedLine -match '^###\s+' -and $trimmedLine -notmatch 'copilot') {
            $inNonProviderSection = $false
            $inCopilotSection = $false
        }
        if ($inNonProviderSection -and $trimmedLine -match '^\|\s*Generic\s*\|\s*([^|]+?)\s*\|') {
            $tokenName = $matches[1].Trim()
            if ($tokenName -and $tokenName -ne 'Token') {
                $GHNonProviderPatterns += $tokenName
            }
        }
        if ($inCopilotSection -and $trimmedLine -match '^\|\s*(Generic)?\s*\|\s*([^|]+?)\s*\|') {
            $tokenName = $matches[2].Trim()
            if ($tokenName -and $tokenName -ne 'Token' -and $tokenName -ne 'Provider') {
                $GHCopilotPatterns += $tokenName
            }
        }
    }
}

$GHNonProviderCount = ($GHNonProviderPatterns | Select-Object -Unique).Count
$GHCopilotCount = ($GHCopilotPatterns | Select-Object -Unique).Count

# --- Build Markdown Output ---
$comment = @"
# GitHub

| [Secret Protection Inventory](https://docs.github.com/en/enterprise-cloud@latest/code-security/reference/secret-security/supported-secret-scanning-patterns) |$($(Get-Date -AsUTC).ToString('u')) |
| --- | --- |
| Number of Partner Secret Types | $($inventory.Count) ($($Variants.Count) with variants) |
| Number of Unique Partner Providers | $($Providers.Count) |
| Number of Secret Types with Push Protection | $($Push.Count) |
| Number of Secret Types with Validity Check | $($Validity.Count) |
| Number of Secret Types with Base64 Support | $($Base64Supported.Count) |
| Number of Secret Types with Extended Metadata | $($ExtendedMetadata.Count) |
| Non-Partner Patterns | [$($GHNonProviderCount)](https://docs.github.com/en/enterprise-cloud@latest/code-security/secret-scanning/secret-scanning-patterns#non-provider-patterns) (0 with validity checks) |
| Copilot Secret Scanning Patterns | [$($GHCopilotCount)](https://docs.github.com/en/enterprise-cloud@latest/code-security/secret-scanning/introduction/supported-secret-scanning-patterns#copilot-secret-scanning) |
| Inventory Commit History | [Docs](https://github.com/github/docs/blob/main/src/secret-scanning/data/pattern-docs/ghec/public-docs.yml)
| Secret Scanning Changelog | [Changelog](https://github.blog/changelog/?label=application-security) |

# GitHub Secret Scanning GitHub Enterprise Server | $($(Get-Date -AsUTC).ToString('u'))

| GHES Version| Count | Push Protection | Validity Check | Base64 | Extended Metadata |
| --- | --- | --- | --- | --- | --- |
$($GHESInventory | ForEach-Object { "| [$($_.GHESVersion)](https://docs.github.com/en/enterprise-server@$($_.GHESVersion)/code-security/reference/secret-security/supported-secret-scanning-patterns) | $($_.Count) | $($_.PushProtectionCount) | $($_.ValidityCheckCount) | $($_.Base64Count) | $($_.ExtendedMetadataCount) |" } | Out-String)

# Azure DevOps
| Secret Scanning Inventory |$($(Get-Date -AsUTC).ToString('u')) |
| --- | --- |
| Number of Partner Secret Types | [$($ADOProviders.Count)](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#partner-provider-patterns) |
| Number of Secret Types with Push Protection | $($ADOProvidersPush.Count + $ADONonProvidersPush.Count) |
| Number of Secret Types with Validity Check | $($ADOProvidersValidity.Count + $ADONonProvidersValidity.Count) |
| Non-Partner Patterns | [$($ADONonProviders.Count)](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#non-provider-patterns) ( $($ADONonProvidersValidity.Count) with validity checks) |
| Copilot Secret Scanning Patterns | 0 |
| Inventory Commit History | [Docs](https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/provider-table.md) [Docs NonPartner](https://raw.githubusercontent.com/MicrosoftDocs/azure-devops-docs/refs/heads/main/docs/repos/security/includes/non-provider-table.md)
| Secret Scanning Changes | [Commits](https://github.com/MicrosoftDocs/azure-devops-docs/commits/main/docs/repos/security/includes/provider-table.md) [Commits Non-Partner](https://github.com/MicrosoftDocs/azure-devops-docs/commits/main/docs/repos/security/includes/non-provider-table.md)|
"@

Write-Host $comment

if ($OutputFile) {
    $comment | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "`nMarkdown written to: $OutputFile"
}

if ($script:hasErrors) {
    Write-Warning "Some data sources encountered errors. Counts may be incomplete."
    exit 1
}
