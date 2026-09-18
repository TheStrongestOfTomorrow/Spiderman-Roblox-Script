--[[=====================================================================
        SPIDER-MAN MOVEMENT ENGINE v3.2  •  Single-File Client LocalScript
        =====================================================================
        CONTROLS (Insomniac's Spider-Man inspired)
          • E (hold)         Web Swing — fires ONLY at a real surface (5-ray
                             smart anchor search), true RopeConstraint
                             pendulum; W reels in, release to fling forward
          • F (tap)          Point Launch — Space within 3s of arrival = boost
          • Space            Tight Gap Zip (face a narrow gap) / wall jump-off
          • R (x2 + S)       Dual-Web Ground Slingshot
          • LeftShift (hold) Sprint on the ground AND on walls (R2 parkour)
          • Wall Climb       PASSIVE — run or jump at any wall to stick and
                             climb; Space jumps off; toggle in the UI panel
          • G (hold) + WASD  Air Tricks (frontflip / backflip / barrel roll)
          • LeftShift        Ground Slide on fast landings (> 45 speed)
          • RightShift       Toggle the control panel

        FEATURES
          • Web Swing with 5-ray real-surface anchor search, engine
            RopeConstraint pendulum, forward drive + reel-in, 18° roll
          • Point Launch, Tight Gap Zip, Dual-Web Slingshot, Ground Slide
          • Passive wall crawl / wall sprint / wall jump-off
          • Procedural Air Tricks — Motor6D tuck poses, zero Animation IDs
          • Full UI panel: per-move toggles, re-binds, resets, mobile canvas
          • Maid-pattern garbage collection on every state change / death

        TECHNICAL NOTES
          • 100% client-side. No RemoteEvents, no server instancing.
          • Webs are plain white local Beams — NO external texture or mesh
            assets, so visuals render instantly on every executor.
          • Movement is applied to LocalPlayer.Character.HumanoidRootPart via
            AssemblyLinearVelocity / CFrame writes (client owns its physics).
          • Zero Animation IDs. All poses are procedural (Motor6D C0 offsets).
          • Re-running this script auto-destroys the previous instance.
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
        SwingMaxDistance   = 350,   -- anchor raycast max distance (studs)
        SwingMinHeightDiff = 5,     -- anchor must be this far above the root
        SwingSteerAccel    = 42,    -- WASD pump acceleration while swinging
        SwingDragXZ        = 0.995, -- per-frame horizontal drag (no WASD held)
        SwingRollMaxDeg    = 18,    -- procedural body roll clamp (degrees)
        SwingRollFactor    = 0.2,   -- roll gain (per spec factor)
        SwingLaunchSpeed   = 62,    -- initial impulse toward the crosshair
        SwingLiftOff       = 18,    -- extra upward pop when starting grounded
        SwingThrust        = 40,    -- continuous forward drive while holding E
        SwingMaxSpeed      = 125,   -- horizontal speed cap for the drive
        SwingWReel         = 9,     -- W reels the rope in (studs/sec)
        SwingReleasePop    = 14,    -- upward pop when releasing mid-air

        -- [B] Point Launch
        LaunchSpeed        = 180,   -- linear pull speed toward target
        LaunchArriveRadius = 4.5,   -- arrival threshold (studs)
        LaunchWindow       = 3.0,   -- Space boost window after arrival (sec)
        LaunchTimeout      = 4.0,   -- hard timeout for the pull (sec)
        BoostLookSpeed     = 130,   -- boost speed along camera look
        BoostUpSpeed       = 45,    -- boost upward component

        -- [C] Tight Gap Zip
        GapShoulderSpacing = 3.5,   -- distance between the two parallel rays
        GapMaxClearance    = 8,     -- max gap width to allow pass-through
        GapZipDuration     = 0.12,  -- lerp time across the gap (sec)
        GapExitBoost       = 25,    -- exit velocity boost on top of entry speed

        -- [D] Dual-Web Slingshot
        SlingMaxStretch    = 18,    -- studs of stretch from initial distance
        SlingMaxSpeed      = 240,   -- launch speed at T = 1.0
        SlingMinT          = 0.50,  -- minimum tension for manual release
        SlingLaunchAngle   = 35,    -- upward launch angle (degrees)

        -- [E] Wall systems (passive climb, Insomniac parkour style)
        CrawlSpeed         = 14,    -- wall crawl speed (studs/sec)
        SprintSpeed        = 38,    -- wall sprint speed (studs/sec)
        WallStickOffset    = 3,     -- hover distance from wall surface
        WallDetectDist     = 7,     -- forward wall detection range
        PassiveWallDist    = 4.5,   -- auto-attach when a wall is this close
        ReattachCooldown   = 0.6,   -- seconds before re-attach after jump-off
        WallJumpUp         = 55,    -- Space jump-off vertical impulse
        WallJumpOut        = 25,    -- Space jump-off push away from wall
        WallJumpLook       = 15,    -- Space jump-off camera-look impulse
        RunSpeed           = 26,    -- ground sprint speed (LeftShift hold)

        -- [F] Air Tricks
        TrickFlipRate      = 12,    -- front/backflip degrees per frame
        TrickRollRate      = 15,    -- barrel roll degrees per frame
        TrickMinAltitude   = 15,    -- auto-recover below this altitude
        TrickRecoveryTime  = 0.15,  -- upright recovery duration (sec)

        -- [G] Ground Slide
        SlideMinSpeed      = 45,    -- required landing speed to start slide
        SlideEndSpeed      = 10,    -- slide ends below this speed
        SlideDecel         = 10,    -- slide deceleration (studs/sec^2)
        SlideDropOffset    = -1.5,  -- root height offset while sliding

        -- Fail-safes / camera
        AntiStuckSpeed     = 1.5,   -- speed below which stuck-timer runs
        AntiStuckTime      = 1.2,   -- consecutive seconds before web snap
        FOVBase            = 70,
        FOVSpeedDivisor    = 220,
        FOVSpeedGain       = 40,
        FOVMax             = 110,
        FOVLerp            = 0.1,

        -- Web visuals: plain local white beam, zero external assets
        WebColor     = Color3.fromRGB(240, 240, 255),
}

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
--      Idle | Swinging | PointLaunching | GapZipping | SlingshotCharging
--      WallCrawling | WallSprinting | WallEjecting | AirTricking | GroundSliding
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
        },
        Current = "Idle",
}

