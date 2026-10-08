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
## Big rotations are fine; they're split into small steps so spins go the long way.

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

	_save_scene(_carbine(), "res://scenes/weapons/carbine.tscn")
	_save_scene(_smg(), "res://scenes/weapons/smg.tscn")
	_save_scene(_sidearm(), "res://scenes/weapons/sidearm.tscn")
	_save_scene(_knife_combat(), "res://scenes/weapons/knife.tscn")
	_save_scene(_knife_karambit(), "res://scenes/weapons/knife_karambit.tscn")
	_save_scene(_knife_butterfly(), "res://scenes/weapons/knife_butterfly.tscn")
	_save_scene(_knife_flip(), "res://scenes/weapons/knife_flip.tscn")
	_save_scene(_knife_bayonet(), "res://scenes/weapons/knife_bayonet.tscn")
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
		hip_position = Vector3(0.19, -0.2, -0.52), ads_position = Vector3(0.0, -0.0775, -0.36),
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
		hip_position = Vector3(0.17, -0.19, -0.47), ads_position = Vector3(0.0, -0.0745, -0.33),
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
		hip_position = Vector3(0.14, -0.16, -0.4), ads_position = Vector3(0.0, -0.0525, -0.34),
		kick_back = 0.05, kick_rotation = 7.0, muzzle_flash_size = 1.3, throw_damage = 20.0,
	})

	# Knives: one is always carried (picked in Settings > Loadout). Fire = alternating slashes,
	# aim = heavy stab, V from a gun = quick slash. Same stats for all, like CS.
	for k: Array in [["knife", "Combat Knife"], ["knife_karambit", "Karambit"], ["knife_butterfly", "Butterfly Knife"],
			["knife_flip", "Flip Knife"], ["knife_bayonet", "Bayonet"]]:
		_save_knife(WeaponData, k[0], k[1])


func _save_knife(WeaponData: GDScript, id: String, title: String) -> void:
	_save_res(WeaponData.new(), "res://weapons/%s.tres" % id, {
		display_name = title, model_scene = load("res://scenes/weapons/%s.tscn" % id), sound_prefix = "",
		is_melee = true, bolt_node = ^"",
		mag_size = 0, reserve_ammo = 0, draw_time = 0.4, quick_draw_time = 0.25, move_speed = 1.12, holster_time = 0.15, sprint_to_fire_time = 0.0,
		hip_position = Vector3(0.2, -0.2, -0.42), ads_position = Vector3(0.2, -0.2, -0.42),
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
	_segment(r, arms, "RightForearm", Vector3(0.02, -0.13, 0.15), Vector3(0.16, -0.36, 0.45), _mat.sleeve)
	_box(r, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.045, -0.27), Vector3(0, 0, -20), _mat.glove)
	_segment(r, arms, "LeftForearm", Vector3(-0.03, -0.07, -0.25), Vector3(-0.42, -0.32, 0.02), _mat.sleeve)

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
		}, [[0.0, "swap", -8.0], [0.6, "rack", -4.0]]),
		"inspect": _clip(3.2, {
			"P.pos": [[0, Vector3.ZERO], [0.4, Vector3(-0.12, 0.06, 0.1)], [1.2, Vector3(-0.12, 0.06, 0.1)],
				[1.5, Vector3(-0.04, 0.03, 0.06)], [2.2, Vector3(-0.04, 0.03, 0.06)], [2.5, Vector3(0, 0.02, 0)],
				[2.75, Vector3.ZERO], [3.2, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.4, Vector3(15, 55, -30)], [1.2, Vector3(5, 60, -35)], [1.5, Vector3(-5, -20, 40)],
				[2.2, Vector3(-8, -25, 45)], [2.5, Vector3(10, 0, 0)], [2.75, Vector3(-2, 0, 0)], [3.2, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [2.3, Vector3.ZERO], [2.5, Vector3(0, 0.12, 0)], [2.7, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [2.3, Vector3.ZERO], [2.7, Vector3(0, 0, 360)]],
		}, [[0.4, "swap", -12.0], [2.3, "throw", -16.0], [2.7, "catch", -4.0]]),
		"reload": _clip(2.4, _with_end(reload_p, 2.4, {"P.pos": [2.1, Vector3(-0.02, -0.02, 0.02)], "P.rot": [2.1, Vector3(4, 2, 10)]}),
			[[0.45, "mag_out", -6.0], [1.6, "mag_in", -3.0]]),
		"reload_empty": _clip(3.1, _merge(reload_p, {
			"P.pos": [[2.05, Vector3(0, -0.01, 0.02)], [2.25, Vector3(0, 0, 0.04)], [2.4, Vector3.ZERO], [3.1, Vector3.ZERO]],
			"P.rot": [[2.05, Vector3(-4, 0, -16)], [2.25, Vector3(2, 0, -18)], [2.5, Vector3(0, 0, -6)], [3.1, Vector3.ZERO]],
			"B.pos": [[0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.2, Vector3(0, 0, 0.06)], [2.28, Vector3.ZERO]],
		}), [[0.45, "mag_out", -6.0], [1.6, "mag_in", -3.0], [2.2, "rack", -3.0]]),
		"melee_lower": _melee_lower(),
		"draw_quick": _quick_draw(0.4, [[0.0, "swap", -10.0]]),
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
	_segment(r, arms, "RightForearm", Vector3(0.02, -0.12, 0.13), Vector3(0.16, -0.36, 0.45), _mat.sleeve)
	_box(r, arms, "LeftHand", Vector3(0.07, 0.06, 0.09), Vector3(-0.02, -0.04, -0.2), Vector3(0, 0, -20), _mat.glove)
	_segment(r, arms, "LeftForearm", Vector3(-0.04, -0.07, -0.18), Vector3(-0.42, -0.32, 0.05), _mat.sleeve)

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
			"G.rot": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.48, Vector3(-360, 0, 0)]],
		}, [[0.0, "swap", -8.0], [0.18, "throw", -14.0], [0.48, "catch", -2.0]]),
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
		"draw_quick": _quick_draw(0.35, [[0.0, "swap", -10.0]]),
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
	_segment(r, arms, "RightForearm", Vector3(0.02, -0.11, 0.11), Vector3(0.12, -0.36, 0.45), _mat.sleeve)
	_box(r, arms, "LeftHand", Vector3(0.06, 0.075, 0.08), Vector3(-0.035, -0.08, 0.06), Vector3(-15, 0, 25), _mat.glove)
	_segment(r, arms, "LeftForearm", Vector3(-0.05, -0.1, 0.09), Vector3(-0.3, -0.36, 0.45), _mat.sleeve)

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
		}, [[0.0, "swap", -8.0], [0.5, "rack", -4.0]]),
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
		}), [[0.35, "mag_out", -6.0], [1.3, "mag_in", -3.0], [1.8, "rack", -2.0]]),
		"melee_lower": _melee_lower(),
		"draw_quick": _quick_draw(0.28, [[0.0, "swap", -10.0]]),
	}, "Pivot/Gun/Slide")
	return r


# --- Knives -----------------------------------------------------------------------------
# CS-style: every knife cuts the same (shared slashes, heavy and quick melee) but
# has its own model, first-draw flourish, inspect and quick-draw flair.

## Rig with the knife hand. Returns the "Gun" node (the knife), pivoting at `pivot`.
func _knife_rig(n: String, pivot: Vector3) -> Node3D:
	var r := _rig(n)
	var knife := _gun(r, pivot)
	var arms := _arms(r)
	_box(r, arms, "RightHand", Vector3(0.07, 0.075, 0.085), Vector3(0.0, -0.005, 0.0), Vector3(-10, 0, 0), _mat.glove)
	_segment(r, arms, "RightForearm", Vector3(0.02, -0.04, 0.04), Vector3(0.16, -0.33, 0.42), _mat.sleeve)
	return knife


func _knife_clips(draw: Dictionary, inspect: Dictionary, quick_extra: Dictionary) -> Dictionary:
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
			"G.rot": [[0, Vector3.ZERO], [0.2, Vector3(0, 0, -90)], [0.36, Vector3(0, 0, -90)], [0.7, Vector3.ZERO]],
		}),
		# Quick melee from a gun: in from the bottom-right, slash, out bottom-left.
		"quick_slash": _clip(0.5, {
			"P.pos": [[0, Vector3(0.12, -0.4, 0.12)], [0.1, Vector3(0.1, 0.08, 0.06)], [0.2, Vector3(-0.28, -0.08, -0.12)],
				[0.32, Vector3(-0.3, -0.12, -0.08)], [0.5, Vector3(-0.1, -0.5, 0.1)]],
			"P.rot": [[0, Vector3(-40, -30, -40)], [0.1, Vector3(25, -35, -55)], [0.2, Vector3(-20, 55, 75)],
				[0.32, Vector3(-25, 60, 80)], [0.5, Vector3(-60, 40, 60)]],
		}),
	}


