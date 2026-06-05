---
description: Security scan. Secrets, SQLi, Auth. Blocks PRs on CRITICAL.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-security-audit
OWASP scan before Epic->Main PR.

## Checks
1. **Secrets**: Grep `git log -p` and source for keys/tokens/`.env`.
2. **Auth**: Verify route protection.
3. **Authorization**: Verify data scoping (e.g., `userId: req.user.id`).
4. **SQLi**: Grep `queryRaw` / interpolation.
5. **Validation**: Verify `req.body` parsed (Zod/Joi).
6. **Rate Limit**: Check auth endpoints.
7. **Deps**: `npm audit --audit-level=high`.

## Output Report
- **CRITICAL**: Blocks PR. Fix required.
- **HIGH/MEDIUM**: Note in PR body.
- **LOW**: Open issue.

## Rules
- Report only. Do NOT fix.
- Return report to `hackathon-verify`.
