# install.ps1 - hackathon-skills installer (Windows)
#
# Downloads runner.ps1 and make-claude-md.ps1 from the latest GitHub release:
#   %LOCALAPPDATA%\hackathon-skills\bin\hackathon-skills.ps1    - PTY runner
#   %LOCALAPPDATA%\hackathon-skills\bin\hackathon-bootstrap.ps1 - project bootstrapper
# Creates .cmd shims for both so they're callable without the .ps1 extension.
#
# Usage (run in PowerShell as your normal user - no elevation needed):
#   irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex
#   # or locally:
#   .\install.ps1

param(
    [string]$Tag = ""   # pin to a specific release tag, e.g. "v1.0.0"
)

$Repo       = "Victor-Casado/HackathonSkills"
$ToolName   = "hackathon-skills"
$InstallDir = Join-Path $env:LOCALAPPDATA "$ToolName\bin"

# -- helpers ------------------------------------------------------------------

function Write-Step([string]$Msg) { Write-Host "  $Msg" }

function Get-LatestTag {
    $url = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        $resp = Invoke-RestMethod -Uri $url -UseBasicParsing
        return $resp.tag_name
    } catch {
        Write-Error "Could not fetch latest release tag: $_"
        exit 1
    }
}

function Invoke-Download([string]$Url, [string]$Dest) {
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
    } catch {
        Write-Error "Download failed from ${Url}: $_"
        exit 1
    }
}

function Install-Script([string]$Url, [string]$ScriptDst, [string]$WrapperDst, [string]$Label) {
    $Tmp = Join-Path $env:TEMP "hs-$([System.IO.Path]::GetRandomFileName()).ps1"
    Invoke-Download -Url $Url -Dest $Tmp

    $firstLine = Get-Content $Tmp -TotalCount 1 -ErrorAction Stop
    if ($firstLine -notmatch '(?i)(param|#|function)') {
        Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
        Write-Error "Downloaded $Label does not look like a PowerShell script."
        exit 1
    }

    Copy-Item -Path $Tmp -Destination $ScriptDst -Force
    Remove-Item $Tmp -Force -ErrorAction SilentlyContinue

    $cmdName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptDst)
    @"
@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0$cmdName.ps1" %*
"@ | Out-File -FilePath $WrapperDst -Encoding ascii -NoNewline

    Write-Step "installed : $ScriptDst"
    Write-Step "shim      : $WrapperDst"
}

# -- PATH management ----------------------------------------------------------

function Add-ToUserPath([string]$Dir) {
    $current = [Environment]::GetEnvironmentVariable("PATH", "User")
    $parts   = $current -split ";" | Where-Object { $_ -ne "" }
    if ($parts -contains $Dir) {
        Write-Step "PATH already includes $Dir"
        return
    }
    $newPath = ($parts + $Dir) -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Step "Added to user PATH: $Dir"
    Write-Step "Restart your terminal for PATH changes to take effect."
}

# -- main ---------------------------------------------------------------------

Write-Host ""
Write-Host "hackathon-skills installer"
Write-Host "=========================="
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Tag)) {
    Write-Host "Fetching latest release tag..."
    $Tag = Get-LatestTag
}
Write-Step "version : $Tag"
Write-Host ""

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

$BaseUrl = "https://github.com/$Repo/releases/download/$Tag"

Write-Host "Downloading..."

Install-Script `
    -Url        "$BaseUrl/runner.ps1" `
    -ScriptDst  (Join-Path $InstallDir "hackathon-skills.ps1") `
    -WrapperDst (Join-Path $InstallDir "hackathon-skills.cmd") `
    -Label      "runner.ps1"

Install-Script `
    -Url        "$BaseUrl/make-claude-md.ps1" `
    -ScriptDst  (Join-Path $InstallDir "hackathon-bootstrap.ps1") `
    -WrapperDst (Join-Path $InstallDir "hackathon-bootstrap.cmd") `
    -Label      "make-claude-md.ps1"

Write-Host ""

Add-ToUserPath -Dir $InstallDir

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Create a new repo from the template on GitHub"
Write-Host "  2. Clone it, cd into it"
Write-Host "  3. hackathon-bootstrap          -- generates CLAUDE.md + slash commands"
Write-Host "  4. Fill in PLAN.md"
Write-Host "  5. Open Claude Code and run /hackathon-setup"
Write-Host ""
Write-Host "Other commands:"
Write-Host "  hackathon-skills -Help          -- PTY runner help"
Write-Host "  hackathon-skills -Reconfigure   -- change AI CLI selection"
Write-Host ""
