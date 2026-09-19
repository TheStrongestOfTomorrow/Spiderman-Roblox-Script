# SPIDER-MAN MOVEMENT ENGINE v3.3 — Roblox (Single-File LocalScript)

A complete, self-contained, **client-side** Spider-Man movement engine for Roblox.
One script. Zero server dependencies. Zero RemoteEvents. **Zero external assets** — webs are plain white local Beams, so visuals render instantly on every executor. All animations are procedural (no Animation IDs).

## Execute (Loadstring)

Copy and paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/Spiderman-Roblox-Script/main/spiderman.lua"))()
```

> **Executor caching the old file?** Append a version tag to bust the cache:
> `loadstring(game:HttpGet("...spiderman.lua?v=3.3"))()`

- Verify you are on the current build: the console must print **`[SPIDEY ENGINE v3.3]`**.
- Press **RightShift** in-game to open / hide the control panel.
- Re-executing the script automatically destroys the previous instance (no duplicates).
- Everything cleans itself up on death / respawn (Maid garbage-collection pattern).

## Files

| File | Description |
|------|-------------|
| `spiderman.lua` | The full movement engine — one production-ready LocalScript (~2,200 lines) |
| `README.md` | This documentation |

## Controls (Insomniac's Spider-Man inspired)

| # | Move | Key | Mode |
|---|------|-----|------|
| 1 | Web Swing | `E` | **Hold** — fires only at a REAL surface (5-ray smart anchor search); W reels in, WASD to pump |
| 2 | Point Launch | `F` | Tap |
| 3 | Tight Gap Zip | `Space` | Tap (face a narrow gap) / **wall jump-off** |
| 4 | Dual-Web Slingshot | `R` | Tap x2, walk back with `S`, tap `R` to release |
| 5 | Sprint (Ground / Wall) | `LeftShift` | **Hold** — run at 26 on ground, wall-sprint at 38 |
| 6 | Wall Climb | **PASSIVE** | Run or jump at any wall to stick & climb; `Space` jumps off |
| 7 | Air Tricks | `G` + WASD | Hold in freefall |
| 8 | Ground Slide | `LeftShift` | Auto on fast landings (> 45 speed) |

**Space** priority: wall jump-off > swing release-jump (Insomniac X) > Point Launch boost (within 3 s of arrival) > Tight Gap Zip.
**E** is swing-only — no shared keybinds.

## UI Panel (RightShift / X button / floating icon)

- **Mobile-friendly toggle** — close the panel with its **X button** (top-right of the header); a small movable red **S icon** appears on the right edge — **tap it to re-open** the panel, **drag it** anywhere to keep it out of the way (mobile players cannot press RightShift; desktop can still use RightShift).
- **Movable header** — drag the title bar (mouse or touch delta) to reposition the 450x380 dark-glass panel.
- **Per-move toggle switch** — green = active, red = disabled. Disabling a move blocks its input listener.
- **Keybind rebind button** — shows the active `Enum.KeyCode.Name`; click it, press any key to rebind (`ESC` cancels).
- **RST button** — restores that move's factory default keybind.
- **Enable Mobile Buttons** — instantiates large touch-friendly buttons for every enabled move.
- **Lock Mobile Layout** — UNLOCKED = yellow border + drag-and-drop repositioning; LOCKED = borders removed, taps trigger moves cleanly.

## Mechanics Highlights

- **Web Swing (true RopeConstraint physics)** — a 5-ray smart search (straight, +18°, +35°, two side rays) hunts for a **real surface** within 350 studs; the web attaches only to an actual part and **never hangs in empty air** — if nothing valid is hit, no web fires. A `RopeConstraint` between the anchor and your root is the pendulum (the physics engine enforces the arc — no CFrame teleporting). On attach you get an instant **launch impulse** (crosshair look * 62, +18 up when grounded), a continuous **forward drive** of 40 studs/s² while holding E (capped at 125), `W` **reels the rope in** for the classic energy pump, and releasing mid-air flings you with an upward pop. 18° procedural body roll; humanoid is held in Freefall so ground friction never fights the rope.
- **Point Launch** — `F` renders a web and pulls at 180 studs/s; arrival within 4.5 studs opens a **3-second window**: `Space` = `Look * 130 + Up * 45` boost; after 3 s the stored momentum resets and `Space` performs a default jump.
- **Tight Gap Zip** — two parallel shoulder rays (3.5 studs apart) detect opposing surfaces < 8 studs apart, then lerp you through the gap in 0.12 s with collision bypass and a `Look * (speed + 25)` exit boost.
- **Dual-Web Slingshot** — Phase 1 anchors left web to LeftHand, Phase 2 anchors right web to RightHand. Walking backward builds tension `T = clamp((dist - initial) / maxStretch, 0, 1)`: WalkSpeed `16 * (1 - T^1.5)`, FOV ramps 70 to 110, webs heat White > Light Yellow > Deep Red. Release at `T >= 0.50` (tap R) or automatically at `T = 1.0` for `Dir * T * 240` launch at 35° elevation.
- **Passive Wall System** — running or jumping into any vertical surface (|Normal.Y| < 0.3, within 4.5 studs) auto-attaches you flat against it; climb at 14 studs/s with WASD, **hold `LeftShift` to wall-sprint at 38 studs/s upright**, `Space` hop-jumps off (`Up * 55 + out * 25 + Look * 15`). A 0.6 s re-attach cooldown prevents instant re-stick after jumping off.
- **Ground Sprint** — hold `LeftShift` on the ground to run at 26 studs/s (WalkSpeed is only written on sprint start/stop, so it never fights games that modify your speed).
- **Air Tricks** — `G+W` frontflip / `G+S` backflip (12°/frame), `G+A/D` barrel rolls (15°/frame), Motor6D shoulder/hip tuck poses, auto-recovery upright over 0.15 s on key release or below 15 studs altitude.
- **Ground Slide** — landing above 45 studs/s with Shift held drops the root -1.5 studs, enters Physics state with zero-friction physical properties, slides until speed < 10 (friction is always restored afterwards).
- **Fail-safes & camera** — anti-stuck web snap (< 1.5 speed for 1.2 consecutive seconds while swinging/zipping), dynamic FOV `clamp(70 + speed/220 * 40, 70, 110)` lerped at 0.1, launch micro-shake and subtle high-speed rumble.

## Technical Notes

- 100% LocalScript — all Beams, Attachments and ScreenGuis are created with `Instance.new()` locally and parented to a client-only FX folder / CoreGui (PlayerGui fallback).
- Movement is driven by `AssemblyLinearVelocity` / CFrame writes on `HumanoidRootPart`; because the client owns its character's network physics, motion replicates to other players natively while the web visuals stay client-only.
- **Zero external assets** — web strands are plain white Beams (`RGB 240, 240, 255`, Width 0.25 → 0.08); no texture or mesh IDs are referenced anywhere, so nothing can fail to load.

## Disclaimer

For educational and private-server use. Using script injectors in games you do not own violates the Roblox Terms of Service — use responsibly in your own projects or in places where scripting is permitted.
