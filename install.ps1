# install.ps1 - hackathon-skills installer (Windows)
#
# Downloads runner.ps1 from the latest GitHub release, installs it as
#   %LOCALAPPDATA%\hackathon-skills\bin\hackathon-skills.ps1
# creates a wrapper batch file so the tool is callable without the .ps1 extension,
# and adds the bin directory to the user PATH.
#
# Usage (run in PowerShell as your normal user - no elevation needed):
#   irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex
#   # or locally:
#   .\install.ps1

param(
    [string]$Tag = ""   # pin to a specific release tag, e.g. "v1.0.0"
)

$Repo      = "Victor-Casado/HackathonSkills"
$ToolName  = "hackathon-skills"
$InstallDir= Join-Path $env:LOCALAPPDATA "$ToolName\bin"
$ScriptDst = Join-Path $InstallDir "$ToolName.ps1"
$WrapperDst= Join-Path $InstallDir "$ToolName.cmd"

# -- helpers ------------------------------------------------------------------

function Write-Step([string]$Msg) { Write-Host "  $Msg" }

function Get-LatestTag {
    $url  = "https://api.github.com/repos/$Repo/releases/latest"
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
        Write-Error "Download failed: $_"
        exit 1
    }
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

$DownloadUrl = "https://github.com/$Repo/releases/download/$Tag/runner.ps1"
Write-Step "source  : $DownloadUrl"
Write-Step "target  : $ScriptDst"
Write-Host ""

# Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

# Download runner.ps1 to a temp file then validate
$Tmp = Join-Path $env:TEMP "hs-runner-$([System.IO.Path]::GetRandomFileName()).ps1"
Write-Host "Downloading..."
Invoke-Download -Url $DownloadUrl -Dest $Tmp

# Basic sanity check
$firstLine = Get-Content $Tmp -TotalCount 1 -ErrorAction Stop
if ($firstLine -notmatch '(?i)(param|#|function)') {
    Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
    Write-Error "Downloaded file does not look like a PowerShell script."
    exit 1
}

Copy-Item -Path $Tmp -Destination $ScriptDst -Force
Remove-Item $Tmp -Force -ErrorAction SilentlyContinue

# Write a .cmd shim so the tool is callable without the .ps1 extension
@"
@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0$ToolName.ps1" %*
"@ | Out-File -FilePath $WrapperDst -Encoding ascii -NoNewline

Write-Host "Installed: $ScriptDst"
Write-Host "  shim  : $WrapperDst"
Write-Host ""

# Add bin dir to user PATH
Add-ToUserPath -Dir $InstallDir

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Run:  hackathon-skills -Help"
Write-Host "      hackathon-skills                   # launches AI CLI in ConPTY session"
Write-Host "      hackathon-skills -Reconfigure      # change AI CLI selection"
Write-Host ""
Write-Host "Note: a GitHub release with runner.ps1 as an asset must exist for this"
Write-Host "      installer to work end-to-end.  Publish a release first."
Write-Host ""
