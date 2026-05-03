-- ╔══════════════════════════════════════════════════════════════╗
-- ║  AUTO CLICKER by Merciful                          v7        ║
-- ║  H = Toggle | C = Lock pos | Left CTRL = Hide UI            ║
-- ║  L = Toggle Lag Reduction                                    ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local ContentProvider     = game:GetService("ContentProvider")
local player              = Players.LocalPlayer
local character           = player.Character or player.CharacterAdded:Wait()
local humanoid            = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    character = c
    humanoid  = c:WaitForChild("Humanoid")
end)

-- =====================================================================
-- LAG REDUCTION
-- =====================================================================
local lagEnabled = true

local LagSettings = {
    Textures      = true,
    VisualEffects = true,
    Parts         = true,
    Particles     = true,
    Sky           = true,
    Sound         = true,
    LOD           = true,
}

-- Save originals for restore
local origQuality    = nil
pcall(function() origQuality = settings().Rendering.QualityLevel end)
local origShadows    = Lighting.GlobalShadows
local origFogEnd     = Lighting.FogEnd
local origFogStart   = Lighting.FogStart
local origAmbient    = Lighting.Ambient
local origBrightness = Lighting.Brightness

local SKY_TYPES = {
    "Sky","Atmosphere","BloomEffect","BlurEffect","ColorCorrectionEffect",
    "SunRaysEffect","DepthOfFieldEffect","BlackAndWhiteEffect",
    "BrightnessEffect","EqualizeEffect","ContrastEffect","SelectiveColorEffect",
}

local modifiedParts    = {}
local hiddenDecals     = {}
local clearedTextures  = {}
local disabledSounds   = {}
local detachedLighting = {}

local lightingChildConn, lightingDescConn, wsConn

local function nukeLightingChild(obj)
    for _, t in ipairs(SKY_TYPES) do
        if obj:IsA(t) then
            table.insert(detachedLighting, obj)
            pcall(function() obj.Parent = nil end)
            return
        end
    end
end

local function sweepObj(obj)
    if not lagEnabled then return end

    if LagSettings.Particles then
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke")
        or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") then
            pcall(function() obj:Destroy() end)
            return
        end
    end

    if LagSettings.Textures then
        if obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                table.insert(hiddenDecals, {obj=obj, orig=obj.Transparency})
                obj.Transparency = 1
            end)
        end
        if obj:IsA("SurfaceAppearance") then
            pcall(function() obj:Destroy() end)
            return
        end
        if obj:IsA("SpecialMesh") then
            pcall(function()
                table.insert(clearedTextures, {obj=obj, origId=obj.TextureId, field="TextureId"})
                obj.TextureId = ""
            end)
        end
        if obj:IsA("MeshPart") then
            pcall(function()
                table.insert(clearedTextures, {obj=obj, origId=obj.TextureID, field="TextureID"})
                obj.TextureID = ""
            end)
        end
    end

    if LagSettings.Parts and obj:IsA("BasePart") then
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

    if LagSettings.VisualEffects then
        for _, t in ipairs(SKY_TYPES) do
            if obj:IsA(t) then
                pcall(function() obj:Destroy() end)
                return
            end
        end
    end

    if LagSettings.Sound and obj:IsA("Sound") then
        pcall(function()
            table.insert(disabledSounds, {obj=obj, vol=obj.Volume})
            obj.Volume = 0
        end)
    end

    if LagSettings.LOD and obj:IsA("LocalScript") then
        local inChar = character and obj:IsDescendantOf(character)
        if not inChar then
            pcall(function() obj.Disabled = true end)
        end
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

    for _, obj in ipairs(Lighting:GetChildren()) do
        nukeLightingChild(obj)
    end
    lightingChildConn = Lighting.ChildAdded:Connect(nukeLightingChild)
    lightingDescConn  = Lighting.DescendantAdded:Connect(nukeLightingChild)

    for _, obj in ipairs(workspace:GetDescendants()) do
        sweepObj(obj)
    end
    wsConn = workspace.DescendantAdded:Connect(sweepObj)

    pcall(function() ContentProvider.RequestQueueSize = 0 end)

    print("[AC·Merciful] Lag reduction ENABLED")
end

local function removeLagReduction()
    if lightingChildConn then lightingChildConn:Disconnect(); lightingChildConn = nil end
    if lightingDescConn  then lightingDescConn:Disconnect();  lightingDescConn  = nil end
    if wsConn            then wsConn:Disconnect();            wsConn            = nil end

    pcall(function()
        if origQuality then settings().Rendering.QualityLevel = origQuality end
        Lighting.GlobalShadows = origShadows
        Lighting.FogEnd        = origFogEnd
        Lighting.FogStart      = origFogStart
        Lighting.Ambient       = origAmbient
        Lighting.Brightness    = origBrightness
    end)

    for _, obj in ipairs(detachedLighting) do
        pcall(function() obj.Parent = Lighting end)
    end
    table.clear(detachedLighting)

    for _, e in ipairs(modifiedParts) do
        pcall(function()
            if e.obj and e.obj.Parent then
                e.obj.Material       = e.mat
                e.obj.CastShadow     = e.shadow
                e.obj.Reflectance    = e.ref
                e.obj.RenderFidelity = e.fidelity
            end
        end)
    end
    table.clear(modifiedParts)

    for _, e in ipairs(hiddenDecals) do
        pcall(function()
            if e.obj and e.obj.Parent then e.obj.Transparency = e.orig end
        end)
    end
    table.clear(hiddenDecals)

    for _, e in ipairs(clearedTextures) do
        pcall(function()
            if e.obj and e.obj.Parent then e.obj[e.field] = e.origId end
        end)
    end
    table.clear(clearedTextures)

    for _, e in ipairs(disabledSounds) do
        pcall(function()
            if e.obj and e.obj.Parent then e.obj.Volume = e.vol end
        end)
    end
    table.clear(disabledSounds)

    print("[AC·Merciful] Lag reduction DISABLED")
