extends SceneTree
## Generates the weapon viewmodels (scenes/weapons/*.tscn, including their
## keyframed animations) and their stats (weapons/*.tres).
##   godot --headless -s tools/build_weapons.gd
## WARNING: overwrites those files. Once you've tuned weapons or edited
## animations in the editor, don't rerun this (or edit the values here first).
##
## Viewmodel layout:  Rig (viewmodel_rig.gd)
##                      Pivot           <- whole-hands motion (swings, tilts)
##                        Gun           <- the weapon alone (spins, tosses)
##                          Magazine, Bolt/Slide, Muzzle, ...
##                        Arms
##                      AnimationPlayer
## Animation keys below are offsets from rest: metres, and degrees (Euler XYZ).
## Big rotations are fine (720 = two full spins). Keys are smoothed and baked into
## dense linear keys (see _bake), so retime animations here and rerun rather than
## moving baked keys in the editor.

const BAKE_FPS := 60.0
## Where each viewmodel sits in front of the camera at the hip (WeaponData.hip_position).
## The arms are built from it so the shoulders end up in the same place for every weapon.
const HIP := {
	carbine = Vector3(0.19, -0.2, -0.52), smg = Vector3(0.17, -0.19, -0.47), sidearm = Vector3(0.14, -0.16, -0.4),
	shotgun = Vector3(0.18, -0.19, -0.5), dmr = Vector3(0.19, -0.2, -0.54), sniper = Vector3(0.19, -0.21, -0.52),
	m4 = Vector3(0.19, -0.2, -0.52), ak47 = Vector3(0.19, -0.2, -0.52), olympia = Vector3(0.17, -0.19, -0.5),
	deagle = Vector3(0.15, -0.17, -0.42), revolver = Vector3(0.15, -0.17, -0.42), knife = Vector3(0.2, -0.2, -0.42),
	ssg = Vector3(0.19, -0.21, -0.5),
	negev = Vector3(0.2, -0.21, -0.54),
}

var _mat := {}


func _init() -> void:
	_mat.gun = load("res://materials/vm_gun.tres")
	_mat.accent = load("res://materials/vm_gun_accent.tres")
	_mat.glove = load("res://materials/vm_glove.tres")
	_mat.sleeve = load("res://materials/vm_sleeve.tres")
	_mat.sight = _vm_material("res://materials/vm_sight.tres", Color(1.0, 0.5, 0.1), 0.5, 0.0, Color(1.0, 0.45, 0.05))
	_mat.blade = _vm_material("res://materials/vm_blade.tres", Color(0.78, 0.8, 0.84), 0.18, 0.9, Color.BLACK)
	_mat.k_orange = _vm_material("res://materials/vm_knife_orange.tres", Color(0.85, 0.42, 0.12), 0.5, 0.2, Color.BLACK)
	_mat.k_teal = _vm_material("res://materials/vm_knife_teal.tres", Color(0.1, 0.45, 0.5), 0.4, 0.3, Color.BLACK)
	_mat.k_gold = _vm_material("res://materials/vm_knife_gold.tres", Color(0.85, 0.65, 0.2), 0.3, 0.8, Color.BLACK)
	_mat.k_red = _vm_material("res://materials/vm_knife_red.tres", Color(0.6, 0.08, 0.08), 0.5, 0.2, Color.BLACK)
	_mat.k_olive = _vm_material("res://materials/vm_knife_olive.tres", Color(0.3, 0.33, 0.2), 0.8, 0.0, Color.BLACK)
	_mat.k_wood = _vm_material("res://materials/vm_wood.tres", Color(0.42, 0.24, 0.12), 0.7, 0.0, Color.BLACK)
	_mat.k_black = _vm_material("res://materials/vm_knife_black.tres", Color(0.07, 0.07, 0.08), 0.6, 0.2, Color.BLACK)
	_mat.k_purple = _vm_material("res://materials/vm_knife_purple.tres", Color(0.32, 0.12, 0.55), 0.4, 0.3, Color.BLACK)
	_mat.k_void = _vm_material("res://materials/vm_knife_void.tres", Color(0.6, 0.35, 1.0), 0.2, 0.0, Color(0.55, 0.25, 1.0))
	_mat.k_kunai = _vm_material("res://materials/vm_knife_kunai.tres", Color(0.07, 0.06, 0.12), 0.25, 0.7, Color(0.02, 0.02, 0.06))
	_mat.k_dot = _vm_material("res://materials/vm_knife_dot.tres", Color(0.75, 0.8, 1.0), 0.2, 0.0, Color(0.55, 0.62, 1.0))
	_mat.awp = _vm_material("res://materials/vm_awp_green.tres", Color(0.26, 0.34, 0.2), 0.75, 0.05, Color.BLACK) # The Harrier's chassis.
	_mat.dark_blade = _vm_material("res://materials/vm_blade_dark.tres", Color(0.22, 0.23, 0.25), 0.3, 0.9, Color.BLACK)

	_save_scene(_carbine(), "res://scenes/weapons/carbine.tscn")
	_save_scene(_smg(), "res://scenes/weapons/smg.tscn")
	_save_scene(_sidearm(), "res://scenes/weapons/sidearm.tscn")
	_save_scene(_deagle(), "res://scenes/weapons/deagle.tscn")
	_save_scene(_revolver(), "res://scenes/weapons/revolver.tscn")
	_save_scene(_shotgun(), "res://scenes/weapons/shotgun.tscn")
	_save_scene(_olympia(), "res://scenes/weapons/olympia.tscn")
	_save_scene(_dmr(), "res://scenes/weapons/dmr.tscn")
	_save_scene(_m4(), "res://scenes/weapons/m4.tscn")
	_save_scene(_ak47(), "res://scenes/weapons/ak47.tscn")
	_save_scene(_sniper(), "res://scenes/weapons/sniper.tscn")
	_save_scene(_ssg(), "res://scenes/weapons/ssg.tscn")
	_save_scene(_negev(), "res://scenes/weapons/negev.tscn")
	_save_scene(_knife_combat(), "res://scenes/weapons/knife.tscn")
	_save_scene(_knife_karambit(), "res://scenes/weapons/knife_karambit.tscn")
	_save_scene(_knife_butterfly(), "res://scenes/weapons/knife_butterfly.tscn")
	_save_scene(_knife_bayonet(), "res://scenes/weapons/knife_bayonet.tscn")
	for id: String in NEW_KNIVES:
		_save_scene(call("_knife_" + id), "res://scenes/weapons/knife_%s.tscn" % id)
	_save_data()
	print("Weapons built.")
	quit()


# --- Stats ------------------------------------------------------------------------

func _save_data() -> void:
	var WeaponData: GDScript = load("res://scripts/weapons/weapon_data.gd")

	# Carbine: R-301 style. Steady climb with a gentle side-to-side wobble.
	var pattern := PackedVector2Array()
	for i in 28:
		var up := 0.42 if i < 6 else (0.34 if i < 14 else 0.26)
		pattern.append(Vector2(0.12 * sin(i * 0.45 + 0.3), up))
	_save_res(WeaponData.new(), "res://weapons/carbine.tres", {
		display_name = "Vanta", model_scene = load("res://scenes/weapons/carbine.tscn"), sound_prefix = "carbine",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.02,
		fire_mode = 0, rpm = 780.0, damage = 14.0, head_multiplier = 1.75,
		falloff_start = 40.0, falloff_end = 80.0, falloff_min = 0.7,
		mag_size = 28, ammo_type = "light", reload_time = 2.4, reload_empty_time = 3.1, reload_commit = 0.7,
		draw_time = 0.55, quick_draw_time = 0.4, move_speed = 1.0, holster_time = 0.25, ads_time = 0.22, ads_zoom = 1.15, ads_move_speed = 0.55,
		sprint_to_fire_time = 0.22,
		hip_spread = 2.0, ads_spread = 0.0, move_spread = 1.2, air_spread = 2.0,
		bloom_per_shot = 0.12, bloom_max = 1.2, bloom_decay = 5.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.05, recoil_recovery = 10.0,
		view_punch = 0.6,
		hip_position = HIP.carbine, ads_position = Vector3(0.0, -0.0775, -0.36),
		kick_back = 0.035, kick_rotation = 3.0, muzzle_flash_size = 1.0, throw_damage = 30.0,
	})

	# SMG: R-99 style. Fast, light kick, more horizontal jitter, great hipfire.
	pattern = PackedVector2Array()
	for i in 22:
		pattern.append(Vector2(0.16 * sin(i * 1.1), 0.34 if i < 5 else 0.28))
	_save_res(WeaponData.new(), "res://weapons/smg.tres", {
		display_name = "Hornet", model_scene = load("res://scenes/weapons/smg.tscn"), sound_prefix = "smg",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.018,
		fire_mode = 0, rpm = 1000.0, damage = 11.0, head_multiplier = 1.5,
		falloff_start = 20.0, falloff_end = 50.0, falloff_min = 0.6,
		mag_size = 22, ammo_type = "light", reload_time = 1.8, reload_empty_time = 2.4, reload_commit = 0.7,
		draw_time = 0.5, quick_draw_time = 0.35, move_speed = 1.0, holster_time = 0.2, ads_time = 0.18, ads_zoom = 1.1, ads_move_speed = 0.7,
		sprint_to_fire_time = 0.18,
		hip_spread = 1.3, ads_spread = 0.0, move_spread = 0.7, air_spread = 1.2,
		bloom_per_shot = 0.08, bloom_max = 0.8, bloom_decay = 6.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.08, recoil_recovery = 12.0,
		view_punch = 0.45,
		hip_position = HIP.smg, ads_position = Vector3(0.0, -0.0745, -0.33),
		kick_back = 0.025, kick_rotation = 2.2, muzzle_flash_size = 0.8, throw_damage = 25.0,
	})

	# Kestrel (sidearm): a light, quick pistol with an extended 20-round mag. Weak hits, fast
	# trigger, little kick; X switches it to a 3-round burst.
	pattern = PackedVector2Array()
	for i in 20:
		pattern.append(Vector2(0.08 if i % 2 == 0 else -0.06, 0.55))
	_save_res(WeaponData.new(), "res://weapons/sidearm.tres", {
		display_name = "Kestrel", model_scene = load("res://scenes/weapons/sidearm.tscn"), sound_prefix = "sidearm",
		bolt_node = ^"Pivot/Gun/Slide", bolt_kick = 0.035,
		fire_mode = 1, rpm = 480.0, damage = 17.0, head_multiplier = 2.0, burst_count = 3, burst_rpm = 1100.0,
		falloff_start = 25.0, falloff_end = 60.0, falloff_min = 0.65,
		mag_size = 20, ammo_type = "light", reload_time = 1.6, reload_empty_time = 2.0, reload_commit = 0.7,
		draw_time = 0.42, quick_draw_time = 0.28, move_speed = 1.06, holster_time = 0.2, ads_time = 0.16, ads_zoom = 1.1, ads_move_speed = 0.8,
		sprint_to_fire_time = 0.15,
		hip_spread = 1.3, ads_spread = 0.0, move_spread = 0.8, air_spread = 1.4,
		bloom_per_shot = 0.15, bloom_max = 1.0, bloom_decay = 5.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.2, recoil_recovery = 14.0,
		view_punch = 0.6,
		hip_position = HIP.sidearm, ads_position = Vector3(0.0, -0.0525, -0.34),
		kick_back = 0.025, kick_rotation = 3.0, muzzle_flash_size = 0.9, throw_damage = 20.0,
	})

	# Desert Eagle: heavy semi-auto. Big hits, big kick; the first shot is accurate, spamming isn't.
	pattern = PackedVector2Array()
	for i in 7:
		pattern.append(Vector2(0.2 if i % 2 == 0 else -0.15, 2.1))
	_save_res(WeaponData.new(), "res://weapons/deagle.tres", {
		display_name = "Desert Eagle", model_scene = load("res://scenes/weapons/deagle.tscn"), sound_prefix = "deagle",
		bolt_node = ^"Pivot/Gun/Slide", bolt_kick = 0.04,
		fire_mode = 1, rpm = 267.0, damage = 53.0, head_multiplier = 2.0,
		falloff_start = 40.0, falloff_end = 90.0, falloff_min = 0.75,
		mag_size = 7, ammo_type = "heavy", reload_time = 2.2, reload_empty_time = 2.6, reload_commit = 0.7,
		draw_time = 0.62, quick_draw_time = 0.3, move_speed = 1.04, holster_time = 0.2, ads_time = 0.18, ads_zoom = 1.15, ads_move_speed = 0.75,
		sprint_to_fire_time = 0.18,
		hip_spread = 1.3, ads_spread = 0.0, move_spread = 1.8, air_spread = 2.0,
		bloom_per_shot = 0.9, bloom_max = 2.4, bloom_decay = 3.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.3, recoil_recovery = 12.0,
		view_punch = 1.8,
		hip_position = HIP.deagle, ads_position = Vector3(0.0, -0.052, -0.34),
		kick_back = 0.06, kick_rotation = 9.0, muzzle_flash_size = 1.4, throw_damage = 25.0,
	})

	# R8 Revolver: hold fire to cock the hammer, and it fires when it's back. Hits like a truck, dead accurate.
	pattern = PackedVector2Array()
	for i in 8:
		pattern.append(Vector2(0.12 if i % 2 == 0 else -0.1, 2.4))
	_save_res(WeaponData.new(), "res://weapons/revolver.tres", {
		display_name = "R8 Revolver", model_scene = load("res://scenes/weapons/revolver.tscn"), sound_prefix = "revolver",
		bolt_node = ^"", bolt_kick = 0.0,
		fire_mode = 0, rpm = 110.0, prime_time = 0.32, damage = 72.0, head_multiplier = 2.0, cycle_after_shot = true,
		falloff_start = 40.0, falloff_end = 90.0, falloff_min = 0.7,
		mag_size = 8, ammo_type = "heavy", reload_time = 2.5, reload_empty_time = 2.5, reload_commit = 0.72,
		draw_time = 0.7, quick_draw_time = 0.3, move_speed = 1.04, holster_time = 0.2, ads_time = 0.2, ads_zoom = 1.15, ads_move_speed = 0.75,
		sprint_to_fire_time = 0.18,
		hip_spread = 0.7, ads_spread = 0.0, move_spread = 1.4, air_spread = 2.2,
		bloom_per_shot = 0.4, bloom_max = 1.6, bloom_decay = 3.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.25, recoil_recovery = 12.0,
		view_punch = 1.6,
		hip_position = HIP.revolver, ads_position = Vector3(0.0, -0.052, -0.34),
		kick_back = 0.06, kick_rotation = 10.0, muzzle_flash_size = 1.4, throw_damage = 25.0,
	})

	# Breacher: pump action, Titanfall / Apex Mastiff-ish. 8 pellets in a flat horizontal line
	# (the line squeezes in when aimed), loads a shell at a time.
	pattern = PackedVector2Array()
	for i in 6:
		pattern.append(Vector2(0.25 if i % 2 == 0 else -0.2, 2.6))
	_save_res(WeaponData.new(), "res://weapons/shotgun.tres", {
		display_name = "Breacher", model_scene = load("res://scenes/weapons/shotgun.tscn"), sound_prefix = "shotgun",
		bolt_node = ^"Pivot/Gun/Pump", bolt_kick = 0.0,
		fire_mode = 1, rpm = 70.0, damage = 13.0, head_multiplier = 1.5, pellets = 8,
		pellet_spread = 5.0, pellet_spread_ads = 2.2, pellet_line = true, cycle_after_shot = true,
		falloff_start = 10.0, falloff_end = 26.0, falloff_min = 0.35,
		mag_size = 6, ammo_type = "shells", reload_commit = 0.7,
		shell_reload = true, reload_start_time = 0.4, shell_time = 0.5, reload_end_time = 0.42,
		draw_time = 0.6, quick_draw_time = 0.4, move_speed = 1.0, holster_time = 0.22, ads_time = 0.2, ads_zoom = 1.1, ads_move_speed = 0.65,
		sprint_to_fire_time = 0.2,
		hip_spread = 0.4, ads_spread = 0.0, move_spread = 0.6, air_spread = 1.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.25, recoil_recovery = 16.0,
		view_punch = 2.2,
		hip_position = HIP.shotgun, ads_position = Vector3(0.0, -0.066, -0.36),
		kick_back = 0.06, kick_rotation = 8.0, muzzle_flash_size = 1.6, throw_damage = 30.0,
	})

	# Olympia: over-under double barrel. Two big blasts back to back, then break it open.
	_save_res(WeaponData.new(), "res://weapons/olympia.tres", {
		display_name = "Olympia", model_scene = load("res://scenes/weapons/olympia.tscn"), sound_prefix = "olympia",
		bolt_node = ^"", bolt_kick = 0.0,
		fire_mode = 1, rpm = 300.0, damage = 14.0, head_multiplier = 1.5, pellets = 10,
		pellet_spread = 3.6, pellet_spread_ads = 2.2,
		falloff_start = 12.0, falloff_end = 30.0, falloff_min = 0.4,
		mag_size = 2, ammo_type = "shells", reload_time = 2.0, reload_empty_time = 2.0, reload_commit = 0.6,
		draw_time = 0.6, quick_draw_time = 0.35, move_speed = 1.0, holster_time = 0.22, ads_time = 0.2, ads_zoom = 1.1, ads_move_speed = 0.65,
		sprint_to_fire_time = 0.2,
		hip_spread = 0.4, ads_spread = 0.0, move_spread = 0.6, air_spread = 1.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = PackedVector2Array([Vector2(0.2, 3.0), Vector2(-0.25, 3.2)]), recoil_scale_ads = 0.85,
		recoil_jitter = 0.25, recoil_recovery = 16.0, view_punch = 2.6,
		hip_position = HIP.olympia, ads_position = Vector3(0.0, -0.045, -0.36),
		kick_back = 0.07, kick_rotation = 9.0, muzzle_flash_size = 1.7, throw_damage = 30.0,
	})

	# DMR: semi-auto marksman rifle with a holo optic, Longbow / G3-ish. Two body shots to crack shields.
	pattern = PackedVector2Array()
	for i in 10:
		pattern.append(Vector2(0.12 * sin(i * 1.3 + 0.5), 1.0 if i < 3 else 0.85))
	_save_res(WeaponData.new(), "res://weapons/dmr.tres", {
		display_name = "Heron", model_scene = load("res://scenes/weapons/dmr.tscn"), sound_prefix = "dmr",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.025,
		fire_mode = 1, rpm = 240.0, damage = 38.0, head_multiplier = 2.0,
		falloff_start = 60.0, falloff_end = 120.0, falloff_min = 0.8,
		mag_size = 10, ammo_type = "sniper", reload_time = 2.5, reload_empty_time = 3.2, reload_commit = 0.7,
		draw_time = 0.6, quick_draw_time = 0.42, move_speed = 0.95, holster_time = 0.25, ads_time = 0.28, ads_zoom = 2.2, ads_move_speed = 0.5,
		sprint_to_fire_time = 0.25,
		hip_spread = 2.6, ads_spread = 0.0, move_spread = 1.6, air_spread = 2.5,
		bloom_per_shot = 0.5, bloom_max = 1.6, bloom_decay = 3.5,
		recoil_pattern = pattern, recoil_scale_ads = 0.8, recoil_jitter = 0.1, recoil_recovery = 12.0,
		view_punch = 1.1,
		hip_position = HIP.dmr, ads_position = Vector3(0.0, -0.088, -0.3),
		kick_back = 0.045, kick_rotation = 4.5, muzzle_flash_size = 1.2, throw_damage = 30.0,
	})

	# M4A4: CS's CT rifle. Controllable: climbs, then drifts left and back right.
	pattern = PackedVector2Array()
	for i in 30:
		var side := 0.0 if i < 6 else (-0.13 if i < 14 else (0.13 if i < 22 else -0.06))
		pattern.append(Vector2(side + 0.03 * sin(i * 1.7), 0.46 if i < 6 else (0.3 if i < 14 else 0.18)))
	_save_res(WeaponData.new(), "res://weapons/m4.tres", {
		display_name = "M4A4", model_scene = load("res://scenes/weapons/m4.tscn"), sound_prefix = "m4",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.0,
		fire_mode = 0, rpm = 666.0, damage = 15.0, head_multiplier = 2.0,
		falloff_start = 40.0, falloff_end = 90.0, falloff_min = 0.75,
		mag_size = 30, ammo_type = "heavy", reload_time = 3.1, reload_empty_time = 3.1, reload_commit = 0.65,
		draw_time = 0.9, quick_draw_time = 0.4, move_speed = 0.97, holster_time = 0.25, ads_time = 0.22, ads_zoom = 1.15, ads_move_speed = 0.55,
		sprint_to_fire_time = 0.22,
		hip_spread = 1.8, ads_spread = 0.0, move_spread = 1.3, air_spread = 2.0,
		bloom_per_shot = 0.1, bloom_max = 1.1, bloom_decay = 5.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.05, recoil_recovery = 10.0,
		view_punch = 0.55,
		hip_position = HIP.m4, ads_position = Vector3(0.0, -0.064, -0.36),
		kick_back = 0.033, kick_rotation = 2.8, muzzle_flash_size = 1.0, throw_damage = 30.0,
	})

	# AK-47: CS's T rifle. Hits harder, kicks harder: a big climb, then whips right and back left.
	pattern = PackedVector2Array()
	for i in 30:
		var side := 0.0 if i < 8 else (0.2 if i < 15 else (-0.22 if i < 23 else 0.12))
		pattern.append(Vector2(side + 0.04 * sin(i * 1.3), 0.58 if i < 8 else (0.32 if i < 15 else 0.16)))
	_save_res(WeaponData.new(), "res://weapons/ak47.tres", {
		display_name = "AK-47", model_scene = load("res://scenes/weapons/ak47.tscn"), sound_prefix = "ak47",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.03,
		fire_mode = 0, rpm = 600.0, damage = 19.0, head_multiplier = 2.0,
		falloff_start = 40.0, falloff_end = 90.0, falloff_min = 0.7,
		mag_size = 30, ammo_type = "heavy", reload_time = 2.5, reload_empty_time = 2.9, reload_commit = 0.65,
		draw_time = 0.85, quick_draw_time = 0.4, move_speed = 0.96, holster_time = 0.25, ads_time = 0.23, ads_zoom = 1.15, ads_move_speed = 0.55,
		sprint_to_fire_time = 0.22,
		hip_spread = 2.1, ads_spread = 0.0, move_spread = 1.5, air_spread = 2.4,
		bloom_per_shot = 0.14, bloom_max = 1.4, bloom_decay = 4.5,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.07, recoil_recovery = 10.0,
		view_punch = 0.7,
		hip_position = HIP.ak47, ads_position = Vector3(0.0, -0.058, -0.36),
		kick_back = 0.04, kick_rotation = 3.5, muzzle_flash_size = 1.1, throw_damage = 30.0,
	})

	# Sniper: bolt action, AWP / Kraber-ish. Headshot kills from full shield and health.
	# Hipfire is wild; scoped is dead on unless you move. Unscopes to work the bolt, then scopes back in.
	_save_res(WeaponData.new(), "res://weapons/sniper.tres", {
		display_name = "Harrier", model_scene = load("res://scenes/weapons/sniper.tscn"), sound_prefix = "sniper",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.0,
		fire_mode = 1, rpm = 40.0, damage = 135.0, head_multiplier = 2.0, cycle_after_shot = true, unscope_on_shot = true,
		falloff_start = 300.0, falloff_end = 400.0, falloff_min = 1.0,
		mag_size = 5, ammo_type = "sniper", reload_time = 3.2, reload_empty_time = 3.8, reload_commit = 0.7,
		draw_time = 0.85, quick_draw_time = 0.55, move_speed = 0.9, holster_time = 0.3, ads_time = 0.3, ads_zoom = 7.0, ads_move_speed = 0.4,
		sprint_to_fire_time = 0.3, scope_overlay = true,
		hip_spread = 7.0, ads_spread = 0.0, move_spread = 3.0, ads_move_spread = 3.0, air_spread = 6.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = PackedVector2Array([Vector2(0.2, 3.2)]), recoil_scale_ads = 0.7, recoil_jitter = 0.3, recoil_recovery = 14.0,
		view_punch = 3.0,
		hip_position = HIP.sniper, ads_position = Vector3(0.0, -0.075, -0.3),
		kick_back = 0.07, kick_rotation = 9.0, muzzle_flash_size = 1.7, throw_damage = 35.0,
	})

	# Negev: light machine gun, 60-round box. Fast and steady once it's going, but heavy to
	# carry and slow to reload. The pattern climbs at first, then settles into a gentle wander.
	pattern = PackedVector2Array()
	for i in 60:
		pattern.append(Vector2(0.08 * sin(i * 0.9), 0.4 if i < 5 else (0.22 if i < 15 else 0.1)))
	_save_res(WeaponData.new(), "res://weapons/negev.tres", {
		display_name = "Negev", model_scene = load("res://scenes/weapons/negev.tscn"), sound_prefix = "negev",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.0,
		fire_mode = 0, rpm = 780.0, damage = 13.0, head_multiplier = 2.0,
		falloff_start = 35.0, falloff_end = 80.0, falloff_min = 0.7,
		mag_size = 60, ammo_type = "heavy", reload_time = 4.4, reload_empty_time = 4.8, reload_commit = 0.65,
		draw_time = 1.1, quick_draw_time = 0.55, move_speed = 0.88, holster_time = 0.3, ads_time = 0.3, ads_zoom = 1.15, ads_move_speed = 0.45,
		sprint_to_fire_time = 0.3,
		hip_spread = 2.6, ads_spread = 0.0, move_spread = 1.8, air_spread = 3.0,
		bloom_per_shot = 0.06, bloom_max = 1.2, bloom_decay = 4.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.8, recoil_jitter = 0.06, recoil_recovery = 9.0,
		view_punch = 0.6,
		hip_position = HIP.negev, ads_position = Vector3(0.0, -0.066, -0.36),
		kick_back = 0.03, kick_rotation = 2.4, muzzle_flash_size = 1.15, throw_damage = 35.0,
	})

	# SSG-008: light bolt action, CS2 Scout style. Quick to handle and you move at rifle speed;
	# a headshot (2.5x) kills from full shield and health, a body shot doesn't. 10-round mag.
	_save_res(WeaponData.new(), "res://weapons/ssg.tres", {
		display_name = "SSG-008", model_scene = load("res://scenes/weapons/ssg.tscn"), sound_prefix = "ssg",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.0,
		fire_mode = 1, rpm = 48.0, damage = 88.0, head_multiplier = 2.5, cycle_after_shot = true, unscope_on_shot = true,
		falloff_start = 300.0, falloff_end = 400.0, falloff_min = 1.0,
		mag_size = 10, ammo_type = "sniper", reload_time = 2.7, reload_empty_time = 3.3, reload_commit = 0.7,
		draw_time = 0.7, quick_draw_time = 0.45, move_speed = 1.0, holster_time = 0.25, ads_time = 0.2, ads_zoom = 4.0, ads_move_speed = 0.6,
		sprint_to_fire_time = 0.2, scope_overlay = true,
		hip_spread = 4.0, ads_spread = 0.0, move_spread = 2.5, ads_move_spread = 2.0, air_spread = 4.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = PackedVector2Array([Vector2(0.15, 2.2)]), recoil_scale_ads = 0.7, recoil_jitter = 0.25, recoil_recovery = 14.0,
		view_punch = 2.0,
		hip_position = HIP.ssg, ads_position = Vector3(0.0, -0.062, -0.3),
		kick_back = 0.05, kick_rotation = 6.0, muzzle_flash_size = 1.3, throw_damage = 30.0,
	})

	# Knives: one is always carried (picked in Settings > Loadout). Fire = alternating slashes,
	# aim = heavy stab, V from a gun = quick slash. Same stats for all, like CS.
	for k: Array in [["knife", "Combat Knife"], ["knife_karambit", "Karambit"], ["knife_butterfly", "Butterfly Knife"],
			["knife_bayonet", "Bayonet"]]:
		_save_knife(WeaponData, k[0], k[1])
	for id: String in NEW_KNIVES:
		_save_knife(WeaponData, "knife_" + id, NEW_KNIVES[id])


