extends RefCounted

class_name Platform

# SPRINT 7: one place for store-platform features. Today it is a no-op layer; once the Steam
# app exists, drop in the GodotSteam extension and these calls light up (no game code changes).
# Nothing here requires an account to run.


static func has_steam() -> bool:
	return Engine.has_singleton("Steam")


static func unlock_achievement(id: String):
	if has_steam():
		var steam = Engine.get_singleton("Steam")
		steam.setAchievement(id)
		steam.storeStats()


static func set_stat(id: String, value: int):
	if has_steam():
		var steam = Engine.get_singleton("Steam")
		steam.setStatInt(id, value)
