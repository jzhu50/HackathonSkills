---
description: Add scope to in-flight project (features, hardening, refactor).
allowed-tools: mcp__github__*, Read, Write, Glob, Grep, Bash
---

# Skill: hackathon-add
Add scope without disrupting active work.

## Phase 1: Context
- Read `hackathon.config.yml`.
- List Projects + Epics via MCP.
- Read `PLAN.md`, `SPECS.md`, `AGENTS.md`.

## Phase 2: Clarify & Scan
- Ask Human: Type? (Features, Hardening, Refactor, Perf, A11y).
- Ask Human: Target? (New Project or Existing).
- **If not Features**: Scan codebase for gaps (e.g., missing auth, N+1, ARIA).

## Phase 3: Scope & Spec
- `grilling: true` -> Call `hackathon-grilling`.
- Propose Epics -> Wait -> Approve.
- Update `SPECS.md`. `git commit`.

## Phase 4: Sync
- Create GitHub Project (if new).
- Create Epic issues (Label: `epic`, `ai-approved`). Add to Project.
- Update Tracking Issue.

## Rules
- Scan is mandatory for hardening/refactor.
- Epics land as `ai-approved`.
