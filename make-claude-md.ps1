# make-claude-md.ps1 — bootstrap a hackathon project for Claude Code
#
# Generates in the target project:
#   CLAUDE.md              — full skill content loaded by interactive Claude Code
#   .claude\commands\      — slash commands for interactive Claude Code
#   .claude\settings.json  — GitHub MCP pre-approved (no permission prompts)
#
# Usage:
#   .\make-claude-md.ps1                         # targets current directory
#   .\make-claude-md.ps1 C:\path\to\project      # targets a specific directory

param([string]$TargetDir = (Get-Location).Path)

# When installed globally (e.g. %LOCALAPPDATA%\hackathon-skills\bin\hackathon-bootstrap.ps1),
# the script lives outside the project. Fall back to the calling directory so bootstrap
# works from inside any clone of the template repo.
$SkillsDir = Join-Path $PSScriptRoot "skills"
if (-not (Test-Path $SkillsDir)) {
    $SkillsDir = Join-Path (Get-Location).Path "skills"
}
$CommandsDir  = Join-Path $TargetDir ".claude\commands"
$SettingsPath = Join-Path $TargetDir ".claude\settings.json"
$ClaudeMdPath = Join-Path $TargetDir "CLAUDE.md"

if (-not (Test-Path $SkillsDir)) { Write-Error "skills/ not found — run from inside a clone of the template repo"; exit 1 }
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
    Write-Host "  WARNING: .claude\settings.json exists -- not overwriting. Ensure mcp__github__*, Bash(git:*), Read, Edit, Write are in permissions.allow."
} else {
    @'
{
  "permissions": {
    "allow": [
      "mcp__github__*",
      "Bash(git:*)",
      "Read",
      "Edit",
      "Write"
    ]
  }
}
'@ | Out-File -FilePath $SettingsPath -Encoding utf8 -NoNewline
    Write-Host "  settings: .claude\settings.json written"
}

# 3. CLAUDE.md — coordination header + full skill content
$header = @'
# Hackathon Agent Coordination

> Auto-generated. Re-run the bootstrap script to update.

## Human-in-the-loop workflow

This project has a human review gate between every major AI step.
No AI agent merges anything without explicit human instruction.

Workflow:
  hackathon-setup       → wizard: configure oversight, scaffold PLAN.md
  hackathon-plan        → Phase 1: PLAN.md → GitHub Projects + generate SPECS.md
  Human approves projects (ai-approved)
  hackathon-epics       → Phase 2: Projects → Epic issues on GitHub
  Human approves epics (ai-approved)
  hackathon-decompose   → Phase 3: Epics → Task issues + epic branches
  Human approves tasks (ai-approved)
  hackathon-session     → Phase 4: Tasks → code + PRs (in-review)
  Human triggers hackathon-review → AI posts findings → human decides
  hackathon-verify      → last task per epic; opens epic→main PR
  hackathon-projects    → track completion; close GitHub Project when all epics merge

## GitHub MCP — use for all GitHub operations

Use `mcp__github__*` for every GitHub operation: issues, labels, assignees,
comments, pull requests. Never use `gh`, `curl`, or Bash for GitHub operations.
Make all MCP calls **sequentially, not in parallel.**

## Branch discipline

Epic branches: epic-<n>-<slug> (created by hackathon-decompose from main)
Task branches: <n>-<slug> (created by hackathon-session from the epic branch)
Task PRs target the epic branch. The verify task opens the epic→main PR.
Never commit to `main` or an epic branch directly.

---

'@

$parts = @($header)
foreach ($skill in $skills) {
    $parts += "`n"
    $parts += Get-Content -Raw $skill.FullName
    $parts += "`n---`n"
}
$parts -join "" | Out-File -FilePath $ClaudeMdPath -Encoding utf8 -NoNewline
Write-Host "  CLAUDE.md written"

Write-Host ""
Write-Host "Bootstrap complete -> $TargetDir"
Write-Host ""
Write-Host "Interactive Claude Code: open the project -- /hackathon-* commands available"
Write-Host "Other agent CLIs:        see HARNESS.md"
