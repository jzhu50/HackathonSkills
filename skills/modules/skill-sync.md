# skill-sync
Sync branch. Enforce linear history. REBASE ONLY.

## Steps
1. `git fetch origin`.
2. `git rebase origin/[target]`.
3. **Conflict?**:
   - `git rebase --abort`.
   - Continue implementation on current branch.
   - **PR Phase**: Open PR + Title `[REBASE_FAILED]` + Comment `agent: rebase too complex`.
4. **Success?**: `git push --force-with-lease`.
