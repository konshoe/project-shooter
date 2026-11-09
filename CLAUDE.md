# Project Shooter — CLAUDE.md

This file is read by Claude Code at the start of every session.
Do not delete or rename it.

---

## What This Project Is

A vertical-scrolling (top-down) shoot-em-up for **iOS, Android, and browser (WebGL/HTML5)**.
A fighter plane at the bottom of the screen fires upward through waves of enemies.
3D models rendered via Godot 4's orthographic camera on a 2D-scrolling battlefield — no full 3D camera movement.

**One-person team. Solo developer.**

---

## Hard Constraints

| Constraint | Value |
|---|---|
| Asset memory budget | ≤200MB total |
| Target framerate | 60fps on mobile, 30fps minimum on browser |
| Offline play | Required — no network dependency for core gameplay |
| Controls | Touch-first; keyboard/mouse secondary for browser |
| Web bundle size | Target <10MB initial load; assets streamed after |
| Monetisation | Cosmetic IAP only — no pay-to-win power gates |

---

## Engine & Platform

- **Engine:** Godot 4 (GDScript)
- **Renderer:** Mobile (GLES3 compatible) for performance; Forward+ only if forced
- **Camera:** Orthographic, top-down, fixed Z — do not add free camera movement
- **Exports:** Web (HTML5/WebGL), iOS, Android
- **Version control:** Git / GitHub (`konshoe/project-shooter`, public repo)

---

## Project Folder Structure

```
project-shooter/
├── CLAUDE.md                  ← you are here
├── project.godot
├── export_presets.cfg
│
├── scenes/
│   ├── game/
│   │   ├── GameWorld.tscn      ← root scene; loads Level + HUD
│   │   └── GameCamera.tscn     ← orthographic camera node
│   ├── player/
│   │   ├── Player.tscn
│   │   └── PlayerBullet.tscn
│   ├── enemies/
│   │   ├── EnemyBase.tscn      ← base scene; all enemies inherit
│   │   ├── EnemyFighter.tscn
│   │   ├── EnemyBomber.tscn
│   │   └── bosses/
│   │       └── BossAlpha.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── MainMenu.tscn
│   │   ├── PauseMenu.tscn
│   │   ├── UpgradePicker.tscn
│   │   └── GameOver.tscn
│   └── levels/
│       ├── Level01.tscn
│       └── Level02.tscn
│
├── scripts/
│   ├── autoloads/
│   │   ├── GameState.gd        ← singleton: score, lives, run state
│   │   ├── AudioManager.gd     ← singleton: SFX + music bus
│   │   └── UpgradeManager.gd   ← singleton: active power-ups for current run
│   ├── player/
│   │   ├── Player.gd
│   │   └── BulletPool.gd       ← object pool; never instantiate bullets at runtime
│   ├── enemies/
│   │   ├── EnemyBase.gd
│   │   ├── EnemyFighter.gd
│   │   ├── EnemyBomber.gd
│   │   └── bosses/
│   │       └── BossAlpha.gd
│   ├── systems/
│   │   ├── WaveSpawner.gd      ← reads wave configs, spawns enemies
│   │   ├── ScrollingBackground.gd
│   │   ├── CollisionHandler.gd
│   │   └── UpgradePicker.gd
│   └── ui/
│       ├── HUD.gd
│       └── UpgradeCard.gd
│
├── resources/
│   ├── waves/                  ← JSON wave configs (see schema below)
│   │   ├── level01_wave01.json
│   │   └── level01_boss.json
│   ├── upgrades/
│   │   └── upgrade_pool.json   ← all possible upgrade definitions
│   └── levels/
│       └── level_manifest.json ← ordered list of levels + unlock conditions
│
├── assets/
│   ├── models/                 ← GLTF/GLB; max 500KB per model
│   │   ├── player_ship.glb
│   │   ├── enemy_fighter.glb
│   │   └── bosses/
│   ├── textures/               ← ETC2/ASTC compressed; max 512×512 units, 1024×1024 bosses
│   ├── audio/
│   │   ├── sfx/                ← OGG; short clips loaded in memory
│   │   └── music/              ← OGG; streamed, not preloaded
│   └── ui/
│       └── icons/
│
└── tests/
    └── unit/                   ← GdUnit4 test scripts (optional but preferred for systems)
```