func _save_knife(WeaponData: GDScript, id: String, title: String) -> void:
	_save_res(WeaponData.new(), "res://weapons/%s.tres" % id, {
		display_name = title, model_scene = load("res://scenes/weapons/%s.tscn" % id), sound_prefix = "",
		is_melee = true, bolt_node = ^"",
		mag_size = 0, draw_time = 0.4, quick_draw_time = 0.25, move_speed = 1.12, holster_time = 0.15, sprint_to_fire_time = 0.0,
		hip_position = HIP.knife, ads_position = HIP.knife,
		recoil_pattern = PackedVector2Array(),
		light_damage = 30.0, light_hit_time = 0.14, heavy_damage = 60.0, heavy_hit_time = 0.36,
		quick_hit_time = 0.18, melee_range = 2.0,
		alternate_draws = id == "knife_m9", # Only the M9 takes turns with its quick draw; the rest always flourish.
	})


func _save_res(r: Resource, path: String, values: Dictionary) -> void:
	for k: String in values:
		r.set(k, values[k])
	ResourceSaver.save(r, path)


# --- Models + animations ------------------------------------------------------------
# All boxes, in viewmodel space (metres, -Z = forward). The front-sight dot's
# height is what ads_position.y cancels out, so the dot sits on screen centre.

func _carbine() -> Node3D:
	var r := _rig("Carbine")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.06, 0.09, 0.32), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Handguard", Vector3(0.05, 0.065, 0.26), Vector3(0, 0.005, -0.29), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.025, 0.025, 0.14), Vector3(0, 0.015, -0.48), Vector3.ZERO, _mat.gun)
	_part(gun, "Magazine", Vector3(0.04, 0.15, 0.07), Vector3(0, -0.1, -0.07), Vector3(12, 0, 0), _mat.accent)
	_part(gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.1), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Stock", Vector3(0.045, 0.075, 0.13), Vector3(0, -0.01, 0.22), Vector3.ZERO, _mat.accent)
	_part(gun, "Bolt", Vector3(0.012, 0.014, 0.035), Vector3(0.036, 0.02, 0.04), Vector3.ZERO, _mat.accent)
	_part(gun, "RearSightBase", Vector3(0.03, 0.012, 0.04), Vector3(0, 0.051, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightL", Vector3(0.007, 0.022, 0.012), Vector3(-0.011, 0.068, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.007, 0.022, 0.012), Vector3(0.011, 0.068, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSight", Vector3(0.006, 0.0365, 0.012), Vector3(0, 0.056, -0.39), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.007, 0.007, 0.007), Vector3(0, 0.0775, -0.39), Vector3.ZERO, _mat.sight)
	_muzzle(gun, Vector3(0, 0.015, -0.56))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.12), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.13, 0.15), HIP.carbine)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.045, -0.19), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.07, -0.17), HIP.carbine)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.03, -0.03, 0.03)], [0.9, Vector3(-0.04, -0.04, 0.04)],
			[1.55, Vector3(-0.03, -0.02, 0.03)], [1.62, Vector3(-0.03, 0.0, 0.03)], [1.75, Vector3(-0.03, -0.03, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(12, 8, 28)], [0.9, Vector3(14, 10, 32)],
			[1.55, Vector3(10, 8, 26)], [1.62, Vector3(16, 8, 24)], [1.8, Vector3(12, 8, 28)]],
		"M.pos": [[0, Vector3.ZERO], [0.35, Vector3.ZERO], [0.55, Vector3(0, -0.06, 0.01)], [0.75, Vector3(0, -0.45, 0.08)],
			[1.1, Vector3(0, -0.4, 0.06)], [1.45, Vector3(0, -0.05, 0.01)], [1.6, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		"draw": _clip(0.85, {
			"P.pos": [[0, Vector3(0.12, -0.45, 0.15)], [0.3, Vector3(-0.015, 0.025, -0.02)], [0.42, Vector3(0, -0.01, 0.01)],
				[0.55, Vector3.ZERO], [0.62, Vector3(0, 0, 0.02)], [0.7, Vector3(0, 0, -0.005)], [0.85, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-70, 40, -90)], [0.3, Vector3(8, -6, -25)], [0.42, Vector3(-3, 2, 6)],
				[0.52, Vector3(-4, 0, -14)], [0.62, Vector3(2, 0, -16)], [0.72, Vector3(0, 0, -6)], [0.85, Vector3.ZERO]],
			"G.rot": [[0, Vector3(0, 0, -360)], [0.3, Vector3(0, 0, -20)], [0.42, Vector3(0, 0, 4)], [0.5, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.55, Vector3.ZERO], [0.6, Vector3(0, 0, 0.06)], [0.66, Vector3.ZERO]],
		}, [[0.6, "rack", -4.0]]),
		"inspect": _clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.06, 0.1)], [1.2, Vector3(-0.12, 0.06, 0.1)],
				[1.5, Vector3(-0.04, 0.03, 0.06)], [2.2, Vector3(-0.04, 0.03, 0.06)], [2.5, Vector3(0, 0.02, 0)],
				[2.75, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(15, 55, -30)], [1.2, Vector3(5, 60, -35)], [1.5, Vector3(-5, -20, 40)],
				[2.2, Vector3(-8, -25, 45)], [2.5, Vector3(10, 0, 0)], [2.75, Vector3(-2, 0, 0)], [3.2, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [2.3, Vector3.ZERO], [2.5, Vector3(0, 0.12, 0)], [2.7, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [2.3, Vector3.ZERO], [2.7, Vector3(0, 0, 360), "linear"]],
		}, [[0.4, "swap", -12.0], [2.3, "throw", -16.0], [2.7, "catch", -4.0]]),
		"reload": _clip(2.4, _with_end(reload_p, 2.4, {"P.pos": [2.1, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.1, Vector3(4, 2, 10)]}),
			[[0.45, "mag_out", -6.0], [1.6, "mag_in", -3.0]]),
		"reload_empty": _clip(3.1, _merge(reload_p, {
			"P.pos": [[2.05, Vector3(0, -0.01, 0.02)], [2.25, Vector3(0, 0, 0.04)], [2.4, Vector3.ZERO], [3.1, Vector3.ZERO]],
			"P.rot": [[2.05, Vector3(-4, 0, -16)], [2.25, Vector3(2, 0, -18)], [2.5, Vector3(0, 0, -6)], [3.1, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.2, Vector3(0, 0, 0.06)], [2.28, Vector3.ZERO]],
		}), [[0.45, "mag_out", -6.0], [1.6, "mag_in", -3.0], [2.2, "rack", -3.0]]),
		"melee_lower": _melee_lower(),
		"draw_quick": _quick_draw(0.4, []),
	}, "Pivot/Gun/Bolt")
	return r


func _smg() -> Node3D:
	var r := _rig("SMG")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.055, 0.08, 0.28), Vector3(0, 0, -0.02), Vector3.ZERO, _mat.gun)
	_part(gun, "Rail", Vector3(0.03, 0.01, 0.2), Vector3(0, 0.045, -0.03), Vector3.ZERO, _mat.gun)
	_part(gun, "Shroud", Vector3(0.04, 0.045, 0.12), Vector3(0, 0.01, -0.22), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.02, 0.02, 0.06), Vector3(0, 0.012, -0.31), Vector3.ZERO, _mat.gun)
	_part(gun, "Magazine", Vector3(0.035, 0.2, 0.045), Vector3(0, -0.13, -0.1), Vector3(5, 0, 0), _mat.accent)
	_part(gun, "Grip", Vector3(0.038, 0.1, 0.048), Vector3(0, -0.08, 0.08), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "StockRod", Vector3(0.012, 0.012, 0.16), Vector3(0, 0.02, 0.2), Vector3.ZERO, _mat.gun)
	_part(gun, "StockPad", Vector3(0.04, 0.08, 0.015), Vector3(0, -0.005, 0.28), Vector3.ZERO, _mat.accent)
	_part(gun, "Bolt", Vector3(0.012, 0.012, 0.03), Vector3(-0.033, 0.015, 0.0), Vector3.ZERO, _mat.accent)
	_part(gun, "RearSightL", Vector3(0.007, 0.028, 0.012), Vector3(-0.01, 0.064, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.007, 0.028, 0.012), Vector3(0.01, 0.064, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSight", Vector3(0.006, 0.022, 0.01), Vector3(0, 0.061, -0.15), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.007, 0.007, 0.007), Vector3(0, 0.0745, -0.15), Vector3.ZERO, _mat.sight)
	_muzzle(gun, Vector3(0, 0.012, -0.35))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.1, 0.09), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.12, 0.13), HIP.smg)
	_box(r, arms, "LeftHand", Vector3(0.07, 0.06, 0.09), Vector3(-0.02, -0.04, -0.2), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.04, -0.07, -0.18), HIP.smg)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.2, Vector3(-0.02, -0.02, 0.03)], [1.15, Vector3(-0.02, -0.03, 0.03)],
			[1.22, Vector3(-0.02, 0.0, 0.03)], [1.35, Vector3(-0.02, -0.02, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.2, Vector3(-8, 15, 30)], [0.7, Vector3(-10, 15, 34)], [1.15, Vector3(-6, 15, 30)],
			[1.22, Vector3(2, 15, 28)], [1.4, Vector3(-6, 12, 26)]],
		"M.pos": [[0, Vector3.ZERO], [0.25, Vector3.ZERO], [0.45, Vector3(0, -0.5, 0.05)], [0.75, Vector3(0, -0.45, 0.05)],
			[1.1, Vector3(0, -0.04, 0)], [1.2, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Hand brings it up, tosses it into a forward flip, catches it.
		"draw": _clip(0.75, {
			"P.pos": [[0, Vector3(0.05, -0.4, 0.1)], [0.18, Vector3(0, -0.06, 0.02)], [0.45, Vector3(0, -0.04, 0.01)],
				[0.5, Vector3(0, -0.07, 0.02)], [0.62, Vector3(0, 0.005, 0)], [0.75, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-60, -20, 40)], [0.18, Vector3(-10, 0, 8)], [0.45, Vector3(-6, 0, 4)],
				[0.5, Vector3(-12, 0, 6)], [0.62, Vector3(3, 0, -2)], [0.75, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.33, Vector3(0, 0.16, 0)], [0.48, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.48, Vector3(-360, 0, 0), "linear"]],
		}, [[0.18, "throw", -14.0], [0.48, "catch", -2.0]]),
		# Twirls on the trigger finger, then shows both sides.
		"inspect": _clip(2.8, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.04, 0.06)], [1.4, Vector3(-0.08, 0.04, 0.06)],
				[1.7, Vector3(-0.03, 0.05, 0.05)], [2.3, Vector3(-0.03, 0.05, 0.05)], [2.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 40, -20)], [1.4, Vector3(10, 40, -20)],
				[1.7, Vector3(-5, -30, 35)], [2.3, Vector3(-5, -30, 35)], [2.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [1.3, Vector3(0, 720, 0)]],
		}, [[0.6, "swap", -12.0], [1.3, "catch", -6.0]]),
		"reload": _clip(1.8, _with_end(reload_p, 1.8, {}), [[0.3, "mag_out", -6.0], [1.2, "mag_in", -3.0]]),
		"reload_empty": _clip(2.4, _merge(reload_p, {
			"P.pos": [[1.55, Vector3(0, -0.01, 0.02)], [1.75, Vector3(0, 0, 0.035)], [1.9, Vector3.ZERO], [2.4, Vector3.ZERO]],
			"P.rot": [[1.55, Vector3(-4, 0, 14)], [1.75, Vector3(2, 0, 16)], [2.0, Vector3(0, 0, 5)], [2.4, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [1.65, Vector3.ZERO], [1.75, Vector3(0, 0, 0.05)], [1.82, Vector3.ZERO]],
		}), [[0.3, "mag_out", -6.0], [1.2, "mag_in", -3.0], [1.75, "rack", -3.0]]),
		"melee_lower": _melee_lower(),
		"draw_quick": _quick_draw(0.35, []),
	}, "Pivot/Gun/Bolt")
	return r


func _sidearm() -> Node3D:
	var r := _rig("Sidearm")
	var gun := _gun(r, Vector3(0, -0.035, 0.0)) # Pivots at the trigger for twirls.
	var slide := _part(gun, "Slide", Vector3(0.036, 0.042, 0.2), Vector3(0, 0.02, -0.03), Vector3.ZERO, _mat.gun)
	# Sights ride on the slide, so they move with it.
	_box(r, slide, "RearSightL", Vector3(0.007, 0.014, 0.01), Vector3(-0.009, 0.028, 0.09), Vector3.ZERO, _mat.gun)
	_box(r, slide, "RearSightR", Vector3(0.007, 0.014, 0.01), Vector3(0.009, 0.028, 0.09), Vector3.ZERO, _mat.gun)
	_box(r, slide, "FrontSight", Vector3(0.006, 0.01, 0.01), Vector3(0, 0.026, -0.09), Vector3.ZERO, _mat.gun)
	_box(r, slide, "FrontSightDot", Vector3(0.007, 0.007, 0.007), Vector3(0, 0.0325, -0.09), Vector3.ZERO, _mat.sight)
	_part(gun, "Frame", Vector3(0.034, 0.03, 0.16), Vector3(0, -0.012, -0.02), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.018, 0.018, 0.03), Vector3(0, 0.02, -0.14), Vector3.ZERO, _mat.gun)
	_part(gun, "Grip", Vector3(0.034, 0.11, 0.048), Vector3(0, -0.075, 0.06), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Magazine", Vector3(0.026, 0.075, 0.036), Vector3(0, -0.157, 0.084), Vector3(-15, 0, 0), _mat.accent) # Extended: 20 rounds.
	_part(gun, "TriggerGuard", Vector3(0.008, 0.02, 0.04), Vector3(0, -0.035, 0.0), Vector3.ZERO, _mat.gun)
	_muzzle(gun, Vector3(0, 0.02, -0.16))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.07, 0.08, 0.08), Vector3(0.005, -0.075, 0.075), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.11, 0.11), HIP.sidearm)
	_box(r, arms, "LeftHand", Vector3(0.06, 0.075, 0.08), Vector3(-0.035, -0.08, 0.06), Vector3(-15, 0, 25), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.05, -0.1, 0.09), HIP.sidearm)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.25, Vector3(0, -0.02, 0.02)], [1.25, Vector3(0, -0.03, 0.02)],
			[1.32, Vector3(0, 0.01, 0.02)], [1.45, Vector3(0, -0.02, 0.02)]],
		"P.rot": [[0, Vector3.ZERO], [0.25, Vector3(20, 10, 25)], [1.25, Vector3(22, 10, 28)],
			[1.32, Vector3(28, 10, 24)], [1.5, Vector3(18, 8, 22)]],
		"M.pos": [[0, Vector3.ZERO], [0.3, Vector3.ZERO], [0.5, Vector3(0, -0.4, 0.1)], [0.9, Vector3(0, -0.35, 0.1)],
			[1.2, Vector3(0, -0.03, 0.01)], [1.3, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Revolver-style double twirl around the trigger finger, then racks the slide.
		"draw": _clip(0.65, {
			"P.pos": [[0, Vector3(0.05, -0.35, 0.05)], [0.2, Vector3(0, -0.02, 0)], [0.42, Vector3.ZERO],
				[0.5, Vector3(0, 0, 0.015)], [0.65, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-50, 10, 30)], [0.2, Vector3(-5, 0, 5)], [0.42, Vector3(3, 0, -4)],
				[0.5, Vector3(-4, 0, -10)], [0.65, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.08, Vector3.ZERO], [0.4, Vector3(720, 0, 0)]],
			"B.pos": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.5, Vector3(0, 0, 0.04)], [0.56, Vector3.ZERO]],
		}, [[0.5, "rack", -4.0]]),
		"inspect": _clip(2.6, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.06, 0.05, 0.08)], [1.0, Vector3(-0.06, 0.05, 0.08)],
				[1.3, Vector3(-0.03, 0.04, 0.06)], [2.0, Vector3(-0.03, 0.04, 0.06)], [2.6, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 35, -15)], [1.0, Vector3(10, 35, -15)],
				[1.3, Vector3(5, -35, 25)], [2.0, Vector3(5, -35, 25)], [2.6, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [1.4, Vector3.ZERO], [1.9, Vector3(1080, 0, 0)]],
		}, [[1.4, "swap", -12.0], [1.9, "catch", -6.0]]),
		"reload": _clip(2.1, _with_end(reload_p, 2.1, {}), [[0.35, "mag_out", -6.0], [1.3, "mag_in", -3.0]]),
		# Slide is locked back on empty, then slams home.
		"reload_empty": _clip(2.6, _merge(reload_p, {
			"P.pos": [[1.7, Vector3(0, -0.01, 0.01)], [1.8, Vector3(0, 0.01, 0.0)], [2.0, Vector3.ZERO], [2.6, Vector3.ZERO]],
			"P.rot": [[1.7, Vector3(10, 4, 10)], [1.8, Vector3(4, 0, 0)], [2.0, Vector3(-2, 0, 0)], [2.6, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.1, Vector3(0, 0, 0.04)], [1.75, Vector3(0, 0, 0.04)], [1.8, Vector3.ZERO]],
		}), [[0.35, "mag_out", -6.0], [1.3, "mag_in", -3.0], [1.8, "slide_home", -2.0]]),
		"melee_lower": _melee_lower(),
		"draw_quick": _quick_draw(0.28, []),
	}, "Pivot/Gun/Slide")
	return r


## Desert Eagle: steel slide on a black frame. Draw tosses it up spinning round the barrel and racks it.
func _deagle() -> Node3D:
	var r := _rig("DesertEagle")
	var gun := _gun(r, Vector3(0, -0.035, 0.0)) # Pivots at the trigger.
	var slide := _part(gun, "Slide", Vector3(0.04, 0.048, 0.24), Vector3(0, 0.022, -0.04), Vector3.ZERO, _mat.blade)
	_box(r, slide, "RearSightL", Vector3(0.007, 0.012, 0.01), Vector3(-0.01, 0.029, 0.105), Vector3.ZERO, _mat.gun)
	_box(r, slide, "RearSightR", Vector3(0.007, 0.012, 0.01), Vector3(0.01, 0.029, 0.105), Vector3.ZERO, _mat.gun)
	_box(r, slide, "FrontSight", Vector3(0.006, 0.01, 0.01), Vector3(0, 0.027, -0.1), Vector3.ZERO, _mat.gun)
	_box(r, slide, "FrontSightDot", Vector3(0.007, 0.007, 0.007), Vector3(0, 0.0305, -0.1), Vector3.ZERO, _mat.sight)
	_box(r, slide, "Ports", Vector3(0.041, 0.012, 0.06), Vector3(0, 0.006, -0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "Frame", Vector3(0.038, 0.03, 0.2), Vector3(0, -0.014, -0.03), Vector3.ZERO, _mat.gun)
	_part(gun, "Grip", Vector3(0.036, 0.12, 0.052), Vector3(0, -0.085, 0.065), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Magazine", Vector3(0.028, 0.03, 0.04), Vector3(0, -0.15, 0.085), Vector3(-15, 0, 0), _mat.accent)
	_part(gun, "TriggerGuard", Vector3(0.008, 0.024, 0.045), Vector3(0, -0.04, 0.0), Vector3.ZERO, _mat.gun)
	_muzzle(gun, Vector3(0, 0.022, -0.17))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.07, 0.085, 0.085), Vector3(0.005, -0.085, 0.08), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.12, 0.12), HIP.deagle)
	_box(r, arms, "LeftHand", Vector3(0.06, 0.075, 0.08), Vector3(-0.037, -0.09, 0.065), Vector3(-15, 0, 25), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.05, -0.11, 0.1), HIP.deagle)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.25, Vector3(0, -0.02, 0.02)], [1.25, Vector3(0, -0.03, 0.02)],
			[1.32, Vector3(0, 0.01, 0.02)], [1.45, Vector3(0, -0.02, 0.02)]],
		"P.rot": [[0, Vector3.ZERO], [0.25, Vector3(20, 10, 25)], [1.25, Vector3(22, 10, 28)],
			[1.32, Vector3(28, 10, 24)], [1.5, Vector3(18, 8, 22)]],
		"M.pos": [[0, Vector3.ZERO], [0.3, Vector3.ZERO], [0.5, Vector3(0, -0.4, 0.1)], [0.9, Vector3(0, -0.35, 0.1)],
			[1.2, Vector3(0, -0.03, 0.01)], [1.3, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Tossed up out of the hand spinning twice round the barrel, caught, slide racked.
		"draw": _clip(0.75, {
			"P.pos": [[0, Vector3(0.05, -0.38, 0.05)], [0.16, Vector3(0, -0.03, 0)], [0.48, Vector3(0, -0.02, 0)],
				[0.53, Vector3(0, -0.045, 0.01)], [0.62, Vector3(0, 0, 0.012)], [0.75, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-50, 10, 30)], [0.16, Vector3(-5, 0, 4)], [0.48, Vector3(-3, 0, 0)],
				[0.53, Vector3(-9, 0, 0)], [0.62, Vector3(-3, 0, -10)], [0.75, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [0.16, Vector3.ZERO], [0.32, Vector3(0, 0.13, 0)], [0.48, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.16, Vector3.ZERO], [0.48, Vector3(0, 0, 720), "linear"]],
			"B.pos": [[0, Vector3.ZERO], [0.58, Vector3.ZERO], [0.62, Vector3(0, 0, 0.045)], [0.68, Vector3.ZERO]],
		}, [[0.16, "throw", -14.0], [0.48, "catch", -2.0], [0.62, "rack", -4.0]]),
		"draw_quick": _quick_draw(0.3, []),
		# Shows the left side, twirls it once round the trigger finger, shows the right side.
		"inspect": _clip(2.8, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.06, 0.05, 0.08)], [1.0, Vector3(-0.06, 0.054, 0.08)],
				[1.3, Vector3(-0.03, 0.04, 0.06)], [2.2, Vector3(-0.03, 0.044, 0.06)], [2.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 40, -15)], [1.0, Vector3(8, 42, -18)],
				[1.3, Vector3(5, -35, 25)], [2.2, Vector3(3, -37, 27)], [2.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [1.45, Vector3.ZERO], [1.95, Vector3(360, 0, 0)]],
		}, [[0.3, "swap", -12.0], [1.45, "swap", -12.0], [1.95, "catch", -6.0]]),
		"reload": _clip(2.2, _with_end(reload_p, 2.2, {}), [[0.35, "mag_out", -6.0], [1.3, "mag_in", -3.0]]),
		# Slide locked back on empty, then slams home.
		"reload_empty": _clip(2.6, _merge(reload_p, {
			"P.pos": [[1.7, Vector3(0, -0.01, 0.01)], [1.8, Vector3(0, 0.01, 0.0)], [2.0, Vector3.ZERO], [2.6, Vector3.ZERO]],
			"P.rot": [[1.7, Vector3(10, 4, 10)], [1.8, Vector3(4, 0, 0)], [2.0, Vector3(-2, 0, 0)], [2.6, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.1, Vector3(0, 0, 0.045)], [1.75, Vector3(0, 0, 0.045)], [1.8, Vector3.ZERO]],
		}), [[0.35, "mag_out", -6.0], [1.3, "mag_in", -3.0], [1.8, "slide_home", -2.0]]),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Slide")
	return r


