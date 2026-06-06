---
description: Sync current branch from target via merge. Call before implementing on any task or verify branch.
allowed-tools: Bash
---

# skill-sync

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Sync branch using merge.

## Steps
1. `git fetch origin`.
2. `git merge origin/[target]`.
3. **Conflict?**:
   - Resolve conflicts or `git merge --abort`.
   - Continue implementation on current branch.
4. **Success?**: `git push`.
