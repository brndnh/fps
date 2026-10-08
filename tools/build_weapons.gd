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
	_save_scene(_knife_combat(), "res://scenes/weapons/knife.tscn")
	_save_scene(_knife_karambit(), "res://scenes/weapons/knife_karambit.tscn")
	_save_scene(_knife_butterfly(), "res://scenes/weapons/knife_butterfly.tscn")
	_save_scene(_knife_flip(), "res://scenes/weapons/knife_flip.tscn")
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
		display_name = "Carbine", model_scene = load("res://scenes/weapons/carbine.tscn"), sound_prefix = "carbine",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.02,
		fire_mode = 0, rpm = 780.0, damage = 14.0, head_multiplier = 1.75,
		falloff_start = 40.0, falloff_end = 80.0, falloff_min = 0.7,
		mag_size = 28, reserve_ammo = 224, reload_time = 2.4, reload_empty_time = 3.1, reload_commit = 0.7,
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
		display_name = "SMG", model_scene = load("res://scenes/weapons/smg.tscn"), sound_prefix = "smg",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.018,
		fire_mode = 0, rpm = 1000.0, damage = 11.0, head_multiplier = 1.5,
		falloff_start = 20.0, falloff_end = 50.0, falloff_min = 0.6,
		mag_size = 22, reserve_ammo = 220, reload_time = 1.8, reload_empty_time = 2.4, reload_commit = 0.7,
		draw_time = 0.5, quick_draw_time = 0.35, move_speed = 1.0, holster_time = 0.2, ads_time = 0.18, ads_zoom = 1.1, ads_move_speed = 0.7,
		sprint_to_fire_time = 0.18,
		hip_spread = 1.3, ads_spread = 0.0, move_spread = 0.7, air_spread = 1.2,
		bloom_per_shot = 0.08, bloom_max = 0.8, bloom_decay = 6.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.08, recoil_recovery = 12.0,
		view_punch = 0.45,
		hip_position = HIP.smg, ads_position = Vector3(0.0, -0.0745, -0.33),
		kick_back = 0.025, kick_rotation = 2.2, muzzle_flash_size = 0.8, throw_damage = 25.0,
	})

	# Sidearm: Wingman style hand cannon. Semi-auto, big hits, big flip.
	pattern = PackedVector2Array()
	for i in 6:
		pattern.append(Vector2(0.15 if i % 2 == 0 else -0.1, 1.6))
	_save_res(WeaponData.new(), "res://weapons/sidearm.tres", {
		display_name = "Sidearm", model_scene = load("res://scenes/weapons/sidearm.tscn"), sound_prefix = "sidearm",
		bolt_node = ^"Pivot/Gun/Slide", bolt_kick = 0.035,
		fire_mode = 1, rpm = 300.0, damage = 45.0, head_multiplier = 2.0,
		falloff_start = 50.0, falloff_end = 100.0, falloff_min = 0.75,
		mag_size = 6, reserve_ammo = 60, reload_time = 2.1, reload_empty_time = 2.6, reload_commit = 0.7,
		draw_time = 0.42, quick_draw_time = 0.28, move_speed = 1.06, holster_time = 0.2, ads_time = 0.16, ads_zoom = 1.1, ads_move_speed = 0.8,
		sprint_to_fire_time = 0.15,
		hip_spread = 1.6, ads_spread = 0.0, move_spread = 0.9, air_spread = 1.5,
		bloom_per_shot = 0.4, bloom_max = 1.2, bloom_decay = 4.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.2, recoil_recovery = 14.0,
		view_punch = 1.4,
		hip_position = HIP.sidearm, ads_position = Vector3(0.0, -0.0525, -0.34),
		kick_back = 0.05, kick_rotation = 7.0, muzzle_flash_size = 1.3, throw_damage = 20.0,
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
		mag_size = 7, reserve_ammo = 35, reload_time = 2.2, reload_empty_time = 2.6, reload_commit = 0.7,
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
		mag_size = 8, reserve_ammo = 40, reload_time = 2.5, reload_empty_time = 2.5, reload_commit = 0.72,
		draw_time = 0.7, quick_draw_time = 0.3, move_speed = 1.04, holster_time = 0.2, ads_time = 0.2, ads_zoom = 1.15, ads_move_speed = 0.75,
		sprint_to_fire_time = 0.18,
		hip_spread = 0.7, ads_spread = 0.0, move_spread = 1.4, air_spread = 2.2,
		bloom_per_shot = 0.4, bloom_max = 1.6, bloom_decay = 3.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.25, recoil_recovery = 12.0,
		view_punch = 1.6,
		hip_position = HIP.revolver, ads_position = Vector3(0.0, -0.052, -0.34),
		kick_back = 0.06, kick_rotation = 10.0, muzzle_flash_size = 1.4, throw_damage = 25.0,
	})

	# Shotgun: pump action, CS Nova / Apex EVA-ish. 8 pellets, loads a shell at a time.
	pattern = PackedVector2Array()
	for i in 6:
		pattern.append(Vector2(0.25 if i % 2 == 0 else -0.2, 2.6))
	_save_res(WeaponData.new(), "res://weapons/shotgun.tres", {
		display_name = "Shotgun", model_scene = load("res://scenes/weapons/shotgun.tscn"), sound_prefix = "shotgun",
		bolt_node = ^"Pivot/Gun/Pump", bolt_kick = 0.0,
		fire_mode = 1, rpm = 70.0, damage = 11.0, head_multiplier = 1.5, pellets = 8,
		pellet_spread = 5.0, pellet_spread_ads = 3.2, cycle_after_shot = true,
		falloff_start = 8.0, falloff_end = 22.0, falloff_min = 0.35,
		mag_size = 6, reserve_ammo = 32, reload_commit = 0.7,
		shell_reload = true, reload_start_time = 0.4, shell_time = 0.5, reload_end_time = 0.42,
		draw_time = 0.6, quick_draw_time = 0.4, move_speed = 1.0, holster_time = 0.22, ads_time = 0.2, ads_zoom = 1.1, ads_move_speed = 0.65,
		sprint_to_fire_time = 0.2,
		hip_spread = 0.4, ads_spread = 0.0, move_spread = 0.6, air_spread = 1.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = pattern, recoil_scale_ads = 0.85, recoil_jitter = 0.25, recoil_recovery = 16.0,
		view_punch = 2.2,
		hip_position = HIP.shotgun, ads_position = Vector3(0.0, -0.046, -0.36),
		kick_back = 0.06, kick_rotation = 8.0, muzzle_flash_size = 1.6, throw_damage = 30.0,
	})

	# Olympia: over-under double barrel. Two big blasts back to back, then break it open.
	_save_res(WeaponData.new(), "res://weapons/olympia.tres", {
		display_name = "Olympia", model_scene = load("res://scenes/weapons/olympia.tscn"), sound_prefix = "olympia",
		bolt_node = ^"", bolt_kick = 0.0,
		fire_mode = 1, rpm = 300.0, damage = 12.0, head_multiplier = 1.5, pellets = 9,
		pellet_spread = 4.0, pellet_spread_ads = 2.6,
		falloff_start = 10.0, falloff_end = 28.0, falloff_min = 0.35,
		mag_size = 2, reserve_ammo = 24, reload_time = 2.0, reload_empty_time = 2.0, reload_commit = 0.6,
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
		display_name = "DMR", model_scene = load("res://scenes/weapons/dmr.tscn"), sound_prefix = "dmr",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.025,
		fire_mode = 1, rpm = 240.0, damage = 38.0, head_multiplier = 2.0,
		falloff_start = 60.0, falloff_end = 120.0, falloff_min = 0.8,
		mag_size = 10, reserve_ammo = 60, reload_time = 2.5, reload_empty_time = 3.2, reload_commit = 0.7,
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
		mag_size = 30, reserve_ammo = 90, reload_time = 3.1, reload_empty_time = 3.1, reload_commit = 0.65,
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
		mag_size = 30, reserve_ammo = 90, reload_time = 2.5, reload_empty_time = 2.9, reload_commit = 0.65,
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
		display_name = "Sniper", model_scene = load("res://scenes/weapons/sniper.tscn"), sound_prefix = "sniper",
		bolt_node = ^"Pivot/Gun/Bolt", bolt_kick = 0.0,
		fire_mode = 1, rpm = 40.0, damage = 135.0, head_multiplier = 2.0, cycle_after_shot = true, unscope_on_shot = true,
		falloff_start = 300.0, falloff_end = 400.0, falloff_min = 1.0,
		mag_size = 5, reserve_ammo = 30, reload_time = 3.2, reload_empty_time = 3.8, reload_commit = 0.7,
		draw_time = 0.85, quick_draw_time = 0.55, move_speed = 0.9, holster_time = 0.3, ads_time = 0.3, ads_zoom = 7.0, ads_move_speed = 0.4,
		sprint_to_fire_time = 0.3, scope_overlay = true,
		hip_spread = 7.0, ads_spread = 0.0, move_spread = 3.0, ads_move_spread = 3.0, air_spread = 6.0,
		bloom_per_shot = 0.0, bloom_max = 0.0, bloom_decay = 5.0,
		recoil_pattern = PackedVector2Array([Vector2(0.2, 3.2)]), recoil_scale_ads = 0.7, recoil_jitter = 0.3, recoil_recovery = 14.0,
		view_punch = 3.0,
		hip_position = HIP.sniper, ads_position = Vector3(0.0, -0.075, -0.3),
		kick_back = 0.07, kick_rotation = 9.0, muzzle_flash_size = 1.7, throw_damage = 35.0,
	})

	# Knives: one is always carried (picked in Settings > Loadout). Fire = alternating slashes,
	# aim = heavy stab, V from a gun = quick slash. Same stats for all, like CS.
	for k: Array in [["knife", "Combat Knife"], ["knife_karambit", "Karambit"], ["knife_butterfly", "Butterfly Knife"],
			["knife_flip", "Flip Knife"], ["knife_bayonet", "Bayonet"]]:
		_save_knife(WeaponData, k[0], k[1])
	for id: String in NEW_KNIVES:
		_save_knife(WeaponData, "knife_" + id, NEW_KNIVES[id])