## R8 Revolver. The cylinder (on the Crane, which swings out to the left) turns a
## chamber as the hammer cocks; "prime" is the cock, "cycle" the hammer falling after the shot.
## The speedloader's rounds sit hidden inside the cylinder until a reload.
func _revolver() -> Node3D:
	var r := _rig("Revolver")
	var gun := _gun(r, Vector3(0, -0.035, 0.0)) # Pivots at the trigger.
	_part(gun, "Frame", Vector3(0.034, 0.05, 0.12), Vector3(0, 0.005, 0.0), Vector3.ZERO, _mat.gun)
	_part(gun, "Barrel", Vector3(0.022, 0.024, 0.15), Vector3(0, 0.03, -0.13), Vector3.ZERO, _mat.blade)
	_part(gun, "Rib", Vector3(0.012, 0.006, 0.15), Vector3(0, 0.045, -0.13), Vector3.ZERO, _mat.gun)
	_part(gun, "UnderLug", Vector3(0.016, 0.016, 0.11), Vector3(0, 0.01, -0.12), Vector3.ZERO, _mat.gun)
	_part(gun, "Grip", Vector3(0.032, 0.11, 0.05), Vector3(0, -0.07, 0.055), Vector3(-18, 0, 0), _mat.k_wood)
	_part(gun, "TriggerGuard", Vector3(0.008, 0.022, 0.04), Vector3(0, -0.03, -0.005), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightL", Vector3(0.005, 0.01, 0.01), Vector3(-0.008, 0.05, 0.045), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.005, 0.01, 0.01), Vector3(0.008, 0.05, 0.045), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.007, 0.007, 0.007), Vector3(0, 0.052, -0.195), Vector3.ZERO, _mat.sight)
	var hammer := _hinge(gun, "Hammer", Vector3(0, 0.03, 0.05))
	_box(r, hammer, "Mesh", Vector3(0.008, 0.024, 0.012), Vector3(0, 0.01, 0.004), Vector3.ZERO, _mat.gun)
	var crane := _hinge(gun, "Crane", Vector3(-0.014, 0.0, -0.03))
	# _hinge places relative to its parent's own position, so give the cylinder's spot from the crane's.
	var cyl := _hinge(crane, "Cylinder", crane.position + Vector3(0.014, 0.026, 0.0))
	_cylinder(r, cyl, "Mesh", 0.023, 0.052, Vector3.ZERO, _mat.blade)
	_box(r, cyl, "Speedloader", Vector3(0.026, 0.026, 0.03), Vector3.ZERO, Vector3.ZERO, _mat.k_gold)
	_muzzle(gun, Vector3(0, 0.03, -0.21))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.07, 0.085, 0.08), Vector3(0.005, -0.075, 0.075), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.11, 0.11), HIP.revolver)
	_box(r, arms, "LeftHand", Vector3(0.06, 0.075, 0.08), Vector3(-0.035, -0.08, 0.06), Vector3(-15, 0, 25), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.05, -0.1, 0.09), HIP.revolver)

	var reload := _clip(2.5, {
		# Muzzle up to dump the empties, then down to load, flick it shut.
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.03, 0.0, 0.03)], [0.85, Vector3(-0.03, 0.01, 0.03)],
			[1.15, Vector3(-0.03, -0.03, 0.03)], [1.75, Vector3(-0.03, -0.03, 0.03)], [1.95, Vector3(-0.01, -0.01, 0.01)], [2.5, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 10, 30)], [0.6, Vector3(40, 10, 30)], [0.85, Vector3(38, 10, 30)],
			[1.15, Vector3(-12, 10, 30)], [1.75, Vector3(-14, 10, 30)], [1.95, Vector3(4, 0, -12)], [2.2, Vector3(0, 0, 2)], [2.5, Vector3.ZERO]],
		"C.rot": [[0, Vector3.ZERO], [0.3, Vector3.ZERO], [0.45, Vector3(0, 0, 80)], [1.85, Vector3(0, 0, 80)], [1.95, Vector3.ZERO]],
		"S.pos": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [0.75, Vector3(0, 0, 0.12)], [0.9, Vector3(0, -0.3, 0.2)],
			[1.15, Vector3(0, -0.25, 0.2)], [1.45, Vector3(0, -0.04, 0.1)], [1.65, Vector3(0, 0, 0.03)], [1.72, Vector3.ZERO]],
	}, [[0.42, "mag_out", -8.0], [0.75, "mag_out", -10.0], [1.7, "mag_in", -3.0], [1.95, "slide_home", -3.0]])
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Comes up with a twirl round the trigger finger while the cylinder spins, thumbs the hammer.
		"draw": _clip(0.8, {
			"P.pos": [[0, Vector3(0.05, -0.35, 0.05)], [0.2, Vector3(0, -0.02, 0)], [0.48, Vector3.ZERO],
				[0.56, Vector3(0, 0, 0.012)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-50, 10, 30)], [0.2, Vector3(-5, 0, 5)], [0.48, Vector3(3, 0, -4)],
				[0.56, Vector3(-5, 0, -8)], [0.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.08, Vector3.ZERO], [0.45, Vector3(720, 0, 0)]],
			"Y.rot": [[0, Vector3.ZERO], [0.1, Vector3.ZERO], [0.6, Vector3(0, 0, 720)]],
			"H.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [0.58, Vector3(-45, 0, 0)], [0.66, Vector3(-45, 0, 0)], [0.72, Vector3.ZERO]],
		}, [[0.45, "catch", -4.0], [0.58, "hammer", -6.0]]),
		"draw_quick": _quick_draw(0.3, []),
		# Swings the cylinder out, spins it, snaps it shut with a flick of the wrist.
		"inspect": _clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.06, 0.05, 0.08)], [1.9, Vector3(-0.06, 0.055, 0.08)],
				[2.1, Vector3(-0.04, 0.04, 0.06)], [2.5, Vector3(-0.04, 0.044, 0.06)], [3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 35, -20)], [1.9, Vector3(8, 37, -22)],
				[2.1, Vector3(-5, -10, 40)], [2.15, Vector3(0, -12, 30)], [2.5, Vector3(2, -30, 25)], [3.0, Vector3.ZERO]],
			"C.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [0.65, Vector3(0, 0, 80)], [2.0, Vector3(0, 0, 80)], [2.1, Vector3.ZERO]],
			"Y.rot": [[0, Vector3.ZERO], [0.8, Vector3.ZERO], [1.7, Vector3(0, 0, 1080)]],
		}, [[0.6, "mag_out", -10.0], [0.8, "knife_swing", -16.0], [2.1, "slide_home", -3.0]]),
		# Hold-to-fire: hammer comes back while the cylinder turns a chamber (stretched to prime_time).
		"prime": _clip(0.32, {
			"H.rot": [[0, Vector3.ZERO], [0.32, Vector3(-45, 0, 0)]],
			"Y.rot": [[0, Vector3.ZERO], [0.3, Vector3(0, 0, 60)]],
		}),
		# The hammer falls.
		"cycle": _clip(0.2, {
			"H.rot": [[0, Vector3(-45, 0, 0)], [0.04, Vector3.ZERO]],
		}),
		"reload": reload,
		"reload_empty": reload.duplicate(true),
		"melee_lower": _melee_lower(),
	}, "", {"H": "Pivot/Gun/Hammer", "C": "Pivot/Gun/Crane", "Y": "Pivot/Gun/Crane/Cylinder", "S": "Pivot/Gun/Crane/Cylinder/Speedloader"})
	return r


## Cylinder along Z (a revolver cylinder, a pommel...). 12 sides, so a 60 degree turn looks the same.
func _cylinder(r: Node, parent: Node3D, n: String, radius: float, length: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	mi.owner = r


## Breacher, after Titanfall's Mastiff: a chunky slab-sided pump gun. A tall boxy receiver,
## a long squared shroud over the barrels with vents down its sides and a wide, flat muzzle
## with a horizontal slot (it throws its pellets in a flat line), a rail and squared sight on
## top, an angular stock. The left hand rides the pump under the shroud (LeftArm) and palms
## a shell (Shell) for the one-at-a-time reload: reload_start rolls it over, reload_shell
## loads one, reload_end rolls back.
func _shotgun() -> Node3D:
	var r := _rig("Shotgun")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.062, 0.1, 0.26), Vector3(0, 0.005, 0), Vector3.ZERO, _mat.gun)
	_part(gun, "Shroud", Vector3(0.066, 0.06, 0.42), Vector3(0, 0.03, -0.33), Vector3.ZERO, _mat.accent)
	_part(gun, "ShroudStripe", Vector3(0.067, 0.008, 0.3), Vector3(0, 0.061, -0.3), Vector3.ZERO, _mat.k_orange)
	for z: float in [-0.24, -0.31, -0.38, -0.45]:
		_part(gun, "Vent", Vector3(0.068, 0.012, 0.045), Vector3(0, 0.03, z), Vector3.ZERO, _mat.gun)
	_part(gun, "MuzzleFace", Vector3(0.074, 0.05, 0.025), Vector3(0, 0.03, -0.548), Vector3.ZERO, _mat.gun)
	_part(gun, "MuzzleSlot", Vector3(0.056, 0.01, 0.027), Vector3(0, 0.03, -0.549), Vector3.ZERO, _mat.k_black)
	_part(gun, "Tube", Vector3(0.032, 0.03, 0.3), Vector3(0, -0.03, -0.3), Vector3.ZERO, _mat.gun)
	_part(gun, "Pump", Vector3(0.062, 0.05, 0.14), Vector3(0, -0.03, -0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "Rail", Vector3(0.018, 0.01, 0.24), Vector3(0, 0.06, -0.02), Vector3.ZERO, _mat.gun)
	_part(gun, "SightHoodL", Vector3(0.005, 0.022, 0.03), Vector3(-0.012, 0.075, 0.07), Vector3.ZERO, _mat.gun)
	_part(gun, "SightHoodR", Vector3(0.005, 0.022, 0.03), Vector3(0.012, 0.075, 0.07), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightL", Vector3(0.004, 0.01, 0.008), Vector3(-0.008, 0.07, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.004, 0.01, 0.008), Vector3(0.008, 0.07, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.008, 0.008, 0.008), Vector3(0, 0.066, -0.5), Vector3.ZERO, _mat.sight)
	_part(gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.1), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "StockTop", Vector3(0.05, 0.05, 0.2), Vector3(0, 0.0, 0.24), Vector3.ZERO, _mat.accent)
	_part(gun, "StockBrace", Vector3(0.04, 0.03, 0.16), Vector3(0, -0.07, 0.25), Vector3(-10, 0, 0), _mat.accent)
	_part(gun, "ButtPlate", Vector3(0.056, 0.12, 0.03), Vector3(0, -0.025, 0.345), Vector3.ZERO, _mat.gun)
	_muzzle(gun, Vector3(0, 0.03, -0.57))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.1, 0.13), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.12, 0.16), HIP.shotgun)
	var left := _hinge(arms, "LeftArm", Vector3.ZERO)
	_box(r, left, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.05, -0.27), Vector3(0, 0, -20), _mat.glove)
	_arm(r, left, "Left", Vector3(-0.03, -0.075, -0.25), HIP.shotgun)
	# Hidden inside the glove until a reload pops it up between the fingers.
	_box(r, left, "Shell", Vector3(0.02, 0.02, 0.055), Vector3(-0.005, -0.05, -0.27), Vector3.ZERO, _mat.k_red)

	var pump := {"B.pos": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.3, Vector3(0, 0, 0.09)], [0.44, Vector3.ZERO]],
		"L.pos": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.3, Vector3(0, 0, 0.09)], [0.44, Vector3.ZERO]]}
	var load_pose_pos := Vector3(-0.02, 0.01, 0.03)
	var load_pose_rot := Vector3(6, -8, -32) # Rolled right over, loading port towards the left hand.
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Comes up one-handed, racks the pump with a snap.
		"draw": _clip(0.8, _merge({
			"P.pos": [[0, Vector3(0.1, -0.4, 0.12)], [0.3, Vector3(0, -0.01, 0)], [0.42, Vector3.ZERO], [0.5, Vector3(0, 0, 0.015)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-50, 25, -50)], [0.3, Vector3(5, -3, -6)], [0.42, Vector3.ZERO], [0.52, Vector3(-4, 0, 6)], [0.8, Vector3.ZERO]],
		}, _shift(pump, 0.22)), [[0.49, "slide_back", -4.0], [0.64, "slide_home", -3.0]]),
		"draw_quick": _quick_draw(0.4, []),
		# Turns it to show the side, pumps it once, then the other side.
		"inspect": _clip(3.0, _merge({
			"P.pos": [[0, Vector3.ZERO], [0.35, Vector3(-0.1, 0.05, 0.08)], [1.3, Vector3(-0.1, 0.055, 0.08)],
				[1.65, Vector3(-0.04, 0.04, 0.06)], [2.5, Vector3(-0.04, 0.045, 0.06)], [3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(12, 50, -25)], [1.3, Vector3(8, 54, -28)],
				[1.65, Vector3(-5, -22, 38)], [2.5, Vector3(-7, -25, 40)], [3.0, Vector3.ZERO]],
		}, _shift(pump, 0.7)), [[0.35, "swap", -12.0], [0.97, "slide_back", -7.0], [1.12, "slide_home", -6.0]]),
		# Pump after every shot.
		"cycle": _clip(0.8, _merge({
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(0, -0.005, 0.012)], [0.44, Vector3(0, 0, -0.006)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(-3, 0, 7)], [0.44, Vector3(1, 0, 2)], [0.8, Vector3.ZERO]],
		}, pump), [[0.27, "slide_back", -4.0], [0.42, "slide_home", -3.0]]),
		"reload_start": _clip(0.4, {
			"P.pos": [[0, Vector3.ZERO], [0.4, load_pose_pos]],
			"P.rot": [[0, Vector3.ZERO], [0.4, load_pose_rot]],
		}),
		# Hand drops to grab a shell, thumbs it into the port, back to the pump.
		"reload_shell": _clip(0.5, {
			"P.pos": [[0, load_pose_pos], [0.34, load_pose_pos], [0.38, load_pose_pos + Vector3(0, 0.008, 0.004)], [0.5, load_pose_pos]],
			"P.rot": [[0, load_pose_rot], [0.34, load_pose_rot], [0.38, load_pose_rot + Vector3(3, 0, -2)], [0.5, load_pose_rot]],
			"L.pos": [[0, Vector3.ZERO], [0.14, Vector3(0.02, -0.17, 0.16)], [0.3, Vector3(0.0, -0.05, 0.25)],
				[0.36, Vector3(0, -0.022, 0.26)], [0.5, Vector3.ZERO]],
			"L.rot": [[0, Vector3.ZERO], [0.14, Vector3(-30, 0, 20)], [0.3, Vector3(-10, 0, 10)], [0.5, Vector3.ZERO]],
			"S.pos": [[0, Vector3.ZERO], [0.12, Vector3.ZERO], [0.17, Vector3(0, 0.045, 0)], [0.33, Vector3(0, 0.045, 0)], [0.37, Vector3.ZERO]],
		}, [[0.12, "mag_out", -14.0], [0.36, "mag_in", -4.0]]),
		"reload_end": _clip(0.42, {
			"P.pos": [[0, load_pose_pos], [0.3, Vector3(0, 0, -0.005)], [0.42, Vector3.ZERO]],
			"P.rot": [[0, load_pose_rot], [0.3, Vector3(1, 0, 3)], [0.42, Vector3.ZERO]],
		}),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Pump", {"L": "Pivot/Arms/LeftArm", "S": "Pivot/Arms/LeftArm/Shell"})
	return r


## Olympia: over-under double barrel. The barrels (with the forend and the two shells in
## the breech) hinge down at the front of the receiver to break it open.
func _olympia() -> Node3D:
	var r := _rig("Olympia")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.05, 0.07, 0.12), Vector3(0, -0.005, 0.02), Vector3.ZERO, _mat.blade)
	_part(gun, "TopLever", Vector3(0.012, 0.008, 0.03), Vector3(0, 0.034, 0.07), Vector3.ZERO, _mat.gun)
	_part(gun, "TriggerGuard", Vector3(0.008, 0.022, 0.045), Vector3(0, -0.05, 0.05), Vector3.ZERO, _mat.gun)
	_part(gun, "Grip", Vector3(0.038, 0.1, 0.05), Vector3(0, -0.075, 0.11), Vector3(-18, 0, 0), _mat.k_wood)
	_part(gun, "Stock", Vector3(0.045, 0.085, 0.24), Vector3(0, -0.035, 0.24), Vector3(-8, 0, 0), _mat.k_wood)
	_part(gun, "ButtPad", Vector3(0.047, 0.09, 0.015), Vector3(0, -0.05, 0.36), Vector3(-8, 0, 0), _mat.gun)
	_muzzle(gun, Vector3(0, 0.025, -0.57))
	var barrels := _hinge(gun, "Barrels", Vector3(0, -0.035, -0.04))
	var local := func(p: Vector3) -> Vector3: return p - Vector3(0, -0.035, -0.04) # Rig space -> barrel hinge space.
	_box(r, barrels, "BarrelTop", Vector3(0.026, 0.026, 0.5), local.call(Vector3(0, 0.025, -0.3)), Vector3.ZERO, _mat.gun)
	_box(r, barrels, "BarrelBottom", Vector3(0.026, 0.026, 0.5), local.call(Vector3(0, -0.003, -0.3)), Vector3.ZERO, _mat.gun)
	_box(r, barrels, "Rib", Vector3(0.008, 0.004, 0.5), local.call(Vector3(0, 0.04, -0.3)), Vector3.ZERO, _mat.gun)
	_box(r, barrels, "Monoblock", Vector3(0.03, 0.058, 0.04), local.call(Vector3(0, 0.011, -0.07)), Vector3.ZERO, _mat.blade)
	_box(r, barrels, "Forend", Vector3(0.04, 0.03, 0.2), local.call(Vector3(0, -0.028, -0.18)), Vector3.ZERO, _mat.k_wood)
	_box(r, barrels, "FrontSightDot", Vector3(0.006, 0.006, 0.006), local.call(Vector3(0, 0.045, -0.54)), Vector3.ZERO, _mat.sight)
	var shells := _hinge(barrels, "Shells", barrels.position + local.call(Vector3(0, 0.011, -0.07)))
	_box(r, shells, "ShellTop", Vector3(0.02, 0.02, 0.05), Vector3(0, 0.014, 0.0), Vector3.ZERO, _mat.k_red)
	_box(r, shells, "ShellBottom", Vector3(0.02, 0.02, 0.05), Vector3(0, -0.014, 0.0), Vector3.ZERO, _mat.k_red)
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.1, 0.13), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.12, 0.16), HIP.olympia)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.06, -0.18), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.085, -0.16), HIP.olympia)

	var broken := Vector3(-38, 0, 0) # Barrels hinged down, breech open.
	var reload := _clip(2.0, {
		"P.pos": [[0, Vector3.ZERO], [0.25, Vector3(-0.02, 0.0, 0.03)], [1.3, Vector3(-0.02, -0.01, 0.03)],
			[1.45, Vector3(-0.02, 0.012, 0.02)], [1.6, Vector3(0, -0.005, 0.01)], [2.0, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.25, Vector3(14, 10, 22)], [0.5, Vector3(26, 10, 22)], [0.6, Vector3(18, 10, 22)],
			[1.3, Vector3(10, 10, 22)], [1.45, Vector3(26, 4, 10)], [1.6, Vector3(-4, 0, -2)], [2.0, Vector3.ZERO]],
		"K.rot": [[0, Vector3.ZERO], [0.25, Vector3.ZERO], [0.4, broken], [1.4, broken], [1.48, Vector3.ZERO, "linear"]],
		# Spent shells flip out the back, fresh ones come up from below and drop in.
		"S.pos": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.55, Vector3(0, 0.07, 0.14)], [0.75, Vector3(0, -0.3, 0.2)],
			[0.95, Vector3(0, -0.25, 0.12)], [1.15, Vector3(0, -0.05, 0.06)], [1.25, Vector3.ZERO]],
		"S.rot": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.75, Vector3(200, 0, 0)], [0.95, Vector3(30, 0, 0)], [1.2, Vector3.ZERO]],
	}, [[0.38, "mag_out", -6.0], [0.55, "catch", -12.0], [1.25, "mag_in", -4.0], [1.48, "slide_home", -2.0]])
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Comes up broken open and a flick of the wrist snaps it shut.
		"draw": _clip(0.8, {
			"P.pos": [[0, Vector3(0.1, -0.4, 0.12)], [0.28, Vector3(0, -0.02, 0.01)], [0.4, Vector3(0, 0.015, -0.01)],
				[0.5, Vector3(0, -0.005, 0.005)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-50, 25, -50)], [0.28, Vector3(-6, -3, -6)], [0.4, Vector3(22, 0, 4)], [0.52, Vector3(-4, 0, 0)],
				[0.8, Vector3.ZERO]],
			"K.rot": [[0, broken], [0.33, broken], [0.42, Vector3.ZERO, "linear"]],
		}, [[0.0, "swap", -10.0], [0.42, "slide_home", -2.0]]),
		"draw_quick": _quick_draw(0.35, []),
		# Breaks it to look down the breech, snaps it shut, shows the other side.
		"inspect": _clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.35, Vector3(-0.08, 0.05, 0.08)], [1.6, Vector3(-0.08, 0.06, 0.07)],
				[1.95, Vector3(-0.06, 0.07, 0.06)], [2.05, Vector3(-0.06, 0.05, 0.06)], [2.6, Vector3(-0.04, 0.045, 0.06)],
				[3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(10, 45, -20)], [0.8, Vector3(30, 40, -10)], [1.6, Vector3(34, 38, -12)],
				[1.95, Vector3(36, 30, -10)], [2.05, Vector3(4, 0, 10)], [2.3, Vector3(-4, -30, 34)], [2.6, Vector3(-6, -32, 36)],
				[3.0, Vector3.ZERO]],
			"K.rot": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [0.8, broken], [1.95, broken], [2.03, Vector3.ZERO, "linear"]],
		}, [[0.35, "swap", -12.0], [0.75, "mag_out", -8.0], [2.03, "slide_home", -2.0]]),
		"reload": reload,
		"reload_empty": reload.duplicate(true),
		"melee_lower": _melee_lower(),
	}, "", {"K": "Pivot/Gun/Barrels", "S": "Pivot/Gun/Barrels/Shells"})
	return r


