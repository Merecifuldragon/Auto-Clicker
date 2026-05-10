-- ╔══════════════════════════════════════════════════════════════╗
-- ║  AFK GUARD by Merciful                                       ║
-- ║  Anti-AFK jump · Black screen · Live timer · FPS lock       ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local ContentProvider     = game:GetService("ContentProvider")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    character = c
    humanoid  = c:WaitForChild("Humanoid")
end)

-- =====================================================================
-- GC LOOP
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(30)
        pcall(collectgarbage, "collect")
    end
end)

-- =====================================================================
-- LAG REDUCTION  (original full save/restore method)
-- =====================================================================
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local SKY_TYPES = {
    "Sky","Atmosphere","BloomEffect","BlurEffect","ColorCorrectionEffect",
    "SunRaysEffect","DepthOfFieldEffect","BlackAndWhiteEffect",
    "BrightnessEffect","EqualizeEffect","ContrastEffect","SelectiveColorEffect",
}

local origQuality = nil
pcall(function() origQuality = settings().Rendering.QualityLevel end)
local origShadows    = Lighting.GlobalShadows
local origFogEnd     = Lighting.FogEnd
local origFogStart   = Lighting.FogStart
local origAmbient    = Lighting.Ambient
local origBrightness = Lighting.Brightness

local modifiedParts   = {}
local hiddenDecals    = {}
local clearedTextures = {}
local disabledSounds  = {}
local detachedLighting= {}

local wsConn, lightChildConn, lightDescConn

local function nukeLightChild(obj)
    if obj.Name == "AFK_BlackScreen" then return end
    for _, t in ipairs(SKY_TYPES) do
        if obj:IsA(t) then
            table.insert(detachedLighting, obj)
            pcall(function() obj.Parent = nil end)
            return
        end
    end
end

local function sweepObj(obj)
    -- Particles & FX
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke")
    or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") then
        pcall(obj.Destroy, obj); return
    end
    -- Decals / Textures — save originals so they can be restored
    if obj:IsA("Decal") or obj:IsA("Texture") then
        pcall(function()
            table.insert(hiddenDecals, {obj=obj, orig=obj.Transparency})
            obj.Transparency = 1
        end)
    end
    if obj:IsA("SurfaceAppearance") then pcall(obj.Destroy, obj); return end
    if obj:IsA("SpecialMesh") then
        pcall(function()
            table.insert(clearedTextures, {obj=obj, field="TextureId", orig=obj.TextureId})
            obj.TextureId = ""
        end)
    end
    if obj:IsA("MeshPart") then
        pcall(function()
            table.insert(clearedTextures, {obj=obj, field="TextureID", orig=obj.TextureID})
            obj.TextureID = ""
        end)
    end
    -- Parts — flatten material, disable shadows & reflections
    if obj:IsA("BasePart") then
        pcall(function()
            table.insert(modifiedParts, {
                obj      = obj,
                mat      = obj.Material,
                shadow   = obj.CastShadow,
                ref      = obj.Reflectance,
                fidelity = obj.RenderFidelity,
            })
            obj.Material       = Enum.Material.SmoothPlastic
            obj.CastShadow     = false
            obj.Reflectance    = 0
            obj.RenderFidelity = Enum.RenderFidelity.Automatic
        end)
    end
    -- Sky / visual effects
    for _, t in ipairs(SKY_TYPES) do
        if obj:IsA(t) and obj.Name ~= "AFK_BlackScreen" then
            pcall(obj.Destroy, obj); return
        end
    end
    -- Sounds
    if obj:IsA("Sound") then
        pcall(function()
            table.insert(disabledSounds, {obj=obj, vol=obj.Volume})
            obj.Volume = 0
        end)
    end
    -- LOD: disable non-character LocalScripts
    if obj:IsA("LocalScript") then
        local inChar = character and obj:IsDescendantOf(character)
        if not inChar then pcall(function() obj.Disabled = true end) end
    end
end

local function applyLagReduction()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd        = 100000
        Lighting.FogStart      = 100000
        Lighting.Ambient       = Color3.fromRGB(178, 178, 178)
        Lighting.Brightness    = 1
    end)
    for _, obj in ipairs(Lighting:GetChildren()) do nukeLightChild(obj) end
    lightChildConn = Lighting.ChildAdded:Connect(nukeLightChild)
    lightDescConn  = Lighting.DescendantAdded:Connect(nukeLightChild)
    for _, obj in ipairs(workspace:GetDescendants()) do sweepObj(obj) end
    wsConn = workspace.DescendantAdded:Connect(sweepObj)
    if Terrain then
        pcall(function()
            Terrain.Decoration       = false
            Terrain.WaterWaveSize    = 0
            Terrain.WaterWaveSpeed   = 0
            Terrain.WaterReflectance = 0
        end)
    end
    pcall(function() ContentProvider.RequestQueueSize = 0 end)
    task.defer(function() pcall(collectgarbage, "collect") end)