-- Allowed transition graph (Section 2 rules; unspecified edges are
-- resolved permissively because user-triggered moves pass force = true)
local VALID_TRANSITIONS = {
        Idle              = { "Swinging", "PointLaunching", "GapZipping", "SlingshotCharging", "WallCrawling", "WallSprinting", "WallEjecting", "AirTricking", "GroundSliding" },
        Swinging          = { "PointLaunching", "GapZipping", "WallCrawling", "AirTricking", "Idle", "WallEjecting" },
        PointLaunching    = { "Idle", "Swinging", "GapZipping", "AirTricking", "WallCrawling", "GroundSliding" },
        GapZipping        = { "Idle", "Swinging", "AirTricking", "GroundSliding" },
        SlingshotCharging = { "Idle" }, -- ground locked until launch / cancel
        WallCrawling      = { "WallSprinting", "WallEjecting", "Swinging", "Idle" },
        WallSprinting     = { "WallCrawling", "WallEjecting", "Swinging", "Idle" },
        WallEjecting      = { "Idle", "Swinging", "AirTricking", "WallCrawling" },
        AirTricking       = { "Idle", "Swinging", "GroundSliding", "PointLaunching" },
        GroundSliding     = { "Idle", "Swinging", "AirTricking" },
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
        [1] = { Name = "Pendulum Swing",      Default = Enum.KeyCode.E,         Key = Enum.KeyCode.E,         Enabled = true },
        [2] = { Name = "Point Launch",        Default = Enum.KeyCode.F,         Key = Enum.KeyCode.F,         Enabled = true },
        [3] = { Name = "Tight Gap Zip",       Default = Enum.KeyCode.Space,     Key = Enum.KeyCode.Space,     Enabled = true },
        [4] = { Name = "Dual-Web Slingshot",  Default = Enum.KeyCode.R,         Key = Enum.KeyCode.R,         Enabled = true },
        [5] = { Name = "Sprint (Ground/Wall)", Default = Enum.KeyCode.LeftShift, Key = Enum.KeyCode.LeftShift, Enabled = true },
        [6] = { Name = "Wall Climb (Passive)", Default = nil,                    Key = nil,                    Enabled = true },
        [7] = { Name = "Air Tricks",          Default = Enum.KeyCode.G,         Key = Enum.KeyCode.G,         Enabled = true },
        [8] = { Name = "Ground Slide",        Default = Enum.KeyCode.LeftShift, Key = Enum.KeyCode.LeftShift, Enabled = true },
}

--======================================================================
-- RUNTIME STATE
--======================================================================
local Character, Humanoid, RootPart
local stuckTimer   = 0
local shakeTimer   = 0
local shiftHeld    = false
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
        Joints = {},           -- [jointName] = { Motor = Motor6D, C0 = originalC0 }
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
                Character:FindFirstChild("RightHand")       -- R15
                or Character:FindFirstChild("Right Arm")    -- R6
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

        if Humanoid then
                Rig.DefaultWalkSpeed = Humanoid.WalkSpeed
        end

        -- keep the local character + camera + fx folder out of our raycasts
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
        if not part then
                return nil
        end
        local att = Instance.new("Attachment")
        att.Name = "SpideyWebAnchor"
        att.Parent = part
        att.WorldPosition = worldPos
        return att
end

local function createWebBeam(attachment0, attachment1)
        local beam = Instance.new("Beam")
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        -- plain white strand: no Texture asset so it renders on every executor
        beam.Width0 = 0.25
        beam.Width1 = 0.08
        beam.Color = ColorSequence.new(CONFIG.WebColor)
        beam.LightEmission = 0.2
        beam.LightInfluence = 0
        beam.FaceCamera = true
        beam.Segments = 12
        beam.Parent = FXFolder
        return beam
end

-- Destroys every active web visual (beams, attachments, virtual anchors)
local function releaseWebs()
        webMaid:Cleanup()
end

