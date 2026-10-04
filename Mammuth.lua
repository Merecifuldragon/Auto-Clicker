--[[
    ███╗   ███╗███████╗██████╗  ██████╗██╗███████╗██╗   ██╗██╗         ██╗  ██╗██╗   ██╗██████╗
    ████╗ ████║██╔════╝██╔══██╗██╔════╝██║██╔════╝██║   ██║██║         ██║  ██║██║   ██║██╔══██╗
    ██╔████╔██║█████╗  ██████╔╝██║     ██║█████╗  ██║   ██║██║         ███████║██║   ██║██████╔╝
    ██║╚██╔╝██║██╔══╝  ██╔══██╗██║     ██║██╔══╝  ██║   ██║██║         ██╔══██║██║   ██║██╔══██╗
    ██║ ╚═╝ ██║███████╗██║  ██║╚██████╗██║██║     ╚██████╔╝███████╗    ██║  ██║╚██████╔╝██████╔╝
    ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝╚═╝      ╚═════╝ ╚══════╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝

    MERCIFUL HUB  -  Blox Fruits (Third Sea)
    Modules: Mammoth Farm • Server Hop • Key Spammer • Bounty Tracker + Webhook
    Tip: save this file as  workspace/MercifulHub/MercifulHub.luau  to enable auto-exec after hopping
         (or set a Loader URL in Settings).
]]

if not game:IsLoaded() then game.Loaded:Wait() end

--//==================================================================
--// SERVICES
--//==================================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local HttpService         = game:GetService("HttpService")
local TeleportService     = game:GetService("TeleportService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local CoreGui             = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

-- Re-execution: cleanly unload the previous instance first
if env.MercifulHubUnload then
    pcall(env.MercifulHubUnload)
end

local VERSION = "2.1"
local Alive = true
local Conns = {}

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Conns, c)
    return c
end

--//==================================================================
--// CONFIG (persisted to workspace/MercifulHub/config.json)
--//==================================================================
local DIR         = "MercifulHub"
local CONFIG_PATH = DIR .. "/config.json"
local STATS_PATH  = DIR .. "/stats.json"
local SELF_PATH   = DIR .. "/MercifulHub.luau"
local LOGO_URL    = "https://i.imgur.com/uo43aVi.png"
local LOGO_PATH   = DIR .. "/logo.png"

local DEFAULTS = {
    -- Farm
    AutoFarm = true,
    FruitName = "Mammoth-Mammoth",
    Fly = true,
    FlySpeed = 300,
    Noclip = true,
    M1Interval = 0.1,
    SkillKey = "V",
    TransformTimeout = 60,
    AutoHaki = true,
    AutoV3 = true,
    AutoV4 = false,
    AutoTeam = true,
    Team = "Pirates",

    -- Server hop
    AutoHop = true,
    HopMethod = "api",          -- "api" | "remote"
    HopInterval = 60,
    HopRetryInterval = 5,
    HopPreferredPlayers = 10,
    HopMinPlayers = 2,
    HopMaxPlayers = 12,
    HopMinBounty = 0,
    HopMaxBounty = 999999999,
    NoHopInCombat = true,

    -- Key spammer
    SpamJ = false,
    JInterval = 0.5,
    SpamNumbers = false,
    NumbersInterval = 10,

    -- Tracker / webhook
    WebhookEnabled = false,
    WebhookUrl = "",
    WebhookMinutes = 15,

    -- Misc
    AutoExec = true,
    AutoExecUrl = "",
    ToggleKey = "RightShift",
}

local CFG = {}
for k, v in pairs(DEFAULTS) do CFG[k] = v end

local function EnsureFolder()
    if makefolder and isfolder and not isfolder(DIR) then
        pcall(makefolder, DIR)
    end
end

local function ReadJson(path)
    if not (isfile and readfile) then return nil end
    local ok, res = pcall(function()
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
    end)
    if ok and type(res) == "table" then return res end
    return nil
end

local function WriteJson(path, tbl)
    if not writefile then return end
    EnsureFolder()
    pcall(function() writefile(path, HttpService:JSONEncode(tbl)) end)
end

do
    local saved = ReadJson(CONFIG_PATH)
    if saved then
        for k, v in pairs(saved) do
            if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then
                CFG[k] = v
            end
        end
    end
end

local saveQueued = false
local function SaveConfig()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.6, function()
        saveQueued = false
        WriteJson(CONFIG_PATH, CFG)
    end)
end

--//==================================================================
--// UTILITIES
--//==================================================================
local function Log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print("[Merciful Hub] " .. (ok and msg or tostring(fmt)))
end

local function GetChar()
    local char = LocalPlayer.Character
    if char and char.Parent then return char end
    return nil
end
local function GetHRP()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function SafeWait(parent, name, timeout)
    if not parent then return nil end
    local child = parent:FindFirstChild(name)
    if child then return child end
    local ok, result = pcall(function() return parent:WaitForChild(name, timeout or 5) end)
    return ok and result or nil
end

-- InvokeServer with a timeout so a hung remote can't freeze a loop
local function InvokeRemote(remote, timeout, ...)
    if not remote then return false end
    local args = table.pack(...)
    local done, result = false, nil
    task.spawn(function()
        local ok, res = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
        done, result = true, ok and res or nil
    end)
    local deadline = os.clock() + (timeout or 5)
    while not done and os.clock() < deadline do task.wait(0.05) end
    return done, result
end

local function FormatNumber(value)
    value = math.floor(tonumber(value) or 0)
    local s = tostring(value)
    while true do
        local changed
        s, changed = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then break end
    end
    return s
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02dh %02dm %02ds", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

local Notify -- assigned by the UI section
local function Toast(title, text, kind)
    if Notify then pcall(Notify, title, text, kind) end
end

--//==================================================================
--// TEAM
--//==================================================================
local function GetCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("CommF_")
end

local function ClickTeamGui(target)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, guiName in ipairs({ "Main (minimal)", "Main" }) do
        local gui = pg and pg:FindFirstChild(guiName)
        local choose = gui and gui:FindFirstChild("ChooseTeam")
        local container = choose and choose:FindFirstChild("Container")
        local side = container and container:FindFirstChild(target)
        local frame = side and side:FindFirstChild("Frame")
        local button = frame and frame:FindFirstChild("TextButton")
        if button then
            local fired = false
            if getconnections then
                local conns = getconnections(button.MouseButton1Down)
                if conns and #conns > 0 then
                    for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                    fired = true
                end
            end
            if not fired and firesignal then
                pcall(function() firesignal(button.MouseButton1Down) end)
                fired = true
            end
            if fired then task.wait(0.8) return true end
        end
    end
    return false
end

local function EnsureTeam()
    if not CFG.AutoTeam then return true end
    local target = (CFG.Team == "Marines") and "Marines" or "Pirates"

    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or SafeWait(ReplicatedStorage, "Remotes", 30)
    local commF = remotes and (remotes:FindFirstChild("CommF_") or SafeWait(remotes, "CommF_", 30))
    if not commF then
        Log("Team: CommF_ not ready, continuing")
        return false
    end

    for i = 1, 40 do
        if not Alive then return false end
        local ok, team = pcall(function() return LocalPlayer.Team end)
        if ok and team and team.Name == target then return true end

        InvokeRemote(commF, 5, "SetTeam", target)
        task.wait(1)

        local ok2, team2 = pcall(function() return LocalPlayer.Team end)
        if ok2 and team2 and team2.Name == target then return true end
        if i % 3 == 0 then pcall(ClickTeamGui, target) end
    end
    return false
end

--//==================================================================
--// FRUIT / EQUIP
--//==================================================================
local function FindFruit()
    local name = CFG.FruitName
    local char = GetChar()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char then
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    if backpack then
        local t = backpack:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    for _, container in ipairs({ char, backpack }) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and child.ToolTip == "Blox Fruit" then return child end
            end
        end
    end
    return nil