end

-- Purge stale destroyed-object entries every 60s
task.spawn(function()
    while true do
        task.wait(60)
        local function purge(t)
            local i = 1
            while i <= #t do
                local e   = t[i]
                local ok  = e.obj and pcall(function() return e.obj.Parent end)
                if not ok then table.remove(t, i) else i = i + 1 end
            end
        end
        purge(modifiedParts)
        purge(hiddenDecals)
        purge(clearedTextures)
        purge(disabledSounds)
        pcall(collectgarbage, "collect")
    end
end)

applyLagReduction()

-- =====================================================================
-- FPS LOCK
-- =====================================================================
local fpsLocked    = true
local fpsTarget    = 20
local minFrameTime = 1 / fpsTarget
local lastFrame    = tick()

local function setFpsTarget(fps)
    fpsTarget    = math.clamp(math.floor(fps), 1, 240)
    minFrameTime = 1 / fpsTarget
end

RunService.RenderStepped:Connect(function()
    if not fpsLocked then return end
    local now = tick()
    if now - lastFrame < minFrameTime then
        while tick() < lastFrame + minFrameTime do end
    end
    lastFrame = tick()
end)

-- =====================================================================
-- BLACK SCREEN  (ColorCorrectionEffect — only darkens 3D world)
-- GUI elements stay fully visible on top.
-- Slightly transparent so the game is faintly visible in background.
-- =====================================================================
local oldBs = Lighting:FindFirstChild("AFK_BlackScreen")
if oldBs then oldBs:Destroy() end

local blackEffect           = Instance.new("ColorCorrectionEffect")
blackEffect.Name            = "AFK_BlackScreen"
blackEffect.Brightness      = -0.88
blackEffect.Contrast        = 0.2
blackEffect.Saturation      = -0.7
blackEffect.TintColor       = Color3.fromRGB(0, 8, 30)
blackEffect.Enabled         = true
blackEffect.Parent          = Lighting

-- =====================================================================
-- GUI PARENT
-- =====================================================================
local guiParent
do
    local ok, h = pcall(gethui)
    if ok and h then guiParent = h
    else
        local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
        guiParent = (ok2 and cg) or player.PlayerGui
    end
end

local oldGui = guiParent:FindFirstChild("AFK_Overlay")
if oldGui then oldGui:Destroy() end

-- =====================================================================
-- SCREEN GUI
-- =====================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "AFK_Overlay"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 9999
screenGui.IgnoreGuiInset = true
screenGui.Parent         = guiParent

-- =====================================================================
-- CENTRE DISPLAY — layered "AFK" with glow overlay effect
-- Three stacked TextLabels simulate a bloom/glow without images.
--   Layer 1 (bottom) : large, very transparent — outer bloom
--   Layer 2 (middle) : slightly smaller, less transparent — inner glow
--   Layer 3 (top)    : sharp, bright — the actual crisp letter
-- =====================================================================
local container = Instance.new("Frame")
container.AnchorPoint            = Vector2.new(0.5, 0.5)
container.Position               = UDim2.new(0.5, 0, 0.46, 0)
container.Size                   = UDim2.new(0, 340, 0, 170)
container.BackgroundTransparency = 1
container.BorderSizePixel        = 0
container.Parent                 = screenGui

-- Layer 1: outer bloom (widest, most transparent)
local bloom = Instance.new("TextLabel")
bloom.Size               = UDim2.new(1, 40, 0, 110)
bloom.Position           = UDim2.new(0, -20, 0, -10)
bloom.BackgroundTransparency = 1
bloom.Text               = "AFK"
bloom.TextColor3         = Color3.fromRGB(20, 60, 200)
bloom.TextTransparency   = 0.78
bloom.Font               = Enum.Font.Cartoon
bloom.TextScaled         = true
bloom.BorderSizePixel    = 0
bloom.ZIndex             = 1
bloom.Parent             = container

