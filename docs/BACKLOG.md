# Backlog for the automated loop
The loop takes the **top open item** each run. The owner can reorder, edit, add or delete items at any time (edit on `main`).
Status: `open` · `in PR #n` · `done (PR #n)` · `rejected (reason)` · `owner-only` (the loop skips these).

Driving verdict (owner, v0.12 playtest, 6/10): **"the gameplay doesn't change and the mice never get stronger."**
Phase 18 added elite mice, interludes and pink poofs. The items below push further on variety and escalation first.

## 1. Variety and escalation (owner verdict)
1. `open` **Planet twists:** give each of the 8 planets one signature rule change that appears from wave 3 (for example a current that drifts the cat on Drainia, double-time bars on Neon Nibble, slower icy bullets on Frostwhisker). Introduce each with a one-line banner. No changes to the controls or the beat windows.
2. `open` **Mice that learn:** each enemy type gets a tier-2 attack from world 2 (planets 5–8), for example gunners fire 3-shot bursts on the off-beat, dashers feint once. The difficulty curve must stay within the persona targets in `docs/KPI.md`.
3. `open` **Set-piece waves:** 4 Chicken-Invaders-style formation entries (swoop-in, spiral, marching line, split-and-converge) mixed into waves 4–10.
4. `open` **Mid-planet surprise events:** a rare bonus event per planet (cheese UFO to chase, a mouse heist that steals your combo until you catch it), about once per planet.
5. `open` **3 more interludes** (there are 3), so a full story run rarely repeats one.
6. `open` **Between-planet upgrade choice:** pick 1 of 3 small run perks after each boss (e.g. +1 companion shot, wider PERFECT sparkle radius, cheese magnet). Off in BULLET HELL mode.

## 2. Polish and tech
7. `open` **Localisation prep:** move inline texts to a CSV and use `tr()` (English only for now).
8. `open` **Session-stat review tool:** a script that summarises the owner's playtest session files into a short report the reviewers can read.
9. `open` **Pooled enemy bullets (MultiMesh)** only if a new pattern pushes BULLET HELL past 8 ms average in `tests/perf_test.gd`.

## Owner-only (the loop never does these)
- `owner-only` Steam Direct fee, "Coming Soon" page, Next Fest dates, press@ alias
- `owner-only` cold external playtests; trailer cut; macOS notarization and Windows signing
- `owner-only` every release (`tools/release.sh`)
