---
description: Phase 4 Implementation. Claims ai-approved tasks, syncs, validates, implements, opens PR. Zero human escalation.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Phase 4: Implement Tasks -> PRs.

## Phase 0: Read Config
- Load `hackathon.config.yml`.
- Gates: `task_completion`, `code_review`.
- Quality: `testing`, `validation`, `autonomy`.

## Phase 1: Orient
- `git fetch origin`.
- `git checkout main; git merge origin/main`.
- Unblock: Check `blocked` issues -> Remove label if deps closed.

## Phase 2: Task Loop
1. **Claim**: Call tool `read_file` on `skills/modules/skill-claim.md`. Follow its steps to claim `ai-approved` task.
2. **Branch**: `git checkout -b task/[id]-[slug]`.
3. **Sync**: Call tool `read_file` on `skills/modules/skill-sync.md`. Follow its steps to sync with epic branch.
4. **Validate Baseline**: Call tool `read_file` on `skills/modules/skill-validate.md`. Follow its steps to write script -> Confirm FAIL.
5. **Implement**:
   - Check signals -> Read and follow domain skills (e.g., `read_file` on `skills/hackathon-auth.md`).
   - Implement -> Run tests -> Debug on regression.
6. **Validate Success**: Run success script -> Must PASS.
7. **PR**:
   - `git push -u origin [branch]`.
   - `mcp__github__create_pull_request`: Base = epic branch.
   - Label: `review-ready`.
   - Comment: What built + test results.

## Rules
- **No Direct Commits**: Always branch.
- **Validation Blocking**: No PASS = No PR.
- **Collision**: Refresh status before claim.