-- Layer 2: inner glow
local glow = Instance.new("TextLabel")
glow.Size               = UDim2.new(1, 14, 0, 96)
glow.Position           = UDim2.new(0, -7, 0, -2)
glow.BackgroundTransparency = 1
glow.Text               = "AFK"
glow.TextColor3         = Color3.fromRGB(60, 130, 255)
glow.TextTransparency   = 0.50
glow.Font               = Enum.Font.Cartoon
glow.TextScaled         = true
glow.BorderSizePixel    = 0
glow.ZIndex             = 2
glow.Parent             = container

-- Layer 3: crisp top text
local afkLabel = Instance.new("TextLabel")
afkLabel.Size               = UDim2.new(1, 0, 0, 88)
afkLabel.Position           = UDim2.new(0, 0, 0, 4)
afkLabel.BackgroundTransparency = 1
afkLabel.Text               = "AFK"
afkLabel.TextColor3         = Color3.fromRGB(215, 235, 255)
afkLabel.TextTransparency   = 0.0
afkLabel.Font               = Enum.Font.Cartoon
afkLabel.TextScaled         = true
afkLabel.BorderSizePixel    = 0
afkLabel.ZIndex             = 3
afkLabel.Parent             = container

-- Thin glowing separator line
local sep = Instance.new("Frame")
sep.Size                  = UDim2.new(0, 110, 0, 1)
sep.AnchorPoint           = Vector2.new(0.5, 0)
sep.Position              = UDim2.new(0.5, 0, 0, 100)
sep.BackgroundColor3      = Color3.fromRGB(50, 110, 255)
sep.BackgroundTransparency= 0.25
sep.BorderSizePixel       = 0
sep.ZIndex                = 3
sep.Parent                = container
Instance.new("UICorner", sep).CornerRadius = UDim.new(0, 1)

-- Timer label
local timerLabel = Instance.new("TextLabel")
timerLabel.Size               = UDim2.new(1, 0, 0, 26)
timerLabel.Position           = UDim2.new(0, 0, 0, 108)
timerLabel.BackgroundTransparency = 1
timerLabel.Text               = "Time Elapsed: 00:00"
timerLabel.TextColor3         = Color3.fromRGB(90, 150, 240)
timerLabel.TextTransparency   = 0.08
timerLabel.Font               = Enum.Font.Cartoon
timerLabel.TextScaled         = true
timerLabel.BorderSizePixel    = 0
timerLabel.ZIndex             = 3
timerLabel.Parent             = container

-- "by Merciful" subtitle
local byLabel = Instance.new("TextLabel")
byLabel.Size               = UDim2.new(1, 0, 0, 16)
byLabel.Position           = UDim2.new(0, 0, 0, 142)
byLabel.BackgroundTransparency = 1
byLabel.Text               = "by Merciful"
byLabel.TextColor3         = Color3.fromRGB(50, 80, 140)
byLabel.TextTransparency   = 0.15
byLabel.Font               = Enum.Font.Cartoon
byLabel.TextScaled         = true
byLabel.BorderSizePixel    = 0
byLabel.ZIndex             = 3
byLabel.Parent             = container

