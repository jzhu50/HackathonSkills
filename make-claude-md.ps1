# make-claude-md.ps1 — bootstrap a hackathon project for autonomous agent use
#
# Generates in the target project:
#   CLAUDE.md              — full skill content for headless mode (claude -p "Go")
#   .claude\commands\      — slash commands for interactive Claude Code
#   .claude\settings.json  — GitHub MCP pre-approved (no permission prompts)
#   run.ps1                — autonomous loop: runs until all tasks and reviews are done
#
# Usage:
#   .\make-claude-md.ps1                         # targets current directory
#   .\make-claude-md.ps1 C:\path\to\project      # targets a specific directory

param([string]$TargetDir = (Get-Location).Path)

$SkillsDir    = Join-Path $PSScriptRoot "skills"
$CommandsDir  = Join-Path $TargetDir ".claude\commands"
$SettingsPath = Join-Path $TargetDir ".claude\settings.json"
$ClaudeMdPath = Join-Path $TargetDir "CLAUDE.md"
$RunPs1Path   = Join-Path $TargetDir "run.ps1"

if (-not (Test-Path $SkillsDir)) { Write-Error "skills/ not found at $SkillsDir"; exit 1 }
$skills = Get-ChildItem -Path $SkillsDir -Filter "*.md" | Sort-Object Name
if ($skills.Count -eq 0) { Write-Error "No .md files in $SkillsDir"; exit 1 }

New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null

# 1. Slash commands (interactive Claude Code)
foreach ($skill in $skills) {
    Copy-Item -Path $skill.FullName -Destination (Join-Path $CommandsDir $skill.Name) -Force
    Write-Host "  command: .claude\commands\$($skill.Name)"
}

# 2. settings.json
if (Test-Path $SettingsPath) {
    Write-Host "  WARNING: .claude\settings.json exists — not overwriting. Ensure mcp__github__* is in permissions.allow."
} else {
    @'
{
  "permissions": {
    "allow": [
      "mcp__github__*"
    ]
  }
}
'@ | Out-File -FilePath $SettingsPath -Encoding utf8 -NoNewline
    Write-Host "  settings: .claude\settings.json written"
}

# 3. CLAUDE.md — coordination header + full skill content (for headless claude -p)
$header = @'
# Hackathon Agent Coordination

> Auto-generated. Re-run the bootstrap script to update.

## GitHub MCP — use for all GitHub operations

Use `mcp__github__*` for every GitHub operation: issues, labels, assignees,
comments, pull requests. Never use `gh`, `curl`, or Bash for GitHub operations.
Make all MCP calls **sequentially, not in parallel.**

## Branch discipline

Every issue gets its own branch before any code is written.
`main` is protected — merge via PR only. Never commit to `main` directly.

## One unit of work per context

Each `claude -p "Go"` invocation does exactly one task or one PR review, then stops.
Context is fresh each time. The `run.ps1` loop handles repetition.

---

'@

$parts = @($header)
foreach ($skill in $skills) {
    $parts += "`n"
    $parts += Get-Content -Raw $skill.FullName
    $parts += "`n---`n"
}
$parts -join "" | Out-File -FilePath $ClaudeMdPath -Encoding utf8 -NoNewline
Write-Host "  CLAUDE.md written (full skill content for headless mode)"

# 4. run.ps1 — autonomous loop
@'
# run.ps1 — autonomous hackathon agent loop
#
# Say "Go" once. Agents claim tasks, open PRs, review PRs, implement
# feedback, and repeat until everything is done. Context is cleared
# automatically between each unit of work.
#
# Run this on each teammate's machine in parallel for multi-agent mode.
# Press Ctrl-C to stop early.

$IDLE = 0
$MAX_IDLE = 3    # exit after this many consecutive NOTHING_TO_DO signals
$IDLE_WAIT = 60  # seconds between idle retries

Write-Host "Hackathon agent loop started. Press Ctrl-C to stop."
Write-Host ""

while ($true) {
    Write-Host "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    $output = claude -p "Go" 2>&1
    Write-Host $output
    Write-Host ""

    if ($output -match 'NOTHING_TO_DO') {
        $IDLE++
        if ($IDLE -ge $MAX_IDLE) {
            Write-Host "Nothing to do for $MAX_IDLE consecutive checks. All done."
            break
        }
        Write-Host "Idle ($IDLE/$MAX_IDLE). Waiting ${IDLE_WAIT}s..."
        Start-Sleep -Seconds $IDLE_WAIT
    } else {
        # "Waiting for peers" does not increment idle — only NOTHING_TO_DO counts.
        $IDLE = 0
        Start-Sleep -Seconds 3
    }
}
'@ | Out-File -FilePath $RunPs1Path -Encoding utf8 -NoNewline
Write-Host "  run.ps1 written"

Write-Host ""
Write-Host "Bootstrap complete -> $TargetDir"
Write-Host ""
Write-Host "For Claude Code (interactive):  open the project — /hackathon-* commands available"
Write-Host "For autonomous mode:            .\run.ps1  (each teammate runs this independently)"
Write-Host "For other agent CLIs:           paste AGENTS.md as system prompt"
