extends Node

# Global sound player (autoload "Sfx"). Usage: Sfx.play("shoot")

const SOUNDS = {
	"shoot": preload("res://Audio/shoot.wav"),
	"hit": preload("res://Audio/hit.wav"),
	"explode": preload("res://Audio/explode.wav"),
	"pickup": preload("res://Audio/pickup.wav"),
	"power_up": preload("res://Audio/power_up.wav"),
	"player_hit": preload("res://Audio/player_hit.wav"),
	"enemy_shoot": preload("res://Audio/enemy_shoot.wav"),
	"shockwave": preload("res://Audio/shockwave.wav"),
	"laser": preload("res://Audio/laser.wav"),
	"lightning": preload("res://Audio/lightning.wav"),
	"shield": preload("res://Audio/shield.wav"),
	"siren": preload("res://Audio/siren.wav"),
	"jingle": preload("res://Audio/jingle.wav"),
	"perfect": preload("res://Audio/perfect.wav"),
	"chain_1": preload("res://Audio/chain_1.wav"),
	"chain_2": preload("res://Audio/chain_2.wav"),
	"chain_3": preload("res://Audio/chain_3.wav"),
	"chain_4": preload("res://Audio/chain_4.wav"),
}

const POOL_SIZE = 12

var pool: Array[AudioStreamPlayer] = []


func _ready():
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		pool.append(player)
	Game.apply_settings()   # the SFX bus exists now


func play(sound_name: String, volume_db: float = 0.0):
	if not SOUNDS.has(sound_name):
		push_warning("Unknown sound: %s" % sound_name)
		return
	for player in pool:
		if not player.playing:
			player.stream = SOUNDS[sound_name]
			player.volume_db = volume_db
			player.play()
			return
