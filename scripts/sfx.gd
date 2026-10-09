extends Node
## Sounds (autoload "Sfx"). Gunshots, clicks, hit confirms and the like are synthesized
## once at startup, each gun from its own recipe (_gun()) so no two sound alike. Knife,
## impact, cloth and handling sounds are recorded: Kenney's CC0 packs (RPG Audio, Impact
## Sounds) in sounds/kenney/ (see its License.txt) and CC0 reload recordings from
## OpenGameArt in sounds/oga/ (see its CREDITS.txt). A sound can have several takes; each
## play picks one at random. To swap any sound for a recording, put the file(s) under the
## same name in _ready().
##
## Weapons also have a voice (their sound_prefix, or the knife's id): play_voiced() looks
## the sound up there first, so each gun's mag, bolt and slide, and each knife's draw,
## swing and hit, sound like that weapon (_voices_setup()).

const RATE := 22050
const KENNEY := "res://sounds/kenney/"
const OGA := "res://sounds/oga/"
const VOICES := 24
const VOICES_3D := 32

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_3d := 0
var _rng := RandomNumberGenerator.new()
## voice -> {pitch, sounds: {sound: takes ([] = silent)}, layers: {sound: [sound on top, dB]}, db: level offset}.
var _voices := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in VOICES_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 12.0
		p.max_distance = 150.0
		add_child(p)
		_players_3d.append(p)
	_rng.seed = 1337
	# Guns (by sound_prefix). See _gun() for what each setting does. Small and snappy up
	# top, big and booming at the bottom; the rings, grit and echoes set them apart.
	_streams["shot_smg"] = _gun({len = 0.14, thump = 150.0, bright = 0.75, crack = 0.35, tail = 0.1, tone = 2200.0, ring = 0.05, drive = 1.6})
	_streams["shot_m4"] = _gun({len = 0.25, thump = 105.0, bright = 0.62, crack = 0.55, tail = 0.3, drive = 1.5, echo = 0.06})
	_streams["shot_carbine"] = _gun({len = 0.24, thump = 95.0, bright = 0.55, crack = 0.5, tail = 0.35, tone = 1400.0, ring = 0.08, drive = 1.4, echo = 0.07})
	_streams["shot_ak47"] = _gun({len = 0.29, thump = 78.0, bright = 0.45, crack = 0.5, tail = 0.4, drive = 2.1, echo = 0.08})
	_streams["shot_sidearm"] = _gun({len = 0.32, thump = 78.0, bright = 0.5, crack = 0.45, tail = 0.3, drive = 1.5, echo = 0.09})
	_streams["shot_deagle"] = _gun({len = 0.45, thump = 60.0, bright = 0.5, crack = 0.7, tail = 0.55, drive = 2.0, echo = 0.12})
	_streams["shot_revolver"] = _gun({len = 0.55, thump = 52.0, bright = 0.4, crack = 0.6, tail = 0.7, tone = 650.0, ring = 0.12, drive = 1.7, echo = 0.15})
	_streams["shot_dmr"] = _gun({len = 0.36, thump = 85.0, bright = 0.5, crack = 0.9, tail = 0.45, tone = 1800.0, ring = 0.06, drive = 1.5, echo = 0.13})
	_streams["shot_shotgun"] = _gun({len = 0.5, thump = 55.0, bright = 0.7, crack = 0.3, tail = 0.6, drive = 2.2, echo = 0.11, gain = 0.5})
	_streams["shot_olympia"] = _gun({len = 0.55, thump = 48.0, bright = 0.62, crack = 0.4, tail = 0.75, drive = 2.4, echo = 0.14, gain = 0.6})
	_streams["shot_sniper"] = _gun({len = 0.85, thump = 42.0, bright = 0.5, crack = 1.0, tail = 0.9, drive = 1.8, echo = 0.22})
	_streams["shot_ssg"] = _gun({len = 0.6, thump = 62.0, bright = 0.6, crack = 0.95, tail = 0.65, tone = 2400.0, ring = 0.05, drive = 1.6, echo = 0.18}) # A sharper, lighter crack than the Harrier.
	_streams["shot_negev"] = _gun({len = 0.24, thump = 88.0, bright = 0.5, crack = 0.5, tail = 0.35, tone = 1100.0, ring = 0.06, drive = 1.9, echo = 0.07}) # Heavy and chattering.
	_streams["shot_enemy"] = _gun({len = 0.2, thump = 130.0, bright = 0.85, crack = 0.2, tail = 0.15, tone = 900.0, ring = 0.3, drive = 1.3}) # Thin and buzzy: not one of yours.
	_streams["dry_fire"] = _click(0.025, 0.9, 0.5)
	_streams["chamber"] = _double_click()
	_streams["melee_swing"] = _whoosh(0.22, 0.3)
	# Hit confirms are tonal and ring on past the gunshot's noise burst, so they never read as part of the shot.
	_streams["hit_body"] = _ding([3150.0, 4720.0], 0.16, 0.9)
	_streams["hit_head"] = _ding([4400.0, 6620.0, 8800.0], 0.32, 1.0)
	_streams["kill"] = _two_tone(1300.0, 2100.0)
	_streams["rack"] = _double_click() # Charging handle / slide pulled and released in one go.
	_streams["slide_back"] = _click(0.05, 0.55, 0.8) # Bolt / pump pulled back...
	_streams["slide_home"] = _click(0.06, 0.35, 1.0) # ...and slammed home.
	_streams["hammer"] = _click(0.03, 0.75, 0.7) # Revolver hammer cocking.
	_streams["throw"] = _whoosh(0.3, 0.2)
	_streams["catch"] = _click(0.04, 0.3, 1.0)
	_streams["heal_done"] = _ding([880.0, 1320.0], 0.4, 0.5)
	_streams["shield_hit"] = _ding([1450.0, 2180.0, 3350.0], 0.14, 0.6) # Electric clang: the shield took it.
	_streams["shield_break"] = _shatter()
	# Recorded (Kenney, CC0).
	_streams["knife_draw"] = _takes(["drawKnife1", "drawKnife2", "drawKnife3"])
	_streams["knife_swing"] = _takes(["knifeSlice", "knifeSlice2"])
	_streams["knife_hit"] = _takes(["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002"])
	_streams["melee_hit"] = _takes(["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"])
	_streams["mag_out"] = _takes(["metalClick"])
	_streams["mag_in"] = _takes(["metalLatch"])
	_streams["pickup"] = _takes(["handleSmallLeather", "handleSmallLeather2"])
	_streams["swap"] = _takes(["cloth1", "cloth2", "cloth3", "cloth4"]) # Hands shifting in inspect flourishes. Soft cloth: no buckles or chains.
	_streams["gun_swap"] = _takes(["clothBelt", "beltHandle1", "beltHandle2"]) # Sling and buckles: switching to a gun (and guns' inspects).
	_streams["heal_start"] = _takes(["handleSmallLeather", "handleSmallLeather2"])
	_streams["heal_apply"] = _takes(["cloth1", "cloth2", "cloth3", "cloth4"])
	_streams["impact_metal"] = _takes(["impactMetal_light_000", "impactMetal_light_001", "impactMetal_light_002"])
	_streams["impact_metal_heavy"] = _takes(["impactMetal_heavy_000", "impactMetal_heavy_001"])
	_streams["impact_wood"] = _takes(["impactPlank_medium_000", "impactPlank_medium_001"])
	_streams["land"] = _takes(["impactSoft_medium_000", "impactSoft_medium_001"])
	_voices_setup()


## Each weapon's own handling sounds. Guns get their own recorded mags, slides, bolts and
## pumps (pitched to suit: lower for the big ones); knives a ring of steel on the draw,
## a keen slash on the swing and a bite on the hit, each knife at its own pitch.
func _voices_setup() -> void:
	var pistol := {mag_out = _oga(["pistol_mag_out"]), mag_in = _oga(["pistol_mag_in"]),
			slide_home = _oga(["pistol_slide"]), rack = _oga(["pistol_slide"])}
	_voice("sidearm", 1.08, pistol)
	_voice("deagle", 0.84, pistol.merged({mag_out = _oga(["pistol_mag_out", "rifle_a_mag_out"])}, true))
	_voice("revolver", 1.0, {mag_out = _oga(["click_14"]), mag_in = _oga(["round_in"]),
			slide_home = _oga(["click_15"]), hammer = _oga(["click_08", "click_11"])})
	_voice("smg", 1.16, {mag_out = _oga(["rifle_b_mag_out"]), mag_in = _oga(["rifle_b_mag_in"]), rack = _oga(["clip_b"])})
	_voice("carbine", 1.0, {mag_out = _oga(["rifle_b_mag_out"]), mag_in = _oga(["rifle_b_mag_in"]), rack = _oga(["clip_a"])})
	_voice("m4", 1.02, {mag_out = _oga(["rifle_a_mag_out"]), mag_in = _oga(["rifle_a_mag_in"]),
			slide_back = _oga(["click_02"]), slide_home = _oga(["clip_a"]), rack = _oga(["clip_a"])})
	_voice("negev", 0.78, {mag_out = _oga(["rifle_a_mag_out"]), mag_in = _oga(["rifle_a_mag_in"]),
			slide_back = _oga(["click_03"]), slide_home = _oga(["clip_b"]), rack = _oga(["clip_b"])})
	_voice("ak47", 0.84, {mag_out = _oga(["rifle_a_mag_out"]), mag_in = _oga(["rifle_a_mag_in"]),
			slide_back = _oga(["click_03"]), slide_home = _oga(["clip_b"]), rack = _oga(["clip_b"])})
	_voice("dmr", 0.92, {mag_out = _oga(["rifle_b_mag_out"]), mag_in = _oga(["rifle_a_mag_in"]),
			slide_back = _oga(["click_13"]), slide_home = _oga(["clip_a"]), rack = _oga(["clip_a", "clip_b"])})
	_voice("ssg", 1.06, {mag_out = _oga(["rifle_b_mag_out"]), mag_in = _oga(["rifle_b_mag_in"]),
			slide_back = _oga(["click_04", "click_05"]), slide_home = _oga(["click_06", "click_09"])})
	_voice("sniper", 0.94, {mag_out = _oga(["rifle_a_mag_out"]), mag_in = _oga(["rifle_b_mag_in"]),
			slide_back = _oga(["click_04", "click_05"]), slide_home = _oga(["click_06", "click_09"])})
	# Shotguns only use short, tightly cut clips, so every pump and shell lands right on its cue.
	_voice("shotgun", 1.0, {mag_in = _oga(["round_in"]), slide_back = _oga(["pump_a"]), slide_home = []}, {}, -6.0)
	_voice("olympia", 0.9, {mag_out = _oga(["click_14"]), mag_in = _oga(["round_in"]), slide_home = _oga(["clip_a"])}, {}, -4.0)
	# Guns rattle their slings when you handle them.
	for id: String in ["sidearm", "deagle", "revolver", "smg", "carbine", "m4", "ak47", "dmr", "sniper", "ssg", "negev", "shotgun", "olympia"]:
		_voices[id].sounds.swap = _streams["gun_swap"]
	# Knives: [id, pitch, ring Hz, slash brightness]. Small, thin blades ring high and
	# slash bright; big ones lower and heavier.
	var flicks := _oga(["click_00", "click_01", "click_07", "click_10", "click_12"]) # Folding knives clack.
	for k: Array in [["combat", 1.0, 2650.0, 0.55], ["bayonet", 0.95, 2350.0, 0.5], ["m9", 0.9, 2100.0, 0.5],
			["bowie", 0.8, 1650.0, 0.42], ["karambit", 1.12, 3150.0, 0.62], ["butterfly", 1.1, 3500.0, 0.6],
			["stiletto", 1.2, 4100.0, 0.7], ["daggers", 1.08, 2800.0, 0.6], ["kunai", 1.15, 3700.0, 0.66]]:
		var id: String = k[0]
		_streams["shing_" + id] = _shing(k[2], 0.55, 0.5)
		_streams["slash_" + id] = _slash(0.17, k[3], k[2] * 1.5)
		_streams["bite_" + id] = _bite(k[2] * 0.6)
		var own := {knife_draw = []} # The draw is just the ring of steel (the shing layer), no rustle.
		if id in ["butterfly", "stiletto"]:
			own.catch = flicks
		_voice(id, k[1], own, {knife_draw = ["shing_" + id, -2.0], knife_swing = ["slash_" + id, -1.0],
				knife_hit = ["bite_" + id, -2.0]})


