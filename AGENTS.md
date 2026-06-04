# Agent Coordination Protocol

This file is the source of truth for how agents coordinate on this project.
All agent skills reference it. If you are not using Claude Code, read this file
in full before starting any session.

---

## Mental model

GitHub is the team's shared brain. You have no memory between sessions — GitHub does.
Every session starts by reading state from GitHub. Every session ends by writing state
back to GitHub. A teammate's agent (or your own, in a new context) will reconstruct
everything from what you leave behind.

The coordination primitives are:
- **Issues** = units of work
- **Labels** = issue state machine
- **Assignees** = who is working on what right now
- **Comments** = handoff notes, status updates, blockers, rationale
- **PRs** = the only valid close-out path for completed work
- **PLAN.md** = the living project brain (never modified during parallel work)
- **SPECS.md** = implementation detail

---

## Human-in-the-loop workflow

This project uses a human review gate between every major AI step.

```
Human fills PLAN.md
       ↓
hackathon-setup  →  epics created (needs-human-review)
       ↓
Human reviews each epic → labels ai-approved
       ↓
hackathon-decompose  →  tasks created (needs-human-review)
       ↓
Human reviews each task → labels ai-approved
       ↓
hackathon-session  →  tasks implemented → PRs opened (in-review)
       ↓
Human triggers hackathon-review  →  AI posts findings
       ↓
Human decides → tells Claude to merge or request changes
       ↓
On request-changes: task returns to ai-approved for fixes
On merge: epic branch accumulates merged tasks
       ↓
Last task per epic is verify → opens PR: epic branch → main
       ↓
Human reviews and merges the epic PR
```

**No AI agent merges anything without explicit human instruction.**

---

## GitHub MCP — required for all GitHub operations

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
| `needs-human-review` | AI produced output waiting for human review and approval |
| `ai-approved` | Human approved — AI can proceed with this issue |
| `in-progress` | Actively being worked — has an assignee |
| `blocked` | Cannot proceed — comment on the issue explains why |
| `in-review` | PR is open and waiting for human to trigger AI review |
| `epic` | Parent container — work happens in child task issues |
| `bug` | Something is broken — routed to hackathon-debug |

An issue has exactly one of: `needs-human-review`, `ai-approved`, `in-progress`,
`blocked`, `in-review`. `epic` and `bug` are additive.

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
4. The verify task is the last child — it opens a PR from the epic branch to main.
5. Merging the epic→main PR closes the epic.

**Before the verify task opens the epic→main PR,** it rebases the epic branch onto the
latest main to incorporate any other epics that have merged since the epic branch was created.

**Never commit to `main` directly.** Branch protection on `main` should enforce this.

---

## Git sync — every session, before anything else

```bash
# Preserve any uncommitted work from a crashed previous session
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -m "agent: checkpoint — session restart" || true
  git push -u origin "$CURRENT_BRANCH" || true
fi

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

**Pick at random from available candidates** when multiple exist — not the oldest.
In a parallel team, all machines starting simultaneously and targeting the same item
causes livelock. Randomisation breaks the symmetry.

Do all steps **sequentially** via the GitHub MCP, with no other actions between:

1. Add yourself as assignee + change label to `in-progress`
2. Comment: `agent: claiming — [your github username] — [ISO timestamp]`

**Collision check:** Re-read the issue. Two assignees or two claiming comments within
2 minutes = collision. Both colliding agents back off: unassign yourself, **reset the
label to its pre-claim state** (`ai-approved`), comment `agent: collision — backing off`,
pick a different issue.

---

## Dependency unblocking — every session, during orientation

For each `blocked` issue, read the issue numbers referenced in its `## Blocked By`
section. If every referenced issue is now closed, change the label `blocked` → `needs-human-review`
(not directly to `ai-approved` — a human should confirm the unblocked issue before it's
worked) and comment `agent: dependency closed — moved to needs-human-review for human review`.

---

## PLAN.md during parallel work

**Never modify PLAN.md in a task branch.** Two agents editing PLAN.md on separate
branches guarantees a merge conflict on the most critical shared file.

If your work reveals PLAN.md is wrong or incomplete:
1. Create a `[Plan Update] <description>` issue via the GitHub MCP, labeled `needs-human-review`
2. Add a comment to the `[Project] Tracking` issue describing the proposed change
3. Continue with the current PLAN.md — the update is its own sequential task

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

- **Before starting implementation:** run the full test suite to get a baseline — you
  need to know what was already failing before you touched anything.
- **During implementation:** run tests after each meaningful piece of work. Output
  what you expect each test to show and what actually happened.
- **Before opening a PR:** run the full test suite. Every failure must be fixed or
  explicitly noted in the PR body.
- **If tests fail unexpectedly** (they were passing at baseline, now they're not):
  stop and call `hackathon-debug` before continuing.
- **During review:** a PR missing required tests does not meet acceptance criteria.

The test command lives in `PLAN.md` (Stack table → Test command row).

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
1. Post on PR: `agent: merge conflict — branch must be rebased`
2. Change issue label `in-review` → `ai-approved` (worker picks up and rebases)
3. Comment on issue with rebase instructions

**Worker's role:** if a `ai-approved` issue has an `agent: merge conflict` comment,
check out the branch, rebase onto the target branch (epic or main), push with
`--force-with-lease`, return the issue to `in-review`.

---

## Closing out a task

**A PR is the only valid close-out path.**

1. Push the feature branch
2. Open a PR via the GitHub MCP — body must include `Closes #<n>` on its own line,
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
- If no branch: reclaim fresh, comment `agent: reclaiming — no branch found, restarting`
- If branch exists: check it out, read prior comments, continue where the previous
  agent left off

---

## Security notes

**PAT scope:** A personal access token covers all repos the account can access.
Use fine-grained PATs scoped to this repo if your GitHub plan supports it.

**`mcp__github__*` covers all GitHub MCP tools,** including destructive ones.
Review what your MCP server exposes and tighten the allowlist if possible.