func _save_knife(WeaponData: GDScript, id: String, title: String) -> void:
	_save_res(WeaponData.new(), "res://weapons/%s.tres" % id, {
		display_name = title, model_scene = load("res://scenes/weapons/%s.tscn" % id), sound_prefix = "",
		is_melee = true, bolt_node = ^"",
		mag_size = 0, reserve_ammo = 0, draw_time = 0.4, quick_draw_time = 0.25, move_speed = 1.12, holster_time = 0.15, sprint_to_fire_time = 0.0,
		hip_position = HIP.knife, ads_position = HIP.knife,
		recoil_pattern = PackedVector2Array(),
		light_damage = 30.0, light_hit_time = 0.14, heavy_damage = 60.0, heavy_hit_time = 0.36,
		quick_hit_time = 0.18, melee_range = 2.0,
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
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
	_part(gun, "Magazine", Vector3(0.026, 0.03, 0.036), Vector3(0, -0.135, 0.078), Vector3(-15, 0, 0), _mat.accent)
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
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


## Pump shotgun. The left hand rides the pump (LeftArm) and palms a shell (Shell)
## for the one-at-a-time reload: reload_start rolls it over, reload_shell loads one, reload_end rolls back.
func _shotgun() -> Node3D:
	var r := _rig("Shotgun")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.055, 0.08, 0.24), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Barrel", Vector3(0.028, 0.028, 0.44), Vector3(0, 0.022, -0.34), Vector3.ZERO, _mat.gun)
	_part(gun, "Rib", Vector3(0.01, 0.006, 0.4), Vector3(0, 0.039, -0.33), Vector3.ZERO, _mat.gun)
	_part(gun, "Tube", Vector3(0.026, 0.026, 0.34), Vector3(0, -0.012, -0.3), Vector3.ZERO, _mat.accent)
	_part(gun, "Pump", Vector3(0.05, 0.045, 0.13), Vector3(0, -0.012, -0.27), Vector3.ZERO, _mat.accent)
	_part(gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.1), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Stock", Vector3(0.045, 0.085, 0.22), Vector3(0, -0.02, 0.24), Vector3.ZERO, _mat.accent)
	_part(gun, "RearSightL", Vector3(0.004, 0.01, 0.008), Vector3(-0.009, 0.045, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "RearSightR", Vector3(0.004, 0.01, 0.008), Vector3(0.009, 0.045, 0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "FrontSightDot", Vector3(0.008, 0.008, 0.008), Vector3(0, 0.046, -0.54), Vector3.ZERO, _mat.sight)
	_muzzle(gun, Vector3(0, 0.022, -0.57))
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
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
		"idle": _clip(0.05, {}),
		"draw": draw,
		"draw_quick": _quick_draw(0.4, []),
		"inspect": inspect,
		"reload": _clip(reload_len, _with_end(reload_p, reload_len, {"P.pos": [reload_len - 0.35, Vector3(-0.02, -0.02, 0.02)],
			"P.rot": [reload_len - 0.35, Vector3(4, 2, 10)]}), [[0.45 * k, "mag_out", -6.0], [1.65 * k, "mag_in", -3.0]]),
		"reload_empty": _clip(empty_len, _merge(reload_p, {
			"P.pos": [[rack - 0.1, Vector3(0, -0.01, 0.02)], [rack + 0.1, Vector3(0, 0, 0.04)], [rack + 0.25, Vector3.ZERO], [empty_len, Vector3.ZERO]],
			"P.rot": [[rack - 0.1, Vector3(-4, 0, -16)], [rack + 0.1, Vector3(2, 0, -18)], [rack + 0.35, Vector3(0, 0, -6)], [empty_len, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [rack, Vector3.ZERO], [rack + 0.08, Vector3(0, 0, bolt_back)], [rack + 0.15, Vector3.ZERO]],
		}), [[0.45 * k, "mag_out", -6.0], [1.65 * k, "mag_in", -3.0], [rack + 0.08, "slide_back", -4.0], [rack + 0.15, "slide_home", -3.0]]),
		"melee_lower": _melee_lower(),
	}


## Bolt-action sniper. The scope is solid (fully aimed, the HUD draws the scope instead).
## The bolt handle (Bolt) lifts, pulls back, pushes home and drops after every shot.
func _sniper() -> Node3D:
	var r := _rig("Sniper")
	var gun := _gun(r, Vector3(0, -0.02, 0.0))
	_part(gun, "Receiver", Vector3(0.055, 0.075, 0.3), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(gun, "Chassis", Vector3(0.06, 0.06, 0.32), Vector3(0, -0.02, -0.3), Vector3.ZERO, _mat.accent)
	_part(gun, "Barrel", Vector3(0.024, 0.024, 0.5), Vector3(0, 0.012, -0.5), Vector3.ZERO, _mat.gun)
	_part(gun, "MuzzleBrake", Vector3(0.042, 0.032, 0.06), Vector3(0, 0.012, -0.77), Vector3.ZERO, _mat.accent)
	_part(gun, "Magazine", Vector3(0.04, 0.08, 0.08), Vector3(0, -0.07, -0.04), Vector3.ZERO, _mat.accent)
	_part(gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.11), Vector3(-15, 0, 0), _mat.gun)
	_part(gun, "Stock", Vector3(0.05, 0.1, 0.26), Vector3(0, -0.025, 0.29), Vector3.ZERO, _mat.accent)
	_part(gun, "Cheek", Vector3(0.042, 0.03, 0.14), Vector3(0, 0.035, 0.28), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeMountF", Vector3(0.016, 0.03, 0.016), Vector3(0, 0.05, -0.08), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeMountR", Vector3(0.016, 0.03, 0.016), Vector3(0, 0.05, 0.06), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeTube", Vector3(0.036, 0.036, 0.28), Vector3(0, 0.075, -0.01), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeBell", Vector3(0.052, 0.052, 0.07), Vector3(0, 0.075, -0.18), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeEye", Vector3(0.046, 0.046, 0.05), Vector3(0, 0.075, 0.14), Vector3.ZERO, _mat.gun)
	_part(gun, "ScopeTurret", Vector3(0.02, 0.022, 0.02), Vector3(0, 0.1, -0.01), Vector3.ZERO, _mat.accent)
	_part(gun, "ScopeLens", Vector3(0.04, 0.04, 0.004), Vector3(0, 0.075, -0.216), Vector3.ZERO, _mat.sight)
	_part(gun, "Bolt", Vector3(0.06, 0.012, 0.012), Vector3(0.05, 0.015, 0.09), Vector3.ZERO, _mat.accent)
	_muzzle(gun, Vector3(0, 0.012, -0.8))
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
		"idle": _clip(0.05, {}),
		# Swings up, rolls over to work the bolt, settles.
		"draw": _clip(1.0, _merge({
			"P.pos": [[0, Vector3(0.1, -0.42, 0.16)], [0.35, Vector3(0, -0.01, 0)], [0.5, Vector3(0, -0.005, 0.01)],
				[0.85, Vector3(0, -0.005, 0.01)], [1.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-55, 30, -60)], [0.35, Vector3(4, -4, -8)], [0.5, Vector3(-2, 4, -16)],
				[0.85, Vector3(-1, 3, -14)], [1.0, Vector3.ZERO]],
		}, _bolt_cycle(0.48)), [[0.65, "slide_back", -4.0], [0.84, "slide_home", -3.0]]),
		"draw_quick": _quick_draw(0.55, []),
		# Looks down the scope from the side, then rolls it to show the bolt.
		"inspect": _clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.05, 0.1)], [1.3, Vector3(-0.12, 0.056, 0.1)],
				[1.6, Vector3(-0.05, 0.03, 0.06)], [2.6, Vector3(-0.05, 0.034, 0.06)], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(10, 62, -18)], [1.3, Vector3(6, 64, -22)], [1.6, Vector3(-6, -24, 44)],
				[2.6, Vector3(-8, -27, 46)], [3.2, Vector3.ZERO]],
		}, [[0.4, "swap", -12.0], [1.6, "swap", -14.0]]),
		# After each shot: a beat for the recoil, then roll over and run the bolt.
		"cycle": _clip(1.4, _merge({
			"P.pos": [[0, Vector3.ZERO], [0.22, Vector3(0, -0.005, 0.01)], [0.95, Vector3(0, -0.008, 0.012)], [1.25, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.22, Vector3(-2, 4, -16)], [0.95, Vector3(-1, 3, -14)], [1.25, Vector3.ZERO]],
		}, _bolt_cycle(0.25)), [[0.42, "slide_back", -4.0], [0.61, "slide_home", -3.0]]),
		"reload": _clip(3.2, _with_end(reload_p, 3.2, {"P.pos": [2.8, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.8, Vector3(4, 2, 10)]}),
			[[0.55, "mag_out", -6.0], [2.0, "mag_in", -3.0]]),
		"reload_empty": _clip(3.8, _merge(reload_p, {
			"P.pos": [[2.45, Vector3(0, -0.005, 0.01)], [3.3, Vector3(0, -0.008, 0.012)], [3.8, Vector3.ZERO]],
			"P.rot": [[2.45, Vector3(-2, 4, -16)], [3.3, Vector3(-1, 3, -14)], [3.8, Vector3.ZERO]],
		}).merged(_bolt_cycle(2.55)), [[0.55, "mag_out", -6.0], [2.0, "mag_in", -3.0], [2.72, "slide_back", -4.0], [2.91, "slide_home", -3.0]]),
		"melee_lower": _melee_lower(),
	}, "Pivot/Gun/Bolt", {"B": "Pivot/Gun/Bolt"})
	return r


