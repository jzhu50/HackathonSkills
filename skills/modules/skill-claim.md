# skill-claim
Claim issue safely. Prevent collision.

## Steps
1. **Refresh**: `mcp__github__get_issue` + `mcp__github__list_issue_comments`.
2. **Check**:
   - Multiple assignees? -> ABORT.
   - Claim comment < 120s old? -> ABORT.
3. **Act**:
   - `mcp__github__update_issue`: assign self + label `in-progress`.
   - `mcp__github__add_issue_comment`: `agent: claiming - [user] - [timestamp]`.
4. **Verify**: Re-read issue. Conflict? -> Unassign + Reset label + ABORT.
