# Smittens: readiness for human testing (simulated panel)

**Method:** `python3 tools/panel.py`. Each run is 100 simulated first-time testers with random skill, patience and tastes. Each plays the real game, sped up, then is judged by the player, critic and business models. The models are documented in `tools/panel.py`. **These are model outputs, not predictions.**

**Targets** were adjusted to Steam benchmarks where the original 80% asks were unrealistic:
- **GTM:** only ~8% of Steam games gross over $100k, so the target is 3× that base rate.
- **Purchase intent:** Next Fest's median demo-to-wishlist conversion is ~19%, so the target is 25%.
- **Completion:** under 40% signals a problem, so the target is 60%.

## Latest KPIs (after iteration 6, playtest 2)
Panel A: fun 98, drop 0/2/1, completion 96, endorse 92, intent 76, GTM 60 (model cap).
Panel B: fun 99, drop 1/2/1, completion 96, endorse 92, intent 77, GTM 60 (cap).
Details and caveats: `docs/AUDIT_LOG.md` Phase 10.

## KPIs after iteration 5 (kept for comparison)

| View | KPI | Panel A | Panel B | Target |
|---|---|---|---|---|
| Player | had fun | 91% | 85% | ≥ 80% ✅ |
| Player | drop rate L1 / L2 / L3 | 4 / 7 / 5% | 4 / 9 / 4% | ≤ 20% ✅ |
| Player | completion | 85% | 84% | ≥ 60% ✅ |
| Critic | likely to endorse | 85% | 85% | ≥ 80% ✅ |
| Business | purchase intent | 55% | 55% | ≥ 25% ✅ |
| Business | GTM success (P > $100k gross) | 48% | 49% | ≥ 24% ✅ |

## How we got here (panel A)

| Iteration | Fun | Endorse | Intent | GTM | Main change |
|---|---|---|---|---|---|
| 0 | 43% | 23% | 18% | 3% | baseline |
| 1 | 53% | 77% | 36% | 23% | settings, saved progress, endless mode |
| 2 | 68% | 82% | 47% | 36% | testers calibrated to your playtest; slower boss melody bullets |
| 3 | 79% | 84% | 51% | 42% | forgiving hitboxes, wider assisted timing, boss lives top-up |
| 4 | 87% | 85% | 54% | 47% | Second Wind, first-start Relaxed/Normal choice |
| 5 | 91% | 85% | 55% | 48% | Spell Chains (signature mechanic, see `docs/DIFFERENTIATION.md`) |
| 6 | 98% | 92% | 76% | 60% (cap) | playtest 2: weapons, focus, bullet-hell bosses + beat armour, slower BPM, dance breaks, story cards, spell guides, cute art |

## Caveats you should weigh
- **Model-driven, not observed:**
  - the fun and quitting formulas, the testers' behaviour, and "70% of low-challenge testers pick Relaxed" are assumptions;
  - critic, intent and GTM depend heavily on a feature checklist and a fixed art/audio rating (0.5, placeholders).
- **Art and music are placeholders.** Real testers and critics will judge them. Professional art and music are the biggest real-world lever the model can't capture.
- **Short content:** a session is about 5–6 minutes for the story, and Endless adds replay. Real buyers may see that as thin for a paid release. As a demo or prototype for testers, it's appropriate.
- **Next step:** run a real playtest with about 10–20 outside testers, and compare their answers to this table to calibrate the models.
