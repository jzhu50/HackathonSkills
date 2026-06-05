---
description: Interrogate to zero ambiguity. Returns structured brief.
allowed-tools: mcp__github__*, Read
---

# Skill: hackathon-grilling
Resolve ambiguities. Produce brief.

## Phase 1: Read Context
- Read `PLAN.md`, `SPECS.md`, and passed context string.

## Phase 2: Interrogation Loop
- Identify open questions (AC, Dependencies, Tech Stack, Scope).
- Batch all questions into ONE message.
- Ask Human -> Wait -> Incorporate answers.
- **Repeat** until zero ambiguities.

## Phase 3: Confirm
- Output: "Grilling complete. Understanding: [bullet points]."
- Ask Human to confirm.

## Phase 4: Output Brief
Return format:
```
## Grilling brief
### Decisions made
### Constraints
### Scope
### Resolved ambiguities
```
