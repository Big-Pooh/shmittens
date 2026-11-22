# Shmittens! ✰: go-to-market plan
Owner: Big-Pooh. Engineering and production: Claude (acting as forward-deployed engineer).
Reviewers: the `senior-game-designer` and `gtm-lead` agent personas (`.claude/agents/`) review every iteration.
Status: v0.10.0 is a public pre-release. Web demo: https://big-pooh.github.io/shmittens/

## 1. Positioning
- **Hook (one line):** *Draw spells to the beat.*
- **Elevator pitch:** a cute rhythm shoot-'em-up. Shmitten the superhero cat and her friends blast clockwork mice in time with the music, draw magic shapes that land exactly where you draw them, and dodge boss spell cards whose bullets dance to the song. The goal: rescue the Princess of Pisitania from Sho, the very buff (and very dramatic) demon lord of the mice.
- **Audience (one):** cute-game and cat fans who enjoy light rhythm action. Streamer-friendly, family-safe humour.
- **Bonus audience:** bullet-hell players (HARD and BULLET HELL modes, captures, ranks), but never the lead message.
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
- **Demo (single scope, updated after the content pass):** all of **world 1**: 4 planets × 8 waves, 3 mid-bosses, Sho as the world-1 finale (he escapes; the rematch opens world 2 in Early Access), plus the tutorial. Simulated average player: about 7.5 min; real players die more, so expect 12–15 min for a first clear, with HARD, ranks and BULLET HELL as replay hooks. Saves carry into the full game.
- **Art and audio:** generated in code (owner decision). Mitigation: one cohesive style guide (`marketing/STYLE_GUIDE.md`), readable capsules, sound design over realism.

## 4. Funnel and channels
```
Web demo (GitHub Pages / itch)  ->  Steam page (wishlists)  ->  Next Fest demo  ->  Early Access  ->  1.0
  ^ devlogs, GIFs, short videos     ^ capsule + trailer          ^ creators, press    ^ updates, reviews
```

| Channel | Action | Cadence |
|---|---|---|
| Steam page | **"Coming Soon" page NOW** (owner pays Steam Direct; identity, tax and review take weeks) with in-engine screenshots; capsule, 45 s trailer and GIFs improved later | page submitted this week |
| Short video (TikTok / Shorts / Reels) | 10–15 s clips: circle burst, spell break, Sho's one-liners, pet the cat | 2 a week |
| Reddit | r/IndieGaming, r/shmups, r/rhythmgames, r/godot, r/playmygame (tester recruiting) | 1 post a week, devlog style |
| Bluesky / X | GIFs and devlogs, #screenshotsaturday | 3 a week |
| Devlogs | GitHub repo + itch devlog; the audit log is the source | every release |
| Creators | 30 small and mid cozy / rhythm / cat YouTubers and streamers, with keys and a press kit; contact via a press@ alias | 2 weeks before Next Fest |
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

## 6. KPIs and go/no-go (real players; 20 cold testers, so counts, not percentages)
| Metric | Go | No-go action |
|---|---|---|
| Cold external testers recruited | ≥ 20 | < 10: delay tuning, recruit via r/playmygame and itch |
| Finish planet 1 | ≥ 14 / 20 | Fix onboarding |
| Cast a spell unprompted on planet 1 | ≥ 16 / 20 | Tutorial and prompt rework |
| Use 3+ spell shapes | ≥ 12 / 20 | Spell roles and weaknesses |
| Describe the game with "draw" + "beat" in one sentence | ≥ 10 / 20 | Hook not landing: tutorial + capsule |
| "Would wishlist" | ≥ 8 / 20 | Presentation and hook |
| Trackpad users who manage to draw | ≥ 80% | Input rework |
| Wishlists per day after a social spike (once the page is live) | ≥ 15 | More short video |
| Wishlists at the Next Fest registration deadline | ≥ 1,000 (aim 3,000) | Skip to the next Next Fest |

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
| Privacy | Session stats stay local; the feedback form is opt-in, with a 13+ age gate and consent line (COPPA / GDPR-K) |
| Next Fest timing | Check the February 2027 Next Fest dates and registration deadline in Steamworks this week. Below 1,000 wishlists at the deadline → skip to the following Next Fest |
