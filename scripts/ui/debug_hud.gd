extends CanvasLayer
## Movement readout for tuning. F3 toggles it.

@onready var stats: Label = $Stats

var _peak := 0.0
var _peak_timer := 0.0


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		stats.visible = not stats.visible
	var p := get_parent() as Player
	if p == null or not stats.visible:
		return
	var spd := p.get_horizontal_speed()
	_peak_timer += delta
	if spd >= _peak or _peak_timer > 3.0:
		_peak = spd
		_peak_timer = 0.0
	stats.text = "Speed   %5.2f m/s\nPeak    %5.2f m/s (3s)\nState   %s%s\nBoost   %s\nFPS     %d\n\nF3 hide  ·  Esc menu" % [
		spd, _peak, p.get_state_name(), "  (crouched)" if p.is_crouched else "",
		"ready" if p.is_slide_boost_ready() else "cooldown", Engine.get_frames_per_second()]