## Semi-auto marksman rifle with an open holo optic (a frame and a dot, so it doesn't block the view).
func _dmr() -> Node3D:
	var r := _rig("DMR")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.06, 0.09, 0.34), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Handguard", Vector3(0.052, 0.07, 0.3), Vector3(0, 0.005, -0.32), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.025, 0.025, 0.16), Vector3(0, 0.015, -0.54), Vector3.ZERO, _mat.gun)
	_part(gun, "MuzzleBrake", Vector3(0.036, 0.03, 0.045), Vector3(0, 0.015, -0.63), Vector3.ZERO, _mat.accent)
	_part(gun, "Magazine", Vector3(0.04, 0.11, 0.08), Vector3(0, -0.09, -0.06), Vector3(8, 0, 0), _mat.accent)
	_part(gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.11), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Stock", Vector3(0.05, 0.09, 0.2), Vector3(0, -0.015, 0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "Cheek", Vector3(0.04, 0.025, 0.12), Vector3(0, 0.04, 0.27), Vector3.ZERO, _mat.gun)
	_part(gun, "Bolt", Vector3(0.012, 0.014, 0.035), Vector3(0.036, 0.02, 0.05), Vector3.ZERO, _mat.accent)
	# Optic: low housing on the rail, a front window frame, and the dot floating in it.
	_part(gun, "OpticBase", Vector3(0.064, 0.012, 0.2), Vector3(0, 0.05, -0.03), Vector3.ZERO, _mat.gun)
	_part(gun, "OpticPostL", Vector3(0.008, 0.02, 0.012), Vector3(-0.0265, 0.054, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "OpticPostR", Vector3(0.008, 0.02, 0.012), Vector3(0.0265, 0.054, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "FrameTop", Vector3(0.058, 0.005, 0.01), Vector3(0, 0.1155, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "FrameBottom", Vector3(0.058, 0.005, 0.01), Vector3(0, 0.0605, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "FrameL", Vector3(0.005, 0.06, 0.01), Vector3(-0.0265, 0.088, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "FrameR", Vector3(0.005, 0.06, 0.01), Vector3(0.0265, 0.088, -0.11), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.004, 0.004, 0.004), Vector3(0, 0.088, -0.11), Vector3.ZERO, _mat.sight)
	_part(gun, "ReticlePost", Vector3(0.0015, 0.016, 0.002), Vector3(0, 0.0755, -0.11), Vector3.ZERO, _mat.sight)
	_muzzle(gun, Vector3(0, 0.015, -0.66))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.13), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.13, 0.16), HIP.dmr)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.05, -0.22), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.075, -0.2), HIP.dmr)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.03, -0.03, 0.03)], [0.95, Vector3(-0.04, -0.04, 0.04)],
			[1.6, Vector3(-0.03, -0.02, 0.03)], [1.67, Vector3(-0.03, 0.0, 0.03)], [1.8, Vector3(-0.03, -0.03, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(12, 8, 28)], [0.95, Vector3(14, 10, 32)],
			[1.6, Vector3(10, 8, 26)], [1.67, Vector3(16, 8, 24)], [1.85, Vector3(12, 8, 28)]],
		"M.pos": [[0, Vector3.ZERO], [0.35, Vector3.ZERO], [0.55, Vector3(0, -0.06, 0.01)], [0.75, Vector3(0, -0.45, 0.08)],
			[1.15, Vector3(0, -0.4, 0.06)], [1.5, Vector3(0, -0.05, 0.01)], [1.65, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Swings up from the hip, tilts to check the optic, racks the charging handle.
		"draw": _clip(0.9, {
			"P.pos": [[0, Vector3(0.12, -0.45, 0.15)], [0.32, Vector3(-0.015, 0.02, -0.02)], [0.45, Vector3(0, 0, 0.01)],
				[0.58, Vector3(0, 0, 0.02)], [0.68, Vector3(0, 0, -0.005)], [0.9, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-60, 35, -70)], [0.32, Vector3(6, -14, 18)], [0.45, Vector3(-3, 2, 4)],
				[0.56, Vector3(-4, 0, -14)], [0.66, Vector3(2, 0, -16)], [0.76, Vector3(0, 0, -6)], [0.9, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.58, Vector3.ZERO], [0.63, Vector3(0, 0, 0.06)], [0.69, Vector3.ZERO]],
		}, [[0.63, "rack", -4.0]]),
		"draw_quick": _quick_draw(0.42, []),
		# Peers down the optic from the side, then shows the ejection port side and taps the mag.
		"inspect": _clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.05, 0.1)], [1.3, Vector3(-0.12, 0.055, 0.1)],
				[1.6, Vector3(-0.04, 0.03, 0.06)], [2.2, Vector3(-0.04, 0.034, 0.06)], [2.3, Vector3(-0.04, 0.042, 0.06)],
				[2.4, Vector3(-0.04, 0.03, 0.06)], [2.75, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(12, 60, -20)], [1.3, Vector3(8, 62, -24)], [1.6, Vector3(-5, -22, 42)],
				[2.2, Vector3(-8, -25, 45)], [2.3, Vector3(-4, -24, 44)], [2.75, Vector3(-2, 0, 0)], [3.2, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [2.3, "mag_in", -8.0]]),
		"reload": _clip(2.5, _with_end(reload_p, 2.5, {"P.pos": [2.15, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.15, Vector3(4, 2, 10)]}),
			[[0.45, "mag_out", -6.0], [1.65, "mag_in", -3.0]]),
		"reload_empty": _clip(3.2, _merge(reload_p, {
			"P.pos": [[2.1, Vector3(0, -0.01, 0.02)], [2.3, Vector3(0, 0, 0.04)], [2.45, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[2.1, Vector3(-4, 0, -16)], [2.3, Vector3(2, 0, -18)], [2.55, Vector3(0, 0, -6)], [3.2, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [2.15, Vector3.ZERO], [2.25, Vector3(0, 0, 0.06)], [2.33, Vector3.ZERO]],
		}), [[0.45, "mag_out", -6.0], [1.65, "mag_in", -3.0], [2.25, "rack", -3.0]]),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Bolt")
	return r


## Negev: a light machine gun. A long receiver with a carry handle on top, a vented shroud
## round the barrel with a folded bipod under it, a 60-round box mag hung underneath, a
## pistol grip and a skeleton stock. The charging handle (Bolt) runs along the right side.
func _negev() -> Node3D:
	var r := _rig("Negev")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.064, 0.09, 0.36), Vector3(0, 0, -0.02), Vector3.ZERO, _mat.gun)
	_part(gun, "FeedCover", Vector3(0.066, 0.02, 0.2), Vector3(0, 0.055, -0.02), Vector3.ZERO, _mat.accent)
	_part(gun, "CarryHandle", Vector3(0.018, 0.012, 0.14), Vector3(0, 0.095, -0.04), Vector3.ZERO, _mat.gun)
	for z: float in [-0.1, 0.02]:
		_part(gun, "HandlePost", Vector3(0.016, 0.035, 0.014), Vector3(0, 0.075, z), Vector3.ZERO, _mat.gun)
	_part(gun, "Shroud", Vector3(0.05, 0.05, 0.3), Vector3(0, 0.008, -0.35), Vector3.ZERO, _mat.accent)
	for z: float in [-0.27, -0.33, -0.39, -0.45]:
		_part(gun, "ShroudVent", Vector3(0.052, 0.012, 0.03), Vector3(0, 0.02, z), Vector3.ZERO, _mat.gun)
	_part(gun, "Barrel", Vector3(0.022, 0.022, 0.16), Vector3(0, 0.008, -0.57), Vector3.ZERO, _mat.gun)
	_part(gun, "FlashHider", Vector3(0.032, 0.032, 0.05), Vector3(0, 0.008, -0.67), Vector3.ZERO, _mat.gun)
	_part(gun, "BipodL", Vector3(0.012, 0.012, 0.22), Vector3(-0.015, -0.03, -0.36), Vector3(0, 0, 0), _mat.gun)
	_part(gun, "BipodR", Vector3(0.012, 0.012, 0.22), Vector3(0.015, -0.03, -0.36), Vector3(0, 0, 0), _mat.gun)
	_part(gun, "FrontSightPost", Vector3(0.012, 0.05, 0.014), Vector3(0, 0.04, -0.5), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.006, 0.006, 0.006), Vector3(0, 0.066, -0.5), Vector3.ZERO, _mat.sight)
	_part(gun, "RearSightL", Vector3(0.007, 0.022, 0.012), Vector3(-0.011, 0.065, 0.12), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.007, 0.022, 0.012), Vector3(0.011, 0.065, 0.12), Vector3.ZERO, _mat.gun)
	_part(gun, "Magazine", Vector3(0.07, 0.11, 0.1), Vector3(0, -0.1, -0.08), Vector3.ZERO, _mat.k_olive)
	_part(gun, "Grip", Vector3(0.038, 0.1, 0.048), Vector3(0, -0.085, 0.12), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "StockTop", Vector3(0.04, 0.03, 0.22), Vector3(0, 0.0, 0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "StockBottom", Vector3(0.036, 0.022, 0.16), Vector3(0, -0.07, 0.29), Vector3(-8, 0, 0), _mat.accent)
	_part(gun, "ButtPlate", Vector3(0.05, 0.11, 0.025), Vector3(0, -0.03, 0.385), Vector3.ZERO, _mat.gun)
	_part(gun, "Bolt", Vector3(0.016, 0.016, 0.03), Vector3(0.04, 0.02, 0.0), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.008, -0.7))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.115, 0.13), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.135, 0.16), HIP.negev)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.03, -0.32), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.055, -0.3), HIP.negev)
	_animate(r, _rifle_clips(4.4, 4.8, 0.06,
		# Heaved up, a turn to show the side, then the charging handle racked back.
		_clip(1.1, {
			"P.pos": [[0, Vector3(0.12, -0.5, 0.15)], [0.4, Vector3(-0.01, 0.01, -0.01)], [0.55, Vector3(0, 0, 0.01)],
				[0.75, Vector3(0, -0.006, 0.025)], [0.85, Vector3(0, 0, -0.005)], [1.1, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-60, 35, -70)], [0.4, Vector3(5, -8, 18)], [0.55, Vector3(-2, 2, 6)],
				[0.75, Vector3(-6, 0, -10)], [0.85, Vector3(2, 0, -12)], [0.95, Vector3(0, 0, -4)], [1.1, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.75, Vector3.ZERO], [0.8, Vector3(0, 0, 0.09)], [0.86, Vector3.ZERO]],
		}, [[0.8, "slide_back", -5.0], [0.86, "slide_home", -4.0]]),
		# Rests it on the forearm to look down the side, then flips the feed cover a look.
		_clip(3.4, {
			"P.pos": [[0, Vector3.ZERO], [0.45, Vector3(-0.12, 0.05, 0.1)], [1.4, Vector3(-0.12, 0.056, 0.1)],
				[1.7, Vector3(-0.04, 0.03, 0.06)], [2.6, Vector3(-0.04, 0.034, 0.06)], [3.0, Vector3.ZERO], [3.4, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.45, Vector3(12, 55, -26)], [1.4, Vector3(9, 60, -30)], [1.7, Vector3(-6, -24, 42)],
				[2.6, Vector3(-8, -26, 44)], [3.0, Vector3(-2, 0, 0)], [3.4, Vector3.ZERO]],
		}, [[0.45, "swap", -12.0], [1.7, "swap", -14.0]])),
	"Pivot/Gun/Bolt")
	return r


## M4A4: flat-top rail, A2 front sight post, quad-rail handguard, collapsible stock, and the
## T charging handle at the back of the rail (Bolt).
func _m4() -> Node3D:
	var r := _rig("M4A4")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.058, 0.08, 0.3), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Rail", Vector3(0.03, 0.012, 0.28), Vector3(0, 0.046, -0.02), Vector3.ZERO, _mat.gun)
	_part(gun, "Handguard", Vector3(0.055, 0.06, 0.24), Vector3(0, 0.0, -0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.022, 0.022, 0.14), Vector3(0, 0.012, -0.46), Vector3.ZERO, _mat.gun)
	_part(gun, "FlashHider", Vector3(0.03, 0.03, 0.05), Vector3(0, 0.012, -0.55), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightPost", Vector3(0.012, 0.05, 0.014), Vector3(0, 0.035, -0.37), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.006, 0.006, 0.006), Vector3(0, 0.064, -0.37), Vector3.ZERO, _mat.sight)
	_part(gun, "RearSightL", Vector3(0.007, 0.022, 0.012), Vector3(-0.011, 0.063, 0.1), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.007, 0.022, 0.012), Vector3(0.011, 0.063, 0.1), Vector3.ZERO, _mat.gun)
	_part(gun, "Magazine", Vector3(0.035, 0.15, 0.07), Vector3(0, -0.1, -0.07), Vector3(8, 0, 0), _mat.accent)
	_part(gun, "Grip", Vector3(0.038, 0.1, 0.048), Vector3(0, -0.08, 0.11), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "BufferTube", Vector3(0.03, 0.03, 0.12), Vector3(0, 0.0, 0.2), Vector3.ZERO, _mat.gun)
	_part(gun, "Stock", Vector3(0.045, 0.07, 0.1), Vector3(0, -0.012, 0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "Bolt", Vector3(0.03, 0.008, 0.02), Vector3(0, 0.044, 0.13), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.012, -0.58))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.12), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.13, 0.15), HIP.m4)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.045, -0.22), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.07, -0.2), HIP.m4)
	_animate(r, _rifle_clips(3.1, 3.1, 0.06,
		# Swings up, rolls it to look at the side, then a sharp pull on the charging handle.
		_clip(0.95, {
			"P.pos": [[0, Vector3(0.12, -0.45, 0.15)], [0.3, Vector3(-0.01, 0.015, -0.015)], [0.45, Vector3(0, 0, 0.01)],
				[0.62, Vector3(0, -0.005, 0.025)], [0.72, Vector3(0, 0, -0.005)], [0.95, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-65, 40, -80)], [0.3, Vector3(6, -10, 22)], [0.45, Vector3(-2, 2, 8)],
				[0.6, Vector3(-6, 0, -10)], [0.7, Vector3(2, 0, -12)], [0.8, Vector3(0, 0, -4)], [0.95, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [0.65, Vector3(0, 0, 0.07)], [0.71, Vector3.ZERO]],
		}, [[0.65, "slide_back", -5.0], [0.71, "slide_home", -4.0]]),
		# Looks down the left side, turns it over to the right, taps the mag.
		_clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.06, 0.1)], [1.3, Vector3(-0.12, 0.066, 0.1)],
				[1.6, Vector3(-0.04, 0.03, 0.06)], [2.2, Vector3(-0.04, 0.034, 0.06)], [2.3, Vector3(-0.04, 0.044, 0.06)],
				[2.4, Vector3(-0.04, 0.03, 0.06)], [2.8, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(14, 58, -28)], [1.3, Vector3(10, 62, -32)], [1.6, Vector3(-6, -24, 44)],
				[2.2, Vector3(-8, -26, 46)], [2.3, Vector3(-4, -25, 44)], [2.8, Vector3(-2, 0, 0)], [3.2, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [1.6, "swap", -14.0], [2.3, "mag_in", -9.0]])),
	"Pivot/Gun/Bolt")
	return r


## AK-47: wood furniture, curved magazine, gas tube over the barrel, front sight at the
## muzzle and the charging handle on the right (Bolt).
func _ak47() -> Node3D:
	var r := _rig("AK47")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.055, 0.075, 0.32), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "DustCover", Vector3(0.05, 0.012, 0.28), Vector3(0, 0.043, 0.0), Vector3.ZERO, _mat.gun)
	_part(gun, "Handguard", Vector3(0.05, 0.05, 0.2), Vector3(0, -0.005, -0.26), Vector3.ZERO, _mat.k_wood)
	_part(gun, "GasTube", Vector3(0.04, 0.025, 0.16), Vector3(0, 0.032, -0.24), Vector3.ZERO, _mat.k_wood)
	_part(gun, "Barrel", Vector3(0.02, 0.02, 0.2), Vector3(0, 0.012, -0.46), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightPost", Vector3(0.01, 0.04, 0.012), Vector3(0, 0.035, -0.53), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.006, 0.006, 0.006), Vector3(0, 0.058, -0.53), Vector3.ZERO, _mat.sight)
	_part(gun, "RearSightBase", Vector3(0.03, 0.012, 0.04), Vector3(0, 0.048, -0.12), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightL", Vector3(0.008, 0.012, 0.012), Vector3(-0.01, 0.058, -0.12), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.008, 0.012, 0.012), Vector3(0.01, 0.058, -0.12), Vector3.ZERO, _mat.gun)
	# The banana mag: segments chained down an arc that bends forward (towards the muzzle),
	# each one overlapping the last so it reads as one curved piece seated in the magwell.
	var mag := _hinge(gun, "Magazine", Vector3(0, -0.03, -0.07))
	var at := Vector3.ZERO
	var k := 0
	for tilt: float in [6.0, 16.0, 27.0, 38.0]:
		var down := Vector3(0, -cos(deg_to_rad(tilt)), -sin(deg_to_rad(tilt)))
		_box(r, mag, "Segment%d" % k, Vector3(0.034, 0.05, 0.072 - k * 0.003), at + down * 0.025, Vector3(tilt, 0, 0), _mat.accent)
		at += down * 0.045
		k += 1
	_box(r, mag, "Floorplate", Vector3(0.036, 0.008, 0.066), at + Vector3(0, 0.002, 0.0), Vector3(44, 0, 0), _mat.gun)
	_part(gun, "Grip", Vector3(0.036, 0.1, 0.046), Vector3(0, -0.08, 0.11), Vector3(-20, 0, 0), _mat.k_wood)
	_part(gun, "Stock", Vector3(0.045, 0.08, 0.24), Vector3(0, -0.025, 0.29), Vector3(-6, 0, 0), _mat.k_wood)
	_part(gun, "Bolt", Vector3(0.02, 0.012, 0.012), Vector3(0.036, 0.02, 0.02), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.012, -0.57))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.12), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.13, 0.15), HIP.ak47)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.045, -0.24), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.07, -0.22), HIP.ak47)
	_animate(r, _rifle_clips(2.5, 2.9, 0.08,
		# Comes up canted to show the right side and racks the side charging handle.
		_clip(0.9, {
			"P.pos": [[0, Vector3(0.1, -0.45, 0.15)], [0.28, Vector3(-0.02, 0.01, 0.0)], [0.42, Vector3(-0.01, 0.0, 0.01)],
				[0.56, Vector3(-0.01, 0.0, 0.02)], [0.66, Vector3(0, 0, -0.005)], [0.9, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-60, 30, -70)], [0.28, Vector3(4, -12, 26)], [0.42, Vector3(0, -8, 24)],
				[0.56, Vector3(-4, -8, 22)], [0.66, Vector3(2, -2, 6)], [0.9, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [0.48, Vector3.ZERO], [0.54, Vector3(0, 0, 0.09)], [0.6, Vector3.ZERO]],
		}, [[0.54, "slide_back", -4.0], [0.6, "slide_home", -3.0]]),
		# Turns it to the right side, swings it round to the left, gives it a shake.
		_clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.08, 0.05, 0.08)], [1.2, Vector3(-0.08, 0.055, 0.08)],
				[1.55, Vector3(-0.12, 0.06, 0.1)], [2.3, Vector3(-0.12, 0.064, 0.1)], [2.4, Vector3(-0.12, 0.05, 0.1)],
				[2.48, Vector3(-0.12, 0.066, 0.1)], [2.8, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(-6, -28, 44)], [1.2, Vector3(-8, -30, 46)], [1.55, Vector3(14, 60, -26)],
				[2.3, Vector3(10, 62, -30)], [2.4, Vector3(16, 60, -28)], [2.48, Vector3(8, 62, -30)], [2.8, Vector3(-2, 0, 0)],
				[3.2, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [1.55, "swap", -12.0], [2.4, "mag_in", -10.0]])),
	"Pivot/Gun/Bolt")
	return r


## Reloads for a magazine rifle: tilt, mag out and in, and on empty a pull on the charging
## handle (Bolt moves back `bolt_back`). Times stretch with the reload length. Plus the
## rifle's own draw and inspect.
func _rifle_clips(reload_len: float, empty_len: float, bolt_back: float, draw: Dictionary, inspect: Dictionary) -> Dictionary:
	var k := reload_len / 2.5
	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.3 * k, Vector3(-0.03, -0.03, 0.03)], [0.95 * k, Vector3(-0.04, -0.04, 0.04)],
			[1.6 * k, Vector3(-0.03, -0.02, 0.03)], [1.67 * k, Vector3(-0.03, 0.0, 0.03)], [1.8 * k, Vector3(-0.03, -0.03, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.3 * k, Vector3(12, 8, 28)], [0.95 * k, Vector3(14, 10, 32)],
			[1.6 * k, Vector3(10, 8, 26)], [1.67 * k, Vector3(16, 8, 24)], [1.85 * k, Vector3(12, 8, 28)]],
		"M.pos": [[0, Vector3.ZERO], [0.35 * k, Vector3.ZERO], [0.55 * k, Vector3(0, -0.06, 0.01)], [0.75 * k, Vector3(0, -0.45, 0.08)],
			[1.15 * k, Vector3(0, -0.4, 0.06)], [1.5 * k, Vector3(0, -0.05, 0.01)], [1.65 * k, Vector3.ZERO]],
	}
	var rack := 1.65 * k + 0.3
	return {
		"idle": _clip(IDLE_LENGTH, {}),
		"draw": draw,
		"draw_quick": _quick_draw(0.4, []),
		"inspect": inspect,
		"reload": _clip(reload_len, _with_end(reload_p, reload_len, {"P.pos": [reload_len - 0.35, Vector3(-0.02, -0.02, 0.02)],
			"P.rot": [reload_len - 0.35, Vector3(4, 2, 10)]}), [[0.45 * k, "mag_out", -6.0], [1.65 * k, "mag_in", -3.0]]),
		"reload_empty": _clip(empty_len, _merge(reload_p, {
			"P.pos": [[rack - 0.1, Vector3(0, -0.01, 0.02)], [rack + 0.1, Vector3(0, 0, 0.04)], [rack + 0.25, Vector3.ZERO], [empty_len, Vector3.ZERO]],
			"P.rot": [[rack - 0.1, Vector3(-4, 0, -2)], [rack + 0.1, Vector3(2, 0, -4)], [rack + 0.35, Vector3(0, 0, -2)], [empty_len, Vector3.ZERO]], # (The roll to the hand is added: GUN_STYLE.)
			"B.pos": [[0, Vector3.ZERO], [rack, Vector3.ZERO], [rack + 0.08, Vector3(0, 0, bolt_back)], [rack + 0.15, Vector3.ZERO]],
		}), [[0.45 * k, "mag_out", -6.0], [1.65 * k, "mag_in", -3.0], [rack + 0.08, "slide_back", -4.0], [rack + 0.15, "slide_home", -3.0]]),
		"melee_lower": _melee_lower(),
	}


## Bolt-action sniper. The scope is solid (fully aimed, the HUD draws the scope instead).
## The bolt handle (Bolt) lifts, pulls back, pushes home and drops after every shot.
func _sniper() -> Node3D:
	var r := _rig("Sniper")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	# CS:GO's AWP (an Accuracy International): olive-green chassis round a black action.
	var green: Material = _mat.awp
	_part(gun, "Receiver", Vector3(0.05, 0.062, 0.28), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Rail", Vector3(0.03, 0.01, 0.3), Vector3(0, 0.036, -0.02), Vector3.ZERO, _mat.gun)
	_part(gun, "Chassis", Vector3(0.062, 0.06, 0.36), Vector3(0, -0.02, -0.3), Vector3.ZERO, green) # The long squared forend.
	_part(gun, "ChassisLip", Vector3(0.066, 0.014, 0.3), Vector3(0, 0.012, -0.27), Vector3.ZERO, green)
	_part(gun, "Barrel", Vector3(0.026, 0.026, 0.68), Vector3(0, 0.012, -0.48), Vector3.ZERO, _mat.gun)
	_part(gun, "MuzzleBrake", Vector3(0.046, 0.04, 0.085), Vector3(0, 0.012, -0.84), Vector3.ZERO, _mat.gun)
	_part(gun, "BrakePort", Vector3(0.05, 0.012, 0.05), Vector3(0, 0.012, -0.84), Vector3.ZERO, _mat.accent)
	for x: float in [-0.014, 0.014]: # The bipod, folded up under the forend.
		_part(gun, "Bipod", Vector3(0.01, 0.012, 0.17), Vector3(x, -0.057, -0.38), Vector3.ZERO, _mat.gun)
	_part(gun, "Magazine", Vector3(0.045, 0.085, 0.09), Vector3(0, -0.07, -0.035), Vector3.ZERO, _mat.accent)
	_part(gun, "TriggerGuard", Vector3(0.03, 0.014, 0.09), Vector3(0, -0.065, 0.06), Vector3.ZERO, green)
	# Thumbhole stock: the grip in front, comb on top, bar underneath, all one green frame.
	_part(gun, "Grip", Vector3(0.044, 0.11, 0.05), Vector3(0, -0.08, 0.12), Vector3(-15, 0, 0), green)
	_part(gun, "StockComb", Vector3(0.054, 0.045, 0.3), Vector3(0, 0.0, 0.28), Vector3.ZERO, green)
	_part(gun, "StockUpright", Vector3(0.05, 0.13, 0.05), Vector3(0, -0.06, 0.38), Vector3.ZERO, green)
	_part(gun, "StockBar", Vector3(0.05, 0.035, 0.2), Vector3(0, -0.115, 0.29), Vector3(-4, 0, 0), green)
	_part(gun, "CheekPiece", Vector3(0.046, 0.024, 0.16), Vector3(0, 0.034, 0.3), Vector3.ZERO, _mat.gun) # Adjustable, black.
	_part(gun, "ButtPad", Vector3(0.056, 0.17, 0.025), Vector3(0, -0.04, 0.415), Vector3.ZERO, _mat.gun)
	_part(gun, "Monopod", Vector3(0.014, 0.05, 0.014), Vector3(0, -0.15, 0.37), Vector3.ZERO, _mat.gun) # The spike under the butt.
	# A big scope: long tube in two rings, a wide objective bell, turrets.
	for z: float in [-0.07, 0.07]:
		_part(gun, "ScopeRing", Vector3(0.044, 0.044, 0.018), Vector3(0, 0.075, z), Vector3.ZERO, _mat.gun)
		_part(gun, "ScopeMount", Vector3(0.02, 0.03, 0.018), Vector3(0, 0.05, z), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeTube", Vector3(0.036, 0.036, 0.32), Vector3(0, 0.075, -0.01), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeBell", Vector3(0.06, 0.06, 0.09), Vector3(0, 0.075, -0.2), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeEye", Vector3(0.05, 0.05, 0.07), Vector3(0, 0.075, 0.17), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeTurret", Vector3(0.024, 0.024, 0.024), Vector3(0, 0.104, -0.01), Vector3.ZERO, _mat.accent)
	_part(gun, "ScopeTurretSide", Vector3(0.024, 0.024, 0.024), Vector3(0.03, 0.075, -0.01), Vector3.ZERO, _mat.accent)
	_part(gun, "ScopeLens", Vector3(0.048, 0.048, 0.004), Vector3(0, 0.075, -0.246), Vector3.ZERO, _mat.sight)
	# Bolt handle with its ball knob (rides along when the bolt's worked).
	var bolt := _part(gun, "Bolt", Vector3(0.06, 0.012, 0.012), Vector3(0.05, 0.015, 0.09), Vector3.ZERO, _mat.gun)
	_box(r, bolt, "BoltKnob", Vector3(0.022, 0.022, 0.022), Vector3(0.032, 0, 0), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.012, -0.885))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.13), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.13, 0.16), HIP.sniper)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.06, -0.22), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.085, -0.2), HIP.sniper)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.35, Vector3(-0.03, -0.03, 0.03)], [1.2, Vector3(-0.04, -0.04, 0.04)],
			[1.95, Vector3(-0.03, -0.02, 0.03)], [2.02, Vector3(-0.03, 0.0, 0.03)], [2.2, Vector3(-0.03, -0.03, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(10, 8, 26)], [1.2, Vector3(12, 10, 30)],
			[1.95, Vector3(8, 8, 24)], [2.02, Vector3(14, 8, 22)], [2.25, Vector3(10, 8, 26)]],
		"M.pos": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.65, Vector3(0, -0.05, 0.01)], [0.9, Vector3(0, -0.45, 0.08)],
			[1.45, Vector3(0, -0.4, 0.06)], [1.85, Vector3(0, -0.04, 0.01)], [2.0, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# CS:GO's AWP deploy: it's bolted as it's lifted. The right hand's on the bolt from the
		# start, and the rifle comes up from low right already leant left (the bolt turned up to
		# you), the bolt going up and back on the way; it slams home with a jolt as the gun
		# arrives in the shoulder, then the rifle rolls level onto target.
		"draw": _clip(1.05, _merge({
			"P.pos": [[0, Vector3(0.1, -0.4, 0.12)], [0.37, Vector3(-0.01, -0.025, 0.035)], [0.43, Vector3(-0.01, -0.025, 0.035)],
				[0.48, Vector3(-0.01, -0.012, 0.02)], [0.58, Vector3(-0.01, -0.025, 0.035)], [0.86, Vector3(0, 0.004, -0.004)],
				[1.05, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-35, 20, 40)], [0.37, Vector3(-4, 4, 22)], [0.43, Vector3(-3, 4, 21)],
				[0.48, Vector3(-8, 4, 18)], [0.58, Vector3(-4, 4, 21)], [0.86, Vector3(1, -1, -2)],
				[1.05, Vector3.ZERO]],
		}, _bolt_cycle(0.1)), [[0.27, "slide_back", -3.0], [0.46, "slide_home", -2.0]]),
		"draw_quick": _quick_draw(0.55, []),
		# Looks down the scope from the side, then rolls it to show the bolt.
		"inspect": _clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.05, 0.1)], [1.3, Vector3(-0.12, 0.056, 0.1)],
				[1.6, Vector3(-0.05, 0.03, 0.06)], [2.6, Vector3(-0.05, 0.034, 0.06)], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(10, 62, -18)], [1.3, Vector3(6, 64, -22)], [1.6, Vector3(-6, -24, 44)],
				[2.6, Vector3(-8, -27, 46)], [3.2, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [1.6, "swap", -14.0]]),
		# After each shot: a beat for the recoil, then leant left into the shoulder, bolt up
		# to you, to run it (as the draw does: the AWP way).
		"cycle": _clip(1.4, _merge({
			"P.pos": [[0, Vector3.ZERO], [0.25, Vector3(-0.01, -0.025, 0.035)], [0.95, Vector3(-0.01, -0.025, 0.035)], [1.28, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.25, Vector3(-4, 4, 22)], [0.95, Vector3(-3, 4, 21)], [1.28, Vector3.ZERO]],
		}, _bolt_cycle(0.3)), [[0.47, "slide_back", -4.0], [0.66, "slide_home", -3.0]]),
		"reload": _clip(3.2, _with_end(reload_p, 3.2, {"P.pos": [2.8, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.8, Vector3(4, 2, 10)]}),
			[[0.55, "mag_out", -6.0], [2.0, "mag_in", -3.0]]),
		"reload_empty": _clip(3.8, _merge(reload_p, {
			"P.pos": [[2.45, Vector3(-0.01, -0.025, 0.035)], [3.3, Vector3(-0.01, -0.025, 0.035)], [3.8, Vector3.ZERO]],
			"P.rot": [[2.45, Vector3(-4, 4, 22)], [3.3, Vector3(-3, 4, 21)], [3.8, Vector3.ZERO]],
		}).merged(_bolt_cycle(2.55)), [[0.55, "mag_out", -6.0], [2.0, "mag_in", -3.0], [2.72, "slide_back", -4.0], [2.91, "slide_home", -3.0]]),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Bolt", {"B": "Pivot/Gun/Bolt"})
	return r


