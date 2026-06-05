---
description: Track project status. Close completed projects.
allowed-tools: mcp__github__*, Read
---

# Skill: hackathon-projects
Track and close GitHub Projects.

## Phase 1: Load State
- List GitHub Projects.
- List assigned Epics.
- Check Epic labels.

## Phase 2: Compute
- **Complete**: All epics closed.
- **In Progress**: >= 1 epic open.
- **Blocked**: >= 1 epic blocked.

## Phase 3: Report
- Output status per project.

## Phase 4: Close
- IF all epics closed AND merged:
  - `mcp__github__update_project`: status -> `closed`.
  - Comment tracking issue: `agent: project closed`.
  - Call `hackathon-docs-demo-script` if last project.

## Rules
- Epic must be MERGED, not just closed.
- Never force-close without human confirmation.