-- =====================================================================
-- FPS CONTROL PANEL  — bottom-center
-- Preset buttons + custom TextBox input + toggle ON/OFF
-- =====================================================================
local fpsPanel = Instance.new("Frame")
fpsPanel.Size                  = UDim2.new(0, 280, 0, 110)
fpsPanel.AnchorPoint           = Vector2.new(0.5, 1)
fpsPanel.Position              = UDim2.new(0.5, 0, 1, -14)
fpsPanel.BackgroundColor3      = Color3.fromRGB(0, 8, 28)
fpsPanel.BackgroundTransparency= 0.15
fpsPanel.BorderSizePixel       = 0
fpsPanel.ZIndex                = 5
fpsPanel.Parent                = screenGui
Instance.new("UICorner", fpsPanel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", fpsPanel)
panelStroke.Color     = Color3.fromRGB(0, 55, 170)
panelStroke.Thickness = 1.5

-- Panel title
local panelTitle = Instance.new("TextLabel")
panelTitle.Size               = UDim2.new(1, 0, 0, 22)
panelTitle.Position           = UDim2.new(0, 0, 0, 6)
panelTitle.BackgroundTransparency = 1
panelTitle.Text               = "FPS LOCK"
panelTitle.TextColor3         = Color3.fromRGB(80, 160, 255)
panelTitle.TextTransparency   = 0.05
panelTitle.Font               = Enum.Font.Cartoon
panelTitle.TextScaled         = true
panelTitle.BorderSizePixel    = 0
panelTitle.ZIndex             = 6
panelTitle.Parent             = fpsPanel

-- Toggle ON/OFF button (top-right of panel)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size                = UDim2.new(0, 52, 0, 20)
toggleBtn.Position            = UDim2.new(1, -58, 0, 7)
toggleBtn.BackgroundColor3    = Color3.fromRGB(0, 40, 120)
toggleBtn.Text                = "ON"
toggleBtn.TextColor3          = Color3.fromRGB(80, 200, 255)
toggleBtn.TextScaled          = true
toggleBtn.Font                = Enum.Font.Cartoon
toggleBtn.BorderSizePixel     = 0
toggleBtn.AutoButtonColor     = false
toggleBtn.ZIndex              = 7
toggleBtn.Parent              = fpsPanel
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", toggleBtn).Color = Color3.fromRGB(0, 80, 200)

-- Preset buttons row
local presets     = {10, 20, 30, 60, 120}
local presetBtns  = {}
local btnW        = 46
local btnGap      = 4
local rowX        = 10
local rowY        = 34

for i, fps in ipairs(presets) do
    local pb = Instance.new("TextButton")
    pb.Size               = UDim2.new(0, btnW, 0, 28)
    pb.Position           = UDim2.new(0, rowX + (i-1)*(btnW+btnGap), 0, rowY)
    pb.BackgroundColor3   = Color3.fromRGB(0, 20, 70)
    pb.Text               = tostring(fps)
    pb.TextColor3         = Color3.fromRGB(120, 180, 255)
    pb.TextScaled         = true
    pb.Font               = Enum.Font.Cartoon
    pb.BorderSizePixel    = 0
    pb.AutoButtonColor    = false
    pb.ZIndex             = 6
    pb.Parent             = fpsPanel
    Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 8)
    local pbStroke = Instance.new("UIStroke", pb)
    pbStroke.Color     = Color3.fromRGB(0, 50, 150)
    pbStroke.Thickness = 1.2
    presetBtns[i] = {btn=pb, stroke=pbStroke, fps=fps}
end

-- Custom FPS row
local customLabel = Instance.new("TextLabel")
customLabel.Size               = UDim2.new(0, 70, 0, 26)
customLabel.Position           = UDim2.new(0, 10, 0, 70)
customLabel.BackgroundTransparency = 1
customLabel.Text               = "Custom:"
customLabel.TextColor3         = Color3.fromRGB(80, 130, 210)
customLabel.TextTransparency   = 0.1
customLabel.Font               = Enum.Font.Cartoon
customLabel.TextScaled         = true
customLabel.BorderSizePixel    = 0
customLabel.ZIndex             = 6
customLabel.Parent             = fpsPanel

