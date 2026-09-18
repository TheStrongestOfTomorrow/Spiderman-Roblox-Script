# SPIDER-MAN MOVEMENT ENGINE v3.0 — Roblox (Single-File LocalScript)

A complete, self-contained, **client-side** Spider-Man movement engine for Roblox.
One script. Zero server dependencies. Zero RemoteEvents. Zero external assets. All animations are procedural (no Animation IDs).

## Execute (Loadstring)

Copy and paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/Spiderman-Roblox-Script/main/spiderman.lua"))()
```

- Press **RightShift** in-game to open / hide the control panel.
- Re-executing the script automatically destroys the previous instance (no duplicates).
- Everything cleans itself up on death / respawn (Maid garbage-collection pattern).

## Files

| File | Description |
|------|-------------|
| `spiderman.lua` | The full movement engine — one production-ready LocalScript (~2,200 lines) |
| `README.md` | This documentation |

## Controls (Default Keybinds)

| # | Move | Key | Mode |
|---|------|-----|------|
| 1 | Pendulum Swing | `E` | Hold |
| 2 | Point Launch | `F` | Tap |
| 3 | Tight Gap Zip | `Space` | Tap (near narrow gaps) |
| 4 | Dual-Web Slingshot | `R` | Tap x2, walk back with `S`, tap `R` to release |
| 5 | Wall Crawl / Wall Sprint | `LeftShift` | Press to attach, press again = sprint |
| 6 | Wall Eject | `E` (while on wall) | Tap |
| 7 | Air Tricks | `G` + WASD | Hold in freefall |
| 8 | Ground Slide | `LeftShift` | Hold on fast landing (> 45 speed) |

**Space** is shared: Point Launch boost (within 3 s of arrival) > Wall jump-off > Tight Gap Zip.

## UI Panel (RightShift)

- **Movable header** — drag the title bar (mouse or touch delta) to reposition the 450x380 dark-glass panel.
- **Per-move toggle switch** — green = active, red = disabled. Disabling a move blocks its input listener.
- **Keybind rebind button** — shows the active `Enum.KeyCode.Name`; click it, press any key to rebind (`ESC` cancels).
- **RST button** — restores that move's factory default keybind.
- **Enable Mobile Buttons** — instantiates large touch-friendly buttons for every enabled move.
- **Lock Mobile Layout** — UNLOCKED = yellow border + drag-and-drop repositioning; LOCKED = borders removed, taps trigger moves cleanly.

## Mechanics Highlights

- **Pendulum Swing** — crosshair raycast up to 350 studs, anchor must sit > 5 studs above the root, geometry-sharpness filter samples 4 auxiliary normals (domes/spheres rejected, roof lips and flat faces accepted), Hooke's-law tension (`Velocity += TensionDir * Gravity * dt`), rope-length pendulum constraint, 18° procedural body roll, momentum decay (`0.982` drag) when coasting with no WASD.
- **Point Launch** — `F` renders a web and pulls at 180 studs/s; arrival within 4.5 studs opens a **3-second window**: `Space` = `Look * 130 + Up * 45` boost; after 3 s the stored momentum resets and `Space` performs a default jump.
- **Tight Gap Zip** — two parallel shoulder rays (3.5 studs apart) detect opposing surfaces < 8 studs apart, then lerp you through the gap in 0.12 s with collision bypass and a `Look * (speed + 25)` exit boost.
- **Dual-Web Slingshot** — Phase 1 anchors left web to LeftHand, Phase 2 anchors right web to RightHand. Walking backward builds tension `T = clamp((dist - initial) / maxStretch, 0, 1)`: WalkSpeed `16 * (1 - T^1.5)`, FOV ramps 70 to 110, webs heat White > Light Yellow > Deep Red. Release at `T >= 0.50` (tap R) or automatically at `T = 1.0` for `Dir * T * 240` launch at 35° elevation.
- **Wall System** — crawl at 14 studs/s flat against vertical surfaces (|Normal.Y| < 0.3), sprint at 38 studs/s in an upright stance, eject with `Up * 85 + inward * 15 + Look * 35` and auto-upright recovery to land on the roof.
- **Air Tricks** — `G+W` frontflip / `G+S` backflip (12°/frame), `G+A/D` barrel rolls (15°/frame), Motor6D shoulder/hip tuck poses, auto-recovery upright over 0.15 s on key release or below 15 studs altitude.
- **Ground Slide** — landing above 45 studs/s with Shift held drops the root -1.5 studs, enters Physics state with zero-friction physical properties, slides until speed < 10.
- **Fail-safes & camera** — anti-stuck web snap (< 1.5 speed for 1.2 consecutive seconds while swinging/zipping), dynamic FOV `clamp(70 + speed/220 * 40, 70, 110)` lerped at 0.1, launch micro-shake and subtle high-speed rumble.

## Technical Notes

- 100% LocalScript — all Beams, Attachments, SpecialMeshes and ScreenGuis are created with `Instance.new()` locally and parented to a client-only FX folder / CoreGui (PlayerGui fallback).
- Movement is driven by `AssemblyLinearVelocity` / CFrame writes on `HumanoidRootPart`; because the client owns its character's network physics, motion replicates to other players natively while the web visuals stay client-only.
- Only the three allowed engine visual assets are referenced: web strand texture `1082822557`, impact mesh `515312384`, impact texture `515312812`.

## Disclaimer

For educational and private-server use. Using script injectors in games you do not own violates the Roblox Terms of Service — use responsibly in your own projects or in places where scripting is permitted.