## Bolt handle keys starting at `t`: lift, pull back, push home, drop (0.6 s).
func _bolt_cycle(t: float) -> Dictionary:
	return {
		"B.rot": [[0, Vector3.ZERO], [t, Vector3.ZERO], [t + 0.07, Vector3(0, 0, 75)], [t + 0.42, Vector3(0, 0, 75)], [t + 0.5, Vector3.ZERO]],
		"B.pos": [[0, Vector3.ZERO], [t + 0.08, Vector3.ZERO], [t + 0.17, Vector3(0, 0, 0.08)], [t + 0.26, Vector3(0, 0, 0.08)],
			[t + 0.36, Vector3.ZERO]],
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

## Knives added after the first five: id (builder _knife_<id>, files knife_<id>) -> name.
const NEW_KNIVES := {
	m9 = "M9 Bayonet", bowie = "Bowie Knife", stiletto = "Stiletto Knife", daggers = "Shadow Daggers",
}
const KNIFE_LEFT_HIDDEN := Vector3(-0.06, -0.32, 0.12) ## LeftArm offset that drops the free hand out of view.


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
## edge down-left). `view` is roughly the camera-to-fist direction at the hip.
func _knife_grip() -> Basis:
	var blade := Vector3(-0.45, 0.6, -0.6).normalized()
	var view := Vector3(0.2, -0.2, -0.45).normalized()
	var spine := view.cross(blade).normalized()
	var z := -blade
	return Basis(spine.cross(z), spine, z)


## Turns the knife into the grip (about the middle of the fist, so the handle stays in
## the hand whatever the knife's own pivot) and animates the rig. Knife rotation keys
## are in the knife's own frame, so spins still go round the blade / end over end.
func _animate_knife(r: Node3D, clips: Dictionary, hinges: Dictionary = {}) -> void:
	var knife: Node3D = r.get_node("Pivot/Gun")
	var grip := _knife_grip()
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
	return {
		"idle": _clip(0.05, {}),
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


func _knife_combat() -> Node3D:
	var k := _knife_model("CombatKnife", Vector3.ZERO, [
		["Handle", Vector3(0.025, 0.03, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.gun],
		["Pommel", Vector3(0.03, 0.034, 0.015), Vector3(0, 0, 0.06), Vector3.ZERO, _mat.accent],
		["Guard", Vector3(0.012, 0.06, 0.015), Vector3(0, 0.002, -0.06), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.035, 0.17), Vector3(0, 0.004, -0.15), Vector3.ZERO, _mat.blade],
		["Tip", Vector3(0.006, 0.024, 0.024), Vector3(0, 0.006, -0.235), Vector3(45, 0, 0), _mat.blade],
	])
	_animate_knife(k.owner, _knife_clips(_draw_roll(), _insp_roll_toss(), _quick_roll()))
	return k.owner


## Curved claw blade with a finger ring. Pivots on the ring, so it spins around your finger.
func _knife_karambit() -> Node3D:
	var k := _knife_model("Karambit", Vector3(0, 0, 0.075), [
		["Ring", Vector3(0.011, 0.019, 0), Vector3(0, 0, 0.075), Vector3.ZERO, _mat.k_orange],
		["Handle", Vector3(0.022, 0.028, 0.1), Vector3(0, 0, 0.005), Vector3.ZERO, _mat.k_orange],
		["Blade1", Vector3(0.005, 0.03, 0.06), Vector3(0, 0.004, -0.075), Vector3.ZERO, _mat.blade],
		["Blade2", Vector3(0.005, 0.028, 0.05), Vector3(0, -0.006, -0.125), Vector3(-25, 0, 0), _mat.blade],
		["Blade3", Vector3(0.005, 0.024, 0.045), Vector3(0, -0.027, -0.163), Vector3(-50, 0, 0), _mat.blade],
		["Tip", Vector3(0.005, 0.018, 0.03), Vector3(0, -0.052, -0.185), Vector3(-72, 0, 0), _mat.blade],
	])
	_animate_knife(k.owner, _knife_clips(_draw_ring(), _insp_ring(), _quick_ring()))
	return k.owner


## Balisong: the blade (BladeArm) and both handles (HandleA = safe, teal; HandleB = bite,
## gold) each turn on the pivot pins at the blade root, like the real thing. Open = all at
## rest (handles together in the fist, blade out front); closed = the blade swung back
## between the handles (BladeArm at 180). Every trick is blade and handles swinging round
## the pins while the wrist rocks in time, and each move starts before the last one lands.
func _knife_butterfly() -> Node3D:
	var pins := Vector3(0, 0, -0.055)
	var k := _knife_rig("Butterfly", pins)
	var r: Node3D = k.owner
	var blade := _hinge(k, "BladeArm", pins)
	_box(r, blade, "Blade", Vector3(0.005, 0.03, 0.13), Vector3(0, 0.004, -0.065), Vector3.ZERO, _mat.blade)
	_box(r, blade, "Tip", Vector3(0.005, 0.022, 0.022), Vector3(0, 0.007, -0.135), Vector3(45, 0, 0), _mat.blade)
	_box(r, blade, "Tang", Vector3(0.006, 0.012, 0.012), Vector3(0, -0.006, 0.0), Vector3.ZERO, _mat.accent)
	var a := _hinge(k, "HandleA", pins)
	_box(r, a, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(0.006, 0, 0.0575), Vector3.ZERO, _mat.k_teal)
	var b := _hinge(k, "HandleB", pins)
	_box(r, b, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(-0.006, 0, 0.0575), Vector3.ZERO, _mat.k_gold)
	_animate_knife(r, _knife_clips(
		# Comes up closed. A flick: the blade swings out while the bite handle goes all the way
		# round to meet the safe handle, then a rollover to finish.
		_clip(1.0, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.16, Vector3(0, -0.03, 0)], [0.55, Vector3(0, -0.015, 0)],
				[0.78, Vector3(0, -0.04, 0.01)], [1.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -10, -20)], [0.16, Vector3(-6, 0, -8)], [0.3, Vector3(-14, 0, 14)],
				[0.46, Vector3(-2, 0, -14)], [0.62, Vector3(-12, 0, 10)], [0.8, Vector3(-6, 0, 0)], [1.0, Vector3.ZERO]],
			"E.rot": [[0, Vector3(180, 0, 0)], [0.14, Vector3(180, 0, 0)], [0.4, Vector3.ZERO]],
			"H.rot": [[0, Vector3.ZERO], [0.14, Vector3.ZERO], [0.4, Vector3(-180, 0, 0)], [0.62, Vector3(-360, 0, 0)]],
			"G.rot": [[0, Vector3.ZERO], [0.55, Vector3.ZERO], [0.85, Vector3(0, 0, 360)]],
		}, [[0.0, "knife_draw", -6.0], [0.14, "knife_swing", -13.0], [0.4, "catch", -7.0], [0.42, "knife_swing", -14.0],
			[0.62, "catch", -5.0], [0.56, "knife_swing", -16.0]]),
		# A chain of tricks: closing aerial, rollover, fan, a zen-style handle loop, then close,
		# hold, and snap it open. Starts and ends at rest, so held inspect loops cleanly.
		_clip(4.0, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [0.7, Vector3(-0.08, 0.04, 0.05)],
				[1.0, Vector3(-0.08, 0.056, 0.05)], [1.5, Vector3(-0.07, 0.05, 0.04)], [1.9, Vector3(-0.08, 0.06, 0.05)],
				[2.3, Vector3(-0.08, 0.045, 0.05)], [2.6, Vector3(-0.06, 0.065, 0.04)], [3.0, Vector3(-0.08, 0.05, 0.05)],
				[3.4, Vector3(-0.08, 0.055, 0.05)], [3.5, Vector3(-0.08, 0.04, 0.055)], [3.6, Vector3(-0.08, 0.052, 0.05)],
				[4.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 25, -10)], [0.55, Vector3(4, 25, -24)], [0.85, Vector3(14, 25, 4)],
				[1.0, Vector3(8, 25, -14)], [1.5, Vector3(6, -15, 18)], [1.8, Vector3(12, -10, -6)], [2.1, Vector3(4, -14, 16)],
				[2.4, Vector3(10, 10, -20)], [2.6, Vector3(18, 20, -40)], [2.85, Vector3(8, 22, -6)], [3.0, Vector3(10, 25, -12)],
				[3.4, Vector3(14, 25, -12)], [3.5, Vector3(0, 25, -4)], [3.6, Vector3(10, 25, -12)], [4.0, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [1.0, Vector3.ZERO], [1.5, Vector3(0, 0, 360)]],
			"E.rot": [[0, Vector3.ZERO], [0.35, Vector3.ZERO], [0.7, Vector3(-180, 0, 0)], [1.0, Vector3(-360, 0, 0)],
				[1.5, Vector3(-360, 0, 0)], [2.3, Vector3(-1080, 0, 0)], [2.55, Vector3(-1260, 0, 0)], [2.85, Vector3(-1440, 0, 0)],
				[3.0, Vector3(-1440, 0, 0)], [3.25, Vector3(-1620, 0, 0)], [3.4, Vector3(-1620, 0, 0)],
				[3.55, Vector3(-1800, 0, 0), "linear"]],
			"A.rot": [[0, Vector3.ZERO], [1.6, Vector3.ZERO], [2.2, Vector3(360, 0, 0)]],
			"H.rot": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.85, Vector3(-180, 0, 0)], [1.1, Vector3(-360, 0, 0)],
				[2.3, Vector3(-360, 0, 0)], [2.8, Vector3(-720, 0, 0)]],
		}, [[0.35, "knife_swing", -14.0], [0.7, "catch", -8.0], [1.0, "catch", -7.0], [1.0, "knife_swing", -16.0],
			[1.1, "catch", -7.0], [1.6, "knife_swing", -14.0], [1.9, "knife_swing", -15.0], [2.2, "catch", -7.0],
			[2.3, "catch", -8.0], [2.4, "knife_swing", -14.0], [2.8, "catch", -7.0], [2.85, "catch", -8.0],
			[3.25, "catch", -6.0], [3.5, "knife_swing", -12.0], [3.55, "catch", -3.0]]),
		# Quick draw: flicks the blade open with the bite handle chasing it round.
		{"E.rot": [[0, Vector3(180, 0, 0)], [0.14, Vector3.ZERO]],
			"H.rot": [[0, Vector3.ZERO], [0.04, Vector3.ZERO], [0.22, Vector3(-360, 0, 0)]]},
	), {"A": "Pivot/Gun/HandleA", "H": "Pivot/Gun/HandleB", "E": "Pivot/Gun/BladeArm"})
	return r