## SSG-008, after CS2's SSG 08: a slim bolt-action with a long fluted barrel, a long
## polymer forend, a skeleton thumbhole stock (comb, upright and bottom bar round an open
## frame), a long scope in two rings with turrets, and a ball-knob bolt. Quicker to draw,
## cycle and reload than the Harrier.
func _ssg() -> Node3D:
	var r := _rig("SSG")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	# Action, barrel and forend.
	_part(gun, "Receiver", Vector3(0.04, 0.05, 0.24), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Barrel", Vector3(0.016, 0.016, 0.52), Vector3(0, 0.01, -0.5), Vector3.ZERO, _mat.gun)
	_part(gun, "BarrelFlute", Vector3(0.0175, 0.004, 0.3), Vector3(0, 0.012, -0.45), Vector3.ZERO, _mat.accent)
	_part(gun, "MuzzleBrake", Vector3(0.024, 0.024, 0.035), Vector3(0, 0.01, -0.775), Vector3.ZERO, _mat.accent)
	_part(gun, "Forend", Vector3(0.046, 0.045, 0.3), Vector3(0, -0.02, -0.27), Vector3.ZERO, _mat.k_black)
	_part(gun, "ForendStep", Vector3(0.04, 0.02, 0.2), Vector3(0, -0.048, -0.24), Vector3.ZERO, _mat.k_black)
	_part(gun, "Magazine", Vector3(0.03, 0.05, 0.055), Vector3(0, -0.055, -0.02), Vector3.ZERO, _mat.accent)
	_part(gun, "TriggerGuard", Vector3(0.008, 0.02, 0.05), Vector3(0, -0.05, 0.05), Vector3.ZERO, _mat.gun)
	# Skeleton stock: grip, comb, upright and bottom bar round the thumbhole.
	_part(gun, "Grip", Vector3(0.034, 0.085, 0.04), Vector3(0, -0.065, 0.095), Vector3(-20, 0, 0), _mat.k_black)
	_part(gun, "StockComb", Vector3(0.038, 0.035, 0.26), Vector3(0, 0.008, 0.25), Vector3(2, 0, 0), _mat.k_black)
	_part(gun, "CheekRiser", Vector3(0.03, 0.02, 0.1), Vector3(0, 0.034, 0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "StockUpright", Vector3(0.04, 0.12, 0.035), Vector3(0, -0.035, 0.37), Vector3.ZERO, _mat.k_black)
	_part(gun, "StockBar", Vector3(0.036, 0.022, 0.2), Vector3(0, -0.095, 0.25), Vector3(-6, 0, 0), _mat.k_black)
	_part(gun, "ButtPad", Vector3(0.044, 0.13, 0.015), Vector3(0, -0.035, 0.393), Vector3.ZERO, _mat.gun)
	# Scope in two rings, turrets on top and the side.
	for z: float in [-0.06, 0.06]:
		_part(gun, "ScopeBase", Vector3(0.014, 0.022, 0.016), Vector3(0, 0.038, z), Vector3.ZERO, _mat.gun)
		_part(gun, "ScopeRing", Vector3(0.034, 0.034, 0.014), Vector3(0, 0.062, z), Vector3.ZERO, _mat.accent)
	_part(gun, "ScopeTube", Vector3(0.028, 0.028, 0.3), Vector3(0, 0.062, 0.0), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeBell", Vector3(0.046, 0.046, 0.07), Vector3(0, 0.062, -0.18), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeEye", Vector3(0.04, 0.04, 0.06), Vector3(0, 0.062, 0.15), Vector3.ZERO, _mat.gun)
	_part(gun, "TurretTop", Vector3(0.018, 0.018, 0.018), Vector3(0, 0.085, 0.0), Vector3.ZERO, _mat.accent)
	_part(gun, "TurretSide", Vector3(0.018, 0.018, 0.018), Vector3(0.022, 0.062, 0.0), Vector3.ZERO, _mat.accent)
	_part(gun, "ScopeLens", Vector3(0.036, 0.036, 0.004), Vector3(0, 0.062, -0.216), Vector3.ZERO, _mat.sight)
	# Bolt handle with its ball knob (the knob rides along when the bolt is worked).
	var bolt := _part(gun, "Bolt", Vector3(0.05, 0.008, 0.008), Vector3(0.042, 0.012, 0.08), Vector3(0, 0, -15), _mat.gun)
	_box(r, bolt, "BoltKnob", Vector3(0.018, 0.018, 0.018), Vector3(0.027, 0, 0), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.01, -0.8))
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.1, 0.12), Vector3(-15, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.12, 0.15), HIP.ssg)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.055, -0.2), Vector3(0, 0, -20), _mat.glove)
	_arm(r, arms, "Left", Vector3(-0.03, -0.08, -0.18), HIP.ssg)

	var reload_p := {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.03, -0.03, 0.03)], [1.0, Vector3(-0.04, -0.04, 0.04)],
			[1.6, Vector3(-0.03, -0.02, 0.03)], [1.66, Vector3(-0.03, 0.0, 0.03)], [1.85, Vector3(-0.03, -0.03, 0.03)]],
		# Light: tipped muzzle up and swung left to drop the mag, not rolled over like the Harrier.
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(16, -12, -8)], [1.0, Vector3(18, -14, -10)],
			[1.6, Vector3(14, -12, -6)], [1.66, Vector3(20, -12, -8)], [1.9, Vector3(16, -12, -8)]],
		"M.pos": [[0, Vector3.ZERO], [0.38, Vector3.ZERO], [0.55, Vector3(0, -0.05, 0.01)], [0.75, Vector3(0, -0.45, 0.08)],
			[1.2, Vector3(0, -0.4, 0.06)], [1.52, Vector3(0, -0.04, 0.01)], [1.65, Vector3.ZERO]],
	}
	_animate(r, {
		"idle": _clip(IDLE_LENGTH, {}),
		# Light: swept in from low left, overshoots up, then the muzzle tips up for a quick
		# flick of the bolt (the Harrier hauls up from the right and cants over instead).
		"draw": _clip(0.8, _merge({
			"P.pos": [[0, Vector3(-0.12, -0.3, 0.12)], [0.22, Vector3(0.005, 0.01, -0.005)], [0.3, Vector3(0, 0.012, 0.0)],
				[0.6, Vector3(0, 0.012, 0.0)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-30, -45, 40)], [0.22, Vector3(4, 6, 4)], [0.3, Vector3(8, -3, -6)],
				[0.6, Vector3(7, -3, -6)], [0.8, Vector3.ZERO]],
		}, _bolt_cycle(0.3, 0.75)), [[0.43, "slide_back", -4.0], [0.57, "slide_home", -3.0]]),
		"draw_quick": _quick_draw(0.45, []),
		# Tips it to look along the barrel, then the other side.
		"inspect": _clip(2.8, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.1, 0.05, 0.08)], [1.2, Vector3(-0.1, 0.055, 0.08)],
				[1.5, Vector3(-0.05, 0.03, 0.05)], [2.3, Vector3(-0.05, 0.034, 0.05)], [2.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(12, 58, -16)], [1.2, Vector3(8, 60, -20)], [1.5, Vector3(-6, -22, 40)],
				[2.3, Vector3(-8, -25, 42)], [2.8, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [1.5, "swap", -14.0]]),
		# After each shot: the muzzle bobs up with the kick and the bolt's flicked, staying on target.
		"cycle": _clip(1.0, _merge({
			"P.pos": [[0, Vector3.ZERO], [0.12, Vector3(0, 0.01, 0.005)], [0.58, Vector3(0, 0.012, 0.0)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.12, Vector3(9, -3, -6)], [0.58, Vector3(7, -3, -6)], [0.8, Vector3.ZERO]],
		}, _bolt_cycle(0.15, 0.75)), [[0.28, "slide_back", -4.0], [0.42, "slide_home", -3.0]]),
		"reload": _clip(2.7, _with_end(reload_p, 2.7, {"P.pos": [2.35, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.35, Vector3(6, -4, -3)]}),
			[[0.45, "mag_out", -6.0], [1.65, "mag_in", -3.0]]),
		"reload_empty": _clip(3.3, _merge(reload_p, {
			"P.pos": [[2.05, Vector3(0, 0.012, 0.0)], [2.75, Vector3(0, 0.012, 0.0)], [3.3, Vector3.ZERO]],
			"P.rot": [[2.05, Vector3(8, -3, -6)], [2.75, Vector3(7, -3, -6)], [3.3, Vector3.ZERO]],
		}).merged(_bolt_cycle(2.15, 0.75)), [[0.45, "mag_out", -6.0], [1.65, "mag_in", -3.0], [2.28, "slide_back", -4.0], [2.42, "slide_home", -3.0]]),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Bolt", {"B": "Pivot/Gun/Bolt"})
	return r


## Bolt handle keys starting at `t`: lift, pull back, push home, drop (0.5 s, times `s`:
## under 1 for a quicker hand). Its sounds go at t + 0.17 s and t + 0.36 s (times `s`).
func _bolt_cycle(t: float, s: float = 1.0) -> Dictionary:
	return {
		"B.rot": [[0, Vector3.ZERO], [t, Vector3.ZERO], [t + 0.07 * s, Vector3(0, 0, 75)], [t + 0.42 * s, Vector3(0, 0, 75)], [t + 0.5 * s, Vector3.ZERO]],
		"B.pos": [[0, Vector3.ZERO], [t + 0.08 * s, Vector3.ZERO], [t + 0.17 * s, Vector3(0, 0, 0.08)], [t + 0.26 * s, Vector3(0, 0, 0.08)],
			[t + 0.36 * s, Vector3.ZERO]],
	}


## Copy of a key dictionary with every key moved `dt` later (rest key kept at 0).
func _shift(tracks: Dictionary, dt: float) -> Dictionary:
	var out := {}
	for k: String in tracks:
		out[k] = [[0, Vector3.ZERO]]
		for key: Array in tracks[k]:
			out[k].append([key[0] + dt, key[1]])
	return out


# --- Knives -----------------------------------------------------------------------------
# CS-style: every knife cuts the same (shared slashes, heavy and quick melee) but
# has its own model, first-draw flourish, inspect and quick-draw flair.

## Knives added after the first four: id (builder _knife_<id>, files knife_<id>) -> name.
const NEW_KNIVES := {
	m9 = "M9 Bayonet", bowie = "Bowie Knife", stiletto = "Stiletto Knife", daggers = "Shadow Daggers", kunai = "Kunai",
}
const KNIFE_LEFT_HIDDEN := Vector3(-0.06, -0.32, 0.12) ## LeftArm offset that drops the free hand out of view.
const KUNAI_HOLD := Vector3(-1.0, 0.12, -0.25) ## Apex kunai hold: the blade points left across the screen (the karambit too).
const KARAMBIT_HOLD := Vector3(-0.35, -0.8, -0.65) ## The karambit's hold: the blade out the left of the fist, pointing well away from you (about 56 degrees) and tipped about 24 degrees down, hooking up, its flat to you. Low enough that on screen the tip sits just below level, not rising (pointing away below eye level reads as up).
const KARAMBIT_REACH := Vector3(0, 0, -0.05) ## The karambit's fist sits this much further out in front than the other knives'.
const KARAMBIT_TWIRL := {length = 0.5, straight = 0.1, spin = Vector2(0.08, 0.34), settle = 0.32, wrist = 30.0} ## Its sprint switch (_add_karambit_twirl()): seconds in all, to turn straight ahead, the twirl (start, end), when it starts turning into the new hold; how far the wrist flicks (degrees).
## Long enough that blending into "idle" (out of an inspect or a flourish) finishes before the
## clip does: a blend still running when its animation ends gets cut short and snaps.
const IDLE_LENGTH := 1.0
const MAG_GRAB := Vector3(-0.07, -0.05, 0.0) ## Where the left hand holds a magazine from: out to the left and under it, so the elbow stays clear of the gun.
const TWIRL_SNAP_DB := -14.0 ## The butterfly's snap at the end of its attack and sprint twirls: quieter than its tricks.


## Rig with the knife hand, plus the free left hand resting low on the left. The left
## hand hangs off the rig root (LeftArm), not Pivot, so slashes only swing the knife hand.
## Returns the "Gun" node (the knife), pivoting at `pivot`. Build its parts as if it
## points straight ahead; _animate_knife turns it into the CS2 grip.
func _knife_rig(n: String, pivot: Vector3) -> Node3D:
	var r := _rig(n)
	var knife := _gun(r, pivot)
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.07, 0.075, 0.085), Vector3(0.0, -0.005, 0.0), Vector3(-10, 0, 0), _mat.glove)
	_arm(r, arms, "Right", Vector3(0.02, -0.04, 0.04), HIP.knife)
	var left := Node3D.new()
	left.name = "LeftArm"
	r.add_child(left)
	left.owner = r
	_box(r, left, "LeftHand", Vector3(0.07, 0.075, 0.085), Vector3(-0.4, -0.06, 0.02), Vector3(-10, 0, 15), _mat.glove)
	_arm(r, left, "Left", Vector3(-0.41, -0.1, 0.06), HIP.knife)
	return knife


## CS2-style hold: instead of pointing straight ahead, the blade angles up and across
## towards the middle of the screen with its flat turned to the camera (spine up-right,
## edge down-left). `view` is roughly the camera-to-fist direction at the hip. Pass `blade`
## for another hold (the kunai points left).
func _knife_grip(blade_dir: Vector3 = Vector3(-0.45, 0.6, -0.6)) -> Basis:
	var blade := blade_dir.normalized()
	var view := Vector3(0.2, -0.2, -0.45).normalized()
	var spine := view.cross(blade).normalized()
	var z := -blade
	return Basis(spine.cross(z), spine, z)


## Every knife's sprint switch, smooth like the kunai's: starting to sprint, the fist drops
## and turns into the run while the knife spins once in the hand ("sprint"); stopping, it
## spins once more on the way back up to the normal hold ("sprint_end"). A full turn, so the
## hold itself doesn't change. WeaponManager plays them.
func _add_flow(clips: Dictionary) -> void:
	var run_pos := Vector3(-0.03, -0.06, 0.04)
	var run_rot := Vector3(-14, 26, 10)
	clips["sprint"] = _clip(0.6, {
		"G.rot": [[0, Vector3.ZERO], [0.48, Vector3(-360, 0, 0)], [0.6, Vector3(-360, 0, 0)]],
		"P.pos": [[0, Vector3.ZERO], [0.15, Vector3(0.0, 0.02, -0.01)], [0.6, run_pos]],
		"P.rot": [[0, Vector3.ZERO], [0.15, Vector3(-6, 6, -4)], [0.6, run_rot]],
	})
	clips["sprint_end"] = _clip(0.6, {
		"G.rot": [[0, Vector3(-360, 0, 0)], [0.48, Vector3(-720, 0, 0)], [0.6, Vector3(-720, 0, 0)]],
		"P.pos": [[0, run_pos], [0.3, Vector3(0.0, 0.02, -0.01)], [0.6, Vector3.ZERO]],
		"P.rot": [[0, run_rot], [0.3, Vector3(-6, 6, -4)], [0.6, Vector3.ZERO]],
	})


## The same grip, or turned half round the blade, whichever has the blade's curve (its -Y:
## the karambit's hook) bending upward.
func _hook_up(grip: Basis) -> Basis:
	var turned := grip * Basis(Vector3(0, 0, 1), PI)
	return grip if (grip * Vector3.DOWN).y >= (turned * Vector3.DOWN).y else turned


## The kunai's sprint switch (the karambit's too): spun in the hand like its draw, only
## slower, a turn and a half so it's caught the other way round (loop out front, blade back
## behind the fist) as you start to sprint ("sprint"), and another turn and a half back to the
## normal hold when you stop ("sprint_end"). WeaponManager plays them. `run` is the turn it's
## caught at (degrees, in the knife's own frame): by default the hold reversed. `back` is
## where it spins on to as it comes back (a whole number of turns: the hold again).
func _add_twirl(clips: Dictionary, run: Vector3 = Vector3(-540, 0, 0), back: Vector3 = Vector3(-1080, 0, 0)) -> void:
	clips["sprint"] = _clip(0.62, {
		"G.rot": [[0, Vector3.ZERO], [0.5, run], [0.62, run]],
		"P.pos": [[0, Vector3.ZERO], [0.15, Vector3(0.01, 0.025, -0.01)], [0.62, Vector3(0.03, -0.01, 0.03)]],
		"P.rot": [[0, Vector3.ZERO], [0.15, Vector3(-8, 0, -6)], [0.62, Vector3(0, 0, 8)]],
	})
	clips["sprint_end"] = _clip(0.62, {
		"G.rot": [[0, run], [0.5, back], [0.62, back]],
		"P.pos": [[0, Vector3(0.03, -0.01, 0.03)], [0.15, Vector3(0.01, 0.025, -0.01)], [0.62, Vector3.ZERO]],
		"P.rot": [[0, Vector3(0, 0, 8)], [0.15, Vector3(-8, 0, -6)], [0.62, Vector3.ZERO]],
	})


## The wrist turns with a knife's sprint twirls: the fist rolls the way the knife spins, about
## the same axis (`axis`, in the fist's frame), up to `peak` degrees halfway through the spin
## (`from` to `to` seconds) and back, so the hand and arm look like they're driving it rather
## than the knife spinning in a still hand. Ends where it would anyway.
func _wrist_follow(clips: Dictionary, axis: Vector3, peak: float, from: float, to: float) -> void:
	for clip_name: String in ["sprint", "sprint_end"]:
		var c: Dictionary = clips[clip_name]
		var keys: Array = c.tracks.get("P.rot", [[0.0, Vector3.ZERO]])
		var times := {}
		for k: Array in keys:
			times[float(k[0])] = true
		for i in 11:
			times[lerpf(from, to, i / 10.0)] = true
		var sorted: Array = times.keys()
		sorted.sort()
		var out: Array = []
		for t: float in sorted:
			var turn := -deg_to_rad(peak) * sin(PI * clampf((t - from) / (to - from), 0.0, 1.0))
			var base := Basis.from_euler(_sample(keys, t) * (PI / 180.0))
			out.append([t, (Basis(axis.normalized(), turn) * base).get_euler() * (180.0 / PI)])
		c.tracks["P.rot"] = out


## The karambit's sprint switch, quicker and cleaner than the kunai's: it turns from the hold to
## point straight away from you, twirls once end over end in that straight line (a wheel seen
## edge on, the point going up and away over the top), then turns into the new hold. Into the
## run from `hold` to `run` ("sprint"), and back ("sprint_end"). The wrist flicks with the twirl.
func _add_karambit_twirl(clips: Dictionary, hold: Basis, run: Basis) -> void:
	var length := KARAMBIT_TWIRL.length
	var run_pos := Vector3(0.03, -0.01, 0.03)
	var run_rot := Vector3(0, 0, 8)
	var mid_pos := Vector3(0.01, 0.025, -0.01)
	var mid_rot := Vector3(-8, 0, -6)
	clips["sprint"] = _clip(length, {
		"G.rot": _twirl_keys(hold, run, hold),
		"P.pos": [[0, Vector3.ZERO], [0.12, mid_pos], [length, run_pos]],
		"P.rot": [[0, Vector3.ZERO], [0.12, mid_rot], [length, run_rot]],
	})
	clips["sprint_end"] = _clip(length, {
		"G.rot": _twirl_keys(run, hold, hold),
		"P.pos": [[0, run_pos], [0.12, mid_pos], [length, Vector3.ZERO]],
		"P.rot": [[0, run_rot], [0.12, mid_rot], [length, Vector3.ZERO]],
	})
	_wrist_follow(clips, Vector3.RIGHT, KARAMBIT_TWIRL.wrist, KARAMBIT_TWIRL.spin.x, KARAMBIT_TWIRL.spin.y)


## Every frame of a karambit twirl from `from` to `to` (the knife's turn in the fist), as turns
## from `rest`: into the straight-ahead hold, the spin about the screen's across axis, then
## into `to`. (Straight ahead is the knife as built: blade forward, hook down, flat to the side.)
func _twirl_keys(from: Basis, to: Basis, rest: Basis) -> Array:
	var tw: Dictionary = KARAMBIT_TWIRL
	var a := from.get_rotation_quaternion()
	var b := to.get_rotation_quaternion()
	var rest_inv := rest.get_rotation_quaternion().inverse()
	var keys: Array = []
	var n := ceili(tw.length * 60.0)
	for i in n + 1:
		var t: float = tw.length * i / n
		var hold := a.slerp(Quaternion.IDENTITY, smoothstep(0.0, tw.straight, t)) if t < tw.straight \
				else Quaternion.IDENTITY.slerp(b, smoothstep(tw.settle, tw.length, t))
		var spin := Quaternion(Vector3.RIGHT, -TAU * smoothstep(tw.spin.x, tw.spin.y, t))
		keys.append([t, rest_inv * spin * hold])
	return keys


## Turns the knife into the grip (about the middle of the fist, so the handle stays in
## the hand whatever the knife's own pivot) and animates the rig. Knife rotation keys
## are in the knife's own frame, so spins still go round the blade / end over end.
func _animate_knife(r: Node3D, clips: Dictionary, hinges: Dictionary = {}, grip: Basis = _knife_grip()) -> void:
	var knife: Node3D = r.get_node("Pivot/Gun")
	knife.position = grip * knife.position
	knife.basis = grip
	_animate(r, clips, "", hinges.merged({"L": "LeftArm"}))


