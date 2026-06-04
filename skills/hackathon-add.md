---
description: Add new scope to an in-flight project — new features, security hardening, refactoring, or any other initiative — as a new GitHub Project or as epics within an existing one. Safe to run at any time alongside active work.
allowed-tools: mcp__github__*, Read, Write, Glob, Grep, Bash
---

# Skill: hackathon-add

**Add new scope to a project already using this framework.** Creates a new GitHub
Project (or adds epics to an existing one) without disrupting in-flight work.

Use this when you want to:
- Add a new batch of features (e.g. "v2", "Mobile", "Admin Portal")
- Run a hardening initiative (security audit fixes, performance, accessibility)
- Attack technical debt as a structured project
- Add any other initiative after the initial setup has already run

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Add features", "Add a project", "I want to harden this", "Add security hardening",
"Add refactoring", "Add tech debt", "Add performance improvements",
"Add <anything> as a new project", "We need to add more scope"

---

## Step 0 — Read config and current state

Read `hackathon.config.yml` (extract `project_breakdown` and `epic_breakdown` gates).

Via the GitHub MCP:
- List existing GitHub Projects
- List open and recently-closed epic issues

Read `PLAN.md`, `SPECS.md`, and `AGENTS.md`.

This gives a complete picture of what already exists before adding anything.

---

## Step 1 — Clarify what's being added

Ask the user:

> "What do you want to add?
>   A) New features — functional capabilities that didn't exist before
>   B) Security hardening — auth fixes, input validation, secrets management, OWASP gaps
>   C) Refactoring — code quality, architecture cleanup, tech debt reduction
>   D) Performance — latency, throughput, caching, query optimization
>   E) Accessibility — a11y audit and fixes
>   F) Something else — describe it"

Then ask:

> "Should this be:
>   A) A new GitHub Project (separate board, own set of epics)
>   B) Additional epics inside an existing project — which one?"

Use the answers to shape the scope in Step 2.

---

## Step 2 — Scan existing codebase (for hardening / refactoring)

If the initiative type is B, C, D, or E (anything other than purely new features),
scan the codebase before scoping:

**Security hardening scan:**
- Check for: unvalidated inputs, SQL/NoSQL injection patterns, hardcoded secrets,
  missing auth checks on routes, insecure direct object references, missing CSRF
  protection, missing rate limiting, exposed error details
- Read existing auth implementation, middleware, and route handlers
- Note: what exists vs what's missing vs what's broken

**Refactoring scan:**
- Identify: duplicated logic, large files (>300 lines), deeply nested conditionals,
  missing abstractions, untested code, deprecated dependencies
- Note: high-impact vs low-impact areas

**Performance scan:**
- Check: N+1 query patterns, missing indexes, unoptimized loops, large payloads,
  missing caching layers
- Read database schema and query patterns if present

**Accessibility scan:**
- Check: missing ARIA labels, keyboard navigation, color contrast issues,
  missing alt text, form label associations

Use findings to populate scope in Step 3. Do not guess — only report what you
actually found in the code.

---

## Step 3 — Grilling (conditional)

**If `project_breakdown.grilling: true`:** call `hackathon-grilling` with context:
`"scoping a <initiative type> project for <repo name>"`.

For hardening/refactor initiatives, pass the scan findings from Step 2 as context
so grilling can refine priorities rather than re-discover them.

**If `project_breakdown.grilling: false`:** proceed immediately.

---

## Step 4 — Propose scope

Present the proposed scope to the user. Format depends on what's being added:

**New GitHub Project:**
```
Proposed new project: <name>
  Goal: <one sentence>
  Epics:
    1. <title> — <done criterion>
    2. <title> — <done criterion>
    ...

Does this look right? Say "looks good" or describe changes.
```

**Additional epics to existing project:**
```
Proposed epics for <existing project name>:
  1. <title> — <done criterion>
  2. <title> — <done criterion>
  ...

Does this look right? Say "looks good" or describe changes.
```

Wait for approval. Loop (apply changes → re-present) until explicit approval.
Respect `project_breakdown.human_required` and `epic_breakdown.human_required` gates.
If both are `false`, skip approval and proceed.

---

## Step 5 — Update SPECS.md (if relevant)

If the new scope adds data models, API routes, new business rules, or env vars,
update `SPECS.md` to include them.

Show the proposed additions to the user before writing. Write on approval.

Commit the updated SPECS.md:
```bash
git add SPECS.md
git commit -m "chore: update SPECS.md for <initiative name>"
git push origin main
```

---

## Step 6 — Create GitHub Project (if new project)

If adding a new GitHub Project, create it via the GitHub MCP.

**Name:** `<initiative name>`
**Description:** `<goal>`

Record the project node ID and URL.

---

## Step 7 — Create epic issues

For each approved epic, create one GitHub issue via the GitHub MCP — **sequentially**.

Use the same body format as `hackathon-epics`:
- `## Project` — which GitHub Project this belongs to
- `## Goal` — done criterion
- `## Context` — relevant SPECS.md sections, existing code to build on or fix
- `## Dependencies` — other epics that must close first
- `## Acceptance Bar` — what causes PR review failure
- `## Open Questions`
- `## Child Issues` (left blank for hackathon-decompose to fill)

**Labels:** `epic`, `ai-approved`

**After creating each issue:** add it to its GitHub Project via the GitHub MCP.

---

## Step 8 — Update tracking issue

Update the `[Project] Tracking` issue body to include the new project/epics.
Comment on it:
```
agent: added project "<name>" — <N> epics created: #<list>
```

---

## Step 9 — Report

```
✓ Scope added

<If new project:>
GitHub Project created: <name> — <URL>

Epics created (<N> total):
  #<n> · [Epic] <title>
  ...

Next steps:
Run /hackathon-decompose to break these epics into tasks.
(They are already ai-approved.)
```

---

## Rules

- **Never** add epics to a project whose GitHub Project board doesn't exist yet —
  create the project first (Step 6).
- **Never** skip the codebase scan for hardening/refactoring initiatives — scope
  without evidence produces useless epics.
- **Always** update SPECS.md before creating epic issues, so the new epics can
  reference the updated spec.
- **Always** add new epics to the tracking issue so the project state stays accurate.
- **Safe to run alongside active work** — new epics are `ai-approved` and won't
  interfere with `in-progress` tasks on other branches.
- **Respect gates:** `project_breakdown.human_required` governs project creation,
  `epic_breakdown.human_required` governs epic creation.
