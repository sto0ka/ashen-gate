# Ashen Gate

A native Linux dark-fantasy FPS built in **Godot 4.7 (Forward+ Vulkan)** combining classic retro-FPS speed with modern 3D articulated viewmodels & enemies, PBR stone/basalt/metal relief, volumetric fog & god-rays, SSAO/SSIL/SSR, real joint/buoyancy physics set-pieces, spatial 3D audio, and Half-Life-style uninterrupted first-person storytelling.

![The Sunken Court](assets/preview.png)

## Play

```bash
./run.sh
```

The launcher uses Godot 4.7.2 if installed, otherwise the bundled Linux runtime or a one-time download of the official Linux runtime.

## Act I Campaign (Foundation — 3 Sprawling Modular Chapters)

Seven years after helping forge Vaelor's resonance locks, exiled Bell-Wright **Caelen** returns to the Ashen Gate as its fractured seal inverts and drains the living city outside.

1. **Chapter I — The Sunken Court** (`scripts/chapters/chapter_1_court.gd`): Cross the outer viaduct, meet **Archivist Seraphina** in person behind the Gatehouse grate, flood the West Cistern to ride **buoyant timber rafts** to the secret parapet (**Heart of Vaelor** relic), outsmart the sound-reactive **Bell-Bound Stalker** in the East Ossuary, and solve the **Counterweight Portcullis**.
2. **Chapter II — The Bell Tower** (`scripts/chapters/chapter_2_tower.gd`): Claim the **Voltaic Tuning Fork (`4`)** in the Clockwork Gallery, energize and ride the **Ascending Counterweight Lift** (shooting jammed latches mid-ascent), swing the real **`PinJoint3D` bronze pendulum** in the East Foundry, confront **Lord Malcor** face-to-face in the Choir Loft, ring the Harmonic Chimes, and defeat the **Bell Warden** in the open-sky Belfry Sanctum.
3. **Chapter III — The Kiln of Ash** (`scripts/chapters/chapter_3_kiln.gd`): Reunite with Seraphina overlooking the furnace, power the Aqueduct pump with Voltaic lightning, freeze cascading water spouts into 12s ice stepping stones, smash the Smeltery slag dam with the ore-cart, forge the **Ashen Key**, survive the **Rising Slag Meltdown**, defeat the mid-campaign guardian **Crucible Colossus**, and unseal the **Great Ashen Gate** into Act II.

## Controls

| Input | Action |
| --- | --- |
| `WASD` / Mouse | Move / Look |
| `Shift` / `C` (`Alt`) / `Space` | Sprint / Aether Dash / Jump (coyote time + ledge mantle) |
| `1` / `2` / `3` / `4` | Runed Cleaver-Axe / Briar Arbalest / Cinder Thurible / Voltaic Tuning Fork |
| `LMB` | Attack / Fire / Hurl held object |
| `RMB` | Frost Bolt (10 Blue Mana) — freezes foes, water channels, spouts, and steam pipes |
| `MMB` / `X` | Timed Parry — negates blow, stuns attacker, restores +25 Blue Mana |
| `Q` | Telekinetic Repulse (15 Blue Mana) — wall-slams foes, reflects orbs, swings pendulum |
| `G` | Telekinetic Grasp — levitate urns/blocks/casks or **rip tower shields off Executioners** |
| `E` | Interact (NPCs, levers, valves, alchemical fonts, portals, inscriptions) |
| `F` | Alchemical Flask (+45 HP, refilled at Alchemical Fonts) |
| `Tab` / `J` | Automap / Story Journal |
| `F5` / `F9` | Quicksave / Quickload (plus automatic milestone checkpoints) |
| `Escape` | Pause & Settings Menu (sensitivity, difficulty, Vulkan graphics toggles) |

## Verification Tests

```bash
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/smoke.gd
.tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/physics_magic.gd
```
