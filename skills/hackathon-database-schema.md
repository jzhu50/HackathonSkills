---
description: Database schema guide. Normalization, PKs, indexes, FKs.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-database-schema
Schema design. Enforce rules before migration.

## Phase 1: Strategy
- Check `PLAN.md`.
- Identify: Database, ORM, Entities, Access Patterns.

## Phase 2: Design Rules
- **PK**: `UUID` (public) or `BIGSERIAL` (internal). Never expose sequential ints.
- **Timestamps**: Always `created_at`, `updated_at` (UTC).
- **Soft Deletes**: `deleted_at` timestamp. Use partial index `WHERE deleted_at IS NULL`.

## Phase 3: FK & Indexing
- **FKs**: Cascade for owned children. Set null for optional.
- **Indexes**: 
  - ALWAYS index FK columns.
  - ALWAYS index frequent WHERE columns.
  - ALWAYS index UNIQUE constraints.

## Anti-Patterns
- `is_deleted BOOLEAN` -> Use `deleted_at` timestamp.
- FK without index -> Slow joins.
- JSON arrays instead of junction table -> Can't join.

## Rules
- Design first. Review -> Then write migration.
