---
description: Phase 2. Scope Projects into Epic issues.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-epics

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Phase 2: Projects -> Epics.

## Phase 0: Orient
- Load `hackathon.config.yml`. Gate: `epic_breakdown`.
- Read `PLAN.md`, `SPECS.md`.
- List Projects via MCP. None? -> ABORT.

## Phase 1: Grilling
- `grilling: true` -> Call `hackathon-grilling`.

## Phase 2: Scope
- Define Done Criteria, Dependencies, AC.
- Output proposal.
- `human_required: true` -> Wait for Human -> Approve. `human_required: false` -> Proceed.

## Phase 3: GitHub Sync
- Create Epic issues sequentially.
- Body sections (all required): `## Project`, `## Goal`, `## Context`, `## Wave` (if parallelism: true), `## Dependencies`, `## Acceptance Bar`, `## Open Questions`, `## Child Issues` (leave blank — hackathon-decompose fills in).
- Label: `epic`, `ai-approved`.
- Assign Epic to GitHub Project.

## Phase 4: Tracking
- Create Tracking Issue: Vision, Goal, Projects, Epics, Out of Scope.
- Label: `epic`.

## Rules
- Wait for approval before issue creation.
- Add Epic to Project board immediately.
