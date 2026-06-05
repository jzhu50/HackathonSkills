---
description: Epic finalization. Verify E2E, audit, merge Epic->Main (regular merge, NO squash).
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-verify
Final task per epic. E2E Verify -> Main Merge.

## Phase 0: Orient
- Load `hackathon.config.yml`. Gate: `epic_review`.
- Claim Verify task.
- Ensure all sibling tasks closed. Open? -> Unassign + ABORT.

## Phase 1: Rebase & Test
- Load `skills/modules/skill-sync.md`. Rebase `epic` branch on `main`.
- Run test suite.
- Security audit: `hackathon-security-audit`. CRITICAL = ABORT + File bugs.
- Verify AC.

## Phase 2: Verdict
- **FAIL**: 
  - Deduplicate bugs.
  - File `bug` issues -> `needs-human-review`.
  - Add to Epic `Child Issues`. 
  - Verify task -> `ai-approved`. Unassign.
- **PASS**: 
  - Open PR: Epic -> Main. Title `[Epic #n] ready`.
  - Task label -> `review-ready`.

## Phase 3: Execute Merge
**Human Mode**: Stop. Wait for human merge.
**Autonomous**: 
- `mcp__github__merge_pull_request`: **MERGE COMMIT** (No squash. Preserve task history).
- Verify Epic auto-closed. Remove task label.

## Rules
- **Linear History**: Rebase before testing.
- **Audit Trail**: Epic -> Main uses regular merge. DO NOT SQUASH.
