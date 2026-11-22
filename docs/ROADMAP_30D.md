# 30-day roadmap (from 2026-11-22)
Every item ships behind a tagged release through `tools/release.sh`: tests, builds, tag, web demo, GitHub Release. Nothing is ever lost, and any version can be rebuilt from its tag.
After each release, the `senior-game-designer` and `gtm-lead` agents review it, and their top issues feed the next week.

## Week 1 (days 1–7): foundation and core fixes, v0.10 → v0.11
- [x] Public repo, export presets (Web, Windows, macOS), release script, web demo on GitHub Pages: v0.10.0
- [x] Mech redesign (PAWFRAME MK-IX, non-infringing) with beam rifle and beam saber; sparse meows
- [x] Reviewer agents: senior game designer, GTM lead
- [x] Rename the "TOUHOU" mode to **BULLET HELL** (trademark)
- [x] **Give each spell its own role:**
  - line slash ≤ 600 px long;
  - circle cancels bullets in its area and magnets cheese;
  - zigzag does heavy damage to shield plates and armour;
  - each boss card shows a "weak to" icon.
- [ ] **Content per planet:** 8 waves (was 5), a mid-boss on planets 2–4, and 2 new enemy types (Weaver mouse, Turret mouse)
- [x] **Introduce systems gradually:** companions from planet 2, the mech from planet 3
- [ ] **Web rhythm calibration:** a 16-tap test on first launch; the PERFECT window +15 ms on web
- [x] **Alternative draw input:** the left button draws too (trackpads, browsers)
- [x] Refresh `docs/DIFFERENTIATION.md`; GTM plan, roadmap, Steam copy, trailer script, press kit and social kit (this document set)
- [ ] **Owner:** pay the Steam Direct fee and submit a "Coming Soon" page with in-engine screenshots; create a press@ alias; check the February 2027 Next Fest dates

## Week 2 (days 8–14): world 2 and the demo build, v0.12
- [ ] **World 2:** planets 5–6 (new waves, 2 new bosses with 3 spell cards each, 2 new music tracks)
- [ ] **Demo flag:** the web and demo builds stop after planet 3 plus a boss teaser, then link to the Steam page
- [ ] **Gamepad:** move with the left stick, aim with the right stick, draw spells by holding RB and tracing with the right stick
- [ ] Ranks per planet shown on the map; a best-rank screen
- [ ] Opt-in feedback form link in the pause menu and on the end screen (Google Form / GitHub issue template)

## Week 3 (days 15–21): store assets and first outside players, v0.13
- [ ] **Capsules** rendered in-engine (`marketing/capsules/`): header 460×215, small 231×87, main 616×353, vertical 374×448, library 600×900 and hero 3840×1240. Plus a logo
- [ ] **Trailer:** capture at 1080p with the movie writer, following `marketing/TRAILER_SCRIPT.md`; 6 screenshots, 2 GIFs
- [ ] Steam page polish: capsule, trailer and GIFs swapped in (the page itself goes up in week 1, see below)
- [ ] **10–20 cold external testers** on the web demo; collect session stats and form answers
- [ ] Demo scope frozen

## Week 4 (days 22–30): polish from real data, v0.14 (demo release candidate)
- [ ] Fix the top 5 problems from tester data (onboarding, difficulty, spell usage)
- [ ] Planets 7–8 and the Sho finale moved to the end of world 2 (Early Access content target: 8 planets)
- [ ] Performance check on low-end Windows and Steam Deck (web as a proxy)
- [ ] Creator list (30) and press kit ready; devlog #2 and #3
- [ ] **Day 30 go/no-go** against the thresholds in `docs/GTM_PLAN.md` section 6

## After day 30 (not in scope yet)
- **Early Access** (about 8–10 weeks): 8 planets, about 1.5 h first clear, Endless mode, BULLET HELL mode.
- **1.0:** 12 planets, cosmetics shop ("Cat Café"), achievements, Steam Deck verified, localisation (ES, PT-BR, DE, FR, JA, ZH).
