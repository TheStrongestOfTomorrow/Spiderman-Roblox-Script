--[[=====================================================================
        SPIDER-MAN MOVEMENT ENGINE v3.6  •  The Insomniac Definitive Suite
        =====================================================================
        CONTROLS (Insomniac's Spider-Man 2 inspired)
          • E (hold)         Web Swing — 8-ray smart anchor search + LOS check,
                             true RopeConstraint pendulum; W reels in, S lowers,
                             alternating left/right hands, procedural arm aim.
          • F (tap)          Point Launch — dual-web pull to crosshair point;
                             perches stably on arrival; Space boosts forward!
                             (Tap Space mid-flight for mid-air zip boost).
          • Space            Multi-Context:
                             - Wall Jump-Off (while on wall)
                             - Swing Release Jump (slingshot fling mid-air)
                             - Point Launch Boost (perched or mid-flight)
                             - Tight Gap Zip (facing narrow passage/crevice)
                             - Quick Air Web Zip (freefall traversal burst)
                             - Charge Jump Release (when charged on ground)
          • R (tap / hold)   Dual-Web Slingshot — smart dual anchor lock;
                             walk back with S to stretch, release to launch!
          • LeftShift (hold) Sprint on ground (27 studs/s) & walls (40 studs/s)
                             + manual Ground Slide while sprinting!
          • Wall Climb       PASSIVE — run or jump at any wall to stick and
                             climb; Space jumps off; automatic Rooftop Ledge Vault
                             and 90° Wall Corner Transfer around building sides!
          • G (hold) + WASD  Air Tricks (frontflip / backflip / barrel roll)
          • LeftShift / C    Ground Slide on fast landings (> 40 speed) or sprint
          • Q (tap in air)   Web Wings (Gliding) — Insomniac Spider-Man 2 glide,
                             WASD bank & pitch, underarm webbing, chains into swing!
          • Q / A,D in swing Corner Tethering — whip 90° around building corners!
          • LeftCtrl / C     Steep Air Dive in mid-air (kinetic swing conversion!)
          • LeftCtrl + Space Ground Charge Jump — deep crouch compression & leap!
          • RightShift / X   Toggle control panel — movable floating 'S' icon
                             re-opens panel (mobile-friendly).

        NEW IN v3.6:
          • Web Wings (Gliding Mode) with aerodynamic lift, bank steering & underarm webbing
          • Steep Air Dive: Streamlined terminal velocity dive with kinetic swing conversion
          • Corner Tethering (Corner Whip): Whip 90° around building corners at full speed
          • Wall Corner Transfer: Smoothly wrap around 90° outside and inside building corners
          • Ground Charge Jump: Hold crouch + jump for a massive vertical rocket leap
          • Dynamic HUD Reticle: Insomniac zip-to-point & swing target tracking indicator
          • Expanded Mobile Layout: Seamless touch controls for Wings, Dive & Charge Jump
=====================================================================--]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// Re-execution guard: destroy a previously injected engine copy -------
local Engine = { Connections = {}, Destroyed = false }
local _previous = _G.__SPIDEY_ENGINE_V3
if typeof(_previous) == "table" and typeof(_previous.Destroy) == "function" then
        pcall(_previous.Destroy, _previous)
end
_G.__SPIDEY_ENGINE_V3 = Engine

local function track(connection)
        table.insert(Engine.Connections, connection)
        return connection
end

--======================================================================
-- CONFIGURATION
--======================================================================
local CONFIG = {
        -- [A] Web Swing (true RopeConstraint pendulum)
        SwingMaxDistance   = 360,   -- anchor raycast max distance (studs)
        SwingMinHeightDiff = 4,     -- anchor must be this far above the root
        SwingSteerAccel    = 46,    -- WASD pump acceleration while swinging
        SwingDragXZ        = 0.995, -- horizontal drag base (scaled with dt*60)
        SwingRollMaxDeg    = 18,    -- procedural body roll clamp (degrees)
        SwingRollFactor    = 0.20,  -- roll gain factor
        SwingLaunchSpeed   = 65,    -- initial impulse toward the crosshair
        SwingLiftOff       = 18,    -- extra upward pop when starting grounded
        SwingThrust        = 44,    -- continuous forward drive while holding E
        SwingMaxSpeed      = 135,   -- horizontal speed cap for the drive
        SwingWReel         = 10,    -- W reels the rope in (studs/sec)
        SwingSExtend       = 8,     -- S extends the rope for deeper drops (studs/sec)
        SwingReleasePop    = 15,    -- upward pop when releasing mid-air
        SwingReleaseBoost  = 1.18,  -- horizontal momentum multiplier on release (slingshot)

        -- [B] Point Launch
        LaunchSpeed        = 185,   -- linear pull speed toward target
        LaunchArriveRadius = 5.0,   -- arrival threshold (studs)
        LaunchWindow       = 3.0,   -- Space boost window after arrival (sec)
        LaunchTimeout      = 3.5,   -- hard timeout for the pull (sec)
        BoostLookSpeed     = 135,   -- boost speed along camera look
        BoostUpSpeed       = 45,    -- boost upward component

        -- [C] Tight Gap Zip
        GapShoulderSpacing = 3.5,   -- distance between the two parallel rays
        GapMaxClearance    = 10,    -- max gap width to allow pass-through
        GapZipDuration     = 0.12,  -- lerp time across the gap (sec)
        GapExitBoost       = 28,    -- exit velocity boost on top of entry speed

        -- [D] Dual-Web Slingshot
        SlingMaxStretch    = 20,    -- studs of stretch from initial distance
        SlingMaxSpeed      = 250,   -- launch speed at T = 1.0
        SlingMinT          = 0.45,  -- minimum tension for manual release
        SlingLaunchAngle   = 35,    -- upward launch angle (degrees)
        SlingTimeout       = 8.0,   -- max charging duration before auto-cancel

        -- [E] Wall systems (passive climb, Insomniac parkour style)
        CrawlSpeed         = 15,    -- wall crawl speed (studs/sec)
        SprintSpeed        = 40,    -- wall sprint speed (studs/sec)
        WallStickOffset    = 3.0,   -- hover distance from wall surface
        WallDetectDist     = 7.5,   -- forward wall detection range
        PassiveWallDist    = 4.8,   -- auto-attach when a wall is this close
        ReattachCooldown   = 0.5,   -- seconds before re-attach after jump-off
        WallJumpUp         = 55,    -- Space jump-off vertical impulse
        WallJumpOut        = 25,    -- Space jump-off push away from wall
        WallJumpLook       = 18,    -- Space jump-off camera-look impulse
        LedgeVaultUp       = 24,    -- rooftop ledge vault vertical impulse
        LedgeVaultForward  = 16,    -- rooftop ledge vault forward push
        RunSpeed           = 27,    -- ground sprint speed (LeftShift hold)

        -- [F] Air Tricks
        TrickFlipRate      = 14,    -- front/backflip rate (deg/frame @ 60fps)
        TrickRollRate      = 16,    -- barrel roll rate (deg/frame @ 60fps)
        TrickMinAltitude   = 14,    -- auto-recover below this altitude
        TrickRecoveryTime  = 0.15,  -- upright recovery duration (sec)

        -- [G] Ground Slide
        SlideMinSpeed      = 40,    -- required landing speed to auto slide
        SlideSprintMin     = 18,    -- speed to trigger manual slide while sprinting
        SlideEndSpeed      = 10,    -- slide ends below this speed
        SlideDecel         = 12,    -- slide deceleration (studs/sec^2)
        SlideDropOffset    = -1.5,  -- root height offset while sliding

        -- [H] Quick Air Zip
        AirZipSpeed        = 75,    -- instant forward burst on air zip
        AirZipPop          = 12,    -- slight upward lift
        AirZipCooldown     = 0.75,  -- cooldown between air zips (sec)

        -- [I] Web Wings (Gliding)
        GlidingMinSpeed    = 45,    -- minimum horizontal glide speed
        GlidingMaxSpeed    = 115,   -- maximum horizontal glide speed
        GlidingSinkRate    = 12,    -- downward sink speed while gliding
        GlidingSteerRate   = 60,    -- banking turn acceleration

        -- [J] Steep Air Dive
        DiveGravityMult    = 2.2,   -- downward gravity multiplier during dive
        DiveTerminalSpeed  = 175,   -- max vertical dive speed
        DiveSwingBonus     = 0.75,  -- fraction of dive speed converted to swing thrust

        -- [K] Corner Tethering
        CornerTetherDist   = 28,    -- max distance to detect building corner
        CornerWhipForce    = 1.10,  -- speed multiplier when whipping around corner

        -- [L] Ground Charge Jump
        ChargeJumpMaxTime  = 0.65,  -- seconds to reach 100% leap charge
        ChargeJumpHeight   = 78,    -- vertical jump impulse at max charge
        ChargeJumpForward  = 36,    -- forward jump impulse

        -- Fail-safes & Visuals
        AntiStuckSpeed     = 1.5,   -- speed below which stuck-timer runs
        AntiStuckTime      = 1.2,   -- consecutive seconds before web snap
        FOVBase            = 70,
        FOVSpeedDivisor    = 220,
        FOVSpeedGain       = 40,
        FOVMax             = 110,
        FOVLerp            = 0.1,
        ReticleEnabled     = true,  -- Insomniac zip-to-point HUD reticle
        WebColor           = Color3.fromRGB(240, 240, 255),
        AudioEnabled       = true,  -- built-in client engine sounds
}

--======================================================================
-- AUDIO HELPER (100% zero external assets, uses built-in engine sounds)
--======================================================================
local function playSound(soundId, volume, pitch)
        if not CONFIG.AudioEnabled then return end
        pcall(function()
                local sound = Instance.new("Sound")
                sound.SoundId = soundId
                sound.Volume = volume or 0.5
                sound.PlaybackSpeed = pitch or 1
                sound.Parent = Workspace
                sound:Play()
                task.delay(1.5, function()
                        pcall(function() sound:Destroy() end)
                end)
        end)
end

--======================================================================
-- MAID (garbage-collection engine)
--======================================================================
local Maid = {}
Maid.__index = Maid

function Maid.new()
        return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
        if task ~= nil then
                table.insert(self._tasks, task)
        end
        return task
end

function Maid:Cleanup()
        for i = #self._tasks, 1, -1 do
                local task = self._tasks[i]
                self._tasks[i] = nil
                local kind = typeof(task)
                if kind == "Instance" then
                        pcall(function() task:Destroy() end)
                elseif kind == "RBXScriptConnection" then
                        pcall(function() task:Disconnect() end)
                elseif kind == "function" then
                        pcall(task)
                end
        end
end

local webMaid  = Maid.new() -- all temporary web visuals (beams/meshes/attachments)
local lifeMaid = Maid.new() -- per-life connections (died, zip tween, etc.)

--======================================================================
-- STATE MANAGER
--======================================================================
local StateManager = {
        States = {
                Idle              = "Idle",
                Swinging          = "Swinging",
                PointLaunching    = "PointLaunching",
                GapZipping        = "GapZipping",
                SlingshotCharging = "SlingshotCharging",
                WallCrawling      = "WallCrawling",
                WallSprinting     = "WallSprinting",
                WallEjecting      = "WallEjecting",
                AirTricking       = "AirTricking",
                GroundSliding     = "GroundSliding",
                Gliding           = "Gliding",
                AirDiving         = "AirDiving",
        },
        Current = "Idle",
}

local VALID_TRANSITIONS = {
        Idle              = { "Swinging", "PointLaunching", "GapZipping", "SlingshotCharging", "WallCrawling", "WallSprinting", "WallEjecting", "AirTricking", "GroundSliding", "Gliding", "AirDiving" },
        Swinging          = { "PointLaunching", "GapZipping", "WallCrawling", "AirTricking", "Idle", "WallEjecting", "Gliding", "AirDiving" },
        PointLaunching    = { "Idle", "Swinging", "GapZipping", "AirTricking", "WallCrawling", "GroundSliding", "Gliding" },
        GapZipping        = { "Idle", "Swinging", "AirTricking", "GroundSliding", "Gliding" },
        SlingshotCharging = { "Idle" },
        WallCrawling      = { "WallSprinting", "WallEjecting", "Swinging", "Idle", "Gliding" },
        WallSprinting     = { "WallCrawling", "WallEjecting", "Swinging", "Idle", "Gliding" },
        WallEjecting      = { "Idle", "Swinging", "AirTricking", "WallCrawling", "Gliding" },
        AirTricking       = { "Idle", "Swinging", "GroundSliding", "PointLaunching", "Gliding", "AirDiving" },
        GroundSliding     = { "Idle", "Swinging", "AirTricking" },
        Gliding           = { "Idle", "Swinging", "AirDiving", "PointLaunching", "WallCrawling", "GroundSliding", "GapZipping" },
        AirDiving         = { "Idle", "Swinging", "Gliding", "GroundSliding", "WallCrawling", "PointLaunching" },
}

function StateManager.CanTransition(targetState)
        local allowed = VALID_TRANSITIONS[StateManager.Current]
        if not allowed then
                return true
        end
        return table.find(allowed, targetState) ~= nil
end

function StateManager.Set(targetState, force)
        local resolved = StateManager.States[targetState] or targetState
        if not force and not StateManager.CanTransition(resolved) then
                return false
        end
        if StateManager.Current ~= resolved then
                StateManager.Current = resolved
        end
        return true
end

--======================================================================
-- MOVE REGISTRY (UI rows + input routing)
--======================================================================
local Moves = {
        [1]  = { Name = "Pendulum Swing",       Default = Enum.KeyCode.E,           Key = Enum.KeyCode.E,           Enabled = true },
        [2]  = { Name = "Point Launch",         Default = Enum.KeyCode.F,           Key = Enum.KeyCode.F,           Enabled = true },
        [3]  = { Name = "Tight Gap Zip",        Default = Enum.KeyCode.Space,       Key = Enum.KeyCode.Space,       Enabled = true },
        [4]  = { Name = "Dual-Web Slingshot",   Default = Enum.KeyCode.R,           Key = Enum.KeyCode.R,           Enabled = true },
        [5]  = { Name = "Sprint (Ground/Wall)",  Default = Enum.KeyCode.LeftShift,   Key = Enum.KeyCode.LeftShift,   Enabled = true },
        [6]  = { Name = "Wall Climb (Passive)",  Default = nil,                      Key = nil,                      Enabled = true },
        [7]  = { Name = "Air Tricks",           Default = Enum.KeyCode.G,           Key = Enum.KeyCode.G,           Enabled = true },
        [8]  = { Name = "Ground Slide",         Default = Enum.KeyCode.LeftShift,   Key = Enum.KeyCode.LeftShift,   Enabled = true },
        [9]  = { Name = "Quick Air Zip",        Default = Enum.KeyCode.Space,       Key = Enum.KeyCode.Space,       Enabled = true },
        [10] = { Name = "Web Wings (Gliding)",  Default = Enum.KeyCode.Q,           Key = Enum.KeyCode.Q,           Enabled = true },
        [11] = { Name = "Steep Air Dive",       Default = Enum.KeyCode.LeftControl, Key = Enum.KeyCode.LeftControl, Enabled = true },
        [12] = { Name = "Ground Charge Jump",   Default = Enum.KeyCode.Space,       Key = Enum.KeyCode.Space,       Enabled = true },
}

--======================================================================
-- RUNTIME STATE
--======================================================================
local Character, Humanoid, RootPart
local stuckTimer   = 0
local shakeTimer   = 0
local shiftHeld    = false
local ctrlHeld     = false
local sprintActive = false
local moveKeys    = { W = false, A = false, S = false, D = false }
local MOVE_KEYS_MAP = {
        [Enum.KeyCode.W] = "W", [Enum.KeyCode.Up]    = "W",
        [Enum.KeyCode.A] = "A", [Enum.KeyCode.Left]  = "A",
        [Enum.KeyCode.S] = "S", [Enum.KeyCode.Down]  = "S",
        [Enum.KeyCode.D] = "D", [Enum.KeyCode.Right] = "D",
}

local function cameraPulse(duration)
        shakeTimer = math.max(shakeTimer, duration)
end

--======================================================================
-- CLIENT FX FOLDER + RAYCAST FILTER
--======================================================================
local FXFolder = Instance.new("Folder")
FXFolder.Name = "SpideyFX_Client"
FXFolder.Parent = Workspace

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.FilterDescendantsInstances = { FXFolder }

--======================================================================
-- RIG RESOLVER (R15 + R6)
--======================================================================
local Rig = {
        IsR15 = true,
        RightHand = nil,
        LeftHand = nil,
        Joints = {},
        DefaultWalkSpeed = 16,
}

local R6_JOINT_MAP = {
        RightShoulder = "Right Shoulder",
        LeftShoulder  = "Left Shoulder",
        RightHip      = "Right Hip",
        LeftHip       = "Left Hip",
}

local function refreshRig()
        Character = LocalPlayer.Character
        Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid") or nil
        RootPart  = Character and Character:FindFirstChild("HumanoidRootPart") or nil

        Rig.IsR15 = (Humanoid ~= nil) and Humanoid.RigType == Enum.HumanoidRigType.R15

        Rig.RightHand = Character and (
                Character:FindFirstChild("RightHand")
                or Character:FindFirstChild("Right Arm")
                or Character:FindFirstChild("RightLowerArm")
        ) or nil
        Rig.LeftHand = Character and (
                Character:FindFirstChild("LeftHand")
                or Character:FindFirstChild("Left Arm")
                or Character:FindFirstChild("LeftLowerArm")
        ) or nil

        Rig.Joints = {}
        local names = { "RightShoulder", "LeftShoulder", "RightHip", "LeftHip" }
        for _, jointName in ipairs(names) do
                local motor = Character and Character:FindFirstChild(jointName, true) or nil
                if not motor and Character then
                        motor = Character:FindFirstChild(R6_JOINT_MAP[jointName], true)
                end
                if motor and motor:IsA("Motor6D") then
                        Rig.Joints[jointName] = { Motor = motor, C0 = motor.C0 }
                end
        end

        if Humanoid and not sprintActive then
                Rig.DefaultWalkSpeed = Humanoid.WalkSpeed
        end

        local ignore = { FXFolder }
        if Character then table.insert(ignore, Character) end
        if Camera then table.insert(ignore, Camera) end
        RayParams.FilterDescendantsInstances = ignore
end

local function getWebHand(isLeft)
        if not Character then
                return RootPart
        end
        local hand
        if isLeft then
                hand = Character:FindFirstChild("LeftHand")
                        or Character:FindFirstChild("Left Arm")
                        or Character:FindFirstChild("LeftLowerArm")
        else
                hand = Character:FindFirstChild("RightHand")
                        or Character:FindFirstChild("Right Arm")
                        or Character:FindFirstChild("RightLowerArm")
        end
        return hand or RootPart
end

--======================================================================
-- INPUT HELPERS
--======================================================================
local function getInputVector()
        local x, z = 0, 0
        if moveKeys.W then z = z + 1 end
        if moveKeys.S then z = z - 1 end
        if moveKeys.D then x = x + 1 end
        if moveKeys.A then x = x - 1 end
        return x, z
end

local function getCameraSteer()
        local x, z = getInputVector()
        if x == 0 and z == 0 then
                return Vector3.new(0, 0, 0)
        end
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local flatLook  = Vector3.new(look.X, 0, look.Z)
        local flatRight = Vector3.new(right.X, 0, right.Z)
        flatLook  = (flatLook.Magnitude  > 0.01) and flatLook.Unit  or Vector3.new(0, 0, 0)
        flatRight = (flatRight.Magnitude > 0.01) and flatRight.Unit or Vector3.new(0, 0, 0)
        local v = flatRight * x + flatLook * z
        if v.Magnitude < 0.01 then
                return Vector3.new(0, 0, 0)
        end
        return v.Unit
end

local function altitudeAboveGround()
        if not RootPart then
                return math.huge
        end
        local hit = Workspace:Raycast(RootPart.Position, Vector3.new(0, -1, 0) * 200, RayParams)
        if hit then
                return (RootPart.Position - hit.Position).Magnitude
        end
        return math.huge
end

--======================================================================
-- VISUAL BUILDERS (all client-local instances)
--======================================================================
local function handAttachment(hand)
        if not hand then
                return nil
        end
        local att = Instance.new("Attachment")
        att.Name = "SpideyWebHand"
        att.Parent = hand
        return att
end

local function anchorAttachment(part, worldPos)
        local att = Instance.new("Attachment")
        att.Name = "SpideyWebAnchor"
        if part and part:IsA("BasePart") and part.Anchored then
                att.Parent = part
                att.WorldPosition = worldPos
        else
                local proxy = Instance.new("Part")
                proxy.Name = "SpideyVirtualAnchor"
                proxy.Size = Vector3.new(0.1, 0.1, 0.1)
                proxy.CFrame = CFrame.new(worldPos)
                proxy.Anchored = true
                proxy.CanCollide = false
                proxy.Transparency = 1
                proxy.Parent = FXFolder
                att.Parent = proxy
                att.Position = Vector3.new(0, 0, 0)
                webMaid:Give(proxy)
        end
        return att
end

local function createWebBeam(attachment0, attachment1)
        local beam = Instance.new("Beam")
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        beam.Width0 = 0.22
        beam.Width1 = 0.08
        beam.Color = ColorSequence.new(CONFIG.WebColor)
        beam.LightEmission = 0.35
        beam.LightInfluence = 0
        beam.FaceCamera = true
        beam.Segments = 12
        beam.Parent = FXFolder
        return beam
end

local function releaseWebs()
        webMaid:Cleanup()
end

--======================================================================
-- GEOMETRY SHARPNESS & SWING ANCHOR SYSTEM
--======================================================================
local function isSharpEnough(hitPos, hitNormal)
        local up = Vector3.new(0, 1, 0)
        local t1 = hitNormal:Cross(up)
        if t1.Magnitude < 0.05 then
                t1 = hitNormal:Cross(Vector3.new(1, 0, 0))
        end
        if t1.Magnitude < 0.05 then
                return true
        end
        t1 = t1.Unit
        local t2 = hitNormal:Cross(t1).Unit
        local radials = { t1, t2, t1 * -1, t2 * -1 }

        local normals = { hitNormal }
        local origin = hitPos + hitNormal * 0.8
        for _, radial in ipairs(radials) do
                local target = hitPos + radial * 2.0
                local dir = (target - origin)
                if dir.Magnitude > 0.05 then
                        local sample = Workspace:Raycast(origin, dir.Unit * (dir.Magnitude + 1.0), RayParams)
                        if sample then
                                table.insert(normals, sample.Normal)
                        end
                end
        end

        if #normals < 2 then
                return true
        end

        local sawSharp = false
        local allFlat = true
        local pairsChecked = 0
        for i = 1, #normals do
                local a = normals[i]
                local b = normals[(i % #normals) + 1]
                local d = a:Dot(b)
                pairsChecked = pairsChecked + 1
                if d <= 0.88 then
                        sawSharp = true
                end
                if d < 0.95 then
                        allFlat = false
                end
        end

        if sawSharp or allFlat then
                return true
        end
        return pairsChecked < 3
end

-- Forward declarations
local Wall, PointLaunch, GapZip, AirZip, Wings, Dive, CornerTether, ChargeJump

--======================================================================
-- UPRIGHT RECOVERY SYSTEM (shared by Wall Eject + Air Tricks)
--======================================================================
local Recovery = { Active = false, Duration = 0.15, T0 = 0, FromRot = nil, After = nil }

local function startUprightRecovery(duration, after)
        if not RootPart then
                return
        end
        Recovery.Active = true
        Recovery.Duration = duration or 0.15
        Recovery.T0 = os.clock()
        Recovery.FromRot = RootPart.CFrame.Rotation
        Recovery.After = after
end

--======================================================================
-- [A] WEB SWING  (Hold E) — Insomniac-Grade RopeConstraint Pendulum
--======================================================================
local Swing = {
        Active = false, AnchorPart = nil, AnchorPos = nil, RopeLength = 0,
        Attach0 = nil, RootAttach = nil, Rope = nil,
        HandAttach = nil, Beam = nil, PrevDir = nil, StartClock = 0,
        IsLeft = false,
}

local function tiltUp(dir, deg)
        local a = math.rad(deg)
        local d = dir * math.cos(a) + Vector3.new(0, math.sin(a), 0)
        if d.Magnitude < 0.05 then
                return dir
        end
        return d.Unit
end

local function findSwingAnchor(rootPos)
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector

        local rays = {
                tiltUp(look, 20),
                tiltUp(look, 38),
                tiltUp((look - right * 0.50).Unit, 24),
                tiltUp((look + right * 0.50).Unit, 24),
                tiltUp((look - right * 0.85).Unit, 32),
                tiltUp((look + right * 0.85).Unit, 32),
                tiltUp(look, 55),
                look,
        }

        local bestIdealHit = nil
        local bestIdealScore = -math.huge
        local bestFallbackHit = nil
        local bestFallbackScore = -math.huge

        local origin = Camera.CFrame.Position
        local rootEye = rootPos + Vector3.new(0, 2, 0)

        for _, dir in ipairs(rays) do
                local hit = Workspace:Raycast(origin, dir * CONFIG.SwingMaxDistance, RayParams)
                if hit and hit.Position.Y > rootPos.Y + CONFIG.SwingMinHeightDiff then
                        local toAnchor = hit.Position - rootEye
                        local dist = toAnchor.Magnitude
                        local occluded = false
                        if dist > 2 then
                                local los = Workspace:Raycast(rootEye, toAnchor.Unit * (dist - 1.2), RayParams)
                                if los and los.Instance ~= hit.Instance then
                                        occluded = true
                                end
                        end

                        if not occluded then
                                local heightBonus = (hit.Position.Y - rootPos.Y) * 1.5
                                local forwardBonus = look:Dot((hit.Position - rootPos).Unit) * 25
                                local score = heightBonus + forwardBonus - dist * 0.1

                                if isSharpEnough(hit.Position, hit.Normal) then
                                        if score > bestIdealScore then
                                                bestIdealScore = score
                                                bestIdealHit = hit
                                        end
                                else
                                        if score > bestFallbackScore then
                                                bestFallbackScore = score
                                                bestFallbackHit = hit
                                        end
                                end
                        end
                end
        end

        return bestIdealHit or bestFallbackHit
end

function Swing.Begin()
        if not (RootPart and Humanoid) then return end
        if Swing.Active then return end
        if StateManager.Current == StateManager.States.SlingshotCharging then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
                if not Camera then return end
        end

        local rootPos = RootPart.Position
        local hit = findSwingAnchor(rootPos)
        if not hit then
                return
        end
        local anchorPos, anchorPart = hit.Position, hit.Instance

        releaseWebs()
        PointLaunch.Cancel()

        -- Kinetic conversion from Dive or Glide
        local diveBonus = 0
        if Dive and Dive.Active then
                diveBonus = math.abs(RootPart.AssemblyLinearVelocity.Y) * CONFIG.DiveSwingBonus
                Dive.End()
        end
        if Wings and Wings.Active then
                Wings.End()
        end

        Swing.Active = true
        Swing.StartClock = os.clock()
        Swing.PrevDir = nil
        Swing.AnchorPart = anchorPart
        Swing.AnchorPos = anchorPos

        local toAnchor = anchorPos - rootPos
        local isLeft = Camera.CFrame.RightVector:Dot(toAnchor) < -0.1
        Swing.IsLeft = isLeft

        local dist = math.max(toAnchor.Magnitude, 6)
        Swing.RopeLength = dist * 0.96

        Swing.Attach0 = anchorAttachment(anchorPart, anchorPos)
        Swing.RootAttach = Instance.new("Attachment")
        Swing.RootAttach.Name = "SpideySwingRoot"
        Swing.RootAttach.Parent = RootPart

        Swing.Rope = Instance.new("RopeConstraint")
        Swing.Rope.Attachment0 = Swing.Attach0
        Swing.Rope.Attachment1 = Swing.RootAttach
        Swing.Rope.Length = Swing.RopeLength
        Swing.Rope.Restitution = 0
        Swing.Rope.Visible = false
        Swing.Rope.Parent = RootPart

        Swing.HandAttach = handAttachment(getWebHand(isLeft))
        Swing.Beam = createWebBeam(Swing.Attach0, Swing.HandAttach)
        webMaid:Give(Swing.Attach0)
        webMaid:Give(Swing.RootAttach)
        webMaid:Give(Swing.Rope)
        webMaid:Give(Swing.HandAttach)
        webMaid:Give(Swing.Beam)

        playSound("rbxasset://sounds/action_swish.mp3", 0.65, 1.25)

        local look = Camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        flat = (flat.Magnitude > 0.05) and flat.Unit or Vector3.new(0, 0, -1)
        local grounded = Humanoid.FloorMaterial ~= Enum.Material.Air
        local impulse = look * (CONFIG.SwingLaunchSpeed + diveBonus)
        if grounded then
                impulse = impulse + Vector3.new(0, CONFIG.SwingLiftOff, 0)
        end
        RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity:Lerp(impulse, 0.7)

        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        StateManager.Set(StateManager.States.Swinging, true)
end

function Swing.Step(dt)
        if not Swing.Active or not (RootPart and RootPart.Parent) then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
                if not Camera then return end
        end
        if not Swing.Rope or not Swing.Rope.Parent then
                Swing.End(true)
                return
        end

        local hState = Humanoid and Humanoid:GetState()
        if Humanoid and Humanoid.Parent
                and hState ~= Enum.HumanoidStateType.Freefall
                and hState ~= Enum.HumanoidStateType.Physics then
                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end

        local vel = RootPart.AssemblyLinearVelocity
        local horiz = Vector3.new(vel.X, 0, vel.Z)

        -- Continuous forward thrust
        if horiz.Magnitude < CONFIG.SwingMaxSpeed then
                local look = Camera.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)
                vel = vel + flatLook * CONFIG.SwingThrust * dt
        end

        -- WASD air steering & framerate-independent coast decay
        local steer = getCameraSteer()
        if steer.Magnitude > 0.01 then
                vel = vel + steer * CONFIG.SwingSteerAccel * dt
        else
                local drag = math.pow(CONFIG.SwingDragXZ, dt * 60)
                vel = Vector3.new(vel.X * drag, vel.Y, vel.Z * drag)
        end

        -- Corner Tether check while swinging
        if CornerTether then
                CornerTether.CheckAndWhip(dt)
        end

        -- W reel-in / S extend-lowering
        if moveKeys.W and Swing.Rope.Length > 14 then
                Swing.Rope.Length = math.max(Swing.Rope.Length - CONFIG.SwingWReel * dt, 14)
                Swing.RopeLength = Swing.Rope.Length
        elseif moveKeys.S and Swing.Rope.Length < CONFIG.SwingMaxDistance then
                Swing.Rope.Length = math.min(Swing.Rope.Length + CONFIG.SwingSExtend * dt, CONFIG.SwingMaxDistance)
                Swing.RopeLength = Swing.Rope.Length
        end
        RootPart.AssemblyLinearVelocity = vel

        -- Procedural body roll
        local flat = Vector3.new(vel.X, 0, vel.Z)
        if flat.Magnitude > 4 then
                local curDir = flat.Unit
                if Swing.PrevDir then
                        local crossY = Swing.PrevDir.X * curDir.Z - Swing.PrevDir.Z * curDir.X
                        local dot = math.clamp(Swing.PrevDir:Dot(curDir), -1, 1)
                        local turnDeg = math.deg(math.atan2(crossY, dot))
                        local rollDeg = math.clamp(turnDeg * 6 * CONFIG.SwingRollFactor, -CONFIG.SwingRollMaxDeg, CONFIG.SwingRollMaxDeg)
                        local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + curDir) * CFrame.Angles(0, 0, math.rad(rollDeg))
                        RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, math.clamp(dt * 15, 0, 1))
                end
                Swing.PrevDir = curDir
        else
                Swing.PrevDir = nil
        end

        -- Procedural arm aiming toward anchor point
        local armKey = Swing.IsLeft and "LeftShoulder" or "RightShoulder"
        local otherKey = Swing.IsLeft and "RightShoulder" or "LeftShoulder"
        local reachArm = Rig.Joints[armKey]
        local trailArm = Rig.Joints[otherKey]
        if reachArm and reachArm.Motor and reachArm.Motor.Parent then
                local reachCF
                if Rig.IsR15 then
                        reachCF = Swing.IsLeft and CFrame.Angles(math.rad(135), 0, math.rad(25)) or CFrame.Angles(math.rad(135), 0, -math.rad(25))
                else
                        reachCF = Swing.IsLeft and CFrame.Angles(0, 0, -math.rad(135)) or CFrame.Angles(0, 0, math.rad(135))
                end
                reachArm.Motor.C0 = reachArm.Motor.C0:Lerp(reachArm.C0 * reachCF, math.clamp(dt * 14, 0, 1))
        end
        if trailArm and trailArm.Motor and trailArm.Motor.Parent then
                local trailCF
                if Rig.IsR15 then
                        trailCF = Swing.IsLeft and CFrame.Angles(-math.rad(25), 0, -math.rad(15)) or CFrame.Angles(-math.rad(25), 0, math.rad(15))
                else
                        trailCF = Swing.IsLeft and CFrame.Angles(0, 0, math.rad(25)) or CFrame.Angles(0, 0, -math.rad(25))
                end
                trailArm.Motor.C0 = trailArm.Motor.C0:Lerp(trailArm.C0 * trailCF, math.clamp(dt * 14, 0, 1))
        end

        -- Grounded bail-out
        if os.clock() - Swing.StartClock > 0.5
                and Humanoid.FloorMaterial ~= Enum.Material.Air
                and vel.Magnitude < 10 then
                Swing.End(true)
        end
end

function Swing.End(keepMomentum)
        if not Swing.Active then return end
        Swing.Active = false
        Swing.AnchorPart = nil
        Swing.AnchorPos = nil
        Swing.Attach0 = nil
        Swing.RootAttach = nil
        Swing.Rope = nil
        Swing.HandAttach = nil
        Swing.Beam = nil
        Swing.PrevDir = nil
        releaseWebs()

        if keepMomentum ~= false and RootPart and RootPart.Parent
                and Humanoid and Humanoid.Parent
                and Humanoid.FloorMaterial == Enum.Material.Air then
                local v = RootPart.AssemblyLinearVelocity
                local flat = Vector3.new(v.X, 0, v.Z) * CONFIG.SwingReleaseBoost
                local up = math.max(v.Y, CONFIG.SwingReleasePop)
                RootPart.AssemblyLinearVelocity = Vector3.new(flat.X, up, flat.Z)
                playSound("rbxasset://sounds/action_jump.mp3", 0.65, 1.1)
        end

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end

        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
        end
        if StateManager.Current == StateManager.States.Swinging then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [B] POINT LAUNCH  (Tap F)  + Perch & Boost Window
--======================================================================
PointLaunch = {
        Pulling = false, Arrived = false, Target = nil,
        ArrivalTimestamp = 0, StartTime = 0,
}

function PointLaunch.Begin()
        if not (RootPart and Humanoid) then return end
        if StateManager.Current == StateManager.States.SlingshotCharging then return end
        if GapZip.Active then return end

        local hit = Workspace:Raycast(
                Camera.CFrame.Position,
                Camera.CFrame.LookVector * 1000,
                RayParams
        )
        if not hit then return end
        if (hit.Position - RootPart.Position).Magnitude < 8 then return end

        if Wall.Crawling then
                Wall.Detach()
        end
        if Swing.Active then
                Swing.End(true)
        end
        if Wings and Wings.Active then
                Wings.End()
        end
        if Dive and Dive.Active then
                Dive.End()
        end
        releaseWebs()

        PointLaunch.Pulling = true
        PointLaunch.Arrived = false
        PointLaunch.Target = hit.Position
        PointLaunch.StartTime = os.clock()

        local handL = handAttachment(getWebHand(true))
        local handR = handAttachment(getWebHand(false))
        local a0 = anchorAttachment(hit.Instance, hit.Position)
        local beamL = createWebBeam(a0, handL)
        local beamR = createWebBeam(a0, handR)
        webMaid:Give(handL)
        webMaid:Give(handR)
        webMaid:Give(a0)
        webMaid:Give(beamL)
        webMaid:Give(beamR)

        playSound("rbxasset://sounds/action_swish.mp3", 0.7, 1.25)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        StateManager.Set(StateManager.States.PointLaunching, true)
end

function PointLaunch.Step(dt)
        if not (RootPart and RootPart.Parent) then return end

        if PointLaunch.Arrived then
                local x, z = getInputVector()
                if x ~= 0 or z ~= 0 then
                        PointLaunch.Cancel()
                        return
                end
                local perchedCF = CFrame.lookAt(PointLaunch.Target + Vector3.new(0, 1.2, 0), PointLaunch.Target + Vector3.new(0, 1.2, 0) + Camera.CFrame.LookVector)
                RootPart.CFrame = RootPart.CFrame:Lerp(perchedCF, math.clamp(dt * 20, 0, 1))
                RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                return
        end

        if not PointLaunch.Pulling then return end

        if os.clock() - PointLaunch.StartTime > CONFIG.LaunchTimeout then
                PointLaunch.Cancel()
                return
        end

        local toTarget = PointLaunch.Target - RootPart.Position
        if toTarget.Magnitude < CONFIG.LaunchArriveRadius then
                PointLaunch.Pulling = false
                PointLaunch.Arrived = true
                PointLaunch.ArrivalTimestamp = os.clock()
                releaseWebs()
                RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                return
        end

        RootPart.AssemblyLinearVelocity = toTarget.Unit * CONFIG.LaunchSpeed

        local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
        if flat.Magnitude > 1 then
                local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + flat.Unit)
                RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, math.clamp(dt * 15, 0, 1))
        end