end

-- ── Apply immediately on load ────────────────────────────────────────
applyLagReduction()

-- =====================================================================
-- FPS LOCK
-- =====================================================================
local fpsLocked    = true
local minFrameTime = 1 / 20
local lastFrame    = tick()

RunService.RenderStepped:Connect(function()
    if fpsLocked then
        local now = tick()
        if now - lastFrame < minFrameTime then
            while tick() < lastFrame + minFrameTime do end
        end
        lastFrame = tick()
    end
end)

-- =====================================================================
-- ANTI-AFK AUTO-JUMP
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(4.7 + math.random(0, 60) / 100)
        if humanoid and humanoid.Parent and humanoid.Health > 0
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

-- =====================================================================
-- STATE
-- Position lock stores scale [0..1] relative to viewport size.
-- This means the locked click point stays correct even if the
-- Roblox window is resized — the scale is converted back to pixels
-- every RenderStepped frame before being used in the click loop.
-- =====================================================================
local state = {
    clicking    = false,
    delay       = 0.002,
    useFixedPos = false,
    fixedScaleX = 0,   -- stored as fraction of viewport width
    fixedScaleY = 0,   -- stored as fraction of viewport height
    fixedX      = 0,   -- resolved pixels (updated every frame)
    fixedY      = 0,
}

local function delaytoCPS(d)
    return d <= 0 and "∞" or tostring(math.floor(1/d))
end

-- Re-resolve pixel coords from scale every frame so resize is handled
RunService.RenderStepped:Connect(function()
    if state.useFixedPos then
        local vp = workspace.CurrentCamera.ViewportSize
        state.fixedX = math.floor(state.fixedScaleX * vp.X)
        state.fixedY = math.floor(state.fixedScaleY * vp.Y)
    end
end)

-- =====================================================================
-- GUI PARENT (executor-safe)
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
for _, n in ipairs({"AC_Merciful_v7","AC_Merciful_Marker_v7"}) do
    local o = guiParent:FindFirstChild(n)
    if o then o:Destroy() end
end

-- =====================================================================
-- COLOUR PALETTE
-- =====================================================================
local C = {
    void0   = Color3.fromRGB(4,   6,  14),
    void1   = Color3.fromRGB(8,  12,  24),
    panel   = Color3.fromRGB(10, 16,  30),
    inputBg = Color3.fromRGB(6,  10,  22),
    cyan0   = Color3.fromRGB(0,  255, 240),
    cyan1   = Color3.fromRGB(0,  180, 200),
    cyan2   = Color3.fromRGB(0,  130, 155),
    cyan3   = Color3.fromRGB(0,   50,  75),
    cyan4   = Color3.fromRGB(0,   20,  40),
    mag0    = Color3.fromRGB(255,  60, 200),
    white   = Color3.fromRGB(220, 240, 255),
    sub     = Color3.fromRGB(75,  115, 155),
    green   = Color3.fromRGB(40,  220, 110),
    red     = Color3.fromRGB(220,  45,  75),
    marker  = Color3.fromRGB(0,   255, 200),
    orange  = Color3.fromRGB(255, 140,  30),
}

-- =====================================================================
-- ROOT GUI — anchored RIGHT side
-- =====================================================================
local gui = Instance.new("ScreenGui")
gui.Name            = "AC_Merciful_v7"
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset  = false
gui.Parent          = guiParent

local W, H = 365, 710

local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, W, 0, H)
frame.AnchorPoint      = Vector2.new(1, 0.5)
frame.Position         = UDim2.new(1, -18, 0.5, 0)
frame.BackgroundColor3 = C.void0
frame.BorderSizePixel  = 0
frame.Active           = true
frame.ClipsDescendants = true
frame.Parent           = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local outerStroke = Instance.new("UIStroke", frame)
outerStroke.Color        = C.cyan2
outerStroke.Thickness    = 1.8
outerStroke.Transparency = 0.2

task.spawn(function()
    local t = 0
    while true do
        RunService.RenderStepped:Wait()
        t = t + 0.02
        outerStroke.Transparency = 0.15 + (math.sin(t)+1)/2 * 0.35
    end
end)

-- Scanlines
local scanContainer = Instance.new("Frame")
scanContainer.Size                   = UDim2.new(1,0,1,0)
scanContainer.BackgroundTransparency = 1
scanContainer.ClipsDescendants       = true
scanContainer.ZIndex                 = 1
scanContainer.Parent                 = frame
for i = 0, 72 do
    local sl = Instance.new("Frame")
    sl.Size                   = UDim2.new(1,0,0,1)
    sl.Position               = UDim2.new(0,0,0,i*10)
    sl.BackgroundColor3       = C.cyan3
    sl.BackgroundTransparency = 0.82
    sl.BorderSizePixel        = 0
    sl.ZIndex                 = 1
    sl.Parent                 = scanContainer
end

