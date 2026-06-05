---
description: Deploy application. Dockerfile, CI/CD, ENV wiring.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-deploy
Live URL + CI/CD Pipeline.

## Phase 1: Strategy
- Check `PLAN.md`.
- Platform: Vercel, Railway, Fly.io.

## Phase 2: Dockerfile (If applicable)
- Use multi-stage builds.
- Example: Node (base -> deps -> builder -> runner).
- Set `NODE_ENV=production`.

## Phase 3: CI/CD
- Write GitHub Actions workflow (`.github/workflows/deploy.yml`).
- Triggers: `on: push branches: [main]`.

## Phase 4: ENV & DB
- Provide `.env.example` (committed).
- Never commit `.env`.
- Migrations in CI: `npx prisma migrate deploy` (Never `dev` in prod).

## Phase 5: Verification Checklist
- [ ] Builds locally with prod ENVs.
- [ ] Docker builds.
- [ ] GH Actions pass.
- [ ] DB URL points to prod DB.
- [ ] `/health` endpoint returns 200.
- [ ] Live URL works.

## Rules
- Check list before returning to session.