end

function PointLaunch.CheckWindow()
        if PointLaunch.Arrived
                and (os.clock() - PointLaunch.ArrivalTimestamp) > CONFIG.LaunchWindow then
                PointLaunch.Arrived = false
                if StateManager.Current == StateManager.States.PointLaunching then
                        StateManager.Set(StateManager.States.Idle, true)
                end
        end
end

function PointLaunch.TryBoost()
        if not (RootPart and RootPart.Parent) then return false end
        if PointLaunch.Pulling then
                PointLaunch.Pulling = false
                releaseWebs()
                local boost = Camera.CFrame.LookVector * (CONFIG.LaunchSpeed * 0.95) + Vector3.new(0, 25, 0)
                RootPart.AssemblyLinearVelocity = boost
                StateManager.Set(StateManager.States.Idle, true)
                cameraPulse(0.35)
                playSound("rbxasset://sounds/action_jump.mp3", 0.75, 1.2)
                return true
        end
        if PointLaunch.Arrived then
                local elapsed = os.clock() - PointLaunch.ArrivalTimestamp
                if elapsed <= CONFIG.LaunchWindow then
                        local boost = Camera.CFrame.LookVector * CONFIG.BoostLookSpeed + Vector3.new(0, CONFIG.BoostUpSpeed, 0)
                        RootPart.AssemblyLinearVelocity = boost
                        PointLaunch.Arrived = false
                        StateManager.Set(StateManager.States.Idle, true)
                        cameraPulse(0.35)
                        playSound("rbxasset://sounds/action_jump.mp3", 0.8, 1.25)
                        return true
                end
                PointLaunch.Arrived = false
                if StateManager.Current == StateManager.States.PointLaunching then
                        StateManager.Set(StateManager.States.Idle, true)
                end
                if Humanoid then
                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                return true
        end
        return false