-- Grid
local grid = Instance.new("Frame")
grid.Size = UDim2.new(1,0,1,0); grid.BackgroundTransparency = 1
grid.ClipsDescendants = true; grid.ZIndex = 0; grid.Parent = frame
for i = 1, 26 do
    local gl = Instance.new("Frame")
    gl.Size = UDim2.new(1,0,0,1); gl.Position = UDim2.new(0,0,0,i*28)
    gl.BackgroundColor3 = C.cyan3; gl.BackgroundTransparency = 0.78
    gl.BorderSizePixel = 0; gl.ZIndex = 0; gl.Parent = grid
end
for i = 1, 14 do
    local gl = Instance.new("Frame")
    gl.Size = UDim2.new(0,1,1,0); gl.Position = UDim2.new(0,i*28,0,0)
    gl.BackgroundColor3 = C.cyan3; gl.BackgroundTransparency = 0.78
    gl.BorderSizePixel = 0; gl.ZIndex = 0; gl.Parent = grid
end

-- =====================================================================
-- TITLE BAR
-- =====================================================================
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1,0,0,84)
titleBar.BackgroundColor3 = C.void1
titleBar.BorderSizePixel  = 0; titleBar.ZIndex = 4; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,16)

local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1,0,0.5,0); tbFix.Position = UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3 = C.void1; tbFix.BorderSizePixel = 0
tbFix.ZIndex = 4; tbFix.Parent = titleBar

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1,0,0,2); titleLine.Position = UDim2.new(0,0,1,-2)
titleLine.BackgroundColor3 = C.cyan0; titleLine.BorderSizePixel = 0
titleLine.ZIndex = 5; titleLine.Parent = titleBar

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0,80,0,2); accentBar.Position = UDim2.new(0,0,1,-4)
accentBar.BackgroundColor3 = C.mag0; accentBar.BorderSizePixel = 0
accentBar.ZIndex = 6; accentBar.Parent = titleBar
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0,2)

task.spawn(function()
    local dir = 1; local pos = 0
    while true do
        RunService.RenderStepped:Wait()
        pos = pos + dir * 1.4
        if pos >= W-80 then dir = -1 end
        if pos <= 0     then dir =  1 end
        accentBar.Position = UDim2.new(0, pos, 1, -4)
    end
end)

local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0,54,0,54); logoBox.Position = UDim2.new(0,14,0,14)
logoBox.BackgroundColor3 = C.cyan4; logoBox.BorderSizePixel = 0
logoBox.ZIndex = 6; logoBox.Parent = titleBar
Instance.new("UICorner", logoBox).CornerRadius = UDim.new(0,12)

local logoStroke = Instance.new("UIStroke", logoBox)
logoStroke.Color = C.cyan0; logoStroke.Thickness = 1.8

local logoHex = Instance.new("TextLabel")
logoHex.Size = UDim2.new(1,0,1,0); logoHex.BackgroundTransparency = 1
logoHex.Text = "⬡"; logoHex.TextColor3 = C.cyan0
logoHex.TextScaled = true; logoHex.ZIndex = 7; logoHex.Parent = logoBox

local logoStar = Instance.new("TextLabel")
logoStar.Size = UDim2.new(0.52,0,0.52,0); logoStar.Position = UDim2.new(0.24,0,0.24,0)
logoStar.BackgroundTransparency = 1; logoStar.Text = "✦"
logoStar.TextColor3 = C.mag0; logoStar.TextScaled = true
logoStar.ZIndex = 8; logoStar.Parent = logoBox

task.spawn(function()
    local t = 0
    while true do
        RunService.RenderStepped:Wait()
        t = t + 0.04
        logoStroke.Transparency = 0.1 + (math.sin(t)+1)/2 * 0.6
    end
end)

local hexAlpha = {0.55,0.40,0.60,0.35,0.50}
for i = 1, 5 do
    local hl = Instance.new("TextLabel")
    hl.Size = UDim2.new(0,26,0,26); hl.Position = UDim2.new(1,-(i*28)-4,0,8)
    hl.BackgroundTransparency = 1; hl.Text = "⬡"
    hl.TextColor3 = C.cyan0; hl.TextTransparency = hexAlpha[i]
    hl.TextScaled = true; hl.ZIndex = 5; hl.Parent = titleBar
end

local titleTxt = Instance.new("TextLabel")
titleTxt.Size = UDim2.new(1,-78,0,30); titleTxt.Position = UDim2.new(0,76,0,10)
titleTxt.BackgroundTransparency = 1; titleTxt.Text = "AUTO CLICKER"
titleTxt.TextColor3 = C.cyan0; titleTxt.TextScaled = true
titleTxt.Font = Enum.Font.GothamBold; titleTxt.TextXAlignment = Enum.TextXAlignment.Left
titleTxt.ZIndex = 6; titleTxt.Parent = titleBar

local subTxt = Instance.new("TextLabel")
subTxt.Size = UDim2.new(1,-78,0,16); subTxt.Position = UDim2.new(0,76,0,44)
subTxt.BackgroundTransparency = 1
subTxt.Text = "by Merciful  ·  CTRL=hide · L=lag toggle"
subTxt.TextColor3 = C.sub; subTxt.TextScaled = true
subTxt.Font = Enum.Font.Gotham; subTxt.TextXAlignment = Enum.TextXAlignment.Left
subTxt.ZIndex = 6; subTxt.Parent = titleBar

local verBadge = Instance.new("TextLabel")
verBadge.Size = UDim2.new(0,36,0,16); verBadge.Position = UDim2.new(0,76,0,62)
verBadge.BackgroundColor3 = C.cyan3; verBadge.BorderSizePixel = 0
verBadge.Text = "v7"; verBadge.TextColor3 = C.cyan0
verBadge.TextScaled = true; verBadge.Font = Enum.Font.GothamBold
verBadge.ZIndex = 7; verBadge.Parent = titleBar
Instance.new("UICorner", verBadge).CornerRadius = UDim.new(0,4)
Instance.new("UIStroke", verBadge).Color = C.cyan2

