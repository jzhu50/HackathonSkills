---
description: Post-implementation security scan - OWASP Top 10, exposed secrets, SQL injection, missing auth checks, insecure dependencies. Auto-called by hackathon-verify before opening the epic->main PR. Distinct from code review: code review checks acceptance criteria, this checks for things the implementation never set out to address.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-security-audit

Auto-called by `hackathon-verify` before opening the epic->main PR. Outputs a findings
report. Verify acts on the report: CRITICAL findings block the PR; HIGH/MEDIUM are
noted in the PR body; LOW go to the issue tracker.

---

## Trigger

Called internally by `hackathon-verify` before Step 5 (Verdict). Passed: epic branch name.
Not triggered directly by humans in normal flow, but can be invoked manually.

---

## Section 1 - Secret exposure (run first)

```bash
# Scan git history for secrets
git log -p | grep -iE "(password|secret|api_key|token|private_key)\s*=\s*['\"]?[A-Za-z0-9+/]{20,}"

# Check for committed .env files
git ls-files | grep -E "\.env$|\.env\."

# Check for hardcoded credentials in URLs
grep -r "://[^:]+:[^@]+@" --include="*.ts" --include="*.js" --include="*.py" src/ 2>/dev/null

# Scan for common secret prefixes
grep -rn "sk-\|pk_\|rk_\|AKIA\|ghp_\|glpat-" --include="*.json" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules
```

Flag: any `.env` committed, any API key or token hardcoded in source.

---

## Section 2 - Authentication checks

Walk every API route and verify:
```
[ ] Auth check present (middleware or handler level)?
[ ] Token/session verified server-side - not just trusted from client?
[ ] JWT signature actually verified (not just decoded)?
[ ] Session ID comes from cookie, not query param or body?
```

Quick scan for unprotected routes:
```bash
grep -n "app\.\(get\|post\|put\|patch\|delete\)\|router\.\(get\|post\|put\|patch\|delete\)" src/**/*.ts 2>/dev/null | grep -v "authenticate\|requireAuth\|withAuth\|health\|public"
```

---

## Section 3 - Authorization / access control

Authentication != authorization. Verify users can only access their own data:

```typescript
// VULNERABLE - returns any resource to any authenticated user
const item = await db.item.findUnique({ where: { id: req.params.id } });

// CORRECT - scoped to the authenticated user
const item = await db.item.findUnique({ where: { id: req.params.id, userId: req.user.id } });
```

```
[ ] GET /resource/:id - :id scoped to authenticated user?
[ ] PUT/PATCH /resource/:id - ownership verified before update?
[ ] DELETE /resource/:id - ownership verified before deletion?
[ ] Admin-only routes - role check in place?
```

---

## Section 4 - Injection vulnerabilities

```bash
# SQL injection - string concatenation in queries
grep -rn "query\|execute\|raw" --include="*.ts" --include="*.js" src/ 2>/dev/null | grep -E "\`.*\$\{|'\s*\+\s*(req\.|params\.|body\.|query\.)"

# Command injection
grep -rn "exec\|spawn\|execSync" --include="*.ts" --include="*.js" src/ 2>/dev/null | grep "req\."
```

Flag any raw query with user-supplied input. ORMs (Prisma, Drizzle) are safe by default;
flag any `.queryRaw` or `.executeRaw` that interpolates user input.

---

## Section 5 - Input validation

```bash
# Routes that access req.body without parsing through a schema validator
grep -n "req\.body\." src/**/*.ts 2>/dev/null | grep -v "safeParse\|parse\|validate\|schema" | head -20
```

```
[ ] POST/PUT/PATCH body validated through Zod/Joi/Yup before use?
[ ] Validation errors return 422 (not 500)?
[ ] No mass assignment (req.body passed directly to db.update)?
[ ] File uploads: type and size validated?
```

---

## Section 6 - Rate limiting

```
[ ] POST /auth/login - rate limited (max 5-10 req/15min)?
[ ] POST /auth/signup - rate limited?
[ ] POST /auth/forgot-password - rate limited?
[ ] Any endpoint that sends email/SMS - rate limited?
```

---

## Section 7 - Dependency vulnerabilities

```bash
npm audit --audit-level=high 2>/dev/null || true
```

Triage: `critical`/`high` = block PR. `moderate` = note in PR body. `low` = skip.

---

## Output format

Return this report to `hackathon-verify`:

```
SECURITY AUDIT - epic-<n>-<slug>

CRITICAL (blocks PR - must fix before merge)
---------------------------------------------
[C1] <finding - file:line + what the issue is>

HIGH (note in PR body)
----------------------
[H1] <finding>

MEDIUM (note in PR body)
------------------------
[M1] <finding>

LOW (create issue, do not block)
---------------------------------
[L1] <finding>

PASSED
------
[[x]] <check that passed>
```

If no findings in a severity level, omit that section.

---

## Rules

- **CRITICAL findings block the epic->main PR.** Verify files each as a bug issue and does not open the PR.
- **Never flag style issues.** Security findings only.
- **Report findings, don't fix them.** Verify (the caller) files bug issues and routes fixes.



