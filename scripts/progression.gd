extends RefCounted

class_name Progression

# SPRINT 4 meta progression: lifetime stats -> achievements (with toasts) and unlockable cat
# hats. Lifetime stats are fed by Game.track(), so every tracked event counts.

const ACHIEVEMENTS = [
	# id, title, description, stat, threshold
	["lift_off", "Lift-off!", "Clear your first planet", "levels_cleared", 1],
	["rescue", "Star Bringer", "Finish the story (both worlds)", "story_completes", 1],
	["purrfect_pitch", "Purr-fect Pitch", "Land 100 PERFECT shots", "perfects", 100],
	["spellcat", "Spellcat", "Cast 50 drawn spells", "spells_cast", 50],
	["card_shark", "Card Shark", "Capture your first spell card", "cards_collected_new", 1],
	["full_deck", "Full Deck", "Collect every spell card", "album_cards", 30],
	["pawframe", "Pawframe Pilot", "Pilot the PAWFRAME MK-IX", "mechs", 1],
	["overdrive", "Catnip Overdrive", "Unleash an overdrive", "overdrives_used", 1],
	["whiskers", "Whisker Width", "Graze 100 bullets", "grazes", 100],
	["dance_fever", "Dance Fever", "Tap 50 beats during dance breaks", "dance_taps", 50],
	["squad", "Squad Goals", "Have companions join 30 times", "companions_joined", 30],
	["good_kitty", "Good Kitty", "Pet the cat 10 times", "pets", 10],
	["untouchable", "Untouchable", "Clear a planet without being hit", "no_hit_planets", 1],
	["star_collector", "Star Collector", "Earn 12 challenge stars", "stars", 12],
	["spell_breaker", "Spell Breaker", "Shatter beat armour with a ZIGZAG BOLT", "spell_breaks", 1],
	["hard_claws", "Hard as Claws", "Finish the story on HARD", "hard_completes", 1],
]

const HATS = [
	# id, name, unlock stat, threshold, hint
	["none", "No hat", "", 0, ""],
	["hat_party", "Party Hat", "", 0, "Always yours"],
	["hat_flowers", "Flower Crown", "stars", 3, "Earn 3 challenge stars"],
	["hat_headphones", "Headphones", "album_cards", 5, "Collect 5 spell cards"],
	["hat_wizard", "Wizard Hat", "spells_cast", 100, "Cast 100 spells"],
	["hat_crown", "Royal Crown", "story_completes", 1, "Finish the story"],
	["hat_halo", "Halo", "album_cards", 30, "Collect every spell card"],
]


static func stat(game, key: String) -> float:
	match key:
		"album_cards":
			return game.card_album.size()
		"stars":
			var total = 0
			for i in 8:
				total += game.stars(i)
			return total
	return game.lifetime.get(key, 0.0)


# Called after any stat changes: unlocks whatever is newly earned. Returns the new ids.
static func check(game) -> Array:
	var fresh = []
	for a in ACHIEVEMENTS:
		if not game.achievements.has(a[0]) and stat(game, a[3]) >= a[4]:
			game.achievements[a[0]] = Time.get_date_string_from_system()
			fresh.append(a[0])
			Platform.unlock_achievement(a[0])
			game.toast("ACHIEVEMENT!  " + a[1], a[2])
	for h in HATS:
		if h[2] != "" and not game.hats_unlocked.has(h[0]) and stat(game, h[2]) >= h[3]:
			game.hats_unlocked[h[0]] = true
			game.toast("NEW HAT!  " + h[1], "Wear it from WARDROBE on the title screen")
	return fresh


static func hat_unlocked(game, id: String) -> bool:
	return id in ["none", "hat_party"] or game.hats_unlocked.has(id)