func _knife_combat() -> Node3D:
	var k := _knife_rig("CombatKnife", Vector3.ZERO)
	_part(k, "Handle", Vector3(0.025, 0.03, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.gun)
	_part(k, "Pommel", Vector3(0.03, 0.034, 0.015), Vector3(0, 0, 0.06), Vector3.ZERO, _mat.accent)
	_part(k, "Guard", Vector3(0.06, 0.012, 0.015), Vector3(0, 0, -0.06), Vector3.ZERO, _mat.accent)
	_part(k, "Blade", Vector3(0.006, 0.035, 0.17), Vector3(0, 0.004, -0.15), Vector3.ZERO, _mat.blade)
	_part(k, "Tip", Vector3(0.006, 0.024, 0.024), Vector3(0, 0.006, -0.235), Vector3(45, 0, 0), _mat.blade)
	var r: Node3D = k.owner
	_animate(r, _knife_clips(
		# Flip toss: two end-over-end spins up out of the hand and a snap catch.
		_clip(0.7, {
			"P.pos": [[0, Vector3(0.1, -0.35, 0.1)], [0.18, Vector3(0, -0.04, 0)], [0.45, Vector3(0, -0.03, 0)],
				[0.5, Vector3(0, -0.06, 0.01)], [0.62, Vector3(0, 0.005, 0)], [0.7, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.18, Vector3(-5, 0, 0)], [0.45, Vector3.ZERO],
				[0.5, Vector3(-8, 0, 0)], [0.7, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.32, Vector3(0, 0.17, -0.02)], [0.46, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.18, Vector3.ZERO], [0.46, Vector3(720, 0, 0)]],
		}, [[0.0, "knife_draw", -6.0], [0.46, "catch", -4.0]]),
		# Twirls around the blade, then a flip.
		_clip(2.8, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.1, 0.06, 0.05)], [2.4, Vector3(-0.1, 0.06, 0.05)], [2.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 25, -10)], [1.0, Vector3(10, 25, -10)], [1.3, Vector3(10, -40, 20)],
				[1.9, Vector3(10, -40, 20)], [2.4, Vector3(10, 25, -10)], [2.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.4, Vector3.ZERO], [1.0, Vector3(0, 0, 720)], [1.9, Vector3(0, 0, 720)],
				[2.3, Vector3(-360, 0, 720)]],
		}, [[0.4, "knife_swing", -14.0], [1.9, "knife_swing", -12.0], [2.3, "catch", -6.0]]),
		{"G.rot": [[0, Vector3(0, 0, -180)], [0.18, Vector3.ZERO]]},
	), "")
	return r


## Curved claw blade with a finger ring. Pivots on the ring, so it spins around your finger.
func _knife_karambit() -> Node3D:
	var k := _knife_rig("Karambit", Vector3(0, 0, 0.075))
	_ring(k, "Ring", Vector3(0, 0, 0.075), 0.011, 0.019, _mat.k_orange)
	_part(k, "Handle", Vector3(0.022, 0.028, 0.1), Vector3(0, 0, 0.005), Vector3.ZERO, _mat.k_orange)
	_part(k, "Blade1", Vector3(0.005, 0.03, 0.06), Vector3(0, 0.004, -0.075), Vector3.ZERO, _mat.blade)
	_part(k, "Blade2", Vector3(0.005, 0.028, 0.05), Vector3(0, -0.006, -0.125), Vector3(-25, 0, 0), _mat.blade)
	_part(k, "Blade3", Vector3(0.005, 0.024, 0.045), Vector3(0, -0.027, -0.163), Vector3(-50, 0, 0), _mat.blade)
	_part(k, "Tip", Vector3(0.005, 0.018, 0.03), Vector3(0, -0.052, -0.185), Vector3(-72, 0, 0), _mat.blade)
	var r: Node3D = k.owner
	_animate(r, _knife_clips(
		# Comes up spinning twice around the finger ring, then snaps still.
		_clip(0.8, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.15, Vector3(0, -0.02, 0)], [0.55, Vector3(0, -0.02, 0)],
				[0.6, Vector3(0, -0.045, 0.01)], [0.7, Vector3(0, 0.005, 0)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.15, Vector3(-5, 0, 0)], [0.55, Vector3(-5, 0, 0)],
				[0.6, Vector3(-10, 0, 0)], [0.8, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.56, Vector3(-720, 0, 0)]],
		}, [[0.0, "knife_draw", -6.0], [0.15, "knife_swing", -12.0], [0.56, "catch", -4.0]]),
		# Spin, show the curve, reverse spin the other way.
		_clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [1.3, Vector3(-0.08, 0.05, 0.05)],
				[1.5, Vector3(-0.05, 0.06, 0.04)], [2.6, Vector3(-0.05, 0.06, 0.04)], [3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 30, -15)], [1.3, Vector3(10, 30, -15)],
				[1.5, Vector3(0, -35, 30)], [2.6, Vector3(0, -35, 30)], [3.0, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [0.9, Vector3(-360, 0, 0)], [1.6, Vector3(-360, 0, 0)],
				[2.2, Vector3(360, 0, 0)]],
		}, [[0.5, "knife_swing", -12.0], [0.9, "catch", -6.0], [1.6, "knife_swing", -12.0], [2.2, "catch", -6.0]]),
		{"G.rot": [[0, Vector3(-360, 0, 0)], [0.2, Vector3.ZERO]]},
	), "")
	return r