--======================================================================
-- GEOMETRY SHARPNESS FILTER (swing anchor validation)
--      Samples 4 auxiliary normals around the primary hit point. Decision
--      tiers per adjacent dot product:
--        dot <= 0.85  -> sharp edge / roof lip          -> ACCEPT
--        dot >= 0.999 -> identical planar face (flat)   -> ACCEPT
--        in between   -> smooth gradient (dome/sphere)  -> REJECT
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
        local origin = hitPos + hitNormal * 1.0
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
                return true -- isolated surface, nothing to compare against
        end

        local sawSharp = false
        local allFlat = true
        local pairsChecked = 0
        for i = 1, #normals do
                local a = normals[i]
                local b = normals[(i % #normals) + 1]
                local d = a:Dot(b)
                pairsChecked = pairsChecked + 1
                if d <= 0.85 then
                        sawSharp = true
                end
                if d < 0.999 then
                        allFlat = false
                end
        end

        if sawSharp then
                return true
        end
        if allFlat and pairsChecked >= 3 then
                return true -- one continuous planar face (flat roof / wall)
        end
        if pairsChecked >= 3 then
                return false -- smooth curved gradient (dome / sphere / pillar)
        end
        return true
end

-- Forward declarations: these systems are defined below this point, but
-- earlier systems (e.g. Swing.Begin -> PointLaunch.Cancel) reference them
-- at runtime (never at parse time). Lua closes over the local declared
-- here, and the definitions further down ASSIGN to these same locals —
-- they must NOT redeclare with 'local', otherwise the early functions
-- would still see nil.
local Wall, PointLaunch, GapZip

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
-- [A] WEB SWING  (Hold E) — true RopeConstraint pendulum physics.
--      The web attaches ONLY to a real surface found by a 5-ray smart
--      search; there is NO fake sky anchor, so webs never hang in air.
--======================================================================
local Swing = {
        Active = false, AnchorPart = nil, AnchorPos = nil, RopeLength = 0,
        Attach0 = nil, RootAttach = nil, Rope = nil,
        HandAttach = nil, Beam = nil, PrevDir = nil, StartClock = 0,
}

-- tilt a camera direction upward by deg degrees
local function tiltUp(dir, deg)
        local a = math.rad(deg)
        local d = dir * math.cos(a) + Vector3.new(0, math.sin(a), 0)
        if d.Magnitude < 0.05 then
                return dir
        end
        return d.Unit
end

-- 5-ray anchor search: straight, up +18°, up +35°, and two side rays.
-- Every candidate must hit a REAL part above the root and pass the
-- sharpness filter — otherwise the web does not fire at all.
local function findSwingAnchor(rootPos)
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local rays = {
                look,
                tiltUp(look, 18),
                tiltUp(look, 35),
                tiltUp((look + right * 0.30).Unit, 12),
                tiltUp((look - right * 0.30).Unit, 12),
        }
        for _, dir in ipairs(rays) do
                local hit = Workspace:Raycast(
                        Camera.CFrame.Position,
                        dir * CONFIG.SwingMaxDistance,
                        RayParams
                )
                if hit
                        and hit.Position.Y > rootPos.Y + CONFIG.SwingMinHeightDiff
                        and isSharpEnough(hit.Position, hit.Normal) then
                        return hit
                end
        end
        return nil
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

        -- REAL SURFACE ONLY: 5-ray smart anchor search. No fake sky webs —
        -- if nothing real is hit, the web simply does not fire.
        local hit = findSwingAnchor(rootPos)
        if not hit then
                return
        end
        local anchorPos, anchorPart = hit.Position, hit.Instance

        releaseWebs()
        PointLaunch.Cancel()

        Swing.Active = true
        Swing.StartClock = os.clock()
        Swing.PrevDir = nil
        Swing.AnchorPart = anchorPart
        Swing.AnchorPos = anchorPos
        local dist = math.max((anchorPos - rootPos).Magnitude, 6)
        Swing.RopeLength = dist * 0.96 -- slight pre-tension: catches you instantly

        Swing.Attach0 = anchorAttachment(anchorPart, anchorPos)
        Swing.RootAttach = Instance.new("Attachment")
        Swing.RootAttach.Name = "SpideySwingRoot"
        Swing.RootAttach.Parent = RootPart

        -- TRUE PHYSICS PENDULUM: engine-side RopeConstraint. The old hand-
        -- rolled CFrame correction fought the solver and produced dangle,
        -- not swing. Visible=false — the Beam is the visible strand.
        Swing.Rope = Instance.new("RopeConstraint")
        Swing.Rope.Attachment0 = Swing.Attach0
        Swing.Rope.Attachment1 = Swing.RootAttach
        Swing.Rope.Length = Swing.RopeLength
        Swing.Rope.Restitution = 0
        Swing.Rope.Visible = false
        Swing.Rope.Parent = RootPart

        Swing.HandAttach = handAttachment(getWebHand(false))
        Swing.Beam = createWebBeam(Swing.Attach0, Swing.HandAttach)
        webMaid:Give(Swing.Attach0)
        webMaid:Give(Swing.RootAttach)
        webMaid:Give(Swing.Rope)
        webMaid:Give(Swing.HandAttach)
        webMaid:Give(Swing.Beam)

        -- LIFT-OFF IMPULSE: this is what makes holding E carry you forward
        local look = Camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        flat = (flat.Magnitude > 0.05) and flat.Unit or Vector3.new(0, 0, -1)
        local grounded = Humanoid.FloorMaterial ~= Enum.Material.Air
        local impulse = look * CONFIG.SwingLaunchSpeed
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
        -- if another system destroyed the rope hardware, bail out cleanly
        if not Swing.Rope or not Swing.Rope.Parent then
                Swing.End(true)
                return
        end

        -- keep the humanoid airborne so ground friction never fights the rope
        local hState = Humanoid and Humanoid:GetState()
        if Humanoid and Humanoid.Parent
                and hState ~= Enum.HumanoidStateType.Freefall
                and hState ~= Enum.HumanoidStateType.Physics then
                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end

        local vel = RootPart.AssemblyLinearVelocity
        local horiz = Vector3.new(vel.X, 0, vel.Z)

        -- continuous forward drive while holding E (pumps the pendulum arc)
        if horiz.Magnitude < CONFIG.SwingMaxSpeed then
                local look = Camera.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                flatLook = (flatLook.Magnitude > 0.05) and flatLook.Unit or Vector3.new(0, 0, -1)
                local thrustDir = (horiz.Magnitude > 2) and horiz.Unit or flatLook
                vel = vel + thrustDir * CONFIG.SwingThrust * dt
        end

        -- WASD steering; holding W reels the rope in (classic energy pump)
        local steer = getCameraSteer()
        if steer.Magnitude > 0.01 then
                vel = vel + steer * CONFIG.SwingSteerAccel * dt
                if moveKeys.W and Swing.Rope.Length > 14 then
                        Swing.Rope.Length = math.max(Swing.Rope.Length - CONFIG.SwingWReel * dt, 14)
                        Swing.RopeLength = Swing.Rope.Length
                end
        else
                -- gentle coast decay when the stick is neutral
                vel = Vector3.new(vel.X * CONFIG.SwingDragXZ, vel.Y, vel.Z * CONFIG.SwingDragXZ)
        end
        RootPart.AssemblyLinearVelocity = vel

        -- Procedural body roll (up to 18° into the swing arc).
        -- NOTE: the literal spec expression Velocity:Dot(Velocity:Cross(up)) is
        -- degenerate (always 0), so roll is driven by the signed angular
        -- velocity of the horizontal velocity vector instead — same 0.2 gain
        -- family, clamped to ±18°.
        local flat = Vector3.new(vel.X, 0, vel.Z)
        if flat.Magnitude > 4 then
                local curDir = flat.Unit
                if Swing.PrevDir then
                        local crossY = Swing.PrevDir.X * curDir.Z - Swing.PrevDir.Z * curDir.X
                        local dot = math.clamp(Swing.PrevDir:Dot(curDir), -1, 1)
                        local turnDeg = math.deg(math.atan2(crossY, dot))
                        local rollDeg = math.clamp(turnDeg * 6 * CONFIG.SwingRollFactor, -CONFIG.SwingRollMaxDeg, CONFIG.SwingRollMaxDeg)
                        local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + curDir) * CFrame.Angles(0, 0, math.rad(rollDeg))
                        RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, 0.25)
                end
                Swing.PrevDir = curDir
        else
                Swing.PrevDir = nil
        end

        -- Grounded bail-out (only after the swing has had time to lift off)
        if os.clock() - Swing.StartClock > 0.5
                and Humanoid.FloorMaterial ~= Enum.Material.Air
                and vel.Magnitude < 10 then
                Swing.End(true)
        end
end