## Folding blade on a hinge at the front of the handle. Rest = open; folded = rotated 180.
func _knife_flip() -> Node3D:
	var k := _knife_model("FlipKnife", Vector3.ZERO, [
		["Handle", Vector3(0.022, 0.03, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.k_red],
		["Bolster", Vector3(0.024, 0.032, 0.012), Vector3(0, 0, -0.055), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.005, 0.03, 0.15), Vector3(0, 0.006, -0.13), Vector3.ZERO, _mat.blade, "K"],
		["Tip", Vector3(0.005, 0.022, 0.022), Vector3(0, 0.009, -0.21), Vector3(45, 0, 0), _mat.blade, "K"],
	], Vector3(0, 0.006, -0.055))
	_animate_knife(k.owner, _knife_clips(_draw_flick(), _insp_fold(), _quick_fold()), {"K": "Pivot/Gun/BladeHinge"})
	return k.owner


## Long blade with a fuller. Draw is a barrel-roll toss.
func _knife_bayonet() -> Node3D:
	var k := _knife_model("Bayonet", Vector3.ZERO, [
		["Handle", Vector3(0.026, 0.032, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.k_olive],
		["Pommel", Vector3(0.03, 0.036, 0.016), Vector3(0, 0, 0.062), Vector3.ZERO, _mat.accent],
		["Guard", Vector3(0.014, 0.075, 0.016), Vector3(0, 0.002, -0.062), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.036, 0.21), Vector3(0, 0.004, -0.17), Vector3.ZERO, _mat.blade],
		["Fuller", Vector3(0.0068, 0.006, 0.15), Vector3(0, 0.012, -0.15), Vector3.ZERO, _mat.accent],
		["Tip", Vector3(0.006, 0.026, 0.026), Vector3(0, 0.008, -0.28), Vector3(45, 0, 0), _mat.blade],
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
		["Guard", Vector3(0.014, 0.07, 0.016), Vector3(0, 0.004, -0.064), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.04, 0.2), Vector3(0, 0.002, -0.17), Vector3.ZERO, _mat.blade],
		["Saw", Vector3(0.0068, 0.008, 0.09), Vector3(0, 0.024, -0.13), Vector3.ZERO, _mat.dark_blade],
		["Tip", Vector3(0.006, 0.028, 0.028), Vector3(0, 0.004, -0.27), Vector3(45, 0, 0), _mat.blade],
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
		["Guard", Vector3(0.016, 0.1, 0.014), Vector3(0, 0.004, -0.068), Vector3.ZERO, _mat.k_gold],
		["Ricasso", Vector3(0.0075, 0.05, 0.025), Vector3(0, 0.002, -0.088), Vector3.ZERO, _mat.blade],
		["Blade", Vector3(0.0075, 0.058, 0.22), Vector3(0, 0, -0.205), Vector3.ZERO, _mat.blade],
		["Clip", Vector3(0.0078, 0.02, 0.07), Vector3(0, 0.022, -0.29), Vector3(-20, 0, 0), _mat.dark_blade],
		["Tip", Vector3(0.0075, 0.036, 0.036), Vector3(0, -0.006, -0.32), Vector3(45, 0, 0), _mat.blade],
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
		["Blade", Vector3(0.004, 0.02, 0.15), Vector3(0, 0.006, -0.137), Vector3.ZERO, _mat.blade, "K"],
		["Tip", Vector3(0.004, 0.016, 0.018), Vector3(0, 0.008, -0.215), Vector3(45, 0, 0), _mat.blade, "K"],
	], Vector3(0, 0.006, -0.062))
	_animate_knife(k.owner, _knife_clips(_draw_switch(), _insp_switch(), _quick_fold()), {"K": "Pivot/Gun/BladeHinge"})
	return k.owner