end

function PointLaunch.Cancel()
        PointLaunch.Pulling = false
        PointLaunch.Arrived = false
        PointLaunch.Target = nil
        releaseWebs()
        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
        end
        if StateManager.Current == StateManager.States.PointLaunching then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [C] TIGHT GAP ZIP  (Tap Space near narrow openings)
--======================================================================
GapZip = { Active = false, Token = 0, Collisions = {} }

local function detectGap()
        if not (RootPart and Camera) then return nil end
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local origin = RootPart.Position + Vector3.new(0, 0.5, 0)

        local centerHit = Workspace:Raycast(origin, look * 60, RayParams)
        local centerDist = centerHit and centerHit.Distance or 60

        local halfSpace = CONFIG.GapShoulderSpacing * 0.5
        local hitL = Workspace:Raycast(origin - right * halfSpace, look * 45, RayParams)
        local hitR = Workspace:Raycast(origin + right * halfSpace, look * 45, RayParams)

        if hitL and hitR then
                local clearance = (hitL.Position - hitR.Position).Magnitude
                local avgDist = (hitL.Distance + hitR.Distance) * 0.5
                if clearance <= CONFIG.GapMaxClearance and clearance >= 1.5 and centerDist > avgDist + 6 then
                        local midPos = (hitL.Position + hitR.Position) * 0.5
                        local exitPos = midPos + look * (clearance * 0.5 + 4.5)
                        return midPos, exitPos, hitL.Position, hitR.Position
                end
        end

        for _, probeDist in ipairs({ 12, 20, 30 }) do
                if centerDist > probeDist + 5 then
                        local probeCenter = origin + look * probeDist
                        local sideL = Workspace:Raycast(probeCenter, -right * (CONFIG.GapMaxClearance * 0.6), RayParams)
                        local sideR = Workspace:Raycast(probeCenter, right * (CONFIG.GapMaxClearance * 0.6), RayParams)
                        if sideL and sideR then
                                local clearance = (sideL.Position - sideR.Position).Magnitude
                                if clearance <= CONFIG.GapMaxClearance and clearance >= 1.5 then
                                        local midPos = (sideL.Position + sideR.Position) * 0.5
                                        local exitPos = midPos + look * 8
                                        return midPos, exitPos, sideL.Position, sideR.Position
                                end
                        end
                end
        end
        return nil
end

