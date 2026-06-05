---
description: Phase 4 Implementation. Claims ai-approved tasks, syncs, validates, implements, opens PR. Zero human escalation.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session
Phase 4: Implement Tasks -> PRs.

## Phase 0: Read Config
- Load `hackathon.config.yml`.
- Gates: `task_completion`, `code_review`.
- Quality: `testing`, `validation`, `autonomy`, `history`.

## Phase 1: Orient
- `git fetch origin`.
- `git checkout main; git rebase origin/main`.
- Unblock: Check `blocked` issues -> Remove label if deps closed.

## Phase 2: Task Loop
1. **Claim**: Load `skills/modules/skill-claim.md`. Claim `ai-approved` task.
2. **Branch**: `git checkout -b task/[id]-[slug]`.
3. **Sync**: Load `skills/modules/skill-sync.md`. Rebase on epic branch.
4. **Validate Baseline**: Load `skills/modules/skill-validate.md`. Write script -> Confirm FAIL.
5. **Implement**: 
   - Check signals -> Load domain skills (`hackathon-auth`, etc.).
   - Implement -> Run tests -> Debug on regression.
6. **Validate Success**: Run success script -> Must PASS.
7. **PR**:
   - `git push -u origin [branch]`.
   - `mcp__github__create_pull_request`: Base = epic branch.
   - Label: `review-ready`.
   - Comment: What built + test results.

## Rules
- **REBASE ONLY**. Ban `merge main`.
- **Validation Blocking**: No PASS = No PR.
- **Autonomy**: Rebase fail -> Open PR + Tag `[REBASE_FAILED]`.
- **Collision**: Refresh status before claim.