func _knife_clips(draw: Dictionary, inspect: Dictionary, quick_extra: Dictionary, hide_left: bool = true) -> Dictionary:
	# The free hand comes up with the draw and gets out of the way for inspects.
	if not draw.tracks.has("L.pos"):
		draw.tracks["L.pos"] = [[0, KNIFE_LEFT_HIDDEN], [0.3, Vector3.ZERO]]
	if hide_left:
		inspect.tracks["L.pos"] = [[0, Vector3.ZERO], [0.25, KNIFE_LEFT_HIDDEN], [inspect.length - 0.35, KNIFE_LEFT_HIDDEN],
			[inspect.length, Vector3.ZERO]]
	quick_extra = quick_extra.merged({"L.pos": [[0, KNIFE_LEFT_HIDDEN], [0.2, Vector3.ZERO]]})
	# Heavy stab: the blade turns from the grip to point dead ahead, edge rolled over.
	var stab := (_knife_grip().inverse() * Basis.from_euler(Vector3(0, 0, deg_to_rad(-90)))).get_euler() * (180.0 / PI)
	var clips := {
		"idle": _clip(IDLE_LENGTH, {}),
		"draw": draw,
		"draw_quick": _quick_draw(0.25, [[0.0, "knife_draw", -10.0]], quick_extra),
		"inspect": inspect,
		# Forehand: cocks up-right, rips down-left.
		"slash_right": _clip(0.45, {
			"P.pos": [[0, Vector3.ZERO], [0.07, Vector3(0.1, 0.08, 0.06)], [0.17, Vector3(-0.28, -0.08, -0.12)],
				[0.28, Vector3(-0.3, -0.12, -0.08)], [0.45, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.07, Vector3(25, -35, -55)], [0.17, Vector3(-20, 55, 75)],
				[0.28, Vector3(-25, 60, 80)], [0.45, Vector3.ZERO]],
		}),
		# Backhand: cocks up-left, rips down-right.
		"slash_left": _clip(0.45, {
			"P.pos": [[0, Vector3.ZERO], [0.07, Vector3(-0.15, 0.1, 0.04)], [0.17, Vector3(0.15, -0.1, -0.12)],
				[0.28, Vector3(0.17, -0.13, -0.08)], [0.45, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.07, Vector3(30, 40, 70)], [0.17, Vector3(-25, -45, -80)],
				[0.28, Vector3(-28, -50, -85)], [0.45, Vector3.ZERO]],
		}),
		# Wind back, then a full-arm lunge stab.
		"heavy": _clip(0.8, {
			"P.pos": [[0, Vector3.ZERO], [0.28, Vector3(0.04, 0.06, 0.16)], [0.36, Vector3(-0.04, 0.02, -0.32)],
				[0.5, Vector3(-0.04, 0.02, -0.3)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.28, Vector3(30, -10, -30)], [0.36, Vector3(-10, 5, 10)],
				[0.5, Vector3(-8, 5, 8)], [0.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.2, stab], [0.36, stab], [0.7, Vector3.ZERO]],
		}),
		# Quick melee from a gun: in from the bottom-right, slash, out bottom-left. The gun's hands stay, so no free hand.
		"quick_slash": _clip(0.5, {
			"L.pos": [[0, KNIFE_LEFT_HIDDEN]],
			"P.pos": [[0, Vector3(0.12, -0.4, 0.12)], [0.1, Vector3(0.1, 0.08, 0.06)], [0.2, Vector3(-0.28, -0.08, -0.12)],
				[0.32, Vector3(-0.3, -0.12, -0.08)], [0.5, Vector3(-0.1, -0.5, 0.1)]],
			"P.rot": [[0, Vector3(-40, -30, -40)], [0.1, Vector3(25, -35, -55)], [0.2, Vector3(-20, 55, 75)],
				[0.32, Vector3(-25, 60, 80)], [0.5, Vector3(-60, 40, 60)]],
		}),
	}
	_add_flow(clips) # Every knife eases into and out of sprinting with a spin (the kunai and karambit swap this for their twirl).
	return clips


func _knife_combat() -> Node3D:
	var k := _knife_model("CombatKnife", Vector3.ZERO, [
		["Handle", Vector3(0.025, 0.03, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.gun],
		["Pommel", Vector3(0.03, 0.034, 0.015), Vector3(0, 0, 0.06), Vector3.ZERO, _mat.accent],
		["Guard", Vector3(0.012, 0.06, 0.015), Vector3(0, 0, -0.06), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.035, 0.17), Vector3(0, 0, -0.15), Vector3.ZERO, _mat.blade],
		_point("Tip", Vector3(0.006, 0.035, 0.17), Vector3(0, 0, -0.15), 0.035, 0.8, _mat.blade),
	])
	_animate_knife(k.owner, _knife_clips(_draw_roll(), _insp_roll_toss(), _quick_roll()))
	return k.owner


## Karambit: a hooked claw blade, honed thin to a needle point, with a finger ring at the
## pommel, all black. Held across the fist, the ring out to the right and the blade out to the
## left hooking upward, so the whole blade shows. Sprinting it spins like the kunai (a turn
## and a half in the hand and back).
func _knife_karambit() -> Node3D:
	var parts := [
		["Ring", Vector3(0.011, 0.019, 0), Vector3(0, 0, 0.075), Vector3.ZERO, _mat.k_black],
		["Handle", Vector3(0.022, 0.028, 0.1), Vector3(0, 0, 0.005), Vector3.ZERO, _mat.k_black],
	]
	# The hooked blade: straight pieces, each starting where the last one ends and bending
	# further down (the hook), thinning and narrowing to a needle point. Out of the handle
	# on its centreline. Each piece: length, angle (degrees, - = hooking down), height, thickness.
	var at := Vector2(0.0, -0.045) # (y, z) where the next piece starts.
	var segments := [[0.06, 0.0, 0.028, 0.004], [0.05, -25.0, 0.023, 0.0035], [0.044, -48.0, 0.016, 0.003]]
	var last: Array = []
	for i in segments.size():
		var s: Array = segments[i]
		var dir := Vector2(sin(deg_to_rad(s[1])), -cos(deg_to_rad(s[1])))
		var c: Vector2 = at + dir * float(s[0]) * 0.5
		# A touch longer than its step, so the bends close up with no notch.
		var size := Vector3(s[3], s[2], s[0] + 0.006)
		var pos := Vector3(0, c.x, c.y)
		parts.append(["Blade%d" % (i + 1), size, pos, Vector3(s[1], 0, 0), _mat.blade])
		# The sharpened inside edge, a hair proud of the blade along its bottom.
		var down := Vector2(-cos(deg_to_rad(s[1])), -sin(deg_to_rad(s[1])))
		var e: Vector2 = c + down * (float(s[2]) * 0.5 - 0.002)
		parts.append(["Edge%d" % (i + 1), Vector3(s[3] + 0.001, 0.004, s[0]), Vector3(0, e.x, e.y), Vector3(s[1], 0, 0), _mat.blade])
		at += dir * float(s[0])
		last = s
	# The needle point off the end of the last piece, bent down a little further still.
	var tip_angle := -62.0
	var tip_dir := Vector2(sin(deg_to_rad(tip_angle)), -cos(deg_to_rad(tip_angle)))
	var tc := at + tip_dir * 0.02
	parts.append(["Tip", Vector3(last[3], last[2], 0.04), Vector3(0, tc.x, tc.y), Vector3(tip_angle, 0, 0), _mat.blade, "W", 0.5])
	var k := _knife_model("Karambit", Vector3(0, 0, 0.005), parts)
	var clips := _knife_clips(_draw_ring(), _insp_ring(), _quick_ring())
	var grip := _hook_up(_knife_grip(KARAMBIT_HOLD))
	# Sprinting, it's caught just as the kunai is (blade out to the right), its hook curving
	# away from you so the point faces out ahead, not down. Getting there it twirls straight ahead (_add_karambit_twirl()).
	var blade := Basis(Vector3.UP, deg_to_rad(25.0)) * (_knife_grip(KUNAI_HOLD) * Basis(Vector3.RIGHT, PI)) * Vector3.FORWARD # Swung a little further away than the kunai.
	var away := (Vector3.FORWARD - blade * blade.dot(Vector3.FORWARD)).normalized()
	var want := Basis((-away).cross(-blade), -away, -blade) # Its -Y (the hook) away, -Z (the blade) out.
	_add_karambit_twirl(clips, grip, want)
	(k.owner.get_node("Pivot") as Node3D).position += KARAMBIT_REACH
	_animate_knife(k.owner, clips, {}, grip)
	return k.owner


## Balisong: the blade (BladeArm) and both handles (HandleA = safe; HandleB = bite;
## both black) each turn on the pivot pins at the blade root, like the real thing. Open = all at
## rest (handles together in the fist, blade out front); closed = the blade swung back
## between the handles (BladeArm at 180). Every trick is blade and handles swinging round
## the pins while the wrist rocks in time, and each move starts before the last one lands.
func _knife_butterfly() -> Node3D:
	var pins := Vector3(0, 0, -0.055)
	var k := _knife_rig("Butterfly", pins)
	var r: Node3D = k.owner
	var blade := _hinge(k, "BladeArm", pins)
	_box(r, blade, "Blade", Vector3(0.005, 0.03, 0.13), Vector3(0, 0, -0.065), Vector3.ZERO, _mat.blade)
	_wedge(r, blade, "Tip", Vector3(0.005, 0.03, 0.028), Vector3(0, 0, -0.144), Vector3.ZERO, 0.8, _mat.blade) # Its point (see _point()).
	_box(r, blade, "Tang", Vector3(0.006, 0.012, 0.012), Vector3(0, -0.006, 0.0), Vector3.ZERO, _mat.accent)
	var a := _hinge(k, "HandleA", pins)
	_box(r, a, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(0.006, 0, 0.0575), Vector3.ZERO, _mat.k_black)
	var b := _hinge(k, "HandleB", pins)
	_box(r, b, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(-0.006, 0, 0.0575), Vector3.ZERO, _mat.k_black)
	var clips := _knife_clips(
		# Comes up closed and snaps open: the blade flies out and round in an aerial while the
		# bite handle chases it round twice, then a rollover to finish.
		_clip(0.7, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.12, Vector3(0, -0.03, 0)], [0.4, Vector3(0, -0.015, 0)],
				[0.55, Vector3(0, -0.035, 0.01)], [0.7, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -10, -20)], [0.12, Vector3(-6, 0, -8)], [0.22, Vector3(-14, 0, 14)],
				[0.32, Vector3(-2, 0, -14)], [0.42, Vector3(-12, 0, 10)], [0.56, Vector3(-6, 0, 0)], [0.7, Vector3.ZERO]],
			"E.rot": [[0, Vector3(180, 0, 0)], [0.1, Vector3(180, 0, 0)], [0.26, Vector3.ZERO], [0.38, Vector3(-360, 0, 0)]],
			"H.rot": [[0, Vector3.ZERO], [0.1, Vector3.ZERO], [0.26, Vector3(-180, 0, 0)], [0.4, Vector3(-360, 0, 0)],
				[0.52, Vector3(-720, 0, 0)]],
			"G.rot": [[0, Vector3.ZERO], [0.4, Vector3.ZERO], [0.62, Vector3(0, 0, 360)]],
		}, [[0.0, "knife_draw", -6.0], [0.1, "knife_swing", -13.0], [0.26, "catch", -7.0], [0.3, "knife_swing", -14.0],
			[0.4, "catch", -6.0], [0.52, "catch", -5.0]]),
		# A fast chain of tricks: closing aerial, rollover, fans, a zen loop with both handles,
		# a second rollover and a flurry of aerials before it snaps open. Six turns of the blade,
		# more than any other knife. Starts and ends at rest, so held inspect loops cleanly.
		_clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.225, Vector3(-0.08, 0.05, 0.05)], [0.525, Vector3(-0.08, 0.04, 0.05)],
				[0.75, Vector3(-0.08, 0.056, 0.05)], [1.125, Vector3(-0.07, 0.05, 0.04)], [1.425, Vector3(-0.08, 0.06, 0.05)],
				[1.725, Vector3(-0.08, 0.045, 0.05)], [1.95, Vector3(-0.06, 0.065, 0.04)], [2.25, Vector3(-0.08, 0.05, 0.05)],
				[2.55, Vector3(-0.08, 0.055, 0.05)], [2.625, Vector3(-0.08, 0.04, 0.055)], [2.7, Vector3(-0.08, 0.052, 0.05)],
				[3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.225, Vector3(10, 25, -10)], [0.41, Vector3(4, 25, -24)], [0.64, Vector3(14, 25, 4)],
				[0.75, Vector3(8, 25, -14)], [1.125, Vector3(6, -15, 18)], [1.35, Vector3(12, -10, -6)], [1.575, Vector3(4, -14, 16)],
				[1.8, Vector3(10, 10, -20)], [1.95, Vector3(18, 20, -40)], [2.14, Vector3(8, 22, -6)], [2.25, Vector3(10, 25, -12)],
				[2.55, Vector3(14, 25, -12)], [2.625, Vector3(0, 25, -4)], [2.7, Vector3(10, 25, -12)], [3.0, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.75, Vector3.ZERO], [1.1, Vector3(0, 0, 360)], [2.3, Vector3(0, 0, 360)],
				[2.6, Vector3(0, 0, 720)]],
			"E.rot": [[0, Vector3.ZERO], [0.26, Vector3.ZERO], [0.5, Vector3(-180, 0, 0)], [0.72, Vector3(-360, 0, 0)],
				[1.1, Vector3(-360, 0, 0)], [1.7, Vector3(-1080, 0, 0)], [1.9, Vector3(-1260, 0, 0)], [2.1, Vector3(-1440, 0, 0)],
				[2.25, Vector3(-1440, 0, 0)], [2.45, Vector3(-1800, 0, 0)], [2.6, Vector3(-1980, 0, 0)],
				[2.72, Vector3(-2160, 0, 0), "linear"]],
			"A.rot": [[0, Vector3.ZERO], [1.2, Vector3.ZERO], [1.65, Vector3(360, 0, 0)], [2.3, Vector3(360, 0, 0)],
				[2.6, Vector3(720, 0, 0)]],
			"H.rot": [[0, Vector3.ZERO], [0.34, Vector3.ZERO], [0.64, Vector3(-180, 0, 0)], [0.82, Vector3(-360, 0, 0)],
				[1.72, Vector3(-360, 0, 0)], [2.1, Vector3(-720, 0, 0)], [2.45, Vector3(-1080, 0, 0)], [2.65, Vector3(-1440, 0, 0)]],
		}, [[0.5, "catch", -8.0], [0.72, "catch", -7.0], [0.82, "catch", -7.0], [1.65, "catch", -7.0], # Just the snaps.
			[1.75, "catch", -8.0], [2.1, "catch", -7.0], [2.45, "catch", -6.0], [2.6, "catch", -6.0], [2.72, "catch", -3.0]]),
		# Quick draw: flicks the blade open with the bite handle whipping round twice.
		{"E.rot": [[0, Vector3(180, 0, 0)], [0.1, Vector3.ZERO]],
			"H.rot": [[0, Vector3.ZERO], [0.03, Vector3.ZERO], [0.12, Vector3(-360, 0, 0)], [0.22, Vector3(-720, 0, 0)]]},
	)
	# Attacks finish with a slow, lazy twirl: once the cut's through, the bite handle and the
	# blade each loop round once and snap home softly. The twirl runs on past the attack
	# ("busy" is when you can act again, same as every knife), so it can take its time; attack
	# again and the next cut simply takes over. Every twirl snaps quietly.
	for n: String in ["slash_right", "slash_left"]:
		clips[n].length = 0.8
		clips[n].busy = 0.45
		clips[n].tracks["H.rot"] = [[0, Vector3.ZERO], [0.24, Vector3.ZERO], [0.71, Vector3(-360, 0, 0)]]
		clips[n].tracks["E.rot"] = [[0, Vector3.ZERO], [0.28, Vector3.ZERO], [0.74, Vector3(-360, 0, 0)]]
		clips[n].sfx = [[0.71, "catch", TWIRL_SNAP_DB]]
	clips.heavy.length = 1.15
	clips.heavy.busy = 0.8
	clips.heavy.tracks["H.rot"] = [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [1.03, Vector3(-360, 0, 0)]]
	clips.heavy.tracks["E.rot"] = [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [1.08, Vector3(-360, 0, 0)]]
	clips.heavy.sfx = [[1.03, "catch", TWIRL_SNAP_DB]]
	# Sprinting: the handles flip round on top of the usual spin, with a soft snap for each.
	for n: String in ["sprint", "sprint_end"]:
		clips[n].tracks["H.rot"] = [[0, Vector3.ZERO], [0.08, Vector3.ZERO], [0.3, Vector3(-360, 0, 0)], [0.5, Vector3(-720, 0, 0)]]
		clips[n].tracks["E.rot"] = [[0, Vector3.ZERO], [0.12, Vector3.ZERO], [0.42, Vector3(-360, 0, 0)]]
		clips[n].sfx = [[0.3, "catch", TWIRL_SNAP_DB], [0.42, "catch", TWIRL_SNAP_DB], [0.5, "catch", TWIRL_SNAP_DB]]
	_animate_knife(r, clips, {"A": "Pivot/Gun/HandleA", "H": "Pivot/Gun/HandleB", "E": "Pivot/Gun/BladeArm"})
	return r


## Long blade with a fuller. Draw is a barrel-roll toss.
func _knife_bayonet() -> Node3D:
	var k := _knife_model("Bayonet", Vector3.ZERO, [
		["Handle", Vector3(0.026, 0.032, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.k_olive],
		["Pommel", Vector3(0.03, 0.036, 0.016), Vector3(0, 0, 0.062), Vector3.ZERO, _mat.accent],
		["Guard", Vector3(0.014, 0.075, 0.016), Vector3(0, 0, -0.062), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.036, 0.21), Vector3(0, 0, -0.17), Vector3.ZERO, _mat.blade],
		["Fuller", Vector3(0.0068, 0.006, 0.15), Vector3(0, 0.008, -0.15), Vector3.ZERO, _mat.accent],
		_point("Tip", Vector3(0.006, 0.036, 0.21), Vector3(0, 0, -0.17), 0.04, 0.8, _mat.blade),
	])
	_animate_knife(k.owner, _knife_clips(_draw_toss(), _insp_show_toss(), _quick_half_roll()))
	return k.owner


# --- More knives ---------------------------------------------------------------------------

## CS2's M9: it pivots at the guard, so its spins go round your index finger rather than
## the middle of the handle. Draw twirls it forward round the finger; inspect shows the flat,
## rolls it to show the saw back, twirls it twice, drops to a reverse grip and snaps back.
func _knife_m9() -> Node3D:
	var k := _knife_model("M9Bayonet", Vector3(0, 0, -0.064), [
		["Handle", Vector3(0.028, 0.034, 0.115), Vector3.ZERO, Vector3.ZERO, _mat.k_black],
		["Pommel", Vector3(0.03, 0.036, 0.016), Vector3(0, 0, 0.064), Vector3.ZERO, _mat.accent],
		["Guard", Vector3(0.014, 0.07, 0.016), Vector3(0, 0, -0.064), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.04, 0.2), Vector3(0, 0, -0.17), Vector3.ZERO, _mat.blade],
		["Saw", Vector3(0.0068, 0.008, 0.09), Vector3(0, 0.022, -0.13), Vector3.ZERO, _mat.dark_blade],
		_point("Tip", Vector3(0.006, 0.04, 0.2), Vector3(0, 0, -0.17), 0.04, 0.9, _mat.blade),
	])
	_animate_knife(k.owner, _knife_clips(
		# Comes up and twirls forward once round the finger, catches with a wrist roll.
		_clip(0.85, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.18, Vector3(0, -0.03, 0)], [0.5, Vector3(0, -0.02, 0)],
				[0.58, Vector3(0, -0.045, 0.01)], [0.7, Vector3(0, 0.004, 0)], [0.85, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.18, Vector3(-6, 0, 0)], [0.5, Vector3(2, 0, 4)],
				[0.58, Vector3(-9, 0, -8)], [0.7, Vector3(-2, 0, 3)], [0.85, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.55, Vector3(-360, 0, 0)]],
		}, [[0.0, "knife_draw", -6.0], [0.2, "knife_swing", -12.0], [0.55, "catch", -4.0]]),
		_clip(3.4, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.1, 0.06, 0.05)], [1.1, Vector3(-0.09, 0.07, 0.04)],
				[1.4, Vector3(-0.09, 0.06, 0.05)], [1.7, Vector3(-0.09, 0.052, 0.05)], [2.0, Vector3(-0.09, 0.06, 0.05)],
				[2.4, Vector3(-0.07, 0.075, 0.04)], [2.7, Vector3(-0.07, 0.072, 0.04)], [3.0, Vector3(-0.08, 0.05, 0.05)],
				[3.4, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(10, 28, -12)], [1.1, Vector3(22, 20, -40)], [1.4, Vector3(10, 26, -14)],
				[2.0, Vector3(12, 22, -10)], [2.4, Vector3(4, -18, 20)], [2.7, Vector3(6, -20, 22)], [3.0, Vector3(-6, -8, 4)],
				[3.4, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [1.1, Vector3(0, 0, 90)], [1.4, Vector3.ZERO],
				[2.0, Vector3(-720, 0, 0)], [2.4, Vector3(-900, 0, 0)], [2.7, Vector3(-900, 0, 0)],
				[3.0, Vector3(-1080, 0, 0), "linear"]],
		}, [[0.45, "swap", -14.0], [1.4, "knife_swing", -12.0], [1.7, "knife_swing", -13.0], [2.0, "catch", -7.0],
			[2.1, "knife_swing", -14.0], [2.4, "catch", -6.0], [2.7, "knife_swing", -12.0], [3.0, "catch", -4.0]]),
		{"G.rot": [[0, Vector3(-360, 0, 0)], [0.22, Vector3.ZERO]]},
	))
	return k.owner


## Big clip-point fighting knife with a brass guard: a third bigger than the others, and it
## moves like it: slow, heavy turns and weighty catches.
func _knife_bowie() -> Node3D:
	var k := _knife_model("Bowie", Vector3.ZERO, [
		["Handle", Vector3(0.032, 0.04, 0.13), Vector3(0, 0, 0.005), Vector3.ZERO, _mat.k_wood],
		["Pommel", Vector3(0.036, 0.044, 0.018), Vector3(0, 0, 0.078), Vector3.ZERO, _mat.k_gold],
		["Guard", Vector3(0.016, 0.1, 0.014), Vector3(0, 0, -0.068), Vector3.ZERO, _mat.k_gold],
		["Ricasso", Vector3(0.0075, 0.05, 0.025), Vector3(0, 0, -0.088), Vector3.ZERO, _mat.blade],
		["Blade", Vector3(0.0075, 0.058, 0.22), Vector3(0, 0, -0.205), Vector3.ZERO, _mat.blade],
		["Swedge", Vector3(0.0078, 0.01, 0.06), Vector3(0, 0.024, -0.285), Vector3.ZERO, _mat.dark_blade], # The false edge along the spine to the clip point.
		_point("Tip", Vector3(0.0075, 0.058, 0.22), Vector3(0, 0, -0.205), 0.055, 0.62, _mat.blade),
	])
	_animate_knife(k.owner, _knife_clips(
		# Pulled up in a reverse grip, tossed into a slow turn and a half, caught with some weight.
		_clip(0.95, {
			"P.pos": [[0, Vector3(0.08, -0.36, 0.1)], [0.2, Vector3(0, -0.03, 0)], [0.27, Vector3(0, -0.01, 0)],
				[0.62, Vector3(0, -0.01, 0)], [0.7, Vector3(0, -0.07, 0.015)], [0.82, Vector3(0, 0.006, 0)], [0.95, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.2, Vector3(-6, 0, 4)], [0.27, Vector3(4, 0, -4)],
				[0.62, Vector3.ZERO], [0.7, Vector3(-14, 0, 2)], [0.95, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [0.27, Vector3.ZERO], [0.45, Vector3(0, 0.2, -0.02)], [0.62, Vector3.ZERO]],
			"G.rot": [[0, Vector3(180, 0, 0)], [0.27, Vector3(180, 0, 0)], [0.62, Vector3(-360, 0, 0), "linear"]],
		}, [[0.0, "knife_draw", -5.0], [0.27, "knife_swing", -10.0], [0.62, "catch", -2.0]]),
		# Sights down the edge, rolls it to the other flat, flips to an ice-pick grip and jabs,
		# then tosses it back round into the normal grip.
		_clip(3.4, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.07, 0.08)], [1.2, Vector3(-0.1, 0.075, 0.06)],
				[1.6, Vector3(-0.08, 0.06, 0.06)], [2.0, Vector3(-0.08, 0.064, 0.06)], [2.2, Vector3(-0.06, 0.09, 0.05)],
				[2.36, Vector3(-0.06, 0.08, 0.01)], [2.46, Vector3(-0.06, 0.09, 0.05)], [2.6, Vector3(-0.06, 0.08, 0.05)],
				[2.8, Vector3(-0.07, 0.09, 0.05)], [3.0, Vector3(-0.07, 0.05, 0.05)], [3.4, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(8, 30, -20)], [1.2, Vector3(25, 30, -60)],
				[1.6, Vector3(-5, -30, 25)], [2.0, Vector3(-3, -32, 27)], [2.2, Vector3(20, -10, 10)],
				[2.36, Vector3(28, -10, 10)], [2.6, Vector3(20, -12, 10)], [2.8, Vector3(10, -16, 10)],
				[3.0, Vector3(-8, -14, 8)], [3.4, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [2.6, Vector3.ZERO], [2.8, Vector3(0, 0.15, -0.01)], [3.0, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [1.2, Vector3.ZERO], [1.6, Vector3(0, 0, 180)], [2.0, Vector3(0, 0, 180)],
				[2.2, Vector3(180, 0, 180)], [2.6, Vector3(180, 0, 180)], [3.0, Vector3(360, 0, 360), "linear"]],
		}, [[0.4, "swap", -12.0], [1.2, "knife_swing", -16.0], [2.0, "knife_swing", -12.0], [2.2, "catch", -6.0],
			[2.36, "knife_swing", -10.0], [2.6, "knife_swing", -12.0], [3.0, "catch", -3.0]]),
		{"G.rot": [[0, Vector3(180, 0, 0)], [0.22, Vector3.ZERO]]},
	))
	return k.owner


## Italian switchblade: long needle blade that snaps open on a button.
func _knife_stiletto() -> Node3D:
	var k := _knife_model("Stiletto", Vector3.ZERO, [
		["Handle", Vector3(0.02, 0.026, 0.125), Vector3.ZERO, Vector3.ZERO, _mat.k_black],
		["Bolster", Vector3(0.022, 0.028, 0.01), Vector3(0, 0, -0.062), Vector3.ZERO, _mat.accent],
		["Button", Vector3(0.008, 0.006, 0.012), Vector3(0, 0.015, -0.03), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.004, 0.02, 0.15), Vector3(0, 0, -0.137), Vector3.ZERO, _mat.blade, "K"],
		_point("Tip", Vector3(0.004, 0.02, 0.15), Vector3(0, 0, -0.137), 0.03, 0.5, _mat.blade) + ["K"],
	], Vector3(0, 0, -0.062))
	_animate_knife(k.owner, _knife_clips(_draw_switch(), _insp_switch(), _quick_fold()), {"K": "Pivot/Gun/BladeHinge"})
	return k.owner


