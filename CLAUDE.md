# Shmittens: notes for Claude
- Start with `docs/PROGRESS.md` and `docs/PLAN.md`; history is in `docs/AUDIT_LOG.md`.
- Engine: Godot 4.7.2. Tests: `$GODOT --headless --path . -s tests/run_tests.gd` (must end "N passed, 0 failed").
- **If you are running as the scheduled iteration loop** (unattended, prompt mentions the loop or `auto-iteration`), `docs/AUTOMATION.md` is binding: follow its guardrails and steps exactly. Never release, publish, merge or push to `main`.
- In interactive sessions the owner decides; releases go through `tools/release.sh` only when the owner asks.