function GapZip.TryBegin()
        if StateManager.Current == StateManager.States.SlingshotCharging then return false end
        if GapZip.Active then return false end
        if not (RootPart and Humanoid) then return false end

        local midPos, exitPos, hitLPos, hitRPos = detectGap()
        if not midPos then return false end

        GapZip.Active = true
        GapZip.Token = GapZip.Token + 1
        local token = GapZip.Token

        releaseWebs()
        if Swing.Active then Swing.End(true) end
        if PointLaunch.Pulling then PointLaunch.Cancel() end
        if Wings and Wings.Active then Wings.End() end

        StateManager.Set(StateManager.States.GapZipping, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        if hitLPos and hitRPos then
                local handL = handAttachment(getWebHand(true))
                local handR = handAttachment(getWebHand(false))
                local aL = anchorAttachment(nil, hitLPos)
                local aR = anchorAttachment(nil, hitRPos)
                local beamL = createWebBeam(aL, handL)
                local beamR = createWebBeam(aR, handR)
                webMaid:Give(handL)
                webMaid:Give(handR)
                webMaid:Give(aL)
                webMaid:Give(aR)
                webMaid:Give(beamL)
                webMaid:Give(beamR)
        end
        playSound("rbxasset://sounds/action_swish.mp3", 0.7, 1.35)

        local startPos = RootPart.Position
        local entrySpeed = RootPart.AssemblyLinearVelocity.Magnitude
        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        local yawCF = (flatLook.Magnitude > 0.05) and CFrame.lookAt(Vector3.new(0, 0, 0), flatLook.Unit) or CFrame.new()

        GapZip.Collisions = {}
        if Character then
                for _, part in ipairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then
                                GapZip.Collisions[part] = part.CanCollide
                                part.CanCollide = false
                        end
                end
        end

        local t0 = os.clock()
        local conn
        conn = RunService.Heartbeat:Connect(function()
                if token ~= GapZip.Token or Engine.Destroyed or not (RootPart and RootPart.Parent) then
                        conn:Disconnect()
                        GapZip.RestoreCollisions()
                        return
                end
                local alpha = math.clamp((os.clock() - t0) / CONFIG.GapZipDuration, 0, 1)
                RootPart.CFrame = CFrame.new(startPos:Lerp(exitPos, alpha)) * yawCF
                RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                if alpha >= 1 then
                        conn:Disconnect()
                        GapZip.RestoreCollisions()
                        releaseWebs()
                        local exitVel = Camera.CFrame.LookVector * (entrySpeed + CONFIG.GapExitBoost)
                        RootPart.AssemblyLinearVelocity = Vector3.new(exitVel.X, math.max(exitVel.Y, 8), exitVel.Z)
                        if Humanoid and Humanoid.Parent then
                                Humanoid.AutoRotate = true
                                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                        end
                        GapZip.Active = false
                        StateManager.Set(StateManager.States.Idle, true)
                        cameraPulse(0.3)
                        playSound("rbxasset://sounds/action_jump.mp3", 0.7, 1.2)
                end
        end)
        lifeMaid:Give(conn)
        return true
end

function GapZip.RestoreCollisions()
        if GapZip.Collisions then
                for part, canCollide in pairs(GapZip.Collisions) do
                        if part and part.Parent then
                                part.CanCollide = canCollide
                        end
                end
                GapZip.Collisions = {}
        end
end

--======================================================================
-- [D] DUAL-WEB GROUND SLINGSHOT  (Tap R, walk back with S, release)
--======================================================================
local Sling = {
        Phase = 0, T = 0, InitialDist = 0,
        AnchorA = nil, AnchorB = nil,
        AttachA = nil, AttachB = nil,
        BeamA = nil, BeamB = nil, HandA = nil, HandB = nil,
        PhaseStartTime = 0,
}

local COL_WHITE  = Color3.fromRGB(240, 240, 255)
local COL_YELLOW = Color3.fromRGB(255, 235, 130)
local COL_RED    = Color3.fromRGB(170, 20, 20)

local function slingColor(t)
        if t < 0.5 then
                return COL_WHITE:Lerp(COL_YELLOW, t / 0.5)
        end
        return COL_YELLOW:Lerp(COL_RED, (t - 0.5) / 0.5)
end

local function slingRaycast(sideSign)
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local dir = look + right * sideSign * 0.85 + Vector3.new(0, 0.35, 0)
        if dir.Magnitude < 0.05 then return nil end
        return Workspace:Raycast(Camera.CFrame.Position, dir.Unit * 95, RayParams)
end

function Sling.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then return end

        if Sling.Phase == 0 then
                if StateManager.Current ~= StateManager.States.Idle
                        and StateManager.Current ~= StateManager.States.GroundSliding then
                        return
                end

                local hitL = slingRaycast(-1)
                local hitR = slingRaycast(1)

                if hitL and hitR then
                        Sling.AnchorA = { Position = hitL.Position, Normal = hitL.Normal, Part = hitL.Instance }
                        Sling.AttachA = anchorAttachment(hitL.Instance, hitL.Position)
                        Sling.HandA = handAttachment(getWebHand(true))
                        Sling.BeamA = createWebBeam(Sling.AttachA, Sling.HandA)

                        Sling.AnchorB = { Position = hitR.Position, Normal = hitR.Normal, Part = hitR.Instance }
                        Sling.AttachB = anchorAttachment(hitR.Instance, hitR.Position)
                        Sling.HandB = handAttachment(getWebHand(false))
                        Sling.BeamB = createWebBeam(Sling.AttachB, Sling.HandB)

                        webMaid:Give(Sling.AttachA)
                        webMaid:Give(Sling.HandA)
                        webMaid:Give(Sling.BeamA)
                        webMaid:Give(Sling.AttachB)
                        webMaid:Give(Sling.HandB)
                        webMaid:Give(Sling.BeamB)

                        local mid = (Sling.AnchorA.Position + Sling.AnchorB.Position) * 0.5
                        Sling.InitialDist = (RootPart.Position - mid).Magnitude
                        Sling.T = 0
                        Sling.Phase = 2
                        Sling.PhaseStartTime = os.clock()
                        StateManager.Set(StateManager.States.SlingshotCharging, true)
                        playSound("rbxasset://sounds/action_swish.mp3", 0.65, 1.1)
                        return
                end

                local hit = hitL or hitR
                local isLeft = (hit == hitL)
                if not hit then return end

                Sling.Phase = 1
                Sling.PhaseStartTime = os.clock()
                Sling.AnchorA = { Position = hit.Position, Normal = hit.Normal, Part = hit.Instance }
                Sling.AttachA = anchorAttachment(hit.Instance, hit.Position)
                Sling.HandA = handAttachment(getWebHand(isLeft))
                Sling.BeamA = createWebBeam(Sling.AttachA, Sling.HandA)
                webMaid:Give(Sling.AttachA)
                webMaid:Give(Sling.HandA)
                webMaid:Give(Sling.BeamA)
                StateManager.Set(StateManager.States.SlingshotCharging, true)
                playSound("rbxasset://sounds/action_swish.mp3", 0.5, 1.2)

        elseif Sling.Phase == 1 then
                local hit = slingRaycast(1) or slingRaycast(1.2)
                if not hit then
                        Sling.Cancel()
                        return
                end
                Sling.AnchorB = { Position = hit.Position, Normal = hit.Normal, Part = hit.Instance }
                Sling.AttachB = anchorAttachment(hit.Instance, hit.Position)
                Sling.HandB = handAttachment(getWebHand(false))
                Sling.BeamB = createWebBeam(Sling.AttachB, Sling.HandB)
                webMaid:Give(Sling.AttachB)
                webMaid:Give(Sling.HandB)
                webMaid:Give(Sling.BeamB)
                local mid = (Sling.AnchorA.Position + Sling.AnchorB.Position) * 0.5
                Sling.InitialDist = (RootPart.Position - mid).Magnitude
                Sling.T = 0
                Sling.Phase = 2
                Sling.PhaseStartTime = os.clock()
                playSound("rbxasset://sounds/action_swish.mp3", 0.5, 1.2)

        elseif Sling.Phase == 2 then
                if Sling.T >= CONFIG.SlingMinT then
                        Sling.Launch()
                else
                        Sling.Cancel()
                end
        end
end

function Sling.Step(dt)
        if Sling.Phase == 0 or not (RootPart and Humanoid) then return end

        if os.clock() - Sling.PhaseStartTime > CONFIG.SlingTimeout then
                Sling.Cancel()
                return
        end

        if Humanoid.FloorMaterial == Enum.Material.Air then
                Sling.Cancel()
                return
        end

        if Sling.Phase ~= 2 then return end

        local posA = (Sling.AttachA and Sling.AttachA.WorldPosition) or Sling.AnchorA.Position
        local posB = (Sling.AttachB and Sling.AttachB.WorldPosition) or Sling.AnchorB.Position
        local mid = (posA + posB) * 0.5

        local currentDist = (RootPart.Position - mid).Magnitude
        Sling.T = math.clamp((currentDist - Sling.InitialDist) / CONFIG.SlingMaxStretch, 0, 1)
        Humanoid.WalkSpeed = Rig.DefaultWalkSpeed * (1 - Sling.T ^ 1.5)

        local col = slingColor(Sling.T)
        if Sling.BeamA and Sling.BeamA.Parent then
                Sling.BeamA.Color = ColorSequence.new(col)
        end
        if Sling.BeamB and Sling.BeamB.Parent then
                Sling.BeamB.Color = ColorSequence.new(col)
        end

        if Sling.T >= 1.0 then
                Sling.Launch()
        end
end

function Sling.Launch()
        local T = math.clamp(Sling.T, 0, 1)
        local dir = Camera.CFrame.LookVector + Vector3.new(0, math.sin(math.rad(CONFIG.SlingLaunchAngle)), 0)
        dir = (dir.Magnitude > 0.05) and dir.Unit or Vector3.new(0, 1, 0)
        Sling.Reset()
        if Humanoid and Humanoid.Parent then
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
        if RootPart and RootPart.Parent then
                RootPart.AssemblyLinearVelocity = dir * (T * CONFIG.SlingMaxSpeed)
        end
        StateManager.Set(StateManager.States.Idle, true)
        cameraPulse(0.45)
        playSound("rbxasset://sounds/action_jump.mp3", 0.9, 1.0)
end

function Sling.Cancel()
        Sling.Reset()
        if Humanoid and Humanoid.Parent then
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
        end
        if StateManager.Current == StateManager.States.SlingshotCharging then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

function Sling.Reset()
        Sling.Phase = 0
        Sling.T = 0
        Sling.AnchorA = nil
        Sling.AnchorB = nil
        Sling.AttachA = nil
        Sling.AttachB = nil
        Sling.BeamA = nil
        Sling.BeamB = nil
        Sling.HandA = nil
        Sling.HandB = nil
        releaseWebs()
end

--======================================================================
-- [E] WALL CRAWL / WALL SPRINT / WALL JUMP, LEDGE VAULT & CORNER TRANSFER
--======================================================================
Wall = {
        Crawling = false, Sprinting = false,
        WallNormal = nil, WallPart = nil, LastTravel = nil,
        CooldownUntil = 0,
}

local function castWall()
        if not RootPart then return nil end
        local look = Camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude < 0.05 then return nil end
        local hit = Workspace:Raycast(RootPart.Position, flatLook.Unit * CONFIG.WallDetectDist, RayParams)
        if not hit then return nil end
        if math.abs(hit.Normal.Y) > 0.3 then return nil end
        return hit
end

local function wallPostureCFrame(pos, normal, sprint, travelDir)
        if sprint then
                local dir = travelDir
                if not dir or dir.Magnitude < 0.05 then
                        dir = normal:Cross(Vector3.new(0, 1, 0))
                        if dir.Magnitude < 0.05 then
                                dir = normal:Cross(Vector3.new(1, 0, 0))
                        end
                end
                return CFrame.lookAt(pos, pos + dir.Unit, normal)
        end
        local upDir = travelDir
        if not upDir or upDir.Magnitude < 0.05 then
                upDir = Vector3.new(0, 1, 0)
        else
                upDir = upDir.Unit
        end
        upDir = upDir - normal * upDir:Dot(normal)
        upDir = (upDir.Magnitude > 0.05) and upDir.Unit or Vector3.new(0, 1, 0)
        return CFrame.lookAt(pos, pos - normal, upDir)
end

function Wall.Attach(hit)
        if not (RootPart and Humanoid) then return end
        if Wall.Crawling then return end
        if StateManager.Current == StateManager.States.SlingshotCharging then return end

        releaseWebs()
        if Swing.Active then Swing.End(true) end
        if PointLaunch.Pulling then PointLaunch.Cancel() end
        if Wings and Wings.Active then Wings.End() end
        if Dive and Dive.Active then Dive.End() end

        Wall.Crawling = true
        Wall.Sprinting = false
        Wall.WallNormal = hit.Normal
        Wall.WallPart = hit.Instance
        Wall.LastTravel = nil

        StateManager.Set(StateManager.States.WallCrawling, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        RootPart.CFrame = wallPostureCFrame(RootPart.Position, hit.Normal, false, nil)
        RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        playSound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.55, 1.1)
end

function Wall.Begin()
        if not (RootPart and Humanoid) then return end
        if Wall.Crawling then return end
        if StateManager.Current == StateManager.States.SlingshotCharging then return end
        local hit = castWall()
        if hit then
                Wall.Attach(hit)
        end
end

function Wall.Step(dt)
        if not Wall.Crawling or not (RootPart and Humanoid) then return end
        local n = Wall.WallNormal
        if not n then
                Wall.Detach()
                return
        end

        local probe = Workspace:Raycast(RootPart.Position, n * -1 * (CONFIG.WallStickOffset + 3), RayParams)
        if not probe or probe.Normal:Dot(n) < 0.6 then
                -- 1) ROOFTOP LEDGE VAULT: Check if we reached the roof lip!
                local roofCheck = Workspace:Raycast(RootPart.Position + Vector3.new(0, 2.5, 0) - n * 3.5, Vector3.new(0, -6, 0), RayParams)
                if roofCheck and roofCheck.Normal.Y > 0.65 then
                        Wall.Detach()
                        RootPart.CFrame = CFrame.new(roofCheck.Position + Vector3.new(0, 3, 0), roofCheck.Position + Vector3.new(0, 3, 0) - n)
                        RootPart.AssemblyLinearVelocity = -n * CONFIG.LedgeVaultForward + Vector3.new(0, CONFIG.LedgeVaultUp, 0)
                        playSound("rbxasset://sounds/action_jump.mp3", 0.6, 1.2)
                        return
                end

                -- 2) 90° WALL CORNER TRANSFER: wrap around outside building corner!
                if Wall.LastTravel and Wall.LastTravel.Magnitude > 0.05 then
                        local cornerOrigin = RootPart.Position + Wall.LastTravel * 2.5 - n * 1.5
                        local cornerDir = Wall.LastTravel * -1 * 5
                        local cornerHit = Workspace:Raycast(cornerOrigin, cornerDir, RayParams)
                        if cornerHit and math.abs(cornerHit.Normal.Y) < 0.3 and cornerHit.Normal:Dot(n) < 0.25 then
                                Wall.WallNormal = cornerHit.Normal
                                Wall.WallPart = cornerHit.Instance
                                RootPart.CFrame = wallPostureCFrame(cornerHit.Position + cornerHit.Normal * CONFIG.WallStickOffset, cornerHit.Normal, Wall.Sprinting, Wall.LastTravel)
                                return
                        end
                end

                Wall.Detach()
                return
        end
        n = probe.Normal
        Wall.WallNormal = n

        -- 3) INSIDE CORNER TRANSFER: running into a perpendicular facing wall
        if Wall.LastTravel and Wall.LastTravel.Magnitude > 0.05 then
                local insideHit = Workspace:Raycast(RootPart.Position, Wall.LastTravel * 3.5, RayParams)
                if insideHit and math.abs(insideHit.Normal.Y) < 0.3 and insideHit.Normal:Dot(n) < 0.25 then
                        Wall.WallNormal = insideHit.Normal
                        Wall.WallPart = insideHit.Instance
                        RootPart.CFrame = wallPostureCFrame(insideHit.Position + insideHit.Normal * CONFIG.WallStickOffset, insideHit.Normal, Wall.Sprinting, Wall.LastTravel)
                        return
                end
        end

        local wantSprint = Moves[5].Enabled and shiftHeld
        if wantSprint ~= Wall.Sprinting then
                Wall.Sprinting = wantSprint
                StateManager.Set(wantSprint and StateManager.States.WallSprinting or StateManager.States.WallCrawling, true)
        end

        local speed = Wall.Sprinting and CONFIG.SprintSpeed or CONFIG.CrawlSpeed
        local x, z = getInputVector()

        local rightOnWall = Camera.CFrame.RightVector - n * Camera.CFrame.RightVector:Dot(n)
        local lookOnWall  = Camera.CFrame.LookVector  - n * Camera.CFrame.LookVector:Dot(n)
        local moveDir = rightOnWall * x + lookOnWall * z
        local pos = RootPart.Position
        if moveDir.Magnitude > 0.05 then
                moveDir = moveDir.Unit
                Wall.LastTravel = moveDir
                pos = pos + moveDir * speed * dt

                if not Wall.Sprinting then
                        local cycle = math.sin(os.clock() * 12)
                        local rArm = Rig.Joints["RightShoulder"]
                        local lArm = Rig.Joints["LeftShoulder"]
                        if rArm and rArm.Motor and rArm.Motor.Parent then
                                rArm.Motor.C0 = rArm.Motor.C0:Lerp(rArm.C0 * CFrame.Angles(math.rad(cycle * 22), 0, 0), 0.3)
                        end
                        if lArm and lArm.Motor and lArm.Motor.Parent then
                                lArm.Motor.C0 = lArm.Motor.C0:Lerp(lArm.C0 * CFrame.Angles(-math.rad(cycle * 22), 0, 0), 0.3)
                        end
                end
        end

        local contact = Workspace:Raycast(pos + n * 2, n * -1 * 8, RayParams)
        if contact then
                pos = contact.Position + n * CONFIG.WallStickOffset
        end

        RootPart.CFrame = RootPart.CFrame:Lerp(
                wallPostureCFrame(pos, n, Wall.Sprinting, Wall.LastTravel), math.clamp(dt * 18, 0, 1)
        )
        RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