-- =====================================================================
-- UI HELPERS
-- =====================================================================
local function divider(y, label)
    local pip = Instance.new("Frame")
    pip.Size = UDim2.new(0,3,0,16); pip.Position = UDim2.new(0,12,0,y+1)
    pip.BackgroundColor3 = C.cyan0; pip.BorderSizePixel = 0
    pip.ZIndex = 3; pip.Parent = frame
    Instance.new("UICorner", pip).CornerRadius = UDim.new(0,2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-22,0,18); lbl.Position = UDim2.new(0,20,0,y)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = C.cyan1; lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3; lbl.Parent = frame
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1,-24,0,1); line.Position = UDim2.new(0,12,0,y+18)
    line.BackgroundColor3 = C.cyan3; line.BorderSizePixel = 0
    line.ZIndex = 2; line.Parent = frame
end

local function card(y, h)
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1,-24,0,h); p.Position = UDim2.new(0,12,0,y)
    p.BackgroundColor3 = C.panel; p.BorderSizePixel = 0
    p.ZIndex = 3; p.Parent = frame
    Instance.new("UICorner", p).CornerRadius = UDim.new(0,10)
    local s = Instance.new("UIStroke", p); s.Color = C.cyan3; s.Thickness = 1
    return p
end

local function nBtn(par, txt, x, y, w, h, col, z)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,h); b.Position = UDim2.new(0,x,0,y)
    b.BackgroundColor3 = col; b.Text = txt
    b.TextColor3 = C.white; b.TextScaled = true
    b.Font = Enum.Font.GothamBold; b.BorderSizePixel = 0
    b.AutoButtonColor = true; b.ZIndex = z or 4; b.Parent = par
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(
        math.min(col.R*255+50,255),
        math.min(col.G*255+50,255),
        math.min(col.B*255+50,255))
    s.Thickness = 1
    return b
end

local function inputBox(par, x, y, w, h, default, placeholder)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0,w,0,h); box.Position = UDim2.new(0,x,0,y)
    box.BackgroundColor3 = C.inputBg; box.Text = default
    box.TextColor3 = C.white; box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = C.sub; box.TextScaled = true
    box.Font = Enum.Font.GothamBold; box.BorderSizePixel = 0
    box.ClearTextOnFocus = false; box.ZIndex = 4; box.Parent = par
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", box).Color = C.cyan2
    return box
end

local function glowDot(par, x, y, col)
    local outer = Instance.new("Frame")
    outer.Size = UDim2.new(0,16,0,16); outer.Position = UDim2.new(0,x,0,y)
    outer.BackgroundTransparency = 1; outer.BorderSizePixel = 0
    outer.ZIndex = 5; outer.Parent = par
    Instance.new("UICorner", outer).CornerRadius = UDim.new(0.5,0)
    local stroke = Instance.new("UIStroke", outer); stroke.Color = col; stroke.Thickness = 2

    local inner = Instance.new("Frame")
    inner.AnchorPoint = Vector2.new(0.5,0.5)
    inner.Size = UDim2.new(0,6,0,6); inner.Position = UDim2.new(0.5,0,0.5,0)
    inner.BackgroundColor3 = col; inner.BorderSizePixel = 0
    inner.ZIndex = 6; inner.Parent = outer
    Instance.new("UICorner", inner).CornerRadius = UDim.new(0.5,0)

    task.spawn(function()
        local t = math.random(0,62)/10
        while true do
            RunService.RenderStepped:Wait()
            t = t + 0.05
            stroke.Transparency = 0.2 + (math.sin(t)+1)/2 * 0.55
        end
    end)
    return inner
end

-- =====================================================================
-- LOCK MARKER OVERLAY
-- markerGui has IgnoreGuiInset=true → covers the full raw viewport.
-- All elements are positioned with UDim2 SCALE so they automatically
-- track the locked point when the window is resized.
-- =====================================================================
local markerGui = Instance.new("ScreenGui")
markerGui.Name           = "AC_Merciful_Marker_v7"
markerGui.ResetOnSpawn   = false
markerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
markerGui.IgnoreGuiInset = true
markerGui.Parent         = guiParent

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5,0.5); ring.Size = UDim2.new(0,36,0,36)
ring.BackgroundTransparency = 1; ring.BorderSizePixel = 0
ring.Visible = false; ring.ZIndex = 20; ring.Parent = markerGui
Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5,0)
local rs = Instance.new("UIStroke", ring); rs.Color = C.marker; rs.Thickness = 2.5

local mDot = Instance.new("Frame")
mDot.AnchorPoint = Vector2.new(0.5,0.5); mDot.Size = UDim2.new(0,8,0,8)
mDot.BackgroundColor3 = C.marker; mDot.BorderSizePixel = 0
mDot.Visible = false; mDot.ZIndex = 21; mDot.Parent = markerGui
Instance.new("UICorner", mDot).CornerRadius = UDim.new(0.5,0)

local lH = Instance.new("Frame"); lH.AnchorPoint = Vector2.new(0.5,0.5)
lH.Size = UDim2.new(0,28,0,1); lH.BackgroundColor3 = C.marker
lH.BorderSizePixel = 0; lH.Visible = false; lH.ZIndex = 21; lH.Parent = markerGui