## Two handles on hinges at the blade root. Rest = open (handles together in the fist);
## closed = both swung forward over the blade.
func _knife_butterfly() -> Node3D:
	var k := _knife_rig("Butterfly", Vector3(0, 0, -0.055))
	_part(k, "Blade", Vector3(0.005, 0.03, 0.13), Vector3(0, 0.004, -0.12), Vector3.ZERO, _mat.blade)
	_part(k, "Tip", Vector3(0.005, 0.022, 0.022), Vector3(0, 0.007, -0.19), Vector3(45, 0, 0), _mat.blade)
	var r: Node3D = k.owner
	var a := _hinge(k, "HandleA", Vector3(0, 0, -0.055))
	_box(r, a, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(0.006, 0, 0.0575), Vector3.ZERO, _mat.k_teal)
	var b := _hinge(k, "HandleB", Vector3(0, 0, -0.055))
	_box(r, b, "Mesh", Vector3(0.009, 0.028, 0.115), Vector3(-0.006, 0, 0.0575), Vector3.ZERO, _mat.k_gold)
	_animate(r, _knife_clips(
		# Comes up closed, swings one handle open, rolls the blade, swings the other, snaps shut in the fist.
		_clip(0.95, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.15, Vector3(0, -0.03, 0)], [0.8, Vector3(0, -0.02, 0)],
				[0.86, Vector3(0, -0.045, 0.01)], [0.95, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -10, -20)], [0.15, Vector3(-5, 0, 0)], [0.4, Vector3(-10, 0, 8)],
				[0.65, Vector3(-5, 0, -8)], [0.86, Vector3(-6, 0, 0)], [0.95, Vector3.ZERO]],
			"A.rot": [[0, Vector3(180, 0, 0)], [0.18, Vector3(180, 0, 0)], [0.38, Vector3.ZERO]],
			"H.rot": [[0, Vector3(-180, 0, 0)], [0.45, Vector3(-180, 0, 0)], [0.65, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.38, Vector3.ZERO], [0.62, Vector3(0, 0, 360)]],
		}, [[0.0, "knife_draw", -6.0], [0.2, "knife_swing", -14.0], [0.38, "catch", -5.0],
			[0.45, "knife_swing", -14.0], [0.65, "catch", -4.0]]),
		# Two rounds of aerials: each handle goes all the way around, with a blade roll between.
		_clip(3.4, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [3.0, Vector3(-0.08, 0.05, 0.05)], [3.4, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 25, -10)], [1.6, Vector3(10, 25, -10)],
				[1.8, Vector3(5, -20, 15)], [3.0, Vector3(5, -20, 15)], [3.4, Vector3.ZERO]],
			"A.rot": [[0, Vector3.ZERO], [0.5, Vector3.ZERO], [1.0, Vector3(360, 0, 0)], [2.0, Vector3(360, 0, 0)],
				[2.5, Vector3(720, 0, 0)]],
			"H.rot": [[0, Vector3.ZERO], [0.75, Vector3.ZERO], [1.25, Vector3(-360, 0, 0)], [2.2, Vector3(-360, 0, 0)],
				[2.7, Vector3(-720, 0, 0)]],
			"G.rot": [[0, Vector3.ZERO], [1.25, Vector3.ZERO], [1.7, Vector3(0, 0, 360)]],
		}, [[0.5, "knife_swing", -14.0], [1.0, "catch", -6.0], [0.75, "knife_swing", -14.0], [1.25, "catch", -6.0],
			[2.0, "knife_swing", -14.0], [2.5, "catch", -6.0], [2.2, "knife_swing", -14.0], [2.7, "catch", -6.0]]),
		# Even the quick draw flicks it open.
		{"A.rot": [[0, Vector3(180, 0, 0)], [0.15, Vector3.ZERO]], "H.rot": [[0, Vector3(-180, 0, 0)], [0.21, Vector3.ZERO]]},
	), "", {"A": "Pivot/Gun/HandleA", "H": "Pivot/Gun/HandleB"})
	return r


