---
description: Generate the README update, API reference, and a literal demo walkthrough script — what to click, what to say, what the judge sees. Triggered manually before a demo or deadline.
allowed-tools: mcp__github__*, Read, Write
---

# Skill: hackathon-docs-demo-script

**Manual trigger. Run 30-60 minutes before a demo or deadline.**

Produces: (1) updated README with live URL and demo credentials, (2) API reference if applicable, (3) a literal demo walkthrough script.

---

## Trigger

"Write the README", "docs", "demo script", "help me demo", "prepare for the demo",
"what do I say", "30 minutes before deadline", or any instruction to document or present.

---

## Phase 0 — Load context

Read sequentially:
1. `PLAN.md` — vision, demo goal, stack, features
2. `SPECS.md` — API routes and UI flows if defined
3. All closed epic issues via the GitHub MCP — what was actually built
4. The tracking issue — overall project state
5. Existing `README.md` — what already exists

Ask the human only for things not in any of the above:
- Live URL (if deployed)
- Demo credentials (if not in seed script)
- Demo duration (2 min, 5 min, 10 min?)
- Any "wow moment" feature to highlight

---

## Part 1 — README update

Write or update `README.md`:

```markdown
# [Project Name]

[One sentence: what it does and who it's for.]

> [One-line value prop or hackathon context]

## What It Does

[2-3 sentences: the problem, the solution, the main workflow. No jargon.]

## Demo

Live: [URL]

Demo credentials:
- Email: `alice@demo.com`  Password: `demo1234`

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | [value] |
| Backend | [value] |
| Database | [value] |
| Auth | [value] |
| Deploy | [value] |

## Quick Start

git clone https://github.com/<org>/<repo>
cd <repo>
npm install
cp .env.example .env.local
# Fill in .env.local
npx prisma migrate dev && npx prisma db seed
npm run dev

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| DATABASE_URL | PostgreSQL connection string | Yes |
| NEXTAUTH_SECRET | Random 32-byte string (`openssl rand -base64 32`) | Yes |

## Team

- [Name](https://github.com/handle) — Role

Built at [Hackathon] · [Date]
```

---

## Part 2 — API reference (if backend exists)

For each endpoint discovered in the codebase or SPECS.md:

```markdown
## API Reference

Base URL: `https://[app-url]/api`
Auth: `Authorization: Bearer <token>` unless marked public.

### POST /auth/login — Public
Request: `{ "email": "string", "password": "string" }`
Response 200: `{ "token": "...", "user": { "id", "email", "name", "role" } }`
Errors: `401 Invalid credentials`, `429 Too many attempts`

### GET /[resource]
Returns all [resources] for the authenticated user.
Response 200: `{ "[resources]": [...], "total": N }`
```

---

## Part 3 — Demo walkthrough script

```
DEMO SCRIPT: [Project Name]
Duration: [X] minutes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPENING (30 sec)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SAY: "[Project Name] solves [problem] for [who]. Here's how it works."
[Open browser to live URL]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1: LOGIN (30 sec)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ACTION: Click "Sign In" → enter alice@demo.com / demo1234
JUDGE SEES: Dashboard with populated data
SAY: "This is the main dashboard — you can see [3 key things]."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 2: CORE FEATURE (60-90 sec)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SAY: "The core workflow is [description]."
ACTION: [Do the primary user action]
JUDGE SEES: [What appears]
SAY: "[The value prop in one sentence]"
[PAUSE — let the judge absorb it]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 3: THE WOW MOMENT (30-60 sec)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SAY: "Here's the part that's genuinely interesting —"
ACTION: [Trigger the impressive feature]
SAY: "[One sentence: why this is hard or novel]"
[PAUSE — let it land]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLOSING (30 sec)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SAY: "[Project Name] does [X] for [who], using [notable tech].
      Built in [time]. Live at [URL]. Happy to answer questions."
[Keep the most impressive view on screen]
```

---

## Speaker notes (append to script)

```
BEFORE: Test full flow 30 min early. Demo credentials in a visible note.
        Fresh browser tab. Close notifications. Have a screen recording as backup.

DURING: Speak to what the judge SEES, not what you're DOING.
        Bad: "Now I'm clicking create." Good: "This is where a user kicks off a project."
        If something breaks: "Let me show you X" — never "it was working this morning."
        Pause after the wow moment. Don't rush past it.

AFTER:  Know your stack cold. Know lines of code / hours — signals effort.
        Have one "what we'd build next" talking point ready.
```

---

## Rules

- **Never invent features that weren't built.** Read the closed epic issues.
- **Demo script must match the actual app state.** Test the flow before writing it.
- **README live URL must be real.** Leave a placeholder only if deploy hasn't happened yet.