end

local function EquipFruit()
    local hum = GetHum()
    if not hum then return false end

    local char = GetChar()
    local equipped = char and char:FindFirstChildOfClass("Tool")
    if equipped and equipped.Name == CFG.FruitName then return true end

    local fruit = FindFruit()
    if fruit and fruit.Parent ~= char then
        pcall(function() hum:EquipTool(fruit) end)
        task.wait(0.3)
    end

    char = GetChar()
    equipped = char and char:FindFirstChildOfClass("Tool")
    return equipped ~= nil and equipped.Name == CFG.FruitName
end

local function WaitForFruit(timeout)
    local deadline = os.clock() + (timeout or 15)
    while os.clock() < deadline do
        local char = GetChar()
        local tool = char and char:FindFirstChild(CFG.FruitName)
        if tool and tool:FindFirstChild("LeftClickRemote") then return tool end
        if not tool then pcall(EquipFruit) end
        task.wait(0.2)
    end
    return nil
end

--//==================================================================
--// FLY (ascend)
--//==================================================================
local FlyActive, FlyConn, FlyObjects = false, nil, {}

local function SetPartsCollide(char, collide)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.CanCollide = collide end) end
    end
end

local function StopFly()
    FlyActive = false
    if FlyConn then pcall(function() FlyConn:Disconnect() end) FlyConn = nil end
    for _, key in ipairs({ "Velocity", "Gyro", "Attachment" }) do
        if FlyObjects[key] then pcall(function() FlyObjects[key]:Destroy() end) end
    end
    FlyObjects = {}

    local hum, hrp = GetHum(), GetHRP()
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    SetPartsCollide(GetChar(), true)
end

local function StartFly()
    if FlyActive then return true end
    local hrp, hum = GetHRP(), GetHum()
    if not hrp or not hum then return false end

    pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
    hum.PlatformStand = true
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    SetPartsCollide(GetChar(), false)

    local att = Instance.new("Attachment")
    att.Name = "MHFlyAtt"
    att.Parent = hrp

    local bv = Instance.new("BodyVelocity")
    bv.Name = "MHFlyVelocity"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.P = 1250
    bv.Velocity = Vector3.new(0, CFG.FlySpeed, 0)
    bv.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.Name = "MHFlyGyro"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 3000
    bg.D = 500
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    FlyObjects = { Attachment = att, Velocity = bv, Gyro = bg }
    FlyActive = true

    FlyConn = RunService.Heartbeat:Connect(function()
        if not FlyActive then return end
        local root, health = GetHRP(), GetHum()
        if not root or not health or health.Health <= 0 then
            StopFly()
            return
        end
        if bv.Parent then bv.Velocity = Vector3.new(0, CFG.FlySpeed, 0) end
        if bg.Parent then bg.CFrame = CFrame.new(root.Position) end
    end)
    return true
end

--//==================================================================
--// NOCLIP
--//==================================================================
local NoclipActive, NoclipConn = false, nil
local NoclipChanged = setmetatable({}, { __mode = "k" })
local NoclipIndex = 0

local function ApplyNoclipPass()
    local char = GetChar()
    if not char then return end
    local parts = char:GetDescendants()
    local count = #parts
    if count == 0 then return end

    local perPass = 40
    if count <= perPass then NoclipIndex = 0 else NoclipIndex = NoclipIndex % count end

    local processed, i = 0, NoclipIndex
    while processed < perPass and processed < count do
        i = (i % count) + 1
        local part = parts[i]
        if part and part:IsA("BasePart") and part.CanCollide then
            NoclipChanged[part] = true
            part.CanCollide = false
        end
        processed += 1
    end
    NoclipIndex = i
end

local function StopNoclip()
    NoclipActive = false
    if NoclipConn then pcall(function() NoclipConn:Disconnect() end) NoclipConn = nil end
    for part in pairs(NoclipChanged) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function() part.CanCollide = true end)
        end
    end
    NoclipChanged = setmetatable({}, { __mode = "k" })
    NoclipIndex = 0
end

local function StartNoclip()
    if NoclipActive then return end
    NoclipActive = true
    NoclipConn = RunService.Stepped:Connect(function()
        if not NoclipActive then return end
        if not GetChar() then return end
        ApplyNoclipPass()
        local root = GetHRP()
        if root and root.Position.Y < -500 then
            pcall(function() root.CFrame = CFrame.new(root.Position.X, 200, root.Position.Z) end)
        end
    end)
end

--//==================================================================
--// SKILL (V) + MAMMOTH FORM
--//==================================================================
local function GetSkillBoard(toolName)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local skills = main and main:FindFirstChild("Skills")
    return skills and skills:FindFirstChild(toolName)
end

local function FireSkillByConnections(skillKey)
    if not getconnections then return false end
    local char = GetChar()
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return false end

    local board = GetSkillBoard(tool.Name)
    local button = board and board:FindFirstChild(skillKey)
    local mobile = button and button:FindFirstChild("Mobile")
    if not mobile then return false end

    local down = getconnections(mobile.MouseButton1Down)
    if not down or #down == 0 then return false end
    for _, c in ipairs(down) do pcall(function() c:Fire() end) end
    task.wait(0.15)
    local up = getconnections(mobile.MouseButton1Up)
    if up then for _, c in ipairs(up) do pcall(function() c:Fire() end) end end
    return true
end

local function FireSkillByKey(skillKey)
    local code = Enum.KeyCode[skillKey:upper()]
    if not code then return false end
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, code, false, game)
        task.wait(0.3)
        VirtualInputManager:SendKeyEvent(false, code, false, game)
    end)
    task.wait(0.2)
    return ok
end

local function IsMammothOn()
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return false end
    local me = chars:FindFirstChild(LocalPlayer.Name)
    if me then
        local m1 = me:FindFirstChild("Mammoth")
        if m1 and m1:FindFirstChild("Mammoth") then return true end
    end
    return false
end

local function CastVUntilMammoth(isLive)
    if IsMammothOn() then return true end

    local deadline = os.clock() + (CFG.TransformTimeout or 60)
    local attempt = 0
    while os.clock() < deadline and isLive() do
        if IsMammothOn() then return true end
        attempt += 1

        local char = GetChar()
        local equipped = char and char:FindFirstChildOfClass("Tool")
        if not (equipped and equipped.Name == CFG.FruitName) then
            pcall(EquipFruit)
            task.wait(0.3)
        end

        local fired = false
        local cur = GetChar()
        local tool = cur and cur:FindFirstChildOfClass("Tool")
        if tool and GetSkillBoard(tool.Name) then
            pcall(function() fired = FireSkillByConnections(CFG.SkillKey) end)
        end
        if not fired then
            pcall(function() fired = FireSkillByKey(CFG.SkillKey) end)
        end
        task.wait(1)
    end
    return IsMammothOn()
end

--//==================================================================
--// VOID M1 LOOP
--//==================================================================
local VOID_VECTOR = Vector3.new(9e30, 9e30, 9e30)
local M1Gen, M1Running = 0, false

local function FireM1()
    local char = GetChar()
    local tool = char and char:FindFirstChild(CFG.FruitName)
    local remote = tool and tool:FindFirstChild("LeftClickRemote")
    if not remote then return false end
    return pcall(function() remote:FireServer(VOID_VECTOR) end)
end

local function StopM1Loop()
    M1Running = false
    M1Gen += 1
end

local function StartM1Loop()
    if M1Running then return end
    M1Running = true
    M1Gen += 1
    local gen = M1Gen
    task.spawn(function()
        while M1Running and gen == M1Gen and Alive do
            task.wait(CFG.M1Interval)
            local char = GetChar()
            if not char then
                task.wait(0.5)
            else
                local tool = char:FindFirstChild(CFG.FruitName)
                if not (tool and tool:FindFirstChild("LeftClickRemote")) then
                    pcall(EquipFruit)
                    task.wait(0.3)
                else
                    FireM1()
                end
            end
        end
    end)
