---
description: Epic finalization. Verify E2E, audit, merge Epic->Main (regular merge, NO squash).
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-verify

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Final task per epic. E2E Verify -> Main Merge.

## Phase 0: Orient
- Load `hackathon.config.yml`. Gate: `epic_review`.
- Claim Verify task.
- Ensure all sibling tasks closed. Open? -> Unassign + ABORT.

## Phase 1: Sync & Test
- Use the `Read` tool on `skills/modules/skill-sync.md`. Follow its steps to sync the `epic` branch.
- Run test suite.
- Security audit: Use the `Read` tool on `skills/hackathon-security-audit.md`. CRITICAL = ABORT + File bugs.
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
- **Testing**: Run tests to verify branch.
- **Audit Trail**: Epic -> Main uses regular merge. DO NOT SQUASH.
