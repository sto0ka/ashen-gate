# ASHEN GATE — ACT I: Master Story Script & Level Redesign Blueprint

> **Scope.** Chapters I–III of Act I: *The Sunken Court*, *The Bell Tower*, *The Kiln of Ash*. The act ends on the cliffhanger into Chapter IV, *The Hollow Beyond*.
> **Audience.** Level, gameplay, audio, VFX and UI engineers, plus anyone writing story content.
> **Companion doc.** [`ENGINE_STORY_SYSTEMS_PLAN.md`](ENGINE_STORY_SYSTEMS_PLAN.md) defines the `StoryDirector` and its opcodes, transition zones, fades and tableau helpers. This script uses that vocabulary. Where this script needs something new, it is marked **[NEW]**. Where it changes a decision in the plan, it is marked **[AMENDS PLAN]**. Section 6 lists both kinds.
> **Engine facts this script relies on** (all verified in code): `NarrativeSystem.say(speaker, line, duration, color)` and `play_sequence()`; `LevelBuilder.add_trigger_volume / add_memory_echo / add_checkpoint_zone / add_rotten_barricade / add_explosive_cask / add_pushable_block / add_voltaic_conduit / add_floor_conduit / add_steam_jet / add_belfry_ward_seal`; `game._npc / _enemy / _inscription / _pickup / _pot / _story_event`; `PhysicsSandbox.create_buoyant_raft / create_hinged_pendulum / create_moving_lift`; enemy kinds `shrieker` (65 HP), `acolyte` (80), `stalker` (110, always active, hunts by noise), `executioner` (125, shield), `ash_sentinel` (165, frost-immune), `warden` (520, Resonant Aegis, Phase II at HP ≤ 260, airborne at y 11.6), `colossus` (640, frost-immune, Voltaic overload always applies); audio cues `axe hit cast lever pickup ambient frost maul portal bell repulse step jump land` (WAV) and `parry voltaic stalker splash lift alarm combat_pulse` (synth).

---

## 0. The Rules of the Act (read before building anything)

These rules carry the Half-Life feel. A beat that breaks one is a bug.

1. **The camera belongs to the player.** No camera moves, cuts, letterboxing, input locks, forced crouches or slow motion. Story shake is additive and never exceeds the 0.12 m story cap in the plan. Story never takes yaw, pitch or aim.
2. **The world waits for the player's eyes.** A key visual beat (the bell cracking, the chandelier falling, Malcor on the balcony, the Gate opening) uses a **look-gate**: the beat holds until the target is inside the player's view cone or a timeout fires. Then it plays anyway, and a sound draws the eye. **[NEW] opcode `await_look`**, args `target`, `cone_deg` (default 38), `timeout` (default 3.5 s).
3. **Story never traps or kills.** Collapses seal only routes the player has already left, and they check that the volume is clear before committing. A falling prop that lands on the player pushes them aside and deals no damage. Every scripted fight has a checkpoint before it.
4. **People move through space.** Each NPC has authored marks, and they walk between vantage points while the player watches. They never teleport while on screen. When they leave, the player sees a door or stair take them.
5. **Lines are short.** A subtitle is at most about 90 characters, one breath. Characters interrupt each other, and they leave silences for Caelen that he never fills.
6. **Puzzles carry meaning.** Every lock the player opens was built by Caelen or built against the people of Vaelor. Every puzzle in the act repeats one of three verbs: *float what was promised*, *open what was shut on them*, *pour what was refused*.
7. **Exposition is optional and gameplay is not.** Plaques, journals and Memory Echoes deepen the story, but a player who skips all of them still learns the three core truths from live events and from their own hands.
8. **The motif.** One counting rhyme threads the act. It is the liturgy of the Tithe:
   > *One for the moon that saw it. One for the crown that willed it. One for the skull that paid it.*
   It sets the order of the chimes, the three wards, the three portcullis tolls, the three notches of the Ashen Key, and the shape of the act: Chapter I **witnesses** (moon), Chapter II **confronts authority** (crown), Chapter III **pays** (skull).

### Notation

- Coordinates are `(x, y, z)` in chapter-local metres. **−Z is north**, and Y is up. `Rect2(x, z, w, d)` gives XZ bounds the way `LevelBuilder.slab()` takes them.
- `t` is seconds from the start of the sequence. `@line_end` means the moment the previous line leaves the subtitle bar.
- Sequence IDs follow the plan's `chapter/sequence` form, for example `ch1_court/gatehouse_fracture`.
- Dialogue rows read `ID · SPEAKER · "line" · duration`. Unless a duration is given, use `clamp(1.2 + 0.055 × characters, 2.0, 7.0)` seconds.

---

## 1. The Core Mystery & the Three-Chapter Dramatic Arc

### 1.1 The world

Vaelor is a cathedral-city built in tiers down a black sea-cliff:

| Tier | Place | Act I location |
| --- | --- | --- |
| Upper City | The living city: palaces, the Register, the Guild of Wards | Seen only as distant lights (Chapters I & II far-landmarks) |
| Lower Ward | The fishers' and cistern-folk's quarter at the waterline. Officially *"drowned by the Grey Tide."* | **Chapter I — The Sunken Court** |
| The Bell Keep | A cathedral-tower on a rock spur. The **Great Bell** hangs in its open-sky belfry from an iron *Crown Yoke*. | **Chapter II — The Bell Tower** |
| The Kiln | A volcanic foundry carved into the cliff root beneath the Keep | **Chapter III — The Kiln of Ash** |
| The Hollow | Under everything lies the sea of the unremembered dead, where forgotten names pool. It hungers for names. | Behind the Great Ashen Gate (**Chapter IV**) |

For seven hundred years the old bone-iron Gate held the Hollow back. In the last decade it rusted, the Hollow seeped upward as the **Grey Tide**, and people began forgetting their own children's names in their sleep.

### 1.2 The true history (designer bible: never stated whole in-game)

1. **Named iron.** Kiln-Master **Orrun** discovered that iron quenched while a living person's *name* (their remembered self) is drawn into it can hold the Hollow back. A person whose name is taken does not die. They become **Hollowed**: a body that keeps shrieking the last words it knew. These are our `shrieker` enemies.
2. **The commission.** **King Vaelor** ordered a new Gate of named iron needing **3,011 names**, and he chose the Lower Ward to pay them. The commission used three instruments, each given to someone who could be told a comfortable half-truth:
   - **The Register.** **Archivist Seraphina Vant** compiled the *Tithe Roll*, a "census for evacuation."
   - **The Lock.** **Master Caelen** of the Guild of Wards built the **Resonance Lock** into the Great Bell. It is a pinned *ward-drum*, like a music box. He was told the 3,011 pins were "harmonic keys of the Gate's seal." In fact each pin was a name from the Roll. Once taught, the bell calls exactly those names.
   - **The Bell.** **Lord Malcor**, Bell Warden and Captain of the Bell-Watch, would ring it.
3. **The Mercy Notch.** At the final fitting, Caelen recognised names in the pin sequence. He secretly filed a hairline notch into the lock's governor tooth so it would slip and fail after a few tolls. Then he quarrelled openly with the Crown and was exiled east the night before the Tithe, his master's mark struck from the Guild rolls.
4. **Malcor's mercy.** That same night, Malcor found the notch. He could have filed it true. He left it, hoping the lock would fail on the first toll and he would be "the man who rang, and nothing came."
5. **Tithe Night (forty nights ago).** The Lower Ward was told to gather on the Cistern Quay at the Third Bell for "evacuation by raft." The rafts were never floated, and the North Portcullis was lowered to keep the people in. Malcor rang. **The notch held.** All 3,011 went hollow where they stood. Their names fell down the bell-shaft into the Kiln as glowing *name-ash*, were quenched into iron *name-vessels*, and were poured into the new **Great Ashen Gate**. A few people the Roll did not name survived as **witnesses**. The King's Edict: *"The bell was ordered to silence the witnesses."* They were carried to the Kiln and hand-poured.
6. **The King's keystone.** To bind the Gate, Vaelor poured *his own name* into its keystone, the **Crown Vessel**. He is now the Gate's **Precentor**, the conductor of the names inside it.
7. **The Hollow Choir** is those 3,011 names singing inside the iron, conducted by their King. They are not demons. They are the victims, and they want their names back. When they sing loudly, the iron *pulls*: the city dreams of drowning and the Hollow presses on the Gate.
8. **Malcor's vigil.** Every night for forty nights Malcor has rung the **Lull**, a soft counter-toll that hushes the Choir. Between tolls he kneels and recites all 3,011 names from memory as penance. He has begun to lose them, and himself.
9. **Seraphina's secret.** Her sister **Ilse Vant** was the first entry on the Roll. Seraphina struck her. Because the count had to hold, she wrote in a family of four from the cistern quay: **the Hesks**. Ilse, unaware, went down on Tithe Night to warn her friends the Hesks. The bell did not call her, so she was taken as a *witness* and hand-poured. The Quench-Masters rebelled and froze the aqueduct mid-pour, so Ilse's vessel lies **half-quenched**: half in the iron, half still herself. Seraphina's emergency writ to Caelen is half true. She needs a lock-smith to fix the bell, but she needs *this* lock-smith because only he can cut the never-poured **Ashen Key** and open the Gate. She wants Ilse back.
10. **Tonight: the Fracture.** Forty nights after the Tithe, the Mercy Notch gives way. The governor slips, the ward-drum spins free, and the Great Bell **cracks**. Its resonance **inverts**: it no longer calls the 3,011 pinned names. It calls **any name in earshot**, which now means the living upper city. Each inverted toll hollows the living, and the Kiln, still hot, begins pouring them automatically.

**Each faction is right about something:**
- **Malcor**: "Keep the Gate shut forever, even if the city goes with it. Open it and the Hollow walks up the cliff."
- **Seraphina**: "Open it. The bell calls names because the Gate is hungry. Let them go and the bell has nothing left to call for."
- **The King** wants his **Key-maker** to come home.

The player opens the Gate. Both of them were right.

### 1.3 Caelen's guilt (the player's guilt)

Caelen built the lock that taught the bell whose names to take. His act of conscience, the Notch, failed on Tithe Night, and forty nights later it is what *caused* tonight's catastrophe. Every puzzle in Act I has the player unlock, re-power and finally **pour** pieces of his own commission. His **master's mark**, a key crossed with a tuning fork inside a ring (the *Key-and-Fork*), is stamped on each of these locks. The player meets it again and again until they understand that the machinery of the atrocity is theirs.

### 1.4 How each chapter reveals one layer *through the world and the mechanics*

| Chapter | Motif | The devastating layer | Delivered by the environment | Delivered by the mechanics |
| --- | --- | --- | --- | --- |
| **I — The Sunken Court** | *Moon that saw it* (witness) | **The Lower Ward did not drown.** Its people were gathered, shut in and emptied. The bell does it *live*: you watch it take Brother Torin. | The Quay of Bundles with no rafts; the Tithe Notice Wall ("THERE ARE NO RAFTS"); fingernail gouges on the *inside* of the portcullis; the Watchmen's Rest; the Hollowed shrieking "—third bell—" | **Float the evacuation rafts** they were promised (sluice); **raise the portcullis** that was lowered on them; your master's mark on the sluice padlock and the gearbox |
| **II — The Bell Tower** | *Crown that willed it* (authority) | **The bell takes names, and your lock taught it whose.** Your mercy caused tonight. And someone else wrote the list. | Pell's workbench slate ("3,011 PINS = NAMES?"); the Founders' Offering bowls; Malcor's vigil altar with his own name rewritten until it falls apart; the bronze plaque | **Break the three wards** and hear Malcor lose a memory with each; **ring the Tithe liturgy** on the chimes; unjam *your* escapement on the lift; the dying confession ("I found your notch. I left it.") |
| **III — The Kiln of Ash** | *Skull that paid it* (payment) | **The Gate is made of the 3,011. Seraphina chose them. The King is inside.** | Name-vessels incl. the still-warm **TORIN, BELL-WATCH**; the Tithe Roll in Seraphina's hand (Ilse struck, the Hesks added); the frozen Quench-Masters; the Key mold tagged *"DO NOT POUR — C."*; the Crown Vessel stamped VAELOR | **Pour the Key** you refused to pour; send a cart of name-ash through the dam; **turn the Key three notches** (moon, crown, skull) and open the Gate yourself |

### 1.5 Dramatic escalation curve

```
Intensity
  ▲                                                                               ┌ GATE OPENS
  │                                                    Belfry Boss ┐             ╱ (cliffhanger)
  │        Portcullis Siege ┐                        ╱‾‾╲          │   Colossus ╱
  │  Cold-Open             ╱╲               Lift    ╱    ╲Collapse │  ╱‾‾‾‾‾‾‾╲╱
  │  Breach ╲      Ossuary╱  ╲             Ambush  ╱      ╲  drop  │ ╱  Meltdown
  │   ╱╲     ╲  ╱╲blackout    ╲Causeway   ╱╲      ╱        ╲       │╱
  │  ╱  ╲     ╲╱  ╲            ╲ (calm)  ╱  ╲ ╱╲ ╱ Choir    ╲ Rim  ╱ Confession
  │ ╱    ╲Cloister Cistern      ╲______ ╱    ╲   face-to-face ╲___╱ (quiet)
  └──────────────────────────────────────────────────────────────────────────────▶ time
     CH I (≈25 min)                     CH II (≈22 min)            CH III (≈25 min)
```

Every peak is followed by a **quiet human beat**: Torin at camp, the causeway walk, Malcor's face-to-face, the rim meeting, Seraphina's confession. Half-Life pacing alternates panic with listening.

---

## 2. Cast Voice & Characterization Guide

The game has no recorded VO. Each voice is built from three things: **(a)** the subtitle accent colour, set on `sub_accent` and the speaker label through `say(..., color)`; **(b)** a short **speaker chime** played when the speaker *changes*; **(c)** a **voice-grain** bed, a synthesized, formant-filtered murmur shaped to the line's syllable count and played *positionally* from the speaker's head so the voice comes from a place. All three are **[NEW]** audio cues (Section 6.6).

### 2.0 Subtitle rules

- **Speaker label** in caps: `ARCHIVIST SERAPHINA`, `BROTHER TORIN`, `LORD MALCOR`, `THE HOLLOW CHOIR`.
  - A remote voice gets a suffix: `SERAPHINA — SPEAKING-TUBE`.
  - A memory echo gets a suffix: `JOURNEYMAN PELL — ECHO`.
  - A hollowed fragment uses the label `— WHISPER —`.
- **Barks** (combat fragments and whispers) go through the **[NEW]** `bark` opcode. A bark is short, plays positionally and **never queues**: if the bar is busy, it is dropped after 1.5 s. Barks can never delay story lines.
- **Priority.** A story line can pre-empt a bark, and a bark never pre-empts a story line. **[NEW]** `priority` field on `say()` entries.
- **Look-away rule.** A conversation started by proximity keeps playing if the player walks away; Half-Life NPCs talk at your back. Subtitles keep running but voice-grain attenuates with distance.

### 2.1 Caelen: the silent protagonist

| Aspect | Direction |
| --- | --- |
| Who | Master of the Guild of Wards, late forties, exiled forty-one nights ago. Builder of the Resonance Lock. |
| Voice | **None, ever.** No grunts on story beats; combat exertion sounds only. |
| How identity is reflected | **1. By how others address him.** Torin: *"the lock-smith," "Master"* → hollowed: *"Who did you say you were?"* Seraphina: *"Caelen"* (intimate, old colleague, and later accusing). Malcor: *"Lock-smith," "Notch-maker"* → only once, dying: *"Caelen."* The Choir: *"Key-maker."* The King: *"Lock-smith"* → *"Caelen."* **2. By what his tools touch.** Every Act I lock carries the Key-and-Fork mark, and its interact hint names it: `SLUICE PADLOCK — YOUR MASTER'S MARK — UNPICK [E]`. **3. By who answers for him.** Characters pause where he would answer, then answer themselves: *"Don't. I know what you'd say."* |
| Signature verb | **[NEW] Unpick**: hold `[E]` for 1.0 s on a Key-and-Fork lock. Three tumbler clicks rise in pitch, then a `lever` thunk. It is used only on his own locks: the sluice padlock, the gearbox crank seat, the lift pawl housing, the Ward III chime-frame and the Gate lock-plate. |

### 2.2 Archivist Seraphina Vant (she/her)

| Aspect | Direction |
| --- | --- |
| Who | Keeper of the Register, late thirties, ink-stained, precise. Compiled the Tithe Roll. Sister of Ilse. |
| Wants / hides | Wants the Gate opened to recover Ilse. Hides that she wrote the names and traded the Hesks for her sister. |
| Cadence | **Clipped and cataloguing.** She narrates disaster as if writing a ledger entry ("Entry: the exile returns, three days late."). Short declaratives. Under stress, sentences break into fragments and then reassemble *colder*. She never swears except once ("Damn the record."). |
| Vocabulary | *entry, record, struck, written, count, receipt, register, fair hand, margin.* She never says "souls" or "dead." She says **"names."** |
| Tells | Changes the subject when the quay, the Hesks or Ilse come up. Says "I'll write him down" about Torin and does not realise what she has said until Chapter III. |
| Address | "Caelen." Never "Master." |
| Subtitle colour | **`#70D7DF`** (cyan, already the `say()` default) |
| Chime cue | `vo_chime_seraphina`: glass bell A5 plus a 0.12 s quill scratch, 0.35 s |
| Voice-grain | `vo_grain_seraphina`: band-passed noise with formants around 820 / 1650 Hz, quick syllable rate (6.5/s), dry |
| Signature lines | *"Don't read the planks."* · *"I'll write him down."* · *"I wrote them."* |

### 2.3 Brother Torin of the Bell-Watch (he/him)

| Aspect | Direction |
| --- | --- |
| Who | A lay-brother guard, about twenty-two, from the upper city's Steps district. Wounded in the side. Being hollowed *live* through Chapter I. |
| Wants | To be useful one more time. To remember his sister's skipping rhyme. |
| Cadence | **Plain, warm, rural.** Uses "quick-like," "lad," "Master." Gallows humour. As the chapter goes on his sentences lose their nouns: *"Gearbox wants its— the thing. The crank."* By the end he is polite to a stranger. |
| Vocabulary | Concrete, small words: *lantern, crank, bread, sister, step.* He calls the bell **"her"** ("She's ringing flat."). |
| Hollowing progression | **Stage 0** (cold-open): fluent. **Stage 1** (after fracture): forgets his mother's name. **Stage 2** (camp): drops nouns, half-sings the Tithe rhyme as a nursery rhyme. **Stage 3** (siege): can finish only "moon" and "crown." **Stage 4** (portcullis open): *"Who did you say you were?"* Silent and seated forever after. |
| Subtitle colour | **`#E8B25C`** (lantern amber) |
| Chime cue | `vo_chime_torin`: chain-mail rattle plus a soft lantern-handle creak, 0.3 s |
| Voice-grain | `vo_grain_torin`: formants around 600 / 1150 Hz, medium rate, a wet cough tail on 1 line in 4. From Stage 2 on, grain amplitude drops 2 dB per stage: he is literally fading. |
| Visual tell | **Name-ash motes**: faint violet glyph particles lift from his head toward the Keep on every inverted toll. **[NEW]** VFX `hollowing_motes`. |

### 2.4 Lord Malcor, Bell Warden (he/him)

| Aspect | Direction |
| --- | --- |
| Who | Captain of the Bell-Watch, sixties, huge, armoured, with a bell rack strapped to his back (existing `warden` rig). Rang the Tithe. Has kept the forty-night vigil. |
| Wants | To keep the Gate shut forever and to die having said every name. |
| Cadence | **Liturgical and heavy.** Long, measured sentences that land on stressed monosyllables, as if each were struck. He *counts*, and he uses triplets. In combat he shouts the rhyme's nouns as telegraphs. As wards break, his lines lose a memory each time, audibly. |
| Vocabulary | *toll, count, kneel, bronze, vigil, Lull, tithe, the third bell, the quay.* He calls the Choir **"them"** and the bell **"my bell."** |
| Address | "Lock-smith." "Notch-maker" when contemptuous. "Caelen" exactly once, dying. |
| Subtitle colour | **`#D99CBD`** (bruised mauve, the existing NPC accent) |
| Chime cue | `vo_chime_malcor`: low bronze hum on F2 with a long 1.4 s tail, plus a breath |
| Voice-grain | `vo_grain_malcor`: formants around 420 / 900 Hz, slow rate (3.5/s), Cathedral reverb bus forced on |
| Signature lines | *"One for the moon that saw it."* · *"Forty nights I have rung the Lull."* · *"I found your notch. I left it."* |

### 2.5 The Hollow Choir (the 3,011, conducted by the King)

| Aspect | Direction |
| --- | --- |
| What | The names inside the Gate's iron, singing as one, with individual names surfacing as whispers. |
| Cadence | **Unison plural, "we."** Present tense. Short phrases, often a fragment of the Tithe rhyme or the Tithe notice. Lines are subtitled in *lower case* with ellipses to mark the alien register: `…we were waiting on the quay…` Individual whispers are single names or last words. |
| Vocabulary | *quay, raft, third bell, written, names, give back, key-maker, home.* |
| Address | "Key-maker." Once, through Ilse: "Sera." |
| Subtitle colour | **`#B9A8FF`** (pale violet). Single whispers use `#8E84B8` with the label `— WHISPER —`. |
| Chime cue | `vo_choir_breath`: a reversed choral swell, 0.9 s, three detuned voices on a minor-second cluster |
| Voice-grain | `vo_grain_choir`: 6 formant voices detuned ±18 cents, slow attack. Spatialised from the nearest **choir emitter** (walls, chasms, vessel racks, the Gate). Never from the screen centre. |
| Escalation | **Ch I**: whispers only; one unison line on the causeway. **Ch II**: whispers answer the chimes. **Ch III**: full unison lines, louder with every toll. Gate: they speak with one voice (the King's). |

### 2.6 Supporting voices (echoes and one-offs)

| Speaker label | Who | Colour | Chime | Notes |
| --- | --- | --- | --- | --- |
| `BELL-WATCH GUARD` | The fleeing guard, cold-open | `#C9B8A0` | `vo_chime_torin` at +3 semitones | Panic, half-screamed |
| `JOURNEYMAN PELL — ECHO` | Caelen's former apprentice, Bell Keep artificer | `#9EE9F5` | `vo_chime_echo` | Fast, earnest, technical |
| `KILN-MASTER ORRUN — ECHO` | Discoverer of named iron | `#FF9A5A` | `vo_chime_echo` at −5 semitones | Craftsman's calm; it chills because he is not cruel |
| `QUENCH-MASTER — ECHO` | Aqueduct rebel | `#9FD8FF` | `vo_chime_echo` | Defiant, frozen breath |
| `A MOTHER ON THE QUAY — ECHO` | Mara Hesk | `#D8C7B0` | `vo_chime_echo` | Hopeful; this is what makes it unbearable |
| `A CHILD — ECHO` | At the portcullis | `#D8C7B0` | `vo_chime_echo` at +7 semitones | One line |
| `ILSE` | Seraphina's sister, half-poured | `#E6D5FF` | `vo_choir_breath`, solo voice | Warm, slightly too slow, like a voice under ice |
| `A VOICE BEYOND THE GATE` | King Vaelor (never named on screen) | `#F2DFA6` | `vo_chime_king`: every bell cue at once, pitched down an octave, then sudden silence | Three lines, the last lines of Act I |

---

## 3. Chapter I — *THE SUNKEN COURT* ("The Night the Bell Cracked")

**Registry metadata [AMENDS registry]:** `subtitle: "The Night the Bell Cracked"`, `default_spawn: Vector3(0, 6.1, 61.0)`, `map_bounds: Rect2(-32, -50, 64, 113)`, `map_caption: "Gatehouse • Cloister • Cistern • Ossuary • Court of Seals • Bell Causeway"`.
**Target length:** 22–28 min. **Dramatic job:** *witness.* The player arrives as a stranger. They watch the bell take a man, float the rafts that never came, and lift the gate that was shut on three thousand people.

### 3.1 Layout topology: a Hexen mini-hub

```
                         N  (−Z)
                         ▲
              ┌──────────────────────┐   far: BELL KEEP crown + Great Bell (0,22,−120)
              │ VESTIBULE  z −42…−50 │◀── transition plane z −44  → ch2 "tower_from_court"
              ├──────────┬───────────┤   Keep South Doors z −42
              │  Z6  BELL CAUSEWAY   │   y 0, open sky, chasm both sides
              │  x ±5.6  z −18.6…−42 │
  ┌───────────┴══════════╪═══════════┴──────────┐  ═ North Portcullis z −19 (gouged bars)
  │ WATCH WALK y2.42 ────┘gearbox  North Gallery │
  │ (one-way drop ▼)     (−5.8,−16.9)  y5 (NPC)  │
┌─┴──────────┐  ┌────────────────────────────┐  ┌┴─────────────┐
│ Z4 WEST    │  │ Z3 COURT OF SEALS (HUB)    │  │ Z5 EAST      │
│ CISTERN    ├──┤ x −10…10  z −19.2…16.2     ├──┤ OSSUARY      │
│ bed y −0.8 │quay plates (±3.8,−5) cage rope│door bed y −0.7  │
│ parapet    │  │ Tithe Notice Wall z 15      │  │ Watchmen's   │
│ y 2.42     │  └─────────────┬──────────────┘  │ Rest         │
└──┬─────────┘    south arch  │  z 15.7          │ reliquary    │
   │ Drain Grate  ┌───────────┴──────────────┐   └──┬───────────┘
   └─(one-way)───▶│ Z2 SOUTH CLOISTER & CAMP │◀─────┘ Ossuary Gate (one-way unpick)
                  │ x −12…9  z 16…30          │   shortcut quay z 15.7…19.8
                  ├──────────────────────────┤
                  │ Z1 GATEHOUSE  z 29…37    │  inner arch z 30 (bar) · outer arch z 36 (collapses)
                  │ OUTER VIADUCT z 35…48    │
                  │ APPROACH STAIR y6→0 z 62…48   SPAWN (0, 6.1, 61.0) facing N
                  └──────────────────────────┘
```

**Hub loops (Hexen-style; every loop returns to the Court of Seals):**

| Loop | Route | Opens | Purpose |
| --- | --- | --- | --- |
| **West Loop** | Court → Cistern Quay (x −10, z −8…12) → Cistern → Sluice Causeway → **Drain Grate** (winch on the cistern side) → Cloister → Court | Drain Grate winch at (−12.4, 0, 13.4); the grate at (−11.2, 0, 15.2) is 2.6 m wide and lifts 3 m | Returns the player to the camp and Torin after the flood without retracing |
| **East Loop** | Court → Ossuary upper path (x 9.8, z −6…2) → Crypt → Watchmen's Rest → Reliquary → Shortcut Quay → **Ossuary Gate** (x 9, z 17.85) → Cloister | Unpick the Ossuary Gate from the east (existing `shortcut_door`) | Brings the player back past Torin's empty camp, so they notice he has gone |
| **High Loop** | Cistern West Parapet (y 2.42) → **Watch Walk** (y 2.42, behind the cistern's north wall) → smash `court_watchwalk_bar` → **one-way 2.42 m drop** into the Court's NW corner beside the gearbox | After the rafts float (the parapet is reachable only by raft) | A Hexen "you're back where you started" moment, and the siege's Wave 2/3 spawn ledge |

### 3.2 Zone geometry & sightline sheet

| Zone | Bounds / elevations | New geometry vs. current builder | Key marks (actors / props) |
| --- | --- | --- | --- |
| **Z1 Approach Stair, Viaduct & Gatehouse** | Approach landing `Rect2(-4, 60, 8, 3)` y 6.0; stair from (0, 6, 61.5) down to (0, 0, 48.5), 7 m wide; Outer Viaduct `Rect2(-5.8, 35, 11.6, 13)` y 0 (existing); Gatehouse `Rect2(-8, 29, 16, 8)` y 0, ceiling 8.5; outer arch z 36; inner arch z 30 with the existing `gatehouse_bar` | **Add** the approach stair and landing, with low 1.1 m parapets so the drowned ward reads below. **Add** an exterior drowned-ward plane at y −14 (black water, 40 roof-ridge props poking out, 6 dim window lights). **Add** a `gatehouse_outer_arch` fracture assembly at z 36 (keystone + 8 voussoirs, debris budget 14, settled rubble `Rect2(-5.8, 36.2, 11.6, 2.2)` h 4.2). **Add** a wicket door at (2.6, 0, 37.0). **Add** a cell back door at (−7.55, 0, 32.2) and a hinged grate wicket at (−4.15, 0, 31.0). | `torin_wicket` (2.6, 0, 38.0) · `torin_grate` (−3.4, 0, 33.6) · `torin_bar` (0.8, 0, 30.8) · `seraphina_grate` (−5.0, 0, 32.4) · `seraphina_winch` (−6.4, 0, 30.6) · `seraphina_exit` (−7.55, 0, 32.2) · `guard_start` (2.0, 0, 21.0) · `guard_bar` (0.8, 0, 29.4) · `guard_fall` (1.6, 0, 36.8) · `court_north_wave_origin` (0, 4, −19) |
| **Z2 South Cloister & Fallen Camp** | `Rect2(-12, 16, 21, 14)` y 0, roof 10.25 (existing) | **Breakable stained-glass** at the three west windows (−11.4, 5.4, z ∈ {19, 23, 27.5}) with a 0.6 m exterior sill at y 3.0 for drop-in spawns. **Add** the Drain Grate opening in the SW corner. Camp props: pallet (existing), bedroll, helmet, bowl, whetstone. | `torin_camp` (6.2, 0, 25.6), seated · `cloister_breach_window_19/23/27` |
| **Z3 Court of Seals (hub)** | `Rect2(-10, -19.2, 20, 35.4)` y 0 (existing); **North Gallery** `Rect2(-9, -18.4, 18, 1.4)` y 5.0, NPC-only, against the portcullis wall's inner face, with an archive door at (−9.2, 5.0, −18.0) | **Tithe Notice Wall** on the south-arch piers' inner faces, x ±(7.2…9.4), z 15.0, y 1.4…4.2. **Gouged-bars** decals on the portcullis's south face. Hydraulic ram housing (cosmetic) beside the gearbox. | `torin_gearbox` (−5.0, 0, −15.8) · `seraphina_gallery` (−4.0, 5.0, −18.0) · `seraphina_gallery_door` (−9.2, 5.0, −18.0) · siege spawn marks (§3.6) |
| **Z4 West Cistern** | Bed `Rect2(-30, -14, 20, 32)` y −0.8; Quay `Rect2(-13, -8, 4, 20)` y 0; Sluice Causeway `Rect2(-27, 8, 15, 4)` y 0; Altar island y −0.05; West Parapet `Rect2(-29.5, -13.5, 7.7, 8.8)` y 2.42 (all existing). **Watch Walk** `Rect2(-27, -17.6, 17.2, 2.4)` y 2.42; **Archive window alcove** `Rect2(-22, 18.4, 4, 2)` y 4.0 (NPC-only, behind a grated window in the south end wall at (−20, 5.0, 18.0), 2.2 × 1.6 m) | Cut a 2 m doorway from the parapet north into the Watch Walk through the cistern's north end wall (x −26…−24, z −14). Three north-facing **arrow slits** at z −17.6, x ∈ {−22, −17, −12}, frame the Keep. A broken east end at x −9.8 gives the drop. **Padlock + chain** prop on the sluice lever. **Hesk planks** on the first raft. Quay of Bundles props. | `seraphina_cistern` (−20.0, 4.0, 18.6) · `hesk_raft` = the raft at z 2.0 · `quay_echo` (−11.0, 0, 3.0) |
| **Z5 East Ossuary** | Existing footprint. Crypt bed y −0.7. | **Jagged breach** in `ossuary_end_wall` at z −18, x 21…25, y 0.8…3.2: the Keep's glowing bell is framed through bones. **Watchmen's Rest** ring around the lever altar. | `watchman_seat_1…6` on a ring of radius 2.6 around (22, −0.7, −13.1) at angles 30°, 90°, 150°, 210°, 270°, 330° (seats 2 and 5 rise) · `malcor_echo` (21.0, −0.7, −9.5) |
| **Z6 North Portcullis & Bell Causeway** | Causeway `Rect2(-5.6, -42, 11.2, 23.4)` y 0 [**AMENDS PLAN**: `court_to_tower` moves from z −31.8 to z −44]; **Vestibule** `Rect2(-4, -50, 8, 8)` y 0, ceiling 7; Keep South Doors at z −42 (two 3 × 7 m leaves, starting 20° ajar) | **Remove** the close-up fake tower at z −36.3 (`bell_tower_pier`, `bell_chamber_*`, `silhouette_bell`, `bell_tower_spire`) and the `_portal`. **Add** the Keep's south facade (24 m wide, 22 m tall) at z −42…−46, plus the far Keep mass (§3.2.1). Parapets 1.2 m. Two rubble gaps filled to 1.6 m (no falls). Kill volume at y −12 respawns at `court_causeway`. | `keep_door_l/r` hinges at (±3, 0, −42) · `causeway_plaque` (4.6, 0, −30) · transition marker `court_to_tower` at (0, 0, −44) |

#### 3.2.1 Far landmarks (identical in every chapter; positions in Ch I frame)

The chapters share one world frame. **Ch II local = Ch I + (0, 0, +77)**, so the Ch I causeway's transition plane z −44 equals the Ch II vestibule z 33. **Ch III local = Ch I + (0, +60, +143.6)** (equivalently Ch II + (0, +60, +66.6)). The Kiln lies 60 m under the Keep: the Ch II belfry shaft (0, 9.5, −42) sits directly above the Ch III arrival (0, 6.1, 24.6), the Kiln stacks rise just outside the Ch III side walls at x ±34, and the Great Gate (Ch III z −38) is Ch I z −181.6.

| Landmark | Ch I position | Look |
| --- | --- | --- |
| **The Bell Keep mass** | `x −16…16, z −46…−128`, nave ridge y 16 (gabled), belfry floor y 9.5 at z −120 | Black gothic mass, lit clerestory windows (2 violet, 2 cyan) |
| **Crown Yoke + Great Bell** | Yoke: two iron arcs from the belfry parapet up to apex (0, 32, −120). Bell centre (0, 22, −120), radius 2.8, height 4.4 | The violet hairline crack is an emissive strip. It **pulses on every toll** (pre-fracture Lull: soft cyan; post-fracture: violet flare plus the cracked-toll screech) |
| **Kiln stacks** | Two chimneys at (±34, −30…+18, −150) | Orange glow tops, ember plumes, under-lit smoke. They flank the Keep like candles. |
| **Upper City lights** | Band at (40…90, 6…20, −20…−80), east | Warm windows. **Post-fracture:** violet name-ash ribbons stream from these lights to the bell on scripted tolls |
| **Drowned Lower Ward** | Water plane y −14 around the viaduct and causeway | Roof ridges, a half-sunk bell-cote, a capsized raft |

| Sightline | From → To | Purpose |
| --- | --- | --- |
| **SL-1 "The Bell Over the Gate"** | Approach stair top (eye 7.8 m, z 61) → Crown Yoke & Great Bell above the gatehouse roofline (bell ≈ 5.1° elevation clears the nave ridge at 4.2°) | First image of the game: the bell you came to fix |
| **SL-2 "The Goal Down the Axis"** | Court south arch (0, 1.7, 15) → north through the portcullis bars → causeway → Keep doors with violet light | The hub always shows the exit |
| **SL-3 "Arrow Slits"** | Watch Walk slits → Keep & bell | Rewards the High Loop with the landmark |
| **SL-4 "Bones and Bell"** | Ossuary north breach → Keep's bell, framed by skulls | Ties the dead to the bell visually |
| **SL-5 "The City Being Taken"** | Bell Causeway → east Upper City → name-ash ribbons to the bell | The stakes made visible: the living city is next |
| **SL-6 "Look Back"** | Causeway → south over the Sunken Court roofs to the gatehouse spires | You crossed it. Hexen-style world coherence. |

### 3.3 The playable 60-second Cold-Open Breach

**The beat, in one sentence:** you walk down a rain-dark viaduct toward a lantern; a wounded young guard leads you to a woman behind a grate who asks you to count the bell with her. On "three" the bell screams, a violet wave tears through the court and cracks the arch above you. The guard forgets his mother's name. A man runs toward you screaming that it is taking names, and a second toll brings the outer arch down on him behind you. The dead come through the bar.

**Choreography timeline** (target times assume walking pace; every step is gated by space, with a fallback timer):

| Time | Seq / Beat | Op & target | What the player sees and hears | Line |
| --- | --- | --- | --- | --- |
| 0:00 | `ch1_court/coldopen_arrival` · `spawn` | Mount, first visit only | Spawn on the approach landing (0, 6.1, 61) facing N. Rain on the viaduct, ash drifting. **SL-1**: the Great Bell hangs in its yoke over the gatehouse. Far below, the drowned ward. | — |
| 0:00 | · `lull_loop` | **[NEW]** `bell_toll` op, mode `lull`, period 8.0 s, emitter `bell_far` | Slow, soft tolls (`bell` at pitch 0.62, far mix). Each toll gives a soft cyan pulse on the bell's crack strip. | — |
| 0:02 | · `card` | `show_chapter` | "CHAPTER I — THE SUNKEN COURT — The Night the Bell Cracked" (non-blocking; the player can walk) | — |
| 0:03 | · `lantern` | `gesture` torin `lantern_wave` (loop) at `torin_wicket` | A swinging amber lantern 23 m ahead at the wicket door | — |
| ~0:12 | `ch1_court/torin_hail` · trigger `(0, 1.5, 47.0)` size `(11.6, 4, 2)`; fallback 20 s | `voice` / `look_at` / `walk_to` | Torin raises the lantern at the player, then limps toward the grate, glancing back once | c1.tor.01–05 |
| ~0:25 | `ch1_court/gatehouse_meeting` · trigger `(0, 1.4, 33.6)` size `(7.6, 2.8, 3.6)`; fallback 35 s after the hail [**AMENDS PLAN**: no bar lift here] | `look_at` seraphina → player | Seraphina's face behind the cell grate, lit cyan by her lamp. Torin stands at the barred inner arch, hands on the bars. | c1.ser.01–06 |
| ~0:35 | `ch1_court/gatehouse_fracture` · starts when "Two…" is spoken **plus 3.1 s**: the third toll comes *early* | see table §3.3.2 | **The Fracture.** Sequence below. | c1.ser.07–10, c1.tor.06–08, guard |
| ~0:55 | · `breach` | `commit` `coldopen_combat` | Two Hollowed pour through the raised bar. First fight. | barks |

#### 3.3.1 Cold-open dialogue

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c1.tor.01 | BROTHER TORIN | "Hold there! Lantern up— show your face!" | 2.6 |
| c1.tor.02 | BROTHER TORIN | "...Guild coat. Ward-iron at the belt." | 2.8 |
| c1.tor.03 | BROTHER TORIN | "You're him. The lock-smith. Gods, she said you'd come." | 3.4 |
| c1.tor.04 | BROTHER TORIN | "Brother Torin, Bell-Watch. What's left of it. In, quick-like." | 3.6 |
| c1.tor.05 | BROTHER TORIN | "She barred herself in the cell-house three nights back. Says the bell's ringing flat." | 4.4 |
| c1.ser.01 | ARCHIVIST SERAPHINA | "Caelen." | 1.6 |
| c1.ser.02 | ARCHIVIST SERAPHINA | "Entry: the exile returns. Three days after the writ." | 3.2 |
| c1.ser.03 | ARCHIVIST SERAPHINA | "Don't. I know what you'd say." | 2.4 |
| c1.ser.04 | ARCHIVIST SERAPHINA | "Listen to the Lull. Count it with me." | 2.8 |
| c1.ser.05 | ARCHIVIST SERAPHINA | "One..." *(emitted on the next Lull toll)* | 1.4 |
| c1.ser.06 | ARCHIVIST SERAPHINA | "Two..." *(emitted on the following toll)* | 1.4 |

#### 3.3.2 `ch1_court/gatehouse_fracture`: beat table

Precondition for `outer_arch_collapse`: **player z < 35.6 and the arch volume is empty**. If not met, hold the beat for up to 20 s. If it is still unmet, skip the collapse, keep the guard alive offscreen, and set `outer_arch_collapsed=false`; the chapter still works.

| t | Beat ID | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.00 | `crack_toll` | `foley` `bell_crack` (far, 2D-weighted 60%) | The toll lands early. A screech, then the toll, then a glassy shatter partial. The Lull loop stops for good. | — |
| 0.35 | `wave` | `resonance` origin `court_north_wave_origin`, radius 60, speed 40 m/s, strength 0.10 | A 6 m violet wavefront rolls south down the Court, visible through the inner bars. Ash reverses direction as it passes. | — |
| 1.55 | `gutter` | `torch_group` `gatehouse`, scale 0.15, dur 1.2, flame tint `#9F7BFF` | Torches flatten and turn violet-blue | — |
| 1.55 | `fissure` | **[NEW]** `fissure` target `inner_arch_z30`, 5 branches, grow 0.8 s, colour `#BBA1FF` | Glowing cracks race across the inner arch stones over the player's head. Dust sifts down (6 non-blocking debris). | — |
| 1.60 | `torin_hollow_1` | `gesture` torin `clutch_head` → `kneel`; **[NEW]** `hollowing_motes` torin 1.5 s | Violet glyph motes peel off Torin's head and stream north | — |
| 1.90 | `ser_react` | `voice` | Seraphina steps back from the grate | c1.ser.07 |
| 2.60 | `torin_react` | `voice` | — | c1.tor.06 |
| 5.80 | `ser_explain` | `voice` | — | c1.ser.08 |
| 6.00 | `guard_run` | `walk_to` `bellwatch_guard` `guard_start`→`guard_bar`, speed 5.2 (sprint anim) | A Bell-Watch guard sprints across the cloister toward the bar, lantern swinging, with two Hollowed loping behind him | guard line |
| 6.00 | `chasers` | `commit` spawn `court_coldopen_shr_1` (−3, 0, 19.5), `court_coldopen_shr_2` (3.5, 0, 18.8) | They run at the bar (toward the player) | bark "—third bell—" |
| 9.20 | `dilemma` | `voice` | Seraphina's hand on the winch, frozen | c1.ser.09 |
| 11.0 | `torin_plead` | `voice` | Torin, on one knee, reaches for the bars | c1.tor.07 |
| 12.2 | `decide` | `voice`; `walk_to` seraphina `seraphina_winch`; `gesture` `winch` | — | c1.ser.10 |
| 13.6 | `lift_bar` | `move_body` `gatehouse_bar` → y 6.35, 0.8 s, cue `lift` | The bar grinds up (existing tween, relocated) | — |
| 14.4 | `guard_flee` | `walk_to` guard → (1.6, 0, 33.0) → `guard_fall`, speed 5.2 | He sprints *past the player* toward the viaduct, eyes wide, not stopping | — |
| 15.6 | `second_toll` | `foley` `bell_crack` (pitch 0.9) + `resonance` (strength 0.12) | — | — |
| 15.7 | `outer_arch_collapse` | `rockfall` `gatehouse_outer_arch` (precondition above) | The keystone drops and the arch caves in over the guard. 14 debris pieces scatter and a solid rubble wall settles. **Retreat sealed.** | — |
| 15.8 | `guard_buried` | `vanish` guard (no FX); persistent `blood_trail` decal at `guard_fall`; spawn prop `guard_lantern` RigidBody at (1.2, 0.6, 35.6), impulse (0, 0, −1.5) | His lantern, still lit, rolls back to the player's feet. It is engraved **"W.W."** (pays off in §3.5 and §5.3). | — |
| 16.2 | `torin_grief` | `voice` | — | c1.tor.08 |
| 16.8 | `breach` | `commit` `coldopen_combat` (combat intensity on) | The two Hollowed are through the bar. The player fights with the Cleaver-Axe. | barks |
| end | — | on both cold-open shriekers dead, or 40 s | → `ch1_court/gatehouse_aftermath` | — |

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c1.ser.07 | ARCHIVIST SERAPHINA | "That's not the Lull." | 2.0 |
| c1.tor.06 | BROTHER TORIN | "Oh— what's my mother's... I had it. I had it just now." | 3.6 |
| c1.ser.08 | ARCHIVIST SERAPHINA | "That was the Tithe toll. Inverted. It's calling the upper city." | 3.8 |
| c1.grd.01 | BELL-WATCH GUARD | "Open the bar! It's taking names— it's TAKING—" | 2.8 |
| c1.ser.09 | ARCHIVIST SERAPHINA | "If I lift it, they follow him in." | 2.6 |
| c1.tor.07 | BROTHER TORIN | "Archivist—!" | 1.2 |
| c1.ser.10 | ARCHIVIST SERAPHINA | "...Damn the record." | 1.8 |
| c1.tor.08 | BROTHER TORIN | "No— no, lad, no..." | 2.2 |

#### 3.3.3 `ch1_court/gatehouse_aftermath`

| t | Op | Choreography | Line |
| --- | --- | --- | --- |
| 0.8 | `voice` | Seraphina at the grate wicket, unlocking it (`gesture unlock`) | c1.ser.11 "Torin. Up. Take him to the camp." |
| +0 | `voice` | — | c1.ser.12 "Caelen— the court seals. The sluice. The portcullis gearbox." |
| +0 | `voice` | She looks at him a beat too long | c1.ser.13 "Every lock between here and that tower has your mark on it." |
| +0 | `voice`; `walk_to` seraphina `seraphina_exit`; `move_body` `cell_back_door` open → close (left 10 cm ajar) | She leaves through the cell's back door toward the archive stair. The grate wicket stays **unlocked**. | c1.ser.14 "I'm taking the archive stair. Don't die before I can ask you why." |
| +1.0 | `gesture` torin `stand`; `walk_to` torin via (0.8, 0, 30) → (2, 0, 27) → `torin_camp`, speed 1.4; on arrival `gesture sit` | He limps north into the cloister ahead of the player and looks back once | — |
| +0 | `commit` objective | `OBJECTIVE: FOLLOW TORIN TO THE CLOISTER CAMP` · checkpoint `court_gatehouse` | — |

**Optional, Seraphina's cell** (through the unlocked grate wicket): her writing desk, an inkwell, a cold lamp and three ledgers. Inscription **"THE EMERGENCY WRIT"**: *"To Master Caelen, late of the Guild of Wards: the Bell of Vaelor rings flat. Your lock is failing. Come by the east road. Burn this. — S.V., Archivist."* Memory Echo `echo_seraphina_cell` at (−6.6, 0, 33.8): `ARCHIVIST SERAPHINA — ECHO` · *"Entry, night thirty-seven. Sent the writ east. He'll come for the bell. He'll stay for the Gate. He never leaves a lock half-open."*

### 3.4 Zone 2: The South Cloister & the Fallen Camp

| Seq | Trigger | Beats | Lines |
| --- | --- | --- | --- |
| `ch1_court/torin_camp` | Player within 4 m of `torin_camp` with LOS | Torin seated on the pallet, pressing a rag to his side. He gestures toward the Court (N), the cistern (W) and the ossuary (E) as he speaks. Objective updates on the last line. Checkpoint `court_cloister` (existing). | c1.tor.09 "Sit a moment? No. Guild men never do." · c1.tor.10 "Portcullis is the only road to the Keep. Gearbox wants its— the thing. The crank." · c1.tor.11 "Captain hid the crank in the ossuary. After the third bell. So nobody could... so nobody." · c1.tor.12 "And the seal-plates want weight. There's an arbalest on the cistern shrine. If the water hasn't— if they haven't..." · c1.tor.13 "I'll be at the gearbox when you've the crank. I'll be there. I'll remember." → `OBJECTIVE: FIND THE GEARBOX CRANK (OSSUARY) & THE ARBALEST (CISTERN)` |
| `ch1_court/cloister_breach` | 2.5 s after c1.tor.13, or player z < 20.5 in the cloister | `await_look` `cloister_breach_window_19` (cone 60°, timeout 2.0) → foley `glass_burst` + glass-shard burst; window sprite hidden → spawn `court_cloister_shr_1` (−10.6, 3.0, 19.0) at t 0, `court_cloister_shr_2` (−10.6, 3.0, 23.0) at t 0.8, `court_cloister_shr_3` (−10.6, 3.0, 27.5) at t 1.6. They drop to the floor. The existing `court_cask_cloister` sits in their landing lane, so a Grasp-hurl is a satisfying first cask kill. | c1.tor.14 "Window! West window!" (1.6) · bark "—the rafts are coming—" |
| `ch1_court/torin_rhyme` | First time the player passes within 6 m of Torin after the breach | Torin staring at nothing, humming | c1.tor.15 "Moon that saw it... crown that... how does it go? My sister used to skip to it." |

**Remove** the existing inscription "THE FALLEN CAMP" (Torin says it now) and the `court_cloister_shr_2` single spawn (replaced by the breach trio).

### 3.5 Zone 4: The West Cistern, "The Quay of Bundles" (flood & evacuation rafts)

**Narrative meaning:** the Crown promised rafts at the Third Bell. The sluice was chained shut. **You float the rafts forty nights late**, and the people who waited for them rise out of the water as the level climbs.

**Tableau T1, "The Quay of Bundles"** (quay x −12.5…−9.5, z −7…11). Fourteen bundles: sacks, a crate of crockery, a birdcage with its door open, a child's rag doll face-down. **Three pairs of shoes** lined up at the water's edge, smallest pair nearest the water. Chalked **row numbers** ("ROW 7", "ROW 8", "ROW 9") painted on the quay floor. Tally marks scratched into the quay wall, hundreds of them in groups of five. No bodies.

| Seq | Trigger | Beats | Lines |
| --- | --- | --- | --- |
| `ch1_court/cistern_arrival` | Volume `(−11, 1.5, 2)` size `(3, 3, 18)` on the quay | Seraphina is in the archive window alcove (`seraphina_cistern`), lantern lit cyan behind the grate, 17 m away SW, high. `await_look` her (cone 45°, timeout 6; if timed out, her lantern pulses and the lines play anyway). Checkpoint `court_cistern`. | c1.ser.15 "Caelen. Up here— the archive window." · c1.ser.16 "This is where they waited. The Crown promised rafts at the third bell." · c1.ser.17 "Nobody floated them. Nobody was ever going to." · bark from the water "—is it the third bell?—" |
| `ch1_court/hesk_planks` | Player within 3 m of `hesk_raft` **while** Seraphina is still at the window | She speaks before the player can read. The planks carry chalk: **"HESK — 4 — WRITTEN"** (inscription on a moving node, **[NEW]** `_inscription` parented to the raft). Reading sets `read_hesk_planks`. | c1.ser.21 "Don't read the planks." (1.8) |
| *(puzzle)* | Sluice lever (−24, 0, 10) | **Unpick** the padlock (Caelen's mark), then pull. Hints: `SLUICE CHAIN — PADLOCK WITH YOUR MASTER'S MARK — UNPICK [HOLD E]` → `CISTERN SLUICE — PULL [E] TO FLOAT THE RAFTS` | — |
| `ch1_court/cistern_sluice` (plan ID) | Accepted lever pull | Plan beats kept: `wheel` 0, `surge` 0.2 (`flood_rush`), water to 1.45 m at 0.95 m/s, rafts lift. **Add:** at t 2.5 spawn `court_cistern_risen_1` (−21.5, −0.8, 6.0) and `court_cistern_risen_2` (−19.0, −0.8, −6.5) with **[NEW]** `emerge` (start 1.6 m under, rise over 1.2 s, `splash`). They wade toward the quay: the crowd, still waiting. | c1.ser.18 "Forty nights late." (1.8) · c1.ser.19 "They'd have liked to see them float." |
| · `high_water` | Water reaches 1.45 | Seraphina's lantern lifts and she turns away; once the player reaches the west parapet she `walk_to`s offstage and the window goes dark | c1.ser.20 "Ride them to the west parapet. The King left something up there he'd rather no one read." |

**Shrine of the Drowned Mother** (the Arbalest altar island, (−17.8, −0.05, −1.2); existing pickup). It is a carved, weeping stone mother with a lap of candles, and the **Briar Arbalest** lies across her knees. Inscription **"SHRINE OF THE DROWNED MOTHER"**: *"Left at Her feet: one Bell-Watch arbalest, loaded, unfired. They told us to keep the crowd on the quay. I could not. Forgive me. — W. Ware."* (The fleeing guard's lantern read W.W. The player connects it, or does not.) The existing executioner `court_cistern_exec` guards the island. Re-fiction it as *the Bell-Watch enforcer who kept the crowd on the quay*.

**West Parapet** (existing vault, barricade and relic). Rewrite inscription **"THE KING'S EDICT"**: *"By the King's hand: the Lower Ward is a debt to the Gate. Let it be paid at the Third Bell, and let the Register be its receipt. The bell shall then silence the witnesses. — VAELOR."* The **Heart of Vaelor** relic stays behind `court_secret_bar_1`. New journal flavour: *"A fist-sized iron heart stamped with the royal sigil. It is warm, and if you hold it to your ear, something inside is counting."*

**Watch Walk (High Loop).** Through the new parapet doorway: a stone walk behind the cistern's north wall with three arrow slits framing the Keep (**SL-3**). Tableau **T2, "The Watch Post"**: empty crossbow racks, a stool, a cold brazier, and scratched into the wall in a guard's hand a tally that ends in **"3,011?"**. Someone counted them. Optional plaque **"WATCH WALK ORDERS"**: *"Archers to the walk. None to leave the Court until the toll is done. — Captain M."* Enemy: `court_watchwalk_aco` (acolyte) at (−18, 2.42, −16.3). At the east end, smash `court_watchwalk_bar` (−10.6, 3.62, −16.4) and drop into the Court beside the gearbox. A Memory Echo is not needed here; the tally is enough.

**Drain Grate (West Loop return).** A winch at (−12.4, 0, 13.4) lifts the grate into the cloister's SW corner. Hint: `DRAIN GRATE WINCH — TURN [E]`. One-way, from the cistern side.

**Memory Echo** `echo_quay_mother` at (−11.0, 0, 3.0): `A MOTHER ON THE QUAY — ECHO` (`#D8C7B0`) · *"Hesk. Four of us. The clerk said there'd be room, if we were written down."*

**Remove** inscription "CISTERN SLUICE" (its tutorial text moves into the lever's hint).

### 3.6 Zone 5: The East Ossuary, "Watchmen's Rest" (Stalker & blackout ambush)

**Narrative meaning:** the Bell-Watch were ordered to hold the Court shut. Six of them sat down together around a lantern while the bell rang and never stood up again. The crank that would have opened the portcullis is hidden among them. Taking it wakes them.

- **Upper path plaque** (replaces the existing tutorial inscription at (12.5, 0, −4.8)), **"KEEPER AVUN"**: *"Keeper Avun put out his own eyes on the night of the Third Bell. He said the dead were looking back. He hunts by sound now. Give him something else to hear."* (The `[G]` hurl hint moves to the urn's interact hint: `FUNERARY URN — GRASP [G] AND HURL TO MAKE NOISE`.) The `court_stalker` **is** Avun.
- **SL-4**: the north-end breach frames the Keep's glowing bell through stacked skulls.
- **Tableau T3, "Watchmen's Rest"**: six seated Bell-Watch corpses (plan helper `add_fallen_guard`, variant `seated`) on the ring of radius 2.6 around the lever altar, facing inward. Helmets are set on the floor in front of them; their halberds lean together like an unlit campfire. One empty seat is the captain's. A **dead lantern** sits on the altar beside the **gearbox crank** (existing `iron_lever` pickup, renamed in UI: `GEARBOX CRANK — YOUR MASTER'S MARK`). Seats **2 and 5** are flagged `rises`.
- **Memory Echo** `echo_watch_captain` at `malcor_echo` (21.0, −0.7, −9.5): `LORD MALCOR — ECHO` · *"Lower the portcullis. That is an order. ...No. Not an order. Mine. Lower it."* (The player meets this voice for real in Chapter II.)
- Approach bark from seat 2 when the player is within 5 m: `— WHISPER —` *"—close the gate, lads—"*

**`ch1_court/ossuary_blackout`** (plan ID; trigger: crank pickup). Plan beats are kept; positions and IDs are refined:

| t | Beat | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.0 | `snuff` | `torch_group` `east_crypt` → 0; the `CRYPT_LIGHT` route lamps stay at 0.55 (plan's wayfinding rule) | Every amber sconce dies at once. Only cold blue lamps remain. | — |
| 0.3 | `whisper` | `bark` from `watchman_seat_2` | — | *"—none leave the court—"* |
| 0.7 | `stingers` | `foley` `hollow_rise` ×2 + `stalker` (if Avun lives) | Bone scrape, a wet inhale | — |
| 1.2 | `rise` | Hide seat-2 and seat-5 corpse props; spawn `court_ambush_shr1` at seat 2 (19.8, −0.7, −12.0) and `court_ambush_shr2` at seat 5 (24.3, −0.7, −14.4) | **Two of the dead watchmen stand up.** | — |
| 2.0 | `reinforcements` | Spawn `court_ambush_exec` (26.5, −0.7, −5.0) at the north arch (existing ID, position refined) | A shield-executioner steps out of the dark | bark *"—back on the quay—"* |
| 2.15 | `relight` | `torch_group` `east_crypt` → 0.6 over 3.0 s | Sconces sputter back to half light | — |
| 0.0 | `torin_moves` | **[NEW]** cross-zone `walk_to` torin `torin_camp` → (0, 0, 17) → (0, 0, 0) → `torin_gearbox`, speed 1.3 | Torin heads for the gearbox, as promised. If the player returns by the East Loop, the camp is empty except for his bowl. If they take the main route, they may catch him limping across the Court. | — |

Return by the **Reliquary** (existing secret barricade `court_secret_bar_2`, loot kept) → Shortcut Quay → **Ossuary Gate**. New hint: `OSSUARY GATE — YOUR MASTER'S MARK — UNPICK [HOLD E]` (existing `shortcut_door` logic, plus the Unpick verb). Checkpoint `court_ossuary` on the upper path.

### 3.7 Zone 3 + 6: The Court of Seals and the North Portcullis Siege

**Narrative meaning:** the portcullis was lowered to keep the Lower Ward in. The inside of its bars is gouged with fingernails. **You lift the gate that was shut on them**, and the bell takes the man cranking it.

**Tableau T4, "The Tithe Notice Wall"** (south-arch piers, inner face): nine royal notices under the Crown seal, paper swollen with damp. Across all nine, one citizen's tar-black scrawl: **THERE ARE NO RAFTS**. Below them, bloody handprints at a child's height. Inscription **"THE TITHE NOTICE"**: *"BY ORDER OF THE CROWN — All souls of the Lower Ward shall assemble upon the Cistern Quay at the Third Bell, to be carried by raft above the Grey Tide. Be written in the Register, that none be left behind."*

**Tableau T5, "The Gouged Bars"**: the portcullis's **south face** carries hundreds of scratch decals. The stone sill below is grooved with fingernail tracks, and there is a scatter of small shoes. Memory Echo `echo_portcullis_child` at (0, 0, −16.0): `A CHILD — ECHO` · *"Mama, why are they shutting the gate? Mama?"*

**Gearbox plate** (replaces "THE COURT SEALS"), inscription **"PORTCULLIS HYDRAULIC"**: *"Ram & escapement by Master C., Guild of Wards. Weight both seal-plates. Hold the east current with frost while the sluice runs. Seat the crank. Do not raise while the Court is occupied."* The last line is a maintenance warning, and also the crime.

**Puzzle (existing systems kept):** shoot the **cage rope** with the Arbalest `[2]` to drop the east counterweight; push or Grasp `[G]` the plinth onto the west plate; freeze the east current `[RMB]` so the counterweight stays on its plate; seat the **crank** at the gearbox. **New precondition:** `cistern_raised` (the ram is hydraulic and fed from the cistern). If it is false, show the hint `HYDRAULIC RAM DRY — RAISE THE CISTERN SLUICE`. Checkpoint `court_basin` at the south arch fires the first time the player holds the crank in the Court.

**`ch1_court/north_portcullis`: the three-toll siege** [**AMENDS PLAN**: the 2.6 m/s single rise is replaced by three toll-staged rises; the plan's teeth and partial-lift rules still apply]

The gate rises only while **both plates stay weighted**. If a plate unweights, rise **halts and holds** (the pawl clacks) and never drops. Each toll stage needs its wave cleared **or** 30 s elapsed, with a minimum of 12 s between tolls.

| Stage | Trigger | Beats | Spawns (stable IDs) | Lines |
| --- | --- | --- | --- | --- |
| **0 — Ratchet** | Crank seated + both plates + `cistern_raised` | Torin, already at `torin_gearbox`, seizes the crank (`gesture crank`, loop). Ram hiss (`steam` jets at the ram housing). Seraphina enters the **North Gallery** from `seraphina_gallery_door` and walks to `seraphina_gallery`, so the player sees her arrive *above* the portcullis. | — | c1.tor.16 "Got her. Come on, you old— turn—" · c1.ser.22 "They'll hear the gears. All of them. Keep them off Torin." |
| **I — Moon** | t 3.0 | `bell_toll` mode `inverted` (far `bell_crack`), `resonance` from the north through the bars, `hollowing_motes` on Torin. Gate 0 → 1.7 m over 2.5 s. | `court_siege_w1_a` (−3, 0, 14.5), `court_siege_w1_b` (0, 0, 15.5), `court_siege_w1_c` (3, 0, 14.5): shriekers through the south arch | c1.tor.17 "Moon that saw it..." · bark "—third bell—" |
| **II — Crown** | Wave I clear, or 30 s | Toll. Gate 1.7 → 3.4 m. **The toll's wave shatters the frost on the east current** (`frozen_timer = 0`), so the counterweight starts sliding off. If the plate unweights, rise halts and the hint `EAST SEAL SLIPPING — FREEZE THE CURRENT [RMB]` shows. | `court_siege_w2_aco_a` (−9.4, 2.42, −16.4) on the Watch Walk ledge; `court_siege_w2_aco_b` (9.0, 0, −2.0) from the ossuary door; `court_siege_w2_shr` (0, 0, 15.0) | c1.tor.18 "Crown that willed it..." · c1.ser.23 "The east plate— the ice is gone! Freeze it!" |
| **III — Skull** | Wave II clear, or 30 s | Toll. Gate 3.4 → 5.2 m (fully open). `clear_exit` once the real aperture clears **and** Wave III is dead, or 45 s. | `court_siege_w3_exec` (9.2, 0, −2.0) from the ossuary door; `court_siege_w3_shr_a` (−9.4, 2.42, −16.8) and `court_siege_w3_shr_b` (−9.4, 2.42, −15.6) dropping off the Watch Walk | c1.tor.19 "Skull that... that..." · c1.ser.24 "Executioner, east door! Pull its shield, Caelen— grasp it!" |

Siege enemy totals: 3 + 3 + 3 = 9, with casks `court_cask_west` and a **[NEW]** `court_cask_siege` at (6.5, 0, −12) staged for hurls. Ammo and health: existing `court_blue_1`, plus a **[NEW]** flask at the gearbox foot (`court_siege_flask`).

**`ch1_court/torin_hollows`** (fires on `clear_exit`):

| t | Op | Choreography | Line |
| --- | --- | --- | --- |
| 0.0 | `gesture` torin `release_crank` → `stand` | The crank spins free. Torin steps back, satisfied. | c1.tor.20 "There. There, Master. Road's open." (3.0) |
| 3.6 | `look_at` torin → player | He looks at Caelen, puzzled and kind | c1.tor.21 "Sorry— who did you say you were?" (3.0) |
| 7.0 | `gesture` torin `sit` (permanent); `hollowing_motes` final burst; his NPC light → 0.3 over 2 s; state `torin_hollowed = true` | He sits down against the gearbox with his helmet in his lap. He never speaks a full line again. | — |
| 8.0 | `voice` (from the North Gallery) | Seraphina, looking down at him | c1.ser.25 "...Go, Caelen. I'll see to him." (2.6) |
| 11.0 | `voice` | — | c1.ser.26 "I'll write him down." (2.0) |
| 13.6 | `voice` | — | c1.ser.27 "Malcor's at the bell. He'll have heard you coming for a mile." |
| 15.0 | `walk_to` seraphina → `seraphina_gallery_door`; `vanish` behind the door | She leaves by the archive door | — |
| 15.0 | `commit` | `OBJECTIVE: CROSS THE BELL CAUSEWAY` · map exit marker on | — |

**Hollowed Torin, interact `[E]`** (cycles; never progresses anything): *"Hm? Oh. Hello."* · *"Are you lost too?"* · *"I had a sister. I think."* · *(he hums two notes of the rhyme)*.

### 3.8 Zone 6: The Bell Causeway and the physical exit into the Keep

Walking out from under the raised portcullis, the player sees **T5's gouges overhead**. The bottom bars are scored white.

| Seq | Trigger | Beats | Lines |
| --- | --- | --- | --- |
| `ch1_court/viaduct_toll` (plan ID) | Player z < −24 | t 0.5 `foley wind_gust`; rain particles over the causeway. t 2.0 `bell_toll` inverted + `resonance` `dust_front` (plan). `await_look` `bell_far` (cone 30°, timeout 4) → **SL-5**: the bell's crack flares and **violet name-ash ribbons rise from the Upper City lights** to the east and stream into the bell (**[NEW]** `name_ash_ribbon` VFX from (60, 10, −40) to (0, 22, −120), 6 s). Checkpoint `court_causeway` at z −22. | — |
| · `choir_first` | t 4.5 | `voice` from the **chasm emitter** (0, −8, −30), spatial | c1.cho.01 `THE HOLLOW CHOIR` "…key-maker…" (2.2) · c1.cho.02 "…moon… crown… skull…" (3.0) |
| `ch1_court/keep_doors` | Player z < −38 | `move_body` `keep_door_l/r` rotate 20° → 55° over 2.0 s, cue `door_groan`; violet light spills out; the wind pushes at the player's back (**[NEW]** `wind_force` 1.2 m/s², toward −Z, 3 s) | The Keep lets you in |
| *(plaque, optional)* | `causeway_plaque` (4.6, 0, −30) | Inscription **"THE BELL CAUSEWAY"**: *"Raised in the reign of Vaelor the Second, that the Keep might always hear the Court."* | — |
| **Transition** `court_to_tower` | Plane z −44 inside the dark vestibule, crossing toward −Z (plan's crossing rules) | 0.45 s dark fade (plan). The player keeps walking. Arrival `tower_from_court` in Ch II at (0, 0.1, 33), facing −Z. The geometry on both sides matches: same vestibule masonry, same door leaves, same rain on the stones behind. | — |

### 3.9 Chapter I rosters & state

**Combat roster**

| ID | Kind | Position | Wake / spawn rule | Fiction |
| --- | --- | --- | --- | --- |
| court_coldopen_shr_1/2 | shrieker | (−3, 0, 19.5) / (3.5, 0, 18.8) | `gatehouse_fracture` t 6.0 | Chasing the fleeing guard |
| court_cloister_shr_1/2/3 | shrieker | west windows, y 3.0 | `cloister_breach` | Hollowed of the Lower Ward |
| court_cistern_risen_1/2 | shrieker (`emerge`) | cistern bed | `cistern_sluice` t 2.5 | The crowd on the quay |
| court_west_1/2 | shrieker | (−16.2, −0.8, 7) / (−21.1, −0.8, −5.9) (existing) | Present | Hollowed wading the bed |
| court_cistern_exec | executioner | (−22.8, −0.8, 1.5) (existing) | Present | The quay enforcer |
| court_watchwalk_aco | acolyte | (−18, 2.42, −16.3) | Present | Choir acolyte praying at the slits |
| court_stalker | stalker | (25.5, −0.7, −10) (existing) | Always active (noise) | Keeper Avun |
| court_east_1 / court_east_aco | shrieker / acolyte | existing | Present | — |
| court_ambush_shr1/shr2/exec | shrieker ×2 / executioner | §3.6 | `ossuary_blackout` | Watchmen's Rest |
| court_entry_shr / court_shrieker_1 / court_north_exec / court_basin_aco | existing | existing | Present in the Court | The Court's dead |
| court_siege_* | §3.7 | §3.7 | Siege stages | — |

**New chapter-state keys** (merge into `default_state()`): `coldopen_done`, `outer_arch_collapsed`, `torin_stage` (0–4), `torin_mark` (`"wicket"|"grate"|"camp"|"gearbox"`), `torin_hollowed`, `seraphina_mark`, `sluice_unpicked`, `drain_grate_open`, `watchwalk_open`, `read_hesk_planks`, `siege_stage` (0–3), `portcullis_height` (float). Existing keys are kept: `gate_open` (true once `siege_stage == 3` and the aperture is clear), `gatehouse_open`, `has_lever`, `lever_inserted`, `cage_dropped`, `shortcut_open`, `ambush_done`, `cistern_raised`.

**Checkpoints:** `court_gatehouse` · `court_cloister` · `court_cistern` · `court_ossuary` · `court_basin` · `court_causeway`.

**Pacing**

| Minute | Beat | Intensity |
| --- | --- | --- |
| 0–1 | Cold-open walk-in → Fracture → arch collapse | Calm → spike |
| 1–2 | Gatehouse fight | High |
| 2–4 | Torin's camp, cloister breach | Quiet → medium |
| 4–11 | Cistern: quay, Seraphina at the window, shrine, flood, risen dead, parapet, Watch Walk | Medium, with exploration rests |
| 11–17 | Ossuary: Avun stealth, Watchmen's Rest, blackout ambush, reliquary, gate return | Dread → spike |
| 17–20 | Court puzzle assembly (rope, plinth, frost, crank) | Low–medium |
| 20–24 | Three-toll siege | Peak |
| 24–25 | Torin hollows | Silence |
| 25–27 | Bell Causeway: city ribbons, first Choir line, doors | Awe |

---

## 4. Chapter II — *THE BELL TOWER* ("The Three Tolls of Malcor")

**Registry metadata [AMENDS registry]:** `subtitle: "The Three Tolls of Malcor"`, `default_spawn: Vector3(0, 0.1, 33)`, `map_bounds: Rect2(-35, -57, 70, 93)`, `map_caption: "Vestibule • Nave • Moon-Clock Gallery • Bell Foundry • Lift • Choir Loft • Belfry"`.
**Target length:** 20–25 min. **Dramatic job:** *confront the crown.* Malcor binds the bell to his own name in front of you. Breaking his wards strips memories out of him, and you hear each one go. His confession turns your guilt inside out.

### 4.1 Layout topology

```
                                     N (−Z)
        ┌──────────────────────────────────────────────────────┐
        │ Z6 BELFRY SANCTUM  y 9.5, OPEN SKY, r = 12.9 parapet  │  Crown Yoke apex (0,32,−43.1)
        │   Great Bell (0,22,−43.1) · floorboards 6×6 @ (0,−42) │  Great Bell r 2.8 h 4.4 (visual)
        │   shaft ▼ catch landing y7 · return steps (existing)  │
        ├──────────────── BELFRY SEAL z −30.8 ─────────────────┤  3 Ward Chains converge here
        │            GRAND STAIR y6 → 9.5 (z −22.5 → −29.6)     │
        │ Z5 CHOIR LOFT  y 6   Rect2(−16,−28,32,18)             │
        │  Ward III niche (−14.25,6,−19.9)  Vigil Altar (6.6,6,−23.4)
        │  harmonic bells (−10.2, 8.5…9.3, −23…−17)             │
        ├─ south rail z −10.15 ─[ LIFT ARRIVAL ]─ malcor_rail ──┤
┌───────┴───────┐   Z4 CENTRAL COUNTERWEIGHT LIFT     ┌─────────┴────────┐
│ Z2 WEST       │   (0, 0→6, −6.57), jam ≈ 3 m        │ Z3 EAST          │
│ MOON-CLOCK    │   flanking stairs x ±11.05:         │ BELL FOUNDRY     │
│ GALLERY       │   upper flights COLLAPSE (stumps    │ Rect2(16,−10,18,22)
│ Rect2(−34,−10,│   to y≈3.6)                         │ balcony y 3.5    │
│ 18,22)  WARD I│                                     │ WARD II (31.2,3.5,−4.8)
│ Pell's bench  │   Z1 LOWER NAVE Rect2(−16,−11,32,38) │ Founders' table  │
└───────┬───────┘   y 0, roof 16, chandelier (0,9.0,9.5)└─────────┬────────┘
        └─ arch x −16 z 2.4 ─────┤          ├──── arch x 16 z 5 ──┘
                                 │ VESTIBULE Rect2(−4,27,8,8) │  doors z 35 ⇄ ch1 causeway
                                 │ ARRIVAL (0, 0.1, 33) ▲     │
```

**Hub logic:** the Nave is the hub. **West** must come before the **Lift**, because the Fork powers the lift conduit. **East** can be done before or after. The **Choir Loft** is reachable only by the lift, since Malcor's toll collapses the upper flights of both flanking stairs. **Belfry** needs all three wards.

### 4.2 Zone geometry sheet

| Zone | Bounds / elevation | Changes vs. current builder | Key marks |
| --- | --- | --- | --- |
| **Z1 Vestibule & Lower Nave** | Vestibule `Rect2(-4, 27, 8, 8)` y 0, ceiling 7, doors at z 35 (matching Ch I leaves); Nave existing | **Split** `nave_south_wall` with a 6 m pointed arch at x −3…3. **Remove** `_portal(… "ch1_court" …)` and the "THE WARDEN'S OATH" inscription. **Replace** the hanging lamp at (0, 6.8, 9.5) with a `nave_chandelier` assembly: iron ring of radius 2.2, 12 candle flames, hung at y 9.0 by a chain to the roof. **Add** 5 speaking tubes (Ch II-wide). | `arrival tower_from_court` (0, 0.1, 33) yaw 0 · `malcor_hidden` (−6.5, 6, −14.5) · `malcor_rail` (−6.5, 6, −10.7) · `chandelier_land` (0, 0, 9.5) · `tube_nave` (8.6, 2.2, 23.5) |
| **Z2 West Moon-Clock Gallery (Ward I)** | Existing `Rect2(-34, -10, 18, 22)` y 0 | **Add** the **Moon-Clock dial** (radius 2.5 framed quad, moon-phase face, hands stopped at the Third Bell) on the outer wall above the gear vault at (−33.4, 6.0, 0.5). **Add** Pell's tableau and the slate (§4.4). Hints replace the two tutorial inscriptions. | `tube_west` (−17.0, 2.0, −3.0) · `pell_bench` (−22.5, 0.43, −7.2) · `pell_slate` (−22.5, 2.6, −9.45), facing +Z |
| **Z3 East Bell Foundry (Ward II)** | Existing floor + balcony y 3.5 | **Add** two clay **bell molds** on the ground floor at (21.0, 0, 6.5) and (27.5, 0, 6.5) (r 2.4, h 3.6; the second one split open around a cracked **Sister Bell**). **Add** a hardened bronze spill decal flowing across the floor. **Add** the **Founders' Offering** table on the balcony at (18.6, 3.5, −3.4). | `tube_east` (17.0, 2.0, 9.0) · `founders_table` · `bell_plaque` (24.0, 0, 9.6) |
| **Z4 Central Counterweight Lift** | Existing `create_moving_lift` (0, −0.18 → 5.78, −6.57); latch at (0.8, 4.65, −9.72) | **Rename** the latch to **pawl** in hints. **Add** two lamps on the lift guides (they die at the jam). **Collapse** the flanking stairs' upper flights (rubble at z −6…−10; the stumps stay climbable to y ≈ 3.6). | `tube_lift` (−4.6, 2.0, −3.6) · stump marks (±11.05, 3.6, −3.0) |
| **Z5 Choir Loft (Ward III)** | Existing `Rect2(-16, -28, 32, 18)` y 6 | **Add** the **Vigil Altar** tableau (§4.6) around (6.6, 6, −23.4). **Add** a north arch spawn door at (0, 6, −27.6) (for the post-conversation testers). **Add** a secret barricade `tower_secret_bar_2` at (−14.6, 7.2, −26.6) hiding an echo. | `malcor_vigil` (5.8, 6, −22.4) kneeling, facing E · `malcor_stair` (0, 6, −22.5) · `tube_loft` (−8.2, 8.0, −11.0) |
| **Z6 Belfry Sanctum** | Existing y 9.5 | **Add** the **Crown Yoke** (non-colliding iron arcs from (±12.5, 12.8, −43.1) to apex (0, 32, −43.1)) and the **Great Bell** visual at (0, 22, −43.1) (r 2.8, h 4.4, violet emissive crack strip, bottom ≈ 19.8, clear of the Warden's 11.6 + 4.6 m airborne capsule). Three tether chains run from the bell lip to the Warden's bell-rack (dynamic beams). Storm FX layer (§4.7). **Far landmarks:** north and down, the Kiln stacks and the Gate's violet glow; south, the Sunken Court roofs and gatehouse spires. | `belfry_center` (0, 9.5, −42.0) · shaft emitter (0, 2, −42) |

### 4.3 Arrival & the live Malcor Balcony Appearance

| Seq | Trigger | t | Op | Choreography | Line |
| --- | --- | --- | --- | --- | --- |
| `ch2_tower/arrival` | Transition arrival | 0.0 | `show_chapter` | "CHAPTER II — THE BELL TOWER — The Three Tolls of Malcor." Rain sound behind the doors. Inside, total stillness and candle smoke. | — |
| `ch2_tower/vestibule_doors` | Player z < 29 | 0.0 | `move_body` doors 55° → 4° over 1.6 s, cue `door_slam`; `wind_force` stops | Wind slams the doors behind the player. They are not locked: `[E]` reopens them, and they form the route `tower_to_court`. | — |
| `ch2_tower/malcor_balcony` | Volume `(0, 1.5, 18.0)` size `(14, 3, 2.5)` | 0.0 | `walk_to` malcor `malcor_hidden` → `malcor_rail` (speed 1.0); `await_look` malcor (cone 40°, timeout 3.0) | A huge armoured shape steps out from behind a choir pier onto the south rail, 30 m away and 6 m up. Lightning through the clerestory lights him violet (diegetic flash: `focus_light` pop + `foley thunder_far`). | — |
| | | 0.8 | `voice` | He looks down at Caelen | c2.mal.01 |
| | | +0 | `voice` | — | c2.mal.02 |
| | | +0 | `voice` | — | c2.mal.03 |
| | | @line_end | `gesture` malcor `toll_handbell`; `foley bell` (pitch 0.8, spatial at Malcor) + `resonance` origin Malcor, radius 30, speed 22, strength 0.10 | **He rings his hand-bell.** A violet ring drops through the nave. | — |
| | | +0.35 | `chandelier_drop` (plan) `nave_chandelier`: `chain_slip` 0.35, `release` 0.65, `impact` on contact or a 1.8 s timeout | The chandelier's chain shrieks and lets go. 12 flames trail down and it lands at `chandelier_land`, 7–9 m in front of the player. **2 fire patches** (existing `_spawn_fire_patch`) burn for 12 s. The wreck is non-blocking with side lanes. | — |
| | | +0.6 | `rockfall` `flank_stair_w_upper`, `flank_stair_e_upper` | Both flanking stairs' upper flights crack and slump. The loft is now cut off except by the lift. | — |
| | | +1.6 | **[NEW]** `ward_chain` from Malcor's chest → `ward_1` (cyan `#82E6FF`, tone A5) | A chain of cyan light whips out of Malcor across the nave and into the west gallery | c2.mal.04 |
| | | +3.2 | `ward_chain` Malcor → `ward_2` (amber `#FFC385`, tone E5) | Amber chain into the east foundry | c2.mal.05 |
| | | +4.8 | `ward_chain` Malcor → `ward_3` (violet `#BBA1FF`, tone A4) | Violet chain back and up into the Choir Loft | c2.mal.06 |
| | | +6.4 | `ward_chain` re-anchor: all three chains detach from Malcor and **re-link from each ward to the Belfry Seal** (0, 12.3, −30.8); the seal's three sigils ignite | The Seal blazes above the loft. The three chains now hang across the tower like rigging. They stay visible until their ward breaks, replacing `_update_ward_beams`' boss-only targeting. | c2.mal.07 |
| | | @line_end | `walk_to` malcor `malcor_rail` → `malcor_vigil` (off-sight) | He turns his back and walks north into the loft's dark | — |
| `ch2_tower/nave_wake` | Malcor out of sight +1.5 s | 0.0 | Spawn `tower_nave_1` (−13.6, 0, 9.0) and `tower_nave_2` (13.6, 0, 4.0) from the side aisles (existing IDs, repositioned) | Drawn by the crash | bark "—the bell, the bell—" |
| `ch2_tower/tube_intro` | `nave_wake` cleared, or 25 s | 0.0 | `voice` from `tube_nave` (horn light pulses) | Seraphina via speaking-tube. Checkpoint `tower_nave`. | c2.ser.01–03 |

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c2.mal.01 | LORD MALCOR | "Lock-smith." | 2.0 |
| c2.mal.02 | LORD MALCOR | "I knew your step on the causeway. Guild boots. Ward-iron. Guilt." | 4.6 |
| c2.mal.03 | LORD MALCOR | "Forty nights I have rung the Lull for them. Tonight your little mercy cracked my bell." | 5.2 |
| c2.mal.04 | LORD MALCOR | "Hear me bind it. One for the moon that saw it." | 3.6 |
| c2.mal.05 | LORD MALCOR | "One for the crown that willed it." | 2.8 |
| c2.mal.06 | LORD MALCOR | "One for the skull that paid it." | 2.8 |
| c2.mal.07 | LORD MALCOR | "Break them, and you break me. Then the bell is yours again. As it always was." | 5.2 |
| c2.ser.01 | SERAPHINA — SPEAKING-TUBE | "Caelen— can you hear me? The Watch tubes still carry. I'm on the archive stair, under the Keep." | 5.0 |
| c2.ser.02 | SERAPHINA — SPEAKING-TUBE | "He's bound the bell to himself. Those chains are his name, split three ways." | 4.4 |
| c2.ser.03 | SERAPHINA — SPEAKING-TUBE | "West is the Moon-Clock. East, the old foundry. The Choir he keeps for himself." | 4.4 |

**Speaking-tube device [NEW]:** a brass horn prop (r 0.25, length 0.6) whose mouth light pulses while it carries a line. Voice-grain plays positionally from the nearest tube within 18 m, with a `tube` filter (comb plus 300–3000 Hz band-pass). Subtitles always show. If no tube is within 18 m, the line waits up to 6 s, then plays 2D at −9 dB.

### 4.4 Zone 2: The West Moon-Clock Gallery (Ward I, *the Moon*)

**Narrative meaning:** the Keep's escapement, built by Caelen, stopped at the Third Bell. Here Caelen's journeyman died trying to fix the lock with a tool built from Caelen's old drawings. **You take the dead apprentice's tuning fork and use it.**

**Tableau T1, "The Artificer's Last Stand"** (at `pell_bench`):
- **Journeyman Pell** lies across the copper workbench (`add_fallen_guard` variant `artificer`: leather apron, brass goggles pushed up), right hand still reaching for the **Voltaic Tuning Fork** (existing pickup `tower_voltaic`).
- Three scorched **acolyte corpses** lie in a half-ring at 2–3 m from the bench, with radial **lightning-scorch decals** spreading from it.
- An **executioner's shield** lies split in two, and the bench's copper is blackened.
- **The slate** (`pell_slate`) is chalk on black: a pinned drum labelled **"3,011 PINS"**, arrows, and the words **"NOT HARMONICS — NAMES?"** underlined three times. Beside it is a sketch of the governor tooth with a hairline notch circled: **"MASTER'S NOTCH — WIDENING — 40 TOLLS LEFT?"**
- Pickup message (replaces the default): `VOLTAIC TUNING FORK — Pell's work, built from your old drawings.`

| Seq / item | Trigger | Content |
| --- | --- | --- |
| `ch2_tower/tube_west` | Entry arch volume `(-16, 1.5, 2.4)` size `(3, 3, 7)` | c2.ser.04 `SERAPHINA — SPEAKING-TUBE` "Pell's workshop. He was your journeyman, wasn't he?" · c2.ser.05 "He wrote to me near the end. I didn't answer." · checkpoint `tower_west` |
| Echo `echo_pell_bench` | (−21.0, 0, −5.5) | `JOURNEYMAN PELL — ECHO` *"Master's notch is widening. I told the Warden. He said: then we ring the Lull until our arms fall off."* |
| Echo `echo_pell_drum` | (−26.5, 0, 0.5), at the gear aperture | `JOURNEYMAN PELL — ECHO` *"The drum isn't tuned to the Gate. It's tuned to people. Every pin is someone. Gods, Master— did you know?"* |
| Plaque **"THE MOON-CLOCK"** | Below the dial at (−32.8, 0, 3.4) | *"The Keep's escapement, by Master C., Guild of Wards. It keeps the bell's hours. Its hands have not moved since the Third Bell."* |
| Puzzle (existing) | Gear vault | Freeze the leaking steam pipe or the gear `[RMB]` (hint `MOON-CLOCK ESCAPEMENT — FREEZE THE PIPE OR GEAR [RMB]`), walk through the aperture, strike **Ward I**. Strike the copper lift conduit with the Fork `[4]` (hint `LIFT CONDUIT — STRIKE WITH THE FORK [4]`); the floor conduit lights to the lift lever. |
| `ch2_tower/ward_1_broken` | `_shatter_ward(ward_1)` | The cyan chain snaps and falls as glowing links (debris). The Moon-Clock's hands lurch one tick forward. **Malcor's voice from the belfry emitter** (spatial, far): c2.mal.10 |
| Secret (existing) | `tower_secret_bar_1` | **Siphon Signet**, re-flavoured: *"Pell's journeyman signet. Inside the band he scratched: FOR MASTER C., WHO TAUGHT ME TO LISTEN."* |

c2.mal.10 · LORD MALCOR · *"...the moon over the quay. I remember the— no. It's gone."* (4.0)

**Enemies:** `tower_west_exec`, `tower_west_aco` (existing) + `tower_west_shr_a` (−20.5, 0, 8.0), `tower_west_shr_b` (−29.0, 0, −6.5): hollowed Bell-Watch novices in surplices.

### 4.5 Zone 3: The East Bell Foundry (Ward II, *the Crown*)

**Narrative meaning:** the Great Bell was cast here. Before the pour, each Founder fed it one memory. The bell *knows* its makers, and Caelen is one of them. **You swing the bell's own old clapper to break the ward.**

**Tableau T2, "The Founders' Offering"** (balcony, `founders_table`): a long oak table with **five ash-bowls**, each with a pinned paper tag in a different hand:
- *"O. — a first forge-fire"*
- *"M. — a wedding morning"*
- *"S. — a mother's face"*
- *"C. — the first lock he ever opened"*
- *"V. — a coronation"*

Plaque **"THE FOUNDERS' OFFERING"**: *"Before the bronze was poured, each Founder gave one memory freely, that the Bell might know its makers. — Ledger of the Casting."* (Caelen is silent. Players who think about it realise he cannot remember his first lock. Seraphina cannot picture her mother.)

**Tableau T3, "The Sister Bell"** (ground floor): two clay bell molds. One is split open, revealing a failed **Sister Bell** cracked from lip to crown. A river of hardened bronze crosses the floor. Plaque **"THE GREAT BELL OF VAELOR"** at `bell_plaque`: *"Cast in this pit in the Year of the Grey Tide. Bronze of the Crown's treasury, quenched in the ash of the Founders' offering. Let it remember for us."*

| Seq / item | Trigger | Content |
| --- | --- | --- |
| `ch2_tower/tube_east` | Entry arch volume `(16, 1.5, 5)` size `(3, 3, 7)` | c2.ser.06 `SERAPHINA — SPEAKING-TUBE` "The foundry. They cast the Great Bell here." · c2.ser.07 "Don't look at the table on the balcony. ...Please." · checkpoint `tower_east` |
| Thurible pickup message | `tower_thurible` | `CINDER THURIBLE — carried before the Tithe procession. Still warm.` |
| Puzzle (existing) | Pendulum | The bronze pendulum is renamed in hints: `THE CROWN CLAPPER — REPULSE [Q] TWICE FROM THE WEST SIDE`. Two Repulses swing it through the cracked brick wall; Ward II is behind. |
| `ch2_tower/ward_2_broken` | `_break_pendulum_wall` → ward | The amber chain snaps. Malcor (far): c2.mal.11 |

c2.mal.11 · LORD MALCOR · *"Crown that willed it... whose crown? I knelt to someone. I knelt..."* (4.6)

**Enemies (existing):** `tower_east_shr`, `tower_east_aco` (balcony), `tower_east_exec`; cask `tower_cask_foundry`.

### 4.6 Zone 4: The Jammed Counterweight Lift ambush & Zone 5: the Choir Loft face-to-face

#### 4.6.1 `ch2_tower/lift_ambush`

Precondition: `lift_powered` (Fork conduit). The existing `tower_lift_aco` guards the lever.

| t | Beat | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.0 | `call` | Lever pull (existing) | The lift rises with chain clatter (`lift`); both lift lamps lit | — |
| at jam ≈ 3.0 m | `jam` | Existing jam logic → shake 0.06; `foley gear_grind`; lift lamps → 0 | The lift lurches and stops halfway up the shaft, in the dark. The **pawl** glows cyan above (existing light). | — |
| +0.3 | `pawl_hint` | Banner `LIFT JAMMED — SHOOT THE GLOWING PAWL` (replaces "LATCH") | — | — |
| +0.6 | `ambush_rail` | Spawn `tower_liftamb_aco_a` (−5.0, 6, −11.0) and `tower_liftamb_aco_b` (5.0, 6, −11.0) (acolyte blink-in VFX) | Two acolytes appear on the loft rail directly above and start casting down | bark *"—none rise—"* |
| +1.4 | `ambush_drop` | Spawn `tower_liftamb_shr_a` (−2.0, 7.5, −8.5) and `tower_liftamb_shr_b` (2.0, 7.5, −5.0) | Two Hollowed leap off the loft onto the stalled deck | — |
| +2.0 | `tube_lift` | `voice` from `tube_lift` | — | c2.ser.08 "That pawl is a Guild escapement— yours. Shoot it loose!" |
| +2.5 | `ambush_stumps` | Spawn `tower_liftamb_aco_c` (−11.05, 3.6, −3.0) and `tower_liftamb_aco_d` (11.05, 3.6, −3.0) | Acolytes on the broken stair stumps cross-fire | — |
| on pawl hit | `unjam` | Existing `lift_unjammed`; the lamps relight | The lift finishes the climb. Loft checkpoint `tower_choir`. | — |

#### 4.6.2 Tableau T4, "The Vigil Altar" (around `malcor_vigil`)

- Malcor's camp cot and a captain's sash folded on it.
- **Forty loaves** in a row along the east wall, from black-mouldered to fresh: he has not eaten.
- A pillar at (8.2, 6, −25.0) with **forty tally notches** cut into it: thirty-nine whole and the fortieth only half cut.
- Around the altar, **thousands of names chalked on the floor in a tightening spiral** (decal texture, r 2.6).
- At the spiral's heart, one name written again and again in degrading script: **MALCOR · MALCOR · MALCOR · MALC · MALK—**

#### 4.6.3 `ch2_tower/choir_departure` (plan ID): face-to-face

Trigger: player within 7 m of `malcor_vigil` with LOS **and** no hostile within 12 m. Fallback: the plan's final-ward fallback. Before the player is close, Malcor kneels with his back turned, **murmuring names** as positional, low-volume barks every 3 s: *"...Hesk, Mara. Hesk, Tomas. Hesk, Anna. Hesk— the little one, unnamed..."* (If `read_hesk_planks` is set, this lands like a blow.)

| t | Op | Choreography | Line |
| --- | --- | --- | --- |
| 0.0 | `gesture` malcor `rise`; `look_at` player | He stands slowly. He is very tall up close. | c2.mal.30 "Closer. My eyes are going. The rest of me is following." |
| +0 | `voice` | He gestures at the floor spiral | c2.mal.31 "Forty nights, Lock-smith. Every night, every name. Three thousand and eleven. Kneeling. Here." |
| +0 | `voice` | — | c2.mal.32 "Tonight I lost the hundredth. A fisher's boy. I knew him. I knew him." |
| +0 | `voice` | — | c2.mal.33 "You came to fix the bell. You can't. You built it to take, and it remembers how." |
| +0 | `voice`; brief pause (1.2 s) before | He steps past Caelen toward the stair | c2.mal.34 "The Archivist sent for you. Ask why she needs a lock-smith... and not a bell-wright." |
| +0 | `voice` | — | c2.mal.35 "Ring the skull in the order they rang it on the quay. Then come up. We'll finish what we started." |
| @line_end | `walk_to` malcor `malcor_stair` → up the grand stair → **through the Belfry Seal** (the seal's surface ripples violet as he passes; **[NEW]** `seal_ripple`); `vanish` beyond | He climbs without looking back | — |
| +1.0 | `voice` (from beyond the seal) | — | c2.mal.36 "Let them test you." |
| +1.5 | Spawn `tower_choir_exec` (0, 6, −26.8) and `tower_choir_stalker` (2.0, 6, −27.2) at the **north arch spawn door** (existing IDs) | The testers enter, and the chime puzzle now runs under pressure | — |

**Remove** `tower_choir_aco` (a calm room is needed for the face-to-face) and the `_ascend_malcor()` instant vanish (replaced by the walk).

#### 4.6.4 Ward III: the Tithe Chimes (existing puzzle, re-fictioned)

Inscription rewritten to **"THE TITHE CHIMES"**: *"As it was rung upon the quay: Moon (cyan). Crown (gold). Skull (violet). A false note wakes the Choir."* The chime-frame carries Caelen's mark (hint suffix `— YOUR MASTER'S MARK`).

| Event | Response |
| --- | --- |
| Correct Crescent / Crown / Skull | `THE HOLLOW CHOIR` whisper from the loft walls: "…moon…" / "…crown…" / "…skull…" (each 1.6 s), a rising choral swell |
| Wrong note (existing reset) | `— WHISPER —` "—wrong bell—" plus a hiss stinger; all three conduits dim |
| Ward III shatters | Violet chain snaps. Malcor (far): c2.mal.12. The seal drops (existing `_update_belfry_seal`). Then c2.mal.13 **replaces** the existing line "My wards are broken!…" |

c2.mal.12 · LORD MALCOR · *"Skull that paid it. I don't remember paying. I remember only the count."* (4.4)
c2.mal.13 · LORD MALCOR · *"It's done, then. Come up, Lock-smith. Bring your hands."* (3.6)

**Secret echo** behind `tower_secret_bar_2`: `echo_seraphina_loft` · `ARCHIVIST SERAPHINA — ECHO` · *"Warden. The Roll is complete. Three thousand and eleven. The King thanks you for your discretion."* (For explorers this reveals Seraphina's role one chapter early. Malcor's dying line then confirms it.)

### 4.7 Zone 6: The Open-Sky Belfry Sanctum (boss showdown)

**Arena (existing):** r 12.9 parapet; cover pillars at (±7, −36.3/−47.1); casks `tower_cask_arena_w/e/n`; pickups unchanged. Checkpoint `tower_belfry` on the threshold.

| Seq | Trigger | Beats | Lines |
| --- | --- | --- | --- |
| `ch2_tower/belfry_awakens` (plan ID; existing trigger `belfry_sanctum`) | Crossing the unsealed threshold | Malcor stands **under the Great Bell**, three tether chains from the bell lip to his bell-rack. Storm Phase I: wind, overcast, distant thunder (`thunder_far` every 9–14 s). Banner `LORD MALCOR — BELL WARDEN`. | c2.mal.14 "Here. Under it. Where I stood on the third bell." · c2.mal.15 "The Kiln is under my feet, Lock-smith. Take it from me." |
| *(combat barks)* | Warden attack wind-ups (`bark` op; never queues) | `tolling_wave` → rotates **"MOON!" / "CROWN!" / "SKULL!"** (audio telegraph: jump on the noun) · `sonic_volley` → *"Count them!"* · `dread_summon` → *"Rise, Watch! Hold the Court!"* | — |
| `ch2_tower/warden_phase_two` (plan ID; HP ≤ 260) | After the mechanical phase commit | **Storm Phase II:** rain particles across the belfry; a **[NEW]** belfry-wide `add_wet_zone`, so Voltaic arcs chain through puddles (tuning: grounded targets only); lightning strikes the Crown Yoke on every `boss_triple` (`spawn_lightning_arc` yoke → sky, 0.12 s white flash light). Malcor tears free and rises (existing airborne y 11.6). Banner `PHASE II — REFLECT HIS TOLLS` (replaces "REFLECT SONIC ORBS!"; Parry `[X/MMB]` or Repulse `[Q]` returns orbs). | c2.mal.16 "Then let the storm count with me!" |
| *(low HP bark)* | HP ≤ 80, once | — | *"Not yet— I haven't— finished the count—"* |

#### 4.7.1 `ch2_tower/belfry_shaft` (plan ID): dying confession & floorboard collapse

| t | Beat | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.0 | `dying_breath` | Remove the Warden; spawn NPC `malcor_dying` at the last position, snapped to y 9.5; `gesture kneel`; storm → Phase I levels | The storm eases. Malcor is on his knees, armour smoking, rain hissing on the bell-rack. | — |
| 0.2 | `crawl` | If more than 1.0 m from `belfry_center`: `walk_to` `belfry_center` at speed 0.6 (`crawl` anim), up to 8 s | He drags himself to the spot under the bell where he stood on Tithe Night | c2.mal.17 |
| +0 | `voice` ×6 | — | He looks up at the bell, not at Caelen | c2.mal.18–23 |
| +1.5 | `joist_crack` (plan) | `foley timber_groan`; dust bursts up through the floorboards; the yoke chain groans (`chain_strain`) | — | — |
| +0.4 | **[NEW]** `bell_drop` | `foley chain_snap`; chain links as debris; the Great Bell (visual RigidBody, no player damage, pushes the player aside if they are under it) falls 12 m in ≈ 1.2 s | **The Great Bell comes down on its Warden.** | — |
| on bell contact | `open_shaft` (plan) | `floorboards` hidden and collision off; splinter burst (24 debris); `malcor_dying` `vanish` (falling with motes); the bell tween continues down to y −30 | Bell, Warden and floor drop into the shaft. If the player is on the boards, they fall with them; that is the route. | — |
| +2.4 | `kiln_answer` | `foley impact_deep` from the shaft emitter; orange light bloom up the shaft (`focus_light` pulse, 1.5 s) | Far below, something enormous lands in fire | — |
| +3.0 | `choir_call` | `voice` from the shaft emitter | Pale light rises from the dark | c2.cho.04 |
| +3.0 | `commit` | `OBJECTIVE: DESCEND THE BELFRY SHAFT`; transition `tower_to_kiln` armed (plan rules: the trigger sits below the broken deck and above the y 7 catch landing; feet must cross downward) | — | — |

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c2.mal.17 | LORD MALCOR | "Wait. Wait. Let me— while I still have it." | 3.2 |
| c2.mal.18 | LORD MALCOR | "I found your notch. The night before the Tithe. A hairline in the governor tooth." | 5.0 |
| c2.mal.19 | LORD MALCOR | "I could have filed it true. I left it." | 3.0 |
| c2.mal.20 | LORD MALCOR | "I thought: let it fail on the first toll. Let me be the man who rang... and nothing came." | 5.6 |
| c2.mal.21 | LORD MALCOR | "It held for three thousand and eleven. Then it waited forty nights. For tonight." | 5.2 |
| c2.mal.22 | LORD MALCOR | "Ask the Archivist whose hand wrote the Roll." | 3.6 |
| c2.mal.23 | LORD MALCOR | "Caelen. My name is... my name was..." *(never finished)* | 4.0 |
| c2.cho.04 | THE HOLLOW CHOIR | "…key-maker… come down…" | 3.0 |

**Transition** `tower_to_kiln` → arrival `kiln_from_tower` (Ch III §5.3). The 0.45 s fade happens mid-fall, and the player lands on the Foundry Rim. **Return route** `kiln_to_tower` (plan) is kept and is re-fictioned as **the Archive Stair** Seraphina took down.

### 4.8 Chapter II rosters & state

| ID | Kind | Position | Rule |
| --- | --- | --- | --- |
| tower_nave_1/2 | shrieker | (−13.6, 0, 9.0) / (13.6, 0, 4.0) | `nave_wake` |
| tower_west_exec / tower_west_aco | existing | existing | Present |
| tower_west_shr_a/b | shrieker | §4.4 | Present |
| tower_east_shr / tower_east_aco / tower_east_exec | existing | existing | Present |
| tower_lift_aco | acolyte | existing | Present (guards the lever) |
| tower_liftamb_aco_a/b/c/d, tower_liftamb_shr_a/b | acolyte ×4, shrieker ×2 | §4.6.1 | `lift_ambush` |
| tower_choir_exec / tower_choir_stalker | executioner / stalker | north arch | After `choir_departure` |
| warden | warden (boss) | (0, 9.5, −44.2) (existing) | `belfry_awakens` |

**New state keys:** `vestibule_shut`, `balcony_done`, `chandelier_down`, `flank_stairs_collapsed`, `nave_awake`, `malcor_mark`, `malcor_conversed`, `lift_ambush_done`, `bell_fallen`, `malcor_confessed`. Existing keys are kept: `wards`, `gear_frozen`, `lift_powered`, `lift_unjammed`, `lift_completed`, `boss_dead`, `boss_hp`.
**Checkpoints:** `arrival/ch2_tower/tower_from_court` · `tower_nave` · `tower_west` · `tower_east` · `tower_choir` · `tower_belfry`.

| Minute | Beat | Intensity |
| --- | --- | --- |
| 0–2 | Vestibule, doors slam, **Malcor's balcony**, chandelier, chains | Awe → spike |
| 2–3 | Nave wake fight; Seraphina via tube | Medium |
| 3–9 | West gallery: Pell's tableau, slate, Ward I, Fork, conduit | Medium; story density high |
| 9–14 | East foundry: Founders' Offering, Thurible, pendulum, Ward II | Medium |
| 14–16 | **Lift ambush** | High |
| 16–18 | **Face-to-face with Malcor** | Silence |
| 18–20 | Chimes under pressure (exec + stalker) | High |
| 20–25 | **Belfry boss**, Phase II storm | Peak |
| 25–26 | Confession, bell drop, fall | Grief → plunge |

---

## 5. Chapter III — *THE KILN OF ASH* ("Where Names Become Iron")

**Registry metadata [AMENDS registry]:** `subtitle: "Where Names Become Iron"`, `default_spawn: Vector3(0, 6.1, 24.6)`, `map_bounds: Rect2(-33, -43, 66, 70)` (unchanged), `map_caption: "Foundry Rim • Crucible Hall • Frozen Aqueduct • Deep Smeltery • Great Ashen Gate"`.
**Target length:** 22–28 min. **Dramatic job:** *pay.* You learn what the Gate is made of and who chose its names. Then you pour the key you once refused to pour, and turn it.

### 5.1 Layout topology

```
                                N (−Z)
   ┌──────────── GREAT ASHEN GATE z −38 · doors 2 × 6.6 × 8 ───────────────┐  tympanum y 10.3…24 (name-grid)
   │  threshold z −38…−43 → THE HOLLOW BEYOND (vista; wind wall z −42.6)     │  Crown Vessel (0, 22.5, −38.2)
   ├───────────── Z6 GATE FORECOURT  Rect2(−13,−38.6,26,18.1) y 0 ───────────┤  S3 gallery (−11.6, 5.5, −26)
   │   Ladle pit (0, 0, −31.6) · cauldron (0, 6.45, −28.75) · casks/flask     │  NPC ladder (−12.2, 0, −22.5)
   ├──────────────────────── arch z −21.1 ────────────────────────────────────┤
┌──┴──────────┐ slag  ┌──────── Z2 CRUCIBLE HALL (hub) ────────┐ slag ┌─────┴────────┐
│ Z3 WEST     │ river │ procession Rect2(−8.1,−20.8,16.2,34.8) │river │ Z4 EAST DEEP │
│ FROZEN      │ x −10 │ vessel racks x ±6.6 · soul channels    │ x 10 │ SMELTERY     │
│ AQUEDUCT    ├bridge─┤ x ±5.6 → forecourt → Gate threshold    ├bridge┤ ash chute,   │
│ valve deck  │ z −10 │ Z5 QUENCH TROUGH & KEY HOIST (0,·,−5)   │ z −10│ ore cart,    │
│ y 3.02      │ z 4   │ GREAT BELL embedded (2.2, −0.3, 10.0)  │ z 4  │ slag dam     │
└──┬──────────┘       └──────────┬─────────────────────────────┘      └─────┬────────┘
   │ West Rim Stair        Pour Stair (BLOCKED by the Bell)         East Gantry Stair │
   └───────────── Z1 FOUNDRY RIM  y 6.0  Rect2(−11.5, 13.8, 23, 13.2) ──────────────┘
         drop throat + ash heap · ARRIVAL (0, 6.1, 24.6) · Archive Stair door (7.4, 6, 24.8)
```

**Hub logic:** the **Rim** overlooks everything. The fallen Bell has smashed the central Pour Stair, so the player must go **West** (Aqueduct → trough water) and **East** (Smeltery → slag power) in either order. Both wings join the **Crucible Hall** floor over the slag bridges. The Hall leads north to the **Forecourt** and the **Gate**. The rim stays Seraphina's vantage point until she comes down.

### 5.2 Zone geometry sheet

| Zone | Bounds / elevation | Changes vs. current builder | Key marks |
| --- | --- | --- | --- |
| **Z1 Foundry Rim** | **Raise** `observation_landing` to **y 6.0** (the existing deck at y 0 becomes the rim's undercroft wall). Rail at z 14.4, y 6.75; rail broken x 1…6 where the Bell went over. | **Add** the drop throat `Rect2(-2.5, 24, 5, 3)` with a stone shaft overhead (broken iron grate at y 12) and an ash heap (decal plus a low mound collider). **Add** the **West Rim Stair**, 4 m wide, from (−9.5, 6, 20.5) descending through a cut in the rim's west wall and the aqueduct end wall (x −13…−16, z 18) to (−16.5, 0, 15.0). Mirror it as the **East Gantry Stair** to (16.5, 0, 15.0). **Add** the **Pour Stair** (0, 6, 14.2) → (0, 0, 7.5), with its lower half crushed and blocked by Bell rubble. **Add** the **fresh-pour rack** and **auto-pour chute** (§5.3). **Remove** `_portal(… "ch2_tower" …)`. The Archive Stair door at (7.4, 6, 24.8) becomes route `kiln_to_tower` (plan). | `arrival kiln_from_tower` (0, 6.1, 24.6) yaw 0 · `S1_rim` (−3.2, 6, 15.1) · `fresh_rack` (−8.5, 6, 21.5) · `malcor_helm` (0.9, 6.05, 23.2) · `crucible_hall_center` (0, 2, −8) |
| **Z2 Crucible Hall** | Existing procession y 0, slag rivers x ±10, bridges z −10/4 | **Add** **name-vessel racks**: 3 tiers (y 0.3/1.3/2.3), MultiMesh, along x ±6.6 from z −18 to z 12; 24 near-player vessels get legible `Label3D` names, the rest a glyph texture. **Add** **soul-slurry channels**: twin emissive floor channels at x ±5.6 from z 12 → −20.8 → forecourt → threshold (0, 0, −37) (`add_floor_conduit` with a **[NEW]** `soul` material, always lit, pulsing on tolls). **Add** the **embedded Great Bell** at (2.2, −0.3, 10.0), tilted 24° (r 2.8, cracked, violet emissive; solid collider). It tolls (§5.3). | `S2_hall` (−5.4, 0, −1.5) · `bell_embedded` (2.2, −0.3, 10.0) · hall choir emitters at the racks |
| **Z3 West Frozen Aqueduct** | Existing; valve deck y 3.02 | **Add** frost rime material on the walls and icicle props on the outlet header. **Add** the **Quench-Masters' Refusal** tableau, **Ilse's vessel**, the **Tithe Roll lectern** (§5.4). **Add** speaking tubes. **Remove** inscriptions "THE AQUEDUCT VALVE" (moved to hints) and "THE KILN OF ASH" (rim). | `tube_aq` (−14.5, 2.0, 12.0) · `tube_valve` (−24.0, 4.2, −12.8) · `ilse_vessel` (−20.5, 0.06, −6.5) · `tithe_lectern` (−26.6, 3.02, −11.6) |
| **Z4 East Deep Smeltery** | Existing | **Add** the **Ash Chute** from the ceiling at (18.9, 9.5, 7.2), pouring glowing ash into the cart. **Add** the **Ladle Crew** tableau along x 13.0, z 0…6. Turn the two Ash Sentinels into **dormant alcove statues** that wake on dam break. **Add** `kiln_smelt_rail_shr` on the rails for the cart crush. | `tube_smelt` (14.5, 2.0, 12.0) |
| **Z5 Quench Trough & Key Hoist** | Existing trough (0, 0.32, −5), mold (0, 2.4, −5), hoist lever (3.55, 0, −5) | **Add** the crucible spout above (0, 8.0, −5) for the pour stream. **Add** the mold tag inscription. Key-tempering sequence (§5.6). | `key_spout` (0, 8.0, −5) |
| **Z6 Forecourt & Great Ashen Gate** | Existing forecourt and gate | **Add** the **S3 gallery** `Rect2(-12.6, -30, 1.8, 8)` y 5.5 (NPC-only) with an NPC ladder at (−12.2, 0, −22.5). **Add** a non-colliding **tympanum** over the Gate, x −12…12, y 10.3…24, z −38.6, carved with the King's face, mouth open; the field is a scrolling emissive **name-grid**. **Add** the **Crown Vessel** keystone at (0, 22.5, −38.2) with a hidden `VAELOR` Label3D. **Add** a lock-plate with a Key-and-Fork mark at (0, 1.5, −37.4). **Add** the **Hollow Beyond vista** beyond the threshold (§5.8). Make `ashen_threshold_backstop` visually transparent; its collision stays as the wind wall at z −42.6. | `S3_gallery` (−11.6, 5.5, −26.0) · `S4_gate` (−2.5, 0, −35.0) · `S5_edge` (0, 0, −41.0) · `ladle_pit` (0, 0, −31.6) |

### 5.3 Arrival: the landing drop, Seraphina at the rim, and the Chilling Revelation

The player falls through the 0.45 s fade and lands in the ash heap at the bottom of the drop throat. The heap is soft (no fall damage). **Malcor's helm** lies in the ash a metre away (interact: `LORD MALCOR'S HELM — STILL HUMMING`). Through the broken rail ahead, the **Great Bell** lies embedded in the Crucible Hall below, cracked and glowing. Seraphina's ash footprints (decal trail) lead from the Archive Stair door to the rail.

**Tableau T1, "Fresh Pour"** (`fresh_rack`): a small iron rack fed by the **auto-pour chute** that drops from the throat. Three vessels still glow orange-hot:
- **TORIN, BELL-WATCH**
- **WENDEL WARE, BELL-WATCH**
- **AGNA OF THE STEPS**

A **fourth mold is filling as the player watches**. Glowing ash trickles in and letters slowly surface that are not yet legible: someone in the upper city, right now. Interact hints: `NAME-VESSEL — "TORIN, BELL-WATCH" — STILL WARM` · `AN UNFINISHED VESSEL — THE NAME IS STILL ARRIVING`.

| Seq | Trigger | t | Op | Choreography | Line |
| --- | --- | --- | --- | --- | --- |
| `ch3_kiln/arrival` | Transition arrival | 0.0 | `show_chapter` | "CHAPTER III — THE KILN OF ASH — Where Names Become Iron." Furnace roar, and the embedded bell tolling every **14 s** (`bell_toll` mode `local`, emitter `bell_embedded`, `pulse_vessels = true`). | — |
| `ch3_kiln/rim_meeting` | Player within 7 m of `S1_rim`, or 12 s | 0.0 | `look_at` seraphina → player | She is at the rail, lantern raised, and turns at his step | c3.ser.01 |
| | | +0 | `voice` | — | c3.ser.02 |
| | | +1.6 (silence for Caelen) | `voice` | She reads the answer in his face | c3.ser.03 |
| | | +0 | `voice`; `gesture` beckon toward the rail | — | c3.ser.04 |
| `ch3_kiln/the_vessels` | Rail volume `(0, 7.5, 15.0)` size `(20, 3, 2)`, or 20 s after `rim_meeting` | 0.0 | `await_look` `crucible_hall_center` (cone 45°, timeout 5) | — | — |
| | | 0.0 | **[NEW]** `kiln_bell_pulse` | **The Revelation.** The embedded bell tolls. A wave of pale violet-white light runs out of every vessel rack, down the soul channels, across the forecourt and up into the Gate. The Gate's tympanum lights name by name in a sweep from the bottom up, 3,011 points. For one second every vessel's name is legible. | — |
| | | 1.2 | `voice` (Choir: rack and Gate emitters, full unison, first time) | — | c3.cho.01 · c3.cho.02 |
| | | 5.6 | `voice` ×4 | Seraphina speaks without looking at him | c3.ser.05–08 |
| `ch3_kiln/torin_vessel` | `await_look` `fresh_rack` TORIN vessel (cone 25°, no timeout; only while Seraphina is at S1) | 0.0 | `voice` | — | c3.ser.09 · c3.ser.10 |
| `ch3_kiln/rim_brief` | End of `the_vessels` lines | 0.0 | `voice` ×3; `commit` objective + checkpoint `kiln_landing` | She points west, then east | c3.ser.11–13 → `OBJECTIVE: FLOOD THE QUENCH TROUGH (WEST) · BREAK THE SLAG DAM (EAST)` |

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c3.ser.01 | ARCHIVIST SERAPHINA | "You fell. Of course you fell. Guild men never take stairs." | 3.6 |
| c3.ser.02 | ARCHIVIST SERAPHINA | "Malcor?" | 1.2 |
| c3.ser.03 | ARCHIVIST SERAPHINA | "...Then he's with the bell." | 2.4 |
| c3.ser.04 | ARCHIVIST SERAPHINA | "Come to the rail. I want you to see it before I say anything." | 3.6 |
| c3.cho.01 | THE HOLLOW CHOIR | "…we were waiting on the quay…" | 3.0 |
| c3.cho.02 | THE HOLLOW CHOIR | "…write us down… write us down…" | 3.2 |
| c3.ser.05 | ARCHIVIST SERAPHINA | "Iron that remembers. The only thing the Hollow can't eat through. Orrun found it. The King paid for it." | 5.6 |
| c3.ser.06 | ARCHIVIST SERAPHINA | "Every vessel is a name. Every name is someone from the lower ward." | 3.8 |
| c3.ser.07 | ARCHIVIST SERAPHINA | "Three thousand and eleven. The Gate is made of them." | 3.4 |
| c3.ser.08 | ARCHIVIST SERAPHINA | "And now the bell's down here with them. Still calling. Listen— it's pouring new ones." | 4.8 |
| c3.ser.09 | ARCHIVIST SERAPHINA | "...Torin." | 1.4 |
| c3.ser.10 | ARCHIVIST SERAPHINA | "I said I'd write him down. I didn't mean— the bell did it for me." | 4.0 |
| c3.ser.11 | ARCHIVIST SERAPHINA | "The Gate won't open without the Ashen Key. The last piece of your commission. They never poured it." | 5.0 |
| c3.ser.12 | ARCHIVIST SERAPHINA | "The hoist needs the quench trough full and the slag sluice running. Aqueduct west. Smeltery east." | 5.0 |
| c3.ser.13 | ARCHIVIST SERAPHINA | "I'll watch from up here. I can see the whole floor. ...I'm not going down among them." | 4.6 |

**Remove** the existing Seraphina NPC lines and position at (−6.15, 0, 17.4). She now stands at `S1_rim` (y 6) with the lines above.

### 5.4 Zone 3: The West Frozen Aqueduct (*the cold that refused*)

**Narrative meaning:** on Tithe Night the Quench-Masters refused. They froze their own aqueduct mid-pour, with themselves in it, and stopped the hand-pour of one witness. **You thaw their refusal** (power, freeze, climb, open the valve) to flood the trough that will quench your key.

**Tableau T2, "The Quench-Masters' Refusal":** four workers in leather quench-aprons stand encased in blue ice at the pool's west edge (x −27.5; z 9.0, 6.0, 3.0, 0.0), hands linked in a chain. Their rakes are frozen upright in the pool. The last one's free hand rests on the aqueduct's frost-valve. (**[NEW]** prop `frozen_worker`: a translucent ice material over the fallen-guard rig, with a faint inner glow.)

**Tableau T3, "The Half-Poured":** at `ilse_vessel`, a single name-vessel lies on its side, frozen into the pool's ice and cracked open. Half its surface is iron. The other half is **translucent, with a figure-shaped glow curled inside**. Its stamp reads **VANT, ILSE — WITNESS — HAND-POUR**. It sings alone, out of tune with the Choir. Interact: `A VESSEL, HALF-POURED — "VANT, ILSE — WITNESS"`.

**Tableau T4, "The Tithe Roll":** a lectern on the valve deck at `tithe_lectern`, lit by a single cold focus light. An open ledger lies on it.

| Seq / item | Trigger | Content |
| --- | --- | --- |
| `ch3_kiln/tube_aqueduct` | Bottom of the West Rim Stair | c3.ser.19 `SERAPHINA — SPEAKING-TUBE` "The Quench. Orrun's men cooled the vessels here. ...It's frozen. It shouldn't be frozen." · checkpoint `kiln_aqueduct` |
| `ch3_kiln/ilse_sings` | Player within 4.5 m of `ilse_vessel` | `ILSE` (solo, from the vessel): c3.ils.01 "Sera...? Is that you on the stair?" (3.0) · c3.ils.02 "It's cold. The others are singing. I only remember half the song." (4.0) · after 2.0 s, from `tube_aq`: c3.ser.14 `SERAPHINA — SPEAKING-TUBE` "...Caelen? Who's— who is that singing?" (3.4). **No answer.** Sets `ilse_heard`. |
| Echo `echo_quenchmaster` | (−26.0, 0, 4.5) | `QUENCH-MASTER — ECHO` *"Freeze it. Freeze the falls. They'll not pour the girl whole while there's breath in us."* |
| Plaque **"THE AQUEDUCT OF THE QUENCH"** | (−21.0, 0, 8.4) (replaces "THE AQUEDUCT VALVE") | *"Cold water makes a name hold its shape. — Kiln-Master Orrun"* |
| Puzzle (existing) | Pump, spouts, valve | Strike the pump conduit with the Fork `[4]` (`AQUEDUCT PUMP — STRIKE WITH THE FORK [4]`). Freeze the three falls `[RMB]` and climb them before they thaw (`FROZEN FALL — CLIMB BEFORE IT THAWS`). Turn the valve `[E]`. |
| `ch3_kiln/tithe_roll_warning` | Player reaches the valve deck (volume `(-24, 4.5, -8.5)` size `(8, 3, 9)`) | From `tube_valve`: c3.ser.15 "Caelen... is there a ledger on the lectern by the valve?" (3.4) · c3.ser.16 "Leave it. Please. Just turn the valve." (2.8) |
| Inscription **"THE TITHE ROLL"** | `tithe_lectern`; reading sets `read_tithe_roll` and adds the journal entry | *"THE TITHE ROLL OF THE LOWER WARD — compiled for the Crown by S. Vant, Archivist of the Register. Three thousand and eleven entries, in a fair hand."* / *"Entry 1: VANT, ILSE — struck through. Beside it, the same hand: Replaced — HESK, Mara · HESK, Tomas · HESK, Anna · HESK, infant (unnamed)."* / *"Below, in another hand: Witness brought down after the Third Bell: VANT, ILSE. Hand-pour, by order. — O."* |
| `ch3_kiln/aqueduct_surge` (plan ID) | Valve turned | Plan beats `wheel_turn` 0, `trough_rush` 0.2, `high_water` 1.4; the cyan trough conduit lights. **Add:** as warm water floods the channels, the frozen workers' ice **sheds a skin of meltwater** (drip particles). They are not freed; the image is that the refusal is finally ending. |
| Secret (existing) | `kiln_secret_bar_1` → `relic_oath` | Re-flavour: **"QUENCH-MASTERS' OATH"**: *"An iron ring stamped WE WILL NOT POUR. Heavier than it looks."* |

**Enemies (existing):** `kiln_aq_shr`, `kiln_aq_walkway_shr_n`, `kiln_aq_walkway_shr_s`, `kiln_aq_aco_1` (on the valve deck).

### 5.5 Zone 4: The East Deep Smeltery (*the runaway ore-cart breach*)

**Narrative meaning:** the carts carried *name-ash* from the bell-shaft chute to the crucible. **You send a cart full of people through a wall.** It is the most practical and the most terrible thing you do in the Act.

**Tableau T5, "The Ladle Crew":** five smelters' skeletons in iron collars, chained to a rail post at x 13.0, z 0…6, their tools still in their hands. Optional plaque **"SMELTERY ROTA"**: *"Night of the Third Bell — all hands to the ladle. Collared hands to be released at dawn. — O."*

**Tableau T6, "The Ash Chute":** a funnel from the ceiling at (18.9, 9.5, 7.2) steadily pours **glowing grey ash** into the ore cart. The cart's load (existing `cart_ore`) gets a **[NEW]** `name_ash` material: dark cinder with drifting emissive glyphs. New hint: `ORE CART — FULL OF NAME-ASH — REPULSE [Q] DOWN THE RAILS INTO THE SLAG DAM`.

| Seq / item | Trigger | Content |
| --- | --- | --- |
| `ch3_kiln/tube_smeltery` | Bottom of the East Gantry Stair | c3.ser.17 `SERAPHINA — SPEAKING-TUBE` "That cart's full of ash from the bell chute. That's... them. What's left before the iron." (4.4) · c3.ser.18 "Send it. They won't mind. They don't remember minding." (3.6) · checkpoint `kiln_smeltery` |
| `ch3_kiln/dam_break` (plan ID) | Ore-cart impact on `slag_dam` | Plan beats `dam_fracture`, `slag_vent`. **Add:** **[NEW]** cart impact damage (speed > 6 m/s → 120 damage to enemies struck); `kiln_smelt_rail_shr` (18.9, 0, −2.0) wanders the rails to be crushed. On impact the name-ash bursts into a **cloud of glowing letters** that drift upward over the smeltery for 20 s (**[NEW]** VFX `glyph_drift`). The amber hoist conduit lights. **The dormant Ash Sentinels wake** (`kiln_smelt_ash`, `kiln_smelt_ash_east`; existing IDs, inactive until this commit), with the stalker `kiln_smelt_stalker`. Banner `SLAG DAM SHATTERED` (existing). |
| Bark on wake | Sentinel activation | `— WHISPER —` from each sentinel: *"—pour—"* / *"—hold the shape—"* |

### 5.6 Zone 5: The Crucible Key Tempering & Seraphina's confession

**Precondition:** `trough_flooded` and `dam_broken`. When both are set, `ch3_kiln/seraphina_descends` moves Seraphina from `S1_rim` to `S2_hall` by the West Rim Stair, the aqueduct and bridge z 4 (off-sight if possible; if seen, she simply walks). She stands among the west vessel racks with one hand on a vessel. She broke her word: she came down among them.

**Mold tag** (inscription attached to the mold): **"THE ASHEN KEY"**: *"Pattern & mold: Master C., Guild of Wards. DO NOT POUR."* It is in Caelen's own hand. Hoist hint: `CHAIN HOIST — LOWER YOUR MOLD [E]`.

**`ch3_kiln/key_tempering`** **[NEW; replaces the instant forge in `_use()`]**. Precondition: no hostile within 14 m of the trough (the hall's existing `kiln_ash_1` and `kiln_crucible_exec` must be dealt with).

| t | Beat | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.0 | `lower` | `move_body` key mold y 2.4 → 1.0 over 2.0 s, cue `lift` | The mold descends on its chain | — |
| 2.2 | `pour` | **[NEW]** `pour_stream` from `key_spout` into the mold, 1.8 s; `name_stream` from the nearest racks into the stream | Molten slag pours. **Threads of pale light pull out of the nearby vessels and run into the pour.** The key is named iron too. | — |
| 4.2 | `quench` | The mold drops into the trough; 4 `add_steam_jet` bursts; `foley quench_hiss`; existing cyan `_shockwave` | A violent white steam explosion | — |
| 4.5 | `cooling` | Pickup spawns non-collectable; hint `THE ASHEN KEY — TEMPERING (TOO HOT)`; 22 s cool timer, key glow red → dull | — | — |
| 5.0 | `confession` | `voice` ×9; Seraphina `walk_to` the trough's west side (−2.6, 0, −5.0) if the player is more than 14 m from `S2_hall` | She speaks to the steam, not to him | c3.ser.20–28 |
| 26.5 | `cooled` | Hint `THE ASHEN KEY — TAKE [E]`; checkpoint `kiln_hall` | — | — |

| ID | Speaker | Line | Dur. | Condition |
| --- | --- | --- | --- | --- |
| c3.ser.20 | ARCHIVIST SERAPHINA | "I wrote them." | 1.8 | — |
| c3.ser.21 | ARCHIVIST SERAPHINA | "The King asked for a census of the lower ward. I knew what a census was for." | 4.4 | — |
| c3.ser.22 | ARCHIVIST SERAPHINA | "Three thousand and eleven names, in a fair hand, by lamplight." | 3.8 | — |
| c3.ser.23 | ARCHIVIST SERAPHINA | "My sister was the first page. I struck her. The count had to hold, so I wrote four more." | 5.0 | — |
| c3.ser.24a | ARCHIVIST SERAPHINA | "You read it. Then you know their name." | 2.8 | `read_tithe_roll` |
| c3.ser.24b | ARCHIVIST SERAPHINA | "A family by the cistern. Hesk. Their name was Hesk." | 3.2 | not `read_tithe_roll` |
| c3.ser.24c | ARCHIVIST SERAPHINA | "You saw it chalked on the raft. I asked you not to read it." | 3.4 | `read_hesk_planks` |
| c3.ser.25 | ARCHIVIST SERAPHINA | "Ilse went down to warn them anyway. The bell didn't call her. So they brought her here. By hand." | 5.2 | — |
| c3.ser.26a | ARCHIVIST SERAPHINA | "That was her, in the aqueduct. Singing half a song." | 3.2 | `ilse_heard` |
| c3.ser.26b | ARCHIVIST SERAPHINA | "She's still in there, Caelen. Half of her." | 2.8 | not `ilse_heard` |
| c3.ser.27 | ARCHIVIST SERAPHINA | "Malcor wanted it shut forever. I want it open. Let them out. Let her out." | 4.4 | — |
| c3.ser.28 | ARCHIVIST SERAPHINA | "You can hate me on the other side. Take the key." | 3.2 | — |

### 5.7 Live Meltdown Alarm, Rising Slag & the Crucible Colossus ("The Ladle")

**`ch3_kiln/meltdown`** (plan ID; trigger: Ashen Key pickup → existing `_trigger_kiln_meltdown()`, re-scripted):

| t | Beat | Op | Choreography | Line |
| --- | --- | --- | --- | --- |
| 0.0 | `alarm` | `foley alarm` (existing synth, looped 3×); `bell_toll` local **period 6 s**; rising slag armed (plan: 0.28 m/s toward y −0.14) | Klaxon horns. The embedded bell begins tolling fast. Every vessel pulses with each toll. | — |
| 0.2 | `overflow` | **[NEW]** `slag_cascade` at both sides of the forecourt arch (z −21.1, x ±5.5): visual slag falls plus 2 fire patches | The crucible spills | — |
| 0.35 | `guardians` (plan) | Spawn `colossus` with **[NEW]** `emerge` from `ladle_pit` (start y −4, rise 2.5 s, slag drip VFX), `kiln_meltdown_ash`, `kiln_meltdown_aco` (existing IDs) | **The Ladle** heaves itself out of the forecourt slag: a 5 m iron pourer with a crucible for a chest | — |
| 0.5 | `seraphina_runs` | `walk_to` seraphina (speed 4.0, run) → forecourt arch → NPC ladder → `S3_gallery` | The player sees her sprint ahead and climb | c3.ser.30 (replaces the existing `say`) |
| — | banners | Replace "MELTDOWN — CRUCIBLE COLOSSUS AWAKENS!" with `MELTDOWN — THE LADLE WAKES`; boss HUD name `THE LADLE — CRUCIBLE COLOSSUS` | — | — |

**Phase I (HP 640 → 320).** Existing attacks `tolling_wave`, `boss_triple`, `melee`. **[NEW]** the Ladle's `tolling_wave` is **gated to the embedded bell's toll**: it can only fire on a toll, so the distant bell is the jump telegraph. It is frost-immune (existing). Voltaic always overloads it (existing). The forecourt cauldron `cauldron_colossus` hangs at (0, 6.45, −28.75). Seraphina calls tactical intel from `S3_gallery`; each line plays once, on its condition:

| ID | Condition | Line | Dur. |
| --- | --- | --- | --- |
| c3.ser.30 | Meltdown t 0.5 | "The crucible's overflowing— it's waking the Ladle! Forecourt, before the slag takes the hall!" | 4.6 |
| c3.ser.31 | Colossus spawned + 6 s | "That's Orrun's Ladle! Made from the overflow— named iron, no single name!" | 4.4 |
| c3.ser.32 | First Frost hit on the Ladle | "Frost won't bite named iron! Fork it— the iron carries the current!" | 4.0 |
| c3.ser.33 | Ladle within 3 m of (0, 0, −28.75) and the chain intact | "Above it— the cauldron chain! Shoot it now!" | 2.8 |
| c3.ser.34 | First `tolling_wave` | "When the bell tolls, it tolls! Jump the ring!" | 2.6 |
| c3.ser.35 | Player holding a cask with `[G]` | "Yes— feed it the cask!" | 1.8 |
| c3.ser.36 | Player HP < 30, once | "Flask by the west pillar— take it!" (`kiln_guardian_flask`) | 2.4 |

**Phase II, "Overdrive"** (plan's `colossus_overdrive`, HP ≤ 320): plan beats `anvil_overdrive` and `slag_burst`. **Add:** the Ladle's chest crucible **cracks open**, exposing a white name-glow. **[NEW]** chest weakpoint ×1.5 damage. Every hit peels **glowing letters** off its body (`glyph_drift`, small). Rate-limited (1 per 4 s) **name barks** from the Ladle: `— WHISPER —` *"—HESK—"*, *"—third bell—"*, *"—room on the raft—"*, *"—WARE—"*. Recovery is already faster in Phase II (existing `boss_phase > 0`).

| ID | Condition | Line | Dur. |
| --- | --- | --- | --- |
| c3.ser.37 | Overdrive | "Its chest is open— the names are coming loose! Strike the white!" | 3.6 |

**`ch3_kiln/colossus_falls`** (plan ID): the Ladle topples forward (plan's `colossus_impact`). Its chest spills **soul-slurry**, which is *non-damaging* and cool white-violet, and it **flows uphill toward the Gate** as though pulled. The alarm stops. The rising slag reverses to −1.8 over 20 s, and the bell slows back to 14 s. Checkpoint `kiln_forecourt`. Objective `UNSEAL THE GREAT ASHEN GATE`.

| ID | Speaker | Line | Dur. |
| --- | --- | --- | --- |
| c3.cho.05 | THE HOLLOW CHOIR | "…key-maker… key-maker… key-maker…" (from the Gate) | 3.6 |
| c3.ser.38 | ARCHIVIST SERAPHINA | "It's over." | 1.4 |
| c3.ser.39 | ARCHIVIST SERAPHINA | *(2.0 s silence)* "...No. It's waiting for you." | 2.4 |

### 5.8 The Unsealing of the Great Ashen Gate (cliffhanger into Chapter IV)

**`ch3_kiln/hollow_choir`** (plan ID; existing trigger `hollow_choir` at (0, 1.45, −35)): plan beats `whisper_swell`, `choir_line`. The existing journal line becomes c3.cho.06. Seraphina climbs down from the gallery and walks to `S4_gate` beside the player.

**`ch3_kiln/great_gate_unseals`** (plan ID) [**AMENDS PLAN**: three turns instead of one valid use]. Interact the lock-plate (0, 1.5, −37.4) holding the key with the Ladle dead. Each turn is a separate `[E]` press, with a minimum of 2.5 s between turns so each beat lands. **The player may walk away between turns, and the Gate waits.** No input is ever locked.

| Turn | Hint | Beats | Lines |
| --- | --- | --- | --- |
| **I — MOON** | `TURN THE ASHEN KEY — MOON [E]` | `foley key_turn` + `iron_release`. Every vessel rack in the Kiln **dims one tier** as streams of pale light lift off them and flow through the air to the tympanum (**[NEW]** `name_stream`, racks → Gate, 4 s). | c3.cho.07 "…moon that saw it…" (2.4) |
| **II — CROWN** | `— CROWN [E]` | `foley key_turn`. The **Crown Vessel** keystone cracks with a gold light, and its `VAELOR` stamp becomes legible. The tympanum's carved face seems to inhale (the emissive brightens toward the mouth). | c3.cho.08 "…crown that willed it…" (2.4) · c3.ser.40 "...The King's name. In the keystone. He's in there with them." (3.8) |
| **III — SKULL** | `— SKULL [E]` | Plan: the leaves slide toward x ±8.5 at 2.8 m/s with `gate_grind`; `threshold_wind` as the seam widens (**[NEW]** `wind_force` toward −Z at 1.5 m/s², resistible, capped at 60% walk speed). Grey light floods the forecourt. **All Kiln ash and embers reverse and stream into the Gate.** | c3.cho.09 "…skull that paid it…" (2.4) |

**Beyond the leaves: the Hollow Beyond (vista geometry, z −43 … −400, non-colliding):**
- The threshold is a stone lip over an abyss. Ahead and *below* hangs the **Lower Ward of Vaelor, inverted**: rooftops pointing down from a ceiling of black water, lanterns burning upside-down.
- A **raft** drifts slowly *upward* toward a sea that is the sky. Its planks read HESK.
- Somewhere below, a bell tolls **underwater** (the `bell` cue, low-passed at 400 Hz).
- Grey-violet fog volume. A broken path of **floating paving stones** leads away into the dark: Chapter IV's first route (no collision in Act I).

| t (after the leaves clear) | Op | Choreography | Line |
| --- | --- | --- | --- |
| 3.0 | `voice` (ILSE, from beyond, solo) | — | c3.ils.03 "Sera? You came down." (2.6) |
| 5.8 | `voice`; `walk_to` seraphina `S4_gate` → `S5_edge` (speed 0.9) | She walks to the very edge, lantern raised, and stops | c3.ser.41 "Ilse...?" (1.6) |
| 9.0 | `voice` (`A VOICE BEYOND THE GATE`, `#F2DFA6`, `vo_chime_king`) | Every light in the Kiln dims to 30%. | c3.vae.01 "Lock-smith." (2.0) |
| 11.4 | `voice` | — | c3.vae.02 "You came back to finish your work. Good." (3.4) |
| 15.2 | `voice` | On the last word **every name-vessel in the Kiln goes dark at once**, followed by **total silence**: audio ducks to −40 dB for 1.5 s | c3.vae.03 "Come home, Caelen. The Choir needs its key." (3.8) |
| 20.5 | `commit` `act_complete` (plan) | Autosave. **Title lane, world live:** "END OF ACT I" (2.5 s) → `show_chapter("CHAPTER IV", "THE HOLLOW BEYOND", "To be continued")`. Then a non-modal line: `ACT I COMPLETE — [ESC] MENU`. **[AMENDS current `_win()`]**: no modal `ending_panel`, and the mouse is not released. | — |
| +30 s idle near Seraphina | `voice`, once each | She does not turn around | c3.ser.42 "She answered me. Did you hear? She answered." (3.2) · c3.ser.43 "Go on, then. I'll be right behind you. I promise." (3.4) |

### 5.9 Chapter III rosters & state

| ID | Kind | Position | Rule |
| --- | --- | --- | --- |
| kiln_ash_1 / kiln_crucible_exec | ash_sentinel / executioner | existing (hall) | Present; must be cleared before tempering |
| kiln_aq_shr / kiln_aq_walkway_shr_n / _s / kiln_aq_aco_1 | existing | existing | Present |
| kiln_smelt_rail_shr | shrieker | (18.9, 0, −2.0) | Present (cart-crush target) |
| kiln_smelt_ash / kiln_smelt_ash_east / kiln_smelt_stalker | existing | existing | **Dormant until `dam_break`** |
| colossus / kiln_meltdown_ash / kiln_meltdown_aco | existing | existing | `meltdown` |

**New state keys:** `rim_met`, `vessels_seen`, `ilse_heard`, `read_tithe_roll`, `seraphina_mark` (`"S1"…"S5"`), `smelt_awake`, `key_tempered_at` (float timestamp; key collectable after +22 s), `gate_turns` (0–3), `act_complete`. Existing keys are kept: `trough_flooded`, `aqueduct_powered`, `dam_broken`, `key_forged`, `gauntlet_triggered`, `dropped_cauldrons`, `colossus_dead`, `colossus_hp`, `great_gate_open` (true at `gate_turns == 3`).
**Checkpoints:** `arrival/ch3_kiln/kiln_from_tower` · `kiln_landing` · `kiln_aqueduct` · `kiln_smeltery` · `kiln_hall` · `kiln_forecourt`.

| Minute | Beat | Intensity |
| --- | --- | --- |
| 0–3 | Landing, helm, fresh pour, rim meeting, **the Revelation** | Silence → awe |
| 3–10 | Aqueduct: frozen workers, **Ilse sings**, the Tithe Roll, falls, valve | Medium; story peak |
| 10–16 | Smeltery: Ladle Crew, ash chute, **cart breach**, glyph cloud, sentinels wake | High |
| 16–19 | Hall clear, key pour and quench, **Seraphina's confession** | Quiet |
| 19–25 | **Meltdown and the Ladle** | Peak |
| 25–28 | **Three turns, the Hollow Beyond, the King's voice** | Awe → black silence |

---

## 6. Master Checklist: New Scripted Events, Art Assets & Audio Cues

Each row is one buildable unit. **Owner** suggests the module: `SD` = `story_director.gd` (plan), `LB` = `level_builder.gd`, `CH1/2/3` = chapter builders, `MAIN` = `main.gd`, `NAR` = `narrative.gd`, `AUD` = `audio_3d.gd`, `VIS` = `visuals.gd`, `M3D` = `meshes_3d.gd`, `AI` = `enemy_ai.gd`, `CS` = `combat_systems.gd`.

### 6.1 Engine primitives & opcodes (new or amended)

| # | Primitive | Spec | Owner | Used by |
| --- | --- | --- | --- | --- |
| E1 | **`await_look`** opcode | Args `target`, `cone_deg = 38`, `timeout = 3.5`. Resolves when the target's AABB centre is within the cone of camera −Z and has LOS, or on timeout. Never moves the camera. | SD | §3.3, §3.5, §3.8, §4.3, §5.3 |
| E2 | **`bark`** opcode + `say()` priority | Args `speaker`, `line`, `origin`, `ttl = 1.5`, `cooldown_per_speaker = 4`. Barks never queue; they drop if the bar is busy past `ttl`. Add `priority` (story > bark) to the `NarrativeSystem` queue entries. | NAR, SD | All combat whispers |
| E3 | **Speaker chime + voice-grain** | On `_pop_next()` with a speaker different from the last: play `vo_chime_<id>`. During the line: play `vo_grain_<id>` positionally from the speaker's origin (the NPC head, a tube, or an emitter), shaped to the syllable count (≈ chars/3). Voice-grain attenuates with distance; subtitles do not. | NAR, AUD | Every line |
| E4 | **`bell_toll`** opcode | Modes `lull` (cyan, soft, `bell` pitch 0.62), `inverted` (`bell_crack`, violet, optional `hollowing_motes` on listed actors), `local` (embedded bell). Args `emitter`, `period` (loop) or one-shot, `pulse_crack`, `pulse_vessels`. Exposes a `toll` signal (used by E15 and §3.7 staging). | SD, AUD | All chapters |
| E5 | **`fissure`** opcode / `LB.add_fissure(target, branches, grow_time, color)` | Generalise Ch II's `_add_foundry_fissures` into a reusable helper that grows emissive seams over time | LB, SD | §3.3.2 inner arch |
| E6 | **`ward_chain`** opcode | Segmented emissive chain mesh from A → B with a 0.4 s whip-out. Sub-ops `reanchor(to)` and `snap` (links fall as debris). Persistent registry `ward_id → chain`. Replaces `_update_ward_beams()` boss-only targeting: chains target the Belfry Seal until the boss spawns, then the boss. | SD, MAIN | §4.3, ward breaks |
| E7 | **`bell_drop`** opcode | The Great Bell visual becomes a RigidBody (no player damage; layer `LAYER_DEBRIS`, pushes the player). On floorboard contact → plan's `open_shaft` commit. Afterwards, tween it out of view down the shaft. | SD, CH2 | §4.7.1 |
| E8 | **`wind_force`** opcode | Args `dir`, `accel`, `duration`. Additive horizontal acceleration on the player, capped at 60% of walk speed. Never prevents walking against it. | MAIN, SD | §3.8, §5.8 |
| E9 | **`seal_ripple`** | Belfry Seal surface wobble + violet flash where an actor passes through it | SD, LB | §4.6.3 |
| E10 | **`hollowing_motes`** VFX | GPU particles: violet glyph motes rising from the actor's head and streaming toward a target direction (the Keep / the Gate). Args `actor`, `duration`, `target_dir`. | VIS | Torin, guard |
| E11 | **`name_ash_ribbon` / `name_stream` / `glyph_drift`** VFX | Ribbons of glyph particles along a bezier from A → B (`ribbon`/`stream`), or a free-floating glyph cloud (`drift`) | VIS | §3.8, §5.5, §5.6, §5.8 |
| E12 | **`emerge`** spawn arg on `_enemy()` | Args `depth = 1.6`, `rise_time = 1.2`, `fx = "splash" or "slag"`. The enemy is inactive until risen. | MAIN, AI | Cistern risen, Ladle |
| E13 | **NPC locomotion & poses** | Plan's `walk_to`, extended with speeds `limp = 1.3–1.6`, `walk = 1.0–1.4`, `run = 4.0–5.2`, `crawl = 0.6` and **cross-zone routes**. Poses / gestures: `lantern_wave`, `lantern_raise`, `clutch_head`, `kneel`, `stand`, `sit`, `crank`, `release_crank`, `winch`, `unlock`, `toll_handbell`, `rise`, `beckon`. | SD, M3D | All NPCs |
| E14 | **Speaking-tube system** | `register_tube(id, node)`. A line with `channel: "tube"` routes voice-grain to the nearest tube within 18 m, else waits up to 6 s, else plays 2D at −9 dB. The horn's mouth light pulses while it speaks. Speaker label suffix `— SPEAKING-TUBE`. | SD, AUD | Ch II, Ch III |
| E15 | **Unpick verb** | Hold `[E]` 1.0 s on nodes with meta `unpick: true`. Reticle shows 3 tumbler ticks with rising clicks, then the `lever` cue. Sets `<lock_id>_unpicked`. | MAIN | Sluice, Ossuary Gate, gearbox seat, lift pawl housing, chime frame, Gate lock-plate |
| E16 | **Moving inscriptions** | `_inscription()` accepts a `parent: Node3D`. Proximity uses the node's global position each frame. | MAIN | Hesk planks, mold tag |
| E17 | **Staged portcullis siege** | Replace Ch I's instant `gate_open` with `siege_stage` 0–3, rising on `bell_toll` signals. Holds when a plate unweights and never drops. Plan's teeth and aperture-clear rules are kept. | MAIN, CH1 | §3.7 |
| E18 | **Toll shatters frost** | On siege Toll II: `water_channels[*].frozen_timer = 0` with an ice-break VFX and the `frost` cue at pitch 0.7 | MAIN | §3.7 |
| E19 | **Hydraulic precondition** | Gearbox requires `cistern_raised`, hint `HYDRAULIC RAM DRY — RAISE THE CISTERN SLUICE` | MAIN | §3.7 |
| E20 | **Key tempering timeline** | Replaces the instant forge in `_use()`: pour → quench → 22 s cool → collectable. Key pickup still calls `_trigger_kiln_meltdown()`. | MAIN, CH3 | §5.6 |
| E21 | **Three-turn Gate + live ending** | Replace the immediate `_win()` with `gate_turns` 0–3, each turn a beat, then `act_complete`: title-lane card, world live, no modal and no mouse release | MAIN, NAR | §5.8 |
| E22 | **Colossus toll-gated wave + chest weakpoint** | `tolling_wave` is selectable only within 0.6 s after a `bell_toll` signal. The chest (upper-front 40% of the capsule) takes ×1.5 damage after overdrive. Name barks rate-limited to 1 per 4 s. | AI, CS | §5.7 |
| E23 | **Ore-cart impact damage** | Contact with an enemy at > 6 m/s deals 120 damage plus stagger | MAIN | §5.5 |
| E24 | **Dormant enemies** | `_enemy(..., dormant = true)` stays inactive (statue pose, no AI) until a commit wakes it | MAIN, AI | Smeltery sentinels |
| E25 | **Shared far-landmark builder** | `LB.add_far_landmarks(game, frame_offset: Vector3)` builds the Keep, Yoke, Bell, Kiln stacks, Upper City lights and drowned ward per §3.2.1 in any chapter frame (Ch I offset 0; Ch II `(0, 0, +77)`; Ch III `(0, +60, +143.6)`, where the Keep is overhead and only the stacks, the drop throat and the Upper City glow are visible). The bell's emissive crack is driven by E4. | LB | All chapters |
| E26 | **Chapter-local wet zone toggle** | `LB.add_wet_zone` callable at runtime (Belfry Phase II rain) | LB | §4.7 |

### 6.2 Sequence registry

| Chapter | Sequence ID | Trigger | Notes |
| --- | --- | --- | --- |
| I | `ch1_court/coldopen_arrival` | First mount | Lull loop, card, Torin's lantern |
| I | `ch1_court/torin_hail` | Volume or 20 s | — |
| I | `ch1_court/gatehouse_meeting` | Volume or 35 s after hail | **AMENDS PLAN**: no bar lift |
| I | `ch1_court/gatehouse_fracture` | "Two…" + 3.1 s | Collapse precondition (§3.3.2) |
| I | `ch1_court/gatehouse_aftermath` | Cold-open shriekers dead or 40 s | — |
| I | `ch1_court/torin_camp` | Proximity 4 m | — |
| I | `ch1_court/cloister_breach` | After the camp lines or z < 20.5 | — |
| I | `ch1_court/torin_rhyme` | Proximity 6 m, after the breach | — |
| I | `ch1_court/cistern_arrival` | Quay volume | — |
| I | `ch1_court/hesk_planks` | Raft proximity while Seraphina is present | — |
| I | `ch1_court/cistern_sluice` | Lever (after Unpick) | Plan ID, extended |
| I | `ch1_court/ossuary_blackout` | Crank pickup | Plan ID, positions refined |
| I | `ch1_court/torin_relocates` | Crank pickup | Cross-zone walk |
| I | `ch1_court/north_portcullis` | Crank + plates + cistern | **AMENDS PLAN**: three-toll siege |
| I | `ch1_court/torin_hollows` | `clear_exit` | — |
| I | `ch1_court/viaduct_toll` | z < −24 | Plan ID, extended |
| I | `ch1_court/keep_doors` | z < −38 | — |
| II | `ch2_tower/arrival` | Transition arrival | — |
| II | `ch2_tower/vestibule_doors` | z < 29 | — |
| II | `ch2_tower/malcor_balcony` | Nave volume (z 18) | Includes the plan's `nave_chandelier` beats |
| II | `ch2_tower/nave_wake` | Malcor out of sight + 1.5 s | — |
| II | `ch2_tower/tube_intro` | `nave_wake` cleared or 25 s | — |
| II | `ch2_tower/tube_west` / `tube_east` | Wing entry volumes | — |
| II | `ch2_tower/ward_1_broken` / `ward_2_broken` / `ward_3_broken` | `_shatter_ward` | Malcor memory-loss lines |
| II | `ch2_tower/lift_ambush` | Lift jam | — |
| II | `ch2_tower/choir_departure` | Proximity 7 m + loft clear | Plan ID; walk replaces vanish |
| II | `ch2_tower/belfry_awakens` | `belfry_sanctum` trigger | Plan ID |
| II | `ch2_tower/warden_phase_two` | HP ≤ 260 commit | Plan ID + storm |
| II | `ch2_tower/belfry_shaft` | Warden death | Plan ID + confession + `bell_drop` |
| III | `ch3_kiln/arrival` | Transition arrival | — |
| III | `ch3_kiln/rim_meeting` | Proximity 7 m or 12 s | — |
| III | `ch3_kiln/the_vessels` | Rail volume or 20 s | — |
| III | `ch3_kiln/torin_vessel` | Look at the TORIN vessel | Optional |
| III | `ch3_kiln/rim_brief` | After `the_vessels` | — |
| III | `ch3_kiln/tube_aqueduct` / `tube_smeltery` | Stair-foot volumes | — |
| III | `ch3_kiln/ilse_sings` | Proximity 4.5 m | — |
| III | `ch3_kiln/tithe_roll_warning` | Valve-deck volume | — |
| III | `ch3_kiln/aqueduct_surge` | Valve | Plan ID |
| III | `ch3_kiln/dam_break` | Cart impact | Plan ID + sentinels wake |
| III | `ch3_kiln/seraphina_descends` | Trough + dam flags | — |
| III | `ch3_kiln/key_tempering` | Hoist lever | Replaces the instant forge |
| III | `ch3_kiln/meltdown` | Key pickup | Plan ID, re-scripted |
| III | `ch3_kiln/colossus_overdrive` | HP ≤ 320 | Plan ID |
| III | `ch3_kiln/colossus_falls` | Ladle death | Plan ID |
| III | `ch3_kiln/hollow_choir` | Existing trigger | Plan ID |
| III | `ch3_kiln/great_gate_unseals` | Three key turns | **AMENDS PLAN** |

### 6.3 Trigger & story volumes (centre / size, chapter-local)

| ID | Centre | Size | Chapter |
| --- | --- | --- | --- |
| `torin_hail` | (0, 1.5, 47.0) | (11.6, 4, 2) | I |
| `gatehouse_meeting` (existing ID, moved) | (0, 1.4, 33.6) | (7.6, 2.8, 3.6) | I |
| `cloister_breach_line` | (−1.5, 1.5, 20.5) | (20, 3, 1) | I |
| `cistern_arrival` | (−11, 1.5, 2) | (3, 3, 18) | I |
| `court_causeway_toll` (replaces `court_exit_bell`) | (0, 1.5, −24) | (11, 4, 2) | I |
| `keep_doors` | (0, 1.5, −38) | (11, 4, 2) | I |
| `malcor_balcony` | (0, 1.5, 18.0) | (14, 3, 2.5) | II |
| `vestibule_doors` | (0, 1.5, 28.5) | (8, 3, 1) | II |
| `tube_west` / `tube_east` | (−16, 1.5, 2.4) / (16, 1.5, 5) | (3, 3, 7) | II |
| `belfry_sanctum` (existing) | (0, 10.9, −33.2) | (7, 3.8, 3.2) | II |
| `rim_rail` | (0, 7.5, 15.0) | (20, 3, 2) | III |
| `aq_stair_foot` / `smelt_stair_foot` | (−16.5, 1.5, 14.0) / (16.5, 1.5, 14.0) | (4, 3, 3) | III |
| `valve_deck` | (−24, 4.5, −8.5) | (8, 3, 9) | III |
| `hollow_choir` (existing) | (0, 1.45, −35) | (7.6, 3.2, 3.1) | III |
| Transitions (plan) | `court_to_tower` plane z −44 · `tower_to_court` vestibule doors · `tower_to_kiln` shaft y ≈ 8.3 · `kiln_to_tower` Archive Stair | — | I–III |

### 6.4 Actors, rigs & marks

| Actor | Rig | Status | Notes |
| --- | --- | --- | --- |
| **Brother Torin** | `torin` | **[NEW]** NPC rig (Bell-Watch surcoat, side wound, lantern socket, helmet prop) | Hollowing stages 0–4 (§2.3); amber accent light (energy 1.8 → 0.3) |
| **Bell-Watch guard (W. Ware)** | `bellwatch_guard` | **[NEW]** (Torin variant, no wound, open helm) | Sprint anim; spectral clear path (no collision) |
| **Archivist Seraphina** | `seraphina` | Existing sprite rig | **[NEW]** gestures: unlock, winch, beckon, lantern raise. Marks are listed per chapter (S1–S5 in Ch III). |
| **Lord Malcor (live)** | `malcor_live` | Existing | **[NEW]** gestures: toll_handbell, rise, walk, crawl. `malcor_dying` = same rig, kneel/crawl poses, smoke VFX. |
| **Seated / fallen corpses** | Plan `add_fallen_guard` variants `seated`, `artificer`, `acolyte_scorched`, `collared_skeleton`, `frozen_worker` | **[NEW]** variants | Watchmen's Rest ×6, Pell, acolytes ×3, Ladle Crew ×5, Quench-Masters ×4 |
| **Ilse** | No rig (vessel emitter) | — | The voice comes from `ilse_vessel`, then from beyond the Gate |
| **The King** | No rig | — | The voice comes from the Crown Vessel (0, 22.5, −38.2) |
| **Choir emitters** | Positional `AudioStreamPlayer3D` nodes | **[NEW]** | Ch I: chasm (0, −8, −30), cloister walls. Ch II: loft walls, shaft (0, 2, −42). Ch III: each vessel rack, the Gate. |

### 6.5 Art assets

**Props & set dressing**

| Asset | Chapter | Spec |
| --- | --- | --- |
| Approach stair + low parapets | I | Stone, 7 m wide, y 6 → 0 |
| Gatehouse outer-arch fracture assembly | I | Keystone + 8 voussoirs, settled rubble wall |
| Guard's lantern ("W.W." engraved) | I | RigidBody, persistent OmniLight |
| Cell interior: desk, ledgers, writ | I | Small set |
| Breakable stained glass ×3 | I | Shard burst + sill |
| Camp kit (bedroll, helmet, bowl, whetstone) | I | — |
| Quay of Bundles (14 bundles, birdcage, doll, 3 shoe pairs, row-number floor paint, tally wall) | I | Decals + small meshes |
| Hesk raft chalk planks | I | Decal on the raft deck |
| Sluice padlock & chain (Key-and-Fork mark) | I | — |
| Shrine of the Drowned Mother statue | I | Replaces the plain altar |
| Watch Walk post: racks, stool, brazier, "3,011?" scratch decal | I | — |
| Watchmen's Rest ring + halberd teepee + dead lantern | I | — |
| Tithe Notice Wall (9 notices + tar scrawl + child handprints) | I | Framed quads + decals |
| Gouged-bars decals + sill grooves + small shoes | I | — |
| North Gallery ledge + archive doors | I | NPC-only |
| Keep South Facade, doors, vestibule | I/II | Matching on both sides of the seam |
| Far landmarks (§3.2.1) | All | E25 |
| Nave chandelier (iron ring, 12 flames) | II | Falls (plan `chandelier_drop`) |
| Flanking stair upper-flight fracture assemblies | II | Rubble stumps |
| Speaking tubes ×5 (II) + ×3 (III) | II/III | Brass horn + mouth light |
| Moon-Clock dial | II | r 2.5, stopped hands |
| Pell's workbench dressing, slate with chalk diagram | II | Unique texture |
| Bell molds ×2, cracked Sister Bell, bronze spill decal | II | — |
| Founders' Offering table, 5 ash-bowls + tags | II | — |
| Vigil Altar: cot, sash, 40 loaves (rot gradient), tally pillar, name-spiral decal | II | The spiral is a unique decal texture |
| Crown Yoke + Great Bell (cracked emissive) + tether chains | II | Bell r 2.8 h 4.4 |
| Malcor's helm | III | Pickup-less interactable |
| Drop throat, ash heap, broken grate | III | — |
| Fresh-pour rack + auto-pour chute + filling mold | III | Animated glyph reveal |
| Name-vessel (base mesh) + MultiMesh racks + 24 Label3D names | III | ~1,000 instances visible; LOD as needed |
| Embedded Great Bell + rubble | III | Solid collider |
| West Rim Stair, East Gantry Stair, Pour Stair (crushed) | III | — |
| Frozen workers ×4, Ilse's half-poured vessel, Tithe Roll lectern | III | — |
| Ash chute, Ladle Crew, dormant sentinel alcoves | III | — |
| Crucible spout + pour stream | III | — |
| Forecourt S3 gallery + NPC ladder | III | — |
| Gate tympanum (King's face) + name-grid + Crown Vessel + lock-plate | III | Tympanum 24 × 14 m, non-colliding |
| Hollow Beyond vista (inverted ward, raft, floating stones) | III | Matte geometry and fog |

**Materials / shaders [NEW]**: `soul` (pale violet-white emissive, scrolling UV, pulse uniform) · `name_ash` (cinder with glyph emissive mask) · `ice_shell` (translucent refractive-ish rim) · `bell_crack` strip (emissive with pulse uniform driven by E4) · `frost_rime` wall overlay · `name_grid` (tympanum, 3,011-point scroll with sweep uniform).

**VFX [NEW]**: `hollowing_motes` · `name_ash_ribbon` · `name_stream` · `glyph_drift` · `pour_stream` · `slag_cascade` · `seal_ripple` · storm rain + lightning flash light (Belfry) · ice-shatter (siege Toll II) · glass-burst shards.

**Decals [NEW]** (plan: surface-oriented, persistent): blood trail under the arch rubble · fingernail gouges · child handprints · tar scrawl · chalk row numbers · Hesk planks · "3,011?" scratch · name spiral · Seraphina's ash footprints · lightning scorch radial (Pell).

**UI**: speaker label suffixes (`— SPEAKING-TUBE`, `— ECHO`) · Unpick tumbler ticks on the reticle · title-lane "END OF ACT I" · non-modal completion line.

### 6.6 Audio cues

All cues are new **synth** cases in `audio_3d.gd` (`SYNTH_LENGTHS` + `_sample`) unless marked WAV. Recipes are starting points.

| Cue | Len (s) | Recipe | Used by |
| --- | --- | --- | --- |
| `bell_crack` | 2.60 | The `bell` partials (inharmonic 1 : 2.4 : 3.9 : 5.4) with a −40-cent pitch droop over 0.4 s, plus a noise burst through a 2.2 kHz resonant band at t 0, plus a glassy 3.1 kHz ring decaying at e^−3t, with exp(−1.1t) on the whole | Fracture, inverted tolls, embedded bell |
| `resonance_wave` | 1.80 | Sub sweep 42 → 18 Hz plus a shimmer of detuned 880/890 Hz beating, swelling then falling | Every `resonance` op |
| `rubble` | 1.40 | 6 randomised low-noise bursts (lowpass ~300 Hz), staggered 0–0.9 s | Arch collapse, stair collapse |
| `glass_burst` | 0.90 | High noise (> 3 kHz) transient plus 8 random sine tinkles 2–6 kHz | Cloister windows |
| `door_groan` / `door_slam` | 2.0 / 0.8 | Low-pass sawtooth 60 → 48 Hz with friction noise / a thump plus a wood knock | Keep doors |
| `wind_gust` | 3.0 | Band-passed noise sweeping 300 → 900 → 400 Hz | Causeway, Gate threshold |
| `thunder_far` | 3.5 | Low noise with slow amplitude envelopes, lowpass 200 Hz | Belfry storm |
| `chain_strain` / `chain_snap` | 1.2 / 0.6 | Fast metallic clicks at 1.7 kHz in a rising cadence / a sharp ring plus a link scatter | Chandelier, bell drop |
| `timber_groan` | 1.6 | Low creak: FM 80 Hz carrier with 3 Hz modulation | Floorboards |
| `impact_deep` | 2.4 | 30 Hz thump plus a long reverb tail; Furnace bus | Bell landing in the Kiln |
| `gear_grind` | 1.0 | Square 24 Hz with noise grit | Lift jam |
| `hollow_rise` | 1.1 | Bone scrape (noise through a 1.2 kHz comb) plus a reversed breath | Ossuary, emerge |
| `steam_ram` | 1.5 | Noise hiss with a pressure envelope | Portcullis hydraulic |
| `quench_hiss` | 2.2 | Bright noise with a fast attack and long decay, plus bubbling (`splash` bubbles) | Key quench |
| `key_turn` / `iron_release` | 0.5 / 1.6 | Three tumbler clicks plus a deep bolt / a 40 Hz clunk with metallic ring | Gate turns, Unpick |
| `gate_grind` | 4.0 | Low sawtooth 35 Hz, friction noise, irregular judder | Gate leaves |
| `slag_surge` | 2.0 | Thick low noise with blub transients | Meltdown cascade |
| `vo_chime_seraphina` | 0.35 | Glass bell A5 plus a 0.12 s quill scratch (high noise through a 5 kHz BP) | Speaker change |
| `vo_chime_torin` | 0.30 | Mail rattle (granular noise) plus a soft creak | Speaker change |
| `vo_chime_malcor` | 1.40 | Bronze hum F2 (87 Hz + partials) plus a breath | Speaker change |
| `vo_choir_breath` | 0.90 | Reversed swell of 3 sines on a minor-second cluster (around 330 Hz), formant-filtered | Choir lines |
| `vo_chime_echo` | 0.60 | The `portal` cue pitched ×1.35 with a crystalline shimmer (existing echo sound, formalised) | Echoes |
| `vo_chime_king` | 2.00 | All bell cues summed and pitched −12 semitones, then a hard cut to silence at 1.6 s | The King's lines |
| `vo_grain_<speaker>` | Generated per line | Formant-filtered noise bursts per syllable; formants and rate per §2 (Seraphina 820/1650 Hz, 6.5/s; Torin 600/1150 Hz; Malcor 420/900 Hz, 3.5/s; Choir 6 detuned voices) | Every line |
| `tube` filter | — | Comb (6 ms) plus BP 300–3000 Hz on voice-grain | Speaking tubes |
| Underwater bell | — | Existing `bell` through a 400 Hz LPF on a bus | Hollow Beyond |

**Ambient beds** (plan's chapter stems): **Ch I**: rain, wind, distant Lull until the fracture, then irregular inverted tolls every 45–70 s outside scripted ones · **Ch II**: candle-hush interior, rain on stained glass, a storm build in the belfry · **Ch III**: furnace roar, slag bubbling, the embedded bell at 14 s / 6 s, choir drone rising with proximity to vessel racks.

### 6.7 Text assets

**Inscriptions (new or rewritten):**
- **Ch I**: THE EMERGENCY WRIT · SHRINE OF THE DROWNED MOTHER · THE KING'S EDICT (rewritten) · WATCH WALK ORDERS · KEEPER AVUN (replaces THE OSSUARY KEEPER) · THE TITHE NOTICE · PORTCULLIS HYDRAULIC (replaces THE COURT SEALS) · THE BELL CAUSEWAY · HESK planks (moving).
- **Ch II**: THE MOON-CLOCK · THE FOUNDERS' OFFERING · THE GREAT BELL OF VAELOR · THE TITHE CHIMES (replaces WARD III — HARMONIC CHIMES).
- **Ch III**: THE AQUEDUCT OF THE QUENCH (replaces THE AQUEDUCT VALVE) · THE TITHE ROLL · SMELTERY ROTA · THE ASHEN KEY (mold tag, moving).

**Memory Echoes:**
- **Ch I**: `echo_seraphina_cell` · `echo_quay_mother` · `echo_watch_captain` · `echo_portcullis_child`
- **Ch II**: `echo_pell_bench` · `echo_pell_drum` · `echo_seraphina_loft` (secret)
- **Ch III**: `echo_quenchmaster`

**Relic flavour (IDs unchanged):** Heart of Vaelor (§3.5) · Siphon Signet = Pell's signet (§4.4) · Cinder-Breaker's Oath = Quench-Masters' Oath (§5.4).

**Pickup messages:** Arbalest · Fork (Pell) · Thurible (procession) · Gearbox Crank (renamed Iron Lever) · Ashen Key.

**Interact hints:** every hint listed in §3–§5. The tutorial verbs (keys) live in hints, never in story plaques.

**Journal:** each sequence with a story beat writes one `_story_event` entry through the plan's stable-ID bridge (title = sequence headline, body = the lines spoken). Inscriptions and echoes already journal through existing paths.

### 6.8 Registry metadata & state summary

| Chapter | `subtitle` | `default_spawn` | `map_bounds` | New state keys |
| --- | --- | --- | --- | --- |
| `ch1_court` | The Night the Bell Cracked | (0, 6.1, 61.0) | Rect2(−32, −50, 64, 113) | §3.9 |
| `ch2_tower` | The Three Tolls of Malcor | (0, 0.1, 33) | Rect2(−35, −57, 70, 93) | §4.8 |
| `ch3_kiln` | Where Names Become Iron | (0, 6.1, 24.6) | Rect2(−33, −43, 66, 70) | §5.9 |

Save schema: extend the plan's normalisation for the new keys, with safe defaults (all `false` / `0` / `""`). **Legacy saves**: a save with `gate_open = true` in Ch I implies `siege_stage = 3` and `torin_hollowed = true`. `boss_dead = true` in Ch II implies `bell_fallen = true`. `great_gate_open = true` in Ch III implies `gate_turns = 3`.

### 6.9 Removals & replacements in the current code

| Remove / replace | Where | With |
| --- | --- | --- |
| All `_portal()` calls (Court → Tower, Tower → Court, Tower belfry → Kiln, Kiln → Tower) | CH1/2/3 | Plan transition zones (§3.8, §4.3, §4.7.1, §5.2) |
| Fake close-up bell tower at z −36 | CH1 `_north_viaduct` | Keep facade at z −42 + far landmarks |
| `gatehouse_meeting` bar-open callback | CH1 `_gatehouse` | `gatehouse_fracture` `lift_bar` beat |
| Seraphina's 3 gatehouse lines; Malcor's 3 loft lines; Seraphina's 3 kiln lines | `_npc()` calls | The sequences in §3.3, §4.6.3, §5.3 |
| Instant gate open on plates + lever | MAIN `_update_puzzles` | E17 staged siege |
| `_ascend_malcor()` instant vanish | MAIN | `walk_to` + `seal_ripple` |
| Wards-empty line "My wards are broken! …" | MAIN `_shatter_ward` | c2.mal.13 |
| Phase II banner "REFLECT SONIC ORBS!" | AI `_update_warden_phase` | `PHASE II — REFLECT HIS TOLLS` (single-owner event per plan) |
| Instant key forge in `_use()` | MAIN | E20 tempering |
| Meltdown `say()` line and banner | MAIN `_trigger_kiln_meltdown` | c3.ser.30 + `MELTDOWN — THE LADLE WAKES` |
| `_win()` modal ending panel | MAIN | E21 live ending |
| `court_exit_bell` trigger | CH1 | `ch1_court/viaduct_toll` |
| Tutorial inscriptions (FALLEN CAMP, CISTERN SLUICE, OSSUARY KEEPER, COURT SEALS, WARDEN'S OATH, LIFT POWER, WARD I, WARD II, AQUEDUCT VALVE, SLAG DAM, KILN OF ASH) | CH1/2/3 | Interact hints, NPC lines and new plaques |
| `court_cloister_shr_2`, `tower_choir_aco` | CH1/CH2 | Breach trio; removed (calm loft) |

### 6.10 Acceptance checks (automatable in `tests/smoke.gd` where marked ⚙)

1. ⚙ **No camera ownership**: during every sequence in §6.2, `camera.global_transform` changes only through player input and additive shake ≤ 0.12 m.
2. ⚙ **No input lock**: the player can move and attack at every beat of every sequence.
3. ⚙ **Collapse safety**: `outer_arch_collapse`, the flanking stair collapse and `bell_drop` never overlap the player capsule at commit, or they hold or skip per §3.3.2 and §4.7.1.
4. ⚙ **Route coherence**: each transition arrives on a supported floor, outside every live trigger, facing −Z (plan §Physical routes).
5. ⚙ **Siege hold**: unweighting a plate mid-stage halts the rise, and the gate never descends.
6. ⚙ **Tempering**: the key is not collectable before 22 s, and the meltdown fires exactly once on pickup.
7. ⚙ **Gate turns**: three distinct presses ≥ 2.5 s apart are needed. `great_gate_open` is set only at turn 3, and `act_complete` autosaves.
8. ⚙ **Branch lines**: the c3.ser.24a/b/c and 26a/b variants select correctly from `read_tithe_roll`, `read_hesk_planks` and `ilse_heard`.
9. ⚙ **Bark discipline**: a bark never delays a queued story line by more than 0 s, and stale barks drop after 1.5 s.
10. **Manual: the three truths.** A playtester who reads *no* plaques, echoes or journals can still answer after the Act: *"What happened to the Lower Ward?"*, *"What did Caelen do?"*, *"What is the Gate made of, and who chose them?"*
11. **Manual: look-gates.** The bell flare, Malcor's balcony, the chandelier and the vessel revelation are each seen by more than 90% of first-time testers.
12. **Manual: Torin.** Testers describe Torin's last line unprompted. If they do not, the beat needs more space.

### 6.11 Suggested build order

1. **Seams first.** Transition zones, matching vestibules, far landmarks (E25), and removal of portals. The Act becomes one physical world.
2. **Story spine.** E1–E4, E13, E14 (look-gate, barks, voice, tolls, NPC locomotion, tubes), then the dialogue sequences with placeholder geometry.
3. **Set-pieces.** Cold-open (E5, collapse), siege (E17–E19), balcony and chains (E6), belfry collapse (E7), tempering and Gate (E20, E21), Ladle (E22).
4. **Tableaux & text.** Props, decals, inscriptions, echoes.
5. **Audio pass.** Every §6.6 cue, then chapter beds and voice-grain tuning.
6. **Polish.** VFX (E10, E11), storm, the Hollow Beyond vista, acceptance checks.

---

*One for the moon that saw it. One for the crown that willed it. One for the skull that paid it. Chapter IV — The Hollow Beyond.*
