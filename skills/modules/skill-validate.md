# skill-validate
Validate Definition of Done. Autonomous success script.

## Steps
1. **Define**: Read AC -> Write `success_check.sh` (or `.py`).
2. **Baseline**: Run script. Must **FAIL**.
3. **Loop**: Implement -> Run script until **PASS**.
4. **Cleanup**: `rm success_check.sh` before PR.

## Rules
- Script must test behavior, not just code existence.
- Fail baseline is mandatory.
- PASS is blocking for PR.