## Kunai (after Wraith's heirloom): a broad, dark leaf blade studded with glowing dots, a
## long engraved handle, and an angular loop at the pommel it spins round your finger by.
## Held Apex style with the blade pointing left across the screen. Starting to sprint, it
## spins a turn and a half in the hand (like its draw, slower) and is caught the other way
## round (the loop pointing left, the blade back behind the fist); stopping, it spins back to
## the blade-left hold. Those are its "sprint" and "sprint_end" clips (_add_twirl()).
func _knife_kunai() -> Node3D:
	var parts := [
		# The loop: a squared-off frame round the finger hole.
		["LoopTop", Vector3(0.008, 0.008, 0.042), Vector3(0, 0.017, 0.09), Vector3.ZERO, _mat.k_kunai],
		["LoopBottom", Vector3(0.008, 0.008, 0.042), Vector3(0, -0.017, 0.09), Vector3.ZERO, _mat.k_kunai],
		["LoopBack", Vector3(0.008, 0.042, 0.008), Vector3(0, 0, 0.108), Vector3(0, 0, 0), _mat.k_kunai],
		["LoopFront", Vector3(0.009, 0.03, 0.008), Vector3(0, 0, 0.068), Vector3.ZERO, _mat.k_kunai],
		# Handle: dark, with an engraved metal panel and a glowing stud where it meets the blade.
		["Handle", Vector3(0.016, 0.021, 0.1), Vector3(0, 0, 0.017), Vector3.ZERO, _mat.k_black],
		["Engraving", Vector3(0.0175, 0.012, 0.07), Vector3(0, 0, 0.02), Vector3.ZERO, _mat.gun],
		["Collar", Vector3(0.018, 0.026, 0.01), Vector3(0, 0, -0.035), Vector3.ZERO, _mat.k_kunai],
		# Blade: broad leaf, dark, to a long point.
		["BladeBase", Vector3(0.005, 0.03, 0.03), Vector3(0, 0, -0.054), Vector3.ZERO, _mat.k_kunai],
		["Blade", Vector3(0.005, 0.052, 0.07), Vector3(0, 0, -0.1), Vector3.ZERO, _mat.k_kunai],
		["BladeTaper", Vector3(0.005, 0.036, 0.045), Vector3(0, 0, -0.155), Vector3.ZERO, _mat.k_kunai],
		_point("Tip", Vector3(0.005, 0.036, 0.045), Vector3(0, 0, -0.155), 0.032, 0.5, _mat.k_kunai),
		["EdgeTop", Vector3(0.006, 0.003, 0.11), Vector3(0, 0.025, -0.11), Vector3(-4, 0, 0), _mat.k_dot],
		["EdgeBottom", Vector3(0.006, 0.003, 0.11), Vector3(0, -0.025, -0.11), Vector3(4, 0, 0), _mat.k_dot],
	]
	# Glowing studs, both faces: the blade's two rows, the collar and the loop's corners.
	var studs := [Vector3(0, 0, -0.034), Vector3(0, 0.012, -0.075), Vector3(0, -0.012, -0.075), Vector3(0, 0.016, -0.105),
			Vector3(0, -0.016, -0.105), Vector3(0, 0, -0.09), Vector3(0, 0.01, -0.135), Vector3(0, -0.01, -0.135),
			Vector3(0, 0, -0.16), Vector3(0, 0.017, 0.108), Vector3(0, -0.017, 0.108)]
	for i in studs.size():
		for side: float in [-1.0, 1.0]:
			parts.append(["Stud%d%s" % [i, "L" if side < 0 else "R"], Vector3(0.002, 0.007, 0.007),
					studs[i] + Vector3(side * 0.0035, 0, 0), Vector3.ZERO, _mat.k_dot])
	# Its origin (the pivot draws and inspects spin round) is the middle of the handle, in the fist.
	var k := _knife_model("Kunai", Vector3(0, 0, 0.017), parts)
	var clips := _knife_clips(_draw_ring(), _insp_ring(), _quick_ring())
	var grip := _knife_grip(KUNAI_HOLD)
	_add_twirl(clips)
	_animate_knife(k.owner, clips, {}, grip)
	return k.owner


## Push daggers, one in each fist: the T-handle sits across the palm and the blade
## sticks out between the fingers. The left one rides the free hand (LeftArm/LeftDagger),
## so the free hand stays up for inspects too.
func _knife_daggers() -> Node3D:
	var parts := [
		["Grip", Vector3(0.022, 0.07, 0.024), Vector3.ZERO, Vector3.ZERO, _mat.k_black],
		["Collar", Vector3(0.02, 0.03, 0.014), Vector3(0, 0, -0.03), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.034, 0.09), Vector3(0, 0, -0.08), Vector3.ZERO, _mat.blade],
		_point("Tip", Vector3(0.006, 0.034, 0.09), Vector3(0, 0, -0.08), 0.032, 0.5, _mat.blade),
	]
	var k := _knife_model("ShadowDaggers", Vector3.ZERO, parts)
	var r: Node3D = k.owner
	var left := Node3D.new()
	left.name = "LeftDagger"
	left.position = Vector3(-0.4, -0.06, 0.02) # The free hand.
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	left.basis = mirror * _knife_grip() * mirror
	r.get_node("LeftArm").add_child(left)
	left.owner = r
	for p: Array in parts:
		_knife_part(r, left, p, Vector3.ZERO)
	_animate_knife(r, _knife_clips(
		# Both fists come up, punch out and twirl the daggers.
		_clip(0.7, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.2, Vector3(0, -0.02, 0)], [0.32, Vector3(0, 0.01, -0.04)],
				[0.45, Vector3.ZERO], [0.7, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.2, Vector3(-5, 0, 0)], [0.32, Vector3(6, 0, 0)], [0.7, Vector3.ZERO]],
			"L.pos": [[0, KNIFE_LEFT_HIDDEN], [0.25, Vector3.ZERO], [0.37, Vector3(0, 0.01, -0.04)], [0.5, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.3, Vector3.ZERO], [0.6, Vector3(0, 0, 360)]],
			"D.rot": [[0, Vector3.ZERO], [0.35, Vector3.ZERO], [0.65, Vector3(0, 0, -360)]],
		}, [[0.0, "knife_draw", -6.0], [0.32, "knife_swing", -12.0], [0.6, "catch", -6.0]]),
		# Turns both fists to show the blades, twirls each, turns them over.
		_clip(2.6, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.06, 0.05, 0.03)], [1.2, Vector3(-0.06, 0.055, 0.03)],
				[1.5, Vector3(-0.05, 0.05, 0.03)], [2.2, Vector3(-0.05, 0.054, 0.03)], [2.6, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 25, -20)], [1.2, Vector3(12, 27, -22)],
				[1.5, Vector3(5, -20, 25)], [2.2, Vector3(4, -22, 27)], [2.6, Vector3.ZERO]],
			"L.pos": [[0, Vector3.ZERO], [0.3, Vector3(0.06, 0.05, 0.03)], [2.2, Vector3(0.05, 0.054, 0.03)], [2.6, Vector3.ZERO]],
			"L.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, -25, 20)], [1.2, Vector3(12, -27, 22)],
				[1.5, Vector3(5, 20, -25)], [2.2, Vector3(4, 22, -27)], [2.6, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [1.0, Vector3(0, 0, 360)]],
			"D.rot": [[0, Vector3.ZERO], [0.8, Vector3.ZERO], [1.2, Vector3(0, 0, -360)]],
		}, [[0.6, "knife_swing", -14.0], [0.8, "knife_swing", -14.0], [1.0, "catch", -7.0], [1.2, "catch", -7.0]]),
		{"G.rot": [[0, Vector3(0, 0, -360)], [0.2, Vector3.ZERO]]},
		false,
	), {"D": "LeftArm/LeftDagger"})
	return r


## A knife from a parts list: [name, size, pos, rot, material] built pointing straight
## ahead (rig space, fist at the origin). "Ring" makes a finger ring (size.x/y = inner/outer
## radius). A sixth element "K" puts the part on the folding blade's hinge at `hinge_at`.
func _knife_model(rig_name: String, pivot: Vector3, parts: Array, hinge_at: Variant = null) -> Node3D:
	var k := _knife_rig(rig_name, pivot)
	var r: Node3D = k.owner
	var hinge: Node3D = _hinge(k, "BladeHinge", hinge_at) if hinge_at != null else null
	for p: Array in parts:
		var on_hinge := p.has("K") # On the folding blade's hinge.
		if String(p[0]).begins_with("Ring"):
			_ring(k, p[0], p[2], p[1].x, p[1].y, p[4])
		else:
			_knife_part(r, hinge if on_hinge else k, p, (hinge_at as Vector3) if on_hinge else k.position)
	return k


## One knife part ([name, size, pos, rot, material, markers...]) on `parent`, which sits at
## `origin`: a box, or a point (_point()'s "W" marker).
func _knife_part(r: Node3D, parent: Node3D, p: Array, origin: Vector3) -> void:
	if p.has("W"):
		_wedge(r, parent, p[0], p[1], p[2] - origin, p[3], p[p.find("W") + 1], p[4])
	else:
		_box(r, parent, p[0], p[1], p[2] - origin, p[3], p[4])


## A blade's point: a wedge off the front of a blade box (its `size` and centre `pos`,
## pointing -Z), `length` long, the blade's own height and thickness, so it carries straight
## on from it. `apex` is how far up the blade's front end the point is: 1 = level with the
## spine (a drop point, the edge sweeping up to it), 0.5 = on the centreline (a dagger),
## lower for a clip point. `rot` turns it with a blade box that's turned (the karambit's hook).
func _point(n: String, size: Vector3, pos: Vector3, length: float, apex: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> Array:
	var forward := Basis.from_euler(rot * (PI / 180.0)) * Vector3.FORWARD
	return [n, Vector3(size.x, size.y, length), pos + forward * (size.z + length) * 0.5, rot, mat, "W", apex]


## A wedge (a triangular prism) pointing -Z: `size` is its thickness (X), the height of its
## back end (Y) and its length (Z); the point is `apex` of the way up the back end.
func _wedge(r: Node, parent: Node, n: String, size: Vector3, pos: Vector3, rot: Vector3, apex: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var prism := PrismMesh.new()
	prism.size = Vector3(size.y, size.z, size.x) # Its base across the blade, its apex forward, its depth the thickness.
	prism.left_to_right = apex
	mi.mesh = prism
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The prism's +Y (to the apex) forward (-Z), its base (X) up the blade (+Y).
	mi.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT), pos)
	parent.add_child(mi)
	mi.owner = r
	return mi


# --- Knife flourishes ----------------------------------------------------------------------
# Shared draws, inspects and quick-draw flair. Each returns a fresh clip. Keys on G are in
# the knife's own frame (blade along -Z), so they work whatever the grip.

## Flip toss: two end-over-end spins up out of the hand and a snap catch.
func _draw_toss() -> Dictionary:
	return _clip(0.7, {
		"P.pos": [[0, Vector3(0.1, -0.35, 0.1)], [0.18, Vector3(0, -0.04, 0)], [0.45, Vector3(0, -0.03, 0)],
			[0.5, Vector3(0, -0.06, 0.01)], [0.62, Vector3(0, 0.005, 0)], [0.7, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, -20, -30)], [0.18, Vector3(-5, 0, 0)], [0.45, Vector3.ZERO],
			[0.5, Vector3(-8, 0, 0)], [0.7, Vector3.ZERO]],
		"G.pos": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.32, Vector3(0, 0.17, -0.02)], [0.46, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.46, Vector3(720, 0, 0), "linear"]],
	}, [[0.0, "knife_draw", -6.0], [0.46, "catch", -4.0]])


## Tossed straight up, barrel-rolling twice around the blade, caught.
func _draw_roll() -> Dictionary:
	return _clip(0.8, {
		"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.15, Vector3(0, -0.03, 0)], [0.5, Vector3(0, -0.02, 0)],
			[0.54, Vector3(0, -0.055, 0.01)], [0.66, Vector3(0, 0.005, 0)], [0.8, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, -20, -30)], [0.15, Vector3(-5, 0, 0)], [0.5, Vector3.ZERO],
			[0.54, Vector3(-8, 0, 0)], [0.8, Vector3.ZERO]],
		"G.pos": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.32, Vector3(0, 0.15, 0)], [0.5, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.5, Vector3(0, 0, -720), "linear"]],
	}, [[0.0, "knife_draw", -6.0], [0.15, "knife_swing", -14.0], [0.5, "catch", -4.0]])


## Comes up spinning twice around the finger ring, then snaps still.
func _draw_ring() -> Dictionary:
	return _clip(0.8, {
		"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.15, Vector3(0, -0.02, 0)], [0.55, Vector3(0, -0.02, 0)],
			[0.6, Vector3(0, -0.045, 0.01)], [0.7, Vector3(0, 0.005, 0)], [0.8, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, -20, -30)], [0.15, Vector3(-5, 0, 0)], [0.55, Vector3(-5, 0, 0)],
			[0.6, Vector3(-10, 0, 0)], [0.8, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.56, Vector3(-720, 0, 0)]],
	}, [[0.0, "knife_draw", -6.0], [0.15, "knife_swing", -12.0], [0.56, "catch", -4.0]])


## Switchblade: thumbs the button and the blade snaps open with no wrist work, then a shake.
func _draw_switch() -> Dictionary:
	return _clip(0.7, {
		"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.22, Vector3(0, -0.02, 0)], [0.3, Vector3(0, -0.02, 0)],
			[0.34, Vector3(0, -0.012, -0.012)], [0.45, Vector3(0, -0.004, 0.004)], [0.7, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, -20, -30)], [0.22, Vector3(-5, 0, 0)], [0.3, Vector3(-5, 0, 0)],
			[0.34, Vector3(4, 0, 3)], [0.42, Vector3(-3, 0, -2)], [0.5, Vector3(1, 0, 1)], [0.7, Vector3.ZERO]],
		"K.rot": [[0, Vector3(178, 0, 0)], [0.3, Vector3(178, 0, 0)], [0.35, Vector3.ZERO, "linear"]],
	}, [[0.29, "dry_fire", -8.0], [0.35, "knife_draw", -5.0]])


## Rolls around the blade, turns it over, then tosses it end over end and catches it.
func _insp_roll_toss() -> Dictionary:
	return _clip(2.9, {
		"P.pos": [[0, Vector3.ZERO], [0.35, Vector3(-0.1, 0.06, 0.05)], [1.05, Vector3(-0.1, 0.066, 0.05)],
			[1.4, Vector3(-0.08, 0.06, 0.04)], [1.85, Vector3(-0.08, 0.062, 0.042)], [2.0, Vector3(-0.08, 0.075, 0.04)],
			[2.36, Vector3(-0.085, 0.045, 0.05)], [2.5, Vector3(-0.085, 0.058, 0.048)], [2.9, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(10, 25, -10)], [1.05, Vector3(12, 28, -12)],
			[1.4, Vector3(10, -40, 20)], [1.85, Vector3(8, -42, 22)], [2.0, Vector3(2, -32, 16)],
			[2.36, Vector3(16, -28, 14)], [2.5, Vector3(10, -24, 12)], [2.9, Vector3.ZERO]],
		"G.pos": [[0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.18, Vector3(0, 0.16, -0.01)], [2.36, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.4, Vector3.ZERO], [1.05, Vector3(0, 0, 720)], [2.0, Vector3(0, 0, 720)],
			[2.36, Vector3(-360, 0, 720), "linear"]],
	}, [[0.4, "knife_swing", -14.0], [2.0, "knife_swing", -12.0], [2.36, "catch", -6.0]])


## Shows the flat of the blade, turns it over, rolls it, then tosses it end over end.
func _insp_show_toss() -> Dictionary:
	return _clip(3.0, {
		"P.pos": [[0, Vector3.ZERO], [0.35, Vector3(-0.1, 0.05, 0.05)], [1.2, Vector3(-0.1, 0.056, 0.05)],
			[1.5, Vector3(-0.09, 0.05, 0.05)], [2.1, Vector3(-0.09, 0.064, 0.05)], [2.5, Vector3(-0.09, 0.038, 0.055)],
			[2.62, Vector3(-0.09, 0.05, 0.05)], [3.0, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(10, 20, -80)], [1.2, Vector3(12, 22, -78)],
			[1.5, Vector3(5, -30, 30)], [2.1, Vector3(2, -30, 28)], [2.5, Vector3(14, -28, 30)],
			[2.62, Vector3(6, -30, 30)], [3.0, Vector3.ZERO]],
		"G.pos": [[0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.3, Vector3(0, 0.15, -0.01)], [2.5, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [1.6, Vector3.ZERO], [2.0, Vector3(0, 0, 360)], [2.1, Vector3(0, 0, 360)],
			[2.5, Vector3(-360, 0, 360), "linear"]],
	}, [[1.6, "knife_swing", -14.0], [2.1, "knife_swing", -12.0], [2.5, "catch", -5.0]])


## Spin round the finger ring, show the curve, spin back the other way.
func _insp_ring() -> Dictionary:
	return _clip(3.0, {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [0.5, Vector3(-0.08, 0.054, 0.05)],
			[0.9, Vector3(-0.08, 0.042, 0.05)], [1.3, Vector3(-0.08, 0.05, 0.05)], [1.55, Vector3(-0.05, 0.06, 0.04)],
			[2.2, Vector3(-0.05, 0.05, 0.04)], [2.6, Vector3(-0.05, 0.058, 0.04)], [3.0, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 30, -15)], [0.9, Vector3(14, 30, -15)], [1.3, Vector3(10, 32, -15)],
			[1.55, Vector3(0, -35, 30)], [2.2, Vector3(5, -35, 30)], [2.6, Vector3(0, -37, 30)], [3.0, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [0.9, Vector3(-360, 0, 0)], [1.7, Vector3(-360, 0, 0)],
			[2.2, Vector3(0, 0, 0)]],
	}, [[0.5, "knife_swing", -12.0], [0.9, "catch", -6.0], [1.7, "knife_swing", -12.0], [2.2, "catch", -6.0]])


## Switchblade: eases the blade shut, pops it open, then shut and pop again, faster.
func _insp_switch() -> Dictionary:
	return _clip(2.8, {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [1.3, Vector3(-0.08, 0.052, 0.05)],
			[1.36, Vector3(-0.08, 0.056, 0.042)], [1.5, Vector3(-0.08, 0.05, 0.05)], [2.2, Vector3(-0.08, 0.05, 0.05)],
			[2.26, Vector3(-0.08, 0.056, 0.042)], [2.4, Vector3(-0.08, 0.05, 0.05)], [2.8, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 30, -15)], [1.3, Vector3(12, 30, -15)], [1.36, Vector3(4, 30, -12)],
			[1.5, Vector3(10, 30, -15)], [2.2, Vector3(10, 28, -15)], [2.26, Vector3(3, 28, -12)], [2.4, Vector3(10, 28, -15)],
			[2.8, Vector3.ZERO]],
		"K.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [1.1, Vector3(178, 0, 0)], [1.3, Vector3(178, 0, 0)],
			[1.35, Vector3.ZERO, "linear"], [1.75, Vector3.ZERO], [2.05, Vector3(178, 0, 0)], [2.2, Vector3(178, 0, 0)],
			[2.25, Vector3.ZERO, "linear"]],
	}, [[1.1, "mag_out", -12.0], [1.29, "dry_fire", -8.0], [1.35, "knife_draw", -6.0], [2.05, "mag_out", -12.0],
		[2.19, "dry_fire", -8.0], [2.25, "knife_draw", -6.0]])


func _quick_half_roll() -> Dictionary:
	return {"G.rot": [[0, Vector3(0, 0, -180)], [0.18, Vector3.ZERO]]}


func _quick_roll() -> Dictionary:
	return {"G.rot": [[0, Vector3(0, 0, -360)], [0.2, Vector3.ZERO]]}


func _quick_ring() -> Dictionary:
	return {"G.rot": [[0, Vector3(-360, 0, 0)], [0.2, Vector3.ZERO]]}


func _quick_fold() -> Dictionary:
	return {"K.rot": [[0, Vector3(180, 0, 0)], [0.14, Vector3.ZERO]]}


## Every draw after the first: rises out of the holster pose (the same offset the
## WeaponManager lowers to), overshoots a touch and settles.
func _quick_draw(length: float, sfx: Array, extra: Dictionary = {}) -> Dictionary:
	var tracks := {
		"P.pos": [[0, Vector3(0.02, -0.25, 0.05)], [length * 0.6, Vector3(0, 0.008, -0.005)], [length, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, 10, 20)], [length * 0.6, Vector3(4, -1, -2)], [length, Vector3.ZERO]],
	}
	tracks.merge(extra)
	return _clip(length, tracks, sfx)


## Gun ducks down and left while the knife does a quick melee.
func _melee_lower() -> Dictionary:
	return _clip(0.5, {
		"P.pos": [[0, Vector3.ZERO], [0.08, Vector3(-0.06, -0.3, 0.06)], [0.36, Vector3(-0.06, -0.3, 0.06)], [0.5, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.08, Vector3(-45, 25, 35)], [0.36, Vector3(-45, 25, 35)], [0.5, Vector3.ZERO]],
	})


# --- Animation building ---------------------------------------------------------------

func _clip(length: float, tracks: Dictionary, sfx: Array = []) -> Dictionary:
	return {length = length, tracks = tracks, sfx = sfx}


## Copy of a key dictionary with one extra key appended per track, then rest at `end`.
func _with_end(base: Dictionary, end: float, extra: Dictionary) -> Dictionary:
	var out := {}
	for k: String in base:
		var keys: Array = base[k].duplicate()
		if extra.has(k):
			keys.append(extra[k])
		keys.append([end, Vector3.ZERO])
		out[k] = keys
	return out


## base keys followed by the extra keys for the same track (extra tracks are added as-is).
func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := {}
	for k: String in base:
		out[k] = base[k].duplicate()
	for k: String in extra:
		if out.has(k):
			out[k].append_array(extra[k])
		else:
			out[k] = extra[k]
	return out


## Builds an AnimationPlayer on the rig. Every clip gets a track for every animated
## node (rest keys where the clip doesn't move it) so clips blend cleanly.
## `hinges` adds extra animated nodes (alias -> path) with position and rotation tracks.
## Each gun's own feel, by rig name:
##   roll   degrees the gun rolls towards the left hand while it cocks (the charging handle or
##          slide turned to the hand, so it never goes through the gun; a handle on the right side,
##          the Vanta's and DMR's, has the gun rolled clockwise, -70, so that side faces down to the arm
##          coming up from below; the AK and Negev roll counter-clockwise instead (CS2's AK draw) and the
##          hand reaches over the top to it ("hand": where it holds the handle from). Never through the gun.)
##   drift  extra motion while it's turned for the handle, so it travels rather than spinning in
##          place: pos (m) and rot (degrees: pitch, yaw) on the way in, swing back the other way
##          through the pull
##   tilt   extra turn (degrees) as the fresh magazine goes home: a rock, a cant, a shove
##   slap   where the palm slaps the magazine home, from where it holds it
##   punch  how hard the reload cues kick the camera (viewmodel_rig.gd RELOAD_PUNCH)
##   inspect  a CS2-style inspect (_cs2_inspect()): how far it turns to show each side, how
##          high it's lifted, its pace, and its beat: "tap" the mag, "magcheck" (pull it and
##          seat it) or "chamber" (ease the bolt or charging handle back and let it go)
## Guns without an inspect here keep their own (the pistols' spins, the shotguns').
const GUN_STYLE := {
	"Carbine": {roll = -70.0, tilt = Vector3(-6, 0, 4), slap = Vector3(0, 0.025, 0), punch = 1.0,
		inspect = {yaw = 55.0, roll = -16.0, flip_yaw = -24.0, flip_roll = 42.0, lift = 0.05, beat = "chamber", pace = 1.0}},
	"SMG": {roll = 18.0, tilt = Vector3(0, 0, -10), slap = Vector3(0.01, 0.015, -0.01), punch = 0.7,
		inspect = {yaw = 62.0, roll = -24.0, flip_yaw = -30.0, flip_roll = 55.0, lift = 0.04, beat = "magcheck", pace = 0.85}},
	"M4A4": {roll = 26.0, tilt = Vector3(-4, 4, 0), slap = Vector3(0, 0.03, 0), punch = 1.0,
		inspect = {yaw = 58.0, roll = -26.0, flip_yaw = -26.0, flip_roll = 46.0, lift = 0.06, beat = "tap", pace = 1.0}},
	"AK47": {roll = 75.0, drift = {pos = Vector3(-0.035, 0.03, 0.04), rot = Vector3(12, 16, 0), swing = Vector3(-8, -14, 0)}, hand = Vector3(0.015, 0.045, 0.01), tilt = Vector3(10, 0, 6), slap = Vector3(0, 0.0, -0.015), punch = 1.25,
		inspect = {yaw = 50.0, roll = -12.0, flip_yaw = -20.0, flip_roll = 60.0, lift = 0.05, beat = "magcheck", pace = 1.05}},
	"DMR": {roll = -70.0, tilt = Vector3(-8, 0, 0), slap = Vector3(0, 0.035, 0), punch = 1.1,
		inspect = {yaw = 66.0, roll = -14.0, flip_yaw = -18.0, flip_roll = 38.0, lift = 0.07, beat = "chamber", pace = 1.1}},
	"Negev": {roll = 85.0, drift = {pos = Vector3(-0.03, 0.02, 0.05), rot = Vector3(9, 12, 0), swing = Vector3(-6, -10, 0)}, hand = Vector3(0.015, 0.045, 0.01), tilt = Vector3(6, 0, -6), slap = Vector3(0, 0.02, 0), punch = 1.5,
		inspect = {yaw = 45.0, roll = -10.0, flip_yaw = -16.0, flip_roll = 32.0, lift = 0.03, beat = "tap", pace = 1.25}},
	"Sniper": {punch = 1.3, # Heavy and slow: lifted high, a long look, and the mag pulled and checked.
		inspect = {yaw = 70.0, roll = -14.0, flip_yaw = -20.0, flip_roll = 34.0, lift = 0.08, beat = "magcheck", pace = 1.3}},
	"SSG": {punch = 1.0, # Light and quick: a fast flick right over onto its side, the bolt eased back.
		inspect = {yaw = 52.0, roll = -30.0, flip_yaw = -34.0, flip_roll = 72.0, lift = 0.03, beat = "chamber", pace = 0.8}},
	"Sidearm": {roll = 20.0, tilt = Vector3(0, 0, 10), slap = Vector3(0, 0.03, 0.01), punch = 0.8},
	"DesertEagle": {roll = 24.0, tilt = Vector3(-6, 0, 8), slap = Vector3(0, 0.03, 0), punch = 1.2},
	"Revolver": {punch = 0.9},
	"Shotgun": {punch = 1.1},
	"Olympia": {punch = 1.2},
}