function Wall.Detach()
        if not Wall.Crawling then return end
        Wall.Crawling = false
        Wall.Sprinting = false
        Wall.WallNormal = nil
        Wall.WallPart = nil
        Wall.CooldownUntil = os.clock() + CONFIG.ReattachCooldown

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end

        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
        local st = StateManager.Current
        if st == StateManager.States.WallCrawling or st == StateManager.States.WallSprinting then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

function Wall.JumpOff()
        if not Wall.Crawling or not RootPart then return end
        local n = Wall.WallNormal or Camera.CFrame.LookVector
        Wall.Detach()
        RootPart.AssemblyLinearVelocity =
                n * CONFIG.WallJumpOut
                + Vector3.new(0, CONFIG.WallJumpUp, 0)
                + Camera.CFrame.LookVector * CONFIG.WallJumpLook
        cameraPulse(0.25)
        playSound("rbxasset://sounds/action_jump.mp3", 0.7, 1.2)
end

--======================================================================
-- [F] PROCEDURAL AIR TRICKS  (Hold G + WASD, airborne)
--======================================================================
local Tricks = { Active = false }

function Tricks.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then return end
        if Swing.Active or PointLaunch.Pulling or (Wall and Wall.Crawling) then return end
        if GapZip.Active or (Wings and Wings.Active) or (Dive and Dive.Active) then return end
        if Tricks.Active then return end

        Tricks.Active = true
        StateManager.Set(StateManager.States.AirTricking, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

function Tricks.Step(dt)
        if not Tricks.Active or not (RootPart and RootPart.Parent) then return end

        if altitudeAboveGround() < CONFIG.TrickMinAltitude then
                Tricks.End()
                return
        end

        local x, z = getInputVector()
        local flipStep = CONFIG.TrickFlipRate * dt * 60
        local rollStep = CONFIG.TrickRollRate * dt * 60

        if z > 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(math.rad(flipStep), 0, 0)
        elseif z < 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(math.rad(-flipStep), 0, 0)
        end
        if x ~= 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, 0, math.rad(rollStep * x))
        end

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder", "RightHip", "LeftHip" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        local tuckOffset
                        if Rig.IsR15 then
                                if jointName == "RightShoulder" then
                                        tuckOffset = CFrame.Angles(math.rad(140), 0, -math.rad(25))
                                elseif jointName == "LeftShoulder" then
                                        tuckOffset = CFrame.Angles(math.rad(140), 0, math.rad(25))
                                else
                                        tuckOffset = CFrame.Angles(math.rad(65), 0, 0)
                                end
                        else
                                if jointName == "RightShoulder" then
                                        tuckOffset = CFrame.Angles(0, 0, math.rad(140))
                                elseif jointName == "LeftShoulder" then
                                        tuckOffset = CFrame.Angles(0, 0, -math.rad(140))
                                elseif jointName == "RightHip" then
                                        tuckOffset = CFrame.Angles(0, 0, math.rad(65))
                                else
                                        tuckOffset = CFrame.Angles(0, 0, -math.rad(65))
                                end
                        end
                        data.Motor.C0 = data.Motor.C0:Lerp(data.C0 * tuckOffset, math.clamp(dt * 15, 0, 1))
                end
        end

        if RootPart.AssemblyLinearVelocity.Magnitude < 22 then
                RootPart.AssemblyLinearVelocity = Camera.CFrame.LookVector * 26
        end
end

function Tricks.RestoreJoints()
        for _, data in pairs(Rig.Joints) do
                if data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0:Lerp(data.C0, 0.22)
                end
        end
end

function Tricks.End()
        if not Tricks.Active then return end
        Tricks.Active = false
        startUprightRecovery(CONFIG.TrickRecoveryTime, function()
                if Humanoid and Humanoid.Parent then
                        Humanoid.AutoRotate = true
                        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end
                if StateManager.Current == StateManager.States.AirTricking then
                        StateManager.Set(StateManager.States.Idle, true)
                end
        end)
end

--======================================================================
-- [G] GROUND SLIDE  (Landing or Sprinting + Shift)
--======================================================================
local Slide = { Active = false, Dir = nil, RestoreProps = nil }

function Slide.TryBegin()
        if Slide.Active then return end
        if not (RootPart and Humanoid) then return end
        if StateManager.Current ~= StateManager.States.Idle and StateManager.Current ~= StateManager.States.WallCrawling then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then return end

        local vel = RootPart.AssemblyLinearVelocity
        local flat = Vector3.new(vel.X, 0, vel.Z)
        local minSpeed = sprintActive and CONFIG.SlideSprintMin or CONFIG.SlideMinSpeed
        if flat.Magnitude < minSpeed then return end

        Slide.Active = true
        Slide.Dir = flat.Unit
        Slide.RestoreProps = RootPart.CustomPhysicalProperties

        StateManager.Set(StateManager.States.GroundSliding, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, CONFIG.SlideDropOffset, 0)
        RootPart.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.5, 100, 1)

        if sprintActive and flat.Magnitude < 42 then
                RootPart.AssemblyLinearVelocity = Slide.Dir * 42 + Vector3.new(0, vel.Y, 0)
        end
        cameraPulse(0.2)
        playSound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.5, 0.8)
end

function Slide.Step(dt)
        if not Slide.Active or not (RootPart and RootPart.Parent) then return end

        local x, z = getInputVector()
        if x ~= 0 or z ~= 0 then
                local look = Camera.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)
                local steerDir = Camera.CFrame.RightVector * x + flatLook * z
                if steerDir.Magnitude > 0.05 then
                        Slide.Dir = Vector3.new(steerDir.X, 0, steerDir.Z).Unit
                end
        end

        local rHip = Rig.Joints["RightHip"]
        local lHip = Rig.Joints["LeftHip"]
        if rHip and rHip.Motor and rHip.Motor.Parent then
                rHip.Motor.C0 = rHip.Motor.C0:Lerp(rHip.C0 * CFrame.Angles(math.rad(75), 0, math.rad(10)), 0.25)
        end
        if lHip and lHip.Motor and lHip.Motor.Parent then
                lHip.Motor.C0 = lHip.Motor.C0:Lerp(lHip.C0 * CFrame.Angles(-math.rad(40), 0, -math.rad(15)), 0.25)
        end

        local vel = RootPart.AssemblyLinearVelocity
        local flat = Vector3.new(vel.X, 0, vel.Z)
        local newSpeed = math.max(flat.Magnitude - CONFIG.SlideDecel * dt, 0)
        RootPart.AssemblyLinearVelocity = Slide.Dir * newSpeed + Vector3.new(0, vel.Y, 0)

        if newSpeed <= CONFIG.SlideEndSpeed or Humanoid.FloorMaterial == Enum.Material.Air then
                Slide.End()
        end
end

