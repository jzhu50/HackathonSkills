# skill-sync

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Sync branch. Enforce linear history. REBASE ONLY.

## Steps
1. `git fetch origin`.
2. `git rebase origin/[target]`.
3. **Conflict?**:
   - `git rebase --abort`.
   - Continue implementation on current branch.
   - **PR Phase**: Open PR + Title `[REBASE_FAILED]` + Comment `agent: rebase too complex`.
4. **Success?**: `git push --force-with-lease`.