func _voice(id: String, pitch: float, sounds: Dictionary, layers: Dictionary = {}, db: float = 0.0) -> void:
	_voices[id] = {pitch = pitch, sounds = sounds, layers = layers, db = db}


## Recorded takes from sounds/oga/ (.wav, or .mp3).
func _oga(names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n: String in names:
		var path := OGA + n + ".wav"
		if not ResourceLoader.exists(path):
			path = OGA + n + ".mp3"
		out.append(load(path))
	return out


## The recorded takes of one sound, from sounds/kenney/.
func _takes(names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n: String in names:
		out.append(load(KENNEY + n + ".ogg"))
	return out


## One of the sound's takes, at random.
func _stream(sound: String) -> AudioStream:
	var s: Variant = _streams.get(sound)
	if s is Array:
		return (s as Array).pick_random() if not (s as Array).is_empty() else null
	return s


## Plays a sound out in the world (other players' guns), quieter with distance.
func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % VOICES_3D
	p.global_position = pos
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Plays a sound on the next free voice. Returns the player, so the caller can cut it off.
func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> AudioStreamPlayer:
	return _emit(_stream(sound), volume_db, 1.0 + randf_range(-pitch_jitter, pitch_jitter))


## A weapon's sound: its own take of it (and anything layered on top) if its voice has
## one, else the shared sound, at the voice's pitch. Returns the main player.
func play_voiced(sound: String, voice: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> AudioStreamPlayer:
	var v: Dictionary = _voices.get(voice, {})
	if v.is_empty():
		return play(sound, volume_db, pitch_jitter)
	var pitch: float = v.pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	var layer: Array = v.layers.get(sound, [])
	if not layer.is_empty():
		_emit(_stream(layer[0]), volume_db + float(layer[1]), 1.0 + randf_range(-pitch_jitter, pitch_jitter))
	var stream := _stream(sound)
	if v.sounds.has(sound):
		var own: Array = v.sounds[sound]
		if own.is_empty():
			return null # This weapon doesn't make that sound (the pump's clip has both strokes).
		stream = own.pick_random()
	return _emit(stream, volume_db + float(v.db), pitch)


func _emit(stream: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


# --- Synthesis ----------------------------------------------------------------

## A gunshot from a recipe, so every gun has its own voice. All optional:
##   len    seconds long
##   thump  body frequency in Hz: lower is a bigger gun
##   bright 0..1, how much hiss the blast keeps
##   crack  0..1, the sharp snap right at the start
##   tail   0..1, how long the blast rings out
##   tone   Hz of a metallic ring in the shot (0 = none), ring = its level
##   drive  distortion: more is grittier
##   echo   seconds until a slap-back off the walls (0 = none)
##   gain   overall level (1 = full; the shotguns are turned down)
func _gun(r: Dictionary) -> AudioStreamWAV:
	var length: float = r.get("len", 0.3)
	var thump: float = r.get("thump", 90.0)
	var bright: float = r.get("bright", 0.55)
	var crack: float = r.get("crack", 0.5)
	var tail: float = r.get("tail", 0.3)
	var tone: float = r.get("tone", 0.0)
	var ring: float = r.get("ring", 0.0)
	var drive: float = r.get("drive", 1.4)
	var echo: float = r.get("echo", 0.0)
	var gain: float = r.get("gain", 1.0)
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	var noise_decay := lerpf(12.0, 3.5, tail)
	var body_decay := lerpf(9.0, 4.0, tail)
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * bright
		var noise := lp * exp(-u * noise_decay)
		var snap := white * exp(-t / 0.0015) * crack * 2.0
		phase += TAU * thump * (1.0 - 0.5 * u) / RATE
		var body := sin(phase) * exp(-u * body_decay)
		var metal := sin(TAU * tone * t) * exp(-u * 6.0) * ring if tone > 0.0 else 0.0
		out[i] = tanh((noise * 0.9 + body * 0.8 + snap + metal) * drive) * 0.9
	if echo > 0.0: # A softer, duller copy, a moment later.
		var d := int(RATE * echo)
		var dry := out.duplicate()
		var smooth := 0.0
		for i in range(d, n):
			smooth += (dry[i - d] - smooth) * 0.25
			out[i] = clampf(out[i] + smooth * 0.35, -1.0, 1.0)
	for i in n:
		out[i] *= _fade_out(float(i) / n) * gain
	return _to_wav(out)


func _click(length: float, brightness: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var u := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * brightness
		out[i] = lp * exp(-u * 10.0) * gain
	return _to_wav(out)


func _double_click() -> AudioStreamWAV:
	var a := _click(0.04, 0.6, 0.8).data
	var gap := PackedByteArray()
	gap.resize(int(RATE * 0.06) * 2)
	var b := _click(0.05, 0.4, 1.0).data
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = a + gap + b
	return wav


func _whoosh(length: float, brightness: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var u := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * brightness
		out[i] = lp * sin(u * PI) * 1.2
	return _to_wav(out)


## Struck-metal "tink": inharmonic sine partials (the first loudest) with a hard
## attack and an exponential ring, plus a tick of noise on the strike.
func _ding(freqs: Array, length: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var s := 0.0
		for k in freqs.size():
			s += sin(TAU * float(freqs[k]) * t) * exp(-u * (4.0 + 3.0 * k)) / (1.0 + k)
		var strike := _rng.randf_range(-1.0, 1.0) * exp(-t / 0.002) * 0.6
		out[i] = (s * 0.55 + strike) * minf(t / 0.0008, 1.0) * gain * _fade_out(u)
	return _to_wav(out)


## A shield breaking: a bright burst of glassy noise, scattered high shards ringing off,
## and a falling electric tone under it.
func _shatter() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var shards: Array = [] # [start s, Hz, decay]
	for i in 9:
		shards.append([_rng.randf_range(0.0, 0.12), _rng.randf_range(2500.0, 7000.0), _rng.randf_range(18.0, 40.0)])
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.6
		var burst := (white - lp * 0.5) * exp(-t / 0.05) * 0.8
		var s := 0.0
		for sh: Array in shards:
			var r: float = t - sh[0]
			if r >= 0.0:
				s += sin(TAU * float(sh[1]) * r) * exp(-r * float(sh[2])) * 0.18
		phase += TAU * lerpf(900.0, 220.0, minf(t / 0.45, 1.0)) / rate
		var fall := signf(sin(phase)) * exp(-t * 6.0) * 0.12
		out[i] = (burst + s + fall) * _fade_out(float(i) / n)
	return _to_wav(out, rate)


func _two_tone(f1: float, f2: float) -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var f := f1 if u < 0.4 else f2
		out[i] = sin(TAU * f * t) * exp(-fmod(u, 0.4) * 5.0) * 0.45 * _fade_out(u)
	return _to_wav(out)


## A blade drawn: a bright rasp along the sheath, then the steel rings as it clears
## (inharmonic partials over `ring` Hz).
func _shing(ring: float, length: float, scrape: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var clear := 0.11 # Seconds of scrape before the blade is out.
	for i in n:
		var t := float(i) / rate
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.3
		var rasp := (white - lp) * (0.65 + 0.35 * sin(TAU * 41.0 * t)) # High-passed, with a grain to it.
		var s_env := smoothstep(0.0, clear, t) * (1.0 - smoothstep(clear, clear + 0.025, t))
		var r := maxf(t - clear, 0.0)
		var r_env := minf(r / 0.0015, 1.0) * exp(-r * 7.0) if t >= clear else 0.0
		var tone := sin(TAU * ring * r) + sin(TAU * ring * 2.76 * r) * 0.5 * exp(-r * 5.0) \
				+ sin(TAU * ring * 5.4 * r) * 0.3 * exp(-r * 12.0)
		out[i] = (rasp * s_env * scrape + tone * r_env * 0.3) * _fade_out(float(i) / n)
	return _to_wav(out, rate)


## A blade cutting the air: a quick, high, hissing swish with a glint of ring.
func _slash(length: float, brightness: float, ring: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / rate
		var u := float(i) / n
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * brightness
		lp2 += (lp - lp2) * 0.08
		var env := pow(u / 0.35, 2.0) if u < 0.35 else exp(-(u - 0.35) * 7.0) # Swells in, cuts off.
		out[i] = ((lp - lp2) * 1.6 + sin(TAU * ring * t) * 0.06) * env * _fade_out(u)
	return _to_wav(out, rate)


## A blade going in: a sharp, crunchy tick and a short, dull ring.
func _bite(ring: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.5
		var tick := (white - lp) * exp(-t / 0.006) * 1.2
		var crunch := lp * exp(-t / 0.025) * (0.6 + 0.4 * signf(sin(TAU * 180.0 * t)))
		var tone := sin(TAU * ring * t) * exp(-t * 40.0) * 0.25
		out[i] = (tick + crunch * 0.7 + tone) * _fade_out(float(i) / n)
	return _to_wav(out, rate)


func _fade_out(u: float) -> float:
	return clampf((1.0 - u) / 0.1, 0.0, 1.0)


func _to_wav(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav
