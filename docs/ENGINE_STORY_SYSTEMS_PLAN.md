# Ashen Gate Act I engine and story systems plan

Target Godot **4.7.2.stable.official.ed1daf0bf**, Forward+ Vulkan and the same gameplay scripts under the headless display driver. Act I covers the Sunken Court, Bell Tower and Kiln of Ash. Story plays in the world with the player camera current throughout. The four chapter crossings use physical routes and a 0.45-second dark fade.

## 1. Story director and chapter crossings

### Engine audit and ownership

| Script | Current behavior and integration point |
| --- | --- |
| [main.gd](../scripts/main.gd) | Owns player, world, puzzles, interaction, trigger bookkeeping, chapter rebuild, save/load and several story effects. `_use()` and `_update_prompt()` know about portal proximity. `_damage_enemy()` directly removes the Belfry floor, creates a portal and announces boss phases. `_physics_process()` drives audio, narrative and torch flicker, with early exits for hitstop and overlays. Move story scheduling, transition state and torch overrides out of these paths. Keep player, combat and gameplay rules here or in their existing modules. |
| [narrative.gd](../scripts/narrative.gd) | Has FIFO subtitle playback, a title card and independent style/checkpoint tweens. Malcor departure polls speaker label text and queue contents from `main.gd`. Add line and group lifecycle signals plus a shared layout. |
| [audio_3d.gd](../scripts/audio_3d.gd) | Plays one shared ambient loop and one synthesized combat loop, with chapter-specific reverb for positional voices. Retain the synthesis and voice lifetime machinery. Replace the shared music pair with chapter stems. |
| [level_builder.gd](../scripts/level_builder.gd) | Provides architecture, hanging lamps, puzzle indicators, echoes and player-only Area3D triggers. Reuse the construction helpers. Centralize story trigger registration and move collision-affecting story effects outside Area3D signal callbacks. |
| [visuals.gd](../scripts/visuals.gd) | Provides chapter environments, PBR textures, decals, gibs and GPU particles. The current decals face floors and time out. Extend placement to surfaces and add separately authored persistent traces and bounded bursts. |
| [save_system.gd](../scripts/save_system.gd) | Schema v2 stores named chapter dictionaries, a player pose, journal and flags. Legacy integer stages are upgraded. Atomic temporary-file rename already protects the previous save. Keep this envelope and add normalization for the new nested state. |
| [map_overlay.gd](../scripts/map_overlay.gd) | Redraws live player, ward, boss, font, NPC and portal markers. Derives chapter metadata and uses `get_objective_target()` with legacy fallback. Feed it physical exits from the same route registry as the compass. |
| [chapter_registry.gd](../scripts/chapters/chapter_registry.gd) | Preloads builders and owns chapter metadata/state defaults. Add a music profile ID, named arrivals, safe spawn markers and route validation. Each chapter builder owns its own geometry, actor marks, trigger placement and sequences. |

### Class and integration contract

`scripts/story_director.gd` extends `Node`. Instantiate one director as a child of the game root. Every rebuild starts a new director generation. The active level root owns actors, moving geometry, positional sounds and effects. The director owns the scheduler, target and exit registrations, transition fade and trace signals. `main.gd` bridges gameplay events and supplies the existing state, audio, narrative and player references. The director holds a weak reference to the game and preloads the leaf modules it calls. Use static construction helpers for chapter builders and an instance for live state.

```gdscript
# StoryDirector public API
static func trigger_sequence(game, seq_id: String) -> bool
func setup(game: Node, fade_rect: ColorRect) -> void
func begin_chapter(chapter: String, level: Node3D, state: Dictionary) -> void
func register_target(id: String, target: Node3D) -> void
func register_sequence(spec: Dictionary) -> void
func register_story_volume(area: Area3D, trigger_id: String, seq_id: String) -> void
func register_transition(area: Area3D, marker: Marker3D, route: Dictionary) -> void
func register_arrival(id: String, marker: Marker3D) -> void
func get_arrival(id: String) -> Marker3D
func finish_chapter_build() -> void
func start_sequence(seq_id: String) -> bool
func step_physics(delta: float) -> void
func request_transition(route_id: String) -> bool
func is_transitioning() -> bool
func cancel_chapter(reason: String) -> void
func get_exits() -> Array[Dictionary]
func get_exit_position(route_id: String, require_open: bool = true) -> Variant

signal sequence_started(seq_id: String)
signal beat_applied(seq_id: String, beat_id: String)
signal sequence_finished(seq_id: String)
signal sequence_cancelled(seq_id: String, reason: String)
signal transition_finished(route_id: String, chapter_id: String, checkpoint_written: bool)
```

- `trigger_sequence` forwards to `game.story_director.start_sequence()` and returns true when a request has been accepted. Duplicate, unavailable, stale and already-completed one-shots return false. Register all specs and node targets before activating volumes in `finish_chapter_build()`. Build validation rejects duplicate IDs, missing required targets or marks, unknown opcodes and malformed arguments. Return a clear diagnostic with chapter, sequence and beat for an invalid registration. Allow an explicitly optional visual target to disappear without breaking gameplay.
- Chapter builders call `register_target()` with level-local stable IDs and use scoped IDs for sequences and triggers. A spec has `id: String`, `once: bool`, optional read-only `when: Callable`, and ordered `beats: Array[Dictionary]`. Each beat has `id: String`, `at: float` in seconds from acceptance into the running timeline, `op: StringName`, `target: String` when needed and `args: Dictionary`. `args` is validated per opcode. A live job contains generation, acceptance serial, time, next beat index and active jobs for movement or contact. Sort due beats across sequences by absolute due time then acceptance serial then authored order. Emit `beat_applied` after dispatch. Completion waits for owned motion and impact jobs with a specified fallback and deadline.
- Wire one call to `step_physics()` at the start of the game's physics step, ahead of combat hitstop. It drains queued Area3D events and advances fixed-delta timelines. Story continues through hitstop and while the player looks away. Gameplay and narrative clocks suspend with the current pause/map/journal behavior, including actor moves, torches and queued triggers. Defer structural scene/collision changes that originate inside physics callbacks. Each deferred task checks the generation and its target's validity before applying. Kill or cancel level-owned jobs on unload, death or explicit reload. Any declared persistent effect already owed to the player is restored using the rules in section 5.
- Use an opcode dispatcher with explicit cases and validated payloads. Chapter story specs contain data and may register an allowlisted, named gameplay commit callable during build for existing puzzle actions. The dispatcher owns timing and effects. The gameplay task still checks prerequisites and owns damage, collision outcomes, items and objective updates. Each moving door, light group and actor has a single owner of transforms or energy. Chapters provide geometry and marks. The director never samples widget text or takes ownership of player aim.

| Opcode | Payload and live behavior |
| --- | --- |
| `resonance` | Target is the world emitter. Args `radius`, `speed`, `strength`. Play spatial `resonance_wave`, emit a moving dust/wave front, and request the player's additive shake and brief post pulse as the front reaches the player. Use previous/current wave radius to catch crossings on a long physics step. Ambient fronts deal zero damage. Combat keeps its own hit rules and can dispatch the same visual effects. |
| `rockfall`, `chandelier_drop` | Target is a fracture assembly or suspended prop. Args identify the authored settled geometry, debris budget, optional impact tag and bounded contact deadline. Swap solid geometry at the fracture event and release debris with Godot rigid-body physics. Use section 4 helpers and emit impact audio/particles at the contact point. |
| `walk_to`, `gesture`, `look_at`, `vanish` | Targets are registered actors. Args include `mark`, route marks, `speed`, `animation`, `duration` and/or FX cue as applicable. Use authored waypoint paths with clearance checks. Drive a `CharacterBody3D` with `velocity` and `move_and_slide()` on physics ticks where collision is needed, or a `Node3D` rig on a dedicated clear path for behind-grate and spectral actors. Use `AnimationPlayer.play()` on the body/gesture tracks. Yaw the actor rig toward the target on the horizontal plane, respecting left/right sprite facing and a zero-length guard. A blocked actor may retry briefly, then perform the mechanical action from the safe authored fallback. Vanish plays world FX/audio, hides the actor and unregisters interaction and map markers in the same commit. |
| `torch_group` | Args `group`, `scale`, `duration` and optional flicker amplitude. Compose a seeded flicker around stored base `light_energy` with story attenuation. Drive light and flame material together. Maintain readable emergency light/wayfinding during the Ossuary blackout. |
| `move_body` | Target `AnimatableBody3D`, args `end_mark`, `duration`, optional `cue`, optional clearance commit. Animate on physics ticks with `sync_to_physics` and one movement owner. Preserve collision until the real aperture clears. For occupied closing motion hold or reverse. Existing puzzle-driven water, raft buoyancy and lift movement keep their existing simulation owners. |
| `voice`, `foley`, `commit` | `voice` submits line data and a world origin to Narrative; `foley` plays a positional stream via Audio3D. `commit` invokes a named action registered for this chapter and generation. Journal entries use stable IDs and the existing `_story_event()` bridge. |