## A CS2-style inspect from a GUN_STYLE entry: the gun comes up and turns to show its left
## side, held there with a slow drift; rolls over to show the right side and the top, held
## again while it does its beat (tap / magcheck / chamber); then settles back with a small
## overshoot. Unhurried, eased throughout (the keys are smoothed when baked), and it starts
## and ends at rest, so holding inspect loops it cleanly.
func _cs2_inspect(s: Dictionary, bolt_turns: bool) -> Dictionary:
	var p: float = s.get("pace", 1.0)
	var lift: float = s.lift
	var a := Vector3(8, s.yaw, s.roll)
	var b := Vector3(-8, s.flip_yaw, s.flip_roll)
	var tracks := {
		"P.pos": [[0, Vector3.ZERO], [0.55 * p, Vector3(-0.1, lift, 0.08)], [1.45 * p, Vector3(-0.1, lift + 0.006, 0.085)],
			[2.0 * p, Vector3(-0.04, lift * 0.6, 0.05)], [2.85 * p, Vector3(-0.04, lift * 0.65, 0.052)],
			[3.35 * p, Vector3(0, -0.004, 0.004)], [3.7 * p, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.55 * p, a], [1.45 * p, a + Vector3(-2, 3, -3)], [2.0 * p, b], [2.85 * p, b + Vector3(-2, -3, 3)],
			[3.35 * p, Vector3(-1, 0, -3)], [3.7 * p, Vector3.ZERO]],
	}
	var sfx: Array = [[0.05, "swap", -13.0], [1.5 * p, "swap", -14.0]]
	match s.beat:
		"tap":
			sfx.append([2.4 * p, "mag_in", -10.0])
		"magcheck":
			tracks["M.pos"] = [[0, Vector3.ZERO], [2.05 * p, Vector3.ZERO], [2.25 * p, Vector3(0, -0.05, 0.01)],
				[2.5 * p, Vector3(0, -0.05, 0.01)], [2.65 * p, Vector3.ZERO]]
			sfx.append_array([[2.22 * p, "mag_out", -12.0], [2.63 * p, "mag_in", -9.0]])
		"chamber":
			tracks["B.pos"] = [[0, Vector3.ZERO], [2.15 * p, Vector3.ZERO], [2.32 * p, Vector3(0, 0, 0.035)],
				[2.5 * p, Vector3(0, 0, 0.035)], [2.6 * p, Vector3.ZERO]]
			if bolt_turns: # A bolt-action's bolt lifts before it comes back.
				tracks["B.rot"] = [[0, Vector3.ZERO], [2.08 * p, Vector3.ZERO], [2.15 * p, Vector3(0, 0, 75)],
					[2.55 * p, Vector3(0, 0, 75)], [2.64 * p, Vector3.ZERO]]
			sfx.append_array([[2.32 * p, "slide_back", -12.0], [2.6 * p, "slide_home", -10.0]])
	return _clip(3.7 * p, tracks, sfx)


## Linear sample of [[time, Vector3], ...] keys at `x`.
func _sample(keys: Array, x: float) -> Vector3:
	if keys.is_empty():
		return Vector3.ZERO
	if x <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if x <= keys[i][0]:
			var k0: Array = keys[i - 1]
			var k1: Array = keys[i]
			return (k0[1] as Vector3).lerp(k1[1], (x - k0[0]) / maxf(k1[0] - k0[0], 0.0001))
	return keys[-1][1]


## Adds `extra` to a track over a window: easing in over `ramp` before `from`, held to `to`,
## easing out over `ramp` after. (On top of whatever the clip already does there.)
func _add_over(t: Dictionary, track: String, extra: Vector3, from: float, to: float, ramp: float, length: float) -> void:
	var keys: Array = t.get(track, [[0.0, Vector3.ZERO]]).duplicate()
	keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var times := {}
	for k: Array in keys:
		times[float(k[0])] = true
	# It's always all the way back out by the end of the clip (a clip holds its last frame, so
	# anything left over would stay on: a gun left tilted after its draw).
	var out_end := minf(to + ramp, length)
	var hold_end := minf(to, out_end - 0.08)
	for x: float in [from - ramp, from, hold_end, out_end, length]:
		times[clampf(x, 0.0, length)] = true
	var sorted: Array = times.keys()
	sorted.sort()
	var out: Array = []
	for x: float in sorted:
		var w := clampf((x - (from - ramp)) / maxf(ramp, 0.001), 0.0, 1.0) \
				* (1.0 - clampf((x - hold_end) / maxf(out_end - hold_end, 0.001), 0.0, 1.0))
		out.append([x, _sample(keys, x) + extra * w])
	t[track] = out


## Puts each hand (its box and its wrist marker) on a pivot of its own under Arms, at the
## origin so nothing moves: LeftArm and RightArm. (The pump shotgun already has LeftArm.)
func _split_hands(r: Node3D) -> void:
	var arms := r.get_node("Pivot/Arms")
	for side: String in ["Left", "Right"]:
		var hand := arms.get_node_or_null(side + "Hand")
		var wrist := arms.get_node_or_null(side + "Wrist")
		if hand == null or arms.has_node(side + "Arm"):
			continue
		var pivot := Node3D.new()
		pivot.name = side + "Arm"
		arms.add_child(pivot)
		pivot.owner = r
		for n: Node in [hand, wrist]:
			if n != null:
				n.reparent(pivot, false)
				n.owner = r


## Hand work for a gun clip, worked out from what its parts do (unless the clip keys the
## hand itself):
##   magazine (M) moving: the left hand reaches down to it, rides it out and off screen, comes
##     back with it, pushes it home and gives it a slap, then goes back to the handguard;
##   slide / charging handle / pump (B) pulled: the left hand goes to it and pulls it with it
##     (on a pump it's already there, so it just rides along);
##   a bolt-action's bolt (B turning): the right hand leaves the grip to work it.
##   an inspect's magazine tap ("mag_in" in an inspect): the left hand taps the magazine.
func _auto_hands(r: Node3D, c: Dictionary, bolt_path: String, clip_name: String) -> void:
	var shell := clip_name.begins_with("reload_shell")
	var style: Dictionary = GUN_STYLE.get(r.name, {})
	var reload := clip_name.begins_with("reload")
	var t: Dictionary = c.tracks
	var length: float = c.length
	var gun_pos: Vector3 = (r.get_node("Pivot/Gun") as Node3D).position
	var left := r.get_node_or_null("Pivot/Arms/LeftArm/LeftHand") as Node3D
	var right := r.get_node_or_null("Pivot/Arms/RightArm/RightHand") as Node3D
	var l_keys: Array = []
	var r_keys: Array = []
	var l_free := 0.0 # When the left hand's done with the magazine.
	# The magazine.
	var mag := r.get_node_or_null("Pivot/Gun/Magazine") as Node3D
	if left != null and mag != null and not t.has("L.pos") and t.has("M.pos") and not shell:
		var m: Array = t["M.pos"]
		var window := _moving_window(m)
		if window.x >= 0.0:
			var grab := gun_pos + mag.position + MAG_GRAB - left.position
			l_keys.append([0.0, Vector3.ZERO])
			l_keys.append([maxf(window.x - 0.25, 0.01), Vector3.ZERO])
			l_keys.append([window.x, grab])
			for k: Array in m:
				if k[0] > window.x and k[0] <= window.y:
					l_keys.append([k[0], grab + (k[1] as Vector3)])
			l_keys.append([minf(window.y + 0.07, length), grab + (style.get("slap", Vector3(0, 0.025, 0)) as Vector3)]) # The slap.
			if reload and style.has("tilt"): # This gun's own move as the mag goes home.
				_add_over(t, "P.rot", style.tilt, window.y - 0.12, window.y + 0.05, 0.18, length)
			l_free = window.y + 0.07
	# An inspect that taps the magazine (its "mag_in" knock): the left hand goes and taps it.
	if left != null and mag != null and not t.has("L.pos") and l_keys.is_empty() and clip_name == "inspect":
		var grab := gun_pos + mag.position + MAG_GRAB - left.position
		for s: Array in c.sfx:
			if s[1] == "mag_in":
				var at: float = s[0]
				l_keys.append_array([[maxf(at - 0.18, 0.0), Vector3.ZERO], [at - 0.02, grab + Vector3(0, -0.02, 0)],
						[at, grab + Vector3(0, 0.01, 0)], [at + 0.12, grab], [minf(at + 0.32, length), Vector3.ZERO]])
		if not l_keys.is_empty():
			l_keys.push_front([0.0, Vector3.ZERO])
			l_free = l_keys[-1][0]
	# The slide, charging handle, pump or bolt.
	var bolt := r.get_node_or_null(bolt_path) as Node3D if bolt_path != "" else null
	if bolt != null and (t.has("B.pos") or t.has("B.rot")):
		var window := _moving_window(t.get("B.pos", []))
		var rot_window := _moving_window(t.get("B.rot", []))
		if rot_window.x >= 0.0 and (window.x < 0.0 or rot_window.x < window.x):
			window.x = rot_window.x
		window.y = maxf(window.y, rot_window.y)
		if window.x >= 0.0:
			var at := gun_pos + bolt.position
			var b_pos: Array = t.get("B.pos", [])
			if r.name in ["Sniper", "SSG"]: # Bolt-action: the right hand works it.
				if right != null and not t.has("R.pos"):
					var target := at + Vector3(0.03, -0.005, 0.0) - right.position
					r_keys = [[0.0, Vector3.ZERO], [maxf(window.x - 0.12, 0.01), Vector3.ZERO], [window.x, target]]
					for k: Array in b_pos:
						if k[0] > window.x and k[0] <= window.y:
							r_keys.append([k[0], target + (k[1] as Vector3) + Vector3(0, 0.012, 0)])
					r_keys.append([minf(window.y + 0.05, length), target])
					r_keys.append([minf(window.y + 0.2, length), Vector3.ZERO])
			elif left != null and not t.has("L.pos"):
				var near := left.position.distance_to(at) < 0.08 # A pump: the hand's already on it.
				# Which side the handle is on: out to the right (the AK's), the hand takes it from that side;
				# on top or to the left, from the left. Either way from outside the gun.
				var side := 1.0 if (at - gun_pos).x > 0.02 else -1.0
				# Well clear of the gun: 6 cm out from a side handle, up and to the left of one on top.
				# (A gun can say where instead, GUN_STYLE "hand": the AK reaches over the top, CS2 style.)
				var grip: Vector3 = style.get("hand", Vector3(0.06, 0.0, 0.01) if side > 0.0 else Vector3(-0.05, 0.03, 0.01))
				var away := Vector3(grip.x, grip.y, 0.0).normalized() # The way the hand comes at the handle from.
				var target := Vector3.ZERO if near else at + grip - left.position
				if not near and clip_name != "inspect": # Rolled towards the hand, so it reaches the handle, not through the gun.
					var roll: float = style.get("roll", 22.0)
					# The further it turns, the earlier and longer the turn, so it's over before the hand gets there.
					_add_over(t, "P.rot", Vector3(0, 0, roll), window.x - absf(roll) / 900.0, window.y, 0.18 + absf(roll) / 300.0, length)
					if style.has("drift"): # Pulled in and up, muzzle swung round, then back the other way through the pull.
						var drift: Dictionary = style.drift
						var lead := window.x - absf(roll) / 900.0
						_add_over(t, "P.pos", drift.pos, lead, window.y, 0.22 + absf(roll) / 300.0, length)
						_add_over(t, "P.rot", drift.rot, lead - 0.05, window.x, 0.2, length)
						_add_over(t, "P.rot", drift.swing, lerpf(window.x, window.y, 0.5), window.y, 0.15, length)
				var from: Vector3 = l_keys[-1][1] if not l_keys.is_empty() else Vector3.ZERO
				var start := maxf(maxf(window.x - 0.22, l_free), 0.0)
				if l_keys.is_empty():
					l_keys.append([0.0, Vector3.ZERO])
				if start > l_keys[-1][0] + 0.001:
					l_keys.append([start, from])
				if not near: # Round the outside of the gun on the way: out to the side first, then over the top.
					var over := target + away * 0.05 + Vector3(0, 0, 0.02)
					var out := target + away * 0.09
					out.z = lerpf(from.z, over.z, 0.5)
					if away.y < 0.5: # From the side: come up from where the hand was, not over the top.
						out.y = lerpf(from.y, over.y, 0.5)
					var t_over := maxf(window.x - 0.07, start + 0.04)
					l_keys.append([lerpf(start, t_over, 0.5), out])
					l_keys.append([t_over, over])
				l_keys.append([maxf(window.x, start + 0.04), target])
				for k: Array in b_pos:
					if k[0] > window.x and k[0] <= window.y:
						l_keys.append([k[0], target + (k[1] as Vector3)])
				if not near: # And back down the outside of the gun to the handguard, not through it.
					var back := target + away * 0.08
					back.z = target.z * 0.4
					if away.y < 0.5:
						back.y = target.y * 0.3
					l_keys.append([minf(window.y + 0.12, length), back])
				l_free = window.y
	# Hands back where they belong before the clip ends.
	for pair: Array in [[l_keys, "L.pos"], [r_keys, "R.pos"]]:
		var keys: Array = pair[0]
		if keys.is_empty():
			continue
		var last: float = keys[-1][0]
		if (keys[-1][1] as Vector3).length() > 0.0001:
			keys.append([minf(last + 0.25, length), Vector3.ZERO])
		t[pair[1]] = _clean_keys(keys, length)


## When a part moves in a clip: x = the last key before it leaves rest, y = the key it's back
## at rest (or its last key). (-1, -1) if it never moves.
func _moving_window(keys: Array) -> Vector2:
	var first := -1
	var last := -1
	for i in keys.size():
		if (keys[i][1] as Vector3).length() > 0.0005:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return Vector2(-1, -1)
	var a: float = keys[maxi(first - 1, 0)][0]
	var b: float = keys[mini(last + 1, keys.size() - 1)][0]
	return Vector2(a, b)


## Sorted, strictly increasing in time, and inside the clip.
func _clean_keys(keys: Array, length: float) -> Array:
	keys.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	for k: Array in keys:
		var time := clampf(k[0], 0.0, length)
		if not out.is_empty() and time <= out[-1][0] + 0.001:
			out[-1] = [out[-1][0], k[1]]
			continue
		out.append([time, k[1]])
	return out


func _animate(r: Node3D, clips: Dictionary, bolt_path: String, hinges: Dictionary = {}) -> void:
	var paths := {"P": "Pivot", "G": "Pivot/Gun"}
	if r.has_node("Pivot/Gun/Magazine"):
		paths["M"] = "Pivot/Gun/Magazine"
	if bolt_path != "":
		paths["B"] = bolt_path
	paths.merge(hinges)
	# Guns: each hand on its own pivot (LeftArm / RightArm), so the animations can take a hand
	# off the gun, and the hand work worked out from what the gun parts do (_auto_hands()).
	if r.has_node("Pivot/Arms/RightHand") or r.has_node("Pivot/Arms/LeftArm"):
		_split_hands(r)
		for side: String in ["Left", "Right"]:
			if r.has_node("Pivot/Arms/%sArm" % side) and not paths.has(side.left(1)):
				paths[side.left(1)] = "Pivot/Arms/%sArm" % side
		var style: Dictionary = GUN_STYLE.get(r.name, {})
		if style.has("inspect"): # A CS2-style inspect in this gun's own style.
			clips["inspect"] = _cs2_inspect(style.inspect, r.name in ["Sniper", "SSG"])
		r.set_meta("punch_scale", style.get("punch", 1.0)) # How hard its reload cues kick the camera.
		for clip_name: String in clips:
			_auto_hands(r, clips[clip_name], bolt_path, clip_name)
	var lib := AnimationLibrary.new()
	for clip_name: String in clips:
		var c: Dictionary = clips[clip_name]
		var a := Animation.new()
		a.length = c.length
		if c.has("busy"): # Attacks whose tail plays on after you can act again (see WeaponManager).
			a.set_meta("busy", c.busy)
		for alias: String in paths:
			var node: Node3D = r.get_node(paths[alias])
			_position_track(a, paths[alias], node.position, c.tracks.get(alias + ".pos", []))
			if alias == "P" or alias == "G" or hinges.has(alias):
				_rotation_track(a, paths[alias], node.rotation, c.tracks.get(alias + ".rot", []))
		if not c.sfx.is_empty():
			var t := a.add_track(Animation.TYPE_METHOD)
			a.track_set_path(t, ^".")
			for s: Array in c.sfx:
				a.track_insert_key(t, s[0], {"method": &"play_sfx", "args": [s[1], s[2]]})
		lib.add_animation(clip_name, a)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.add_animation_library("", lib)
	r.add_child(ap)
	ap.owner = r


func _position_track(a: Animation, path: String, rest: Vector3, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath(path))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
	if keys.is_empty():
		keys = [[0.0, Vector3.ZERO]]
	for k: Array in _bake(keys, 0.0003, INF):
		a.position_track_insert_key(t, k[0], rest + k[1])


func _rotation_track(a: Animation, path: String, rest: Vector3, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath(path))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
	if keys.is_empty():
		keys = [[0.0, Vector3.ZERO]]
	var rest_q := Basis.from_euler(rest).get_rotation_quaternion()
	if keys[0][1] is Quaternion: # Already sampled every frame, as turns from rest (a spin no Euler key can follow cleanly).
		for k: Array in keys:
			a.rotation_track_insert_key(t, k[0], rest_q * (k[1] as Quaternion))
		return
	# Baked keys stay <= 30 degrees apart, so the slerp between them never takes the short way round a spin.
	for k: Array in _bake(keys, 0.3, 30.0):
		_rot_key(a, t, k[0], rest_q, k[1])


func _rot_key(a: Animation, t: int, time: float, rest_q: Quaternion, deg: Vector3) -> void:
	var off := Basis.from_euler(deg * (PI / 180.0)).get_rotation_quaternion()
	a.rotation_track_insert_key(t, time, rest_q * off)


## Turns authored keys ([time, offset], or [time, offset, "linear"]) into baked keys.
## The curve is a monotone cubic: it flows through keys that keep heading the same
## way, eases to a stop on holds and turnarounds, and never overshoots a key. (Godot's
## cubic tracks do overshoot: held poses drifted and spins wound backwards before
## starting.) "linear" makes the segment into that key constant speed, for spins in
## the air that snap into a catch. Sampled at BAKE_FPS, then thinned to the samples a
## straight line between neighbours can't stand in for (within `tolerance`).
func _bake(keys: Array, tolerance: float, max_step: float) -> Array:
	keys = keys.duplicate()
	keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var n := keys.size()
	if n < 2:
		return keys
	var slopes: Array[Vector3] = []
	for i in n - 1:
		slopes.append((keys[i + 1][1] - keys[i][1]) / maxf(keys[i + 1][0] - keys[i][0], 0.0001))
	# Fritsch-Butland tangents: zero at holds, turnarounds and both ends.
	var tangents: Array[Vector3] = []
	for i in n:
		var m := Vector3.ZERO
		if i > 0 and i < n - 1:
			var h0: float = keys[i][0] - keys[i - 1][0]
			var h1: float = keys[i + 1][0] - keys[i][0]
			var w0 := 2.0 * h1 + h0
			var w1 := h1 + 2.0 * h0
			for c in 3:
				var s0: float = slopes[i - 1][c]
				var s1: float = slopes[i][c]
				if s0 * s1 > 0.0:
					m[c] = (w0 + w1) / (w0 / s0 + w1 / s1)
		tangents.append(m)
	var samples: Array = []
	for i in n - 1:
		var t0: float = keys[i][0]
		var h: float = keys[i + 1][0] - t0
		if h <= 0.0:
			continue
		var p0: Vector3 = keys[i][1]
		var p1: Vector3 = keys[i + 1][1]
		var linear: bool = keys[i + 1].size() > 2 and keys[i + 1][2] == "linear"
		var steps := maxi(1, ceili(h * BAKE_FPS))
		for s in steps:
			var u := float(s) / steps
			var v := p0.lerp(p1, u)
			if not linear:
				var u2 := u * u
				var u3 := u2 * u
				v = p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + tangents[i] * (h * (u3 - 2.0 * u2 + u)) \
						+ p1 * (3.0 * u2 - 2.0 * u3) + tangents[i + 1] * (h * (u3 - u2))
			samples.append([t0 + h * u, v])
	samples.append([keys[n - 1][0], keys[n - 1][1]])
	# Thin out: drop every sample a straight line from the last kept one covers.
	var out: Array = [samples[0]]
	var anchor := 0
	for j in range(2, samples.size()):
		var a: Array = samples[anchor]
		var b: Array = samples[j]
		var d: Vector3 = (b[1] - a[1]).abs()
		var ok := maxf(d.x, maxf(d.y, d.z)) <= max_step
		for k in range(anchor + 1, j):
			if not ok:
				break
			var f: float = (samples[k][0] - a[0]) / (b[0] - a[0])
			ok = (a[1].lerp(b[1], f) - samples[k][1]).length() <= tolerance
		if not ok:
			anchor = j - 1
			out.append(samples[anchor])
	out.append(samples[samples.size() - 1])
	return out


# --- Node helpers ------------------------------------------------------------------------

func _rig(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	r.set_script(load("res://scripts/weapons/viewmodel_rig.gd"))
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	r.add_child(pivot)
	pivot.owner = r
	return r


## The weapon node, placed at `pivot` (what it spins around). Use _part() for its children.
func _gun(r: Node3D, pivot: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Gun"
	g.position = pivot
	r.get_node("Pivot").add_child(g)
	g.owner = r
	return g


func _arms(r: Node3D) -> Node3D:
	var a := Node3D.new()
	a.name = "Arms"
	r.get_node("Pivot").add_child(a)
	a.owner = r
	return a


## A box on the gun, positioned in viewmodel space.
func _part(gun: Node3D, n: String, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	return _box(gun.owner, gun, n, size, pos - gun.position, rot, mat)


## Animated sub-node of the weapon (folding blade, butterfly handle), placed in viewmodel space.
func _hinge(gun: Node3D, n: String, pos: Vector3) -> Node3D:
	var h := Node3D.new()
	h.name = n
	h.position = pos - gun.position
	gun.add_child(h)
	h.owner = gun.owner
	return h


## Torus on the weapon with its hole along X (a finger ring).
func _ring(gun: Node3D, n: String, pos: Vector3, inner: float, outer: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	mi.mesh = t
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos - gun.position
	mi.rotation_degrees = Vector3(0, 0, 90)
	gun.add_child(mi)
	mi.owner = gun.owner


func _muzzle(gun: Node3D, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Muzzle"
	m.position = pos - gun.position
	gun.add_child(m)
	m.owner = gun.owner


func _box(r: Node, parent: Node, n: String, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	mi.owner = r
	return mi


## An arm from the wrist (a point on the hand's parent, so it follows the hand) up to the
## shoulder: forearm, elbow and upper arm. viewmodel_rig.gd re-solves them every frame;
## this bakes the rest pose. `hip` is the weapon's hip_position (rig space = camera space - hip).
func _arm(r: Node3D, hand_parent: Node3D, side: String, wrist: Vector3, hip: Vector3) -> void:
	var Rig: GDScript = load("res://scripts/weapons/viewmodel_rig.gd")
	var marker := Marker3D.new()
	marker.name = side + "Wrist"
	marker.position = wrist - hand_parent.position
	hand_parent.add_child(marker)
	marker.owner = r
	var shoulder: Vector3 = Rig.SHOULDERS[side] - hip
	# A real forearm's length; the upper arm takes up the rest of the reach (support hands sit
	# far out on long guns) with a little slack so the elbow always bends.
	var fore := 0.29
	var upper := maxf(0.3, wrist.distance_to(shoulder) * 1.06 - fore)
	marker.set_meta("forearm_length", fore)
	marker.set_meta("upper_arm_length", upper)
	var parts: Array[MeshInstance3D] = []
	for part: Array in [["Forearm", 0.075], ["Elbow", 0.088], ["UpperArm", 0.095]]:
		var mi := MeshInstance3D.new()
		mi.name = side + part[0]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(part[1], part[1], part[1] if part[0] == "Elbow" else 1.0) # Bones are scaled to length along Z.
		mi.mesh = mesh
		mi.material_override = _mat.sleeve
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(mi)
		mi.owner = r
		parts.append(mi)
	Rig.solve_arm(parts[0], parts[1], parts[2], hand_parent.position + marker.position, shoulder, Rig.POLES[side], fore, upper)


func _vm_material(path: String, albedo: Color, rough: float, metal: float, emission: Color) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/viewmodel.gdshader")
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("emission", emission)
	ResourceSaver.save(m, path)
	return load(path)


func _save_scene(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("Pack failed for %s: %s" % [path, err])
	ResourceSaver.save(ps, path)
	root.free()
