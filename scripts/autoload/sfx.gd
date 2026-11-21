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
}

const POOL_SIZE = 12

var pool: Array[AudioStreamPlayer] = []


func _ready():
	for i in POOL_SIZE:
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)


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
