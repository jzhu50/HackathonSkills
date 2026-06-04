---
description: Recursive interrogation - asks batched questions about a given context until zero ambiguities remain, then returns a structured brief. Called internally by hackathon-setup and hackathon-decompose when grilling is enabled.
allowed-tools: mcp__github__*, Read
---

# Skill: hackathon-grilling

**Zero ambiguity or don't return.** Always called with a context string describing what
is being planned. Interrogates until no questions remain, then returns a structured brief
the calling skill uses to proceed.

Never triggered directly by a human. Called internally by:
- `hackathon-setup` before scoping epics - context: `"epic breakdown for <project name>"`
- `hackathon-decompose` before decomposing an epic - context: `"task breakdown for epic #<n>: <title>"`

---

## Step 1 - Read all available context

Read the following before forming any questions:

1. `PLAN.md` - vision, stack, features, done criteria, open questions
2. `SPECS.md` - if it exists
3. The context string passed by the calling skill

If called from `hackathon-decompose`: also read the full epic issue (body + all comments)
via the GitHub MCP.

Do not ask questions already answered in the above documents.

---

## Step 2 - Interrogation loop

Repeat until you have zero remaining questions:

### 2a. Identify every open question

Surface every ambiguity that would affect decisions the calling skill must make.
Check all relevant categories:

**When context is epic breakdown:**
- Done criteria: what does "done" look like for each feature, specifically enough that
  an agent can verify it without asking a human?
- Dependencies: which features must exist before others can start?
- Priority and cuts: if time runs out, what gets dropped first?
- Technical decisions still open: stack, libraries, services
- Environment requirements: native packages, OS-specific tooling, build tools
- Data and state: where does data live, is it shared across machines?
- Scope boundaries: what is explicitly out of scope per feature?
- Integration points: which features share code, schemas, or API contracts?
- Acceptance bar: what would cause a PR review to fail for each feature?
- Test command: what command runs the full test suite? (Required - no ambiguity allowed)

**When context is task breakdown:**
- Implementation approach: which library, pattern, or algorithm?
- File and module structure: where does new code live in the repo?
- Schema or interface contracts: exact shape of API requests/responses or data models
- Error handling: what should happen on each failure case?
- Edge cases that must be handled vs. explicitly out of scope
- What the preceding tasks will have left in place (interfaces, files, contracts)
- Performance or scale requirements, if any
- Authentication or authorization assumptions

### 2b. Batch all questions into one message

Never send questions one at a time. Write every open question in a single message.
Number them. Be specific - vague questions produce vague answers.

Example of bad question: "How should errors be handled?"
Example of good question: "If the POST /api/auth/login endpoint receives invalid
credentials, should it return 401 with a JSON body `{error: 'invalid credentials'}`,
or redirect to /login?error=1?"

Wait for the human's response before continuing.

### 2c. Incorporate answers and check for new ambiguities

Update your understanding with the answers received.
Ask: do any answers introduce new ambiguities? Are any questions still unresolved?

If yes -> return to 2a with only the new/remaining questions.
If no -> proceed to Step 3.

---

## Step 3 - Confirm understanding

Write a concise summary of everything that was unclear and is now resolved:

```
Grilling complete. Here's my understanding:

[Key decisions, constraints, scope boundaries, and anything else
 that was ambiguous and is now resolved - bullet points, concise]

Does this capture everything correctly?
```

Wait for confirmation. If the human corrects anything -> return to Step 2 for one more round.
If they confirm -> proceed to Step 4.

---

## Step 4 - Return structured brief to caller

Output the following. The calling skill reads this brief before proceeding:

```
## Grilling brief - <context string>

### Decisions made
- <decision>
- <decision>

### Constraints
- <constraint>

### Scope
In scope: <list>
Out of scope: <list>

### Resolved ambiguities
- Q: <question> -> A: <answer>
- Q: <question> -> A: <answer>

### Still open
<None - or item + owner if anything remains unresolved>
```

---

## Rules

- **Never return with open questions.** If an answer introduces a new question, ask it.
- **Never ask one at a time.** Every round is one batched message.
- **Never ask about things already in PLAN.md or SPECS.md.**
- **Always confirm understanding before returning the brief.**
- **Never take action** - no GitHub writes, no file edits. Read and interrogate only.



