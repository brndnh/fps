class_name WeaponData
extends Resource
## Stats for one weapon. Each weapon is a .tres in weapons/, so you can tune it
## in the Inspector while the game is running.
## The viewmodel scene's AnimationPlayer holds the keyframed animations:
## guns use draw, draw_quick, inspect, reload, reload_empty, melee_lower and idle;
## melee weapons use draw, draw_quick, inspect, slash_left, slash_right, heavy, quick_slash and idle.
## Draws take turns each time you pull the weapon out: "draw" (flourish), "draw_quick",
## then any other "draw*" animation you add.

enum FireMode { AUTO, SEMI }

@export var display_name: String = "Weapon"
@export var model_scene: PackedScene ## Viewmodel: Pivot/Gun (+ Muzzle marker) and Pivot/Arms, plus an AnimationPlayer.
@export var sound_prefix: String = "carbine" ## Sfx names: shot_<prefix>.
@export var is_melee: bool = false ## Knife-type weapon: fire = light slash, aim = heavy. Can't be thrown.
@export var bolt_node: NodePath = ^"Pivot/Gun/Bolt" ## Kicks back on every shot (slide / charging handle).
@export var bolt_kick: float = 0.02

@export_group("Fire")
@export var fire_mode: FireMode = FireMode.AUTO
@export var rpm: float = 600.0
@export var damage: float = 14.0
@export var head_multiplier: float = 1.75
@export var falloff_start: float = 40.0 ## Metres. Full damage up to here.
@export var falloff_end: float = 80.0
@export var falloff_min: float = 0.7 ## Damage fraction at falloff_end and beyond.

@export_group("Ammo")
@export var mag_size: int = 28
@export var reserve_ammo: int = 224 ## Ignored when the weapon manager has infinite reserve on.
@export var reload_time: float = 2.4 ## Mag still has rounds.
@export var reload_empty_time: float = 3.1 ## Mag was empty (also chambers a round).
@export_range(0.0, 1.0) var reload_commit: float = 0.7 ## Ammo goes in at this fraction of the reload. Cancel before it and you get nothing.

@export_group("Handling")
@export var draw_time: float = 0.45 ## Flourish draws: when you can shoot. The flourish keeps playing until you act.
@export var quick_draw_time: float = 0.35 ## The "draw_quick" animation.
@export var move_speed: float = 1.0 ## Movement speed multiplier while this is in your hands (sprint included).
@export var holster_time: float = 0.25
@export var ads_time: float = 0.22 ## Seconds to fully aim in.
@export var ads_zoom: float = 1.15 ## FOV zoom while aiming (1 = none).
@export var ads_move_speed: float = 0.55 ## Movement speed multiplier while fully aimed.
@export var sprint_to_fire_time: float = 0.22 ## Delay after sprinting before you can shoot.

@export_group("Accuracy")
@export var hip_spread: float = 2.0 ## Degrees (cone radius) when standing still.
@export var ads_spread: float = 0.0 ## 0 = perfectly accurate when aimed.
@export var move_spread: float = 1.2 ## Added at sprint speed (hipfire only).
@export var air_spread: float = 2.0 ## Added while airborne (hipfire only).
@export var bloom_per_shot: float = 0.12 ## Hipfire spread grows while you hold fire.
@export var bloom_max: float = 1.2
@export var bloom_decay: float = 5.0 ## Degrees per second.

@export_group("Recoil")
## Per-shot camera kick in degrees: x = yaw (right +), y = pitch (up +).
## When a spray runs past the end, the last 8 entries loop.
@export var recoil_pattern: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.5)])
@export var recoil_scale_ads: float = 0.85
@export var recoil_jitter: float = 0.05 ## Random degrees added per shot.
@export var recoil_recovery: float = 10.0 ## Degrees/s the view drifts back after you stop firing, only for recoil you didn't pull down. 0 = none (pure Apex).
@export var view_punch: float = 0.6 ## Visual-only camera shake per shot, degrees. Doesn't move your aim.

@export_group("Viewmodel")
@export var hip_position: Vector3 = Vector3(0.19, -0.2, -0.52)
@export var ads_position: Vector3 = Vector3(0.0, -0.077, -0.38)
@export var kick_back: float = 0.035 ## Metres the gun pushes back per shot.
@export var kick_rotation: float = 3.0 ## Degrees the muzzle flips up per shot.
@export var muzzle_flash_size: float = 1.0

@export_group("Melee")
@export var light_damage: float = 30.0
@export var light_hit_time: float = 0.14 ## Seconds into the slash when the hit lands.
@export var heavy_damage: float = 60.0
@export var heavy_hit_time: float = 0.36
@export var quick_hit_time: float = 0.18 ## Quick melee (V) from a gun.
@export var melee_range: float = 2.0

@export_group("Throw")
@export var throw_damage: float = 25.0 ## Damage when a thrown gun hits a target (x2 on the head).
