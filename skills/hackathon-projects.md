---
description: Show GitHub Project completion status and close a project board when all its epics have merged. Run at any time to check progress, or after the last epic in a project merges.
allowed-tools: mcp__github__*, Read
---

# Skill: hackathon-projects

**Cross-cutting project management.** Shows the completion status of each GitHub Project
and closes a project board when all its epics are merged into main.

---

## GitHub MCP - required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

- "Show project status", "How are the projects going?", "What's left per project?"
- "Close the <project name> project", "All epics in <project> are done"
- Auto-called by `hackathon-docs-demo-script` when all epics in a project close

---

## Step 1 - Load state

Via the GitHub MCP:
1. List all GitHub Projects in this repo
2. For each project, list all items (epics) assigned to it
3. For each epic issue: read its current label state (`in-progress`, `in-review`, `closed`, etc.)

Also read `PLAN.md` for project goals and the tracking issue for the dependency map.

---

## Step 2 - Compute status per project

For each GitHub Project, compute:

| Epic | Status |
|---|---|
| #n [Epic] <title> | [x] closed / (in-progress) in-progress / [ ] not started / (blocked) blocked |

Overall project state:
- **Complete** - all epics closed
- **In progress** - at least one epic open, none blocked
- **Blocked** - at least one epic blocked, others may be complete

---

## Step 3 - Report status

Present the status in chat:

```
Project status

-- <Project 1 name> ------------------------ IN PROGRESS
  [x] #1 [Epic] <title>
  (in-progress) #2 [Epic] <title>   (in-progress)
  [ ] #3 [Epic] <title>   (ai-approved, depends on #2)

-- <Project 2 name> ------------------------ COMPLETE
  [x] #4 [Epic] <title>
  [x] #5 [Epic] <title>
```

If a project is **Complete** and its board is still open: offer to close it (see Step 4).

---

## Step 4 - Close a completed project (conditional)

Only close a GitHub Project when ALL of the following are true:
- Every epic assigned to the project is closed
- The epic->main PRs are all merged (not just the issues closed manually)

To close:
1. Via the GitHub MCP, update the GitHub Project status to `closed`
2. Comment on the tracking issue:
   `agent: project "<name>" complete - all epics merged, GitHub Project closed`
3. Call `hackathon-docs-demo-script` if this is the last open project in the repo

**Never close a project with open epics.** If the human asks to close a project that
has open epics, report the open items and ask for confirmation before proceeding.

---

## Rules

- **Never** close a project unless every assigned epic issue is closed.
- **Always** verify epic closure via merged PRs, not just label state.
- **If the human requests a force-close** (open epics remain): list the open epics,
  state the risk, and require explicit confirmation before closing.