---

## Autoloads (Singletons)

These are registered in Project Settings → Autoload.
**Do not duplicate their responsibilities in scene scripts.**

| Singleton | File | Responsibility |
|---|---|---|
| `GameState` | `scripts/autoloads/GameState.gd` | Score, lives, current level index, run-start/end |
| `AudioManager` | `scripts/autoloads/AudioManager.gd` | Play SFX by key, crossfade music, respect mute setting |
| `UpgradeManager` | `scripts/autoloads/UpgradeManager.gd` | Store active upgrades for the current run; apply stat modifiers |

---

## Key Systems

### WaveSpawner

- Reads a JSON wave config file at level load
- Spawns enemies at the positions and timings defined in the config
- Emits `wave_complete` signal when all enemies in a wave are dead or off-screen
- Emits `level_complete` signal when all waves in a level are done
- Does **not** know about the player directly — communicates via signals

### BulletPool

- Pre-allocates a fixed pool of `PlayerBullet` nodes at scene start
- `fire(position, direction, speed)` checks out a bullet; bullet calls `return_to_pool()` on exit or collision
- Never use `instantiate()` for bullets at runtime — this causes frame drops on mobile

### UpgradePicker

- Triggered by `wave_complete` signal from WaveSpawner (every N waves, configurable)
- Draws 3 random upgrades from `upgrade_pool.json`, excluding already-maxed upgrades
- Player picks one; `UpgradeManager` applies it
- Upgrade effects are stat multipliers or flag toggles — no bespoke code per upgrade

---

## Wave Config Schema

Wave configs live in `resources/waves/` as JSON.

```json
{
  "wave_id": "level01_wave02",
  "enemies": [
    {
      "type": "EnemyFighter",
      "count": 4,
      "formation": "V",
      "spawn_x_center": 0.5,
      "spawn_y": -0.05,
      "speed": 120,
      "delay_between": 0.4
    }
  ],
  "duration_limit_sec": 30,
  "is_boss_wave": false
}
```

`spawn_x_center` and `spawn_y` are viewport fractions (0.0–1.0).
`formation` values: `"V"`, `"line"`, `"grid"`, `"random"`.

---

## Upgrade Pool Schema

`resources/upgrades/upgrade_pool.json`

```json
[
  {
    "id": "fire_rate_up",
    "label": "Rapid Fire",
    "description": "Increases fire rate by 25%.",
    "icon": "res://assets/ui/icons/fire_rate.png",
    "stat": "fire_rate_multiplier",
    "delta": 0.25,
    "max_stacks": 3
  }
]
```

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Scene files | PascalCase + `.tscn` | `EnemyBomber.tscn` |
| Script files | PascalCase + `.gd` | `WaveSpawner.gd` |
| JSON configs | snake_case | `level01_wave02.json` |
| Signals | snake_case verb phrase | `wave_complete`, `player_died` |
| Constants | UPPER_SNAKE | `MAX_BULLETS = 64` |
| Variables | snake_case | `fire_rate_multiplier` |
| Node names in scene | PascalCase | `BulletPool`, `EnemySpawnPoint` |

---

## Physics & Collision Layers

| Layer | Number | Used by |
|---|---|---|
| Player | 1 | Player node |
| PlayerBullet | 2 | Bullets fired by player |
| Enemy | 3 | All enemy nodes |
| EnemyBullet | 4 | Bullets fired by enemies |
| Pickup | 5 | Power-up drops |

Collision matrix: PlayerBullet hits Enemy only. EnemyBullet hits Player only. No layer-vs-same-layer collision.

