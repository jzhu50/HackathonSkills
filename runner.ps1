# runner.ps1 - hackathon-skills PTY runner (Windows)
#
# Spawns the configured AI CLI in a fresh console session for each task.
# Sets TERM=xterm-256color, COLUMNS=220, ROWS=50 as environment variables and
# resizes the PowerShell console buffer/window via $Host.UI.RawUI so the child
# process inherits the correct geometry through the Windows ConPTY layer.
#
# Usage:
#   .\runner.ps1 [-Cli <name>] [-Reconfigure] [args passed to AI CLI...]
#
# On first run, scans PATH for claude/aider/codex and writes the choice to
#   $env:APPDATA\hackathon-skills\config.json
# Subsequent runs load that config.  Use -Reconfigure to re-detect.
#
# Each invocation stops any previously tracked process (PID file) before
# starting a new one - fresh context per task.

param(
    [string]  $Cli          = "",
    [switch]  $Reconfigure,
    [switch]  $Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CliArgs     = @()
)

$ToolName  = "hackathon-skills"
$ConfigDir = Join-Path $env:APPDATA $ToolName
$ConfigFile= Join-Path $ConfigDir "config.json"
$PidFile   = Join-Path $env:TEMP   "$ToolName.pid"

# -- console geometry ---------------------------------------------------------

function Set-ConsoleGeometry {
    param([int]$Cols = 220, [int]$Rows = 50)
    try {
        # Buffer width must be >= window width; set buffer first
        $buf = $Host.UI.RawUI.BufferSize
        if ($buf.Width -lt $Cols) {
            $buf.Width  = $Cols
            $buf.Height = [Math]::Max($buf.Height, $Rows + 100)
            $Host.UI.RawUI.BufferSize = $buf
        }
        $win = $Host.UI.RawUI.WindowSize
        $win.Width  = $Cols
        $win.Height = $Rows
        $Host.UI.RawUI.WindowSize = $win
    } catch {
        # Non-fatal: hosted or non-interactive terminals may not support resize
    }
}

# -- first-run AI CLI detection -----------------------------------------------

function Invoke-FirstRunSetup {
    Write-Host "$ToolName : first run - scanning PATH for AI CLIs..."

    $known = @("claude", "aider", "codex")
    $found = @($known | Where-Object { $null -ne (Get-Command $_ -ErrorAction SilentlyContinue) })

    if ($found.Count -eq 0) {
        Write-Host ""
        Write-Host "No known AI CLIs found (claude, aider, codex)."
        $custom = Read-Host "Enter the command to use (e.g. my-ai-cli)"
        if ([string]::IsNullOrWhiteSpace($custom)) {
            Write-Error "No AI CLI specified."
            exit 1
        }
        $found = @($custom.Trim())
    } else {
        Write-Host ""
        Write-Host "Found:"
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $found[$i])
        }
        Write-Host ""
        $sel = Read-Host "Enter numbers to select (space-separated), or press Enter to use all"
        if (-not [string]::IsNullOrWhiteSpace($sel)) {
            $chosen = @()
            foreach ($n in ($sel -split '\s+')) {
                $idx = [int]$n - 1
                if ($idx -lt 0 -or $idx -ge $found.Count) {
                    Write-Error "Invalid selection: $n"
                    exit 1
                }
                $chosen += $found[$idx]
            }
            $found = $chosen
        }
    }

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    }

    $obj = [pscustomobject]@{ cli = $found }
    $obj | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigFile -Encoding utf8 -NoNewline

    Write-Host ""
    Write-Host "Saved: $ConfigFile"
    Write-Host ("  cli: {0}" -f ($found -join ", "))
    Write-Host ""
}

# -- process management -------------------------------------------------------

function Stop-ExistingSession {
    if (-not (Test-Path $PidFile)) { return }
    $pidStr = Get-Content $PidFile -ErrorAction SilentlyContinue
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($pidStr)) { return }
    $oldPid = [int]$pidStr
    try {
        $proc = Get-Process -Id $oldPid -ErrorAction Stop
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
        # Process already gone - that's fine
    }
}

# -- PTY spawn (Windows ConPTY via direct invocation) -------------------------
#
# On Windows, the process is already running inside a ConPTY-backed console
# (Windows Terminal, VS Code integrated terminal, etc.).  We resize the console
# buffer and window to 220x50 (the Windows equivalent of TIOCSWINSZ), set the
# three standard terminal environment variables, stop any previous session, then
# start the AI CLI as a child process of this shell - it inherits the console
# handle and therefore the ConPTY connection.

function Invoke-SpawnPty {
    param([string]$AiCli, [string[]]$ExtraArgs)

    Set-ConsoleGeometry -Cols 220 -Rows 50

    $env:TERM    = "xterm-256color"
    $env:COLUMNS = "220"
    $env:ROWS    = "50"

    Stop-ExistingSession

    # Record our PID so the next invocation can stop this session
    $PID | Out-File -FilePath $PidFile -Encoding utf8 -NoNewline

    try {
        if ($ExtraArgs.Count -gt 0) {
            & $AiCli @ExtraArgs
        } else {
            & $AiCli
        }
        $exitCode = $LASTEXITCODE
    } finally {
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }

    exit $exitCode
}

# -- read config --------------------------------------------------------------

function Get-PrimaryCli {
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Config not found: $ConfigFile - run with -Reconfigure"
        exit 1
    }
    try {
        $data = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Cannot parse config: $_"
        exit 1
    }
    $clis = $data.cli
    if ($null -eq $clis -or $clis.Count -eq 0) {
        Write-Error "Config 'cli' list is empty - run with -Reconfigure"
        exit 1
    }
    return $clis[0]
}

# -- main ---------------------------------------------------------------------

if ($Help) {
    Write-Host "Usage: hackathon-skills [-Cli <name>] [-Reconfigure] [args...]"
    Write-Host ""
    Write-Host "  Spawns the configured AI CLI in a fresh console session"
    Write-Host "  (TERM=xterm-256color, COLUMNS=220, ROWS=50) and stops any"
    Write-Host "  previous session first."
    Write-Host ""
    Write-Host "  -Cli <name>     override the configured AI CLI for this invocation"
    Write-Host "  -Reconfigure    re-run AI CLI detection and update config"
    Write-Host ""
    Write-Host "  Config: $ConfigFile"
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($Cli)) {
    # Direct override - skip config detection for this run
    $aiCli = $Cli.Trim()
} else {
    if ($Reconfigure -or -not (Test-Path $ConfigFile)) {
        Invoke-FirstRunSetup
    }
    $aiCli = Get-PrimaryCli
}

Invoke-SpawnPty -AiCli $aiCli -ExtraArgs $CliArgs
