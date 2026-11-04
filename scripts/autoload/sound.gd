## Звук: ефекти, атмосфера локацій і музика з плавним переходом «спокій ↔ бій».
## Гучність музики й ефектів зберігається в user://settings.cfg.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DIR := "res://audio/"
const POOL := 10
const FADE := 1.6

var music_volume := 0.7
var sfx_volume := 0.8
var _streams: Dictionary = {}
var _pool: Array = []
var _pi := 0
var _calm: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _amb_id := ""
var _combat_on := false
var _mix := 0.0          # 0 — спокій, 1 — бій
var _music_on := false
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_calm = _mk_loop("music_calm")
	_combat = _mk_loop("music_combat")
	_amb = AudioStreamPlayer.new()
	add_child(_amb)


func _mk_loop(id: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(id, true)
	p.volume_db = -80.0
	add_child(p)
	return p


func stream(id: String, loop := false) -> AudioStream:
	var key := id + ("#l" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var path := DIR + id + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is AudioStreamOggVorbis:
			s = (r as AudioStreamOggVorbis).duplicate() if loop else r
			if loop:
				(s as AudioStreamOggVorbis).loop = true
	_streams[key] = s
	return s


func has_sound(id: String) -> bool:
	return stream(id) != null


## Короткий ефект. pitch_var — випадкова зміна висоти, щоб повтори не набридали.
func play(id: String, vol_db := 0.0, pitch_var := 0.08) -> void:
	if sfx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -1000)) < 45:
		return
	_last_play[id] = now
	var s := stream(id)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pi]
	_pi = (_pi + 1) % POOL
	p.stream = s
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.volume_db = vol_db + linear_to_db(maxf(sfx_volume, 0.0001))
	p.play()


func set_ambience(id: String) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	_amb.stop()
	var s := stream("amb_" + id, true) if id != "" else null
	if s == null:
		return
	_amb.stream = s
	_apply_amb()
	_amb.play()


func start_music() -> void:
	if _music_on:
		return
	_music_on = true
	if _calm.stream != null:
		_calm.play()
	if _combat.stream != null:
		_combat.play()


func stop_music() -> void:
	_music_on = false
	_calm.stop()
	_combat.stop()


func set_combat(on: bool) -> void:
	_combat_on = on


func in_combat() -> bool:
	return _combat_on


func _process(delta: float) -> void:
	if not _music_on:
		return
	_mix = move_toward(_mix, 1.0 if _combat_on else 0.0, delta / FADE)
	var mv := maxf(music_volume, 0.0001)
	_calm.volume_db = linear_to_db(maxf(mv * (1.0 - _mix), 0.0001)) - 6.0
	_combat.volume_db = linear_to_db(maxf(mv * _mix, 0.0001)) - 6.0


func _apply_amb() -> void:
	_amb.volume_db = linear_to_db(maxf(sfx_volume * 0.7, 0.0001)) - 4.0


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_amb()
	save_settings()


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(c.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(c.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)


func save_settings() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS_PATH)
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sfx", sfx_volume)
	c.save(SETTINGS_PATH)


const SKILL_SOUNDS := {
	"power_strike": "sfx_slash", "shield_bash": "sfx_hit_metal", "triple_slash": "sfx_slash", "whirlwind": "sfx_whoosh",
	"battle_cry": "sfx_roar", "ground_slam": "sfx_hit_metal", "chain_lightning": "sfx_magic_lightning", "iron_wall": "sfx_hit_metal",
	"arrow_volley": "sfx_arrow", "piercing_shot": "sfx_arrow", "rapid_shot": "sfx_arrow", "arrow_rain": "sfx_arrow",
	"poison_cloud": "sfx_magic_nature", "wolf_spirit": "sfx_magic_nature", "stribog_dash": "sfx_whoosh", "hunters_trap": "sfx_hit_metal",
	"element_wave": "sfx_magic_fire", "sun_beam": "sfx_magic_holy", "ice_shards": "sfx_magic_ice", "ancestral_heal": "sfx_magic_holy",
	"fire_wave": "sfx_magic_fire", "raven_swarm": "sfx_magic_nature", "earth_spikes": "sfx_magic_nature", "ancestral_ward": "sfx_magic_holy",
	"ancestors_wrath": "sfx_magic_lightning",
}


static func skill_sound(id: String, kind: String) -> String:
	if SKILL_SOUNDS.has(id):
		return SKILL_SOUNDS[id]
	match kind:
		"volley":
			return "sfx_arrow"
		"heal", "shield", "buff":
			return "sfx_magic_holy"
		"chain":
			return "sfx_magic_lightning"
		"dash":
			return "sfx_whoosh"
	return "sfx_magic_fire"


static func blessing_magic(b: String) -> String:
	match b:
		"perun":
			return "sfx_magic_lightning"
		"veles", "mokosh":
			return "sfx_magic_nature"
		"dazhbog", "svarog":
			return "sfx_magic_fire"
		"morana":
			return "sfx_magic_ice"
	return "sfx_magic_holy"