function Slide.End()
        if not Slide.Active then return end
        Slide.Active = false
        if RootPart and RootPart.Parent then
                RootPart.CustomPhysicalProperties = Slide.RestoreProps
                RootPart.CFrame = RootPart.CFrame + Vector3.new(0, 1.5, 0)
        end
        for _, jointName in ipairs({ "RightHip", "LeftHip" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end
        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        Slide.RestoreProps = nil
        if StateManager.Current == StateManager.States.GroundSliding then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [H] QUICK AIR WEB ZIP  (Tap Space in mid-air)
--======================================================================
AirZip = { CooldownUntil = 0 }

function AirZip.Try()
        if not Moves[9] or not Moves[9].Enabled then return false end
        if not (RootPart and Humanoid) then return false end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then return false end
        if os.clock() < AirZip.CooldownUntil then return false end
        if StateManager.Current ~= StateManager.States.Idle and StateManager.Current ~= StateManager.States.Gliding then return false end

        AirZip.CooldownUntil = os.clock() + CONFIG.AirZipCooldown

        if Wings and Wings.Active then
                Wings.End()
        end

        local look = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local origin = RootPart.Position

        local attL = Instance.new("Attachment")
        attL.WorldPosition = origin + look * 80 - right * 10 + Vector3.new(0, 6, 0)
        attL.Parent = FXFolder

        local attR = Instance.new("Attachment")
        attR.WorldPosition = origin + look * 80 + right * 10 + Vector3.new(0, 6, 0)
        attR.Parent = FXFolder

        local handL = handAttachment(getWebHand(true))
        local handR = handAttachment(getWebHand(false))
        local beamL = createWebBeam(attL, handL)
        local beamR = createWebBeam(attR, handR)

        local m = Maid.new()
        m:Give(attL); m:Give(attR); m:Give(handL); m:Give(handR); m:Give(beamL); m:Give(beamR)
        task.delay(0.18, function() m:Cleanup() end)

        RootPart.AssemblyLinearVelocity = look * CONFIG.AirZipSpeed + Vector3.new(0, CONFIG.AirZipPop, 0)
        cameraPulse(0.25)
        playSound("rbxasset://sounds/action_swish.mp3", 0.75, 1.35)
        return true
end

--======================================================================
-- [I] WEB WINGS (GLIDING MODE)  (Tap Q in mid-air)
--======================================================================
Wings = {
        Active = false, Speed = 0,
        AttTorsoL = nil, AttTorsoR = nil,
        AttArmL = nil, AttArmR = nil,
        BeamL = nil, BeamR = nil,
}

function Wings.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then return end
        if Swing.Active or PointLaunch.Pulling or (Wall and Wall.Crawling) or GapZip.Active then return end
        if Wings.Active then return end

        if Dive and Dive.Active then Dive.End() end
        if Tricks and Tricks.Active then Tricks.End() end

        Wings.Active = true
        StateManager.Set(StateManager.States.Gliding, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        local vel = RootPart.AssemblyLinearVelocity
        local flat = Vector3.new(vel.X, 0, vel.Z)
        Wings.Speed = math.clamp(flat.Magnitude, CONFIG.GlidingMinSpeed, CONFIG.GlidingMaxSpeed)

        local torso = Character and (Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso"))
        local lArm = getWebHand(true)
        local rArm = getWebHand(false)
        if torso and lArm and rArm then
                Wings.AttTorsoL = Instance.new("Attachment")
                Wings.AttTorsoL.Name = "SpideyWingTorsoL"
                Wings.AttTorsoL.Position = Vector3.new(-0.8, -0.2, 0)
                Wings.AttTorsoL.Parent = torso

                Wings.AttTorsoR = Instance.new("Attachment")
                Wings.AttTorsoR.Name = "SpideyWingTorsoR"
                Wings.AttTorsoR.Position = Vector3.new(0.8, -0.2, 0)
                Wings.AttTorsoR.Parent = torso

                Wings.AttArmL = Instance.new("Attachment")
                Wings.AttArmL.Name = "SpideyWingArmL"
                Wings.AttArmL.Position = Vector3.new(0, -0.4, 0)
                Wings.AttArmL.Parent = lArm

                Wings.AttArmR = Instance.new("Attachment")
                Wings.AttArmR.Name = "SpideyWingArmR"
                Wings.AttArmR.Position = Vector3.new(0, -0.4, 0)
                Wings.AttArmR.Parent = rArm

                Wings.BeamL = Instance.new("Beam")
                Wings.BeamL.Attachment0 = Wings.AttTorsoL
                Wings.BeamL.Attachment1 = Wings.AttArmL
                Wings.BeamL.Width0 = 1.6
                Wings.BeamL.Width1 = 0.5
                Wings.BeamL.Color = ColorSequence.new(Color3.fromRGB(225, 230, 255))
                Wings.BeamL.Transparency = NumberSequence.new(0.3)
                Wings.BeamL.LightEmission = 0.25
                Wings.BeamL.FaceCamera = true
                Wings.BeamL.Parent = FXFolder

                Wings.BeamR = Instance.new("Beam")
                Wings.BeamR.Attachment0 = Wings.AttTorsoR
                Wings.BeamR.Attachment1 = Wings.AttArmR
                Wings.BeamR.Width0 = 1.6
                Wings.BeamR.Width1 = 0.5
                Wings.BeamR.Color = ColorSequence.new(Color3.fromRGB(225, 230, 255))
                Wings.BeamR.Transparency = NumberSequence.new(0.3)
                Wings.BeamR.LightEmission = 0.25
                Wings.BeamR.FaceCamera = true
                Wings.BeamR.Parent = FXFolder

                webMaid:Give(Wings.AttTorsoL)
                webMaid:Give(Wings.AttTorsoR)
                webMaid:Give(Wings.AttArmL)
                webMaid:Give(Wings.AttArmR)
                webMaid:Give(Wings.BeamL)
                webMaid:Give(Wings.BeamR)
        end

        cameraPulse(0.25)
        playSound("rbxasset://sounds/action_swish.mp3", 0.6, 1.4)
end

function Wings.Step(dt)
        if not Wings.Active or not (RootPart and RootPart.Parent) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then
                Wings.End()
                return
        end

        local x, z = getInputVector()
        local look = Camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)

        if z > 0 then
                Wings.Speed = math.min(Wings.Speed + 35 * dt, CONFIG.GlidingMaxSpeed + 15)
        elseif z < 0 then
                Wings.Speed = math.max(Wings.Speed - 25 * dt, CONFIG.GlidingMinSpeed)
        else
                if Wings.Speed < 65 then
                        Wings.Speed = Wings.Speed + 15 * dt
                end
        end

        local right = Camera.CFrame.RightVector
        local turnDir = flatLook + right * (x * 0.45)
        turnDir = (turnDir.Magnitude > 0.05) and turnDir.Unit or flatLook

        local sink = (z > 0) and -24 or (z < 0 and -6 or -CONFIG.GlidingSinkRate)
        RootPart.AssemblyLinearVelocity = turnDir * Wings.Speed + Vector3.new(0, sink, 0)

        local bankAngle = math.rad(-x * 22)
        local pitchAngle = math.rad((z > 0) and 20 or (z < 0 and -10 or 8))
        local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + turnDir) * CFrame.Angles(pitchAngle, 0, bankAngle)
        RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, math.clamp(dt * 12, 0, 1))

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        local isLeft = (jointName == "LeftShoulder")
                        local spreadCF
                        if Rig.IsR15 then
                                spreadCF = isLeft and CFrame.Angles(math.rad(10), 0, -math.rad(80)) or CFrame.Angles(math.rad(10), 0, math.rad(80))
                        else
                                spreadCF = isLeft and CFrame.Angles(0, 0, math.rad(80)) or CFrame.Angles(0, 0, -math.rad(80))
                        end
                        data.Motor.C0 = data.Motor.C0:Lerp(data.C0 * spreadCF, math.clamp(dt * 15, 0, 1))
                end
        end
end

function Wings.End()
        if not Wings.Active then return end
        Wings.Active = false
        if Wings.BeamL then pcall(function() Wings.BeamL:Destroy() end); Wings.BeamL = nil end
        if Wings.BeamR then pcall(function() Wings.BeamR:Destroy() end); Wings.BeamR = nil end
        if Wings.AttTorsoL then pcall(function() Wings.AttTorsoL:Destroy() end); Wings.AttTorsoL = nil end
        if Wings.AttTorsoR then pcall(function() Wings.AttTorsoR:Destroy() end); Wings.AttTorsoR = nil end
        if Wings.AttArmL then pcall(function() Wings.AttArmL:Destroy() end); Wings.AttArmL = nil end
        if Wings.AttArmR then pcall(function() Wings.AttArmR:Destroy() end); Wings.AttArmR = nil end

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end

        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                if Humanoid.FloorMaterial == Enum.Material.Air then
                        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end
        end
        if StateManager.Current == StateManager.States.Gliding then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [J] STEEP AIR DIVE  (LeftControl or C in mid-air)
--======================================================================
Dive = { Active = false, Speed = 0 }

function Dive.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then return end
        if Swing.Active or PointLaunch.Pulling or (Wall and Wall.Crawling) or GapZip.Active then return end
        if Dive.Active then return end

        if Wings and Wings.Active then Wings.End() end
        if Tricks and Tricks.Active then Tricks.End() end

        Dive.Active = true
        StateManager.Set(StateManager.States.AirDiving, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        local vel = RootPart.AssemblyLinearVelocity
        Dive.Speed = math.max(vel.Magnitude, 50)
        cameraPulse(0.3)
        playSound("rbxasset://sounds/action_swish.mp3", 0.7, 0.9)
end

function Dive.Step(dt)
        if not Dive.Active or not (RootPart and RootPart.Parent) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then
                Dive.End()
                if shiftHeld and Moves[8].Enabled then
                        Slide.TryBegin()
                end
                return
        end

        local vel = RootPart.AssemblyLinearVelocity
        local look = Camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)

        local forwardVel = flatLook * (math.max(math.sqrt(vel.X * vel.X + vel.Z * vel.Z), 35))
        local downVel = math.min(vel.Y - (Workspace.Gravity * CONFIG.DiveGravityMult) * dt, -CONFIG.DiveTerminalSpeed)
        RootPart.AssemblyLinearVelocity = Vector3.new(forwardVel.X, downVel, forwardVel.Z)

        local currentVel = RootPart.AssemblyLinearVelocity
        local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + currentVel.Unit)
        RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, math.clamp(dt * 16, 0, 1))

        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        local isLeft = (jointName == "LeftShoulder")
                        local tuckCF = isLeft and CFrame.Angles(-math.rad(25), 0, -math.rad(15)) or CFrame.Angles(-math.rad(25), 0, math.rad(15))
                        data.Motor.C0 = data.Motor.C0:Lerp(data.C0 * tuckCF, math.clamp(dt * 15, 0, 1))
                end
        end
end

function Dive.End()
        if not Dive.Active then return end
        Dive.Active = false
        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end
        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                if Humanoid.FloorMaterial == Enum.Material.Air then
                        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end
        end
        if StateManager.Current == StateManager.States.AirDiving then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [K] CORNER TETHERING  (Q or A/D during Web Swing)
--======================================================================
CornerTether = { LastWhip = 0 }

function CornerTether.CheckAndWhip(dt)
        if not Swing.Active or not RootPart then return end
        local isLeft = moveKeys.A
        local isRight = moveKeys.D
        if not (isLeft or isRight) then return end
        if os.clock() - CornerTether.LastWhip < 1.0 then return end

        local right = Camera.CFrame.RightVector
        local look = Camera.CFrame.LookVector
        local sideSign = isLeft and -1 or 1
        local rayDir = (look * 0.7 + right * sideSign * 0.7).Unit
        local hit = Workspace:Raycast(RootPart.Position, rayDir * CONFIG.CornerTetherDist, RayParams)
        if hit and math.abs(hit.Normal.Y) < 0.3 then
                CornerTether.LastWhip = os.clock()
                local vel = RootPart.AssemblyLinearVelocity
                local currentSpeed = math.max(vel.Magnitude, 70)

                local whipDir = hit.Normal:Cross(Vector3.new(0, sideSign, 0)).Unit
                RootPart.AssemblyLinearVelocity = whipDir * (currentSpeed * CONFIG.CornerWhipForce)

                local a0 = anchorAttachment(hit.Instance, hit.Position)
                local handAtt = handAttachment(getWebHand(isLeft))
                local beam = createWebBeam(a0, handAtt)
                task.delay(0.22, function()
                        pcall(function() beam:Destroy() end)
                        pcall(function() a0:Destroy() end)
                        pcall(function() handAtt:Destroy() end)
                end)

                cameraPulse(0.35)
                playSound("rbxasset://sounds/action_swish.mp3", 0.8, 1.4)
        end
end

--======================================================================
-- [L] GROUND CHARGE JUMP  (Hold Ctrl + Space on ground)
--======================================================================
ChargeJump = { Charging = false, StartTime = 0 }

function ChargeJump.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then return end
        if ChargeJump.Charging then return end

        ChargeJump.Charging = true
        ChargeJump.StartTime = os.clock()
        playSound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.4, 0.7)
end

function ChargeJump.Release()
        if not ChargeJump.Charging or not (RootPart and Humanoid) then return end
        ChargeJump.Charging = false

        for _, jointName in ipairs({ "RightHip", "LeftHip" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end

        local elapsed = os.clock() - ChargeJump.StartTime
        local ratio = math.clamp(elapsed / CONFIG.ChargeJumpMaxTime, 0.3, 1.0)
        local look = Camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)

        RootPart.AssemblyLinearVelocity = Vector3.new(
                flatLook.X * (CONFIG.ChargeJumpForward * ratio),
                CONFIG.ChargeJumpHeight * ratio,
                flatLook.Z * (CONFIG.ChargeJumpForward * ratio)
        )
        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        cameraPulse(0.3)
        playSound("rbxasset://sounds/action_jump.mp3", 0.85, 1.15)
end

--======================================================================
-- GLOBAL CLEANUP (death / respawn / destroy)
--======================================================================
local function fullCleanup()
        Swing.Active = false
        Swing.PrevDir = nil
        Swing.AnchorPart = nil
        Swing.AnchorPos = nil
        Swing.Attach0 = nil
        Swing.RootAttach = nil
        Swing.Rope = nil
        Swing.HandAttach = nil
        Swing.Beam = nil
        Swing.IsLeft = false

        PointLaunch.Pulling = false
        PointLaunch.Arrived = false
        PointLaunch.Target = nil

        GapZip.Active = false
        GapZip.Token = GapZip.Token + 1
        GapZip.RestoreCollisions()

        Sling.Phase = 0
        Sling.T = 0
        Sling.AnchorA = nil
        Sling.AnchorB = nil
        Sling.AttachA = nil
        Sling.AttachB = nil
        Sling.BeamA = nil
        Sling.BeamB = nil
        Sling.HandA = nil
        Sling.HandB = nil

        Wall.Crawling = false
        Wall.Sprinting = false
        Wall.WallNormal = nil
        Wall.WallPart = nil

        Tricks.Active = false
        Slide.Active = false
        if Wings then Wings.End() end
        if Dive then Dive.End() end
        ChargeJump.Charging = false

        if RootPart and RootPart.Parent then
                RootPart.CustomPhysicalProperties = Slide.RestoreProps
        end
        Slide.RestoreProps = nil

        Recovery.Active = false
        Recovery.After = nil
        stuckTimer = 0
        sprintActive = false
        releaseWebs()

        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
        end
        for _, data in pairs(Rig.Joints) do
                if data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.C0
                end
        end
        StateManager.Set(StateManager.States.Idle, true)
end

--======================================================================
-- UI THEME + HELPERS
--======================================================================
local GUI = nil
local uiRefs = { BindButtons = {}, ResetButtons = {}, Toggles = {}, Knobs = {} }
local captureMove = nil
local panelVisible = true
local uiMain = nil
local panelIcon = nil
local reticleFrame = nil
local togglePanel

local THEME = {
        Background = Color3.fromRGB(20, 20, 25),
        Row        = Color3.fromRGB(32, 32, 42),
        Text       = Color3.fromRGB(235, 235, 245),
        SubText    = Color3.fromRGB(160, 160, 180),
        Accent     = Color3.fromRGB(210, 40, 45),
        On         = Color3.fromRGB(60, 200, 95),
        Off        = Color3.fromRGB(215, 70, 70),
        Bind       = Color3.fromRGB(45, 45, 58),
        Yellow     = Color3.fromRGB(255, 210, 60),
        Cyan       = Color3.fromRGB(100, 220, 255),
}

local function make(class, props, parent)
        local inst = Instance.new(class)
        for k, v in pairs(props) do
                inst[k] = v
        end
        inst.Parent = parent
        return inst
end

local function addCorner(inst, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = inst
end

local function mountGui(gui)
        local ok = pcall(function()
                local target
                if typeof(gethui) == "function" then
                        target = gethui()
                else
                        target = game:GetService("CoreGui")
                end
                gui.Parent = target
        end)
        if not ok or not gui.Parent then
                gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
end

--======================================================================
-- MOBILE TOUCH CANVAS SYSTEM (Ergonomic 4x3 Responsive Grid)
--======================================================================
local mobileEnabled = false
local mobileLocked = true
local mobileGui = nil
local mobileButtons = {}
local mobileDrag = nil

local MOBILE_SHORT = {
        [1]  = "SWING",   [2]  = "LAUNCH", [3]  = "GAP ZIP",
        [4]  = "SLING",   [5]  = "SPRINT", [6]  = "CLIMB",
        [7]  = "TRICK",   [8]  = "SLIDE",  [9]  = "AIR ZIP",
        [10] = "WINGS",   [11] = "DIVE",   [12] = "CHARGE",
}

local function mobileTrigger(index, isDown)
        if not isDown then
                if index == 1 and Swing.Active then
                        Swing.End(true)
                elseif index == 5 then
                        shiftHeld = false
                        Wall.Sprinting = false
                        if StateManager.Current == StateManager.States.WallSprinting then
                                StateManager.Set(StateManager.States.WallCrawling, true)
                        end
                        if Slide.Active then
                                Slide.End()
                        end
                elseif index == 7 and Tricks.Active then
                        Tricks.End()
                elseif index == 11 and Dive.Active then
                        Dive.End()
                elseif index == 12 and ChargeJump.Charging then
                        ChargeJump.Release()
                end
                return
        end

        local move = Moves[index]
        if not move or not move.Enabled then return end

        if index == 1 then
                if Wall.Crawling then Wall.Detach() end
                Swing.Begin()
        elseif index == 2 then
                PointLaunch.Begin()
        elseif index == 3 then
                if Wall.Crawling then
                        Wall.JumpOff()
                        return
                end
                if StateManager.Current == StateManager.States.Swinging and Swing.Active then
                        Swing.End(true)
                        return
                end
                if not PointLaunch.TryBoost() then
                        GapZip.TryBegin()
                end
        elseif index == 4 then
                Sling.Begin()
        elseif index == 5 then
                shiftHeld = true
                Slide.TryBegin()
        elseif index == 6 then
                Wall.Begin()
        elseif index == 7 then
                Tricks.Begin()
        elseif index == 8 then
                Slide.TryBegin()
        elseif index == 9 then
                AirZip.Try()
        elseif index == 10 then
                if Wings.Active then
                        Wings.End()
                else
                        Wings.Begin()
                end
        elseif index == 11 then
                Dive.Begin()
        elseif index == 12 then
                ChargeJump.Begin()
        end
end

local function updateMobileLockVisual()
        for _, entry in pairs(mobileButtons) do
                if entry.Stroke and entry.Stroke.Parent then
                        entry.Stroke.Transparency = mobileLocked and 1 or 0
                end
        end
end

local function refreshMobileButtons()
        if mobileGui then
                pcall(function() mobileGui:Destroy() end)
                mobileGui = nil
        end
        mobileButtons = {}
        if not mobileEnabled then return end

        mobileGui = Instance.new("ScreenGui")
        mobileGui.Name = "SpideyMobileCanvas"
        mobileGui.ResetOnSpawn = false
        mobileGui.IgnoreGuiInset = true
        mobileGui.DisplayOrder = 999

        local slot = 0
        for index = 1, #Moves do
                local move = Moves[index]
                if move and move.Enabled then
                        slot = slot + 1
                        local col = (slot - 1) % 4
                        local row = math.floor((slot - 1) / 4)
                        local btn = Instance.new("TextButton")
                        btn.Name = "Mobile_" .. tostring(index)
                        btn.Size = UDim2.fromOffset(58, 58)
                        btn.Position = UDim2.new(1, -260 + col * 64, 1, -68 - row * 64)
                        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                        btn.BackgroundTransparency = 0.35
                        btn.BorderSizePixel = 0
                        btn.AutoButtonColor = false
                        btn.Text = MOBILE_SHORT[index] or move.Name
                        btn.TextColor3 = Color3.fromRGB(240, 240, 250)
                        btn.Font = Enum.Font.GothamBold
                        btn.TextSize = 10
                        addCorner(btn, 12)
                        local stroke = Instance.new("UIStroke")
                        stroke.Color = THEME.Yellow
                        stroke.Thickness = 2
                        stroke.Transparency = mobileLocked and 1 or 0
                        stroke.Parent = btn

                        btn.InputBegan:Connect(function(input)
                                local t = input.UserInputType
                                if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                                        if not mobileLocked then
                                                mobileDrag = { Btn = btn, Input = input, StartInput = input.Position, StartPos = btn.Position }
                                        else
                                                mobileTrigger(index, true)
                                        end
                                end
                        end)
                        btn.InputEnded:Connect(function(input)
                                local t = input.UserInputType
                                if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                                        if mobileDrag and mobileDrag.Input == input then
                                                mobileDrag = nil
                                        end
                                        if mobileLocked then
                                                mobileTrigger(index, false)
                                        end
                                end
                        end)

                        btn.Parent = mobileGui
                        mobileButtons[index] = { Button = btn, Stroke = stroke }
                end
        end
        mountGui(mobileGui)
end

--======================================================================
-- UI ROW BUILDERS
--======================================================================
local function updateToggleVisual(index)
        local move = Moves[index]
        local toggleBtn = uiRefs.Toggles[index]
        local knob = uiRefs.Knobs[index]
        if not (toggleBtn and knob) then return end
        toggleBtn.BackgroundColor3 = move.Enabled and THEME.On or THEME.Off
        knob.Position = UDim2.new(0, move.Enabled and 23 or 3, 0.5, -8)
end

local function buildMoveRow(parent, move, index)
        local row = make("Frame", {
                Size = UDim2.new(1, -8, 0, 40),
                BackgroundColor3 = THEME.Row,
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                LayoutOrder = index,
        }, parent)
        addCorner(row, 6)

        make("TextLabel", {
                Size = UDim2.new(0, 148, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = move.Name,
                TextColor3 = THEME.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        local toggleBtn = make("TextButton", {
                Size = UDim2.fromOffset(42, 22),
                Position = UDim2.new(0, 164, 0.5, -11),
                BackgroundColor3 = move.Enabled and THEME.On or THEME.Off,
                Text = "",
                BorderSizePixel = 0,
                AutoButtonColor = false,
        }, row)
        addCorner(toggleBtn, 11)
        local knob = make("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, move.Enabled and 23 or 3, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(245, 245, 250),
                BorderSizePixel = 0,
        }, toggleBtn)
        addCorner(knob, 8)

        local bindBtn = make("TextButton", {
                Size = UDim2.fromOffset(116, 24),
                Position = UDim2.new(0, 214, 0.5, -12),
                BackgroundColor3 = THEME.Bind,
                Text = move.Key and move.Key.Name or "AUTO",
                TextColor3 = THEME.Text,
                Font = Enum.Font.Code,
                TextSize = 12,
                BorderSizePixel = 0,
                AutoButtonColor = false,
        }, row)
        addCorner(bindBtn, 6)

        local resetBtn = make("TextButton", {
                Size = UDim2.fromOffset(46, 24),
                Position = UDim2.new(0, 336, 0.5, -12),
                BackgroundColor3 = THEME.Bind,
                Text = "RST",
                TextColor3 = THEME.SubText,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                BorderSizePixel = 0,
                AutoButtonColor = false,
        }, row)
        addCorner(resetBtn, 6)

        uiRefs.Toggles[index] = toggleBtn
        uiRefs.Knobs[index] = knob
        uiRefs.BindButtons[index] = bindBtn
        uiRefs.ResetButtons[index] = resetBtn

        toggleBtn.Activated:Connect(function()
                move.Enabled = not move.Enabled
                updateToggleVisual(index)
                refreshMobileButtons()
        end)

        bindBtn.Activated:Connect(function()
                if not move.Key then return end
                captureMove = index
                bindBtn.Text = "...Press Key..."
                bindBtn.TextColor3 = THEME.Yellow
        end)

        resetBtn.Activated:Connect(function()
                move.Key = move.Default
                if captureMove == index then
                        captureMove = nil
                end
                bindBtn.Text = move.Key and move.Key.Name or "AUTO"
                bindBtn.TextColor3 = THEME.Text
        end)
end

local function buildMobileRow(parent, orderIndex, label, callback, initialState)
        local row = make("Frame", {
                Size = UDim2.new(1, -8, 0, 40),
                BackgroundColor3 = THEME.Row,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                LayoutOrder = orderIndex,
        }, parent)
        addCorner(row, 6)

        make("TextLabel", {
                Size = UDim2.new(0, 250, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = THEME.SubText,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        local state = initialState
        local toggleBtn = make("TextButton", {
                Size = UDim2.fromOffset(42, 22),
                Position = UDim2.new(1, -56, 0.5, -11),
                BackgroundColor3 = state and THEME.On or THEME.Off,
                Text = "",
                BorderSizePixel = 0,
                AutoButtonColor = false,
        }, row)
        addCorner(toggleBtn, 11)
        local knob = make("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, state and 23 or 3, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(245, 245, 250),
                BorderSizePixel = 0,
        }, toggleBtn)
        addCorner(knob, 8)

        toggleBtn.Activated:Connect(function()
                state = not state
                toggleBtn.BackgroundColor3 = state and THEME.On or THEME.Off
                knob.Position = UDim2.new(0, state and 23 or 3, 0.5, -8)
                callback(state)
        end)
end

local function buildUI()
        GUI = Instance.new("ScreenGui")
        GUI.Name = "SpideyEngineUI"
        GUI.ResetOnSpawn = false
        GUI.IgnoreGuiInset = true
        GUI.DisplayOrder = 1000

        -- HUD Target Reticle (Insomniac Zip-to-Point HUD)
        reticleFrame = make("Frame", {
                Name = "SpideyReticle",
                Size = UDim2.fromOffset(22, 22),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                Visible = false,
        }, GUI)
        local reticleCorner = Instance.new("UICorner")
        reticleCorner.CornerRadius = UDim.new(1, 0)
        reticleCorner.Parent = reticleFrame
        local reticleStroke = Instance.new("UIStroke")
        reticleStroke.Color = THEME.Cyan
        reticleStroke.Thickness = 2
        reticleStroke.Transparency = 0.4
        reticleStroke.Parent = reticleFrame

        local main = make("Frame", {
                Name = "MainPanel",
                Size = UDim2.fromOffset(450, 400),
                Position = UDim2.new(0.5, -225, 0.5, -200),
                BackgroundColor3 = THEME.Background,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Active = true,
        }, GUI)
        addCorner(main, 8)
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(120, 120, 150)
        outline.Transparency = 0.55
        outline.Parent = main
        uiMain = main

        local header = make("Frame", {
                Name = "Header",
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Color3.fromRGB(28, 28, 36),
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Active = true,
        }, main)
        addCorner(header, 8)

        make("Frame", {
                Size = UDim2.new(0, 4, 1, -12),
                Position = UDim2.new(0, 10, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = THEME.Accent,
                BorderSizePixel = 0,
        }, header)

        make("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 24, 0, 0),
                BackgroundTransparency = 1,
                Text = "SPIDER-MAN MOVEMENT ENGINE v3.6",
                TextColor3 = THEME.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, header)

        make("TextLabel", {
                Size = UDim2.new(0, 60, 1, 0),
                Position = UDim2.new(1, -104, 0, 0),
                BackgroundTransparency = 1,
                Text = "RShift",
                TextColor3 = THEME.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
        }, header)

        local closeBtn = make("TextButton", {
                Size = UDim2.fromOffset(26, 26),
                Position = UDim2.new(1, -34, 0.5, -13),
                BackgroundColor3 = THEME.Bind,
                Text = "X",
                TextColor3 = THEME.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                BorderSizePixel = 0,
                AutoButtonColor = false,
        }, header)
        addCorner(closeBtn, 6)
        closeBtn.Activated:Connect(function()
                if panelVisible then
                        togglePanel()
                end
        end)

        local scroll = make("ScrollingFrame", {
                Name = "Rows",
                Size = UDim2.new(1, -16, 1, -48),
                Position = UDim2.new(0, 8, 0, 40),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 5,
                ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150),
                AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
        }, main)

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        for index = 1, #Moves do
                buildMoveRow(scroll, Moves[index], index)
        end
        buildMobileRow(scroll, 20, "Enable Mobile Buttons", function(state)
                mobileEnabled = state
                refreshMobileButtons()
        end, mobileEnabled)
        buildMobileRow(scroll, 21, "Lock Mobile Layout", function(state)
                mobileLocked = state
                updateMobileLockVisual()
        end, mobileLocked)
        buildMobileRow(scroll, 22, "Show Target Reticle (HUD)", function(state)
                CONFIG.ReticleEnabled = state
                if reticleFrame then
                        reticleFrame.Visible = state
                end
        end, CONFIG.ReticleEnabled)

        local headerDrag = nil
        header.InputBegan:Connect(function(input)
                local t = input.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                        headerDrag = { Input = input, StartInput = input.Position, StartPos = main.Position }
                end
        end)
        header.InputEnded:Connect(function(input)
                if headerDrag and headerDrag.Input == input then
                        headerDrag = nil
                end
        end)

        local iconDrag = nil
        local icon = make("TextButton", {
                Name = "SpideyToggleIcon",
                Size = UDim2.fromOffset(52, 52),
                Position = UDim2.new(1, -70, 0.3, 0),
                BackgroundColor3 = THEME.Accent,
                Text = "S",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.GothamBlack,
                TextSize = 24,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Active = true,
                Visible = false,
        }, GUI)
        addCorner(icon, 26)
        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = Color3.fromRGB(255, 255, 255)
        iconStroke.Transparency = 0.35
        iconStroke.Thickness = 2
        iconStroke.Parent = icon
        panelIcon = icon

        icon.InputBegan:Connect(function(input)
                local t = input.UserInputType
                if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                        iconDrag = { Input = input, StartInput = input.Position, StartPos = icon.Position, Moved = false }
                end
        end)
        icon.InputEnded:Connect(function(input)
                if iconDrag and iconDrag.Input == input then
                        if not iconDrag.Moved then
                                togglePanel()
                        end
                        iconDrag = nil
                end
        end)

        track(UserInputService.InputChanged:Connect(function(input)
                local t = input.UserInputType
                if headerDrag and headerDrag.Input == input then
                        local delta = input.Position - headerDrag.StartInput
                        main.Position = UDim2.new(
                                headerDrag.StartPos.X.Scale, headerDrag.StartPos.X.Offset + delta.X,
                                headerDrag.StartPos.Y.Scale, headerDrag.StartPos.Y.Offset + delta.Y
                        )
                elseif mobileDrag and mobileDrag.Input == input then
                        local delta = input.Position - mobileDrag.StartInput
                        mobileDrag.Btn.Position = UDim2.new(
                                mobileDrag.StartPos.X.Scale, mobileDrag.StartPos.X.Offset + delta.X,
                                mobileDrag.StartPos.Y.Scale, mobileDrag.StartPos.Y.Offset + delta.Y
                        )
                elseif iconDrag and iconDrag.Input == input then
                        local delta = input.Position - iconDrag.StartInput
                        if delta.Magnitude > 6 then
                                iconDrag.Moved = true
                        end
                        icon.Position = UDim2.new(
                                iconDrag.StartPos.X.Scale, iconDrag.StartPos.X.Offset + delta.X,
                                iconDrag.StartPos.Y.Scale, iconDrag.StartPos.Y.Offset + delta.Y
                        )
                end
        end))

        mountGui(GUI)
end

--======================================================================
-- PANEL TOGGLE + KEY CAPTURE
--======================================================================
function togglePanel()
        panelVisible = not panelVisible
        if uiMain and uiMain.Parent then
                uiMain.Visible = panelVisible
        end
        if panelIcon and panelIcon.Parent then
                panelIcon.Visible = not panelVisible
        end
end

local function finishCapture(key)
        if not captureMove then return end
        local index = captureMove
        captureMove = nil
        local btn = uiRefs.BindButtons[index]
        if key then
                Moves[index].Key = key
        end
        if btn then
                btn.Text = Moves[index].Key and Moves[index].Key.Name or "AUTO"
                btn.TextColor3 = THEME.Text
        end
end

--======================================================================
-- KEYBOARD ROUTING
--======================================================================
local function handleKeyBegan(key)
        -- E: Web Swing
        if key == Moves[1].Key then
                if Moves[1].Enabled then
                        if Wall.Crawling then
                                Wall.Detach()
                        end
                        Swing.Begin()
                end
                return
        end

        -- F: Point Launch
        if key == Moves[2].Key and Moves[2].Enabled then
                PointLaunch.Begin()
                return
        end

        -- Space: Wall Jump > Swing Pop > Mid/Perch Boost > Gap Zip > Quick Air Zip / Charge Jump
        if key == Moves[3].Key or key == Enum.KeyCode.Space then
                if ctrlHeld and Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air and Moves[12].Enabled then
                        ChargeJump.Begin()
                        return
                end
                if Wall.Crawling or StateManager.Current == StateManager.States.WallSprinting then
                        Wall.JumpOff()
                        return
                end
                if StateManager.Current == StateManager.States.Swinging and Swing.Active then
                        Swing.End(true)
                        return
                end
                if PointLaunch.TryBoost() then
                        return
                end
                if Moves[3].Enabled and GapZip.TryBegin() then
                        return
                end
                if Moves[9] and Moves[9].Enabled and AirZip.Try() then
                        return
                end
                return
        end

        -- R: Dual-Web Slingshot
        if key == Moves[4].Key and Moves[4].Enabled then
                Sling.Begin()
                return
        end

        -- LeftShift: Sprint + Ground Slide
        if key == Moves[5].Key or key == Moves[8].Key then
                shiftHeld = true
                if Moves[8].Enabled then
                        Slide.TryBegin()
                end
                return
        end

        -- G: Air Tricks
        if key == Moves[7].Key and Moves[7].Enabled then
                Tricks.Begin()
                return
        end

        -- Q: Web Wings (Gliding) / Corner Tether
        if key == Moves[10].Key then
                if Swing.Active then
                        CornerTether.CheckAndWhip(0)
                        return
                end
                if Moves[10].Enabled then
                        if Wings.Active then
                                Wings.End()
                        else
                                Wings.Begin()
                        end
                end
                return
        end

        -- LeftControl / C: Steep Air Dive or Crouch Charge Jump
        if key == Moves[11].Key or key == Enum.KeyCode.C then
                ctrlHeld = true
                if Humanoid and Humanoid.FloorMaterial == Enum.Material.Air then
                        if Moves[11].Enabled then
                                Dive.Begin()
                        end
                else
                        if Moves[8].Enabled then
                                Slide.TryBegin()
                        end
                end
                return
        end
end

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if Engine.Destroyed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode

        if key == Enum.KeyCode.RightShift then
                togglePanel()
                return
        end

        local moveKeyFlag = MOVE_KEYS_MAP[key]
        if moveKeyFlag then
                moveKeys[moveKeyFlag] = true
        end
        if key == Moves[5].Key then
                shiftHeld = true
        end

        if captureMove then
                if key == Enum.KeyCode.Escape then
                        finishCapture(nil)
                else
                        finishCapture(key)
                end
                return
        end

        if gameProcessed and key ~= Enum.KeyCode.Space and key ~= Enum.KeyCode.Q then
                return
        end

        handleKeyBegan(key)
end))

track(UserInputService.InputEnded:Connect(function(input)
        if Engine.Destroyed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode

        local moveKeyFlag = MOVE_KEYS_MAP[key]
        if moveKeyFlag then
                moveKeys[moveKeyFlag] = false
        end
        if key == Moves[5].Key then
                shiftHeld = false
        end
        if key == Moves[11].Key or key == Enum.KeyCode.C then
                ctrlHeld = false
                if Dive.Active then
                        Dive.End()
                end
        end

        if key == Enum.KeyCode.Space and ChargeJump.Charging then
                ChargeJump.Release()
        end

        if Swing.Active and key == Moves[1].Key then
                Swing.End(true)
        end
        if key == Moves[5].Key or key == Moves[8].Key then
                if Wall.Sprinting then
                        Wall.Sprinting = false
                        if StateManager.Current == StateManager.States.WallSprinting then
                                StateManager.Set(StateManager.States.WallCrawling, true)
                        end
                end
                if Slide.Active then
                        Slide.End()
                end
        end
        if Tricks.Active and key == Moves[7].Key then
                Tricks.End()
        end
end))

--======================================================================
-- DYNAMIC CAMERA FOV, MICRO-SHAKE & HUD RETICLE
--======================================================================
RunService:BindToRenderStep("SpideyCamera_v3", Enum.RenderPriority.Camera.Value + 1, function(dt)
        if Engine.Destroyed then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
                if not Camera then return end
        end

        local targetFOV
        if Sling.Phase == 2 then
                targetFOV = CONFIG.FOVBase + Sling.T * (CONFIG.FOVMax - CONFIG.FOVBase)
        elseif Wings and Wings.Active then
                targetFOV = CONFIG.FOVBase + 12
        elseif Dive and Dive.Active then
                targetFOV = CONFIG.FOVBase + 22
        else
                local speed = 0
                if RootPart and RootPart.Parent then
                        speed = RootPart.AssemblyLinearVelocity.Magnitude
                end
                targetFOV = math.clamp(
                        CONFIG.FOVBase + (speed / CONFIG.FOVSpeedDivisor) * CONFIG.FOVSpeedGain,
                        CONFIG.FOVBase, CONFIG.FOVMax
                )
        end
        Camera.FieldOfView = Camera.FieldOfView + (targetFOV - Camera.FieldOfView) * CONFIG.FOVLerp

        -- Dynamic HUD Reticle Tracking
        if CONFIG.ReticleEnabled and reticleFrame then
                local hitTarget = nil
                if RootPart then
                        local hit = Workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 280, RayParams)
                        if hit and (hit.Position - RootPart.Position).Magnitude > 10 then
                                hitTarget = hit.Position
                        end
                end

                if hitTarget then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(hitTarget)
                        if onScreen and screenPos.Z > 0 then
                                reticleFrame.Visible = true
                                reticleFrame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
                        else
                                reticleFrame.Visible = false
                        end
                else
                        reticleFrame.Visible = false
                end
        end

        if shakeTimer > 0 then
                shakeTimer = math.max(shakeTimer - dt, 0)
                local mag = math.min(shakeTimer * 0.3, 0.14)
                if mag > 0.001 then
                        Camera.CFrame = Camera.CFrame * CFrame.new(
                                (math.random() - 0.5) * mag,
                                (math.random() - 0.5) * mag,
                                0
                        )
                end
        elseif RootPart and RootPart.Parent then
                local speed = RootPart.AssemblyLinearVelocity.Magnitude
                if speed > 140 then
                        local intensity = math.clamp((speed - 140) / 500, 0, 0.06)
                        Camera.CFrame = Camera.CFrame * CFrame.new(
                                (math.random() - 0.5) * intensity,
                                (math.random() - 0.5) * intensity,
                                0
                        )
                end
        end
end)

--======================================================================
-- MAIN PHYSICS DISPATCH (Heartbeat)
--======================================================================
track(RunService.Heartbeat:Connect(function(dt)
        if Engine.Destroyed then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
        end
        if not (RootPart and RootPart.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0) then
                if LocalPlayer.Character and LocalPlayer.Character ~= Character then
                        refreshRig()
                        fullCleanup()
                end
                return
        end

        -- 1) Upright recovery pass
        if Recovery.Active then
                local alpha = math.clamp((os.clock() - Recovery.T0) / Recovery.Duration, 0, 1)
                Tricks.RestoreJoints()
                local look = Camera.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                flat = (flat.Magnitude > 0.05) and flat.Unit or Vector3.new(0, 0, -1)
                local targetRot = CFrame.lookAt(Vector3.new(0, 0, 0), flat)
                RootPart.CFrame = CFrame.new(RootPart.Position) * Recovery.FromRot:Lerp(targetRot, alpha)
                if alpha >= 1 then
                        Recovery.Active = false
                        for _, data in pairs(Rig.Joints) do
                                if data.Motor and data.Motor.Parent then
                                        data.Motor.C0 = data.C0
                                end
                        end
                        if Humanoid and Humanoid.Parent then
                                Humanoid.AutoRotate = true
                        end
                        local callback = Recovery.After
                        Recovery.After = nil
                        if typeof(callback) == "function" then
                                callback()
                        end
                end
        end

        -- 1.2) Ground Charge Jump Pose
        if ChargeJump.Charging then
                for _, jointName in ipairs({ "RightHip", "LeftHip" }) do
                        local data = Rig.Joints[jointName]
                        if data and data.Motor and data.Motor.Parent then
                                data.Motor.C0 = data.Motor.C0:Lerp(data.C0 * CFrame.Angles(math.rad(60), 0, 0), 0.2)
                        end
                end
        end

        -- 1.5) Passive wall attach
        if not Wall.Crawling
                and Moves[6].Enabled
                and os.clock() > Wall.CooldownUntil
                and StateManager.Current == StateManager.States.Idle then
                local look = Camera and Camera.CFrame.LookVector
                if look then
                        local flatLook = Vector3.new(look.X, 0, look.Z)
                        if flatLook.Magnitude > 0.05 then
                                local probe = Workspace:Raycast(
                                        RootPart.Position,
                                        flatLook.Unit * CONFIG.PassiveWallDist,
                                        RayParams
                                )
                                if probe and math.abs(probe.Normal.Y) < 0.3 then
                                        local airborne = Humanoid.FloorMaterial == Enum.Material.Air
                                        local runningAtWall = moveKeys.W and look:Dot(probe.Normal * -1) > 0.45
                                        if airborne or runningAtWall then
                                                Wall.Attach(probe)
                                        end
                                end
                        end
                end
        end

        -- 1.6) Ground sprint
        local wantSprint = Moves[5].Enabled and shiftHeld
                and not Wall.Crawling and Sling.Phase ~= 2
                and Humanoid.FloorMaterial ~= Enum.Material.Air
                and StateManager.Current ~= StateManager.States.SlingshotCharging
                and StateManager.Current ~= StateManager.States.PointLaunching
        if wantSprint and not sprintActive then
                sprintActive = true
                Rig.DefaultWalkSpeed = Humanoid.WalkSpeed
                Humanoid.WalkSpeed = CONFIG.RunSpeed
        elseif not wantSprint and sprintActive then
                sprintActive = false
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
        end

        -- 2) Physics dispatch
        local st = StateManager.Current
        if st == StateManager.States.Swinging then
                Swing.Step(dt)
        elseif st == StateManager.States.PointLaunching then
                PointLaunch.Step(dt)
        elseif st == StateManager.States.SlingshotCharging then
                Sling.Step(dt)
        elseif st == StateManager.States.WallCrawling or st == StateManager.States.WallSprinting then
                Wall.Step(dt)
        elseif st == StateManager.States.AirTricking then
                Tricks.Step(dt)
        elseif st == StateManager.States.GroundSliding then
                Slide.Step(dt)
        elseif st == StateManager.States.Gliding then
                Wings.Step(dt)
        elseif st == StateManager.States.AirDiving then
                Dive.Step(dt)
        end

        -- 3) Auto slide on landing
        if not Slide.Active and Moves[8].Enabled and shiftHeld
                and StateManager.Current == StateManager.States.Idle
                and Humanoid.FloorMaterial ~= Enum.Material.Air then
                Slide.TryBegin()
        end

        -- 4) Boost window expiry
        PointLaunch.CheckWindow()

        -- 5) Anti-stuck velocity fail-safe
        local speed = RootPart.AssemblyLinearVelocity.Magnitude
        if st == StateManager.States.Swinging or st == StateManager.States.PointLaunching then
                local snagged = speed < CONFIG.AntiStuckSpeed
                if snagged and st == StateManager.States.Swinging and Swing.Active and Swing.AnchorPos then
                        local d = (RootPart.Position - Swing.AnchorPos).Magnitude
                        if d >= Swing.RopeLength - 2.5 then
                                snagged = false
                        end
                end
                if snagged then
                        stuckTimer = stuckTimer + dt
                        if stuckTimer >= CONFIG.AntiStuckTime then
                                stuckTimer = 0
                                Swing.Active = false
                                PointLaunch.Pulling = false
                                PointLaunch.Arrived = false
                                releaseWebs()
                                StateManager.Set(StateManager.States.Idle, true)
                        end
                else
                        stuckTimer = 0
                end
        else
                stuckTimer = 0
        end
end))

--======================================================================
-- CHARACTER LIFECYCLE
--======================================================================
local function onCharacterAdded(character)
        lifeMaid:Cleanup()
        character:WaitForChild("Humanoid", 10)
        character:WaitForChild("HumanoidRootPart", 10)
        refreshRig()
        fullCleanup()
        if Humanoid then
                Rig.DefaultWalkSpeed = Humanoid.WalkSpeed
                lifeMaid:Give(Humanoid.Died:Connect(function()
                        fullCleanup()
                end))
        end
end

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if Workspace.CurrentCamera then
                Camera = Workspace.CurrentCamera
        end
end))

track(LocalPlayer.CharacterAdded:Connect(function(character)
        task.spawn(onCharacterAdded, character)
end))

--======================================================================
-- ENGINE DESTROY (re-execution support)
--======================================================================
function Engine.Destroy()
        if Engine.Destroyed then return end
        Engine.Destroyed = true
        for _, conn in ipairs(Engine.Connections) do
                pcall(function() conn:Disconnect() end)
        end
        Engine.Connections = {}
        pcall(function() RunService:UnbindFromRenderStep("SpideyCamera_v3") end)
        lifeMaid:Cleanup()
        webMaid:Cleanup()
        fullCleanup()
        if FXFolder then pcall(function() FXFolder:Destroy() end) end
        if mobileGui then pcall(function() mobileGui:Destroy() end) end
        if GUI then pcall(function() GUI:Destroy() end) end
        _G.__SPIDEY_ENGINE_V3 = nil
end

--======================================================================
-- INIT
--======================================================================
buildUI()
refreshMobileButtons()
if LocalPlayer.Character then
        task.spawn(onCharacterAdded, LocalPlayer.Character)
end

print("[SPIDEY ENGINE v3.6] Loaded successfully — press RightShift or the X button to open/close the panel.")