---

## Performance Rules

1. **Object pools for all bullets** — see BulletPool above
2. **Baked lighting on environment/background** — real-time lights only on player and enemies
3. **Texture compression:** ETC2 for Android, ASTC for iOS, S3TC for desktop/web — configure in Godot import settings
4. **Audio:** music files must be set to **Stream** in import settings; SFX set to **Load** (in-memory)
5. **No `_process()` on inactive nodes** — disable processing when an enemy is pooled or off-screen
6. **Viewport scaling:** use `Stretch Mode = canvas_items`, `Aspect = keep` — do not change this

---

## Platform-Specific Notes

### Browser (WebGL)
- Use `OS.get_name() == "Web"` to detect and adjust LOD or effect quality
- Disable shadow casting on all meshes in the web export profile
- Audio requires a user gesture before playback — HUD play button initialises AudioManager

### Mobile (iOS/Android)
- Touch input handled via `InputEventScreenTouch` and `InputEventScreenDrag`
- The player ship follows the drag position, clamped to the bottom third of the viewport
- Haptic feedback: `Input.vibrate_handheld(50)` on player death only — not on bullet fire

### Browser Controls
- Ship follows mouse cursor position (not click-to-move)
- Keyboard WASD/arrows as secondary input
- Same movement code path as mobile touch drag

---

## GameState Tracks (Phase 1 scope)

- Current score
- High score (saved to disk)
- Combo counter
- Combo timer
- Medal thresholds (bronze/silver/gold/platinum)
- Lives

---

## Replayability Model (Phase 1)

- Personal best / local high score
- Score medals per level
- Instant restart
- Combo multiplier
- No roguelike upgrade system in Phase 1 or 2 — UpgradeManager/UpgradePicker deferred to Phase 3

---

## What Claude Should Not Do

- Do not add network calls to the core gameplay loop — offline play is required
- Do not use `instantiate()` for bullets or frequently spawned objects at runtime
- Do not introduce a third-party plugin without flagging it first
- Do not change the orthographic camera to perspective — this is an intentional visual constraint
- Do not add pay-to-win mechanics — cosmetic IAP only
- Do not add the UpgradePicker/UpgradeManager systems in Phase 1 or 2

---

## Compact Instructions

*(Preserved across `/compact` — do not remove this section.)*

- Never use `instantiate()` for bullets at runtime — only BulletPool's `_ready()` pre-allocates them; use `BulletPool.fire()` during gameplay.
- Offline play required — no network calls in the gameplay loop.
- Camera stays orthographic, top-down, fixed Z. No perspective.
- Monetisation: cosmetic IAP only, no pay-to-win gates.
- Asset budget: ≤200MB total; ≤500KB per GLB model; 512×512 textures (1024×1024 bosses).
- PlayerBullet hits Enemy only; EnemyBullet hits Player only (collision layer matrix).
- WaveSpawner communicates via signals only — it does not reference the player directly.
- UpgradeManager/UpgradePicker deferred to Phase 3.

---

## Current Status

- [x] Phase 0: Stack confirmed — Godot 4 (GDScript), orthographic camera, Mobile renderer
- [x] Git + GitHub set up — repo at `konshoe/project-shooter`
- [x] Godot project initialised at C:\GameDesign\project-shooter
- [ ] Phase 1: Core loop (player movement, fire, one enemy type, collision, death)
- [ ] Phase 2: Wave system (3 enemy types, JSON wave configs, WaveSpawner)
- [ ] Phase 3: Boss + roguelike upgrade picker
- [ ] Phase 4: Content (5–8 levels, 2–3 bosses, audio)
- [ ] Phase 5: Platform export (web <10MB, iOS/Android wrapped, RevenueCat IAP)

---

## Key References

- `project-shooter.md` — full design brief, market research, case studies
- Godot 4 docs: https://docs.godotengine.org/en/stable/
- Sky Force Reloaded (reference title for 3D-in-2D visual approach)