## Folding blade on a hinge at the front of the handle. Rest = open; folded = rotated 180.
func _knife_flip() -> Node3D:
	var k := _knife_rig("FlipKnife", Vector3.ZERO)
	_part(k, "Handle", Vector3(0.022, 0.03, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.k_red)
	_part(k, "Bolster", Vector3(0.024, 0.032, 0.012), Vector3(0, 0, -0.055), Vector3.ZERO, _mat.accent)
	var r: Node3D = k.owner
	var hinge := _hinge(k, "BladeHinge", Vector3(0, 0.006, -0.055))
	_box(r, hinge, "Blade", Vector3(0.005, 0.03, 0.15), Vector3(0, 0, -0.075), Vector3.ZERO, _mat.blade)
	_box(r, hinge, "Tip", Vector3(0.005, 0.022, 0.022), Vector3(0, 0.003, -0.155), Vector3(45, 0, 0), _mat.blade)
	_animate(r, _knife_clips(
		# Comes up folded, wrist cocks back, flicks the blade open, then a quick twirl.
		_clip(0.75, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.18, Vector3(0, -0.02, 0)], [0.28, Vector3(0, -0.01, 0.02)],
				[0.36, Vector3(0, -0.02, -0.02)], [0.5, Vector3.ZERO], [0.75, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.18, Vector3(-5, 0, 0)], [0.28, Vector3(-30, 0, 0)],
				[0.36, Vector3(12, 0, 0)], [0.5, Vector3(-3, 0, 0)], [0.75, Vector3.ZERO]],
			"K.rot": [[0, Vector3(180, 0, 0)], [0.28, Vector3(180, 0, 0)], [0.37, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.45, Vector3.ZERO], [0.7, Vector3(0, 0, 360)]],
		}, [[0.0, "swap", -12.0], [0.3, "knife_draw", -6.0], [0.37, "catch", -3.0]]),
		# Slowly folds it shut, flicks it back open, end-over-end flip.
		_clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.08, 0.05, 0.05)], [1.4, Vector3(-0.08, 0.05, 0.05)],
				[1.5, Vector3(-0.08, 0.06, 0.07)], [1.6, Vector3(-0.08, 0.04, 0.03)], [2.6, Vector3(-0.08, 0.05, 0.05)],
				[3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.3, Vector3(10, 30, -15)], [1.4, Vector3(10, 30, -15)],
				[1.5, Vector3(-20, 30, -15)], [1.62, Vector3(18, 30, -15)], [1.8, Vector3(10, 30, -15)],
				[2.6, Vector3(10, 30, -15)], [3.0, Vector3.ZERO]],
			"K.rot": [[0, Vector3.ZERO], [0.6, Vector3.ZERO], [1.2, Vector3(170, 0, 0)], [1.5, Vector3(170, 0, 0)],
				[1.6, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.2, Vector3(0, 0.12, 0)], [2.4, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.4, Vector3(-360, 0, 0)]],
		}, [[0.6, "mag_out", -12.0], [1.6, "knife_draw", -6.0], [2.0, "knife_swing", -12.0], [2.4, "catch", -5.0]]),
		{"K.rot": [[0, Vector3(180, 0, 0)], [0.14, Vector3.ZERO]]},
	), "", {"K": "Pivot/Gun/BladeHinge"})
	return r