## Push daggers, one in each fist: the T-handle sits across the palm and the blade
## sticks out between the fingers. The left one rides the free hand (LeftArm/LeftDagger),
## so the free hand stays up for inspects too.
func _knife_daggers() -> Node3D:
	var parts := [
		["Grip", Vector3(0.022, 0.07, 0.024), Vector3.ZERO, Vector3.ZERO, _mat.k_black],
		["Collar", Vector3(0.02, 0.03, 0.014), Vector3(0, 0, -0.03), Vector3.ZERO, _mat.accent],
		["Blade", Vector3(0.006, 0.034, 0.09), Vector3(0, 0, -0.08), Vector3.ZERO, _mat.blade],
		["Tip", Vector3(0.006, 0.024, 0.024), Vector3(0, 0, -0.125), Vector3(45, 0, 0), _mat.blade],
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
		_box(r, left, p[0], p[1], p[2], p[3], p[4])
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
		if p.size() > 5 and p[5] == "K":
			_box(r, hinge, p[0], p[1], p[2] - (hinge_at as Vector3), p[3], p[4])
		elif String(p[0]).begins_with("Ring"):
			_ring(k, p[0], p[2], p[1].x, p[1].y, p[4])
		else:
			_part(k, p[0], p[1], p[2], p[3], p[4])
	return k


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


## Folder: comes up folded, wrist cocks back, flicks the blade (hinge K) open, quick twirl.
func _draw_flick() -> Dictionary:
	return _clip(0.75, {
		"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.18, Vector3(0, -0.02, 0)], [0.28, Vector3(0, -0.01, 0.02)],
			[0.36, Vector3(0, -0.02, -0.02)], [0.5, Vector3.ZERO], [0.75, Vector3.ZERO]],
		"P.rot": [[0, Vector3(-40, -20, -30)], [0.18, Vector3(-5, 0, 0)], [0.28, Vector3(-30, 0, 0)],
			[0.36, Vector3(12, 0, 0)], [0.5, Vector3(-3, 0, 0)], [0.75, Vector3.ZERO]],
		"K.rot": [[0, Vector3(180, 0, 0)], [0.28, Vector3(180, 0, 0)], [0.37, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.7, Vector3(0, 0, 360)]],
	}, [[0.3, "knife_draw", -6.0], [0.37, "catch", -3.0]])


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


