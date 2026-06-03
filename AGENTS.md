# Agent Coordination Protocol

This file is the source of truth for how agents coordinate on this project.
All agent skills reference it. If you are not using Claude Code, read this file
in full as your system prompt before starting any session.

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

## One context, one task

Each agent session handles exactly one unit of work — one task or one PR review —
then stops. The human starts a new session for the next unit.

This keeps each context fresh (no stale state about what other agents did an hour ago),
makes parallel agents safe (each works on its own branch), and produces a clean
record of what each session accomplished.

**Never pick up a second task in the same context.**

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
| `needs-scoping` | Too large or unclear to start — must be decomposed into tasks first |
| `ready` | Scoped, unblocked, no assignee — available to claim |
| `in-progress` | Actively being worked — has an assignee |
| `blocked` | Cannot proceed — comment on the issue explains why |
| `in-review` | PR is open and unmerged — waiting for a review session |
| `epic` | Parent container — work happens in child task issues |
| `bug` | Something is broken — routed to hackathon-debug |

An issue has exactly one of: `needs-scoping`, `ready`, `in-progress`, `blocked`, `in-review`.
`epic` and `bug` are additive.

`in-review` means exactly one thing: a PR is open and unmerged. Do not apply this label
in any other situation. GitHub auto-removes it (by closing the issue) when the PR merges.

---

## Git sync — every session, before anything else

At the start of every invocation, before reading GitHub state or touching any files:

