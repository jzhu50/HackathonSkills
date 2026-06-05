---
description: Generate fixture data + demo toggle.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-seed-demo-data
Produce seed script + DEMO_MODE toggle.

## Phase 1: Context
- Read `PLAN.md` (Stack/DB) + `SPECS.md` (Entities).
- Ask Human: What entities? DB? Demo story? Idempotent?

## Phase 2: Seed Script
- **Prisma Example**: `await db.user.upsert({ ... })`.
- **Data Rules**: Realistic names (No "Test User"), Avatar URLs, staggered timestamps (30-60 days).
- **Idempotent**: Must be safe to run multiple times.

## Phase 3: Demo Toggle
- Create `DEMO_MODE=true` env var.
- Implement UI banner + guard functions.

## Phase 4: Verify
- [ ] Script runs without errors.
- [ ] Data appears.
- [ ] Idempotent.
- [ ] Credentials printed at end.