local lV = Instance.new("Frame"); lV.AnchorPoint = Vector2.new(0.5,0.5)
lV.Size = UDim2.new(0,1,0,28); lV.BackgroundColor3 = C.marker
lV.BorderSizePixel = 0; lV.Visible = false; lV.ZIndex = 21; lV.Parent = markerGui

local mLbl = Instance.new("TextLabel")
mLbl.AnchorPoint = Vector2.new(0.5,1); mLbl.Size = UDim2.new(0,120,0,22)
mLbl.BackgroundColor3 = C.void0; mLbl.BackgroundTransparency = 0.1
mLbl.Text = "◈ LOCKED"; mLbl.TextColor3 = C.marker; mLbl.TextScaled = true
mLbl.Font = Enum.Font.GothamBold; mLbl.Visible = false
mLbl.ZIndex = 22; mLbl.Parent = markerGui
Instance.new("UICorner", mLbl).CornerRadius = UDim.new(0,5)
Instance.new("UIStroke", mLbl).Color = C.marker

-- Every frame, reposition marker elements using stored scale coords.
-- This makes them stay on the locked point even after window resize.
RunService.RenderStepped:Connect(function()
    if not state.useFixedPos then return end
    local sx, sy = state.fixedScaleX, state.fixedScaleY
    local sp = UDim2.new(sx, 0, sy, 0)
    ring.Position = sp; mDot.Position = sp
    lH.Position   = sp; lV.Position   = sp
    mLbl.Position = UDim2.new(sx, 0, sy, -30)
end)

local function showMarker()
    ring.Visible = true; mDot.Visible = true
    lH.Visible   = true; lV.Visible   = true
    mLbl.Visible = true
end
local function hideMarker()
    ring.Visible = false; mDot.Visible = false
    lH.Visible   = false; lV.Visible   = false
    mLbl.Visible = false
end

-- =====================================================================
-- SECTION: CLICK DELAY / SPEED
-- =====================================================================
divider(96, "CLICK DELAY / SPEED")
local spdCard = card(118, 106)

local speedDispBg = Instance.new("Frame")
speedDispBg.Size = UDim2.new(0,90,0,42); speedDispBg.Position = UDim2.new(0,6,0,8)
speedDispBg.BackgroundColor3 = C.inputBg; speedDispBg.BorderSizePixel = 0
speedDispBg.ZIndex = 4; speedDispBg.Parent = spdCard
Instance.new("UICorner", speedDispBg).CornerRadius = UDim.new(0,8)
local bStroke = Instance.new("UIStroke", speedDispBg); bStroke.Color = C.cyan0; bStroke.Thickness = 1.5

task.spawn(function()
    local t = 1.5
    while true do
        RunService.RenderStepped:Wait()
        t = t + 0.035
        bStroke.Transparency = 0.1 + (math.sin(t)+1)/2 * 0.5
    end
end)

local speedDisp = Instance.new("TextLabel")
speedDisp.Size = UDim2.new(1,0,0.55,0); speedDisp.Position = UDim2.new(0,0,0.05,0)
speedDisp.BackgroundTransparency = 1
speedDisp.TextColor3 = C.cyan0; speedDisp.TextScaled = true
speedDisp.Font = Enum.Font.GothamBold; speedDisp.ZIndex = 5; speedDisp.Parent = speedDispBg

local cpsLabel = Instance.new("TextLabel")
cpsLabel.Size = UDim2.new(1,0,0.35,0); cpsLabel.Position = UDim2.new(0,0,0.62,0)
cpsLabel.BackgroundTransparency = 1; cpsLabel.Text = "clicks/sec"
cpsLabel.TextColor3 = C.sub; cpsLabel.TextScaled = true
cpsLabel.Font = Enum.Font.Gotham; cpsLabel.ZIndex = 5; cpsLabel.Parent = speedDispBg

local function refreshDisp()
    speedDisp.Text = delaytoCPS(state.delay)
end
refreshDisp()

local sTrack = Instance.new("Frame")
sTrack.Size = UDim2.new(0,148,0,8); sTrack.Position = UDim2.new(0,104,0,25)
sTrack.BackgroundColor3 = C.inputBg; sTrack.BorderSizePixel = 0
sTrack.ZIndex = 4; sTrack.Parent = spdCard
Instance.new("UICorner", sTrack).CornerRadius = UDim.new(0,4)
Instance.new("UIStroke", sTrack).Color = C.cyan3

local sFill = Instance.new("Frame")
sFill.Size = UDim2.new(0.09,0,1,0); sFill.BackgroundColor3 = C.cyan1
sFill.BorderSizePixel = 0; sFill.ZIndex = 5; sFill.Parent = sTrack
Instance.new("UICorner", sFill).CornerRadius = UDim.new(0,4)

local sKnob = Instance.new("TextButton")
sKnob.Size = UDim2.new(0,20,0,20); sKnob.Position = UDim2.new(0.09,-10,0.5,-10)
sKnob.BackgroundColor3 = C.cyan0; sKnob.Text = ""
sKnob.BorderSizePixel = 0; sKnob.ZIndex = 6; sKnob.Parent = sTrack
Instance.new("UICorner", sKnob).CornerRadius = UDim.new(0.5,0)
Instance.new("UIStroke", sKnob).Color = C.white

local function applyPct(pct)
    pct = math.clamp(pct, 0, 1)
    local cps = math.clamp(math.round(1 + pct*499), 1, 500)
    state.delay = 1/cps
    sFill.Size = UDim2.new(pct,0,1,0)
    sKnob.Position = UDim2.new(pct,-10,0.5,-10)
    refreshDisp()
end

