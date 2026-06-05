# Agent Coordination Protocol

This file is the source of truth for how agents coordinate on this project.
All agent skills reference it. If you are not using Claude Code, read this file
in full before starting any session.

---

## Mental model

GitHub is the team's shared brain. You have no memory between sessions - GitHub does.
Every session starts by reading state from GitHub. Every session ends by writing state
back to GitHub. A teammate's agent (or your own, in a new context) will reconstruct
everything from what you leave behind.

The hierarchy is: **GitHub Project -> Epics -> Tasks**

Work flows through four phases:
```
PLAN.md
  |-> hackathon-plan      Phase 1: scope into Projects + generate SPECS.md
        |-> hackathon-epics   Phase 2: scope each Project into Epic issues
              |-> hackathon-decompose  Phase 3: break each Epic into Task issues
                    |-> hackathon-session   Phase 4: implement Tasks, open PRs
```

- A **GitHub Project** is an initiative container grouping epics into one named deliverable.
- An **Epic** is a feature within a project.
- A **Task** is a session-sized unit of work.

The coordination primitives are:
- **GitHub Projects** = initiative containers.
- **Issues** = units of work (epics and tasks).
- **Labels** = state machine.
- **Assignees** = who is working now.
- **Comments** = status updates, blockers, rationale.
- **PRs** = only valid close-out path.
- **PLAN.md** = project brain (never modify in task branch).
- **SPECS.md** = implementation detail.

---

## Oversight configuration

| Gate | Governs | `true` (default) | `false` |
|---|---|---|---|
| `project_breakdown.grilling` | `hackathon-plan` | Interrogate before Projects | Best-guess |
| `project_breakdown.human_required` | `hackathon-plan` | Chat approval before GitHub | Create immediately |
| `epic_breakdown.grilling` | `hackathon-epics` | Interrogate before Epics | Best-guess |
| `epic_breakdown.human_required` | `hackathon-epics` | Chat approval before GitHub | Create immediately |
| `task_breakdown.grilling` | `hackathon-decompose` | Interrogate before tasks | Best-guess |
| `task_breakdown.human_required` | `hackathon-decompose` | Chat approval before GitHub | Create immediately |
| `task_completion.human_required` | `hackathon-session` | Chat approval before PR | Open PR immediately |
| `code_review.human_required` | `hackathon-session` | Human triggers review | AI reviews and merges |
| `epic_review.human_required` | `hackathon-verify` | Human reviews epic->main PR | Auto-merge on clean verify |

**Autonomy Level:** `hackathon.config.yml` `autonomy: total` enables end-to-end autonomous loops. Failures tag metadata for future agents rather than escalating.

---

## Label states

| Label | Meaning |
|---|---|
| `needs-human-review` | Bug/Discovered scope - always needs human judgment |
| `ai-approved` | Ready for claim |
| `in-progress` | Active work - has assignee |
| `review-ready` | Task done, PR open, waiting for review |
| `in-review` | Review in progress - prevent double review |
| `epic` | Parent container |
| `bug` | Broken - routes to hackathon-debug |

An issue has exactly one of: `needs-human-review`, `ai-approved`, `in-progress`, `review-ready`, `in-review`.

---

## Branch strategy

Every epic gets its own branch. Every task gets a branch off its epic branch.

| Branch | Naming | Created by | PR target |
|---|---|---|---|
| Epic | `epic/<n>-<slug>` | hackathon-decompose | main |
| Task | `task/<n>-<slug>` | hackathon-session | epic branch |

**Merge Rules:**
- **Epic -> Main:** Regular merge commit (`git merge --no-ff`) to preserve history.
- **Task -> Epic:** Squash merge (standard task close-out).
- **Main -> Epic:** **BANNED**. Use `git rebase origin/main`.

---

## Git sync - REBASE ONLY

**Sync main:**
```bash
git fetch origin
git rebase origin/main
```
If rebase fails: `git rebase --abort`, open PR as-is, tag `[REBASE_FAILED]`.

**Per task:** sync epic branch:
```bash
git fetch origin
git rebase origin/epic/<n>-<slug>
```

---

## Collision Prevention

Before any `claim` or `review`:
1. **Refresh:** Get latest issue comments + assignees.
2. **Verify:** Check if someone claimed in last 120 seconds.
3. **Act:** Claim/Review only if clear.

---

## Issue Dependency Tracking

Every issue must include:
- `## Blocks`: List of issues this task enables.
- `## Blocked By`: List of issues required before this starts.

---

## Artifact Hygiene

Add `.geminiignore` to repo. Exclude:
- `.claude/`
- Session logs/artifacts
- Agent markdown skills (unless loading)