end

--//==================================================================
--// HAKI / V3 / V4
--//==================================================================
local function IsHakiOn()
    local char = GetChar()
    if not char then return false end
    return char:FindFirstChild("HasBuso") ~= nil or char:FindFirstChild("_BusoLayer1", true) ~= nil
end

local function TurnOnHaki()
    if not GetChar() or IsHakiOn() then return end
    local commF = GetCommF()
    if commF then InvokeRemote(commF, 5, "Buso") end
end

local function TurnOnV3()
    local char = GetChar()
    if not char then return end
    local transformed = char:FindFirstChild("RaceTransformed")
    if transformed and transformed.Value then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commE = remotes and remotes:FindFirstChild("CommE")
    if commE then pcall(function() commE:FireServer("ActivateAbility") end) end
end

local function TurnOnV4()
    local char = GetChar()
    if not char then return end
    local energy = char:FindFirstChild("RaceEnergy")
    local transformed = char:FindFirstChild("RaceTransformed")
    if not energy or tonumber(energy.Value) == nil or energy.Value < 1 then return end
    if not transformed or transformed.Value then return end

    local awakening = char:FindFirstChild("Awakening")
    if not awakening then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        awakening = bp and bp:FindFirstChild("Awakening")
    end
    local remote = awakening and awakening:FindFirstChild("RemoteFunction")
    if not remote then return end

    local ok = pcall(function() remote:InvokeServer(true) end)
    if not ok then pcall(function() remote:InvokeServer({ true }) end) end
end

task.spawn(function()
    while Alive do
        task.wait(2)
        if CFG.AutoHaki then pcall(TurnOnHaki) end
        if CFG.AutoV3 then pcall(TurnOnV3) end
    end
end)
task.spawn(function()
    while Alive do
        task.wait(1)
        if CFG.AutoV4 then pcall(TurnOnV4) end
    end
end)

--//==================================================================
--// FARM CONTROLLER
--//==================================================================
local FarmGen, FarmActive, MovementReady = 0, false, false
local FarmState = "Idle"

local function SyncMovement()
    if MovementReady and CFG.Fly then
        if not FlyActive then StartFly() end
    elseif FlyActive then
        StopFly()
    end

    if MovementReady and CFG.Noclip then
        if not NoclipActive then StartNoclip() end
    elseif NoclipActive then
        StopNoclip()
    end
end

local function StopFarm()
    FarmGen += 1
    FarmActive = false
    MovementReady = false
    FarmState = "Idle"
    StopM1Loop()
    SyncMovement()
end

local function RunFarm(gen)
    local function live() return Alive and FarmActive and gen == FarmGen end

    FarmState = "Waiting for character"
    if not WaitForCharacterReady(60) then
        return
    end
    if not live() then return end

    FarmState = "Equipping fruit"
    local tool
    for _ = 1, 15 do
        if not live() then return end
        pcall(EquipFruit)
        tool = WaitForFruit(2)
        if tool then break end
    end
    if not tool then Toast("Farm", "Fruit '" .. CFG.FruitName .. "' not found, continuing anyway", "warn") end
    if not live() then return end

    FarmState = "Ascending"
    MovementReady = true
    SyncMovement()

    task.wait(0.6)
    FarmState = "Transforming"
    CastVUntilMammoth(live)
    if not live() then return end

    FarmState = "Farming"
    StartM1Loop()
end

local function WaitForCharacterReady(timeout)
    local deadline = os.clock() + (timeout or 60)

    while Alive and os.clock() < deadline do
        local char = LocalPlayer.Character

        if char and char.Parent then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")

            if hum and hrp and hum.Health > 0 then
                -- Give Roblox a short moment to finish character/UI/tool replication.
                task.wait(1)
                if Alive and LocalPlayer.Character == char and char.Parent then
                    hum = char:FindFirstChildOfClass("Humanoid")
                    hrp = char:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then
                        return true
                    end
                end
            end
        end

        task.wait(0.25)
    end

    return false
end

local function StartFarm()
    if FarmActive then return end

    -- Do not start the farm/team logic until the character is completely ready.
    FarmState = "Waiting for character"
    if not WaitForCharacterReady(60) then
        if Alive and CFG.AutoFarm then
            Toast("Farm", "Character did not finish loading.", "warn")
        end
        return
    end

    if not Alive or not CFG.AutoFarm then return end

    FarmActive = true
    FarmGen += 1
    local gen = FarmGen

    task.spawn(function()
        if CFG.AutoTeam then
            FarmState = "Joining team"
            pcall(EnsureTeam)
        end

        if Alive and FarmActive and gen == FarmGen then
            RunFarm(gen)
        end
    end)
end

Connect(LocalPlayer.CharacterAdded, function()
    if not Alive or not CFG.AutoFarm then return end

    StopFarm()
    FarmState = "Waiting for character"

    task.spawn(function()
        if WaitForCharacterReady(60) and Alive and CFG.AutoFarm then
            StartFarm()
        end
    end)
end)

--//==================================================================
--// COMBAT STATUS
--//==================================================================
local function GetCombatStatus()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local mainUI = pg and pg:FindFirstChild("Main")
    local hud = mainUI and mainUI:FindFirstChild("BottomHUDList")
    local ui = hud and hud:FindFirstChild("InCombat")

    if ui and ui.Visible then
        local raw = ""
        if ui:IsA("TextLabel") then
            raw = ui.Text
        else
            local t = ui:FindFirstChildWhichIsA("TextLabel", true)
            if t then raw = t.Text end
        end
        local lower = string.lower(raw)
        if string.find(lower, "bounty") or string.find(lower, "賞金") then
            return "BountyAtRisk"
        end
        return "InCombatNoRisk"
    end
    return "NotInCombat"
end

local function IsBountyAtRisk()
    if not CFG.NoHopInCombat then return false end
    local ok, status = pcall(GetCombatStatus)
    return ok and status == "BountyAtRisk"
end

--//==================================================================
--// AUTO-EXEC (queue_on_teleport)
--//==================================================================
local QUEUE_GUARD_KEY = "MERCIFUL_HUB_AUTOEXEC_JOB"
local AutoExecQueuedFor = nil
local AutoExecWarned = false

local function GetQueueOnTeleport()
    local fn = env and (rawget(env, "queue_on_teleport") or rawget(env, "queueonteleport"))
    if type(fn) ~= "function" and syn then fn = syn.queue_on_teleport end
    if type(fn) ~= "function" and fluxus then fn = fluxus.queue_on_teleport end
    return type(fn) == "function" and fn or nil
end

local function GetHopSource()
    if CFG.AutoExecUrl ~= "" then
        return string.format('loadstring(game:HttpGet(%q))()', CFG.AutoExecUrl)
    end
    if isfile and readfile and isfile(SELF_PATH) then
        return string.format('loadstring(readfile(%q))()', SELF_PATH)
    end
    return nil
end

local function SetupAutoExec()
    if not CFG.AutoExec then return false end
    if AutoExecQueuedFor == game.JobId then return true end

    local queueFn = GetQueueOnTeleport()
    if not queueFn then
        if not AutoExecWarned then
            AutoExecWarned = true
            Log("Auto-exec skipped: executor lacks queue_on_teleport")
        end
        return false
    end

    local code = GetHopSource()
    if not code then
        if not AutoExecWarned then
            AutoExecWarned = true
            Toast("Auto-Exec", "No loader URL set and " .. SELF_PATH .. " not found. Auto-exec disabled.", "warn")
        end
        return false
    end

    local payload = table.concat({
        "task.spawn(function()",
        "    repeat task.wait(1) until game:IsLoaded()",
        "    task.wait(2)",
        string.format("    if getgenv().%s == game.JobId then return end", QUEUE_GUARD_KEY),
        string.format("    getgenv().%s = game.JobId", QUEUE_GUARD_KEY),
        string.format("    local ok, err = pcall(function() %s end)", code),
        '    if not ok then warn("[Merciful Hub auto-exec] " .. tostring(err)) end',
        "end)",
    }, "\n")

    local ok = pcall(queueFn, payload)
    if ok then AutoExecQueuedFor = game.JobId end
    return ok
