# FPS Prototype (Godot 4.5)

Greybox FPS prototype: Apex Legends-style movement and gunplay, plus a firing range map.

## Open it
1. Install **Godot 4.5+** (standard build, not .NET).
2. Godot Project Manager → **Import** → pick `project.godot`.
3. Press **F5** to play.

## Controls
| Action | Key |
|---|---|
| Move | WASD |
| Sprint | Shift (forward only) |
| Jump | Space |
| Crouch / Slide | Ctrl or C (slide = crouch while sprinting) |
| Fire / Aim down sights | Mouse 1 / Mouse 2 (knife: light slash / heavy stab) |
| Reload / Inspect / Quick melee | R / F / V |
| Weapon 1 / Weapon 2 / Knife | 1 / 2 / 3 (or scroll wheel) |
| Throw weapon / Pick up | G / E |
| Buy menu (in a buy zone) | B |
| Pause menu / Settings | Esc |
| Debug readout | F3 |

## Weapons
You carry **two guns and a knife**. You start with the Carbine and Sidearm. All three guns float on the rack on the bench in front of you (they restock after 3 s): look at one and press E to pick it up, or swap it for the gun in your hands when both slots are full.

| | Carbine | SMG | Sidearm | Knife |
|---|---|---|---|---|
| Style | R-301-ish AR | R-99-ish SMG | Wingman-ish hand cannon | Always carried |
| Fire | Auto, 780 rpm | Auto, 1000 rpm | Semi, 300 rpm | Light slash / heavy stab |
| Damage (head) | 14 (24.5) | 11 (16.5) | 45 (90) | 30 / 60 |
| Mag | 28 | 22 | 6 | — |

- **G throws your gun.** It spins end over end, hits a target for 20–30 damage (x2 on the head), and lands as a pickup with its ammo intact. You switch to your other gun, or the knife.
- **Buy menu (B):** works inside the green buy zones (spawn, and the movement course hub). CS:GO-style radial: pick a category (Pistols, SMGs, Rifles, Knives), then an item. Point with the mouse or press its number, click to buy; right-click goes back, B or Esc closes. You can keep moving while it's open. Everything is free. Buying a gun you own refills it; otherwise it fills a free slot or replaces the gun in your hands (the old one drops).
- **Knives** come from the buy menu, CS2-style. The last one you bought is saved for next time. Every knife cuts the same; each has its own look, draw, inspect (F) and quick-draw flair:
  - **Combat Knife:** end-over-end flip toss.
  - **Karambit:** curved claw blade; spins twice around your finger through the ring.
  - **Butterfly Knife:** comes up closed and flips open one handle at a time; inspect does full aerials.
  - **Flip Knife:** wrist flick snaps the folding blade open; inspect folds it shut and flicks it back.
  - **Bayonet:** long blade, tossed up barrel-rolling around the blade.
- **V is a quick knife slash** from any gun: the gun ducks away and the knife cuts in from the side.
- **Draws take turns:** each time you pull out a weapon it alternates between its flourish and a quick raise. Flourishes: the Carbine spins up and racks its charging handle, the SMG gets tossed into a flip, the Sidearm does a revolver twirl, each knife has its own (below). You can shoot once `draw_time` passes; firing or aiming cuts the rest of the flourish. Any animation in a weapon's scene whose name starts with `draw` joins the rotation. A freshly picked-up or bought gun starts with its flourish.
- **What's in your hands changes your speed (sprint included):** rifles and SMGs 1.0x, Sidearm 1.06x, knife 1.12x (`move_speed` in each `.tres`).

- **Recoil is Apex-style:** each gun kicks your view in a fixed pattern you learn to pull down against. ADS shots go exactly where the crosshair is; hipfire has spread (the crosshair gap shows it). Recoil you didn't pull down drifts back after you stop firing (set `recoil_recovery` to 0 for pure Apex).
- Firing or aiming stops a sprint, and there's a short sprint-to-fire delay.
- Empty mag auto-reloads. Ammo goes in ~70% through a reload; switching weapons before that cancels it.
- Melee works mid-reload. Inspect cancels on fire, aim, reload or switch.
- Targets have 100 shield (purple) + 100 health like purple armour, show damage numbers, fall over when killed and refill after 3 s without damage.

## Movement tricks to test
- **Slide boost:** sprint, then crouch. You get +2.4 m/s once every 2 s.
- **Slide-hop:** jump out of a slide and keep crouch held. You'll re-slide on landing and keep your speed.
- **Bunny hop:** press jump just before landing. You skip friction on the landing tick.
- **Air strafe:** in the air, hold A or D and turn the mouse the same way.
- **Slide ramp:** slide down the orange ramp to build speed (~13–14 m/s).

