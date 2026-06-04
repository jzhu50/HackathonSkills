---
description: Full authentication and authorization implementation guide. Covers strategy choice (JWT vs sessions vs provider), OAuth, protected routes, token refresh, and the security traps that catch naive implementations. Auto-called by hackathon-session when a task involves auth, login, OAuth, JWT, sessions, or permissions.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-auth

Called by `hackathon-session` during N3 (implement) when auth signals are detected.
Provides structured guidance for the implementation phase. Session retains ownership of
git, tests, and PR creation.

Security-sensitive. Every auth decision has a failure mode. This skill covers the full
surface: strategy choice, implementation patterns, and the traps implementations always miss.

---

## Trigger

Auto-called by `hackathon-session` when task title or body contains:
`auth`, `login`, `signup`, `logout`, `oauth`, `jwt`, `token`, `session`, `password`,
`protected`, `permission`, `role`, `user accounts`, `credentials`, `middleware`

---

## Phase 0 - Load context

Read sequentially:
1. The task issue - goal, context, acceptance criteria
2. `PLAN.md` - stack, any auth decisions already made
3. `SPECS.md` - if auth model described
4. Any existing auth files in the repo

---

## Phase 1 - Strategy decision

Check existing context first. For anything not yet decided, ask in one batch:

1. **Auth approach** - JWT (stateless), sessions (stateful), or delegated provider (Clerk, Auth0, Supabase Auth, NextAuth)?
2. **OAuth providers needed?** - Google, GitHub, Discord, others?
3. **Framework** - Next.js, Express, FastAPI? (determines the right library)
4. **Persistence** - Where are sessions/tokens stored? (DB, Redis, cookie?)
5. **Roles / permissions?** - Per-user roles, team-based access, multi-tenancy?
6. **Token refresh?** - Short-lived access tokens + refresh token rotation?

### Decision matrix: JWT vs sessions

| Factor | JWT (stateless) | Sessions (stateful) |
|---|---|---|
| Scalability | Horizontal scaling trivial | Requires shared session store (Redis) |
| Invalidation | Hard - token lives until expiry | Instant - delete the session record |
| Size overhead | ~500 bytes per request | ~40 bytes (session ID in cookie) |
| Best for | APIs, microservices, mobile | Web apps when instant revocation matters |
| Security trap | Can't revoke without a blocklist | Session fixation on login |

**Hackathon recommendation:** Use a provider (NextAuth / Clerk / Auth0) unless the project specifically needs custom auth. Provider = 30 min. Custom = 4 hours + security holes.

---

## Phase 2 - JWT implementation (if chosen)

### Access + refresh token pattern

```typescript
interface TokenPair {
  accessToken: string;   // Short-lived: 15 min
  refreshToken: string;  // Long-lived: 7 days, stored in DB
}

function generateTokens(userId: string): TokenPair {
  const accessToken = jwt.sign(
    { sub: userId, type: 'access' },
    process.env.JWT_ACCESS_SECRET!,
    { expiresIn: '15m' }
  );
  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET!,
    { expiresIn: '7d' }
  );
  return { accessToken, refreshToken };
}
```

### Token storage - the right way

```typescript
// Refresh token: httpOnly cookie (XSS-safe)
res.cookie('refreshToken', refreshToken, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  maxAge: 7 * 24 * 60 * 60 * 1000,
  path: '/api/auth/refresh',  // Limit scope
});
// Access token: memory only (React state / Zustand)
// NEVER localStorage for access tokens
```

### Refresh token rotation (prevents replay attacks)

```typescript
// POST /api/auth/refresh
async function refreshHandler(req, res) {
  const { refreshToken } = req.cookies;
  if (!refreshToken) return res.status(401).json({ error: 'No refresh token' });

  let payload;
  try {
    payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as { sub: string };
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }

  // Check not revoked
  const stored = await db.refreshToken.findFirst({
    where: { token: refreshToken, userId: payload.sub, revokedAt: null }
  });
  if (!stored) return res.status(401).json({ error: 'Token revoked' });

  // Rotate: revoke old, issue new
  await db.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
  const { accessToken, refreshToken: newRefresh } = generateTokens(payload.sub);
  await db.refreshToken.create({ data: { token: newRefresh, userId: payload.sub } });

  res.cookie('refreshToken', newRefresh, { httpOnly: true, secure: true, sameSite: 'lax' });
  return res.json({ accessToken });
}
```