end

--//==================================================================
--// SERVER HOP
--//==================================================================
local Hopping = false
if not _G.JumpHistory then _G.JumpHistory = {} end

local function FetchServerList()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
    local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if ok and type(res) == "table" and type(res.data) == "table" then return res.data end
    return nil
end

local function FetchServerListRemote(timeout)
    local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser") or SafeWait(ReplicatedStorage, "__ServerBrowser", 10)
    if not browser then return nil end

    local servers, pending = {}, 0
    for page = 1, 100 do
        pending += 1
        task.delay(page * 0.02, function()
            local ok, result = pcall(function() return browser:InvokeServer(page) end)
            if not ok then
                local tries = 0
                repeat
                    task.wait(0.5)
                    tries += 1
                    ok, result = pcall(function() return browser:InvokeServer(page) end)
                until ok or tries >= 2
            end
            if ok and type(result) == "table" then
                for job, info in pairs(result) do
                    if type(info) == "table" then
                        servers[job] = {
                            Region = tostring(info.Region or "Unknown"),
                            Count  = tonumber(info.Count) or 0,
                            Bounty = tonumber(info.Bounty) or 0,
                        }
                    end
                end
            end
            pending -= 1
        end)
    end

    local deadline = os.clock() + (timeout or 20)
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
    if next(servers) == nil then return nil end
    return servers
end

local function PickServer(servers)
    if type(servers) ~= "table" then return nil end
    local function scan(minPlayers)
        for _, s in ipairs(servers) do
            local id = s.id and tostring(s.id)
            local playing = tonumber(s.playing) or 0
            local maxPlayers = tonumber(s.maxPlayers) or 12
            if id and id ~= game.JobId and not table.find(_G.JumpHistory, id)
                and playing >= minPlayers and playing < maxPlayers then
                return id, playing
            end
        end
    end
    local id, playing = scan(CFG.HopPreferredPlayers)
    if id then return id, playing end
    return scan(CFG.HopMinPlayers)
end