local customBox = Instance.new("TextBox")
customBox.Size               = UDim2.new(0, 70, 0, 26)
customBox.Position           = UDim2.new(0, 84, 0, 70)
customBox.BackgroundColor3   = Color3.fromRGB(0, 12, 40)
customBox.Text               = ""
customBox.PlaceholderText    = "e.g. 45"
customBox.PlaceholderColor3  = Color3.fromRGB(50, 70, 120)
customBox.TextColor3         = Color3.fromRGB(180, 220, 255)
customBox.TextScaled         = true
customBox.Font               = Enum.Font.Cartoon
customBox.BorderSizePixel    = 0
customBox.ClearTextOnFocus   = true
customBox.ZIndex             = 6
customBox.Parent             = fpsPanel
Instance.new("UICorner", customBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", customBox).Color = Color3.fromRGB(0, 50, 150)

local setBtn = Instance.new("TextButton")
setBtn.Size               = UDim2.new(0, 56, 0, 26)
setBtn.Position           = UDim2.new(0, 160, 0, 70)
setBtn.BackgroundColor3   = Color3.fromRGB(0, 50, 160)
setBtn.Text               = "✔ SET"
setBtn.TextColor3         = Color3.fromRGB(180, 220, 255)
setBtn.TextScaled         = true
setBtn.Font               = Enum.Font.Cartoon
setBtn.BorderSizePixel    = 0
setBtn.AutoButtonColor    = false
setBtn.ZIndex             = 6
setBtn.Parent             = fpsPanel
Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", setBtn).Color = Color3.fromRGB(0, 80, 220)

-- Current FPS display (right side of custom row)
local curFpsLbl = Instance.new("TextLabel")
curFpsLbl.Size               = UDim2.new(0, 50, 0, 26)
curFpsLbl.Position           = UDim2.new(0, 222, 0, 70)
curFpsLbl.BackgroundTransparency = 1
curFpsLbl.Text               = "20 fps"
curFpsLbl.TextColor3         = Color3.fromRGB(50, 120, 220)
curFpsLbl.TextTransparency   = 0.1
curFpsLbl.Font               = Enum.Font.Cartoon
curFpsLbl.TextScaled         = true
curFpsLbl.BorderSizePixel    = 0
curFpsLbl.ZIndex             = 6
curFpsLbl.Parent             = fpsPanel

-- ── State & refresh helpers ─────────────────────────────────────────
local activePresetIdx = 2  -- index into presets table (20 fps default)

local function highlightPresets()
    for i, data in ipairs(presetBtns) do
        local active = fpsLocked and (data.fps == fpsTarget)
        data.btn.BackgroundColor3 = active
            and Color3.fromRGB(0, 50, 160)
            or  Color3.fromRGB(0, 20, 70)
        data.btn.TextColor3 = active
            and Color3.fromRGB(200, 230, 255)
            or  Color3.fromRGB(120, 180, 255)
        data.stroke.Color = active
            and Color3.fromRGB(0, 100, 255)
            or  Color3.fromRGB(0, 50, 150)
    end
end

local function refreshToggleBtn()
    if fpsLocked then
        toggleBtn.Text            = "ON"
        toggleBtn.TextColor3      = Color3.fromRGB(80, 200, 255)
        toggleBtn.BackgroundColor3= Color3.fromRGB(0, 40, 120)
    else
        toggleBtn.Text            = "OFF"
        toggleBtn.TextColor3      = Color3.fromRGB(100, 100, 140)
        toggleBtn.BackgroundColor3= Color3.fromRGB(15, 15, 30)
    end
end

local function refreshAll()
    curFpsLbl.Text = fpsLocked and (fpsTarget.." fps") or "free"
    panelTitle.Text = fpsLocked
        and string.format("FPS LOCK: %d", fpsTarget)
        or  "FPS LOCK: OFF"
    highlightPresets()
    refreshToggleBtn()
end

-- Preset button clicks
for i, data in ipairs(presetBtns) do
    data.btn.MouseButton1Click:Connect(function()
        fpsLocked = true
        setFpsTarget(data.fps)
        lastFrame = tick()
        refreshAll()
    end)
    data.btn.MouseEnter:Connect(function()
        data.btn.BackgroundTransparency = 0.35
    end)
    data.btn.MouseLeave:Connect(function()
        data.btn.BackgroundTransparency = 0
    end)
end

-- Toggle button
toggleBtn.MouseButton1Click:Connect(function()
    fpsLocked = not fpsLocked
    lastFrame  = tick()
    refreshAll()
end)

-- Custom SET button
setBtn.MouseButton1Click:Connect(function()
    local v = tonumber(customBox.Text)
    if v and v >= 1 and v <= 999 then
        fpsLocked = true
        setFpsTarget(math.floor(v))
        lastFrame     = tick()
        customBox.Text = ""
        refreshAll()
    else
        customBox.Text = ""
        customBox.PlaceholderText = "1–999 only!"
    end
end)

-- Also trigger on Enter key inside the box
customBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local v = tonumber(customBox.Text)
        if v and v >= 1 and v <= 999 then
            fpsLocked = true
            setFpsTarget(math.floor(v))
            lastFrame     = tick()
            customBox.Text = ""
            refreshAll()
        end
    end
end)

-- Hover on SET
setBtn.MouseEnter:Connect(function() setBtn.BackgroundTransparency = 0.35 end)
setBtn.MouseLeave:Connect(function() setBtn.BackgroundTransparency = 0 end)

refreshAll()


-- =====================================================================
-- LIVE TIMER  (1s interval — zero per-frame render cost)
-- Switches to HH:MM:SS format after one hour
-- =====================================================================
local startTime = tick()

task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = math.floor(tick() - startTime)
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        if h > 0 then
            timerLabel.Text = string.format("Time Elapsed: %02d:%02d:%02d", h, m, s)
        else
            timerLabel.Text = string.format("Time Elapsed: %02d:%02d", m, s)
        end
    end
end)

-- =====================================================================
-- ANTI-AFK AUTO-JUMP  (randomised interval to avoid pattern detection)
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(4.7 + math.random(0, 60) / 100)
        if humanoid and humanoid.Parent
        and humanoid.Health > 0
        and humanoid.FloorMaterial ~= Enum.Material.Air then
            pcall(function()
                humanoid.Jump = true
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
                task.wait(0.07)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end
    end
end)

print("✅ AFK Guard active | Lag reduction applied | FPS cap 20 | Timer started")
print("   Left-click FPS button to cycle 10 / 20 / 30 / 60")
print("   Right-click FPS button to toggle cap ON / OFF")