Use a per-event `RandomNumberGenerator` seeded from a stable authored integer or ID and a beat index. Gameplay RNG and camera shake RNG already share state in `main.gd`; new story FX use an isolated stream. Route view shake through the existing additive camera-effect path with a tunable story cap of 0.12 m, distance attenuation and a short decay. The player retains yaw, pitch, aim, weapons and movement throughout sequences. [Godot 4.7 AnimatableBody3D](https://docs.godotengine.org/en/4.7/classes/class_animatablebody3d.html)

### Act I sequences and acceptance beats

Times are initial authoring targets in seconds, relative to sequence start. A named contact or motion-completion event and its fallback both go through the same one-shot commit. Keep each listed beat's ID stable for tests. Existing written dialogue and journal IDs are reused where applicable.

| Sequence ID and trigger | Required beats and committed outcome |
| --- | --- |
| `ch1_court/gatehouse_meeting` on approach or first interaction | `greet` at 0 with Seraphina turning and speaking; `reach_bar` at 0.3 with a walk to the winch mark; `gesture` at 0.9; `lift_bar` at 1.25 over 0.8; `clear_bar` on clearance. Continue the remaining lines during play. Save her final mark and bar state. |
| `ch1_court/gatehouse_fracture` on crossing the opened interior bar | `toll` at 0 from the far bell; `grit` at 0.35 with dust and a short torch gutter; `fracture` at 0.8 with a side-arch masonry fall; `settled` by 2.5 with a static rubble shoulder and a walkable through lane. The route and the winch remain reachable from both sides. |
| `ch1_court/cistern_sluice` on accepted lever pull | `wheel` at 0; `surge` at 0.2 with `flood_rush` at the sluice and a waterline indicator. Retain the target at 1.45 m, rise at 0.95 m/s and simulated raft lift. `high_water` fires when the water reaches target. |
| `ch1_court/ossuary_blackout` on Iron Lever pickup | `snuff` at 0; `stingers` at 0.7 from ambush approach; `reinforcements` at 2.0 with existing three IDs and dead-ID filtering; `relight` at 2.15. An optional guard echo is spatial and uses its own subtitle line ID. |
| `ch1_court/north_portcullis` on gearbox and two weighted plates | `ratchet` at 0; `rise` starts from current height and uses 2.6 m/s to y=5.2. Lever alone raises to y=1.9; preserve existing teeth and partial blockage. `clear_exit` at real aperture clearance and expose the exit marker. `ch1_court/viaduct_toll` independently dispatches `toll` and `dust_front` on viaduct approach. |
| `ch2_tower/nave_chandelier` on first lower-nave approach | `peal` at 0; `chain_slip` at 0.35; `release` at 0.65; `impact` on first qualifying world contact, with timeout 1.8 s after release; `settled` after impact. Leave a readable side lane around nonblocking final wreckage. |
| `ch2_tower/choir_departure` on first Malcor conversation or final-ward fallback | `address` at 0; `turn` at 0.3; `retreat` at 1.0 toward the Choir arch mark; `dissolve` after the dialogue group finishes, at a bounded 16 s fallback, or immediately on Belfry activation after retiring that group's queued lines. The last two cases use the same departure commit. |
| `ch2_tower/belfry_awakens`, `warden_phase_two`, `belfry_shaft` in the Tower namespace | Crossing the unsealed Belfry threshold fires `awaken` once. The Warden's existing phase rule at HP ≤260 dispatches `phase_toll` and `orb_callout` after the combat phase commit. Death schedules `dying_breath` at 0 from the Warden's last position, `joist_crack` at 0.4 and `open_shaft` at 0.9; enable the shaft transition only after colliders update. |
| `ch3_kiln/aqueduct_surge` on powered valve; `ch3_kiln/dam_break` on ore-cart impact | The valve emits `wheel_turn`, `trough_rush` and `high_water` at 0, 0.2 and 1.4. Impact against the dam emits `dam_fracture` and `slag_vent`; the existing hoist predicate observes the committed trough and dam flags. |
| `ch3_kiln/meltdown`, `colossus_overdrive`, `colossus_falls` in the Kiln namespace | Key pickup fires `alarm` and arms the rising slag at 0, `guardians` by 0.35 with stable spawn IDs, and `seraphina_warning` during the alarm lull. Slag continues at 0.28 m/s toward y=-0.14. Overdrive fires `anvil_overdrive` and `slag_burst` after HP ≤320 combat commit. Death emits `colossus_impact` and `gate_callout`. Keep the cauldron chain puzzle and one gameplay impact even when a save is requested during the fall. |
| `ch3_kiln/hollow_choir` on Great Gate approach; `ch3_kiln/great_gate_unseals` after valid key use | `whisper_swell` and `choir_line` come from beyond the leaves. On valid use play `iron_release` and slide the leaves toward x=±8.5 at 2.8 m/s; add `threshold_wind` as the seam widens. Commit `act_complete` when both leaves clear, autosave and show completion copy in the title lane with the world and player still live. Keep replay available through the existing action. |

Wire Warden and Colossus mechanical phase changes to a single idempotent combat function per boss, including Warden Aegis initialization and the phase-dependent attack pattern. Replace the two competing phase announcements in `_damage_enemy()` and `EnemyAI._update_warden_phase()` with an event after the mechanical update. The Belfry seal still depends on three wards; dying speech and shaft state are independent of subtitle timing.

### Physical routes

Use `LevelBuilder.add_transition_zone(parent: Node3D, zone_transform: Transform3D, size: Vector3, route_id: String) -> Area3D`. Attach one BoxShape3D, collision layer 0, mask `LAYER_PLAYER` (bit value 32), `monitorable = false`. Enable monitoring when the chapter is mounted. Register descriptor fields `id`, `destination`, `arrival_id`, `label`, `kind` (`"arch"` or `"drop"`), `direction_local`, `safe_return_id` and an optional open predicate. A Marker3D at the aperture provides the map position. The destination builder registers its arrival and fallback Marker3Ds by name. Connect `body_entered` and `body_exited` once. The handler accepts only the live player, records the generation and queues an intent. Require a crossing toward the destination plane with the route open. Track the previous/current signed plane distance inside the approach volume, including entry and exit samples, so standing in an area or entering from its back cannot travel. For the shaft require the player's feet to cross the plane downward. Evaluate after a physics sample and keep the box deep enough for a full-speed dash or fall per step. [Godot 4.7 Area3D](https://docs.godotengine.org/en/4.7/classes/class_area3d.html)

| Route ID | Physical aperture and destination arrival |
| --- | --- |
| `court_to_tower` | North Portcullis arch, Court x=0, z≈-31.8, beyond the existing gate at z≈-19. Extend floor into a short masonry breezeway before the backdrop; gate travel on real clearance. Arrive at `tower_from_court` in the Lower Nave south vestibule, facing into the nave. |
| `tower_to_court` | Matching arched vestibule near x=-7.5, z≈24.4. Split the south wall around a recessed opening and extend its slab. Arrive at `court_from_tower`, north of the Portcullis on the viaduct with the player facing back into Court. |
| `tower_to_kiln` | Belfry shaft x=0, z≈-42, floor y=9.5. Open floorboards after Warden death. Trigger below the broken deck and above the existing y=7 catch landing. Keep a continuous shaft wall around the drop and keep inset return steps outside the forward trigger footprint. Arrive at `kiln_from_tower` on the Foundry Landing at the bottom of a matching stone drop throat with floor clearance. |
| `kiln_to_tower` | A short, walkable service stair behind the return arch near x=7.4, z≈24.8. Cut the solid southern wall around the recess and provide a bottom/top landing. Arrive at `tower_from_kiln` on the ledge beside the y=7 shaft landing, clear of the drop Area3D and oriented toward the inset steps to y=9.5. |

Final transforms belong in the builders. Validate each arrival and safe return with the actual radius 0.35 m, height 1.8 m player capsule and its 0.9 m offset, a supporting downward ray and exclusion from every live exit/hazard/checkpoint volume. Keep a margin from entry volumes after arrival and require exit before rearming any trigger the player spawned inside. This protects both directions from bounce even when restoring a save at an old portal coordinate. Use matching brickwork, stairs, framed sightlines and muffled destination foley at each boundary.

Transition state machine advances on normal rendered time for fade and physics ticks for readiness. The default destination is a settled walk-in arrival, including after the shaft drop.

1. **Accept.** Check route, destination and arrival metadata, current generation, liveness, modal state and availability. Take a single travel lock before deferring any work. Reject other travel, new combat actions and reload requests through the short swap interval. Retain mouse look and existing camera; the player can walk to the boundary and settle on the catch floor or behind an opaque corner during fade-out. Release or return any held prop to the source level. Capture the stable source state and route fallback pose.
2. **Fade.** Use a black `ColorRect` with mouse filter ignore on its own highest `CanvasLayer`. Interpolate alpha 0→1 over 0.20 s, dwell for 0.05 s, then 1→0 over 0.20 s. Hide gameplay toast/subtitle presentation during the handoff. Apply the new chapter title after reveal; a return visit skips the introductory card by using a saved chapter-visit flag.
3. **Swap under black.** At full opacity, defer a call to the game-owned chapter mount. The mount validates the destination, lets the director clean up the old generation, detaches the old root, clears level references, builds the new chapter and hydrates durable state. It places the same player at the destination mark using its world orientation, clears linear/dash/jump state, calls `reset_physics_interpolation()` after teleport and refreshes objectives/HUD. Orient at the physical transfer only; there are no scripted pans. Verify shape and floor clearance using the live physics space after the colliders have registered. Use the authored destination fallback if the preferred mark is blocked. If both are invalid, rebuild the source from its snapshot at the safe return, cancel transition, and retain the previous checkpoint. Keep black until swap verification if the budget overruns, report the excess in the visual gate and finish or roll back within a bounded watchdog.
4. **Checkpoint.** Write a destination checkpoint after transform and state are coherent and before rearming destination volumes. Preserve current health, mana, loadout and all chapter states. Use ID `arrival/<destination>/<arrival_id>`. Coalesce or suppress any pending checkpoint signal from the source generation. On storage failure retain the previous file, clear the travel lock after reveal and report save failure without replaying the chapter; allow `_save_game()` to retry. Hold manual save requests received during travel and flush after the settled arrival; on rollback save only the settled source. Destination spawn triggers become live after the baseline physics sample and volume rearm rule. [Godot 4.7 physics interpolation](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html)

Remove the purple surface, plinth, portal sound calls and E-to-portal branch from Act I. Ward/rune materials can retain their violet palette. Keep `_change_stage()` and default spawn support for restart and tests. Factor `_mount_chapter(chapter_id: String) -> bool` out of `_load_chapter()` for validation, cleanup and build. Let its callers choose the arrival or restore pose and presentation policy. Travel passes the director's named arrival through this bridge. Save restore supplies the saved position and yaw/pitch after the mount. Initial load, restart and existing direct tests use the chapter default.

### Environmental tableaux

Build under the level root with fixed seeds and named targets. Return scene handles for tests and register interactive elements through existing lore/echo paths.

```gdscript
# StoryDirector static construction helpers
static func add_fallen_guard(parent: Node3D, pose: Transform3D, variant: String) -> Node3D
static func add_supply_scatter(parent: Node3D, pose: Transform3D, seed_value: int, count: int = 5) -> Node3D
static func add_masonry_pile(parent: Node3D, pose: Transform3D, material: Material, seed_value: int, solid: bool = false) -> Node3D
static func add_blood_trail(parent: Node3D, points: PackedVector3Array, normals: PackedVector3Array, seed_value: int) -> Node3D
static func add_broken_lantern(parent: Node3D, pose: Transform3D, light_group: String) -> Node3D
static func add_echo_wisp(game, pose: Transform3D, echo_id: String, line: Dictionary) -> Area3D
```

Use a pitched guard rig with grouped limbs and a dropped weapon; scatter authored crate silhouettes and only register puzzle props as pushables. Use fixed rubble geometry for persistent wreckage and one coarse collider where needed. Use oriented, low-depth marks for the trail. Build lanterns from existing lamp materials and register their glow and flame with the shared torch driver. Route echo wisps through `seen_echoes`, add a faint light and a world sound near their source, and bind them to the subtitle system. Place the first tableaux around the Gatehouse breach and Cistern quay, the second around the Choir Loft and nave approach, and the third beside the Kiln observation gantry. Wall art uses section 4's framed-quad helper.

## 2. Narrative UI and subtitle director

Keep the existing `setup()`, `tick()`, `show_chapter()`, `show_style_banner()` and `show_checkpoint_toast()` entry points. Preserve the four-argument `say()` call and legacy `play_sequence(lines)` dictionaries while moving new story callers to the structured entry point.

```gdscript
enum Priority { BACKGROUND, DIALOGUE, URGENT }
enum Interrupt { QUEUE, RESUME_LOWER, DROP_LOWER }

func submit_line(line: Dictionary) -> bool
func play_sequence(lines: Array, group_id: String = "") -> void
func cancel_group(group_id: String) -> void
func clear_chapter() -> void
func set_gameplay_hud_visible(active: bool) -> void

signal line_started(line_id: String)
signal line_finished(line_id: String, interrupted: bool)
signal dialogue_finished(group_id: String, cancelled: bool)
signal speaker_cue(cue_id: String, world_origin: Variant)
```

Line data has stable `id`, `group_id`, `speaker_id`, optional display `speaker`, `line`, finite positive `duration`, optional `color`, `priority`, `interrupt` and optional `world_origin: Vector3`. A queued line can additionally carry a chapter-local origin resolver for moving actors; resolve it at presentation and fall back to the authored last position. A missing origin is represented by `null`. Compatibility code maps legacy display names to speaker profiles, adapts colors and assigns a session ID to anonymous lines. Empty text and malformed content are rejected or defaulted at the adapter boundary.

| Speaker ID | Banner accent and presentation | Cue |
| --- | --- | --- |
| `seraphina` | Silver cyan `#70D7DF`, crisp label and accent bar | `cue_seraphina` |
| `malcor` | Tarnished bronze `#C7986A`, including his dying breath | `cue_malcor` |
| `guard` | Muted ash-ochre `#B6A18B` | `cue_guard` |
| `hollow_choir` | Violet `#C8A7FE` accent and pale violet italic body on a dark translucent panel. Preload a licensed true italic font or use a single cached `FontVariation` with `variation_transform` shear for the existing body font. | `cue_choir` |

A single current line occupies the subtitle lane. Select higher priority first, FIFO within a priority. An urgent callout with an immediate interrupt policy preempts only a lower-priority active line. `RESUME_LOWER` restores its remaining duration after pending urgent lines, silently on resumption. `DROP_LOWER` terminates that active line and cancels the remainder of its group. Emit the cue once, when a new line first becomes visible, at `line_started`. At most one new line begins per presentation tick so skipped frames do not play multiple inaudible cues. Emit `line_finished` only when a line expires or is dropped. Emit `dialogue_finished` once when the group's work drains or is cancelled. Malcor consumes this signal and retains the explicit timeout so puzzle progress never depends on the queue. Deduplicate live line IDs within the generation. Bound the queue at 32, evict oldest background entries first and count cancelled groups correctly. Pause presentation and clocks while the gameplay HUD is masked by the map, journal, pause menu or fade.

Put chapter cards, subtitles, checkpoint/style cues and existing message/prompt labels into one anchor-based layout in the current logical viewport. Use safe insets and container sizing with the actual wrapped text height. Reserve the top for the objective and boss HUD, space around the central reticle, and the existing bottom vitals strip. Subtitle uses the central lower lane immediately above the controls strip. Place the use prompt above the measured subtitle panel; center combat/checkpoint callouts in a bounded side lane with no part extending into the subtitle or prompt rects. Put the title card in the upper-middle story lane. It yields to active boss HUD or critical objective messages when safe space is insufficient. In a compact layout, defer title/style/checkpoint and hide lower-priority prompts while a subtitle is showing. Never clip urgent subtitle text or cover vitals/reticle; design and lint authored lines to wrap to at most three body lines at the minimum supported viewport. Recompute on `resized` and complete container layout before visibility checks. Set decorative controls to `MOUSE_FILTER_IGNORE`. Menu, journal and map own their modal canvas presentation.

## 3. Per-chapter music and synthesized foley

Add `Audio3D.set_chapter(chapter_id: String, acoustics: String, crossfade_seconds: float = 0.60) -> void` and `Audio3D.play_speaker_cue(cue_id: String, parent: Node3D, world_origin: Variant) -> void`. Keep `play_2d()`, `play_at()`, `set_combat_intensity()`, `set_room_acoustics()` and `stop_all()`. Accept an optional final `vol_db` argument on `play_at()` for authored levels. Connect Narrative's `speaker_cue` to Audio3D once via the game bridge. Spatialize a cue when its line has an origin; use a quiet 2D accessibility cue for origin-free lines. Reuse the positional bus routing for voices, chimes and story foley. Remove the portal stingers from NPC interactions. Journal text and speaker chimes remain available independently of sound device availability.

| Profile and room bus | Ambient stem | Combat stem | Base loop |
| --- | --- | --- | --- |
| `ch1_court` / Crypt | Slow crypt drone with filtered wind, organ fifth and hollow stone resonance | Low skin-drum rhythm and sparse bass response | 75 BPM, eight 4/4 bars, 25.6 s / 614,400 frames |
| `ch2_tower` / Cathedral | Inharmonic bronze overtones and long air decay | Tense muted eighth-note pulse with bell accents on bar turns | 96 BPM, 20.0 s / 480,000 frames |
| `ch3_kiln` / Furnace | Filtered furnace rumble and periodic bellows | Anvil strikes on a syncopated industrial groove, low bass under short metallic tails | 100 BPM, 19.2 s / 460,800 frames |

Generate PCM once per session at 24 kHz and warm all three pairs before gameplay travel. Benchmark boot separately; if generation misses the boot budget, bake the same deterministic PCM at build time and preload the resulting resources. Extend the existing sample pipeline with phase-periodic drones, repeatable noise with an overlapped seam, and wrapped percussion tails. Use signed 16-bit samples via `PackedByteArray.encode_s16()`, `AudioStreamWAV.FORMAT_16_BITS`, `mix_rate`, `stereo = false`, `loop_mode = LOOP_FORWARD`, and loop points 0 and the exact sample frame count. Validate the seam by testing the adjacent sample and slope deltas against typical in-loop differences. One-shots taper their first and final samples and use `LOOP_DISABLED`.

Each live chapter pair is a dedicated `AudioStreamSynchronized` with `stream_count = 2` and two equal-length stems assigned through `set_sync_stream()`. Start the pair once through a non-positional `AudioStreamPlayer` so stems stay phase-aligned while combat intensity changes. Apply the existing base levels (-17 dB ambient, -15 dB combat), with `set_sync_stream_volume()` for the two stem gains and `AudioStreamPlayer.volume_db` for chapter gain. Fade combat in over about 0.7 s and out over about 1.4 s, retaining the previous combat mix across the swap until the new room supplies a fresh target. Crossfade the old and new players in linear amplitude space using cosine/sine gains converted by `linear_to_db()`; stop and free the outgoing pair at completion. A same-chapter load updates acoustics and target without restarting the pair. On rapid hops reuse or retire decks and start from current gains with at most two chapter players. Keep music separate from room reverb. Positional voices remain owned by their source level; timed cleanup supplements `finished` under Dummy audio. Cap positional voices at 24 with priority for major story impacts and speech, and duck music about 3 dB briefly for urgent callouts and major impacts. [Godot AudioStreamSynchronized](https://docs.godotengine.org/en/4.6/classes/class_audiostreamsynchronized.html) · [Godot 4.7 AudioStreamWAV](https://docs.godotengine.org/en/4.7/classes/class_audiostreamwav.html)

| Stream key | Length | Synthesis and routing |
| --- | --- | --- |
| `collapse` | 2.40 s | Staggered stone transients, filtered broadband fracture and decaying low rubble rumble. Use at masonry or chandelier impact with material pitch variation. |
| `resonance_wave` | 1.65 s | Descending 60→32 Hz sweep under a cracked, inharmonic bronze ring. Start at the emitter, with propagation FX offset handled by the director. |
| `choir_whisper` | 2.80 s | Detuned harmonic voices with band-filtered breath and slow swell. Spatial, from the Choir location. |
| `flood_rush` | 2.20 s | Attack ramp and broad water noise around low surges and small resonant bubbles. Position at the sluice, then let existing steady water ambience carry the scene. |
| `cue_seraphina` | 0.55 s | Silver-glass partials with quick clear decay. |
| `cue_malcor` | 0.75 s | Low bronze fundamental with off-harmonic bell tail. |
| `cue_guard` | 0.40 s | Muted low tone plus brief grit. |
| `cue_choir` | 0.80 s | Quiet beating minor-second chord and spectral breath. |

Use separate dry cue levels around -22 dB before positional attenuation. Normalize synthesized one-shots below clipping and test loudest combined voices against the headroom budget. Extend the existing format-based synth helpers rather than introducing real-time sample generation in gameplay.

## 4. Level construction and visual effects

```gdscript
# LevelBuilder
static func add_wall_mural(game, parent: Node3D, mural_id: String, pose: Transform3D, size: Vector2, art: Texture2D, normal: Texture2D = null, inspect: Dictionary = {}) -> Node3D
static func trigger_rockfall(parent: Node3D, fracture: Node3D, settled: Node3D, seed_value: int, count: int = 12) -> Array[RigidBody3D]
static func drop_chandelier(parent: Node3D, suspended: Node3D, wreck: Node3D, seed_value: int) -> RigidBody3D

# Visuals
static func spawn_surface_splatter(parent: Node3D, hit_pos: Vector3, normal: Vector3, kind: String, radius: float, seed_value: int, persistent: bool = false) -> Node3D
static func spawn_dust_burst(parent: Node3D, world_pos: Vector3, direction: Vector3, kind: String, seed_value: int) -> GPUParticles3D
static func set_resonance_pulse(material: ShaderMaterial, strength: float) -> void
```

- **Murals and tapestries.** Construct an oriented holder with a `QuadMesh` in front of the wall and `StandardMaterial3D` using `albedo_texture`, `normal_enabled` and `normal_texture`. Use a cached textile or engraved relief normal; reuse `make_normal_map()` during preparation if the art has a suitable grayscale height source. Set restrained emission for luminous pigment and use `focus_light()` for one subtle spotlight, with a PBR stone/bronze frame built from existing mats. Use wall-pinned cloth or framed quads for relief response; reserve Sprite3D for the luminous wisps or decorative flat overlays. `inspect` accepts `title`, `writing` and optional `interact_hint`. Register one static world-space entry with a stable `mural_id` in the inscription path. Select it using a short player-facing ray and a distance limit in the existing E-use bridge. Write `inscription_<mural_id>` once. Decorative art adds no interaction or physics collider unless the existing wall needs it. Author motifs for Vaelor's broken oath in the Court, the ward order in the Tower, and memory molds in the Kiln.
- **Rockfall.** A fracture assembly contains authored intact colliders and a settled variant. On fracture capture the world pose, defer the intact collision change out of the physics signal, and instantiate seeded convex or box-shaped `RigidBody3D` fragments as siblings under the level root. Set transforms at spawn, apply a bounded `apply_central_impulse()` and `apply_torque_impulse()`, and let physics take over. Use `LAYER_DEBRIS` and a world-only mask for ordinary cosmetic pieces. Supply a separate authored static obstruction when progression requires a blocked path. Check actual player occupancy before bringing settled collision online and retain a valid escape lane. Retire fragments on a bounded lifetime with up to 24 story rigid bodies simultaneously. Preserve the existing damage and Repulse paths for gameplay props.
- **Chandelier.** Detach the chain visual at release; build a low-complexity rigid body with the lamp mesh, `continuous_cd = true`, `contact_monitor = true`, and `max_contacts_reported = 4`. Capture the first world-body collision after release using `body_entered` and defer the impact transaction. Derive the contact point from direct body state when available, with a world downward ray and the authored floor mark as fallbacks. If the first qualifying contact is never reported, resolve at the authored point after the deadline. Trigger `collapse`, dust, additive camera shake and sparks exactly once, then replace the falling prop with the authored static wreck, separated from the through lane. Use the same impact discipline for the gameplay cauldron but route damage through its existing area-of-effect rule. [Godot 4.7 RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html)
- **Impacts.** Resolve floor/wall hit points and normals in world space. Orient each `Decal` with local +Y along the surface normal; size.y is projection depth. Use small atlas-backed albedo/normal/ORM variants, a narrow depth and world-only render cull mask to keep marks off actors and thin adjacent surfaces. Layer dark blood with smaller droplets, rough scorch around hot hits and pale-emissive frost crystals. Supply `texture_emission` for emissive frost and restrict its energy. Preserve the existing `spawn_decal()` entry point as a floor wrapper. Use a 48-slot per-level transient budget with oldest-first retirement, keeping author-placed trails in a small separate fixed budget. Restore authored trails with the level build. Headless checks placement descriptors and cleanup; a mesh-quad fallback is sufficient for compatibility inspection. [Godot 4.7 Decal](https://docs.godotengine.org/en/4.7/classes/class_decal.html)
- **Resonance and particles.** Use a fullscreen `canvas_item` shader with `hint_screen_texture`, `SCREEN_UV`, and radial RGB sample offsets capped at 1.5 output pixels, plus a tinted edge vignette. Apply it on a dedicated canvas below HUD text and above 3D, with a 0.06 s attack and 0.24 s decay. Gate the screen copy by hiding the pass when amplitude is zero. Compose with the existing damage/low-health treatment, keep legibility and drive both shake and shader intensity from one scalar. Render a world-space dust front and one-shot bursts at vault seams using `GPUParticles3D`, a `ParticleProcessMaterial` and existing sprite materials. Start with 32–96 particles per burst and at most four bursts per active level. Set `one_shot`, `explosiveness`, fixed seed, and a correct `visibility_aabb`. Lifetime cleanup works on the CPU even when GPU emission is absent. [Godot 4.7 screen reading](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html) · [Godot 4.7 GPUParticles3D](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html)

Reapply graphics preferences after each `configure_environment()` call, which currently reinstates chapter environment defaults. Forward+ owns the rendered result. Gameplay and save branches use state and physics and run identically under Dummy rendering.

## 5. Save schema, automap and verification

### Schema v2 additions and restore semantics

Keep `schema_version: 2`, `chapter_id`, existing save paths, integer-stage migration and top-level flags. Add this optional nested contract to each chapter's `ChapterRegistry.default_state()`. JSON values are booleans, finite numbers, strings, arrays and dictionaries. Store stable IDs rather than Godot instances or resource paths.

| JSON path / type | Defaults and values | Restore contract |
| --- | --- | --- |
| `level_states.<chapter>.story_world` / object | Fresh object per chapter. Nested keys below. | Merge known fields by key with defaults. Validate each new field and use a safe default for invalid values. Preserve legacy fields and aggregate history. |
| `level_states.ch1_court.story_world.gatehouse_arch_collapsed` / bool | `false` | Restore missing side masonry, fixed rubble and the clear lane. |
| `level_states.ch1_court.story_world.seraphina_mark` / string | `"gatehouse_grate"`; final `"gatehouse_winch"` | Snap the actor to a registered mark with an authored facing. On pre-addition saves with `gatehouse_open == true`, default to the winch. |
| `level_states.ch2_tower.story_world.nave_chandelier_fallen` / bool | `false` | Restore the wreck and remove suspended lamp and obsolete collision. |
| `level_states.ch2_tower.story_world.malcor_departed` / bool | `false` | Omit the Choir actor and its interact/map entry. For an absent field in a legacy save infer departure from `npc_malcor_choir` or three resolved wards, matching current chapter-load behavior. |
| `level_states.ch2_tower.story_world.belfry_shaft_open` / bool | `false` | Swap the floorboards for the open shaft. On prior saves and pending collapse reconciliation derive open from `boss_dead`. An open shaft requires a defeated Warden. |
| `level_states.ch3_kiln.story_world.seraphina_mark` / string | `"kiln_observation"`; final `"kiln_safe_gantry"` | Move the actor to the safe gantry during meltdown. Restore to that mark when `gauntlet_triggered` is durable. |
| `level_states.<chapter>.story_world.completed_sequences` / object of true values | `{}` | Record stable sequence IDs after terminal commits. Suppress the same one-shot on revisit. Repeatable routes do not enter this map. |
| `story_flags` / string array | Existing journal IDs and `visited/ch1_court`, `visited/ch2_tower`, `visited/ch3_kiln` | Use visits to gate first-arrival cards and retain existing narrative flags including `arrival`, the `npc_` prefix and `ending`. Geometry reads chapter state. |
| `triggered_volumes` / object of true values | Existing IDs plus `story/<chapter>/<trigger_id>` | Record narrative sensor acceptance once. Keep `seen_echoes` for echo dedup. Normalize known pre-addition keys when their old gameplay effect already ran. Exits stay reusable and checkpoints retain their own IDs. |

Treat existing puzzle flags as authoritative, including `gatehouse_open`, `cistern_raised`, `ambush_done`, `gate_open`, `shortcut_open`, `wards`, `lift_*`, `aqueduct_powered`, `trough_flooded`, `dam_broken`, `key_forged`, `gauntlet_triggered`, `dropped_cauldrons` and `great_gate_open`. Keep `dead`, `taken` and `broken` as existing collections. Recompute Warden phase from `boss_hp` and Colossus phase from `colossus_hp` on rebuild, including phase-specific starting Aegis and the right combat behavior. Transient attacks, exposure timers, blackouts, subtitle cursors, random debris transforms and smoke clear on load. Restore water, slag and committed gate states at their safe terminal poses and retain existing defaults for unsolved physics puzzles.

Use a consistent persistence boundary for delayed beats. Register a named reconciliation function alongside every durable sequence. It writes terminal state and its completed marker into a save snapshot if the running sequence has already been accepted and owns an owed state change. The running world continues its live performance. Apply the same reconciliation to the source chapter's in-memory state when leaving, before cancelling its jobs. On restore, a completed marker reconstructs final geometry and spawn state without launching the timeline, audio or journal popups. A save with a closed bar, intact arch or hanging prop can still trigger its future sequence if it was never accepted. Generate the trigger key and normalized world effects in the same snapshot. Reconcile accepted-but-pending Ossuary and Kiln reinforcements by rebuilding surviving enemies with stable IDs when `ambush_done` or `gauntlet_triggered` is true. This fixes the current possible save between lever pickup and actual ambush spawn. A stateful terminal journal entry uses the normal stable story ID and is present on restore. Restore the completed Act I objective and replay action from `ending` without replaying the gate sequence. Separate completion from the current `won` early return so the opened threshold remains walkable.

Handle gameplay impact as a live transaction when the result depends on world state. A quicksave or checkpoint request after cauldron release waits until the bounded impact transaction has applied damage, deaths, and the dropped ID together. Capture neither an uncredited collapse nor damage twice. Apply the same rule to a checkpoint taken during final gate unsealing before the Act I commit. On chapter travel during an outstanding stateful impact, wait at the source for its bounded resolution before accepting the crossing, or allow leaving and keep the initial state if the impact never started. Coalesce repeated pending writes by save slot. Consume pending writes only after resolving generation ownership and liveness. Save/quicksave disk IO stays with SaveSystem and its atomic rename; show a success toast after a successful write.

After normalization and hydration, validate the saved pose before unmasking gameplay. A load inside rubble, in a closing aperture, on the removed shaft floor or inside a new hazard uses the nearest authored safe ledge/pad for that changed room, then the chapter fallback if needed. Preserve saved yaw/pitch for a valid saved pose. Level mount runs the same reconciliation for direct restores, travel and checkpoints. Reset chapter-local saved keys and visits only according to the corresponding restart action's scope; a whole-Act replay starts fresh.

### Dynamic automap and compass

Expose route descriptors as `{id, label, kind, destination, position, active}` via `get_exits()`. The registry stores chapter metadata and the director resolves live alignment and access. Map icons use an arch or downward stair/shaft, with an open/locked state from the same readiness predicate the Area3D uses. Keep hints for discovered or visible locked exits and only route the compass to the shaft after the opening commit. Update `get_objective_target()` for the actual exit position once open, and preserve the existing ward, NPC, boss, secrets and player heading markers. A departed NPC disappears from the map immediately. Expanding corridors or return terraces requires updating `map_bounds` so their markers project inside the rectangle. Preserve the legacy stage/state fallback for existing callers and fixtures, while the live project queries the route API.

### Preload and dependency rules

Use `const … = preload("res://…")` for every shipped dependency touched by this work, including the test `main.tscn`, script references, imported soundtrack/foley assets, murals, shaders, fonts and textures. Use keyed preload tables for variable selections. Move or remove the unused backward-facing `LevelBuilder.build_*()` wrappers before making all references static. `ChapterRegistry → chapter builders → LevelBuilder` already exists; changing the current dynamic wrappers into preloads would create a cycle. Check callers before removal, and put still-needed adapters at the composition layer. `main.gd` owns the composition root, chapter builders depend on leaf helpers and StoryDirector avoids preloading Main or Registry. Pass registry data and game callbacks into it. Map can preload Registry as long as chapter builders and their dependencies never reference Map. New saves and generated resources use their existing runtime APIs. On a fresh checkout run Godot import before launching scripts, so `preload()` can resolve imported binaries with no reliance on editor class caches.

### Headless integration and acceptance tests

The current working tree passed both `tests/smoke.gd` and `tests/physics_magic.gd` on the pinned Godot binary, with isolated `XDG_DATA_HOME`. The physics run then reported 19 leaked ObjectDB instances and five resources still in use at shutdown. Record this baseline and investigate teardown while wiring the new lifecycle. New suites must free level/game nodes, drain pending frames and leave no new leaks.

Future CI runs each suite with independent disposable user data and a process timeout. The first command imports assets on a clean checkout.

```sh
./run.sh --headless --editor --import --quit
./run.sh --headless --script res://tests/smoke.gd
./run.sh --headless --script res://tests/physics_magic.gd
./run.sh --headless --script res://tests/story_beats.gd
```

- **Smoke.** Traverse the redesigned story through its normal entry points and cross all four routes by moving/dropping the real CharacterBody3D across its volume over physics frames. Remove the two E-to-portal assertions. Assert closed exits reject crossing before their conditions, arrivals are clear and face the authored direction, return travel never respawns consumed items or dead bosses, and both quicksaves and automatic checkpoints preserve state across restart. Keep the current item, weapon loadout, hidden relic and campaign sequence checks. Validate the final Gate opens physically, then Act I completes.
- **Physics and magic.** Retain raft buoyancy, plate centering, grapple/hurl, dash, spread/knockback, axe/parry, fire patch, Voltaic target and Aegis checks. Add collision/clearance for gatehouse bar, portcullis partial and open states and shortcut, collision-to-mesh agreement for falling assemblies, disabled shaft collision after the opening commit, and debris/cauldron contact and cleanup. Exercise Cistern freeze/thaw and raft boarding, cage drop/two plates, Tower gear/steam, pendulum hits and wall break, lift power/jam/latch/arrive, ward seal and correct/incorrect Crescent→Crown→Skull, aqueduct power and spout thaw, trough cooling, ore-cart dam and precondition failures at the hoist and Great Gate. Warden tests cover ward lock, Phase I Aegis break/recovery and Phase II threshold, flight and reflected sonic orb. Colossus tests cover Phase I, overdrive threshold, wet/frost-fire and Voltaic responses as appropriate, cauldron damage applied once and death. Save and restore one fixture in each live phase.
- **Story beats.** Add a `SceneTree` harness that preloads `main.tscn`, uses deterministic synthetic input or physics movement, and subscribes to director and narrative signals. Give every beat in section 1 an explicit test contract with expected order, timing tolerance ±1 fixed tick for timer beats, contact/motion deadlines, target outcome and audio/FX dispatch. Fail coverage if a registered beat has no contract or its fixture never reaches it. Compare just before, at and after each irreversible commit. Exercise repeated entry, throwing a non-player through the area, simultaneous exits, high-speed crossing, spawn inside volume, wrong direction, blockers and both fallback/rollback paths, checkpoint storage failure, pause/resume, death/reload during a sequence and generation cleanup. Verify mid-ambush/mid-collapse/mid-fall and repeated round trips restore the state described above, and check a legacy integer-stage save and a v2 save missing nested fields. Test priority, resume/drop, group completion, same-speaker cue count, style and title visibility arbitration, and real camera identity/player look input while beats fire. Test generated audio PCM lengths, loop endpoints, headroom, stream routing and logical mix ramps under Dummy audio. Use a watchdog and explicit nonzero exit on a failed check, since a script assertion can otherwise leave the SceneTree running.

### Forward+ Vulkan visual verification

Create `tests/visual_story.gd` and a versioned capture manifest during implementation. Use the real runtime scene and director events. Run in a windowed Vulkan session on a pinned device and driver, with an isolated user data directory. X11 under Xvfb is acceptable if the configured Vulkan device supports the window surface. Check `RenderingServer.get_current_rendering_method() == "forward_plus"` and `get_current_rendering_driver_name() == "vulkan"` before running, and record device, driver, engine version, settings and viewport in the capture manifest. A renderer fallback fails the Vulkan job as an infrastructure issue. [Godot 4.7 RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html)

```sh
./run.sh --display-driver x11 --rendering-method forward_plus --rendering-driver vulkan \
  --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 \
  --script res://tests/visual_story.gd
```

Use a fixed step, seeded scenario, explicit player pose/look input, graphics settings and stable light/FX parameters. For scripted fixtures, place the existing player/camera through normal setup, then trigger the public beat and observe play. Capture after `await RenderingServer.frame_post_draw` using the root viewport's `get_texture().get_image()` and `Image.save_png()`. Wait for viewport initialization, process shader/pipeline warm-up before timing the fade and give static baselines a fixed temporal settling window. Check rendered frame deltas during fast events before any settling delay. Use an external process watchdog and CI artifact directory for captures and diffs. [Godot viewport capture](https://docs.godotengine.org/en/latest/tutorials/rendering/viewports.html)

| Capture matrix | Assertions |
| --- | --- |
| Every visual beat in the authored timeline, plus puzzle and boss state boundaries exercised by the headless matrix | Capture one frame before onset, onset, peak or impact and settled state as applicable. Store the scene/beat ID and frame number. Include representative wall art with and without inspection, broken lantern/echo, blood/scorch/frost on floors and walls, peak bell dust, intact/falling/wreck chandelier, both boss phases, ward removal, water and slag progression, Great Gate seam and ending signal. For beats with no visual change, assert their signal and associated audio/queue event and compare surrounding frame invariants. |
| Continuous frame checks during transitions, resonance, blackout and simultaneous HUD states | Check every rendered frame in the fixture window for fade alpha, camera identity, valid image, subtitle/control bounds, and region luminance envelopes. Assert no fully black frames outside the permitted black interval/intentional local blackout, no world swap exposed under partial opacity, and the nominal 0.45 s fade within one render-frame tolerance on the reference device. Capture old scene, fade midpoint, black swap, destination reveal, checkpoint and first player step for all four routes. |
| HUD layout and settings | Test 1280×720, a narrower/taller effective gameplay area and an ultrawide mode, using the actual visible viewport rect for safe bounds. Assert pairwise non-overlap of visible content rects after container layout, including simultaneous title, three-line subtitle, checkpoint, boss/Aegis, prompt and combat style cases. Capture both standard and reduced fog/SSR/SSAO/MSAA presets with state assertions. |

Use reviewed reference PNGs on the pinned runner. Compare stable regions using perceptual differences and small pixel tolerances measured from repeated reference runs. Dynamic particles and fog use region masks, occupancy/luminance limits and onset/settled differences instead of exact full-frame hashes. Fail on an unreviewed regression, missing capture, shader compilation/validation error, or a required frame that never arrives. Attach the expected, actual and diff crops and the beat trace for diagnosis. Use captures and selected frame timing from a warmed representative run to check the transition black dwell, FX budgets and frame pacing. Headless remains the fast behavior gate, and the Vulkan job verifies the rendered result.

### Implementation order

1. Establish director lifecycle, registration validation, test traces and preload dependency cleanup. Adapt the existing load/reset entry points and ship the four physical routes together with save and map plumbing.
2. Add narrative/event contracts and audio mixing/cue banks. Route current interactions through those contracts before introducing new authored performances.
3. Migrate Court, Tower and Kiln in order. Wire each structural and gameplay commit with its restore function and beat fixtures when introducing it. Remove the old story-only fields and paths from `main.gd` after their replacements pass smoke.
4. Complete authored tableaux, environmental/audio tuning and Vulkan reference captures. Sign off on the campaign smoke, physics regressions, beat and restore coverage, and pinned-GPU visual gate.
