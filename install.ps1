#Requires -Version 5.1
<#
.SYNOPSIS
    hackathon-skills installer for Windows

.DESCRIPTION
    Downloads and installs hackathon-skills to %LOCALAPPDATA%\hackathon-skills\bin

.PARAMETER Tag
    Install a specific version tag

.PARAMETER Beta
    Install from beta channel (pre-releases)

.EXAMPLE
    irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex

.EXAMPLE
    & { param($Beta) irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex } -Beta
#>

param(
    [string]$Tag = "",
    [switch]$Beta,
    [string]$BaseUrl = "" # For testing: override the download base URL
)

$ErrorActionPreference = "Stop"

# -- Configuration ------------------------------------------------------------

$Repo       = "Victor-Casado/HackathonSkills"
$ToolName   = "hackathon-skills"
$InstallDir = Join-Path $env:LOCALAPPDATA "$ToolName\bin"

# Define assets to download and their installation targets
$Assets = @(
    @{
        Name   = "runner.ps1"
        Target = "hackathon-skills.ps1"
        Shim   = "hackathon-skills.cmd"
    },
    @{
        Name   = "make-claude-md.ps1"
        Target = "hackathon-bootstrap.ps1"
        Shim   = "hackathon-bootstrap.cmd"
    }
)

# -- Helpers ------------------------------------------------------------------

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Yellow
}

function Get-LatestRelease {
    if ($BaseUrl) { return "latest" }

    $Url = "https://api.github.com/repos/$Repo/releases"
    $headers = @{}
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "token $($env:GITHUB_TOKEN)"
    }
    
    try {
        if ($Beta) {
            # Get latest release including pre-releases
            $Releases = Invoke-RestMethod -Uri $Url -UseBasicParsing -Headers $headers
            return $Releases[0].tag_name
        } else {
            # Get latest stable release only
            $Release = Invoke-RestMethod -Uri "$Url/latest" -UseBasicParsing -Headers $headers
            return $Release.tag_name
        }
    } catch {
        throw "Failed to get latest release: $_"
    }
}

function Get-FileHash256 {
    param([string]$Path)
    $Hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $Hash.Hash.ToLower()
}

function Download-File {
    param(
        [string]$Url,
        [string]$Path
    )
    if ($env:GITHUB_TOKEN) {
        $SecPassword = ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ("token", $SecPassword)
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing -Credential $Cred
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing
    }
}

# -- Installation -------------------------------------------------------------

function Install-HackathonSkills {
    Write-Host ""
    Write-Host "$ToolName installer" -ForegroundColor Cyan
    Write-Host ("=" * ($ToolName.Length + 10)) -ForegroundColor Cyan
    Write-Host ""
    
    $Version = $Tag
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Info "Fetching latest release tag..."
        $Version = Get-LatestRelease
    }
    
    Write-Info "Version: $Version"
    if ($Beta) { Write-Info "Channel: beta" }
    Write-Host ""

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Create temp directory for downloads
    $TempDir = Join-Path $env:TEMP "$ToolName-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    try {
        # Optional: Download checksums
        $ChecksumUrl = if ($BaseUrl) { "$BaseUrl/checksums.sha256" } else { "https://github.com/$Repo/releases/download/$Version/checksums.sha256" }
        $TempChecksum = Join-Path $TempDir "checksums.sha256"
        $HasChecksums = $false

        try {
            Download-File -Url $ChecksumUrl -Path $TempChecksum
            $HasChecksums = $true
            Write-Info "Checksums available for verification."
        } catch {
            # Gracefully handle missing checksum file
            Write-Warn "Note: No checksums found for this release, skipping verification."
        }

        foreach ($Asset in $Assets) {
            $AssetName = $Asset.Name
            $TargetName = $Asset.Target
            $ShimName = $Asset.Shim
            
            Write-Info "Downloading $AssetName..."
            
            $DownloadUrl = if ($BaseUrl) { "$BaseUrl/$AssetName" } else { "https://github.com/$Repo/releases/download/$Version/$AssetName" }
            $TempFile = Join-Path $TempDir $AssetName
            
            try {
                Download-File -Url $DownloadUrl -Path $TempFile
            } catch {
                throw "Failed to download ${AssetName}: $_"
            }

            # Verify checksum if available
            if ($HasChecksums) {
                Write-Info "Verifying checksum for $AssetName..."
                $ExpectedHash = (Get-Content $TempChecksum | 
                    Where-Object { $_ -match [regex]::Escape($AssetName) } |
                    ForEach-Object { ($_ -split '\s+')[0] }).ToLower()
                
                if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
                    $ActualHash = Get-FileHash256 -Path $TempFile
                    if ($ExpectedHash -ne $ActualHash) {
                        throw "Checksum verification failed for ${AssetName}!`nExpected: $ExpectedHash`nActual: $ActualHash"
                    }
                    Write-Success "Checksum verified."
                } else {
                    Write-Warn "No hash found for $AssetName in checksums file."
                }
            }

            # Install script
            $FinalPath = Join-Path $InstallDir $TargetName
            Move-Item $TempFile $FinalPath -Force
            Write-Success "Installed: $FinalPath"

            # Create shim
            if ($ShimName) {
                $ShimPath = Join-Path $InstallDir $ShimName
                $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($TargetName)
                @"
@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0$BaseName.ps1" %*
"@ | Out-File -FilePath $ShimPath -Encoding ascii -NoNewline
                Write-Success "Created shim: $ShimPath"
            }
        }
        
    } finally {
        # Cleanup
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force
        }
    }
    
    # Add to PATH if needed
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        Write-Host ""
        Write-Info "Adding $InstallDir to PATH..."
        
        $NewPath = "$InstallDir;$UserPath"
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        
        # Update current session
        $env:Path = "$InstallDir;$env:Path"
        
        Write-Success "PATH updated. You may need to restart your terminal."
    }
    
    Write-Host ""
    Write-Success "$ToolName $Version installed successfully!"
    Write-Host ""

    # Auto-bootstrap if running inside a git repo
    if (git rev-parse --git-dir 2>$null) {
        Write-Host "Git repo detected - running bootstrap..."
        & "$InstallDir\hackathon-bootstrap.ps1"
    } else {
        Write-Host "Next steps:"
        Write-Host "  1. Create a new repo from the template on GitHub"
        Write-Host "  2. Clone it, cd into it"
        Write-Host "  3. Open Claude Code and run /hackathon-setup"
        Write-Host ""
        Write-Host "Other commands:"
        Write-Host "  hackathon-skills --help         -- PTY runner help"
        Write-Host "  hackathon-skills --reconfigure  -- change AI CLI selection (Claude, Aider, Codex, Antigravity)"
        Write-Host ""
    }
}

Install-HackathonSkills
exit 0
