# skill-validate

**MANDATES:**
- **Caveman**: Drop filler words (I will, I can, sure). Use fragments. Keep substance. Keep code/paths. Technical accuracy 100%. Word count 25%. Mouth small, brain big.
- **Context**: Never read what you can compute. Do not read large files to find patterns. Write scripts to extract exact answers. If output > 5KB, write a sandbox script.

Validate Definition of Done. Autonomous success script.

## Phase 0: Check Config
- Read `hackathon.config.yml`. Check `quality.validation`.
- Value must be `autonomous-script`. Any other value: report unsupported mode and ABORT.

## Steps
1. **Define**: Read AC -> Write `success_check.sh` (or `.py`).
2. **Baseline**: Run script.
   - Script errors (syntax, missing deps, wrong path)? -> Fix script. Do NOT count as a meaningful run.
   - Must **FAIL** (non-zero exit). Exception: if AC is a removal/deletion ("X no longer exists"), a baseline PASS is expected — skip the fail-gate and proceed.
3. **Loop**: Implement -> Run script until **PASS**.
4. **Cleanup**: `rm success_check.sh` before PR.

## Rules
- Script must test behavior, not just code existence.
- Fail baseline is mandatory.
- PASS is blocking for PR.
