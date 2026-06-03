# hackathon-agent-template

A GitHub repository template for running autonomous AI coding agents as a small team.

Agents coordinate entirely through GitHub issues — no shared servers, no custom
orchestration, no manual backlog management. Anyone can sit down, configure their
agent, say "Go", and their agent picks up exactly where the team left off.

---

## How it works

| File | Role |
|---|---|
| `PLAN.md` | The shared brain — vision, stack, features, decisions. Fill this in first. |
| `SPECS.md` | Optional detail layer — data models, routes, UI flows. Fill in as needed. |
| `AGENTS.md` | The coordination protocol — how agents claim work, handle blockers, close out. |
| GitHub Issues | The task queue — agents create, claim, update, and close them. |
| Labels | Issue state machine — agents use these to coordinate without talking to each other. |

---

## Quickstart

### One-time setup (do this once per hackathon)

```
1. Click "Use this template" → create a new public repo
2. Fill in PLAN.md as a team (takes ~10 minutes)
3. Fill in SPECS.md if you have data models or API contracts already decided
4. Configure GitHub MCP on each machine (see below)
5. Tell your agent: "Set up the project"
```

Step 5 triggers the `hackathon-setup` skill, which reads `PLAN.md` and automatically
creates all labels and epic issues. No manual issue creation needed.

### Each session

```
Tell your agent: "Go"
```

The `hackathon-session` skill handles everything: reading project state, claiming an
issue, doing the work, capturing new scope, and closing out correctly.

---

## GitHub MCP setup (each machine)

Each teammate needs the GitHub MCP server configured with their own Personal Access Token.

**Required PAT scopes:** `repo`, `read:org`

**Docker-based config** (add to your agent's MCP settings):

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_PAT_HERE"
      }
    }
  }
}
```

Use your own PAT — not a shared one. This makes agent actions attributable in issue comments.

For detailed MCP setup per agent CLI, see the
[GitHub MCP Server docs](https://github.com/github/github-mcp-server).

---

## For non-Claude Code agents

`AGENTS.md` is the full coordination protocol. If your agent CLI does not auto-load
files from the repo, paste `AGENTS.md` contents as a system prompt before starting.
The session skill will also instruct your agent to read it on startup.

---

## Skills required

This template is designed to work with three skills from the hackathon skills repo:

| Skill | When it's used |
|---|---|
| `hackathon-setup` | Once — bootstraps labels and creates all epic issues from PLAN.md |
| `hackathon-session` | Every session — claim, work, capture scope, close out |
| `hackathon-decompose` | On demand — breaks a needs-scoping epic into ready tasks |

---

## Requirements

- GitHub Free, public repo, up to 3 collaborators
- Docker (to run the GitHub MCP server)
- GitHub Personal Access Token per teammate (`repo` scope)
- Agent CLI with MCP support and access to the hackathon skills
