---
description: Production-grade frontend implementation guide. Enforces the design system decisions, component architecture, accessibility baseline, and performance gates that session won't naturally ask about. Auto-called by hackathon-session when a task involves UI, components, pages, layouts, or frontend work.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-frontend

Called by `hackathon-session` during N3 (implement) when frontend signals are detected.
Provides structured guidance for the implementation phase. Session retains ownership of
git, tests, and PR creation.

---

## Trigger

Auto-called by `hackathon-session` when task title or body contains:
`ui`, `component`, `page`, `screen`, `layout`, `frontend`, `design`, `stylesheet`,
`responsive`, `navigation`, `dashboard`, `form`, `view`

---

## Phase 0 — Load context

Read sequentially:
1. The task issue (already claimed by session) — goal, context, acceptance criteria
2. `PLAN.md` — tech stack section (framework, component library, CSS approach already decided?)
3. `SPECS.md` — UI flows section if it exists
4. Any existing frontend files in the repo (to match existing patterns)

Carry forward whatever is already decided. Only surface questions for gaps.

---

## Phase 1 — Confirm tech stack

Check `PLAN.md` and `SPECS.md` for answers before asking anything. For any of the
following that are not yet decided, ask in one batched message:

- **Component library** — shadcn/ui, MUI, Radix, Chakra, none?
- **CSS approach** — Tailwind, CSS Modules, styled-components, vanilla?
- **Framework + version** — React, Next.js App Router, Vue, Svelte?
- **State management** — local only, or shared? (Zustand, Redux, Jotai, Context?)
- **Routing** — React Router, Next.js, TanStack Router, none?
- **Accessibility baseline** — WCAG AA required? Keyboard nav required?
- **Dark mode** — required?
- **Target devices** — mobile-first? Key breakpoints?

Once confirmed, summarize before writing any code:
```
Frontend stack confirmed:
- Framework: <value>
- Components: <value>
- Styles: <value>
- State: <value>
- Routing: <value>
- A11y: <value>
```

---

## Phase 2 — Enforce structure

Before building individual components, establish or verify:

**Directory structure:**
```
ui/           # Primitive components (Button, Input, Badge) — from library or custom
components/   # Composed feature components (UserCard, TaskList)
layouts/      # Page-level layout wrappers
hooks/        # Custom hooks extracted from components
lib/          # Utilities, helpers, API clients
types/        # Shared TypeScript interfaces
```

**State boundary rules — apply these during implementation:**
- UI state (open/closed, hover, focus) → local `useState`
- Form state → React Hook Form or controlled local state
- Server state (fetched data) → React Query / SWR / tRPC
- Shared client state (user, cart, theme) → Zustand or Context
- URL state (filters, pagination) → search params

Flag any proposed `useContext` for data that could be server state — that's the most common architecture mistake.

**Responsive baseline — mobile-first, no exceptions:**
```css
/* mobile base */
.container { padding: 1rem; }
/* tablet */
@media (min-width: 768px) { ... }
/* desktop */
@media (min-width: 1280px) { ... }
```
In Tailwind: `class="p-4 md:p-6 lg:p-8"` — mobile value always first.

---

## Phase 3 — Design principles

Commit to a clear aesthetic before writing markup:
- Use CSS variables for all design tokens — never hardcode hex values
- Choose typography intentionally (avoid Inter/Roboto as unreflective defaults)
- Motion: CSS-only where possible, purposeful on load/hover/transition, respects `prefers-reduced-motion`
- Avoid generic "out of the box" aesthetics — hackathon judges notice effort in design

---

## Phase 4 — Accessibility checklist

Verify every component before returning to session:

```
[ ] Semantic HTML — button is <button>, not <div onClick>
[ ] All interactive elements keyboard-reachable (Tab, Enter, Escape, Arrow keys)
[ ] Focus rings visible — never `outline: none` without a replacement
[ ] ARIA labels on icon-only buttons and inputs without visible labels
[ ] Color contrast ≥ 4.5:1 for normal text, 3:1 for large text (WCAG AA)
[ ] Images have alt text (or alt="" if decorative)
[ ] Form fields have associated <label> or aria-label
[ ] Error messages linked to inputs via aria-describedby
[ ] Motion respects prefers-reduced-motion
```

---

## Phase 5 — Performance gates

For any component that renders a list or loads data:

```
[ ] Lists virtualized if >100 items (TanStack Virtual)
[ ] Images use next/image or loading="lazy"
[ ] Heavy imports are dynamic (next/dynamic or React.lazy)
[ ] No layout shifts — reserve space for async content with skeleton/min-height
[ ] No library imported for a single utility function
```

---

## Red flags to avoid

| Smell | Problem |
|---|---|
| `useState` holding data fetched from an API | Use React Query — useState doesn't cache or deduplicate |
| `useEffect` with fetch inside a component | Extract to a hook or use React Query |
| CSS hardcoding hex values | Use CSS variables — blocks theming and dark mode |
| `z-index: 9999` | Symptom of no stacking context strategy |
| Components >300 lines without extraction | Split into smaller composed components |

---

## Return to session

When implementation is complete and all checklists pass, signal to `hackathon-session`
that the frontend implementation phase is done. Session continues with tests and PR.

---

## Rules

- **Never skip the accessibility checklist.** Retrofitting a11y costs more than building it in.
- **Never hardcode design values.** Use CSS variables or Tailwind tokens.
- **Never use `useEffect` for data fetching.** Server state belongs in React Query / SWR.
- **Always mobile-first.** No exceptions.
