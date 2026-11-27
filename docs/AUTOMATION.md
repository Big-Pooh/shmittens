# Automated iteration loop

A scheduled Claude run improves Shmittens twice a week (Tuesday and Friday, about 01:47 Bucharest).
Each run delivers **one pull request**. The owner (Big-Pooh) tests the build and decides.
Nothing is released or published by the loop.

## The owner's side
1. Open the PR. Read "How to test" and the reviewer panel.
2. Check out the branch, open `project.godot` in Godot 4.7.2 and play it (F5).
3. Decide:
   - **Approve:** merge the PR. Release yourself when you want, with `tools/release.sh X.Y.Z "notes"`.
   - **Change it:** leave a PR comment. The next run fixes that PR before starting anything new.
   - **Reject:** close the PR without merging. The next run marks the item rejected in `docs/BACKLOG.md` and logs why (from your comment, if any).
4. Reorder or edit `docs/BACKLOG.md` on `main` at any time. The loop always takes the top open item.

## Guardrails (hard rules for every run)
The loop **never**:
- pushes to `main` or `gh-pages`, merges a PR, or approves its own PR;
- runs `tools/release.sh`, exports builds, creates tags or GitHub Releases, or deploys the web demo;
- bumps the version (`project.godot`, `export_presets.cfg`); the owner's release does that;
- edits `.github/workflows/`, `tools/release.sh`, `LICENSE`, this file's guardrails or `.claude/`;
- deletes branches, force-pushes to a branch it did not create, or rewrites history on `main`;
- changes repo settings, secrets, collaborators, issues of other people, or anything outside this repo;
- downloads new art, audio, fonts, plugins or addons (generated placeholder assets via `tools/gen_*.py` are fine);
- touches the Steam page, store copy or press contacts, or posts anything outside this repo;
- reads or writes the owner's save files.

Scope and pacing:
- **One backlog item per run, one PR per run.** Keep the diff reviewable (aim for under ~600 changed lines of code, excluding generated assets and reports).
- **At most 2 open loop PRs.** If 2 are already waiting for the owner, the run does no new work: it only answers owner comments on those PRs, logs a "skipped: waiting for review" line and stops.
- The core loop stays **frozen** (owner rule since Phase 17): no changes to the controls, the beat judgement windows or the spell gestures unless the backlog item says so.
- All 354+ tests must pass. A run that cannot get them green opens the PR as a **draft** titled `[BLOCKED]`, explains why, and stops.
- If a reviewer flags something serious (crash, save corruption, a core-loop change, legal/trademark risk), the run fixes it or opens the PR as a draft with the issue at the top. It never hides a finding.
- When unsure about a design choice the owner would care about, pick the smaller, reversible option and put the question in the PR under "Decisions for you".

## What one run does
1. **Sync:** clone `main`. Read `docs/AUTOMATION.md`, `docs/BACKLOG.md`, `docs/PROGRESS.md`, the latest phase of `docs/AUDIT_LOG.md`, `docs/AUTOMATION_LOG.md`.
2. **Owner feedback first:** read every open or recently closed PR labelled `auto-iteration` and its comments.
   - Unanswered owner comments on an open PR: fix them on that PR's branch, push, reply in the PR, re-run tests. That is the run's work if it takes the session.
   - A PR closed without merge: mark its backlog item `rejected` with the reason.
   - A merged PR: mark its item `done (vX / PR #n)`.
3. **Pick** the top open item in `docs/BACKLOG.md` (unless step 2 used the run).
4. **Baseline:** run the tests and `tools/montecarlo.py --runs 4` on `main`; keep the tables.
5. **Build** on a new branch `auto/<yyyy-mm-dd>-<short-slug>` from `main`. Small commits with clear messages.
6. **Verify:** tests, then the same montecarlo run on the branch. Compare.
7. **Reviewer panel** (independent agents that did not write the code, all read-only), each given the PR diff and the item:
   `senior-game-designer`, `qa-bug-hunter`, `first-time-player`, `godot-code-reviewer`, `rhythm-specialist`
   (plus `gtm-lead` when the item touches marketing, store text or the demo).
   Fix what is cheap and clearly right; list the rest.
8. **Document:**
   - a new phase in `docs/AUDIT_LOG.md` (what changed, why, numbers before/after, decisions);
   - an entry under `## Unreleased` in `CHANGELOG.md` (player-facing, short);
   - the item's status in `docs/BACKLOG.md`;
   - one line in `docs/AUTOMATION_LOG.md`;
   - `docs/PROGRESS.md` only if "where things are" changed.
9. **Open the PR** against `main` with the label `auto-iteration` and the template below.

## PR template
```
## What changed (player view)
## Why (backlog item, owner verdict it answers)
## How to test (exact steps: planet, mode, what to look for; ~5 min)
## Results
- Tests: N passed, 0 failed
- Bot playthroughs (montecarlo --runs 4), main → branch: fun, deaths/min, minutes, drop per planet
## Reviewer panel
| Reviewer | Verdict | Top issues | Fixed in this PR? |
## Decisions for you
## Risks and rollback (revert = close the PR / `git revert <merge commit>`)
```

## Limits worth knowing
- Bot playthroughs and the 100-tester panel are **models**, not players. Feel, fun and humour are judged by the owner's playtest. That is why every PR waits for it.
- The loop runs in the cloud on Linux with headless Godot. It cannot open a window, so visual checks rely on code review and the owner.
