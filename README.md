# SPIDER-MAN MOVEMENT ENGINE v3.6 — Roblox (Single-File LocalScript)

A complete, self-contained, **client-side** Spider-Man movement engine for Roblox inspired by Insomniac's Spider-Man games.
One script. Zero server dependencies. Zero RemoteEvents. **Zero external assets** — webs are plain white local Beams, audio cues use built-in engine sounds, so visuals and physics render instantly on every executor. All animations are procedural (no Animation IDs).

## Execute (Loadstring)

Copy and paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/Spiderman-Roblox-Script/main/spiderman.lua"))()
```

> **Executor caching the old file?** Append a version tag to bust the cache:
> `loadstring(game:HttpGet("...spiderman.lua?v=3.6"))()`

- Verify you are on the current build: the console must print **`[SPIDEY ENGINE v3.6]`**.
- Press **RightShift** in-game to open / hide the control panel.
- Re-executing the script automatically destroys the previous instance (no duplicates).
- Everything cleans itself up on death / respawn (Maid garbage-collection pattern).

## Files

| File | Description |
|------|-------------|
| `spiderman.lua` | The full movement engine — one production-ready LocalScript (~2,700 lines) |
| `README.md` | This documentation |

## Controls (Insomniac's Spider-Man inspired)

| # | Move | Key | Mode |
|---|------|-----|------|
| 1 | Web Swing | `E` | **Hold** — fires at real surfaces (8-ray smart anchor search + LOS check); W reels in, S lowers arc, alternating hands & procedural arm aim |
| 2 | Corner Tethering | `A` / `D` or `Q` | While swinging — procedurally whips 90° around building corners without losing momentum |
| 3 | Point Launch | `F` | Tap — dual-web pull to reticle target; perches stably on arrival; Space boosts forward (mid-flight Space = zip boost) |
| 4 | Quick Air Zip | `Space` | Tap in mid-air for instant forward web traversal burst |
| 5 | Steep Air Dive | `LeftControl` / `C` | Hold in air — aerodynamic terminal velocity bullet dive; converts kinetic momentum directly into swing speed on attach! |
| 6 | Web Wings (Gliding) | `Q` | Tap/Hold in air — deploy underarm web wings mid-air; pitch/yaw banking controls; chains cleanly into swings |
| 7 | Tight Gap Zip | `Space` | Tap near gap — detects openings & crevices with dual-web pull & bulletproof collision bypass |
| 8 | Dual-Web Slingshot | `R` | Tap / Hold — smart dual-anchor lock; walk back with `S` to stretch, release to launch |
| 9 | Ground Charge Jump | `LeftControl` + `Space` | Hold on ground — compress kinetic energy in a deep crouch, release for explosive rocket leap |
| 10 | Sprint (Ground / Wall) | `LeftShift` | **Hold** — run at 27 on ground, wall-sprint at 40 (R2 parkour) |
| 11 | Wall Climb & Corner Transfer | **PASSIVE** | Run or jump at wall to stick & climb; automatic **Rooftop Ledge Vault**; **90° Wall Corner Transfer**; `Space` jumps off |
| 12 | Ground Slide | `LeftShift` / `C` | Auto on fast landings (> 40 speed) OR manual trigger while sprinting on ground! |
| 13 | Air Tricks | `G` + WASD | Hold in freefall (framerate-independent rotation, symmetrical R15/R6 tuck poses) |

**Space** priority: wall jump-off > swing release-jump (Insomniac X) > mid-flight Point Launch zip boost > perched Point Launch boost > Tight Gap Zip > Quick Air Zip > default jump.
**E** is swing-only — no shared keybinds.

## UI Panel (RightShift / X button / floating icon)

- **Mobile-friendly toggle** — close the panel with its **X button** (top-right of the header); a movable red **S icon** appears on the right edge — **tap it to re-open** the panel, **drag it** anywhere to keep it out of the way (mobile players cannot press RightShift; desktop can still use RightShift).
- **Movable header** — drag the title bar (mouse or touch delta with multi-touch tracking) to reposition the dark-glass panel.
- **Per-move toggle switch** — green = active, red = disabled. Disabling a move blocks its input listener.
- **Keybind rebind button** — shows the active `Enum.KeyCode.Name`; click it, press any key to rebind (`ESC` cancels).
- **RST button** — restores that move's factory default keybind.
- **Enable Mobile Buttons** — instantiates an ergonomic 4x3 compact responsive touch button grid (12 moves) that fits on mobile screens without overflowing or obscuring the camera.
- **Lock Mobile Layout** — UNLOCKED = yellow border + drag-and-drop repositioning; LOCKED = borders removed, taps trigger moves cleanly with dedicated touch tracking (zero multi-touch jitter).

## Mechanics Highlights

- **Web Swing (true RopeConstraint physics)** — an 8-ray multi-tier smart search (high roofs, avenue skyscrapers, street facades, overhead bridges) hunts for real surfaces within 360 studs with character line-of-sight validation. If an ideal sharp roof edge is hit, it takes priority; if only rounded/mesh surfaces are present, it gracefully falls back to the best physical surface above the player (zero missed swings). Alternates left and right web hands based on anchor angle, with procedural arm aiming towards the anchor point. Dynamic pendulum energy pump: `W` reels in (10 studs/s), `S` lowers the arc (8 studs/s) for deeper drops. Releasing `E` or tapping `Space` flings out of the arc with horizontal momentum preserved and multiplied ×1.18. Framerate-independent drag ensures identical physics at 60Hz, 144Hz, and 240Hz+.
- **Corner Tethering** — press `A` or `D` (or tap `Q`) while swinging near a building corner: Spider-Man procedurally plants a secondary pivot tether and whips 90° around the facade without losing forward pendulum speed, exactly matching Insomniac's city cornering.
- **Web Wings (Gliding)** — tap `Q` in mid-air to deploy underarm web wings (procedural dual Beams attached between torso and wrists). Provides smooth aerodynamic gliding with WASD pitch and yaw banking controls (`W` dips nose for speed, `S` flattens glide, `A`/`D` banks roll). Chains seamlessly into a Web Swing, Quick Air Zip, or Wall Climb.
- **Steep Air Dive & Kinetic Swing Conversion** — hold `LeftControl` or `C` while airborne to enter a streamlined vertical bullet dive accelerating rapidly to terminal velocity (up to 180 studs/s) with aerodynamic camera FOV expansion. Attaching a Web Swing during or right out of a dive directly converts your accumulated dive velocity into raw pendulum launch kinetic energy.
- **Dynamic Insomniac HUD Reticle** — a lightweight, zero-asset circular HUD reticle that dynamically highlights valid Point Launch perches and swing anchor targets via `Camera:WorldToViewportPoint`. Expands and snaps with a sleek lock ring when a prime ledge or spire is in view.
- **Point Launch & Perch** — `F` renders dual web strands from both hands and pulls at 185 studs/s. Tapping `Space` mid-flight executes a **Mid-Flight Zip Boost** flinging past the point. Arriving at the target point opens a stable **Perch** (gravity stabilized so you don't slide off spires or ledges) with a 3-second launch window: `Space` = `Look * 135 + Up * 45` boost; pressing WASD steps off into free movement.
- **Tight Gap Zip** — detects narrow passages, windows, and interior crevices where the center path is open while flanking surfaces are within 10 studs. Fires dual web strands to the gap edges, smoothly pulls through in 0.12 s with safe collision bypass and a `Look * (speed + 28)` exit fling. Collision state is guaranteed to restore under all exit conditions.
- **Dual-Web Slingshot** — automatically acquires dual anchors on press when valid flanking geometry is present. Walking backward builds tension `T = clamp((dist - initial) / maxStretch, 0, 1)`: WalkSpeed slows progressively, FOV ramps 70 to 110, webs heat White > Light Yellow > Deep Red. Release at `T >= 0.45` or automatically at `T = 1.0` for `Dir * T * 250` launch at 35° elevation in `Freefall` state (no ground friction drag). Features an 8-second safety timeout and clean jump cancellation so you never get stuck.
- **Ground Charge Jump** — hold `LeftControl` + `Space` while grounded to compress into a deep kinetic charge pose. Release to unleash an explosive vertical rocket leap (`Up * 110 + Look * 45`) accompanied by built-in audio cues, perfect for vaulting directly into a high-altitude Web Swing or Web Wings glide.
- **Passive Wall System, Rooftop Ledge Vault & Corner Transfer** — running or jumping into any vertical surface (|Normal.Y| < 0.3, within 4.8 studs) auto-attaches you flat against it; climb at 15 studs/s with WASD, **hold `LeftShift` to wall-sprint at 40 studs/s upright**. Crawl posture correctly keeps chest to wall and aligns head with crawl direction with procedural limb movement. When climbing to the top lip of a building, Spider-Man automatically performs a **Rooftop Ledge Vault** up and onto the roof. When navigating around 90° building corners (both outer and inner corners), the engine performs an automatic **Wall Corner Transfer** to maintain seamless wall contact without dropping. `Space` performs an outward jump-off.
- **Ground Sprint & Superhero Slide** — hold `LeftShift` on the ground to sprint at 27 studs/s (preserves and restores game-specific walkspeeds). Landing above 40 studs/s with Shift held — or pressing Slide/Crouch while sprinting — enters a zero-friction slide with a **procedural superhero slide pose** (leading leg extended, rear leg tucked) and pops upright on exit.
- **Air Tricks** — `G+W` frontflip, `G+S` backflip, `G+A/D` barrel rolls with framerate-independent rotation scaling (`dt * 60`). Symmetrical Motor6D shoulder/hip tuck poses for both R15 and R6 rigs, auto-recovering upright below 14 studs altitude.
- **Quick Air Web Zip** — tapping `Space` in mid-air (when not swinging, climbing, or gap zipping) fires a quick dual web forward and delivers an instant 75 studs/s traversal burst.
- **Zero-Asset Built-in Audio** — subtle, clean web swishes (`action_swish.mp3`), launch pops (`action_jump.mp3`), and landing/slide sounds (`action_footsteps_plastic.mp3`) using Roblox's built-in core sounds.

## Technical Notes

- 100% LocalScript — all Beams, Attachments and ScreenGuis are created with `Instance.new()` locally and parented to a client-only FX folder / CoreGui (PlayerGui fallback).
- Movement is driven by `AssemblyLinearVelocity` / CFrame writes on `HumanoidRootPart`; because the client owns its character's network physics, motion replicates to other players natively while the web visuals stay client-only.
- **Zero external assets** — web strands and wings are plain white Beams (`RGB 240, 240, 255`, Width 0.22 → 0.08); sounds use built-in engine assets, so nothing can fail to load.

## Disclaimer

For educational and private-server use. Using script injectors in games you do not own violates the Roblox Terms of Service — use responsibly in your own projects or in places where scripting is permitted.
