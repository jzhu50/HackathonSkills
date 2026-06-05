# skill-claim

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

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