function Swing.End(keepMomentum)
        -- keepMomentum: released velocity persists naturally on the root
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
        -- release fling: a small upward pop when you let go mid-air
        if keepMomentum ~= false and RootPart and RootPart.Parent
                and Humanoid and Humanoid.Parent
                and Humanoid.FloorMaterial == Enum.Material.Air then
                local v = RootPart.AssemblyLinearVelocity
                if v.Y < CONFIG.SwingReleasePop then
                        RootPart.AssemblyLinearVelocity = Vector3.new(v.X, CONFIG.SwingReleasePop, v.Z)
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
-- [B] POINT LAUNCH  (Tap F)  + 3-second Space boost window
--      (assigns to the forward-declared local — do NOT redeclare)
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
        releaseWebs()

        PointLaunch.Pulling = true
        PointLaunch.Arrived = false
        PointLaunch.Target = hit.Position
        PointLaunch.StartTime = os.clock()

        local handAtt = handAttachment(getWebHand(false))
        local a0 = anchorAttachment(hit.Instance, hit.Position)
        local beam = createWebBeam(a0, handAtt)
        webMaid:Give(handAtt)
        webMaid:Give(a0)
        webMaid:Give(beam)

        StateManager.Set(StateManager.States.PointLaunching, true)
end

function PointLaunch.Step(dt)
        if not PointLaunch.Pulling or not (RootPart and RootPart.Parent) then return end

        -- hard timeout
        if os.clock() - PointLaunch.StartTime > CONFIG.LaunchTimeout then
                PointLaunch.Cancel()
                return
        end

        local toTarget = PointLaunch.Target - RootPart.Position
        if toTarget.Magnitude < CONFIG.LaunchArriveRadius then
                -- ARRIVED: halt the pull, open the 3-second boost window
                PointLaunch.Pulling = false
                PointLaunch.Arrived = true
                PointLaunch.ArrivalTimestamp = os.clock()
                releaseWebs()
                RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity * 0.15
                return
        end

        -- linear pull
        RootPart.AssemblyLinearVelocity = toTarget.Unit * CONFIG.LaunchSpeed

        -- face the target while pulling
        local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
        if flat.Magnitude > 1 then
                local targetCF = CFrame.lookAt(RootPart.Position, RootPart.Position + flat.Unit)
                RootPart.CFrame = RootPart.CFrame:Lerp(targetCF, 0.2)
        end
end

function PointLaunch.CheckWindow()
        if PointLaunch.Arrived
                and (os.clock() - PointLaunch.ArrivalTimestamp) > CONFIG.LaunchWindow then
                PointLaunch.Arrived = false -- stored launch momentum resets to 0
                if StateManager.Current == StateManager.States.PointLaunching then
                        StateManager.Set(StateManager.States.Idle, true)
                end
        end
end

function PointLaunch.TryBoost()
        if not PointLaunch.Arrived or not (RootPart and RootPart.Parent) then
                return false
        end
        local elapsed = os.clock() - PointLaunch.ArrivalTimestamp
        if elapsed <= CONFIG.LaunchWindow then
                -- BOOST: camera look * 130 + up * 45
                local boost = Camera.CFrame.LookVector * CONFIG.BoostLookSpeed
                        + Vector3.new(0, CONFIG.BoostUpSpeed, 0)
                RootPart.AssemblyLinearVelocity = boost
                PointLaunch.Arrived = false
                StateManager.Set(StateManager.States.Idle, true)
                cameraPulse(0.35)
                return true
        end
        -- window expired: default Roblox jump instead
        PointLaunch.Arrived = false
        if StateManager.Current == StateManager.States.PointLaunching then
                StateManager.Set(StateManager.States.Idle, true)
        end
        if Humanoid then
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        return true
end

function PointLaunch.Cancel()
        PointLaunch.Pulling = false
        PointLaunch.Arrived = false
        releaseWebs()
        if StateManager.Current == StateManager.States.PointLaunching then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

--======================================================================
-- [C] TIGHT GAP ZIP  (Tap Space near narrow gaps)
--      (assigns to the forward-declared local — do NOT redeclare)
--======================================================================
GapZip = { Active = false, Token = 0 }

local function detectGap()
        if not RootPart then return nil end
        local look  = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local shoulderBase = RootPart.Position + Vector3.new(0, 0.5, 0)
        local halfSpace = CONFIG.GapShoulderSpacing * 0.5

        -- two parallel forward rays from the shoulders, 3.5 studs apart
        local hitL = Workspace:Raycast(shoulderBase - right * halfSpace, look * 60, RayParams)
        local hitR = Workspace:Raycast(shoulderBase + right * halfSpace, look * 60, RayParams)
        if not (hitL and hitR) then return nil end

        -- surfaces must be opposing parallel faces (slot / crevice walls)
        if hitL.Normal:Dot(hitR.Normal) > -0.6 then return nil end

        local clearance = (hitL.Position - hitR.Position).Magnitude
        if clearance > CONFIG.GapMaxClearance or clearance < 0.5 then return nil end

        local midPos = (hitL.Position + hitR.Position) * 0.5
        local exitPos = midPos + look * (clearance * 0.5 + 3.5)

        -- make sure the exit point is not buried inside geometry
        local lookFlat = Vector3.new(look.X, 0, look.Z)
        lookFlat = (lookFlat.Magnitude > 0.05) and lookFlat.Unit or Vector3.new(0, 0, -1)
        local back = Workspace:Raycast(exitPos, (midPos - exitPos).Unit * 8, RayParams)
        if back and (exitPos - back.Position).Magnitude < 1.5 then
                exitPos = exitPos + lookFlat * 2.5
        end
        return midPos, exitPos
end

