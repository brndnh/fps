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
	_streams["dry_fire"] = _click(0.025, 0.9, 0.5)
	_streams["mag_out"] = _click(0.05, 0.5, 0.7)
	_streams["mag_in"] = _click(0.06, 0.35, 1.0)
	_streams["chamber"] = _double_click()
	_streams["swap"] = _whoosh(0.2, 0.15)
	_streams["melee_swing"] = _whoosh(0.22, 0.3)
	_streams["melee_hit"] = _gunshot(0.12, 60.0, 0.2)
	_streams["hit_body"] = _blip(1700.0, 0.05)
	_streams["hit_head"] = _blip(2500.0, 0.14, 2.0)
	_streams["kill"] = _two_tone(1300.0, 2100.0)
	_streams["knife_draw"] = _shing()
	_streams["knife_swing"] = _whoosh(0.18, 0.45)
	_streams["knife_hit"] = _gunshot(0.1, 90.0, 0.25)
	_streams["rack"] = _double_click()
	_streams["throw"] = _whoosh(0.3, 0.2)
	_streams["pickup"] = _click(0.05, 0.6, 0.9)
	_streams["catch"] = _click(0.04, 0.3, 1.0)


func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


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


func _blip(freq: float, length: float, harmonic: float = 0.0) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var s := sin(TAU * freq * t)
		if harmonic > 0.0:
			s += 0.4 * sin(TAU * freq * harmonic * t)
		out[i] = s * exp(-u * 6.0) * minf(t / 0.002, 1.0) * 0.5
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
