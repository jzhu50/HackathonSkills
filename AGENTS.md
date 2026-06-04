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

- A **GitHub Project** is an initiative container grouping epics into one named
  deliverable (e.g. "MVP", "Admin Portal"). Created by `hackathon-plan`.
- An **Epic** is a feature within a project. Scoped by `hackathon-epics`, decomposed
  into tasks by `hackathon-decompose`.
- A **Task** is a session-sized unit of work. Implemented by `hackathon-session`.

The coordination primitives are:
- **GitHub Projects** = initiative containers - group epics by deliverable
- **Issues** = units of work (epics and tasks)
- **Labels** = issue state machine
- **Assignees** = who is working on what right now
- **Comments** = handoff notes, status updates, blockers, rationale
- **PRs** = the only valid close-out path for completed work
- **PLAN.md** = the living project brain (never modified during parallel work)
- **SPECS.md** = implementation detail

---

## Oversight configuration

All human-in-the-loop gates are governed by `hackathon.config.yml` at the repo root.
Read this file at the start of every skill. Missing file or missing keys default to
maximum oversight (all gates `true`, `testing: required`, `comments: verbose`).

The gates and what they control:

| Gate | Governs | `true` (default) | `false` |
|---|---|---|---|
| `project_breakdown.grilling` | `hackathon-plan` | Call `hackathon-grilling` before scoping projects and generating SPECS.md | Skip interrogation, best-guess |
| `project_breakdown.human_required` | `hackathon-plan` | Show proposed projects in chat, wait for approval before creating GitHub Projects | Create GitHub Projects immediately |
| `epic_breakdown.grilling` | `hackathon-epics` | Call `hackathon-grilling` before scoping epics | Skip interrogation, best-guess |
| `epic_breakdown.human_required` | `hackathon-epics` | Show proposed epics in chat, wait for approval before GitHub | Create epics immediately |
| `task_breakdown.grilling` | `hackathon-decompose` | Call `hackathon-grilling` before decomposing each epic | Skip interrogation, best-guess |
| `task_breakdown.human_required` | `hackathon-decompose` | Show proposed tasks in chat, wait for approval before GitHub | Create tasks immediately |
| `task_completion.human_required` | `hackathon-session` | Show completed work in chat, wait for approval before opening PR | Open PR immediately after tests pass |
| `code_review.human_required` | `hackathon-session` | Human triggers `hackathon-review` and decides merge/changes | Session auto-reviews and merges; loops until clean |
| `epic_review.human_required` | `hackathon-verify` | Human reviews and merges epic->main PR | Auto-merge on clean verify; failures always escalate |

**When `human_required: true`:** the skill presents its output in chat and waits for
approval before writing to GitHub. If the human requests changes, apply them, then
loop back for approval again. GitHub receives only approved work.

**When `human_required: false` at every gate:** running `/hackathon-plan` kicks off
the full pipeline end-to-end without pausing. Any failure (test regression,
verify failure) escalates to human regardless of config.

**Merging:** `code_review.human_required: false` enables auto-merge of task PRs.
`epic_review.human_required: false` enables auto-merge of epic->main PRs.
Both default to `true` - AI does not merge without explicit permission unless configured.

---

## GitHub MCP - required for all GitHub operations

Use the **GitHub MCP** (`mcp__github__*`) for every GitHub operation:
reading and writing issues, labels, assignees, comments, and pull requests.

Do **not** use `gh`, `curl`, the GitHub REST API directly, or any Bash command for
GitHub operations the MCP can handle.

Make MCP calls **sequentially, not in parallel.** Parallel calls stack at the
permission prompt and require a full retry cycle.

---

## Label states

| Label | Meaning |
|---|---|
| `needs-human-review` | Used only for bug issues filed during verify and discovered-scope issues - always requires human review regardless of config |
| `ai-approved` | Ready for an agent to claim and work |
| `in-progress` | Actively being worked - has an assignee |
| `blocked` | Cannot proceed - comment on the issue explains why |
| `in-review` | PR is open and waiting for review/merge |
| `epic` | Parent container - work happens in child task issues |
| `bug` | Something is broken - routed to hackathon-debug |

**Note:** when `human_required: true` gates are on, human approval happens in chat
before issues are created. Issues therefore land on GitHub already labeled `ai-approved`,
not `needs-human-review`. The `needs-human-review` label is reserved for bug issues
and discovered scope that always require human judgment regardless of config.

An issue has exactly one of: `needs-human-review`, `ai-approved`, `in-progress`,
`blocked`, `in-review`. `epic`, `bug`, and `blocked` are additive.

`in-review` means exactly one thing: a PR is open and unmerged. Do not apply it
in any other situation.

When the human approves a PR and merges it, GitHub auto-closes the issue (via
`Closes #n` in the PR body). The reviewer also removes the `in-review` label on
merge so a reopened issue never carries a stale state.

---

## Branch strategy

Every epic gets its own branch. Every task gets a branch off its epic branch.

| Branch | Naming | Created by | PR target |
|---|---|---|---|
| Epic | `epic-<n>-<slug>` | hackathon-decompose | main |
| Task | `<n>-<slug>` | hackathon-session | epic branch |
| Verify | (epic branch directly) | hackathon-verify | main |

**Epic branch lifecycle:**
1. `hackathon-decompose` creates `epic-<n>-<slug>` from main and pushes to origin.
2. Task branches fork off the epic branch.
3. Task PRs merge into the epic branch (human reviews and merges).
4. The verify task is the last child - it opens a PR from the epic branch to main.
5. The PR body contains `Closes #<epic>` and `Closes #<verify-task>` - GitHub auto-closes both on merge.

**Before the verify task opens the epic->main PR,** it rebases the epic branch onto the
latest main to incorporate any other epics that have merged since the epic branch was created.

**Never commit to `main` directly.** Branch protection on `main` should enforce this.

---

## Git sync - every session, before anything else

```bash
# Preserve any uncommitted work from a crashed previous session
CURRENT_BRANCH=$(git branch --show-current)
if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ] && [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -m "agent: checkpoint - session restart" || true
  git push -u origin "$CURRENT_BRANCH" || true
fi
# Note: empty CURRENT_BRANCH means detached HEAD - skip checkpoint, cannot push.

# Sync main
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main has diverged. Comment on the tracking issue and stop.

**Per task:** before creating a task branch, sync the epic branch:
```bash
git fetch origin
git checkout epic-<n>-<slug>
git merge --ff-only origin/epic-<n>-<slug>
git checkout -b <task-n>-<slug>
```

---

## Claiming an issue

**Pick at random from available candidates** when multiple exist - not the oldest.
In a parallel team, all machines starting simultaneously and targeting the same item
causes livelock. Randomisation breaks the symmetry.

Do all steps **sequentially** via the GitHub MCP, with no other actions between:

1. Add yourself as assignee + change label to `in-progress`
2. Comment: `agent: claiming - [your github username] - [ISO timestamp]`

**Collision check:** Re-read the issue. Two assignees or two claiming comments within
2 minutes = collision. Both colliding agents back off: unassign yourself, **reset the
label to its pre-claim state** (`ai-approved`), comment `agent: collision - backing off`,
pick a different issue.

---

## Dependency unblocking - every session, during orientation

For each `blocked` issue, read the issue numbers referenced in its `## Blocked By`
section. If every referenced issue is now closed, **remove the `blocked` label** (do not
touch `needs-human-review` if present - it stays until a human approves). Comment:
`agent: dependency closed - removed blocked label, awaiting human review`.

---

## PLAN.md during parallel work

**Never modify PLAN.md in a task branch.** Two agents editing PLAN.md on separate
branches guarantees a merge conflict on the most critical shared file.

If your work reveals PLAN.md is wrong or incomplete:
1. Create a `[Plan Update] <description>` issue via the GitHub MCP, labeled `needs-human-review`
2. Add a comment to the `[Project] Tracking` issue describing the proposed change
3. Continue with the current PLAN.md - the update is its own sequential task

---

## Capturing scope during work

When you discover work outside your current issue, create an issue via the GitHub MCP
before continuing:

- Title: `[#parent] short imperative description`
- Body: parent reference, goal, context, acceptance criteria
- Label: `needs-human-review` (human decides priority before AI works it)

**Never let discovered scope stay uncaptured.** Issue first, then continue working.

---

## Testing protocol

Tests are a first-class acceptance requirement.

- **Before starting implementation:** run the full test suite to get a baseline - you
  need to know what was already failing before you touched anything.
- **During implementation:** run tests after each meaningful piece of work. Output
  what you expect each test to show and what actually happened.
- **Before opening a PR:** run the full test suite. Every failure must be fixed or
  explicitly noted in the PR body.
- **If tests fail unexpectedly** (they were passing at baseline, now they're not):
  stop and call `hackathon-debug` before continuing.
- **During review:** a PR missing required tests does not meet acceptance criteria.

The test command lives in `PLAN.md` (Stack table -> Test command row).

---

## PR review gate

**Humans trigger all PR reviews.** The `in-review` label means a PR is waiting for
the human to invoke `hackathon-review`.

After the AI review posts findings, the human decides:
- **Merge:** tell Claude to merge the PR via the GitHub MCP
- **Request changes:** tell Claude to post a changes-requested review on the PR; the
  task label returns to `ai-approved` so the worker can pick it up and fix it

There is no intermediate status while the human is thinking. PRs sit in `in-review`
until the human acts.

---

## Merge conflict protocol

**Reviewer's role (via hackathon-review):** before merging, check the PR's `mergeable`
state. If conflicted:
1. Post on PR: `agent: merge conflict - branch must be rebased`
2. Change issue label `in-review` -> `ai-approved` (worker picks up and rebases)
3. Comment on issue with rebase instructions

**Worker's role:** if a `ai-approved` issue has an `agent: merge conflict` comment,
check out the branch, rebase onto the target branch (epic or main), push with
`--force-with-lease`, return the issue to `in-review`.

---

## Closing out a task

**A PR is the only valid close-out path.**

1. Push the feature branch
2. Open a PR via the GitHub MCP - body must include `Closes #<n>` on its own line,
   base must be the epic branch (or main for the verify task)
3. Change issue label to `in-review` via the GitHub MCP
4. Comment on the issue: what was built, PR number, new issues created, test suite status
5. Continue to next `ai-approved` task in the loop

**Do not close the issue manually.** GitHub closes it automatically on merge.

---

## Stale claim reclaim

An `in-progress` issue is stalled if its most recent agent comment is the original
claiming comment (no progress updates) and is more than 30 minutes old.

If no `ai-approved` tasks remain but a stale `in-progress` task exists:
- Check whether the branch was pushed (`git fetch origin && git branch -r`)
- If no branch: reclaim fresh, comment `agent: reclaiming - no branch found, restarting`
- If branch exists: check it out, read prior comments, continue where the previous
  agent left off

---

## Security notes

**PAT scope:** A personal access token covers all repos the account can access.
Use fine-grained PATs scoped to this repo if your GitHub plan supports it.

**`mcp__github__*` covers all GitHub MCP tools,** including destructive ones.
Review what your MCP server exposes and tighten the allowlist if possible.
