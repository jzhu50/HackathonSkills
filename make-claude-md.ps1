# make-claude-md.ps1
# Concatenates all skill files from skills/ into .claude/CLAUDE.md in the target project.
# Usage (from inside target project):  path\to\make-claude-md.ps1
# Usage (from skills repo root):       .\make-claude-md.ps1  or  .\make-claude-md.ps1 C:\path\to\project

param(
    [string]$TargetDir = (Get-Location).Path
)

$SkillsDir = Join-Path $PSScriptRoot "skills"
$OutputDir = Join-Path $TargetDir ".claude"
$OutputFile = Join-Path $OutputDir "CLAUDE.md"

if (-not (Test-Path $SkillsDir)) {
    Write-Error "skills/ directory not found at: $SkillsDir"
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$skills = Get-ChildItem -Path $SkillsDir -Filter "*.md" | Sort-Object Name

if ($skills.Count -eq 0) {
    Write-Error "No .md files found in $SkillsDir"
    exit 1
}

$content = @()
foreach ($skill in $skills) {
    $content += Get-Content -Raw $skill.FullName
    $content += "`n"
}

$content -join "" | Out-File -FilePath $OutputFile -Encoding utf8 -NoNewline

Write-Host "Generated $OutputFile from $($skills.Count) skill(s):"
foreach ($skill in $skills) {
    Write-Host "  - $($skill.Name)"
}
