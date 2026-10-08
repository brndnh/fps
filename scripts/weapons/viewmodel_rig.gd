extends Node3D
## Root of a weapon viewmodel scene. Method tracks in its animations call
## play_sfx() so sounds stay in sync with the keyframes (and with reload speed).


func play_sfx(sound: String, volume_db: float = -6.0) -> void:
	# Looked up by path (not the Sfx global) so tools/build_weapons.gd can load this script.
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(sound, volume_db)
