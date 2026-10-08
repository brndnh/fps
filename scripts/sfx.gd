extends Node
## Placeholder sounds (autoload "Sfx"). Everything is synthesized once at startup,
## so the project needs no audio files. To use real samples, load them into
## _streams under the same names.

const RATE := 22050
const VOICES := 24

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_rng.seed = 1337
	_streams["shot_carbine"] = _gunshot(0.22, 95.0, 0.55)
	_streams["shot_smg"] = _gunshot(0.13, 140.0, 0.7)
	_streams["shot_sidearm"] = _gunshot(0.38, 70.0, 0.45)
	_streams["shot_shotgun"] = _gunshot(0.45, 58.0, 0.65)
	_streams["shot_dmr"] = _gunshot(0.32, 82.0, 0.5)
	_streams["shot_sniper"] = _gunshot(0.7, 48.0, 0.5)
	_streams["dry_fire"] = _click(0.025, 0.9, 0.5)
	_streams["mag_out"] = _click(0.05, 0.5, 0.7)
	_streams["mag_in"] = _click(0.06, 0.35, 1.0)
	_streams["chamber"] = _double_click()
	_streams["swap"] = _whoosh(0.2, 0.15)
	_streams["melee_swing"] = _whoosh(0.22, 0.3)
	_streams["melee_hit"] = _gunshot(0.12, 60.0, 0.2)
	# Hit confirms are tonal and ring on past the gunshot's noise burst, so they never read as part of the shot.
	_streams["hit_body"] = _ding([3150.0, 4720.0], 0.16, 0.9)
	_streams["hit_head"] = _ding([4400.0, 6620.0, 8800.0], 0.32, 1.0)
	_streams["kill"] = _two_tone(1300.0, 2100.0)
	_streams["knife_draw"] = _shing()
	_streams["knife_swing"] = _whoosh(0.18, 0.45)
	_streams["knife_hit"] = _thud()
	_streams["rack"] = _double_click() # Charging handle / slide pulled and released in one go.
	_streams["slide_back"] = _click(0.05, 0.55, 0.8) # Bolt / pump pulled back...
	_streams["slide_home"] = _click(0.06, 0.35, 1.0) # ...and slammed home.
	_streams["hammer"] = _click(0.03, 0.75, 0.7) # Revolver hammer cocking.
	_streams["shot_olympia"] = _gunshot(0.5, 52.0, 0.62)
	_streams["shot_m4"] = _gunshot(0.24, 100.0, 0.6)
	_streams["shot_ak47"] = _gunshot(0.27, 80.0, 0.5)
	_streams["shot_deagle"] = _gunshot(0.42, 64.0, 0.55)
	_streams["shot_revolver"] = _gunshot(0.5, 56.0, 0.42)
	_streams["throw"] = _whoosh(0.3, 0.2)
	_streams["pickup"] = _click(0.05, 0.6, 0.9)
	_streams["catch"] = _click(0.04, 0.3, 1.0)


## Plays a sound on the next free voice. Returns the player, so the caller can cut it off.
func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> AudioStreamPlayer:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return null
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
	return p


# --- Synthesis ----------------------------------------------------------------

## Noise crack + low thump. brightness 0..1 = how much high end the noise keeps.
func _gunshot(length: float, thump_hz: float, brightness: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * brightness
		var noise := lp * exp(-u * 9.0) * (1.6 if t < 0.004 else 1.0)
		phase += TAU * thump_hz * (1.0 - 0.5 * u) / RATE
		var thump := sin(phase) * exp(-u * 7.0)
		out[i] = tanh((noise * 0.9 + thump * 0.8) * 1.4) * _fade_out(u)
	return _to_wav(out)


## Blade scrape: rising metallic ring over filtered noise.
func _shing() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.8
		phase += TAU * lerpf(2800.0, 4200.0, u) / RATE
		var ring := (sin(phase) + 0.5 * sin(phase * 1.51)) * 0.25
		out[i] = (lp * 0.35 + ring) * sin(minf(u * 8.0, 1.0) * PI * 0.5) * exp(-u * 4.0)
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


## Knife landing: a dull body thump with a short wet slap on top.
func _thud() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		phase += TAU * lerpf(150.0, 70.0, u) / RATE
		out[i] = tanh((sin(phase) * exp(-u * 6.0) + lp * exp(-t / 0.02) * 1.5) * 1.3) * 0.9 * _fade_out(u)
	return _to_wav(out)


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


func _fade_out(u: float) -> float:
	return clampf((1.0 - u) / 0.1, 0.0, 1.0)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav
