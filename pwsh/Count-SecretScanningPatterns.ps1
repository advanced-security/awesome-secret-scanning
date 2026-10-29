# Count-SecretScanningPatterns.ps1
# Fetches secret scanning pattern data from GitHub and Azure DevOps documentation
# and outputs a markdown summary of pattern counts.
#
# Adapted from https://github.com/felickz/scripts/blob/main/pwsh/Count-SecretScanningPatterns.ps1

param(
    [string]$OutputFile = ""
)

$ErrorActionPreference = 'Stop'

# Install the PowerShell-yaml module if not already installed
if (-not (Get-Module -Name PowerShell-yaml -ListAvailable)) {
    Install-Module -Name PowerShell-yaml -Scope CurrentUser -Force -ErrorAction Stop
}
Import-Module PowerShell-yaml -ErrorAction Stop

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
    if (-not $data -or @($data | Where-Object { -not $_.provider -or -not $_.secretType }).Count) {
        throw 'GitHub GHEC pattern data is empty or invalid.'
    }
} catch {
    throw "Failed to fetch GitHub GHEC data from $url : $_"
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
    if (-not $ghesVersions) { throw 'No GHES versions found.' }
    Write-Host "Found $($ghesVersions.Count) GHES versions: $($ghesVersions -join ', ')"

    foreach ($ghesVer in $ghesVersions) {
        $ghesUrl = "https://raw.githubusercontent.com/github/docs/main/src/secret-scanning/data/pattern-docs/ghes-$ghesVer/public-docs.yml"
        try {
            $ghesData = Invoke-RestMethod -Uri $ghesUrl | ConvertFrom-Yaml
            if (-not $ghesData -or @($ghesData | Where-Object { -not $_.provider -or -not $_.secretType }).Count) {
                throw "GHES $ghesVer pattern data is empty or invalid."
            }
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
            throw "Failed to fetch GHES $ghesVer data: $_"
        }
    }
} catch {
    throw "Failed to get GHES data: $_"
}

# --- Azure DevOps Provider/Non-Provider Parsing ---
function ConvertFrom-AdoDocumentation {
    param(
        [string]$Html,
        [string]$Section,
        [switch]$NonProvider
    )
    $sectionPattern = '(?is)<h[1-6]\b[^>]*\bid=["'']' + [regex]::Escape($Section) +
        '["''][^>]*>.*?</h[1-6]>(?<content>.*?)(?=<h[1-3]\b|\z)'
    $sectionMatch = [regex]::Match($Html, $sectionPattern)
    $table = [regex]::Match($sectionMatch.Groups['content'].Value, '(?is)<table\b[^>]*>.*?</table>')
    if (-not $table.Success) { throw "ADO documentation table '$Section' not found." }

    $results = @()
    foreach ($row in [regex]::Matches($table.Value, '(?is)<tr\b[^>]*>(.*?)</tr>')) {
        $cells = @([regex]::Matches($row.Groups[1].Value, '(?is)<td\b[^>]*>(.*?)</td>') | ForEach-Object {
            $cell = $_.Groups[1].Value -replace '(?is)<img\b[^>]*\balt=["'']([^"'']*)["''][^>]*>', '$1'
            [System.Net.WebUtility]::HtmlDecode(($cell -replace '<[^>]+>', '')).Trim()
        })
        if (-not $cells.Count) { continue }
        $expectedColumns = if ($NonProvider) { 4 } else { 5 }
        if ($cells.Count -ne $expectedColumns -or -not $cells[0] -or -not $cells[1]) {
            throw "Invalid row in ADO documentation table '$Section'."
        }
        $test = { param($v) return $v -match '(?i)green|check\s*mark|true|yes' }
        $results += [pscustomobject]@{
            RuleID           = $cells[0]
            TokenName        = $cells[1]
            PushProtection   = $(if ($NonProvider) { $false } else { & $test $cells[2] })
            UserAlerts       = (& $test $cells[$expectedColumns - 2])
            ValidityChecking = (& $test $cells[$expectedColumns - 1])
            IsNonProvider    = [bool]$NonProvider
        }
    }
    if (-not $results.Count) { throw "ADO documentation table '$Section' is empty." }
    return $results
}

$ADODocsUrl = 'https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops'
$ADODocumentation = (Invoke-WebRequest -Uri $ADODocsUrl).Content
$ADOProviders = @(ConvertFrom-AdoDocumentation -Html $ADODocumentation -Section 'partner-provider-patterns')
$ADOProvidersPush = $ADOProviders | Where-Object { $_.PushProtection }
$ADOProvidersValidity = $ADOProviders | Where-Object { $_.ValidityChecking }

$ADONonProviders = @(ConvertFrom-AdoDocumentation -Html $ADODocumentation -Section 'non-provider-patterns' -NonProvider)
$ADONonProvidersPush = $ADONonProviders | Where-Object { $_.PushProtection }
$ADONonProvidersValidity = $ADONonProviders | Where-Object { $_.ValidityChecking }

# --- GitHub Non-Provider & Copilot Patterns ---
$GHNonProviderMarkdown = $null
try {
    $GHNonProviderMarkdown = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/github/docs/refs/heads/main/content/code-security/reference/secret-security/supported-secret-scanning-patterns.md' | Out-String
} catch {
    throw "Failed to fetch GitHub non-provider patterns markdown: $_"
}

$GHNonProviderPatterns = @()
$GHCopilotPatterns = @()

if ($GHNonProviderMarkdown) {
    $inNonProviderSection = $false
    $inCopilotSection = $false
    $lines = $GHNonProviderMarkdown -split "`n"

    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()

        # Match both old "### Non-provider patterns" and new "## Supported generic patterns"
        if ($trimmedLine -match '^#{2,3}\s+(Non-provider patterns|Supported generic patterns)') {
            $inNonProviderSection = $true
            $inCopilotSection = $false
            continue
        }
        # Match both old Copilot data variable/heading and new "## Supported AI-detected patterns"
        if ($trimmedLine -match '^\{\%\s*data variables\.secret-scanning\.copilot-secret-scanning' -or
            $trimmedLine -match '^#{2,3}.*copilot.*secret.*scanning' -or
            $trimmedLine -match '^#{2,3}\s+Supported AI-detected patterns') {
            $inCopilotSection = $true
            $inNonProviderSection = $false
            continue
        }
        # Exit section on next heading that isn't part of our sections
        if (($inNonProviderSection -or $inCopilotSection) -and $trimmedLine -match '^#{2,3}\s+' -and
            $trimmedLine -notmatch 'copilot' -and $trimmedLine -notmatch 'AI-detected' -and
            $trimmedLine -notmatch 'generic patterns' -and $trimmedLine -notmatch 'Non-provider') {
            $inNonProviderSection = $false
            $inCopilotSection = $false
        }
        # Skip Liquid ifversion/endif blocks but keep parsing inside them
        if ($trimmedLine -match '^\{%\s*(ifversion|endif|else)') { continue }
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
if (-not $GHNonProviderCount -or -not $GHCopilotCount) {
    throw 'GitHub non-provider or Copilot patterns are empty or could not be parsed.'
}

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

<details><summary>GHES Versions / Count</summary>
<p>

| GHES Version | Count | Push Protection | Validity Check | Base64 | Extended Metadata |
| --- | --- | --- | --- | --- | --- |
$($GHESInventory | ForEach-Object { "| [$($_.GHESVersion)](https://docs.github.com/en/enterprise-server@$($_.GHESVersion)/code-security/reference/secret-security/supported-secret-scanning-patterns) | $($_.Count) | $($_.PushProtectionCount) | $($_.ValidityCheckCount) | $($_.Base64Count) | $($_.ExtendedMetadataCount) |" } | Out-String)

</p>
</details>

# Azure DevOps
| Secret Scanning Inventory |$($(Get-Date -AsUTC).ToString('u')) |
| --- | --- |
| Number of Partner Secret Types | [$($ADOProviders.Count)](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#partner-provider-patterns) |
| Number of Secret Types with Push Protection | $($ADOProvidersPush.Count + $ADONonProvidersPush.Count) |
| Number of Secret Types with Validity Check | $($ADOProvidersValidity.Count + $ADONonProvidersValidity.Count) |
| Non-Partner Patterns | [$($ADONonProviders.Count)](https://learn.microsoft.com/en-us/azure/devops/repos/security/github-advanced-security-secret-scan-patterns?view=azure-devops#non-provider-patterns) ( $($ADONonProvidersValidity.Count) with validity checks) |
| Copilot Secret Scanning Patterns | 0 |
| Secret Scanning Documentation | [Microsoft Learn]($ADODocsUrl) |
"@

Write-Host $comment

if ($OutputFile) {
    $comment | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "`nMarkdown written to: $OutputFile"
}
