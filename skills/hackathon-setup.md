---
description: Onboarding guide. Configures hackathon.config.yml, scaffolds CI, guides workflow.
allowed-tools: Read, Write, Glob, Grep, Bash
---

# Skill: hackathon-setup
Start here. Configures project.

## Phase 1: Context
- Ask Human: New project or Existing?
- **Existing**: Scan repo -> Draft `PLAN.md` -> Pre-seed `SPECS.md`.

## Phase 2: Prerequisites
- Ensure: Claude Code, Docker, GH PAT (`repo` scope), Branch protection (`main`).

## Phase 3: Config
- Guide `PLAN.md` creation.
- Configure `hackathon.config.yml` (Gates, Quality, Actions, Autonomy, Linear History).
- Scaffold CI templates to `.github/workflows/`.
- Create `.geminiignore` template.
- `git commit` config + CI.

## Phase 4: GitHub Labels
- Create via MCP: `needs-human-review`, `ai-approved`, `in-progress`, `review-ready`, `in-review`, `epic`, `bug`, `planning-update`.

## Workflow Reference
1. `/hackathon-plan` (Phase 1).
2. `/hackathon-epics` (Phase 2).
3. `/hackathon-decompose` (Phase 3).
4. `/hackathon-session` (Phase 4 - Implementation loop).
