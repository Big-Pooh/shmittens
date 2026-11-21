# Smittens: KPIs from Monte Carlo playthroughs

**Source:** `python3 tools/montecarlo.py --runs 40`. That's 40 sped-up full playthroughs per player profile, 120 in total, about 1.5 minutes on 8 cores.

**Compared:**
- **Original:** the game before any tuning (commit `ce0fa58`: tooling only, no gameplay change).
- **Tuned:** after tuning commits 1–10 on the `tuning/personas` branch.

**Fun** is a 0–100 heuristic score:

| Ingredient | Weight |
|---|---|
| Challenge near the profile's sweet spot (deaths per minute) | 35% |
| Few game overs | 25% |
| On-beat success | 20% |
| Skill use (casts per minute, minus fizzles) | 10% |
| Comfortable pace | 10% |

**Drop rate** = the share of players who started a level and quit during it. It comes from a quitting model:
- after each game over, a player quits with a profile-based chance (beginner 22%, average 12%, speedrunner 6%), rising with repeated game overs;
- a small boredom quit applies to trivially easy levels.

The exact formulas are in `tools/montecarlo.py`.

## Fun score by level (0–100)

| Profile | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Beginner | 20 → **44** | never reached → **69** | never reached → **27** |
| Average | 51 → **65** | 33 → **66** | 30 → **62** |
| Speedrunner | 76 → **78** | 74 → **67** | 62 → **69** |

## Drop rate by level

| Profile | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Beginner | 100% → **46%** | — → **31%** | — → **84%** |
| Average | 30% → **6%** | 74% → **7%** | 92% → **10%** |
| Speedrunner | 0% → **0%** | 0% → **1%** | 4% → **1%** |

## Completion

| Profile | Automated player finishes the game (with retries) | Modelled players still playing at the end |
|---|---|---|
| Beginner | 0% → **55%** | 0% → **5%** |
| Average | 7% → **100%** | 1% → **77%** |
| Speedrunner | 100% → **100%** | 95% → **96%** |

## Reading the numbers
- **Beginner:** went from "can't pass Level 1" to finishing more than half the time. The final boss (the Rat King: 17.8 shot deaths per fight, 55% clear) is still the main wall, and the main reason modelled beginners quit in Level 3.
- **Average:** the biggest win. Fun is 62–66 on every level, and drop rate is at most 10% (it was up to 92%).
- **Speedrunner:** about the same overall: Level 3 improved, Level 2 fun went 74 → 67. It was the only profile with no assist active, so the cause is a change everyone gets: the mothership's phase 2 now launches grunts every bar (Tuning 4), giving 1.3 deaths per run vs 0.7 originally. Worth watching. FEVER and ranks give it a mastery goal that the fun score doesn't measure.
- **Caveats:**
  - These are automated players with modelled behaviour, not people. Their timing accuracy, reaction and drawing noise are set in `tests/persona_bot.gd`.
  - The fun and drop models are explicit heuristics.
  - Use the numbers to compare versions, not as absolute truth.