```bash
# 1. Preserve any uncommitted work from a crashed previous session
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -m "agent: checkpoint — session restart" || true
  git push -u origin "$CURRENT_BRANCH" || true
fi

# 2. Sync main (--ff-only fails loud if local main diverged — surfaces bugs, doesn't hide them)
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main diverged. This should never happen (agents never
commit to main). Comment on the tracking issue and stop — do not proceed with stale state.

## Branch per issue — always

Every issue gets its own branch created before any code is written.
Handle the case where the branch already exists (from a stalled reclaimed session):
```bash
git checkout -b <issue-number>-<short-slug> 2>/dev/null || git checkout <issue-number>-<short-slug>
```

Never commit to `main` directly. With branch protection enabled on `main`
(recommended — Settings → Branches → require PR before merging), direct pushes will
be rejected automatically.

---

## Claiming an issue

**Always pick at random from available candidates — never the oldest.**
In a parallel team, all machines start simultaneously and see the same issue list.
"Oldest first" causes every machine to target the same item, collide, back off,
and target the same next item — a livelock. Randomisation breaks the symmetry.

Do all steps **sequentially** via the GitHub MCP, with no other actions between them:

1. Add yourself as assignee + change label to `in-progress`
2. Comment: `agent: claiming — [your github username] — [ISO timestamp]`

**Collision check (multi-agent concurrent sessions only):** Re-read the issue. Two
assignees or two claiming comments within 2 minutes = collision. Unassign, comment
`agent: collision — backing off`, pick a different issue at random.

---

## PLAN.md during parallel work

**Never modify PLAN.md in a task branch.** Two agents editing PLAN.md on separate
branches guarantees a merge conflict on the most critical shared file.

If your work reveals PLAN.md is wrong or incomplete:
1. Create a `[Plan Update] <description>` issue via the GitHub MCP, labeled `ready`
2. Add a comment to the `[Project] Tracking` issue describing the proposed change
3. Continue with the current PLAN.md — the update is its own sequential task

---

## Capturing scope during work

When you discover work outside your current issue, create an issue via the GitHub MCP
before continuing:

- Title: `[#parent] short imperative description`
- Body: parent reference, goal, context, acceptance criteria
- Label: `ready` / `needs-scoping` / `blocked` as appropriate

**Never let discovered scope stay uncaptured.** Issue first, then continue working.
Agents cannot ask humans mid-task in AFK mode — create a blocked issue and move on.

---

## Merge conflict protocol

Merge conflicts happen when two agents modify the same files on separate branches.

**Reviewer's role:** Before merging, check the PR's `mergeable` state via the GitHub MCP.
If the PR conflicts with `main`:
1. Post a comment on the PR: `agent: merge conflict — branch must be rebased onto main`
2. Change the issue label from `in-review` → `ready` via the GitHub MCP
3. Unassign the issue
4. Comment on the issue with rebase instructions (branch name, PR number, what to do)

**Next agent's role (Path A3 in hackathon-session):**
The `agent: merge conflict` comment on a `ready` issue signals the rebase path.
```bash
git fetch origin
git checkout <branch-name>
git rebase origin/main
# resolve conflicts if any
git push --force-with-lease origin <branch-name>
```
After rebasing, comment on the PR and return the issue to `in-review`.

---

## Stale claim reclaim

An agent that crashes mid-task leaves the issue `in-progress` indefinitely. This
prevents the loop from claiming it.

**Detection:** During Phase 1 orientation, an `in-progress` issue is stalled if its
most recent agent comment is the original claiming comment with no subsequent activity,
and that comment is more than 2 hours old.

**Reclaim:** If no `ready` issues exist (Path A'), a stalled issue may be reclaimed:
- Check whether the branch was pushed (`git fetch origin && git branch -r`)
- If no branch: reclaim fresh — comment `agent: reclaiming — no branch found, restarting`, re-assign, start from scratch
- If branch exists: check it out, read prior comments for context, continue from where the previous agent left off

---

## Testing protocol

Tests are a first-class acceptance requirement, not an afterthought.

- **During decomposition:** every task's acceptance criteria must include a test requirement
  (`Tests written for new behavior` and `Full test suite passes`)
- **During implementation:** write tests alongside the feature, not after
- **Before opening a PR:** run the full test suite; fix any failures; note unfixed ones in the PR body
- **During review:** a PR without the required tests does not meet acceptance criteria — request changes
- **When idle (Path D):** run the test suite to discover pre-existing failures; create `bug` + `ready` issues

The test command lives in `PLAN.md` (Stack table → Test command row). If it is not filled in,
the first task for the project should be to establish one and add it.

---

## Closing out a task

**A PR is the only valid close-out path.**

1. Push the feature branch
2. Open a PR via the GitHub MCP — body must include `Closes #<n>` on its own line
3. Change issue label to `in-review` via the GitHub MCP
4. Comment on the issue: what was built, PR number, new issues created, test suite status, reviewer notes
5. Stop — do not pick up another task in this context

**Do not close the issue manually.** GitHub closes it automatically on merge.

---

## Session ending with work unfinished

1. Push the branch
2. Leave the issue `in-progress`, yourself as assignee
3. Comment via the GitHub MCP: branch name, what's done, what's left, exactly where to pick up

---

## Security notes

**PAT scope:** A personal access token covers all repos the account can access, not
just this one. Use fine-grained PATs scoped to this repo if your GitHub plan supports it.

**CLAUDE.md is agent-editable:** An agent with write access can modify `CLAUDE.md` and
`.claude/commands/`, rewriting skill instructions. Treat changes to these files in PRs
with the same scrutiny as code changes.

**Allowlist scope:** `mcp__github__*` covers all GitHub MCP tools, including destructive
ones. Review what your MCP server exposes and tighten the allowlist if possible.

---

## Bootstrap

Run the bootstrap script once per project from the repo root after filling in `PLAN.md`:

- **Windows:** `.\make-claude-md.ps1`
- **Mac/Linux:** `./make-claude-md.sh`

The script generates:
1. `CLAUDE.md` — full skill content for headless mode (`claude -p "Go"`)
2. `.claude/commands/` — slash commands for interactive Claude Code sessions
3. `.claude/settings.json` — GitHub MCP pre-approved (no permission prompts)
4. `run.sh` / `run.ps1` — the autonomous loop

For other agent CLIs, paste `AGENTS.md` as a system prompt and individual skill files
as additional context when invoking each one.