local sDrag = false
sKnob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then sDrag = true end
end)
sTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        sDrag = true
        applyPct((i.Position.X - sTrack.AbsolutePosition.X) / sTrack.AbsoluteSize.X)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if sDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        applyPct((i.Position.X - sTrack.AbsolutePosition.X) / sTrack.AbsoluteSize.X)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then sDrag = false end
end)

nBtn(spdCard,"−",258,8,30,42,C.cyan3,4).MouseButton1Click:Connect(function()
    local cps = math.max(1, math.floor(1/state.delay)-10)
    state.delay = 1/cps; applyPct((cps-1)/499)
end)
nBtn(spdCard,"+",292,8,30,42,C.cyan2,4).MouseButton1Click:Connect(function()
    local cps = math.min(500, math.floor(1/state.delay)+10)
    state.delay = 1/cps; applyPct((cps-1)/499)
end)

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0,100,0,20); delayLabel.Position = UDim2.new(0,6,0,60)
delayLabel.BackgroundTransparency = 1; delayLabel.Text = "Custom delay (s):"
delayLabel.TextColor3 = C.sub; delayLabel.TextScaled = true
delayLabel.Font = Enum.Font.Gotham; delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.ZIndex = 4; delayLabel.Parent = spdCard

local delayBox = inputBox(spdCard, 6, 80, 120, 22, "0.002", "e.g. 0.002")

local delayHint = Instance.new("TextLabel")
delayHint.Size = UDim2.new(0,130,0,22); delayHint.Position = UDim2.new(0,132,0,80)
delayHint.BackgroundTransparency = 1; delayHint.Text = "0.002 ≈ 500 CPS"
delayHint.TextColor3 = C.sub; delayHint.TextScaled = true
delayHint.Font = Enum.Font.Gotham; delayHint.TextXAlignment = Enum.TextXAlignment.Left
delayHint.ZIndex = 4; delayHint.Parent = spdCard

local applyDelayBtn = nBtn(spdCard,"✔ SET",282,78,48,24,C.cyan2,4)
applyDelayBtn.MouseButton1Click:Connect(function()
    local v = tonumber(delayBox.Text)
    if v and v > 0 then
        state.delay = math.max(0.001, v)
        delayBox.Text = tostring(state.delay)
        local cps = math.clamp(math.round(1/state.delay),1,500)
        applyPct((cps-1)/499); refreshDisp()
    else
        delayBox.Text = tostring(state.delay)
    end
end)

-- =====================================================================
-- SECTION: POSITION LOCK
-- =====================================================================
divider(234, "POSITION LOCK")
local lockCard = card(256, 100)

local lockInfo = Instance.new("TextLabel")
lockInfo.Size = UDim2.new(1,-28,0,22); lockInfo.Position = UDim2.new(0,26,0,7)
lockInfo.BackgroundTransparency = 1; lockInfo.Text = "OFF — following live cursor"
lockInfo.TextColor3 = C.sub; lockInfo.TextScaled = true
lockInfo.Font = Enum.Font.Gotham; lockInfo.TextXAlignment = Enum.TextXAlignment.Left
lockInfo.ZIndex = 4; lockInfo.Parent = lockCard

local lockHint = Instance.new("TextLabel")
lockHint.Size = UDim2.new(1,-12,0,16); lockHint.Position = UDim2.new(0,10,0,34)
lockHint.BackgroundTransparency = 1; lockHint.Text = "Hover target → press C or click Lock"
lockHint.TextColor3 = C.sub; lockHint.TextScaled = true
lockHint.Font = Enum.Font.Gotham; lockHint.TextXAlignment = Enum.TextXAlignment.Left
lockHint.ZIndex = 4; lockHint.Parent = lockCard

local lockBtn   = nBtn(lockCard,"◈ LOCK HERE [C]",6,60,192,32,C.cyan3,4)
local unlockBtn = nBtn(lockCard,"◎ UNLOCK",202,60,118,32,C.red,4)
unlockBtn.Visible = false

local lockDotInner = glowDot(lockCard, 4, 6, C.sub)

local function applyLock()
    local vp = workspace.CurrentCamera.ViewportSize
    local mp = UserInputService:GetMouseLocation()
    -- Store as scale so the point survives window resizes
    state.fixedScaleX = mp.X / vp.X
    state.fixedScaleY = mp.Y / vp.Y
    state.fixedX = math.floor(mp.X)
    state.fixedY = math.floor(mp.Y)
    state.useFixedPos = true
    lockInfo.Text = string.format("ON · X: %d  Y: %d", state.fixedX, state.fixedY)
    lockInfo.TextColor3 = C.cyan0
    lockDotInner.BackgroundColor3 = C.cyan0
    lockBtn.Visible = false; unlockBtn.Visible = true
    showMarker()
end

local function applyUnlock()
    state.useFixedPos = false
    lockInfo.Text = "OFF — following live cursor"
    lockInfo.TextColor3 = C.sub
    lockDotInner.BackgroundColor3 = C.sub
    lockBtn.Visible = true; unlockBtn.Visible = false
    hideMarker()
end
lockBtn.MouseButton1Click:Connect(applyLock)
unlockBtn.MouseButton1Click:Connect(applyUnlock)

-- =====================================================================
-- SECTION: SYSTEM
-- =====================================================================
divider(366, "SYSTEM")
local sysCard = card(388, 60)