---

## Phase 3 - Session implementation (if chosen)

```typescript
import session from 'express-session';
import connectPgSimple from 'connect-pg-simple';

const PgSession = connectPgSimple(session);

app.use(session({
  store: new PgSession({ pool: db }),
  secret: process.env.SESSION_SECRET!,  // >=32 random bytes
  resave: false,
  saveUninitialized: false,
  name: '__session',  // Don't use default 'connect.sid'
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 24 * 60 * 60 * 1000,
  },
}));
```

---

## Phase 4 - OAuth (NextAuth.js for Next.js)

```typescript
// app/api/auth/[...nextauth]/route.ts
const handler = NextAuth({
  providers: [
    GoogleProvider({ clientId: process.env.GOOGLE_CLIENT_ID!, clientSecret: process.env.GOOGLE_CLIENT_SECRET! }),
    GitHubProvider({ clientId: process.env.GITHUB_ID!, clientSecret: process.env.GITHUB_SECRET! }),
  ],
  callbacks: {
    async session({ session, token }) {
      session.user.id = token.sub!;  // Add userId for use in API routes
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
});

export { handler as GET, handler as POST };
```

---

## Phase 5 - Protected routes

### Middleware-level (Next.js)

```typescript
// middleware.ts
import { withAuth } from 'next-auth/middleware';

export default withAuth({ pages: { signIn: '/auth/signin' } });

export const config = {
  matcher: ['/dashboard/:path*', '/api/protected/:path*'],
};
```

### Route-level (Express)

```typescript
function authenticate(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    req.user = { id: jwt.verify(token, process.env.JWT_ACCESS_SECRET!).sub };
    return next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function authorize(roles: string[]) {
  return async (req, res, next) => {
    const user = await db.user.findUnique({ where: { id: req.user.id } });
    if (!roles.includes(user.role)) return res.status(403).json({ error: 'Forbidden' });
    return next();
  };
}
```

---

## Phase 6 - Security traps checklist

Verify all of these before signaling completion to session:

```
[ ] Passwords hashed with bcrypt/argon2 (NEVER MD5, SHA1, or plaintext)
[ ] Rate limiting on /login, /signup, /forgot-password (max 5-10 req/15min)
[ ] Account enumeration prevention - same response for "wrong password" and "no account"
[ ] CSRF protection on all state-mutating endpoints
[ ] Token/session invalidated on logout (not just cookie deletion)
[ ] Refresh tokens stored hashed in DB (not plaintext)
[ ] Password reset tokens: single-use, expire in 1 hour, constant-time compare
[ ] No sensitive data (userId, email) in URL parameters
[ ] Secrets in environment variables - not in source code
[ ] Session ID regenerated on login (prevents session fixation)
```

| Pattern | Trap | Fix |
|---|---|---|
| JWT | Stored in localStorage | httpOnly cookie for refresh, memory for access |
| JWT | Long expiry (1 day+) | Access: 15min, Refresh: 7 days with rotation |
| OAuth | `state` param not validated | Always validate - prevents CSRF on OAuth callback |
| Sessions | Session ID not regenerated | Regenerate on login (session fixation) |
| Password reset | Reusable tokens | Mark used on first consumption, expire in 1hr |

---

## Return to session

When implementation is complete and security checklist passes, signal to `hackathon-session`
that the auth implementation phase is done. Session continues with tests and PR.

---

## Rules

- **Use a provider if at all possible.** NextAuth/Clerk/Auth0 = 30 min. Custom = 4 hours + holes.
- **Never store tokens in localStorage.** httpOnly cookie or memory only.
- **Rate limit auth endpoints.** Always.
- **Same error response for wrong password and no account.** Prevents enumeration.