function GapZip.Begin()
        if StateManager.Current == StateManager.States.SlingshotCharging then return end
        if GapZip.Active then return end
        if not (RootPart and Humanoid) then return end

        local midPos, exitPos = detectGap()
        if not midPos then return end

        GapZip.Active = true
        GapZip.Token = GapZip.Token + 1
        local token = GapZip.Token

        releaseWebs()
        if Swing.Active then Swing.End(true) end
        if PointLaunch.Pulling then PointLaunch.Cancel() end

        StateManager.Set(StateManager.States.GapZipping, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        local startPos = RootPart.Position
        local entrySpeed = RootPart.AssemblyLinearVelocity.Magnitude
        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        local yawCF
        if flatLook.Magnitude > 0.05 then
                yawCF = CFrame.lookAt(Vector3.new(0, 0, 0), flatLook.Unit)
        else
                yawCF = CFrame.new()
        end

        -- bypass collision hitboxes during the pass-through
        local originalCollisions = {}
        if Character then
                for _, part in ipairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then
                                originalCollisions[part] = part.CanCollide
                                part.CanCollide = false
                        end
                end
        end

        local t0 = os.clock()
        local conn
        conn = RunService.Heartbeat:Connect(function()
                if token ~= GapZip.Token or Engine.Destroyed or not (RootPart and RootPart.Parent) then
                        conn:Disconnect()
                        return
                end
                local alpha = math.clamp((os.clock() - t0) / CONFIG.GapZipDuration, 0, 1)
                RootPart.CFrame = CFrame.new(startPos:Lerp(exitPos, alpha)) * yawCF
                RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                if alpha >= 1 then
                        conn:Disconnect()
                        for part, canCollide in pairs(originalCollisions) do
                                if part.Parent then
                                        part.CanCollide = canCollide
                                end
                        end
                        local exitVel = Camera.CFrame.LookVector * (entrySpeed + CONFIG.GapExitBoost)
                        RootPart.AssemblyLinearVelocity = Vector3.new(exitVel.X, math.max(exitVel.Y, 6), exitVel.Z)
                        if Humanoid and Humanoid.Parent then
                                Humanoid.AutoRotate = true
                                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                        end
                        GapZip.Active = false
                        StateManager.Set(StateManager.States.Idle, true)
                end
        end)
        lifeMaid:Give(conn)
end

--======================================================================
-- [D] DUAL-WEB GROUND SLINGSHOT  (Tap R twice, walk back with S, tap R)
--======================================================================
local Sling = {
        Phase = 0, T = 0, InitialDist = 0,
        AnchorA = nil, AnchorB = nil,
        AttachA = nil, AttachB = nil,
        BeamA = nil, BeamB = nil, HandA = nil, HandB = nil,
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
        return Workspace:Raycast(Camera.CFrame.Position, dir.Unit * 90, RayParams)
end

function Sling.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then return end -- ground only

        if Sling.Phase == 0 then
                -- PHASE 1: left anchor + web to LeftHand
                if StateManager.Current ~= StateManager.States.Idle
                        and StateManager.Current ~= StateManager.States.GroundSliding then
                        return
                end
                local hit = slingRaycast(-1)
                if not hit then return end
                Sling.Phase = 1
                Sling.AnchorA = { Position = hit.Position, Normal = hit.Normal, Part = hit.Instance }
                Sling.AttachA = anchorAttachment(hit.Instance, hit.Position)
                Sling.HandA = handAttachment(getWebHand(true))
                Sling.BeamA = createWebBeam(Sling.AttachA, Sling.HandA)
                webMaid:Give(Sling.AttachA)
                webMaid:Give(Sling.HandA)
                webMaid:Give(Sling.BeamA)
                StateManager.Set(StateManager.States.SlingshotCharging, true)

        elseif Sling.Phase == 1 then
                -- PHASE 2: turn opposite, right anchor + web to RightHand
                local hit = slingRaycast(1)
                if not hit then return end
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

        elseif Sling.Phase == 2 then
                -- manual release inside [0.50, 0.99]; auto release happens at T = 1
                if Sling.T >= CONFIG.SlingMinT and Sling.T < 1.0 then
                        Sling.Launch()
                elseif Sling.T < CONFIG.SlingMinT then
                        Sling.Cancel() -- not enough tension: abort
                end
        end
end

function Sling.Step(dt)
        if Sling.Phase ~= 2 or not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then
                Sling.Cancel()
                return
        end

        local posA = (Sling.AttachA and Sling.AttachA.WorldPosition) or Sling.AnchorA.Position
        local posB = (Sling.AttachB and Sling.AttachB.WorldPosition) or Sling.AnchorB.Position
        local mid = (posA + posB) * 0.5

        -- tension ratio T = clamp((dist - initial) / maxStretch, 0, 1)
        local currentDist = (RootPart.Position - mid).Magnitude
        Sling.T = math.clamp((currentDist - Sling.InitialDist) / CONFIG.SlingMaxStretch, 0, 1)

        -- progressive slowdown: WalkSpeed = 16 * (1 - T^1.5)  (0 at T = 1)
        Humanoid.WalkSpeed = Rig.DefaultWalkSpeed * (1 - Sling.T ^ 1.5)

        -- heat-up web colors: white -> light yellow -> deep red
        local col = slingColor(Sling.T)
        if Sling.BeamA and Sling.BeamA.Parent then
                Sling.BeamA.Color = ColorSequence.new(col)
        end
        if Sling.BeamB and Sling.BeamB.Parent then
                Sling.BeamB.Color = ColorSequence.new(col)
        end

        -- automatic release at the 100% elastic limit
        if Sling.T >= 1.0 then
                Sling.Launch()
        end
end

function Sling.Launch()
        local T = math.clamp(Sling.T, 0, 1)
        local dir = Camera.CFrame.LookVector + Vector3.new(0, math.sin(math.rad(CONFIG.SlingLaunchAngle)), 0)
        if dir.Magnitude < 0.05 then
                dir = Vector3.new(0, 1, 0)
        else
                dir = dir.Unit
        end
        Sling.Reset()
        if Humanoid and Humanoid.Parent then
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
        end
        if RootPart and RootPart.Parent then
                RootPart.AssemblyLinearVelocity = dir * (T * CONFIG.SlingMaxSpeed)
        end
        StateManager.Set(StateManager.States.Idle, true)
        cameraPulse(0.45) -- FOV punch + micro shake handled by camera system
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
-- [E] WALL CRAWL / WALL SPRINT / WALL EJECT
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
        -- wall normal must be near-horizontal (vertical surface)
        if math.abs(hit.Normal.Y) > 0.3 then return nil end
        return hit
end

local function wallPostureCFrame(pos, normal, sprint, travelDir)
        if sprint then
                -- upright stance relative to the wall plane (wall = floor)
                local dir = travelDir
                if not dir or dir.Magnitude < 0.05 then
                        dir = normal:Cross(Vector3.new(0, 1, 0))
                        if dir.Magnitude < 0.05 then
                                dir = normal:Cross(Vector3.new(1, 0, 0))
                        end
                end
                dir = dir.Unit
                return CFrame.lookAt(pos, pos + dir, normal)
        end
        -- flat crawl posture: body parallel to the wall (spec formula)
        return CFrame.lookAt(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
end

function Wall.Attach(hit)
        if not (RootPart and Humanoid) then return end
        if Wall.Crawling then return end
        if StateManager.Current == StateManager.States.SlingshotCharging then return end

        releaseWebs()
        if Swing.Active then Swing.End(true) end
        if PointLaunch.Pulling then PointLaunch.Cancel() end

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
end

function Wall.Begin()
        -- manual attach attempt (mobile CLIMB button); keyboard is passive
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

        -- maintain wall contact; detach if the surface is lost
        local probe = Workspace:Raycast(RootPart.Position, n * -1 * (CONFIG.WallStickOffset + 3), RayParams)
        if not probe or probe.Normal:Dot(n) < 0.6 then
                Wall.Detach()
                return
        end
        n = probe.Normal
        Wall.WallNormal = n

        -- wall sprint follows the Shift key (Insomniac R2 parkour)
        local wantSprint = Moves[5].Enabled and shiftHeld
        if wantSprint ~= Wall.Sprinting then
                Wall.Sprinting = wantSprint
                StateManager.Set(wantSprint and StateManager.States.WallSprinting or StateManager.States.WallCrawling, true)
        end

        local speed = Wall.Sprinting and CONFIG.SprintSpeed or CONFIG.CrawlSpeed
        local x, z = getInputVector()

        -- move along the wall plane (WASD projected onto the surface)
        local rightOnWall = Camera.CFrame.RightVector - n * Camera.CFrame.RightVector:Dot(n)
        local lookOnWall  = Camera.CFrame.LookVector  - n * Camera.CFrame.LookVector:Dot(n)
        local moveDir = rightOnWall * x + lookOnWall * z
        local pos = RootPart.Position
        if moveDir.Magnitude > 0.05 then
                moveDir = moveDir.Unit
                Wall.LastTravel = moveDir
                pos = pos + moveDir * speed * dt
        end

        -- stick to the surface at the configured offset (zero gravity feel)
        local contact = Workspace:Raycast(pos + n * 2, n * -1 * 8, RayParams)
        if contact then
                pos = contact.Position + n * CONFIG.WallStickOffset
        end

        RootPart.CFrame = RootPart.CFrame:Lerp(
                wallPostureCFrame(pos, n, Wall.Sprinting, Wall.LastTravel), 0.45
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
        if Humanoid and Humanoid.Parent then
                Humanoid.AutoRotate = true
                Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
        local st = StateManager.Current
        if st == StateManager.States.WallCrawling or st == StateManager.States.WallSprinting then
                StateManager.Set(StateManager.States.Idle, true)
        end
end

-- Insomniac-style X / Space jump-off: strong hop away from the wall
function Wall.JumpOff()
        if not Wall.Crawling or not RootPart then return end
        local n = Wall.WallNormal or Camera.CFrame.LookVector
        Wall.Detach()
        RootPart.AssemblyLinearVelocity =
                n * CONFIG.WallJumpOut
                + Vector3.new(0, CONFIG.WallJumpUp, 0)
                + Camera.CFrame.LookVector * CONFIG.WallJumpLook
        cameraPulse(0.2)
end

--======================================================================
-- [F] PROCEDURAL AIR TRICKS  (Hold G + WASD, airborne)
--======================================================================
local Tricks = { Active = false }

function Tricks.Begin()
        if not (RootPart and Humanoid) then return end
        if Humanoid.FloorMaterial ~= Enum.Material.Air then return end -- airborne only
        if Swing.Active or PointLaunch.Pulling or (Wall and Wall.Crawling) then return end
        if GapZip.Active then return end
        if Tricks.Active then return end

        Tricks.Active = true
        StateManager.Set(StateManager.States.AirTricking, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

function Tricks.Step(dt)
        if not Tricks.Active or not (RootPart and RootPart.Parent) then return end

        -- safety auto-recovery when close to the ground
        if altitudeAboveGround() < CONFIG.TrickMinAltitude then
                Tricks.End()
                return
        end

        local x, z = getInputVector()
        -- frame-by-frame angular velocity rotation matrices
        if z > 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(math.rad(CONFIG.TrickFlipRate), 0, 0)      -- frontflip
        elseif z < 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(math.rad(-CONFIG.TrickFlipRate), 0, 0)     -- backflip
        end
        if x ~= 0 then
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, 0, math.rad(CONFIG.TrickRollRate * x))  -- barrel roll
        end

        -- procedural limb tuck via Motor6D C0 offsets
        for _, jointName in ipairs({ "RightShoulder", "LeftShoulder", "RightHip", "LeftHip" }) do
                local data = Rig.Joints[jointName]
                if data and data.Motor and data.Motor.Parent then
                        local isShoulder = (jointName == "RightShoulder" or jointName == "LeftShoulder")
                        local tuckOffset
                        if isShoulder then
                                tuckOffset = CFrame.Angles(math.rad(150), 0, math.rad(25))
                        else
                                tuckOffset = CFrame.Angles(math.rad(70), 0, 0)
                        end
                        data.Motor.C0 = data.Motor.C0:Lerp(data.C0 * tuckOffset, 0.2)
                end
        end

        -- keep a minimum drift so tricks never stall mid-air
        if RootPart.AssemblyLinearVelocity.Magnitude < 20 then
                RootPart.AssemblyLinearVelocity = Camera.CFrame.LookVector * 24
        end
end

function Tricks.RestoreJoints()
        for _, data in pairs(Rig.Joints) do
                if data.Motor and data.Motor.Parent then
                        data.Motor.C0 = data.Motor.C0:Lerp(data.C0, 0.22)
                end
        end
end

function Tricks.End()
        if not Tricks.Active then return end
        Tricks.Active = false
        -- safety auto-recovery: lerp joints + CFrame upright over 0.15s
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
-- [G] GROUND SLIDE  (Hold Shift on landing with speed > 45)
--======================================================================
local Slide = { Active = false, Dir = nil, RestoreProps = nil }

function Slide.TryBegin()
        if Slide.Active then return end
        if not (RootPart and Humanoid) then return end
        if StateManager.Current ~= StateManager.States.Idle then return end
        if Humanoid.FloorMaterial == Enum.Material.Air then return end

        local vel = RootPart.AssemblyLinearVelocity
        local flat = Vector3.new(vel.X, 0, vel.Z)
        if flat.Magnitude < CONFIG.SlideMinSpeed then return end

        Slide.Active = true
        Slide.Dir = flat.Unit
        Slide.RestoreProps = RootPart.CustomPhysicalProperties

        StateManager.Set(StateManager.States.GroundSliding, true)
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        -- drop the root toward the floor
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, CONFIG.SlideDropOffset, 0)
        -- zero-friction physical properties on the root
        RootPart.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.5, 100, 1)
end

function Slide.Step(dt)
        if not Slide.Active or not (RootPart and RootPart.Parent) then return end

        -- allow WASD steering while sliding
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

        local vel = RootPart.AssemblyLinearVelocity
        local flat = Vector3.new(vel.X, 0, vel.Z)
        local newSpeed = math.max(flat.Magnitude - CONFIG.SlideDecel * dt, 0)
        RootPart.AssemblyLinearVelocity = Slide.Dir * newSpeed + Vector3.new(0, vel.Y, 0)

        -- end condition: speed below 10 studs/sec or left the floor
        if newSpeed <= CONFIG.SlideEndSpeed or Humanoid.FloorMaterial == Enum.Material.Air then
                Slide.End()
        end
end

function Slide.End()
        if not Slide.Active then return end
        Slide.Active = false
        if RootPart and RootPart.Parent then
                -- unconditional restore: nil is valid and resets to defaults,
                -- otherwise zero-friction props would leak onto the root
                RootPart.CustomPhysicalProperties = Slide.RestoreProps
                RootPart.CFrame = RootPart.CFrame + Vector3.new(0, 1.5, 0) -- pop back up
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
        PointLaunch.Pulling = false
        PointLaunch.Arrived = false
        GapZip.Active = false
        GapZip.Token = GapZip.Token + 1
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
-- MOBILE TOUCH CANVAS SYSTEM
--======================================================================
local mobileEnabled = false
local mobileLocked = true
local mobileGui = nil
local mobileButtons = {}
local mobileDrag = nil

local MOBILE_SHORT = {
        [1] = "SWING", [2] = "LAUNCH", [3] = "ZIP",   [4] = "SLING",
        [5] = "RUN",   [6] = "CLIMB",  [7] = "TRICK", [8] = "SLIDE",
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
                end
                return
        end
        local move = Moves[index]
        if not move or not move.Enabled then return end
        if index == 1 then
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
                        GapZip.Begin()
                end
        elseif index == 4 then
                Sling.Begin()
        elseif index == 5 then
                shiftHeld = true -- hold RUN: ground sprint + wall sprint
                Slide.TryBegin()
        elseif index == 6 then
                Wall.Begin() -- manual attach (climb is passive on keyboard)
        elseif index == 7 then
                Tricks.Begin()
        elseif index == 8 then
                Slide.TryBegin()
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
        for index = 1, 8 do
                local move = Moves[index]
                if move.Enabled then
                        slot = slot + 1
                        local col = (slot - 1) % 2
                        local row = math.floor((slot - 1) / 2)
                        local btn = Instance.new("TextButton")
                        btn.Name = "Mobile_" .. tostring(index)
                        btn.Size = UDim2.fromOffset(78, 78)
                        btn.Position = UDim2.new(1, (col == 0) and -176 or -90, 1, -90 - row * 90)
                        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                        btn.BackgroundTransparency = 0.35
                        btn.BorderSizePixel = 0
                        btn.AutoButtonColor = false
                        btn.Text = MOBILE_SHORT[index]
                        btn.TextColor3 = Color3.fromRGB(240, 240, 250)
                        btn.Font = Enum.Font.GothamBold
                        btn.TextSize = 13
                        addCorner(btn, 14)
                        local stroke = Instance.new("UIStroke")
                        stroke.Color = THEME.Yellow
                        stroke.Thickness = 2
                        stroke.Transparency = mobileLocked and 1 or 0 -- yellow border only when UNLOCKED
                        stroke.Parent = btn

                        btn.InputBegan:Connect(function(input)
                                local t = input.UserInputType
                                if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                                        if not mobileLocked then
                                                -- UNLOCKED: drag-and-drop repositioning mode
                                                mobileDrag = { Btn = btn, StartInput = input.Position, StartPos = btn.Position }
                                        else
                                                -- LOCKED: taps trigger the move cleanly
                                                mobileTrigger(index, true)
                                        end
                                end
                        end)
                        btn.InputEnded:Connect(function(input)
                                local t = input.UserInputType
                                if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                                        if mobileDrag and mobileDrag.Btn == btn then
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

        -- enable / disable toggle switch
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

        -- keybind rebind button
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

        -- factory reset button
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
                if not move.Key then return end -- passive system: nothing to bind
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

        local main = make("Frame", {
                Name = "MainPanel",
                Size = UDim2.fromOffset(450, 380),
                Position = UDim2.new(0.5, -225, 0.5, -190),
                BackgroundColor3 = THEME.Background,
                BackgroundTransparency = 0.2, -- dark glassmorphism
                BorderSizePixel = 0,
                Active = true,
        }, GUI)
        addCorner(main, 8)
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(120, 120, 150)
        outline.Transparency = 0.55
        outline.Parent = main

        -- draggable header
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
                Text = "SPIDER-MAN MOVEMENT ENGINE v3.2",
                TextColor3 = THEME.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, header)

        make("TextLabel", {
                Size = UDim2.new(0, 60, 1, 0),
                Position = UDim2.new(1, -66, 0, 0),
                BackgroundTransparency = 1,
                Text = "RShift",
                TextColor3 = THEME.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
        }, header)

        local scroll = make("ScrollingFrame", {
                Name = "Rows",
                Size = UDim2.new(1, -16, 1, -48),
                Position = UDim2.new(0, 8, 0, 40),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 5,
                ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150),
                CanvasSize = UDim2.fromOffset(0, 448),
        }, main)

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        for index = 1, 8 do
                buildMoveRow(scroll, Moves[index], index)
        end
        buildMobileRow(scroll, 9, "Enable Mobile Buttons", function(state)
                mobileEnabled = state
                refreshMobileButtons()
        end, mobileEnabled)
        buildMobileRow(scroll, 10, "Lock Mobile Layout", function(state)
                mobileLocked = state
                updateMobileLockVisual()
        end, mobileLocked)

        -- header drag logic (mouse + touch delta)
        local dragging = false
        local dragStart, startPos
        header.InputBegan:Connect(function(input)
                local t = input.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                        dragging = true
                        dragStart = input.Position
                        startPos = main.Position
                end
        end)
        header.InputEnded:Connect(function(input)
                local t = input.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                        dragging = false
                end
        end)

        track(UserInputService.InputChanged:Connect(function(input)
                local t = input.UserInputType
                if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
                        local delta = input.Position - dragStart
                        main.Position = UDim2.new(
                                startPos.X.Scale, startPos.X.Offset + delta.X,
                                startPos.Y.Scale, startPos.Y.Offset + delta.Y
                        )
                elseif mobileDrag and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
                        local delta = input.Position - mobileDrag.StartInput
                        mobileDrag.Btn.Position = UDim2.new(
                                mobileDrag.StartPos.X.Scale, mobileDrag.StartPos.X.Offset + delta.X,
                                mobileDrag.StartPos.Y.Scale, mobileDrag.StartPos.Y.Offset + delta.Y
                        )
                end
        end))

        mountGui(GUI)
end

--======================================================================
-- PANEL TOGGLE + KEY CAPTURE
--======================================================================
local function togglePanel()
        panelVisible = not panelVisible
        if GUI then
                GUI.Enabled = panelVisible
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
                btn.Text = Moves[index].Key.Name
                btn.TextColor3 = THEME.Text
        end
end

--======================================================================
-- KEYBOARD ROUTING
--======================================================================
local function handleKeyBegan(key)
        -- E: web swing ONLY (Insomniac R2) — detaches from walls first
        if key == Moves[1].Key then
                if Moves[1].Enabled then
                        if Wall.Crawling then
                                Wall.Detach()
                        end
                        Swing.Begin()
                end
                return
        end

        if key == Moves[2].Key and Moves[2].Enabled then
                PointLaunch.Begin()
                return
        end

        if key == Moves[3].Key then
                -- Space: wall jump-off > swing release-jump > boost > gap zip
                if Wall.Crawling or StateManager.Current == StateManager.States.WallSprinting then
                        Wall.JumpOff()
                        return
                end
                if StateManager.Current == StateManager.States.Swinging and Swing.Active then
                        Swing.End(true) -- Insomniac X: let go of the web with a hop
                        return
                end
                if not PointLaunch.TryBoost() and Moves[3].Enabled then
                        GapZip.Begin()
                end
                return
        end

        if key == Moves[4].Key and Moves[4].Enabled then
                Sling.Begin()
                return
        end

        -- LeftShift: hold to sprint on ground and walls + fast-landing slide
        if key == Moves[5].Key or key == Moves[8].Key then
                shiftHeld = true
                if Moves[8].Enabled then
                        Slide.TryBegin()
                end
                return
        end

        if key == Moves[7].Key and Moves[7].Enabled then
                Tricks.Begin()
                return
        end
end

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if Engine.Destroyed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode

        -- hide / show the control panel
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

        -- active keybind capture consumes the next key
        if captureMove then
                if key == Enum.KeyCode.Escape then
                        finishCapture(nil)
                else
                        finishCapture(key)
                end
                return
        end

        -- ignore inputs the game already consumed (e.g. typing in chat),
        -- EXCEPT Space which we intentionally intercept for zip/boost
        if gameProcessed and key ~= Enum.KeyCode.Space then
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
-- DYNAMIC CAMERA FOV + MICRO-SHAKE  (after default camera update)
--======================================================================
RunService:BindToRenderStep("SpideyCamera_v3", Enum.RenderPriority.Camera.Value + 1, function(dt)
        if Engine.Destroyed then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
                if not Camera then return end
        end

        -- TargetFOV = clamp(70 + (speed / 220) * 40, 70, 110); slingshot overrides
        local targetFOV
        if Sling.Phase == 2 then
                targetFOV = CONFIG.FOVBase + Sling.T * (CONFIG.FOVMax - CONFIG.FOVBase)
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

        -- launch micro-shake pulse, plus a subtle high-speed rumble
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
-- MAIN PHYSICS LOOP  (Heartbeat)
--======================================================================
track(RunService.Heartbeat:Connect(function(dt)
        if Engine.Destroyed then return end
        if not Camera then
                Camera = Workspace.CurrentCamera
        end
        if not (RootPart and RootPart.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0) then
                -- self-heal: if the character was replaced without our handler
                -- catching it, re-resolve the rig instead of staying dead
                if LocalPlayer.Character and LocalPlayer.Character ~= Character then
                        refreshRig()
                        fullCleanup()
                end
                return
        end

        -- 1) orientation recovery pass (wall eject / air trick landing)
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

        -- 1.5) passive wall attach (Insomniac parkour) — run/jump into walls
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
                                        local runningAtWall = moveKeys.W
                                                and look:Dot(probe.Normal * -1) > 0.45
                                        if airborne or runningAtWall then
                                                Wall.Attach(probe)
                                        end
                                end
                        end
                end
        end

        -- 1.6) ground sprint (LeftShift hold) — WalkSpeed written on transitions only
        local wantSprint = Moves[5].Enabled and shiftHeld
                and not Wall.Crawling and Sling.Phase ~= 2
                and Humanoid.FloorMaterial ~= Enum.Material.Air
                and StateManager.Current ~= StateManager.States.SlingshotCharging
                and StateManager.Current ~= StateManager.States.PointLaunching
        if wantSprint and not sprintActive then
                sprintActive = true
                Humanoid.WalkSpeed = CONFIG.RunSpeed
        elseif not wantSprint and sprintActive then
                sprintActive = false
                Humanoid.WalkSpeed = Rig.DefaultWalkSpeed
        end

        -- 2) per-state physics dispatch
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
        end

        -- 3) hold-to-slide auto trigger on fast landings
        if not Slide.Active and Moves[8].Enabled and shiftHeld
                and StateManager.Current == StateManager.States.Idle
                and Humanoid.FloorMaterial ~= Enum.Material.Air then
                Slide.TryBegin()
        end

        -- 4) expire the point-launch boost window
        PointLaunch.CheckWindow()

        -- 5) anti-stuck velocity fail-safe
        local speed = RootPart.AssemblyLinearVelocity.Magnitude
        if st == StateManager.States.Swinging or st == StateManager.States.PointLaunching then
                local snagged = speed < CONFIG.AntiStuckSpeed
                if snagged and st == StateManager.States.Swinging and Swing.Active and Swing.AnchorPos then
                        -- hanging still at full rope extension is natural, not stuck
                        local d = (RootPart.Position - Swing.AnchorPos).Magnitude
                        if d >= Swing.RopeLength - 2.5 then
                                snagged = false
                        end
                end
                if snagged then
                        stuckTimer = stuckTimer + dt
                        if stuckTimer >= CONFIG.AntiStuckTime then
                                stuckTimer = 0
                                -- force snap: destroy webs and return to Idle
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
        -- wait for the rig to finish spawning (CharacterAdded fires before
        -- Humanoid / HumanoidRootPart are guaranteed to be parented)
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
        if RootPart then
                -- The client already owns its character physics; this is a best
                -- effort no-op assertion that movement replicates from this client.
                task.defer(function()
                        pcall(function()
                                RootPart:SetNetworkOwner(nil)
                        end)
                end)
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

print("[SPIDEY ENGINE v3.2] Loaded successfully — press RightShift to open the control panel.")