local function PickServerRemote(servers)
    if type(servers) ~= "table" then return nil end
    local matches = {}
    for job, info in pairs(servers) do
        local count, bounty = tonumber(info.Count) or 0, tonumber(info.Bounty) or 0
        if job ~= game.JobId and not table.find(_G.JumpHistory, job)
            and count >= CFG.HopMinPlayers and count <= CFG.HopMaxPlayers
            and bounty >= CFG.HopMinBounty and bounty <= CFG.HopMaxBounty then
            table.insert(matches, { Job = job, Count = count })
        end
    end
    if #matches == 0 then return nil end
    local pick = matches[math.random(1, #matches)]
    return pick.Job, pick.Count
end

local function TeleportToJob(jobId)
    local remote = ReplicatedStorage:FindFirstChild("__ServerBrowser") or SafeWait(ReplicatedStorage, "__ServerBrowser", 3)
    if remote then
        local done = InvokeRemote(remote, 8, "teleport", jobId)
        if done then return true, "browser" end
    end
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
    if ok then return true, "teleport" end
    return false, tostring(err)
end

local function DoServerHop()
    if Hopping then return false end
    Hopping = true

    local useRemote = (CFG.HopMethod == "remote")
    local servers, target, playing

    if useRemote then
        servers = FetchServerListRemote()
        if not servers then Log("Hop[remote]: no server list") Hopping = false return false end
        target, playing = PickServerRemote(servers)
        if not target then _G.JumpHistory = {} target, playing = PickServerRemote(servers) end
    else
        servers = FetchServerList()
        if not servers then Log("Hop[api]: no server list") Hopping = false return false end
        target, playing = PickServer(servers)
        if not target then _G.JumpHistory = {} target, playing = PickServer(servers) end
    end

    if not target then
        Log("Hop[%s]: no suitable server", CFG.HopMethod)
        Hopping = false
        return false
    end

    table.insert(_G.JumpHistory, target)
    if #_G.JumpHistory > 100 then table.remove(_G.JumpHistory, 1) end
    Log("Hopping to %s (%s players)", target, tostring(playing))

    pcall(SetupAutoExec)

    local ok, method = TeleportToJob(target)
    if not ok then
        Log("Hop failed: %s", tostring(method))
        Hopping = false
        return false
    end
    task.wait(0.5)
    Hopping = false
    return true
end

local HopRemaining = 0
task.spawn(function()
    local lastJob = game.JobId
    local t0 = os.clock()
    while Alive do
        task.wait(1)
        if game.JobId ~= lastJob then
            lastJob = game.JobId
            t0 = os.clock()
        end

        if not CFG.AutoHop then
            t0 = os.clock()
            HopRemaining = -1
        else
            HopRemaining = math.max(0, CFG.HopInterval - (os.clock() - t0))
            if HopRemaining <= 0 then
                if IsBountyAtRisk() then
                    -- stay put until the bounty is safe again
                else
                    local hum, hrp = GetHum(), GetHRP()
                    if hum and hrp and hum.Health > 0 then
                        pcall(DoServerHop)
                    end
                    -- next attempt after the retry interval if we're still here
                    t0 = os.clock() - CFG.HopInterval + CFG.HopRetryInterval
                end
            end
        end
    end
end)

--//==================================================================
--// KEY SPAMMER
--//==================================================================
local function PressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

task.spawn(function()
    while Alive do
        if CFG.SpamJ then
            PressKey(Enum.KeyCode.J)
            task.wait(math.max(0.05, CFG.JInterval))
        else
            task.wait(0.3)
        end
    end
end)

task.spawn(function()
    local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
    while Alive do
        if CFG.SpamNumbers then
            for _, k in ipairs(keys) do
                PressKey(k)
                task.wait(0.1)
            end
            local waitLeft = math.max(1, CFG.NumbersInterval)
            while waitLeft > 0 and Alive and CFG.SpamNumbers do
                task.wait(0.5)
                waitLeft -= 0.5
            end
        else
            task.wait(0.3)
        end
    end
end)

--//==================================================================
--// BOUNTY TRACKER + WEBHOOK
--//==================================================================
local Stats = { total = 0, sessionStart = os.time(), lastSeen = os.time() }
local serverBounty = 0
local lastWebhook = os.clock()

do
    local saved = ReadJson(STATS_PATH)
    if saved and os.time() - (tonumber(saved.lastSeen) or 0) < 1800 then
        Stats.total = tonumber(saved.total) or 0
        Stats.sessionStart = tonumber(saved.sessionStart) or os.time()
    end
end

local function SaveStats()
    Stats.lastSeen = os.time()
    WriteJson(STATS_PATH, Stats)
end

local function GetRequestFn()
    return request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
end

local function BountyPerHour()
    local elapsed = math.max(os.time() - Stats.sessionStart, 1)
    return Stats.total / (elapsed / 3600)
end

local function SendWebhook(reason, force)
    if not force and not CFG.WebhookEnabled then return false end
    if CFG.WebhookUrl == "" then return false end

    local req = GetRequestFn()
    if not req then
        warn("[Merciful Hub] No HTTP request function on this executor.")
        return false
    end

    local elapsed = math.max(os.time() - Stats.sessionStart, 1)
    local payload = {
        username = "Merciful Hub",
        avatar_url = LOGO_URL,
        embeds = {{
            title = "Merciful Hub • Bounty Report",
            description = reason or "Bounty update",
            color = 9133302,
            thumbnail = { url = LOGO_URL },
            fields = {
                { name = "Server Bounty", value = "+" .. FormatNumber(serverBounty), inline = true },
                { name = "Total Bounty", value = "+" .. FormatNumber(Stats.total), inline = true },
                { name = "Bounty / Hour", value = "+" .. FormatNumber(BountyPerHour()), inline = true },
                { name = "Time Elapsed", value = FormatTime(elapsed), inline = true },
                { name = "Player", value = LocalPlayer.Name, inline = true },
                { name = "Job ID", value = "```" .. game.JobId .. "```", inline = false },
            },
            footer = { text = "Merciful Hub v" .. VERSION .. " • " .. os.date("%X"), icon_url = LOGO_URL },
        }},
    }

    local ok = pcall(function()
        req({
            Url = CFG.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
    lastWebhook = os.clock()
    return ok
end

local function ProcessBountyArgs(args)
    for _, arg in ipairs(args) do
        if type(arg) == "string" and string.find(string.lower(arg), "bounty") then
            local num = string.match(arg, "%d+")
            local amount = num and tonumber(num)
            if amount and amount > 0 then
                serverBounty += amount
                Stats.total += amount
                SaveStats()
                Toast("Bounty", "+" .. FormatNumber(amount) .. " bounty gained", "good")
                task.spawn(SendWebhook, "Gained +" .. FormatNumber(amount) .. " bounty")
                break
            end
        end
    end
end

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
    local commE = remotes and remotes:WaitForChild("CommE", 15)
    if commE then
        Connect(commE.OnClientEvent, function(...)
            ProcessBountyArgs({ ... })
        end)
    else
        warn("[Merciful Hub] CommE not found; bounty tracking disabled.")
    end
end)

task.spawn(function()
    local tick = 0
    while Alive do
        task.wait(1)
        tick += 1
        if tick % 10 == 0 then SaveStats() end
        if CFG.WebhookEnabled and CFG.WebhookUrl ~= ""
            and os.clock() - lastWebhook >= CFG.WebhookMinutes * 60 then
            SendWebhook("Periodic summary")
        end
    end
end)

--//==================================================================
--// UI  -  LIQUID GLASS DYNAMIC ISLAND (single page, expanded)
--//==================================================================
local function BuildUI()
    local T = {
        Accent   = Color3.fromRGB(139, 92, 246),
        Accent2  = Color3.fromRGB(236, 72, 153),
        AccentLt = Color3.fromRGB(196, 181, 253),
        Text     = Color3.fromRGB(245, 245, 252),
        Muted    = Color3.fromRGB(158, 158, 190),
        Good     = Color3.fromRGB(74, 222, 128),
        Warn     = Color3.fromRGB(251, 191, 36),
        Bad      = Color3.fromRGB(248, 113, 113),
        White    = Color3.new(1, 1, 1),
    }

    local function make(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local function corner(p, r) return make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, p) end
    local function tween(o, props, t, style, dir)
        local tw = TweenService:Create(o, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end

    -- Liquid-glass primitives: white fill whose alpha comes from a gradient (so it reads as a lit pane),
    -- plus a stroke that is bright on the top edge and fades toward the bottom.
    local function glassFill(p, a0, a1, rot)
        p.BackgroundColor3 = T.White
        p.BackgroundTransparency = 0
        make("UIGradient", { Transparency = NumberSequence.new(a0, a1), Rotation = rot or 90 }, p)
    end
    local function glassStroke(p, a0, a1, thick)
        local s = make("UIStroke", {
            Color = T.White, Thickness = thick or 1, Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, p)
        make("UIGradient", { Transparency = NumberSequence.new(a0, a1), Rotation = 90 }, s)
        return s
    end

    local function GetGuiParent()
        if gethui then
            local ok, h = pcall(gethui)
            if ok and h then return h end
        end
        local ok, cg = pcall(function() return CoreGui end)
        if ok and cg then return cg end
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    local GuiParent = GetGuiParent()
    local old = GuiParent:FindFirstChild("MercifulHubUI")
    if old then old:Destroy() end

    local ScreenGui = make("ScreenGui", {
        Name = "MercifulHubUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = GuiParent

    local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)

    --------------------------------------------------------------------
    -- Toasts (glass pills, bottom centre)
    --------------------------------------------------------------------
    local toastHolder = make("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(0, 320, 1, -44),
    }, ScreenGui)
    make("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, toastHolder)

    Notify = function(title, text, kind)
        local color = ({ good = T.Good, warn = T.Warn, bad = T.Bad })[kind or ""] or T.AccentLt
        local card = make("CanvasGroup", {
            BackgroundColor3 = Color3.fromRGB(16, 14, 30), BackgroundTransparency = 0.12,
            Size = UDim2.new(0, 300, 0, 50), GroupTransparency = 1,
        }, toastHolder)
        corner(card, 25)
        glassStroke(card, 0.6, 0.92, 1)
        local dot = make("Frame", {
            BackgroundColor3 = color, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.new(0, 8, 0, 8),
        }, card)
        corner(dot, 4)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 36, 0, 8), Size = UDim2.new(1, -50, 0, 16),
            Text = tostring(title), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 36, 0, 25), Size = UDim2.new(1, -50, 0, 16),
            Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
        tween(card, { GroupTransparency = 0 }, 0.25)
        task.delay(3.5, function()
            if not card.Parent then return end
            tween(card, { GroupTransparency = 1 }, 0.3)
            task.wait(0.35)
            card:Destroy()
        end)
    end

    --------------------------------------------------------------------
    -- Island shell
    --------------------------------------------------------------------
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local ISL_W = math.clamp(viewport.X - 24, 300, 500)
    local ISL_H = math.clamp(viewport.Y - 70, 320, 620)
    local HEAD_H = 56
    local COL_W, COL_H = math.clamp(viewport.X - 24, 300, 470), 56

    local Island = make("Frame", {
        Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80),
        Size = UDim2.new(0, COL_W, 0, COL_H), BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.1, BorderSizePixel = 0, ClipsDescendants = true,
    }, ScreenGui)
    local IslandCorner = corner(Island, COL_H / 2)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 20, 70)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(11, 10, 22)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 14, 42)),
        }),
        Rotation = 125,
    }, Island)
    glassStroke(Island, 0.45, 0.88, 1.5)

    -- specular highlight along the top edge
    local sheen = make("Frame", {
        BackgroundColor3 = T.White, BorderSizePixel = 0, ZIndex = 2,
        Position = UDim2.new(0.14, 0, 0, 1), Size = UDim2.new(0.72, 0, 0, 1),
    }, Island)
    make("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sheen)

    -- soft inner light (liquid look)
    local inner = make("Frame", {
        BackgroundColor3 = T.White, BorderSizePixel = 0, ZIndex = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, Island)
    corner(inner, 32)
    make("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.9),
            NumberSequenceKeypoint.new(0.35, 0.975),
            NumberSequenceKeypoint.new(1, 0.96),
        }),
        Rotation = 90,
    }, inner)

    --------------------------------------------------------------------
    -- Header (tap = expand/collapse, drag = move)
    --------------------------------------------------------------------
    local Header = make("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEAD_H), ZIndex = 3, Active = true,
    }, Island)

    -- logo badge (image is downloaded async; falls back to an "M")
    local LogoBox = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.new(0, 36, 0, 36), ZIndex = 4,
    }, Header)
    corner(LogoBox, 18)
    glassFill(LogoBox, 0.8, 0.9, 90)
    glassStroke(LogoBox, 0.35, 0.8, 1)
    local LogoFallback = make("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "M", Font = Enum.Font.GothamBlack,
        TextSize = 16, TextColor3 = T.Text, ZIndex = 5,
    }, LogoBox)
    local LogoImg = make("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ScaleType = Enum.ScaleType.Fit,
        Image = "", ZIndex = 6, Visible = false,
    }, LogoBox)
    corner(LogoImg, 18)

    -- live status badge on the logo
    local Dot = make("Frame", {
        BackgroundColor3 = T.Muted, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 45, 0.5, 13), Size = UDim2.new(0, 10, 0, 10), ZIndex = 8,
    }, Header)
    corner(Dot, 5)
    make("UIStroke", { Color = Color3.fromRGB(11, 10, 22), Thickness = 2 }, Dot)

    local Title = make("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(0, 220, 1, 0), ZIndex = 4,
        Font = Enum.Font.GothamBlack, TextSize = 14, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'MERCIFUL <font color="rgb(196,181,253)">HUB</font>', TextColor3 = T.Text, Visible = false,
    }, Header)

    -- collapsed readout: total / server / time / bounty-per-hour
    local CompactRow = make("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(1, -108, 1, 0), ZIndex = 4,
    }, Header)
    local function compactCell(i, label, color)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new((i - 1) * 0.25, 0, 0, 10), Size = UDim2.new(0.25, -4, 0, 11),
            Text = label, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
        }, CompactRow)
        return make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new((i - 1) * 0.25, 0, 0, 23), Size = UDim2.new(0.25, -4, 0, 20),
            Text = "-", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = color,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
        }, CompactRow)
    end
    local cTotal  = compactCell(1, "TOTAL", T.Good)
    local cServer = compactCell(2, "SERVER", T.AccentLt)
    local cTime   = compactCell(3, "TIME", T.Text)
    local cBph    = compactCell(4, "BOUNTY/HR", T.Warn)

    local function headBtn(text, xOff)
        local b = make("TextButton", {
            AutoButtonColor = false, Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Muted,
            BackgroundColor3 = T.White, BackgroundTransparency = 0, ZIndex = 5,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.new(0, 28, 0, 28),
        }, Header)
        corner(b, 14)
        make("UIGradient", { Transparency = NumberSequence.new(0.88, 0.94), Rotation = 90 }, b)
        b.MouseEnter:Connect(function() tween(b, { TextColor3 = T.Text, BackgroundColor3 = T.AccentLt }, 0.12) end)
        b.MouseLeave:Connect(function() tween(b, { TextColor3 = T.Muted, BackgroundColor3 = T.White }, 0.12) end)
        return b
    end
    local Chevron = headBtn("▼", -12)
    local CloseBtn = headBtn("✕", -46)
    CloseBtn.Visible = false

    --------------------------------------------------------------------
    -- Body
    --------------------------------------------------------------------
    local Body = make("CanvasGroup", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, HEAD_H), Size = UDim2.new(1, 0, 1, -HEAD_H),
        GroupTransparency = 1, Visible = false, ZIndex = 3,
    }, Island)

    local Scroll = make("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.AccentLt, ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, Body)
    make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, Scroll)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 18),
    }, Scroll)

    local order = 0
    local function ord() order += 1 return order end

    local function card(parent, h)
        local f = make("Frame", { Size = UDim2.new(1, 0, 0, h or 0), LayoutOrder = ord() }, parent)
        corner(f, 16)
        glassFill(f, 0.9, 0.95, 110)
        glassStroke(f, 0.62, 0.93, 1)
        return f
    end

    local function section(text)
        make("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = ord(),
            Text = text, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.AccentLt,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, Scroll)
    end

    local function grid(cols, h)
        local f = make("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = ord(),
        }, Scroll)
        make("UIGridLayout", {
            CellSize = UDim2.new(1 / cols, -(10 * (cols - 1) / cols), 0, h),
            CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
        }, f)
        return f
    end

    local function pressable(frame, hit)
        local sc = make("UIScale", { Scale = 1 }, frame)
        hit.MouseButton1Down:Connect(function() tween(sc, { Scale = 0.96 }, 0.08) end)
        hit.MouseButton1Up:Connect(function() tween(sc, { Scale = 1 }, 0.14, Enum.EasingStyle.Back) end)
        hit.MouseLeave:Connect(function() tween(sc, { Scale = 1 }, 0.1) end)
    end

    --------------------------------------------------------------------
    -- Hero: total bounty (mirrors the webhook report)
    --------------------------------------------------------------------
    local Hero = card(Scroll, 124)
    local HeroLogo = make("ImageLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 92, 0, 92), ScaleType = Enum.ScaleType.Fit, ImageTransparency = 0.8, Visible = false,
    }, Hero)
    make("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 14), Size = UDim2.new(1, -36, 0, 14),
        Text = "TOTAL BOUNTY EARNED", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Hero)
    local HeroNum = make("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 30), Size = UDim2.new(1, -36, 0, 46),
        Text = "+0", Font = Enum.Font.GothamBlack, TextSize = 38, TextColor3 = T.White,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, Hero)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(250, 255, 252), Color3.fromRGB(110, 235, 165)), Rotation = 90,
    }, HeroNum)
    local HeroSub = make("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 84), Size = UDim2.new(0.6, 0, 0, 14),
        Text = "Waiting for the first bounty gain", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, Hero)
    local HeroHook = make("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 84),
        Size = UDim2.new(0.4, 0, 0, 14), Text = "● Webhook off", Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right,
    }, Hero)
    local HeroFlash = make("Frame", {
        BackgroundColor3 = T.Good, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 0,
    }, Hero)
    corner(HeroFlash, 16)

    --------------------------------------------------------------------
    -- Stat grid (same fields as the Discord embed + live status)
    --------------------------------------------------------------------
    local function statCard(parent, label)
        local f = card(parent)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 11), Size = UDim2.new(1, -28, 0, 12),
            Text = string.upper(label), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        local v = make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 29), Size = UDim2.new(1, -28, 0, 24),
            Text = "-", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        return function(text, color)
            v.Text = text
            if color then v.TextColor3 = color end
        end
    end

    local stats = grid(3, 64)
    local setServer = statCard(stats, "Server bounty")
    local setBph    = statCard(stats, "Bounty / hour")
    local setTime   = statCard(stats, "Time elapsed")
    local setFarm   = statCard(stats, "Farm state")
    local setHop    = statCard(stats, "Next hop")
    local setCombat = statCard(stats, "Combat")

    -- Player + Job ID (tap to copy), like the embed footer fields
    do
        local f = card(Scroll, 58)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(0.4, 0, 0, 12),
            Text = "PLAYER", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(0.4, -10, 0, 20),
            Text = LocalPlayer.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0.42, 0, 0, 10), Size = UDim2.new(0.58, -14, 0, 12),
            Text = "JOB ID  ·  TAP TO COPY", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        local job = make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0.42, 0, 0, 28), Size = UDim2.new(0.58, -14, 0, 20),
            Text = game.JobId ~= "" and game.JobId or "studio", Font = Enum.Font.Code, TextSize = 12,
            TextColor3 = T.AccentLt, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        local hit = make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 5 }, f)
        pressable(f, hit)
        hit.MouseButton1Click:Connect(function()
            if clip then
                pcall(clip, game.JobId)
                Toast("Copied", "Job ID copied to clipboard", "good")
            else
                Toast("Job ID", "Executor has no clipboard function", "warn")
            end
        end)
        local _ = job
    end

    --------------------------------------------------------------------
    -- Controls: toggle chips
    --------------------------------------------------------------------
    section("CONTROLS")

    local function chip(parent, label, key, cb)
        local f = card(parent)
        local on = make("Frame", { BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, f)
        corner(on, 16)
        make("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Rotation = 20 }, on)
        local dot = make("Frame", {
            BackgroundColor3 = T.Muted, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 13, 0.5, 0), Size = UDim2.new(0, 7, 0, 7),
        }, f)
        corner(dot, 4)
        local lab = make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 28, 0, 0), Size = UDim2.new(1, -32, 1, 0),
            Text = label, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        local function render(v)
            tween(on, { BackgroundTransparency = v and 0.42 or 1 }, 0.18)
            tween(dot, { BackgroundColor3 = v and T.White or T.Muted }, 0.18)
            tween(lab, { TextColor3 = v and T.Text or T.Muted }, 0.18)
        end
        render(CFG[key])
        local hit = make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 5 }, f)
        pressable(f, hit)
        hit.MouseButton1Click:Connect(function()
            CFG[key] = not CFG[key]
            render(CFG[key])
            SaveConfig()
            if cb then task.spawn(cb, CFG[key]) end
        end)
    end

    local chips = grid(3, 38)
    chip(chips, "Auto Farm", "AutoFarm", function(v)
        if v then StartFarm() else StopFarm() end
        Toast("Auto Farm", v and "Enabled" or "Disabled", v and "good" or "warn")
    end)
    chip(chips, "Ascend", "Fly", function() SyncMovement() end)
    chip(chips, "Noclip", "Noclip", function() SyncMovement() end)
    chip(chips, "Buso Haki", "AutoHaki")
    chip(chips, "Race V3", "AutoV3")
    chip(chips, "Race V4", "AutoV4")
    chip(chips, "Auto Hop", "AutoHop")
    chip(chips, "Safe Hop", "NoHopInCombat")
    chip(chips, "Spam J", "SpamJ")
    chip(chips, "Spam 1-4", "SpamNumbers")
    chip(chips, "Webhook", "WebhookEnabled")
    chip(chips, "Auto-Exec", "AutoExec", function(v) if v then SetupAutoExec() end end)

    --------------------------------------------------------------------
    -- Settings
    --------------------------------------------------------------------
    section("SETTINGS")

    local function field(parent, label, key, opts)
        opts = opts or {}
        local f = card(parent, opts.h)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -28, 0, 12),
            Text = string.upper(label), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        local box = make("TextBox", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 25), Size = UDim2.new(1, -28, 0, 20),
            Text = tostring(CFG[key]), PlaceholderText = opts.placeholder or "", PlaceholderColor3 = T.Muted,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Text, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        local st = f:FindFirstChildOfClass("UIStroke")
        box.Focused:Connect(function() if st then tween(st, { Color = T.AccentLt }, 0.12) end end)
        box.FocusLost:Connect(function()
            if st then tween(st, { Color = T.White }, 0.12) end
            if opts.number then
                local n = tonumber(box.Text)
                if n then
                    if opts.min then n = math.max(opts.min, n) end
                    if opts.max then n = math.min(opts.max, n) end
                    CFG[key] = n
                end
                box.Text = tostring(CFG[key])
            else
                CFG[key] = box.Text
            end
            SaveConfig()
        end)
        return f
    end

    local fields = grid(2, 52)
    field(fields, "Hop after (sec)", "HopInterval", { number = true, min = 5, max = 3600 })
    field(fields, "Retry every (sec)", "HopRetryInterval", { number = true, min = 1, max = 120 })
    field(fields, "Ascend speed", "FlySpeed", { number = true, min = 0, max = 2000 })
    field(fields, "M1 interval (sec)", "M1Interval", { number = true, min = 0.03, max = 5 })
    field(fields, "Preferred players", "HopPreferredPlayers", { number = true, min = 0, max = 100 })
    field(fields, "Minimum players", "HopMinPlayers", { number = true, min = 0, max = 100 })
    field(fields, "J interval (sec)", "JInterval", { number = true, min = 0.05, max = 60 })
    field(fields, "1-4 cycle (sec)", "NumbersInterval", { number = true, min = 1, max = 600 })
    field(fields, "Summary every (min)", "WebhookMinutes", { number = true, min = 1, max = 1440 })
    field(fields, "Fruit tool name", "FruitName")

    field(Scroll, "Discord webhook URL", "WebhookUrl", { h = 52, placeholder = "https://discord.com/api/webhooks/..." })
    field(Scroll, "Loader URL (optional)", "AutoExecUrl", { h = 52, placeholder = "blank = use workspace/MercifulHub/MercifulHub.luau" })

    local function segmented(parent, label, options, get, set)
        local f = card(parent)
        make("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -28, 0, 12),
            Text = string.upper(label), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        local holder = make("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
            Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 24),
        }, f)
        corner(holder, 12)
        make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, holder)
        local buttons = {}
        local function render()
            for opt, b in pairs(buttons) do
                local sel = (get() == opt)
                tween(b, { BackgroundTransparency = sel and 0.3 or 1, TextColor3 = sel and T.Text or T.Muted }, 0.15)
            end
        end
        for i, opt in ipairs(options) do
            local b = make("TextButton", {
                AutoButtonColor = false, BackgroundColor3 = T.Accent, BackgroundTransparency = 1,
                Size = UDim2.new(1 / #options, 0, 1, 0), Text = opt, Font = Enum.Font.GothamMedium,
                TextSize = 11, TextColor3 = T.Muted, LayoutOrder = i,
            }, holder)
            corner(b, 12)
            buttons[opt] = b
            b.MouseButton1Click:Connect(function()
                set(opt)
                render()
                SaveConfig()
            end)
        end
        render()
    end

    local segs = grid(2, 58)
    segmented(segs, "Team", { "Pirates", "Marines", "Off" },
        function() return CFG.AutoTeam and CFG.Team or "Off" end,
        function(opt)
            if opt == "Off" then
                CFG.AutoTeam = false
            else
                CFG.AutoTeam = true
                CFG.Team = opt
            end
        end)
    segmented(segs, "Server search", { "api", "remote" },
        function() return CFG.HopMethod end,
        function(opt) CFG.HopMethod = opt end)

    --------------------------------------------------------------------
    -- Actions
    --------------------------------------------------------------------
    local function action(parent, label, color, cb)
        local f = make("Frame", { LayoutOrder = ord() }, parent)
        corner(f, 16)
        glassFill(f, 0.86, 0.93, 110)
        glassStroke(f, 0.55, 0.9, 1)
        make("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = label,
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = color or T.Text,
        }, f)
        local hit = make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 5 }, f)
        hit.MouseEnter:Connect(function() tween(f, { BackgroundColor3 = T.AccentLt }, 0.12) end)
        hit.MouseLeave:Connect(function() tween(f, { BackgroundColor3 = T.White }, 0.12) end)
        pressable(f, hit)
        hit.MouseButton1Click:Connect(function() task.spawn(cb) end)
    end

    local actions = grid(3, 40)
    action(actions, "Hop now", nil, function()
        Toast("Server Hop", "Searching for a server...", nil)
        if not DoServerHop() then Toast("Server Hop", "No server found, try again", "bad") end
    end)
    action(actions, "Test webhook", nil, function()
        if CFG.WebhookUrl == "" then Toast("Webhook", "Set a webhook URL first", "bad") return end
        local ok = SendWebhook("Test report", true)
        Toast("Webhook", ok and "Test report sent" or "Failed to send", ok and "good" or "bad")
    end)
    action(actions, "Reset stats", T.Bad, function()
        Stats.total, Stats.sessionStart = 0, os.time()
        serverBounty = 0
        SaveStats()
        Toast("Tracker", "Stats reset", "warn")
    end)

    make("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = ord(),
        Text = "Merciful Hub v" .. VERSION .. "   ·   " .. CFG.ToggleKey .. " hides the island   ·   tap the island to expand / collapse",
        Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.Muted, TextWrapped = true,
    }, Scroll)

    --------------------------------------------------------------------
    -- Expand / collapse + drag
    --------------------------------------------------------------------
    local expanded = false
    local function SetExpanded(v)
        expanded = v
        if v then
            Title.Visible, CloseBtn.Visible, CompactRow.Visible = true, true, false
            Chevron.Text = "▲"
            Body.Visible = true
            tween(Island, { Size = UDim2.new(0, ISL_W, 0, ISL_H) }, 0.55, Enum.EasingStyle.Back)
            tween(IslandCorner, { CornerRadius = UDim.new(0, 32) }, 0.45)
            tween(Body, { GroupTransparency = 0 }, 0.45)
        else
            Chevron.Text = "▼"
            tween(Body, { GroupTransparency = 1 }, 0.15)
            tween(Island, { Size = UDim2.new(0, COL_W, 0, COL_H) }, 0.45, Enum.EasingStyle.Quint)
            tween(IslandCorner, { CornerRadius = UDim.new(0, COL_H / 2) }, 0.45)
            task.delay(0.15, function()
                if not expanded then
                    Body.Visible = false
                    Title.Visible, CloseBtn.Visible, CompactRow.Visible = false, false, true
                end
            end)
        end
    end

    Chevron.MouseButton1Click:Connect(function() SetExpanded(not expanded) end)

    do
        local dragging, moved, dragStart, startPos = false, false, nil, nil
        Connect(Header.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, moved, dragStart, startPos = true, false, i.Position, Island.Position
                local c
                c = i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        c:Disconnect()
                        if dragging and not moved then SetExpanded(not expanded) end
                        dragging = false
                    end
                end)
            end
        end)
        Connect(UserInputService.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                if d.Magnitude > 6 then moved = true end
                if moved then
                    Island.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
            end
        end)
    end

    Connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        local ok, code = pcall(function() return Enum.KeyCode[CFG.ToggleKey] end)
        if ok and code and input.KeyCode == code then Island.Visible = not Island.Visible end
    end)

    --------------------------------------------------------------------
    -- Unload
    --------------------------------------------------------------------
    local function Unload()
        if not Alive then return end
        Alive = false
        StopFarm()
        StopFly()
        StopNoclip()
        for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
        pcall(function() ScreenGui:Destroy() end)
        SaveStats()
        env.MercifulHubUnload = nil
        Log("Unloaded")
    end
    env.MercifulHubUnload = Unload
    CloseBtn.MouseButton1Click:Connect(Unload)

    --------------------------------------------------------------------
    -- Live refresh
    --------------------------------------------------------------------
    local function FormatCompact(n)
        n = tonumber(n) or 0
        if n >= 1e9 then return string.format("+%.2fB", n / 1e9) end
        if n >= 1e6 then return string.format("+%.2fM", n / 1e6) end
        return "+" .. FormatNumber(n)
    end
    local function FormatShort(sec)
        sec = math.max(0, math.floor(sec))
        local h, m, sc = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
        if h > 0 then return string.format("%dh %02dm", h, m) end
        return string.format("%dm %02ds", m, sc)
    end

    local function ago(seconds)
        seconds = math.max(0, math.floor(seconds))
        if seconds < 60 then return seconds .. "s ago" end
        if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
        return math.floor(seconds / 3600) .. "h ago"
    end

    task.spawn(function()
        local shown = Stats.total
        local lastTotal = Stats.total
        local gains, lastGain, lastGainAt = 0, 0, nil
        local tick = 0

        while Alive do
            task.wait(0.1)
            tick += 1

            -- gain detection -> flash + counters
            if Stats.total > lastTotal then
                lastGain = Stats.total - lastTotal
                gains += 1
                lastGainAt = os.clock()
                HeroFlash.BackgroundTransparency = 0.72
                tween(HeroFlash, { BackgroundTransparency = 1 }, 1.1)
            elseif Stats.total < lastTotal then
                shown = Stats.total
                gains, lastGain, lastGainAt = 0, 0, nil
            end
            lastTotal = Stats.total

            -- count-up animation
            shown += (Stats.total - shown) * 0.3
            if math.abs(Stats.total - shown) < 1 then shown = Stats.total end
            local totalText = "+" .. FormatNumber(shown)
            HeroNum.Text = totalText
            cTotal.Text = FormatCompact(shown)

            -- status dot
            local dotColor = (FarmState == "Farming" and T.Good) or (FarmActive and T.Warn) or T.Muted
            Dot.BackgroundColor3 = dotColor
            Dot.BackgroundTransparency = 0.25 + 0.25 * math.sin(os.clock() * 3)

            if tick % 5 == 0 then
                -- hero sub line
                if lastGainAt then
                    HeroSub.Text = string.format("Last +%s  ·  %s  ·  %d gain%s", FormatNumber(lastGain),
                        ago(os.clock() - lastGainAt), gains, gains == 1 and "" or "s")
                    HeroSub.TextColor3 = T.Text
                else
                    HeroSub.Text = "Waiting for the first bounty gain"
                    HeroSub.TextColor3 = T.Muted
                end

                -- webhook status
                if CFG.WebhookEnabled and CFG.WebhookUrl ~= "" then
                    local rem = math.max(0, CFG.WebhookMinutes * 60 - (os.clock() - lastWebhook))
                    HeroHook.Text = string.format("● Webhook · next %02d:%02d", math.floor(rem / 60), math.floor(rem % 60))
                    HeroHook.TextColor3 = T.Good
                elseif CFG.WebhookEnabled then
                    HeroHook.Text = "● Webhook · no URL"
                    HeroHook.TextColor3 = T.Warn
                else
                    HeroHook.Text = "● Webhook off"
                    HeroHook.TextColor3 = T.Muted
                end

                -- stat cards
                setServer("+" .. FormatNumber(serverBounty), T.AccentLt)
                setBph("+" .. FormatNumber(BountyPerHour()), T.Warn)
                setTime(FormatTime(os.time() - Stats.sessionStart), T.Text)

                -- collapsed island readout
                cServer.Text = FormatCompact(serverBounty)
                cTime.Text = FormatShort(os.time() - Stats.sessionStart)
                cBph.Text = FormatCompact(BountyPerHour())

                local state = FarmActive and FarmState or (CFG.AutoFarm and "Starting" or "Off")
                setFarm(state, FarmState == "Farming" and T.Good or (FarmActive and T.Warn or T.Muted))

                if HopRemaining < 0 then
                    setHop("Off", T.Muted)
                elseif HopRemaining <= 0 then
                    setHop("Searching", T.Warn)
                else
                    setHop(string.format("%ds", math.ceil(HopRemaining)), T.AccentLt)
                end

                local okC, combat = pcall(GetCombatStatus)
                combat = okC and combat or "Unknown"
                if combat == "BountyAtRisk" then
                    setCombat("At risk", T.Bad)
                elseif combat == "InCombatNoRisk" then
                    setCombat("In combat", T.Warn)
                else
                    setCombat("Safe", T.Good)
                end
            end
        end
    end)

    -- logo: download once, cache in workspace, load as a custom asset
    task.spawn(function()
        local getAsset = getcustomasset or getsynasset
        if not (getAsset and writefile and isfile and readfile) then return end
        local ok = pcall(function()
            EnsureFolder()
            local need = true
            if isfile(LOGO_PATH) then need = #readfile(LOGO_PATH) < 200 end
            if need then
                local data = game:HttpGet(LOGO_URL)
                if #data < 200 then error("bad image data") end
                writefile(LOGO_PATH, data)
            end
        end)
        if not ok then return end
        local okA, asset = pcall(getAsset, LOGO_PATH)
        if okA and asset and Alive then
            LogoImg.Image = asset
            LogoImg.Visible = true
            LogoFallback.Visible = false
            HeroLogo.Image = asset
            HeroLogo.Visible = true
        end
    end)

    -- starts collapsed: drop in from the top as a pill
    tween(Island, { Position = UDim2.new(0.5, 0, 0, 12) }, 0.7, Enum.EasingStyle.Back)
end

BuildUI()

--//==================================================================
--// START
--//==================================================================
SetupAutoExec()
Toast("Merciful Hub", "Loaded. Tap the island to expand, " .. CFG.ToggleKey .. " hides it.", "good")
Log("Loaded v%s", VERSION)

if CFG.AutoFarm then StartFarm() end