## Folder: slowly folds it shut, flicks it back open, end-over-end flip.
func _insp_fold() -> Dictionary:
	return _clip(3.0, {
		"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [1.4, Vector3(-0.08, 0.05, 0.05)],
			[1.5, Vector3(-0.08, 0.06, 0.07)], [1.6, Vector3(-0.08, 0.04, 0.03)], [2.6, Vector3(-0.08, 0.05, 0.05)],
			[3.0, Vector3.ZERO]],
		"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 30, -15)], [1.4, Vector3(10, 30, -15)],
			[1.5, Vector3(-20, 30, -15)], [1.62, Vector3(18, 30, -15)], [1.8, Vector3(10, 30, -15)],
			[2.6, Vector3(10, 30, -15)], [3.0, Vector3.ZERO]],
		"K.rot": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [1.2, Vector3(170, 0, 0)], [1.5, Vector3(170, 0, 0)],
			[1.6, Vector3.ZERO]],
		"G.pos": [[0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.2, Vector3(0, 0.12, 0)], [2.4, Vector3.ZERO]],
		"G.rot": [[0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.4, Vector3(-360, 0, 0), "linear"]],
	}, [[0.6, "mag_out", -12.0], [1.6, "knife_draw", -6.0], [2.0, "knife_swing", -12.0], [2.4, "catch", -5.0]])


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
func _animate(r: Node3D, clips: Dictionary, bolt_path: String, hinges: Dictionary = {}) -> void:
	var paths := {"P": "Pivot", "G": "Pivot/Gun"}
	if r.has_node("Pivot/Gun/Magazine"):
		paths["M"] = "Pivot/Gun/Magazine"
	if bolt_path != "":
		paths["B"] = bolt_path
	paths.merge(hinges)
	var lib := AnimationLibrary.new()
	for clip_name: String in clips:
		var c: Dictionary = clips[clip_name]
		var a := Animation.new()
		a.length = c.length
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