## Long blade with a fuller. Draw is a barrel-roll toss.
func _knife_bayonet() -> Node3D:
	var k := _knife_rig("Bayonet", Vector3.ZERO)
	_part(k, "Handle", Vector3(0.026, 0.032, 0.11), Vector3.ZERO, Vector3.ZERO, _mat.k_olive)
	_part(k, "Pommel", Vector3(0.03, 0.036, 0.016), Vector3(0, 0, 0.062), Vector3.ZERO, _mat.accent)
	_part(k, "Guard", Vector3(0.075, 0.014, 0.016), Vector3(0, 0, -0.062), Vector3.ZERO, _mat.accent)
	_part(k, "Blade", Vector3(0.006, 0.036, 0.21), Vector3(0, 0.004, -0.17), Vector3.ZERO, _mat.blade)
	_part(k, "Fuller", Vector3(0.0068, 0.006, 0.15), Vector3(0, 0.012, -0.15), Vector3.ZERO, _mat.accent)
	_part(k, "Tip", Vector3(0.006, 0.026, 0.026), Vector3(0, 0.008, -0.28), Vector3(45, 0, 0), _mat.blade)
	var r: Node3D = k.owner
	_animate(r, _knife_clips(
		# Tossed straight up, barrel-rolling twice around the blade, caught.
		_clip(0.8, {
			"P.pos": [[0, Vector3(0.08, -0.35, 0.1)], [0.15, Vector3(0, -0.03, 0)], [0.5, Vector3(0, -0.02, 0)],
				[0.54, Vector3(0, -0.055, 0.01)], [0.66, Vector3(0, 0.005, 0)], [0.8, Vector3.ZERO]],
			"P.rot": [[0, Vector3(-40, -20, -30)], [0.15, Vector3(-5, 0, 0)], [0.5, Vector3.ZERO],
				[0.54, Vector3(-8, 0, 0)], [0.8, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.32, Vector3(0, 0.15, 0)], [0.5, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.5, Vector3(0, 0, -720)]],
		}, [[0.0, "knife_draw", -6.0], [0.15, "knife_swing", -14.0], [0.5, "catch", -4.0]]),
		# Shows the flat of the blade, turns it over, spin and toss.
		_clip(3.0, {
			"P.pos": [[0, Vector3.ZERO], [0.3, Vector3(-0.1, 0.05, 0.05)], [2.6, Vector3(-0.1, 0.05, 0.05)], [3.0, Vector3.ZERO]],
			"P.rot": [[0, Vector3.ZERO], [0.35, Vector3(10, 20, -80)], [1.2, Vector3(10, 20, -80)],
				[1.5, Vector3(5, -30, 30)], [2.6, Vector3(5, -30, 30)], [3.0, Vector3.ZERO]],
			"G.pos": [[0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.3, Vector3(0, 0.13, 0)], [2.5, Vector3.ZERO]],
			"G.rot": [[0, Vector3.ZERO], [1.6, Vector3.ZERO], [2.0, Vector3(0, 0, 360)], [2.1, Vector3(0, 0, 360)],
				[2.5, Vector3(-360, 0, 360)]],
		}, [[1.6, "knife_swing", -14.0], [2.1, "knife_swing", -12.0], [2.5, "catch", -5.0]]),
		{"G.rot": [[0, Vector3(0, 0, -360)], [0.2, Vector3.ZERO]]},
	), "")
	return r


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
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	if keys.is_empty():
		keys = [[0.0, Vector3.ZERO]]
	for k: Array in keys:
		a.position_track_insert_key(t, k[0], rest + k[1])


func _rotation_track(a: Animation, path: String, rest: Vector3, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath(path))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	if keys.is_empty():
		keys = [[0.0, Vector3.ZERO]]
	var rest_q := Basis.from_euler(rest).get_rotation_quaternion()
	var prev: Array = []
	for k: Array in keys:
		if not prev.is_empty():
			# Quaternions take the short way round, so split big turns into <= 60 degree steps.
			var d: Vector3 = k[1] - prev[1]
			var steps := ceili(maxf(maxf(absf(d.x), absf(d.y)), absf(d.z)) / 60.0)
			for i in range(1, steps):
				var f := float(i) / steps
				_rot_key(a, t, lerpf(prev[0], k[0], f), rest_q, prev[1].lerp(k[1], f))
		_rot_key(a, t, k[0], rest_q, k[1])
		prev = k


func _rot_key(a: Animation, t: int, time: float, rest_q: Quaternion, deg: Vector3) -> void:
	var off := Basis.from_euler(deg * (PI / 180.0)).get_rotation_quaternion()
	a.rotation_track_insert_key(t, time, rest_q * off)


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


## Box stretched between two points (for forearms).
func _segment(r: Node, parent: Node, n: String, a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.085, 0.085, a.distance_to(b))
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5)
	parent.add_child(mi)
	mi.owner = r


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
