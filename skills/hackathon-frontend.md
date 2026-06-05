---
description: Frontend implementation guide. A11y, state boundaries, components.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-frontend
Frontend rules. Enforce A11y + State.

## Phase 1: Stack
- Read `PLAN.md`.
- Identify: Framework, Components, CSS, State, Routing.

## Phase 2: Structure & State
- **Structure**: `ui/`, `components/`, `layouts/`, `hooks/`, `lib/`, `types/`.
- **State Rules**:
  - UI State -> `useState`.
  - Form State -> React Hook Form.
  - Server State -> React Query/SWR (NOT `useEffect`).
  - Shared Client -> Zustand/Context.
- **Responsive**: Mobile-first always (e.g. `p-4 md:p-6`).

## Phase 3: A11y Checklist
- [ ] Semantic HTML (`<button>`, not `<div onClick>`).
- [ ] Keyboard reachable.
- [ ] Visible focus rings.
- [ ] ARIA labels on icon buttons.
- [ ] Contrast >= 4.5:1.
- [ ] Image `alt`.
- [ ] Form `<label>`.

## Phase 4: Performance
- [ ] Virtualize lists > 100 items.
- [ ] Lazy load heavy imports.
- [ ] Prevent layout shifts.

## Rules
- Check list before return.
- Server state = React Query. Never `useEffect` fetch.
