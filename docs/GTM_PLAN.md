# Shmittens! ✰: go-to-market plan
Owner: Big-Pooh. Engineering and production: Claude (acting as forward-deployed engineer).
Reviewers: the `senior-game-designer` and `gtm-lead` agent personas (`.claude/agents/`) review every iteration.
Status: v0.10.0 is a public pre-release. Web demo: https://big-pooh.github.io/shmittens/

## 1. Positioning
- **Hook (one line):** *Draw spells to the beat.*
- **Elevator pitch:** a cute rhythm shoot-'em-up. Shmitten the superhero cat and her friends blast clockwork mice in time with the music, draw magic shapes that land exactly where you draw them, and dodge boss spell cards whose bullets dance to the song. The goal: rescue the Princess of Pisitania from Sho, the very buff (and very dramatic) demon lord of the mice.
- **Primary audience:** cat lovers and casual rhythm / shmup players aged 12–35. Cozy-adjacent, streamer-friendly, family-safe humour.
- **Secondary audience:** bullet-hell fans. HARD and BULLET HELL modes, spell-card captures, ranks.
- **Category:** rhythm shmup × drawing. The Steam check found no game with 90%+ similarity (`docs/DIFFERENTIATION.md`).
- **Tone:** wholesome puns, cartoon villains, pastel pixel art, chiptune.

## 2. Competitive frame (for price and scope)
| Game | Why it matters | Our answer |
|---|---|---|
| Chicken Invaders series | Comedy shmup, power-up chase, waves of cute enemies | Same humour and power-up joy, plus rhythm and drawing |
| Just Shapes & Beats | Music-synced bullet patterns | Our bullets pulse with the beat, and you fight back |
| Bass Harrier / RHYUP / BeatShips | Rhythm shooters (a crowded niche) | Drawn spells and the cat cast set us apart; lead with drawing, not "rhythm shooter" |
| Touhou-likes | Spell cards, graze, patterns | Spell cards, graze and Focus, made approachable |

**Content benchmark:** Early Access in this niche launches with 1.5–3 h of first-clear content plus replay modes. Next Fest demos run 20–30 min.

## 3. Product and pricing
- **Platforms:** Windows and macOS on Steam (Steam Deck check later). A free web demo on GitHub Pages / itch.io for reach.
- **Price:** $7.99 in Early Access, $9.99 at 1.0, with a 10–15% launch discount. Regional pricing uses Steam's suggested pricing.
- **Demo:** the first 3 planets plus the first boss of world 2 (20–30 min), with saves carried into the full game.
- **Art and audio:** generated in code (owner decision). Mitigation: one cohesive style guide (`marketing/STYLE_GUIDE.md`), readable capsules, sound design over realism.

## 4. Funnel and channels
```
Web demo (GitHub Pages / itch)  ->  Steam page (wishlists)  ->  Next Fest demo  ->  Early Access  ->  1.0
  ^ devlogs, GIFs, short videos     ^ capsule + trailer          ^ creators, press    ^ updates, reviews
```

| Channel | Action | Cadence |
|---|---|---|
| Steam page | capsule, 60 s trailer, 6 screenshots, 2 GIFs, short and long descriptions | live by day 21 |
| Short video (TikTok / Shorts / Reels) | 10–15 s clips: meow on a PERFECT, spell break, Sho's one-liners, pet the cat | 3 a week |
| Reddit | r/IndieGaming, r/shmups, r/rhythmgames, r/cats (only where allowed), r/godot | 1 post a week, devlog style |
| Bluesky / X | GIFs and devlogs, #screenshotsaturday | 3 a week |
| Devlogs | GitHub repo + itch devlog; the audit log is the source | every release |
| Creators | 30 small and mid cozy / rhythm / cat YouTubers and streamers, with keys and a press kit | 2 weeks before Next Fest |
| Press | indie and cozy sites (Rock Paper Shotgun, PC Gamer indie round-ups, TheGamer) | Next Fest week |
| Community | Discord (or Steam forums at first), plus a feedback form in the pause menu | from day 7 |

## 5. Milestones (30 days, see `docs/ROADMAP_30D.md`)
| Day | Milestone | Release |
|---|---|---|
| 1 | Deploy pipeline, public repo, web demo | v0.10 ✅ |
| 7 | Content and design pass 1: 8 waves per planet, mid-bosses, 2 new enemy types, spell roles, web calibration | v0.11 |
| 14 | World 2 (planets 5–6), trackpad and gamepad drawing, demo flag | v0.12 |
| 21 | Steam page assets: capsules, trailer capture, screenshots; first 10–20 external testers | v0.13 |
| 28 | Polish from tester data, demo-ready build, planets 7–8 in progress | v0.14 (demo RC) |
| 30 | Go/no-go for submitting the Steam page and Next Fest registration | – |

## 6. KPIs and go/no-go (real players, not simulations)
| Metric | Source | Go | No-go action |
|---|---|---|---|
| Web demo: finish planet 1 | session stats / form | ≥ 70% | Fix onboarding |
| Demo completion (3 planets) | session stats | ≥ 40% | Shorten or rebalance |
| Median demo session | session stats | ≥ 15 min | Add content or replay hooks |
| "Would wishlist" (form) | tester form | ≥ 40% | Revisit the hook and presentation |
| Spells cast per planet | session stats | ≥ 3, using all 4 shapes | Rebalance spell roles |
| Steam wishlists before Next Fest | Steamworks | ≥ 2,000 (aim 5,000) | Push creators and short videos harder |
| Next Fest demo players → wishlists | Steamworks | ≥ 15% | Fix first-10-minutes retention |

## 7. Budget
Zero-cash plan as decided: art and audio generated in code, organic marketing.
- **Required spend:** the Steam Direct fee ($100 per app).
- **Optional:** $200–500 on creator gifting, capsule polish, or a trailer editor, if wishlist velocity justifies it.

## 8. Risks and mitigations
| Risk | Mitigation |
|---|---|
| Procedural art caps perceived quality | One consistent style; capsule readability tests at 120×45; lead with motion (GIFs), not stills |
| Trademarks | Mode renamed from "TOUHOU" to **BULLET HELL**; mech is an original design (PAWFRAME MK-IX, no V-fin or tricolour); no other franchise names in materials |
| All feedback so far comes from one player (the developer) | 10–20 cold external players on the web build before tuning further |
| Rhythm timing differs on web and Bluetooth audio | First-launch tap calibration; wider PERFECT window on web |
| Right-click drawing on trackpads and in browsers | Alternative draw input (hold Ctrl + left button); gamepad right-stick drawing |
| Scope creep | Each iteration ships behind a tag; demo scope frozen on day 21 |
| Privacy | Session stats stay local; any upload is opt-in and documented |
