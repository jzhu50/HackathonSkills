# Hackathon Skills v3.1.0

AI agents write code. You control oversight.
**V3.1.0 Focus**: Autonomous loops, linear history, context hygiene.

## Core Concepts
- **GitHub = Brain**: Issues, Projects, PRs store all state. No local memory.
- **Caveman Mode**: Agents speak in fragments. Save 50% tokens. No filler.
- **Context Mode**: Agents write scripts to compute data. Never read large files.
- **Validation-First**: Agents write Success Scripts before coding. PR blocks if FAIL.

## Hierarchy
`GitHub Project -> Epics -> Tasks`

## 4 Phases
1. `/hackathon-plan`: Scope `PLAN.md` -> Projects + `SPECS.md`. (Auto-adds Glue Epics).
2. `/hackathon-epics`: Scope Projects -> Epic issues.
3. `/hackathon-decompose`: Scope Epics -> Task issues. Populates `Blocks` / `Blocked By`.
4. `/hackathon-session`: Implement loop. Claim -> Sync -> Validate -> Implement -> PR.

## Setup
```bash
# Mac/Linux
curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex
```
Run `/hackathon-setup` inside project.

## Config (`hackathon.config.yml`)
- `autonomy: total`: Agents never escalate. Auto-validate.
- `validation: autonomous-script`: Mandate Success Scripts for AC.

## States
- `needs-human-review`: Bugs/Scope.
- `ai-approved`: Ready for claim.
- `in-progress`: Active work.
- `review-ready`: Task done. PR open. Waiting.
- `in-review`: Review active. Double-review prevented.

## Artifact Hygiene
- `.geminiignore` blocks session logs and `.claude/` from LLM context.
- Modular skills (`skills/modules/`) load on-demand to save tokens.