## Settings (Esc → Settings)
- **Mouse & View:** sensitivity on the CS2/Source scale (type in your CS2 value), ADS sensitivity multiplier (1.0 = zoom-matched), invert Y, and FOV (horizontal at 16:9; 106 = CS2).
- **Controls:** hold or toggle for crouch, sprint and aim (aim is toggle by default), plus a primary and secondary binding for every action. Click a binding, then press a key or mouse button. Esc cancels, Backspace clears. Binding a key that's already in use unbinds it from the other action.
- Settings save automatically to `user://settings.cfg` (on Windows: `%APPDATA%\Godot\app_userdata\FPS Prototype\`).
- New actions show up in the menu once you add them to `REBINDABLE` in `scripts/settings.gd`.

## Tuning
Select `Player` in `scenes/player.tscn`. Every movement value is in the Inspector, grouped by Ground, Air, Slide, Crouch and Camera FX. Viewmodel sway, bob and poses are on the `Viewmodel` node.

Each weapon's stats (damage, fire rate, spread, recoil pattern, ADS zoom, reload times, melee timings, viewmodel positions) are in `weapons/*.tres`. Open one in the Inspector, even while the game runs. The starting loadout, knife, infinite reserve ammo and throw settings are on the `Weapons` node in `player.tscn`.

**Animations** are keyframed in each `scenes/weapons/*.tscn`. Open one, select its `AnimationPlayer` and edit in the Animation panel. `Pivot` moves the whole hand, `Pivot/Gun` moves the weapon alone (spins, tosses), plus `Magazine` and `Bolt`/`Slide`. Method keys calling `play_sfx` trigger sounds. Guns need: `idle`, `draw`, `draw_quick`, `inspect`, `reload`, `reload_empty`, `melee_lower`. Melee weapons need: `idle`, `draw`, `draw_quick`, `inspect`, `slash_left`, `slash_right`, `heavy`, `quick_slash`. Reloads are stretched to the weapon's reload time; the melee hit lands at the `*_hit_time` in the knife's `.tres`.

To add a gun: duplicate a `.tres` and a scene in `scenes/weapons/`, then add a `WeaponSpawner` (scripts/weapons/weapon_spawner.gd) for it in the map. To add a knife: duplicate a knife `.tres` and scene, then add it to `KNIVES` in `scripts/settings.gd` so it shows up in the buy menu. New guns go in the buy menu's categories at the top of `scripts/ui/buy_menu.gd`. To add a buy zone, drop a `BuyZone` (Area3D with scripts/buy_zone.gd) in the map and set its `size`. The butterfly's handles (`Pivot/Gun/HandleA`, `HandleB`) and the flip knife's blade (`Pivot/Gun/BladeHinge`) have their own animation tracks.

## Layout
```
scenes/firing_range.tscn   main map (range lanes + movement course)
scenes/player.tscn         player, camera, box viewmodel, HUD
scenes/target.tscn         box target (Body/Head have a "hitzone" meta for hit detection)
scenes/weapons/            box viewmodels + their keyframed animations (Pivot/Gun, Pivot/Arms, AnimationPlayer)
weapons/                   weapon stats (WeaponData resources)
scripts/player/            player.gd (movement), viewmodel.gd (procedural motion)
scripts/weapons/           weapon_manager.gd (slots, fire/ADS/reload/switch/melee/throw/pickup), weapon_data.gd,
                           weapon_pickup.gd (guns in the world), weapon_spawner.gd (rack), viewmodel_rig.gd,
                           weapon_fx.gd (tracers, impacts, flash)
scripts/target.gd          shield/health, damage numbers, knockdown and reset
scripts/sfx.gd             Sfx autoload: placeholder sounds synthesized at startup (no audio files)
scripts/settings.gd        Settings autoload (sens, FOV, modes, bindings, save/load)
scripts/ui/                pause menu + settings UI (autoload), debug HUD, crosshair + hit markers, weapon HUD
materials/                 grid materials, viewmodel shader (no wall clipping)
tools/build_scenes.gd      generated the original scenes. Don't rerun it: it would overwrite player.tscn with the old pre-weapons version.
tools/build_weapons.gd     generated scenes/weapons (incl. animations) and weapons/*.tres. Don't rerun once you've tuned them in the editor.
```
