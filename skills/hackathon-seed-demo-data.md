---
description: Generate realistic fixture data, populate the database, and wire up a demo mode toggle. Built for hackathon demos where a blank app kills the presentation. Auto-called by hackathon-session when a task involves seed data, demo data, or database population.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-seed-demo-data

Called by `hackathon-session` during N3 (implement) when seed signals are detected.
Produces a seed script, idempotent upsert pattern, and DEMO_MODE toggle.

---

## Trigger

Auto-called by `hackathon-session` when task title or body contains:
`seed`, `demo data`, `fixture`, `populate`, `sample data`, `demo mode`, `test data`

---

## Phase 0 - Load context

Read sequentially:
1. The task issue - what entities, what demo story
2. `PLAN.md` - stack, database, ORM
3. `SPECS.md` - data models if defined
4. Any existing schema/migration files to understand entity shapes

---

## Phase 1 - Confirm seed requirements

Check context first. Ask only for gaps, in one batch:

1. **What entities?** - List main tables/models that need data
2. **DB + ORM?** - Prisma, Mongoose, Drizzle, raw SQL?
3. **How many records?** - Demo: 5 users, 3 orgs, 20 tasks is usually enough
4. **What story should the demo tell?** - What journey should the judge take?
5. **Idempotent?** - Running seed twice = same result, no duplicates? (Almost always yes)

---

## Phase 2 - Seed script (Prisma example)

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client';
import { hash } from 'bcrypt';

const db = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Wipe in FK-safe order
  await db.comment.deleteMany();
  await db.task.deleteMany();
  await db.project.deleteMany();
  await db.user.deleteMany();

  // Seed users
  const [alice, bob, carol] = await Promise.all([
    db.user.create({ data: {
      email: 'alice@demo.com', name: 'Alice Chen', role: 'admin',
      passwordHash: await hash('demo1234', 12),
      avatarUrl: 'https://i.pravatar.cc/150?u=alice',
      createdAt: daysAgo(45),
    }}),
    db.user.create({ data: {
      email: 'bob@demo.com', name: 'Bob Okafor', role: 'member',
      passwordHash: await hash('demo1234', 12),
      avatarUrl: 'https://i.pravatar.cc/150?u=bob',
      createdAt: daysAgo(30),
    }}),
    db.user.create({ data: {
      email: 'carol@demo.com', name: 'Carol Yamamoto', role: 'member',
      passwordHash: await hash('demo1234', 12),
      avatarUrl: 'https://i.pravatar.cc/150?u=carol',
      createdAt: daysAgo(20),
    }}),
  ]);

  // Seed with realistic status distribution: 30% done, 40% in_progress, 30% todo
  const taskData = [
    { title: 'Design wireframes', status: 'done', assigneeId: alice.id, priority: 'high', createdAt: daysAgo(25) },
    { title: 'Set up project structure', status: 'done', assigneeId: alice.id, priority: 'high', createdAt: daysAgo(22) },
    { title: 'Build core feature', status: 'in_progress', assigneeId: bob.id, priority: 'high', createdAt: daysAgo(15) },
    { title: 'Write API endpoints', status: 'in_progress', assigneeId: carol.id, priority: 'medium', createdAt: daysAgo(10) },
    { title: 'Add error handling', status: 'todo', assigneeId: bob.id, priority: 'low', createdAt: daysAgo(5) },
    { title: 'Mobile responsive pass', status: 'todo', assigneeId: null, priority: 'medium', createdAt: daysAgo(3) },
  ];

  const project = await db.project.create({ data: {
    name: 'Main Project', status: 'active', ownerId: alice.id, createdAt: daysAgo(30),
  }});

  for (const task of taskData) {
    await db.task.create({ data: { ...task, projectId: project.id } });
  }

  console.log('Done! Demo credentials:');
  console.log('  alice@demo.com / demo1234  (admin)');
  console.log('  bob@demo.com   / demo1234  (member)');
  console.log('  carol@demo.com / demo1234  (member)');
}

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

main().catch(console.error).finally(() => db.$disconnect());
```

```json
// package.json
{
  "prisma": { "seed": "ts-node prisma/seed.ts" },
  "scripts": {
    "db:seed": "prisma db seed",
    "db:reset": "prisma migrate reset --force"
  }
}
```

---

## Phase 3 - Idempotent upsert (for CI / repeated runs)

```typescript
const alice = await db.user.upsert({
  where: { email: 'alice@demo.com' },
  update: {},
  create: { email: 'alice@demo.com', name: 'Alice Chen', passwordHash: await hash('demo1234', 12) },
});
```

---

## Phase 4 - Demo mode toggle

```typescript
// lib/demo.ts
export const DEMO_MODE = process.env.DEMO_MODE === 'true';

export function guardDemoMode(action: string) {
  if (DEMO_MODE) throw new Error(`"${action}" is disabled in demo mode.`);
}
```

```tsx
// components/DemoBanner.tsx
import { DEMO_MODE } from '@/lib/demo';
export function DemoBanner() {
  if (!DEMO_MODE) return null;
  return (
    <div className="bg-amber-500 text-black text-center text-sm py-2 px-4">
      Demo mode - log in as <code>alice@demo.com</code> / <code>demo1234</code>
    </div>
  );
}
```

---

## Realistic data principles

- **Names:** use realistic diverse names, not "User1" / "Test User"
- **Avatars:** `https://i.pravatar.cc/150?u=<username>` (no account needed)
- **Timestamps:** spread over 30-60 days so charts and activity feeds look alive
- **Status distribution:** ~30% done, ~40% in progress, ~30% todo - all-todo looks unused

---

## Verification checklist

```
[ ] `npm run db:seed` runs without errors
[ ] Demo credentials printed at end of output
[ ] App shows populated data immediately after seed
[ ] Demo banner shows in DEMO_MODE=true
[ ] Timestamps spread over multiple weeks
[ ] At least 3 users with different roles
[ ] Primary entities have 15+ records
[ ] No real personal data used
[ ] Seed is idempotent (run twice = same result)
```

---

## Return to session

When seed script is written and tested, signal to `hackathon-session` that the seed
phase is done. Session continues with tests and PR.



