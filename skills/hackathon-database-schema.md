---
description: Database schema design guide. Covers normalization decisions, primary key strategy, indexing, soft deletes, FK constraints, and the design conversation that prevents schema rewrites mid-hackathon. Auto-called by hackathon-session when a task involves schema design, migrations, or data models.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-database-schema

Called by `hackathon-session` during N3 (implement) when schema signals are detected.
Enforces design decisions before any migration is written. Session retains ownership of
git, tests, and PR creation.

The design conversation before the first migration is where 80% of schema rework originates.

---

## Trigger

Auto-called by `hackathon-session` when task title or body contains:
`schema`, `migration`, `table`, `model`, `database`, `erd`, `create table`,
`prisma model`, `drizzle`, `entity`, `data model`, `relations`

---

## Phase 0 — Load context

Read sequentially:
1. The task issue — goal, acceptance criteria
2. `PLAN.md` — stack (which DB? which ORM/migration tool?)
3. `SPECS.md` — Data Models section if it exists
4. Any existing migration files or schema files in the repo

---

## Phase 1 — Confirm design decisions

Check existing context first. For anything not yet decided, ask in one batch:

1. **Database** — PostgreSQL, MySQL, SQLite, MongoDB?
2. **ORM / migration tool** — Prisma, Drizzle, TypeORM, Alembic, raw SQL?
3. **Main entities** — List the 5-10 core things the app manages
4. **Access patterns** — The 3 most common queries (drives indexing decisions)
5. **Expected scale** — Hundreds, thousands, or millions of rows?
6. **Multi-tenancy?** — Isolated schemas, row-level tenancy, or single tenant?
7. **Soft deletes?** — Archive vs. hard delete?
8. **Audit trail?** — Track who changed what, when?

---

## Phase 2 — Design decisions

Work through each before writing any SQL or schema code:

### Primary keys

```sql
-- Public-facing IDs, distributed systems → UUID
id UUID PRIMARY KEY DEFAULT gen_random_uuid()

-- High-insert internal tables → BIGSERIAL (faster inserts, smaller indexes)
id BIGSERIAL PRIMARY KEY
```

In Prisma:
```prisma
id String @id @default(cuid())  -- Good default for hackathons
```

**Rule:** Never expose sequential integer IDs to clients — they leak record counts.

### Timestamps (always include on every table)

```sql
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

In Prisma:
```prisma
createdAt DateTime @default(now())
updatedAt DateTime @updatedAt
```

Always store UTC. Convert to local time in the application layer, never in the DB.

### Soft deletes

```sql
deleted_at TIMESTAMP WITH TIME ZONE  -- NULL = active, non-NULL = deleted

-- Partial index — only indexes active rows (huge performance win)
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
```

Use soft deletes when: audit trail required, referential integrity must be preserved, records may need recovery.
Skip soft deletes on: junction tables, event/log tables.

### Normalization

```
3NF (Normalized) → OLTP, data changes frequently, storage matters
Denormalized     → Read-heavy (>10:1 read/write), analytics, join cost is prohibitive
```

---

## Phase 3 — Schema output format

For every table, produce:

```sql
-- ============================================
-- TABLE: users
-- ============================================
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       VARCHAR(255) NOT NULL,
  name        VARCHAR(255) NOT NULL,
  role        VARCHAR(50)  NOT NULL DEFAULT 'member',
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMP WITH TIME ZONE
);

ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'member', 'viewer'));

CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
```

---

## Phase 4 — FK constraints

```sql
-- Owned children: cascade delete
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_project
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;

-- Optional reference: set null on parent delete
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_assignee
  FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE SET NULL;

-- Many-to-many: composite PK, no surrogate ID
CREATE TABLE project_members (
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       VARCHAR(50) NOT NULL DEFAULT 'member',
  joined_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (project_id, user_id)
);
CREATE INDEX idx_project_members_user ON project_members(user_id);
```

---

## Phase 5 — Indexing rules

```
Always index:
  ✓ All foreign key columns
  ✓ Columns in WHERE clauses of frequent queries
  ✓ Unique constraints (email, slug)

Consider:
  ? Composite indexes for multi-column WHERE (high-selectivity column first)
  ? Partial indexes for filtered queries (WHERE deleted_at IS NULL)

Never:
  ✗ Columns rarely in WHERE/JOIN
  ✗ Low-cardinality columns alone (boolean, 3-value status) — add to composite
  ✗ Every column "just in case"
```

---

## Phase 6 — Prisma schema variant (if using Prisma)

```prisma
model User {
  id        String    @id @default(cuid())
  email     String    @unique
  name      String
  role      Role      @default(MEMBER)
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?

  ownedProjects Project[]       @relation("owner")
  assignedTasks Task[]
  memberships   ProjectMember[]

  @@index([deletedAt])
}

enum Role { ADMIN MEMBER VIEWER }
```

---

## Anti-patterns to avoid

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Sequential integer IDs exposed in URLs | Leaks record counts, enumerable | UUID or CUID |
| No `updated_at` | Can't detect stale data | Always include |
| `is_deleted BOOLEAN` instead of `deleted_at` | Can't query deletion time | Nullable timestamp |
| FK without index | Slow joins and cascades | Always index FK columns |
| JSON arrays instead of junction table | Can't join, index, or constrain | Junction table |
| `VARCHAR(255)` everywhere | Arbitrary | `TEXT` for long strings, `VARCHAR(n)` only when limit matters |

---

## Return to session

When schema is designed and migration file is written, signal to `hackathon-session`
that the schema phase is done. Session continues with tests and PR.