local function sysBadge(x, txt, col, clickFn)
    local bg = Instance.new(clickFn and "TextButton" or "Frame")
    bg.Size = UDim2.new(0,96,0,40); bg.Position = UDim2.new(0,x,0,10)
    bg.BackgroundColor3 = C.inputBg; bg.BorderSizePixel = 0
    bg.ZIndex = 4; bg.Parent = sysCard
    if clickFn then bg.AutoButtonColor = false; bg.Text = "" end
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", bg); stroke.Color = col; stroke.Thickness = 1.4
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1,0,0,2); accent.BackgroundColor3 = col
    accent.BorderSizePixel = 0; accent.ZIndex = 5; accent.Parent = bg
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0,8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,-4); lbl.Position = UDim2.new(0,0,0,4)
    lbl.BackgroundTransparency = 1; lbl.Text = txt; lbl.TextColor3 = col
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold; lbl.ZIndex = 5; lbl.Parent = bg
    if clickFn then bg.MouseButton1Click:Connect(clickFn) end
    return lbl, stroke, bg
end

sysBadge(6, "↑ JUMP\nON", C.green)

local fpsBadgeLbl, fpsBadgeStroke
local function refreshFpsBtn()
    if fpsLocked then
        fpsBadgeLbl.Text       = "🔒 FPS\n20 cap"
        fpsBadgeLbl.TextColor3 = C.cyan1
        fpsBadgeStroke.Color   = C.cyan1
    else
        fpsBadgeLbl.Text       = "🔓 FPS\nFREE"
        fpsBadgeLbl.TextColor3 = C.sub
        fpsBadgeStroke.Color   = C.sub
    end
end
fpsBadgeLbl, fpsBadgeStroke = sysBadge(108, "", C.cyan1, function()
    fpsLocked = not fpsLocked
    lastFrame = tick()
    refreshFpsBtn()
end)
refreshFpsBtn()

local soundMuted = false
local soundBadgeLbl, soundBadgeStroke
local function refreshSoundBtn()
    if soundMuted then
        soundBadgeLbl.Text       = "🔇 SFX\nMUTED"
        soundBadgeLbl.TextColor3 = C.orange
        soundBadgeStroke.Color   = C.orange
    else
        soundBadgeLbl.Text       = "🔊 SFX\nON"
        soundBadgeLbl.TextColor3 = C.sub
        soundBadgeStroke.Color   = C.sub
    end
end
soundBadgeLbl, soundBadgeStroke = sysBadge(210, "", C.sub, function()
    soundMuted = not soundMuted
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Sound") then
            pcall(function() obj.Volume = soundMuted and 0 or 1 end)
        end
    end
    refreshSoundBtn()
end)
refreshSoundBtn()

-- =====================================================================
-- SECTION: LAG REDUCTION (TOGGLEABLE)
-- =====================================================================
divider(458, "LAG REDUCTION")
local lagCard = card(480, 118)

local lagToggleBtn = nBtn(lagCard,"⚡ LAG REDUCTION: ON  [L]",6,6,329,36,C.green,4)

local function refreshLagBtn()
    if lagEnabled then
        lagToggleBtn.BackgroundColor3 = C.green
        lagToggleBtn.Text = "⚡ LAG REDUCTION: ON  [L]"
    else
        lagToggleBtn.BackgroundColor3 = C.red
        lagToggleBtn.Text = "⚡ LAG REDUCTION: OFF  [L]"
    end
end

local function toggleLag()
    lagEnabled = not lagEnabled
    if lagEnabled then applyLagReduction() else removeLagReduction() end
    refreshLagBtn()
end
lagToggleBtn.MouseButton1Click:Connect(toggleLag)

local lagSubOptions = {
    { key="Textures",  label="Textures"  },
    { key="Particles", label="Particles" },
    { key="Parts",     label="Materials" },
    { key="Sound",     label="Sounds"    },
    { key="LOD",       label="Scripts"   },
}

local cbW = 329 / #lagSubOptions
for i, opt in ipairs(lagSubOptions) do
    local col = LagSettings[opt.key] and C.cyan2 or C.sub
    local cbBg = Instance.new("TextButton")
    cbBg.Size = UDim2.new(0, cbW-4, 0, 32)
    cbBg.Position = UDim2.new(0, 6+(i-1)*cbW, 0, 50)
    cbBg.BackgroundColor3 = C.inputBg; cbBg.Text = ""
    cbBg.BorderSizePixel = 0; cbBg.AutoButtonColor = false
    cbBg.ZIndex = 4; cbBg.Parent = lagCard
    Instance.new("UICorner", cbBg).CornerRadius = UDim.new(0,6)
    local cbStroke = Instance.new("UIStroke", cbBg)
    cbStroke.Color = col; cbStroke.Thickness = 1.2

    local cbLbl = Instance.new("TextLabel")
    cbLbl.Size = UDim2.new(1,0,0.55,0)
    cbLbl.BackgroundTransparency = 1; cbLbl.Text = opt.label
    cbLbl.TextColor3 = col; cbLbl.TextScaled = true
    cbLbl.Font = Enum.Font.Gotham; cbLbl.ZIndex = 5; cbLbl.Parent = cbBg

    local cbCheck = Instance.new("TextLabel")
    cbCheck.Size = UDim2.new(1,0,0.42,0); cbCheck.Position = UDim2.new(0,0,0.55,0)
    cbCheck.BackgroundTransparency = 1
    cbCheck.Text = LagSettings[opt.key] and "✔" or "✘"
    cbCheck.TextColor3 = col; cbCheck.TextScaled = true
    cbCheck.Font = Enum.Font.GothamBold; cbCheck.ZIndex = 5; cbCheck.Parent = cbBg

    cbBg.MouseButton1Click:Connect(function()
        LagSettings[opt.key] = not LagSettings[opt.key]
        local nc = LagSettings[opt.key] and C.cyan2 or C.sub
        cbLbl.TextColor3 = nc; cbCheck.TextColor3 = nc; cbStroke.Color = nc
        cbCheck.Text = LagSettings[opt.key] and "✔" or "✘"
    end)
