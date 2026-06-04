---
description: Get the application live for a demo. Produces a Dockerfile (or platform config), GitHub Actions CI/CD workflow, environment variable wiring, and a live URL. Auto-called by hackathon-session when a task involves deployment, CI/CD, Docker, or hosting.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-deploy

Called by `hackathon-session` during N3 (implement) when deploy signals are detected.
Concrete artifact: a live URL + a reproducible deploy pipeline. Session retains ownership
of git, tests, and PR creation.

---

## Trigger

Auto-called by `hackathon-session` when task title or body contains:
`deploy`, `dockerfile`, `ci/cd`, `github actions`, `production`, `host`, `live`,
`vercel`, `railway`, `fly`, `render`, `heroku`, `pipeline`, `environment`

---

## Phase 0 - Load context

Read sequentially:
1. The task issue - what deploy target, what the artifact should be
2. `PLAN.md` - stack, app type, database details
3. Any existing Dockerfile, `.github/workflows/`, or platform config files

---

## Phase 1 - Confirm platform and config

Check existing context first. For anything not yet decided, ask in one batch:

1. **Target platform** - Vercel, Railway, Fly.io, Render, self-hosted?
2. **App type** - Next.js, Node/Express, Python, static site?
3. **Database** - Postgres (where hosted?), SQLite, no DB?
4. **Environment variable names** - list them (values never shared here)
5. **Build command** - `npm run build`, `next build`, other?
6. **Port** - what port does the app listen on?

---

## Phase 2 - Platform fast paths

### Vercel (best for Next.js)

```json
// vercel.json - only needed for non-default config
{
  "buildCommand": "npm run build",
  "env": {
    "DATABASE_URL": "@database-url",
    "NEXTAUTH_SECRET": "@nextauth-secret"
  }
}
```

Set env vars: Vercel Dashboard -> Project -> Settings -> Environment Variables.

### Railway (best for Node APIs + Postgres)

```bash
railway login
railway up
railway add --plugin postgresql  # Auto-provides DATABASE_URL
```

### Fly.io (full Docker control)

```bash
fly auth login
fly launch          # generates fly.toml
fly secrets set DATABASE_URL="..." NEXTAUTH_SECRET="..."
fly deploy
```

---

## Phase 3 - Dockerfile

### Node.js / Next.js (multi-stage)

```dockerfile
FROM node:22-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --only=production

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=3000
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

```
# .dockerignore
node_modules
.next
.git
.env*
```

### Python FastAPI

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Phase 4 - GitHub Actions CI/CD

### Deploy on push to main (Fly.io)

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Deploy on push to main (Vercel)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

---

## Phase 5 - Environment variable wiring

**The pattern:**
```
.env.example   -> committed (template, no values)
.env           -> NOT committed (.gitignore)
GitHub Secrets -> Settings -> Secrets -> Actions -> New secret
Platform       -> Dashboard or `fly secrets set` / `railway variables set`
```

**Always create `.env.example`:**
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/myapp
NEXTAUTH_SECRET=generate-with-openssl-rand-base64-32
NEXTAUTH_URL=http://localhost:3000
NODE_ENV=development
```

**Generate secrets:**
```bash
openssl rand -base64 32
```

**Set GitHub secrets:**
```bash
gh secret set VERCEL_TOKEN --body "your-token"
gh secret set DATABASE_URL --body "postgresql://..."
```

---

## Phase 6 - Database migrations in CI

```yaml
# Prisma
- name: Run migrations
  run: npx prisma migrate deploy
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}

# Drizzle
- name: Run migrations
  run: npx drizzle-kit migrate
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

Never run `migrate dev` in production. Use `migrate deploy`.

---

## Phase 7 - Health check endpoint

Every deployed app needs `/health` for platform uptime checks:

```typescript
// Next.js App Router - app/api/health/route.ts
export function GET() {
  return Response.json({ status: 'ok', timestamp: new Date().toISOString() });
}

// Express
app.get('/health', (req, res) => res.json({ status: 'ok' }));
```

---

## Verification checklist

```
[ ] App builds locally with production env vars
[ ] docker build succeeds (if using Docker)
[ ] GitHub Actions passes on push
[ ] Environment variables set in platform dashboard
[ ] DATABASE_URL points to production DB (not localhost)
[ ] Migrations run as part of deploy
[ ] /health returns 200
[ ] Live URL accessible
[ ] No secrets in git: git log -p | grep -i "secret\|password\|key"
```

---

## Common failure modes

| Failure | Cause | Fix |
|---|---|---|
| Build fails in CI but works locally | Missing env vars in CI | Add to GitHub Secrets |
| DB connection refused | DATABASE_URL points to localhost | Use production DB URL |
| `npm run build` hangs | Missing `NEXT_PUBLIC_*` vars | These must be set at build time |
| Port conflict | App not reading PORT from env | `const port = process.env.PORT ?? 3000` |
| CORS errors after deploy | Origin hardcoded to localhost | Use `ALLOWED_ORIGINS` env var |

---

## Return to session

When deploy artifacts are written and verified locally, signal to `hackathon-session`
that the deploy phase is done. Session continues with tests and PR.