end

local lagInfo = Instance.new("TextLabel")
lagInfo.Size = UDim2.new(1,-12,0,18); lagInfo.Position = UDim2.new(0,6,0,90)
lagInfo.BackgroundTransparency = 1
lagInfo.Text = "Sub-options apply on next re-enable  ·  L = quick toggle"
lagInfo.TextColor3 = C.sub; lagInfo.TextScaled = true
lagInfo.Font = Enum.Font.Gotham; lagInfo.TextXAlignment = Enum.TextXAlignment.Left
lagInfo.ZIndex = 4; lagInfo.Parent = lagCard

-- =====================================================================
-- SECTION: CLICK STATUS
-- =====================================================================
divider(608, "CLICK STATUS")
local statCard = card(630, 38)

local statusDot = glowDot(statCard, 6, 11, C.sub)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1,-32,1,0); statusLbl.Position = UDim2.new(0,28,0,0)
statusLbl.BackgroundTransparency = 1; statusLbl.Text = "IDLE · Press H to activate"
statusLbl.TextColor3 = C.sub; statusLbl.TextScaled = true
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 4; statusLbl.Parent = statCard

-- =====================================================================
-- START / STOP BUTTON
-- =====================================================================
local toggleBtn = nBtn(frame,"▶  START  [H]",12,H-52,W-24,42,C.green,4)

local shimmer = Instance.new("Frame")
shimmer.Size = UDim2.new(0,40,1,0); shimmer.Position = UDim2.new(0,-40,0,0)
shimmer.BackgroundColor3 = Color3.fromRGB(255,255,255)
shimmer.BackgroundTransparency = 0.82; shimmer.BorderSizePixel = 0
shimmer.ZIndex = 5; shimmer.ClipsDescendants = false; shimmer.Parent = toggleBtn
Instance.new("UICorner", shimmer).CornerRadius = UDim.new(0,8)

task.spawn(function()
    while true do
        task.wait(2.8)
        for i = -40, W+40, 4 do
            shimmer.Position = UDim2.new(0, i, 0, 0)
            task.wait(0.012)
        end
    end
end)

local function setActive(on)
    state.clicking = on
    if on then
        toggleBtn.BackgroundColor3 = C.red
        toggleBtn.Text = "⏹  STOP  [H]"
        local ms = math.floor(state.delay*1000)
        statusLbl.Text = "ACTIVE · " .. ms .. "ms" ..
            (state.useFixedPos and (" @ "..state.fixedX..","..state.fixedY) or " · live cursor")
        statusLbl.TextColor3 = C.green
        statusDot.BackgroundColor3 = C.green
    else
        toggleBtn.BackgroundColor3 = C.green
        toggleBtn.Text = "▶  START  [H]"
        statusLbl.Text = "IDLE · Press H to activate"
        statusLbl.TextColor3 = C.sub
        statusDot.BackgroundColor3 = C.sub
    end
end
toggleBtn.MouseButton1Click:Connect(function() setActive(not state.clicking) end)

-- =====================================================================
-- KEYBOARD BINDS
-- =====================================================================
UserInputService.InputBegan:Connect(function(inp, gpe)
    if inp.KeyCode == Enum.KeyCode.LeftControl then
        gui.Enabled = not gui.Enabled
        return
    end
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.H then
        setActive(not state.clicking)
    elseif inp.KeyCode == Enum.KeyCode.C then
        if state.useFixedPos then applyUnlock() else applyLock() end
    elseif inp.KeyCode == Enum.KeyCode.L then
        toggleLag()
    end
end)

-- =====================================================================
-- DRAGGABLE TITLE BAR
-- =====================================================================
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = frame.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- =====================================================================
-- CLICK LOOP
-- fixedX/fixedY are already kept up-to-date each frame by the
-- RenderStepped hook above, so this loop always reads the correct
-- pixel coords regardless of window size.
-- =====================================================================
task.spawn(function()
    while true do
        if state.clicking then
            local cx = state.useFixedPos and state.fixedX or UserInputService:GetMouseLocation().X
            local cy = state.useFixedPos and state.fixedY or UserInputService:GetMouseLocation().Y
            local ok1 = pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx,cy,0,true,game,0)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(cx,cy,0,false,game,0)
            end)
            if not ok1 then
                local ok2 = pcall(function() mouse1click() end)
                if not ok2 then
                    pcall(function()
                        local ray = workspace.CurrentCamera:ScreenPointToRay(cx,cy)
                        local res = workspace:Raycast(ray.Origin, ray.Direction*1000)
                        if res and res.Instance then
                            local cd = res.Instance:FindFirstChildOfClass("ClickDetector")
                            if cd then fireclickdetector(cd) end
                        end
                    end)
                end
            end
            if state.clicking then
                local ms = math.floor(state.delay*1000)
                statusLbl.Text = "ACTIVE · " .. ms .. "ms" ..
                    (state.useFixedPos and (" @ "..state.fixedX..","..state.fixedY) or " · live cursor")
            end
            task.wait(state.delay)
        else
            task.wait(0.05)
        end
    end
end)

print("✅ AC·Merciful v7 loaded | H=toggle | C=lock | L=lag | CTRL=hide")