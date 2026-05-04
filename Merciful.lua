-- ╔══════════════════════════════════════════════════════════════╗
-- ║  AUTO CLICKER by Merciful  v8                               ║
-- ║  H=Toggle  C=Lock  CTRL=Hide  L=Lag  B=Black               ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local player              = Players.LocalPlayer
local character           = player.Character or player.CharacterAdded:Wait()
local humanoid            = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    character = c
    humanoid  = c:WaitForChild("Humanoid")
end)

-- =====================================================================
-- GARBAGE COLLECTION
-- =====================================================================
task.spawn(function()
    while true do task.wait(30); pcall(function() collectgarbage("collect") end) end
end)

-- =====================================================================
-- LAG REDUCTION  (aggressive — textures, meshes, grass, bricks, sky)
-- =====================================================================
local lagEnabled = true

local SKY_EFFECT_TYPES = {
    "Sky","Atmosphere","BloomEffect","BlurEffect","ColorCorrectionEffect",
    "SunRaysEffect","DepthOfFieldEffect","BlackAndWhiteEffect",
    "BrightnessEffect","EqualizeEffect","ContrastEffect","SelectiveColorEffect",
}

-- Materials that look like terrain/grass — flatten them all
local HEAVY_MATERIALS = {
    [Enum.Material.Grass]         = true,
    [Enum.Material.Ground]        = true,
    [Enum.Material.LeafyGrass]    = true,
    [Enum.Material.Mud]           = true,
    [Enum.Material.Sand]          = true,
    [Enum.Material.Rock]          = true,
    [Enum.Material.Cobblestone]   = true,
    [Enum.Material.Brick]         = true,
    [Enum.Material.Marble]        = true,
    [Enum.Material.Granite]       = true,
    [Enum.Material.Pebble]        = true,
    [Enum.Material.Wood]          = true,
    [Enum.Material.WoodPlanks]    = true,
    [Enum.Material.Fabric]        = true,
    [Enum.Material.Glass]         = true,
    [Enum.Material.Foil]          = true,
    [Enum.Material.Metal]         = true,
    [Enum.Material.DiamondPlate]  = true,
    [Enum.Material.Concrete]      = true,
    [Enum.Material.Glacier]       = true,
    [Enum.Material.Ice]           = true,
    [Enum.Material.Basalt]        = true,
    [Enum.Material.CrackedLava]   = true,
    [Enum.Material.Limestone]     = true,
    [Enum.Material.Pavement]      = true,
    [Enum.Material.Salt]          = true,
    [Enum.Material.Sandstone]     = true,
    [Enum.Material.Slate]         = true,
}

local wsConn, lightChildConn, lightDescConn

local function nukeLightObj(obj)
    if obj.Name == "AC_BlackScreen_Effect" then return end
    for _, t in ipairs(SKY_EFFECT_TYPES) do
        if obj:IsA(t) then pcall(function() obj.Parent = nil end); return end
    end
end

local function sweepObj(obj)
    if not lagEnabled then return end

    -- Particles / trails
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke")
    or obj:IsA("Fire")            or obj:IsA("Sparkles") or obj:IsA("Beam") then
        pcall(function() obj:Destroy() end); return
    end

    -- Decals & surface textures → fully transparent
    if obj:IsA("Decal") or obj:IsA("Texture") then
        pcall(function() obj.Transparency = 1 end)
    end

    -- SurfaceAppearance (PBR textures, most expensive) → destroy
    if obj:IsA("SurfaceAppearance") then
        pcall(function() obj:Destroy() end); return
    end

    -- Mesh texture IDs → blank (removes texture atlas lookups)
    if obj:IsA("SpecialMesh") then
        pcall(function() obj.TextureId = "" end)
    end
    if obj:IsA("MeshPart") then
        pcall(function() obj.TextureID = "" end)
    end

    -- BaseParts → SmoothPlastic kills all material shaders
    if obj:IsA("BasePart") then
        pcall(function()
            if HEAVY_MATERIALS[obj.Material] then
                obj.Material = Enum.Material.SmoothPlastic
            end
            obj.CastShadow  = false
            obj.Reflectance = 0
            obj.RenderFidelity = Enum.RenderFidelity.Automatic
        end)
    end

    -- Terrain: replace all grass/sand/rock with smooth plastic equivalent
    if obj:IsA("Terrain") then
        pcall(function()
            obj.WaterWaveSize   = 0
            obj.WaterWaveSpeed  = 0
            obj.WaterReflectance = 0
            obj.WaterTransparency = 0
        end)
    end

    -- Post effects in workspace
    for _, t in ipairs(SKY_EFFECT_TYPES) do
        if obj:IsA(t) and obj.Name ~= "AC_BlackScreen_Effect" then
            pcall(function() obj:Destroy() end); return
        end
    end

    -- Sounds → mute
    if obj:IsA("Sound") then
        pcall(function() obj.Volume = 0 end)
    end
end

local function applyLag()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    Lighting.GlobalShadows = false
    Lighting.FogEnd        = 100000
    Lighting.FogStart      = 100000
    Lighting.Ambient       = Color3.fromRGB(180, 180, 180)
    Lighting.Brightness    = 1

    -- Nuke sky objects
    for _, obj in ipairs(Lighting:GetChildren()) do nukeLightObj(obj) end
    lightChildConn = Lighting.ChildAdded:Connect(nukeLightObj)
    lightDescConn  = Lighting.DescendantAdded:Connect(nukeLightObj)

    -- Sweep all workspace descendants
    for _, obj in ipairs(workspace:GetDescendants()) do sweepObj(obj) end
    wsConn = workspace.DescendantAdded:Connect(sweepObj)

    -- Terrain material override
    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize    = 0
            terrain.WaterWaveSpeed   = 0
            terrain.WaterReflectance = 0
        end
    end)

    task.defer(function() pcall(function() collectgarbage("collect") end) end)
    print("[AC·Merciful] Lag reduction ON")
end

local function removeLag()
    if lightChildConn then lightChildConn:Disconnect(); lightChildConn = nil end
    if lightDescConn  then lightDescConn:Disconnect();  lightDescConn  = nil end
    if wsConn         then wsConn:Disconnect();          wsConn         = nil end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    Lighting.GlobalShadows = true
    print("[AC·Merciful] Lag reduction OFF")
end

applyLag()

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
-- ANTI-AFK
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(4.7 + math.random(0,60)/100)
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
-- =====================================================================
local state = { clicking=false, delay=0.002, useFixedPos=false, fixedX=0, fixedY=0, fixedSX=0, fixedSY=0 }
local function delaytoCPS(d) return d<=0 and "∞" or tostring(math.floor(1/d)) end

RunService.RenderStepped:Connect(function()
    if not state.useFixedPos then return end
    local vp = workspace.CurrentCamera.ViewportSize
    state.fixedX = math.floor(state.fixedSX * vp.X)
    state.fixedY = math.floor(state.fixedSY * vp.Y)
end)

-- =====================================================================
-- BLACK SCREEN
-- =====================================================================
local blackEnabled = false
local blackEffect  = Instance.new("ColorCorrectionEffect")
blackEffect.Name       = "AC_BlackScreen_Effect"
blackEffect.Brightness = -1
blackEffect.Saturation = -1
blackEffect.Enabled    = false
blackEffect.Parent     = Lighting

local function setBlack(on)
    blackEnabled        = on
    blackEffect.Enabled = on
end

-- =====================================================================
-- SOUND MUTE
-- =====================================================================
local soundMuted = false
local function setSoundMute(on)
    soundMuted = on
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Sound") then
            pcall(function() obj.Volume = on and 0 or 1 end)
        end
    end
end

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
for _, n in ipairs({"AC_M_v8","AC_M_Marker_v8"}) do
    local o = guiParent:FindFirstChild(n)
    if o then o:Destroy() end
end

-- =====================================================================
-- PALETTE
-- =====================================================================
local C = {
    bg      = Color3.fromRGB(5,  8,  18),
    panel   = Color3.fromRGB(9,  14, 26),
    card    = Color3.fromRGB(12, 18, 32),
    input   = Color3.fromRGB(5,  9,  20),
    cyan    = Color3.fromRGB(0,  220, 210),
    cyanDim = Color3.fromRGB(0,  100, 120),
    cyanDk  = Color3.fromRGB(0,  35,  55),
    mag     = Color3.fromRGB(220, 50, 190),
    white   = Color3.fromRGB(215, 235, 255),
    sub     = Color3.fromRGB(70, 105, 145),
    green   = Color3.fromRGB(35, 210, 100),
    red     = Color3.fromRGB(210, 40,  70),
    orange  = Color3.fromRGB(240,140,  30),
    marker  = Color3.fromRGB(0,  230, 180),
    tabOn   = Color3.fromRGB(0,  160, 180),
    tabOff  = Color3.fromRGB(9,  14,  26),
}

-- =====================================================================
-- ROOT GUI   — fixed compact height, right side
-- =====================================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "AC_M_v8"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 9999
gui.Parent         = guiParent

local W, H = 340, 480   -- compact! fits any screen

local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, W, 0, H)
frame.AnchorPoint      = Vector2.new(1, 0.5)
frame.Position         = UDim2.new(1, -14, 0.5, 0)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel  = 0
frame.Active           = true
frame.ClipsDescendants = true
frame.Parent           = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

-- Animated outer glow
local outerStroke = Instance.new("UIStroke", frame)
outerStroke.Color     = C.cyan
outerStroke.Thickness = 1.6
task.spawn(function()
    local t = 0
    while true do
        RunService.RenderStepped:Wait()
        t = t + 0.018
        outerStroke.Transparency = 0.2 + (math.sin(t)+1)/2 * 0.45
    end
end)

-- Scanlines
do
    local sc = Instance.new("Frame")
    sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1
    sc.ClipsDescendants = true; sc.ZIndex = 1; sc.Parent = frame
    for i = 0, 50 do
        local sl = Instance.new("Frame")
        sl.Size = UDim2.new(1,0,0,1); sl.Position = UDim2.new(0,0,0,i*9)
        sl.BackgroundColor3 = C.cyanDk; sl.BackgroundTransparency = 0.78
        sl.BorderSizePixel = 0; sl.ZIndex = 1; sl.Parent = sc
    end
end

-- =====================================================================
-- TITLE BAR  (compact, 62px)
-- =====================================================================
local TB_H = 62
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1,0,0,TB_H)
titleBar.BackgroundColor3 = C.panel
titleBar.BorderSizePixel  = 0; titleBar.ZIndex = 4; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,14)

-- fix bottom corners
local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1,0,0.5,0); tbFix.Position = UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3 = C.panel; tbFix.BorderSizePixel = 0; tbFix.ZIndex = 4; tbFix.Parent = titleBar

-- bottom accent line
local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1,0,0,2); titleLine.Position = UDim2.new(0,0,1,-2)
titleLine.BackgroundColor3 = C.cyan; titleLine.BorderSizePixel = 0; titleLine.ZIndex = 5; titleLine.Parent = titleBar

-- sliding magenta accent bar
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0,60,0,2); accentBar.Position = UDim2.new(0,0,1,-4)
accentBar.BackgroundColor3 = C.mag; accentBar.BorderSizePixel = 0; accentBar.ZIndex = 6; accentBar.Parent = titleBar
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0,2)
task.spawn(function()
    local dir=1; local pos=0
    while true do
        RunService.RenderStepped:Wait()
        pos = pos + dir*1.6
        if pos >= W-60 then dir=-1 end
        if pos <= 0     then dir= 1 end
        accentBar.Position = UDim2.new(0, pos, 1, -4)
    end
end)

-- Logo
local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0,44,0,44); logoBox.Position = UDim2.new(0,10,0,9)
logoBox.BackgroundColor3 = C.cyanDk; logoBox.BorderSizePixel = 0; logoBox.ZIndex = 6; logoBox.Parent = titleBar
Instance.new("UICorner", logoBox).CornerRadius = UDim.new(0,10)
local logoStroke = Instance.new("UIStroke", logoBox); logoStroke.Color = C.cyan; logoStroke.Thickness = 1.6
task.spawn(function()
    local t=0
    while true do
        RunService.RenderStepped:Wait(); t=t+0.04
        logoStroke.Transparency = 0.1+(math.sin(t)+1)/2*0.65
    end
end)
local lHex = Instance.new("TextLabel")
lHex.Size = UDim2.new(1,0,1,0); lHex.BackgroundTransparency=1; lHex.Text="⬡"
lHex.TextColor3=C.cyan; lHex.TextScaled=true; lHex.ZIndex=7; lHex.Parent=logoBox
local lStar = Instance.new("TextLabel")
lStar.Size=UDim2.new(0.5,0,0.5,0); lStar.Position=UDim2.new(0.25,0,0.25,0)
lStar.BackgroundTransparency=1; lStar.Text="✦"; lStar.TextColor3=C.mag
lStar.TextScaled=true; lStar.ZIndex=8; lStar.Parent=logoBox

-- Title text
local titleTxt = Instance.new("TextLabel")
titleTxt.Size=UDim2.new(1,-64,0,24); titleTxt.Position=UDim2.new(0,60,0,8)
titleTxt.BackgroundTransparency=1; titleTxt.Text="AUTO CLICKER"
titleTxt.TextColor3=C.cyan; titleTxt.TextScaled=true; titleTxt.Font=Enum.Font.GothamBold
titleTxt.TextXAlignment=Enum.TextXAlignment.Left; titleTxt.ZIndex=6; titleTxt.Parent=titleBar

local subTxt = Instance.new("TextLabel")
subTxt.Size=UDim2.new(1,-64,0,14); subTxt.Position=UDim2.new(0,60,0,34)
subTxt.BackgroundTransparency=1; subTxt.Text="by Merciful  ·  v8  ·  CTRL=hide"
subTxt.TextColor3=C.sub; subTxt.TextScaled=true; subTxt.Font=Enum.Font.Gotham
subTxt.TextXAlignment=Enum.TextXAlignment.Left; subTxt.ZIndex=6; subTxt.Parent=titleBar

-- Decorative hex strip
local hexA={0.55,0.38,0.62,0.42}
for i=1,4 do
    local h=Instance.new("TextLabel")
    h.Size=UDim2.new(0,20,0,20); h.Position=UDim2.new(1,-(i*22)-2,0,6)
    h.BackgroundTransparency=1; h.Text="⬡"; h.TextColor3=C.cyan
    h.TextTransparency=hexA[i]; h.TextScaled=true; h.ZIndex=5; h.Parent=titleBar
end

-- =====================================================================
-- TAB BAR  (just below title — 3 tabs)
-- =====================================================================
local TABS = {"CLICK","SYSTEM","LAG"}
local TAB_Y = TB_H
local TAB_H = 32
local tabBtns = {}
local tabPages = {}
local activeTab = 1

local tabBar = Instance.new("Frame")
tabBar.Size=UDim2.new(1,0,0,TAB_H); tabBar.Position=UDim2.new(0,0,0,TAB_Y)
tabBar.BackgroundColor3=C.panel; tabBar.BorderSizePixel=0; tabBar.ZIndex=5; tabBar.Parent=frame

local tabW = W/#TABS
for i, name in ipairs(TABS) do
    local tb = Instance.new("TextButton")
    tb.Size=UDim2.new(0,tabW,1,0); tb.Position=UDim2.new(0,(i-1)*tabW,0,0)
    tb.BackgroundColor3=i==1 and C.tabOn or C.tabOff
    tb.Text=name; tb.TextColor3=i==1 and C.white or C.sub
    tb.TextScaled=true; tb.Font=Enum.Font.GothamBold
    tb.BorderSizePixel=0; tb.AutoButtonColor=false; tb.ZIndex=6; tb.Parent=tabBar
    if i==1 then Instance.new("UICorner",tb).CornerRadius=UDim.new(0,0) end

    -- tab underline indicator
    local tline=Instance.new("Frame")
    tline.Size=UDim2.new(1,0,0,2); tline.Position=UDim2.new(0,0,1,-2)
    tline.BackgroundColor3=i==1 and C.cyan or C.cyanDk
    tline.BorderSizePixel=0; tline.ZIndex=7; tline.Parent=tb
    tabBtns[i] = {btn=tb, line=tline}

    -- page container
    local page=Instance.new("Frame")
    page.Size=UDim2.new(1,0,1,-(TAB_Y+TAB_H+50))
    page.Position=UDim2.new(0,0,0,TAB_Y+TAB_H)
    page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.Visible=i==1; page.ZIndex=3; page.Parent=frame
    tabPages[i]=page
end

local function switchTab(idx)
    for i, data in ipairs(tabBtns) do
        local on = i==idx
        data.btn.BackgroundColor3 = on and C.tabOn or C.tabOff
        data.btn.TextColor3       = on and C.white or C.sub
        data.line.BackgroundColor3 = on and C.cyan or C.cyanDk
        tabPages[i].Visible       = on
    end
    activeTab = idx
end
for i=1,#TABS do
    local ci=i
    tabBtns[i].btn.MouseButton1Click:Connect(function() switchTab(ci) end)
end

-- =====================================================================
-- HELPERS (scoped to pages)
-- =====================================================================
local function mkCard(parent, y, h)
    local p=Instance.new("Frame")
    p.Size=UDim2.new(1,-20,0,h); p.Position=UDim2.new(0,10,0,y)
    p.BackgroundColor3=C.card; p.BorderSizePixel=0; p.ZIndex=4; p.Parent=parent
    Instance.new("UICorner",p).CornerRadius=UDim.new(0,8)
    local s=Instance.new("UIStroke",p); s.Color=C.cyanDim; s.Thickness=1
    return p
end

local function mkLabel(par,x,y,w,h,txt,col,font,align)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(0,w,0,h); l.Position=UDim2.new(0,x,0,y)
    l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=col or C.white
    l.TextScaled=true; l.Font=font or Enum.Font.Gotham
    l.TextXAlignment=align or Enum.TextXAlignment.Left
    l.BorderSizePixel=0; l.ZIndex=5; l.Parent=par
    return l
end

local function mkBtn(par,txt,x,y,w,h,col,z)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,w,0,h); b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=col; b.Text=txt; b.TextColor3=C.white
    b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    b.AutoButtonColor=true; b.ZIndex=z or 5; b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    local s=Instance.new("UIStroke",b)
    s.Color=Color3.fromRGB(math.min(col.R*255+60,255),math.min(col.G*255+60,255),math.min(col.B*255+60,255))
    s.Thickness=1
    return b
end

local function mkInput(par,x,y,w,h,def,ph)
    local b=Instance.new("TextBox")
    b.Size=UDim2.new(0,w,0,h); b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=C.input; b.Text=def; b.TextColor3=C.white
    b.PlaceholderText=ph or ""; b.PlaceholderColor3=C.sub
    b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    b.ClearTextOnFocus=false; b.ZIndex=5; b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",b).Color=C.cyanDim
    return b
end

local function mkGlowDot(par,x,y,col)
    local outer=Instance.new("Frame")
    outer.Size=UDim2.new(0,14,0,14); outer.Position=UDim2.new(0,x,0,y)
    outer.BackgroundTransparency=1; outer.BorderSizePixel=0; outer.ZIndex=6; outer.Parent=par
    Instance.new("UICorner",outer).CornerRadius=UDim.new(0.5,0)
    local stroke=Instance.new("UIStroke",outer); stroke.Color=col; stroke.Thickness=2
    local inner=Instance.new("Frame")
    inner.AnchorPoint=Vector2.new(0.5,0.5); inner.Size=UDim2.new(0,5,0,5)
    inner.Position=UDim2.new(0.5,0,0.5,0); inner.BackgroundColor3=col
    inner.BorderSizePixel=0; inner.ZIndex=7; inner.Parent=outer
    Instance.new("UICorner",inner).CornerRadius=UDim.new(0.5,0)
    task.spawn(function()
        local t=math.random(0,62)/10
        while true do
            RunService.RenderStepped:Wait(); t=t+0.05
            stroke.Transparency=0.15+(math.sin(t)+1)/2*0.6
        end
    end)
    return inner, stroke
end

-- Small toggle pill button
local function mkTogglePill(par,x,y,w,h,labelOn,labelOff,isOn,col,fn)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,w,0,h); b.Position=UDim2.new(0,x,0,y)
    b.BackgroundColor3=isOn and col or C.cyanDk
    b.Text=isOn and labelOn or labelOff
    b.TextColor3=isOn and C.white or C.sub
    b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    b.AutoButtonColor=false; b.ZIndex=5; b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    local s=Instance.new("UIStroke",b); s.Color=col; s.Thickness=1

    local state_={on=isOn}
    b.MouseButton1Click:Connect(function()
        state_.on=not state_.on
        b.BackgroundColor3=state_.on and col or C.cyanDk
        b.Text=state_.on and labelOn or labelOff
        b.TextColor3=state_.on and C.white or C.sub
        if fn then fn(state_.on) end
    end)
    return b, state_
end

-- =====================================================================
-- ══════════════ TAB 1: CLICK ═════════════════════════════════════════
-- =====================================================================
local pg1 = tabPages[1]

-- ── CPS display + slider ─────────────────────────────────────────────
local cpsCard = mkCard(pg1, 8, 90)

local cpsDispBg=Instance.new("Frame")
cpsDispBg.Size=UDim2.new(0,80,0,46); cpsDispBg.Position=UDim2.new(0,8,0,8)
cpsDispBg.BackgroundColor3=C.input; cpsDispBg.BorderSizePixel=0; cpsDispBg.ZIndex=5; cpsDispBg.Parent=cpsCard
Instance.new("UICorner",cpsDispBg).CornerRadius=UDim.new(0,8)
local cpsDispStroke=Instance.new("UIStroke",cpsDispBg); cpsDispStroke.Color=C.cyan; cpsDispStroke.Thickness=1.5
task.spawn(function() local t=0 while true do RunService.RenderStepped:Wait(); t=t+0.035
    cpsDispStroke.Transparency=0.1+(math.sin(t)+1)/2*0.5 end end)

local cpsNum=Instance.new("TextLabel")
cpsNum.Size=UDim2.new(1,0,0.58,0); cpsNum.Position=UDim2.new(0,0,0.04,0)
cpsNum.BackgroundTransparency=1; cpsNum.TextColor3=C.cyan; cpsNum.TextScaled=true
cpsNum.Font=Enum.Font.GothamBold; cpsNum.ZIndex=6; cpsNum.Parent=cpsDispBg

local cpsUnit=Instance.new("TextLabel")
cpsUnit.Size=UDim2.new(1,0,0.35,0); cpsUnit.Position=UDim2.new(0,0,0.63,0)
cpsUnit.BackgroundTransparency=1; cpsUnit.Text="CPS"; cpsUnit.TextColor3=C.sub
cpsUnit.TextScaled=true; cpsUnit.Font=Enum.Font.Gotham; cpsUnit.ZIndex=6; cpsUnit.Parent=cpsDispBg

local function refreshCPS() cpsNum.Text=delaytoCPS(state.delay) end
refreshCPS()

-- Slider
local sliderTrack=Instance.new("Frame")
sliderTrack.Size=UDim2.new(0,144,0,7); sliderTrack.Position=UDim2.new(0,98,0,28)
sliderTrack.BackgroundColor3=C.input; sliderTrack.BorderSizePixel=0; sliderTrack.ZIndex=5; sliderTrack.Parent=cpsCard
Instance.new("UICorner",sliderTrack).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",sliderTrack).Color=C.cyanDk

local sFill=Instance.new("Frame"); sFill.Size=UDim2.new(0.09,0,1,0)
sFill.BackgroundColor3=C.cyan; sFill.BorderSizePixel=0; sFill.ZIndex=6; sFill.Parent=sliderTrack
Instance.new("UICorner",sFill).CornerRadius=UDim.new(0,4)

local sKnob=Instance.new("TextButton")
sKnob.Size=UDim2.new(0,18,0,18); sKnob.Position=UDim2.new(0.09,-9,0.5,-9)
sKnob.BackgroundColor3=C.cyan; sKnob.Text=""; sKnob.BorderSizePixel=0; sKnob.ZIndex=7; sKnob.Parent=sliderTrack
Instance.new("UICorner",sKnob).CornerRadius=UDim.new(0.5,0)
Instance.new("UIStroke",sKnob).Color=C.white

local function applySliderPct(pct)
    pct=math.clamp(pct,0,1)
    local cps=math.clamp(math.round(1+pct*499),1,500)
    state.delay=1/cps
    sFill.Size=UDim2.new(pct,0,1,0)
    sKnob.Position=UDim2.new(pct,-9,0.5,-9)
    refreshCPS()
end

-- +/- buttons
mkBtn(cpsCard,"−",248,14,26,38,C.cyanDim,5).MouseButton1Click:Connect(function()
    local cps=math.max(1,math.floor(1/state.delay)-10); state.delay=1/cps; applySliderPct((cps-1)/499)
end)
mkBtn(cpsCard,"+",278,14,26,38,C.cyanDim,5).MouseButton1Click:Connect(function()
    local cps=math.min(500,math.floor(1/state.delay)+10); state.delay=1/cps; applySliderPct((cps-1)/499)
end)

local sliderDrag=false
sKnob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliderDrag=true end end)
sliderTrack.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        sliderDrag=true; applySliderPct((i.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X) end end)
UserInputService.InputChanged:Connect(function(i)
    if sliderDrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        applySliderPct((i.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X) end end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliderDrag=false end end)

-- Custom delay row inside cpsCard
local delayBox=mkInput(cpsCard,98,58,100,22,"0.002","delay s")
mkLabel(cpsCard,8,60,88,20,"Delay (s):",C.sub)
mkBtn(cpsCard,"SET",202,58,50,22,C.cyanDim,5).MouseButton1Click:Connect(function()
    local v=tonumber(delayBox.Text)
    if v and v>0 then
        state.delay=math.max(0.001,v); delayBox.Text=tostring(state.delay)
        local cps=math.clamp(math.round(1/state.delay),1,500); applySliderPct((cps-1)/499)
    else delayBox.Text=tostring(state.delay) end
end)

-- ── Position Lock ─────────────────────────────────────────────────────
local posCard=mkCard(pg1,106,80)

local lockDot,lockDotStroke=mkGlowDot(posCard,8,10,C.sub)

local lockInfo=mkLabel(posCard,28,8,270,20,"OFF — live cursor",C.sub)
mkLabel(posCard,8,30,300,16,"Hover target → press C or click LOCK",C.sub)

local lockBtn=mkBtn(posCard,"◈ LOCK  [C]",8,52,148,22,C.cyanDim,5)
local unlockBtn=mkBtn(posCard,"◎ UNLOCK",160,52,140,22,C.red,5)
unlockBtn.Visible=false

local function applyLock()
    local vp=workspace.CurrentCamera.ViewportSize
    local mp=UserInputService:GetMouseLocation()
    state.fixedSX=mp.X/vp.X; state.fixedSY=mp.Y/vp.Y
    state.fixedX=math.floor(mp.X); state.fixedY=math.floor(mp.Y)
    state.useFixedPos=true
    lockInfo.Text=string.format("LOCKED  X:%-4d Y:%d",state.fixedX,state.fixedY)
    lockInfo.TextColor3=C.cyan
    lockDot.BackgroundColor3=C.cyan; lockDotStroke.Color=C.cyan
    lockBtn.Visible=false; unlockBtn.Visible=true
end
local function applyUnlock()
    state.useFixedPos=false
    lockInfo.Text="OFF — live cursor"; lockInfo.TextColor3=C.sub
    lockDot.BackgroundColor3=C.sub; lockDotStroke.Color=C.sub
    lockBtn.Visible=true; unlockBtn.Visible=false
end
lockBtn.MouseButton1Click:Connect(applyLock)
unlockBtn.MouseButton1Click:Connect(applyUnlock)

-- ── Status + big START button ─────────────────────────────────────────
local statCard=mkCard(pg1,194,30)
local statusDot=mkGlowDot(statCard,8,8,C.sub)
local statusLbl=mkLabel(statCard,28,5,270,20,"IDLE · Press H",C.sub)

local startBtn=mkBtn(pg1,"▶  START  [H]",10,232,W-40,38,C.green,5)
-- shimmer sweep
local shimmer=Instance.new("Frame")
shimmer.Size=UDim2.new(0,36,1,0); shimmer.Position=UDim2.new(0,-36,0,0)
shimmer.BackgroundColor3=Color3.fromRGB(255,255,255); shimmer.BackgroundTransparency=0.82
shimmer.BorderSizePixel=0; shimmer.ZIndex=6; shimmer.Parent=startBtn
Instance.new("UICorner",shimmer).CornerRadius=UDim.new(0,7)
task.spawn(function()
    while true do task.wait(3)
        for i=-36,W+36,5 do shimmer.Position=UDim2.new(0,i,0,0); task.wait(0.01) end
    end
end)

local function setActive(on)
    state.clicking=on
    if on then
        startBtn.BackgroundColor3=C.red; startBtn.Text="⏹  STOP  [H]"
        local ms=math.floor(state.delay*1000)
        statusLbl.Text="ACTIVE · "..ms.."ms"..(state.useFixedPos and (" @"..state.fixedX..","..state.fixedY) or " · cursor")
        statusLbl.TextColor3=C.green; statusDot.BackgroundColor3=C.green
    else
        startBtn.BackgroundColor3=C.green; startBtn.Text="▶  START  [H]"
        statusLbl.Text="IDLE · Press H"; statusLbl.TextColor3=C.sub; statusDot.BackgroundColor3=C.sub
    end
end
startBtn.MouseButton1Click:Connect(function() setActive(not state.clicking) end)

-- =====================================================================
-- ══════════════ TAB 2: SYSTEM ════════════════════════════════════════
-- =====================================================================
local pg2=tabPages[2]

local function mkBadge(par,x,y,w,h,txt,col,fn)
    local bg=Instance.new(fn and "TextButton" or "Frame")
    bg.Size=UDim2.new(0,w,0,h); bg.Position=UDim2.new(0,x,0,y)
    bg.BackgroundColor3=C.card; bg.BorderSizePixel=0; bg.ZIndex=5; bg.Parent=par
    if fn then bg.AutoButtonColor=false; bg.Text="" end
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    local stroke=Instance.new("UIStroke",bg); stroke.Color=col; stroke.Thickness=1.4
    -- top colour bar
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,0,0,3); bar.BackgroundColor3=col
    bar.BorderSizePixel=0; bar.ZIndex=6; bar.Parent=bg
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,8)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,-6); lbl.Position=UDim2.new(0,0,0,5)
    lbl.BackgroundTransparency=1; lbl.Text=txt; lbl.TextColor3=col
    lbl.TextScaled=true; lbl.Font=Enum.Font.GothamBold; lbl.ZIndex=6; lbl.Parent=bg
    if fn then bg.MouseButton1Click:Connect(fn) end
    return lbl, stroke
end

-- Row 1: Jump / FPS / Sound / Black
local bW,bH,bGap = 72,58,8
local function bx(i) return 10+(i-1)*(bW+bGap) end

mkBadge(pg2,bx(1),8,bW,bH,"↑ JUMP\nON",C.green)

local fpsBadgeLbl,fpsBadgeStroke
local function refreshFpsBtn()
    if fpsLocked then
        fpsBadgeLbl.Text=string.format("🔒FPS\n%d",fpsTarget); fpsBadgeLbl.TextColor3=C.cyan; fpsBadgeStroke.Color=C.cyan
    else
        fpsBadgeLbl.Text="🔓FPS\nFREE"; fpsBadgeLbl.TextColor3=C.sub; fpsBadgeStroke.Color=C.sub
    end
end
fpsBadgeLbl,fpsBadgeStroke=mkBadge(pg2,bx(2),8,bW,bH,"",C.cyan,function()
    fpsLocked=not fpsLocked; lastFrame=tick(); refreshFpsBtn()
end); refreshFpsBtn()

local sfxLbl,sfxStroke
local function refreshSfx()
    if soundMuted then sfxLbl.Text="🔇SFX\nOFF"; sfxLbl.TextColor3=C.orange; sfxStroke.Color=C.orange
    else sfxLbl.Text="🔊SFX\nON"; sfxLbl.TextColor3=C.sub; sfxStroke.Color=C.sub end
end
sfxLbl,sfxStroke=mkBadge(pg2,bx(3),8,bW,bH,"",C.sub,function()
    setSoundMute(not soundMuted); refreshSfx()
end); refreshSfx()

local blkLbl,blkStroke
local function refreshBlk()
    if blackEnabled then blkLbl.Text="⬛SCR\nON"; blkLbl.TextColor3=C.green; blkStroke.Color=C.green
    else blkLbl.Text="⬛SCR\nOFF"; blkLbl.TextColor3=C.sub; blkStroke.Color=C.sub end
end
blkLbl,blkStroke=mkBadge(pg2,bx(4),8,bW,bH,"",C.sub,function()
    setBlack(not blackEnabled); refreshBlk()
end); refreshBlk()

-- FPS CAP row
local fpsCapCard=mkCard(pg2,74,106)
mkLabel(fpsCapCard,8,6,80,16,"FPS CAP",C.cyan,Enum.Font.GothamBold)

-- Preset buttons
local presets={10,20,30,60,120,240}
local pW=math.floor((W-40)/#presets)
for i,fps in ipairs(presets) do
    local pb=mkBtn(fpsCapCard,tostring(fps),8+(i-1)*pW,24,pW-3,22,C.cyanDk,5)
    pb.MouseButton1Click:Connect(function()
        setFpsTarget(fps); fpsLocked=true; lastFrame=tick()
        refreshFpsBtn()
        local pct=(fpsTarget-1)/239
        fFill2.Size=UDim2.new(pct,0,1,0); fKnob2.Position=UDim2.new(pct,-9,0.5,-9)
        fpsNum2.Text=tostring(fpsTarget); fpsIn2.Text=tostring(fpsTarget)
    end)
end

-- FPS slider
local fpsDispBg2=Instance.new("Frame")
fpsDispBg2.Size=UDim2.new(0,56,0,34); fpsDispBg2.Position=UDim2.new(0,8,0,52)
fpsDispBg2.BackgroundColor3=C.input; fpsDispBg2.BorderSizePixel=0; fpsDispBg2.ZIndex=5; fpsDispBg2.Parent=fpsCapCard
Instance.new("UICorner",fpsDispBg2).CornerRadius=UDim.new(0,7)
local fBStroke2=Instance.new("UIStroke",fpsDispBg2); fBStroke2.Color=C.cyan; fBStroke2.Thickness=1.5
task.spawn(function() local t=0 while true do RunService.RenderStepped:Wait(); t=t+0.035
    fBStroke2.Transparency=0.1+(math.sin(t)+1)/2*0.5 end end)

local fpsNum2=Instance.new("TextLabel")
fpsNum2.Size=UDim2.new(1,0,0.6,0); fpsNum2.Position=UDim2.new(0,0,0.04,0)
fpsNum2.BackgroundTransparency=1; fpsNum2.Text=tostring(fpsTarget); fpsNum2.TextColor3=C.cyan
fpsNum2.TextScaled=true; fpsNum2.Font=Enum.Font.GothamBold; fpsNum2.ZIndex=6; fpsNum2.Parent=fpsDispBg2

local fpsUnit2=Instance.new("TextLabel")
fpsUnit2.Size=UDim2.new(1,0,0.35,0); fpsUnit2.Position=UDim2.new(0,0,0.63,0)
fpsUnit2.BackgroundTransparency=1; fpsUnit2.Text="FPS"; fpsUnit2.TextColor3=C.sub
fpsUnit2.TextScaled=true; fpsUnit2.Font=Enum.Font.Gotham; fpsUnit2.ZIndex=6; fpsUnit2.Parent=fpsDispBg2

local fTrack2=Instance.new("Frame")
fTrack2.Size=UDim2.new(0,158,0,7); fTrack2.Position=UDim2.new(0,72,0,64)
fTrack2.BackgroundColor3=C.input; fTrack2.BorderSizePixel=0; fTrack2.ZIndex=5; fTrack2.Parent=fpsCapCard
Instance.new("UICorner",fTrack2).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",fTrack2).Color=C.cyanDk

local fFill2=Instance.new("Frame"); fFill2.Size=UDim2.new((fpsTarget-1)/239,0,1,0)
fFill2.BackgroundColor3=C.cyan; fFill2.BorderSizePixel=0; fFill2.ZIndex=6; fFill2.Parent=fTrack2
Instance.new("UICorner",fFill2).CornerRadius=UDim.new(0,4)

local fKnob2=Instance.new("TextButton")
fKnob2.Size=UDim2.new(0,18,0,18); fKnob2.Position=UDim2.new((fpsTarget-1)/239,-9,0.5,-9)
fKnob2.BackgroundColor3=C.cyan; fKnob2.Text=""; fKnob2.BorderSizePixel=0; fKnob2.ZIndex=7; fKnob2.Parent=fTrack2
Instance.new("UICorner",fKnob2).CornerRadius=UDim.new(0.5,0)
Instance.new("UIStroke",fKnob2).Color=C.white

local fpsIn2=mkInput(fpsCapCard,72,82,60,18,tostring(fpsTarget),"FPS")
mkBtn(fpsCapCard,"SET",136,82,46,18,C.cyanDim,5).MouseButton1Click:Connect(function()
    local v=tonumber(fpsIn2.Text)
    if v and v>=1 and v<=240 then
        local pct=(math.floor(v)-1)/239
        setFpsTarget(math.floor(v)); fpsLocked=true; lastFrame=tick()
        fFill2.Size=UDim2.new(pct,0,1,0); fKnob2.Position=UDim2.new(pct,-9,0.5,-9)
        fpsNum2.Text=tostring(fpsTarget); refreshFpsBtn()
    else fpsIn2.Text=tostring(fpsTarget) end
end)

mkBtn(fpsCapCard,"−",234,52,22,36,C.cyanDk,5).MouseButton1Click:Connect(function()
    local pct=(math.max(1,fpsTarget-1)-1)/239
    setFpsTarget(math.max(1,fpsTarget-1)); fpsLocked=true; lastFrame=tick()
    fFill2.Size=UDim2.new(pct,0,1,0); fKnob2.Position=UDim2.new(pct,-9,0.5,-9)
    fpsNum2.Text=tostring(fpsTarget); fpsIn2.Text=tostring(fpsTarget); refreshFpsBtn()
end)
mkBtn(fpsCapCard,"+",260,52,22,36,C.cyan,5).MouseButton1Click:Connect(function()
    local pct=(math.min(240,fpsTarget+1)-1)/239
    setFpsTarget(math.min(240,fpsTarget+1)); fpsLocked=true; lastFrame=tick()
    fFill2.Size=UDim2.new(pct,0,1,0); fKnob2.Position=UDim2.new(pct,-9,0.5,-9)
    fpsNum2.Text=tostring(fpsTarget); fpsIn2.Text=tostring(fpsTarget); refreshFpsBtn()
end)

local fDrag2=false
fKnob2.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then fDrag2=true end end)
fTrack2.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        fDrag2=true; local pct2=math.clamp((i.Position.X-fTrack2.AbsolutePosition.X)/fTrack2.AbsoluteSize.X,0,1)
        local fps2=math.clamp(math.round(1+pct2*239),1,240); setFpsTarget(fps2); fpsLocked=true; lastFrame=tick()
        fFill2.Size=UDim2.new(pct2,0,1,0); fKnob2.Position=UDim2.new(pct2,-9,0.5,-9)
        fpsNum2.Text=tostring(fpsTarget); fpsIn2.Text=tostring(fpsTarget); refreshFpsBtn() end end)
UserInputService.InputChanged:Connect(function(i)
    if fDrag2 and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local pct2=math.clamp((i.Position.X-fTrack2.AbsolutePosition.X)/fTrack2.AbsoluteSize.X,0,1)
        local fps2=math.clamp(math.round(1+pct2*239),1,240); setFpsTarget(fps2); fpsLocked=true; lastFrame=tick()
        fFill2.Size=UDim2.new(pct2,0,1,0); fKnob2.Position=UDim2.new(pct2,-9,0.5,-9)
        fpsNum2.Text=tostring(fpsTarget); fpsIn2.Text=tostring(fpsTarget); refreshFpsBtn() end end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then fDrag2=false end end)

-- =====================================================================
-- ══════════════ TAB 3: LAG ═══════════════════════════════════════════
-- =====================================================================
local pg3=tabPages[3]

-- Master toggle
local lagToggle=mkBtn(pg3,"⚡ LAG REDUCTION: ON  [L]",10,8,W-40,34,C.green,5)
local function refreshLagBtn()
    lagToggle.BackgroundColor3=lagEnabled and C.green or C.red
    lagToggle.Text="⚡ LAG REDUCTION: "..(lagEnabled and "ON" or "OFF").."  [L]"
end
local function toggleLag()
    lagEnabled=not lagEnabled
    if lagEnabled then applyLag() else removeLag() end
    refreshLagBtn()
end
lagToggle.MouseButton1Click:Connect(toggleLag)

-- Sub-toggles grid (2 columns)
local opts={
    {k="Textures",  l="Textures & Meshes"},
    {k="Particles", l="Particles & FX"},
    {k="Parts",     l="Material Flatten"},
    {k="Sound",     l="Mute Sounds"},
    {k="Sky",       l="Sky & Atmosphere"},
    {k="LOD",       l="LOD Scripts"},
}
local LagSettings={Textures=true,Particles=true,Parts=true,Sound=true,Sky=true,LOD=true}

local colW=math.floor((W-30)/2)
for i,opt in ipairs(opts) do
    local col_=((i-1)%2); local row_=math.floor((i-1)/2)
    local bx_=10+col_*(colW+5); local by_=50+row_*38
    local on=LagSettings[opt.k]
    local cb=Instance.new("TextButton")
    cb.Size=UDim2.new(0,colW,0,32); cb.Position=UDim2.new(0,bx_,0,by_)
    cb.BackgroundColor3=C.card; cb.Text=""; cb.BorderSizePixel=0
    cb.AutoButtonColor=false; cb.ZIndex=5; cb.Parent=pg3
    Instance.new("UICorner",cb).CornerRadius=UDim.new(0,7)
    local cbS=Instance.new("UIStroke",cb); cbS.Color=on and C.cyanDim or C.cyanDk; cbS.Thickness=1.2

    local cbIcon=Instance.new("TextLabel")
    cbIcon.Size=UDim2.new(0,28,1,0); cbIcon.Position=UDim2.new(0,4,0,0)
    cbIcon.BackgroundTransparency=1; cbIcon.Text=on and "✔" or "✘"
    cbIcon.TextColor3=on and C.cyan or C.sub; cbIcon.TextScaled=true
    cbIcon.Font=Enum.Font.GothamBold; cbIcon.ZIndex=6; cbIcon.Parent=cb

    local cbLbl=Instance.new("TextLabel")
    cbLbl.Size=UDim2.new(1,-34,1,0); cbLbl.Position=UDim2.new(0,32,0,0)
    cbLbl.BackgroundTransparency=1; cbLbl.Text=opt.l; cbLbl.TextColor3=on and C.white or C.sub
    cbLbl.TextScaled=true; cbLbl.Font=Enum.Font.Gotham
    cbLbl.TextXAlignment=Enum.TextXAlignment.Left; cbLbl.ZIndex=6; cbLbl.Parent=cb

    cb.MouseButton1Click:Connect(function()
        LagSettings[opt.k]=not LagSettings[opt.k]
        local n=LagSettings[opt.k]
        cbS.Color=n and C.cyanDim or C.cyanDk
        cbIcon.Text=n and "✔" or "✘"; cbIcon.TextColor3=n and C.cyan or C.sub
        cbLbl.TextColor3=n and C.white or C.sub
    end)
end

-- Info strip
local infoLbl=mkLabel(pg3,10,168,W-30,16,"GC every 30s · Sky permanently removed · Textures/mesh/grass/bricks stripped",C.sub)
infoLbl.TextWrapped=true; infoLbl.TextScaled=false; infoLbl.TextSize=10

-- =====================================================================
-- LOCK MARKER OVERLAY
-- =====================================================================
local markerGui=Instance.new("ScreenGui")
markerGui.Name="AC_M_Marker_v8"; markerGui.ResetOnSpawn=false
markerGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; markerGui.IgnoreGuiInset=true
markerGui.DisplayOrder=5000; markerGui.Parent=guiParent

local ring=Instance.new("Frame"); ring.AnchorPoint=Vector2.new(0.5,0.5)
ring.Size=UDim2.new(0,34,0,34); ring.BackgroundTransparency=1; ring.BorderSizePixel=0
ring.Visible=false; ring.ZIndex=20; ring.Parent=markerGui
Instance.new("UICorner",ring).CornerRadius=UDim.new(0.5,0)
Instance.new("UIStroke",ring).Color=C.marker

local mDot=Instance.new("Frame"); mDot.AnchorPoint=Vector2.new(0.5,0.5)
mDot.Size=UDim2.new(0,7,0,7); mDot.BackgroundColor3=C.marker; mDot.BorderSizePixel=0
mDot.Visible=false; mDot.ZIndex=21; mDot.Parent=markerGui
Instance.new("UICorner",mDot).CornerRadius=UDim.new(0.5,0)

local lH2=Instance.new("Frame"); lH2.AnchorPoint=Vector2.new(0.5,0.5)
lH2.Size=UDim2.new(0,26,0,1); lH2.BackgroundColor3=C.marker
lH2.BorderSizePixel=0; lH2.Visible=false; lH2.ZIndex=21; lH2.Parent=markerGui

local lV2=Instance.new("Frame"); lV2.AnchorPoint=Vector2.new(0.5,0.5)
lV2.Size=UDim2.new(0,1,0,26); lV2.BackgroundColor3=C.marker
lV2.BorderSizePixel=0; lV2.Visible=false; lV2.ZIndex=21; lV2.Parent=markerGui

RunService.RenderStepped:Connect(function()
    if not state.useFixedPos then return end
    local p=UDim2.new(state.fixedSX,0,state.fixedSY,0)
    ring.Position=p; mDot.Position=p; lH2.Position=p; lV2.Position=p
    ring.Visible=true; mDot.Visible=true; lH2.Visible=true; lV2.Visible=true
end)

-- =====================================================================
-- KEYBOARD BINDS
-- =====================================================================
UserInputService.InputBegan:Connect(function(inp,gpe)
    if inp.KeyCode==Enum.KeyCode.LeftControl then
        gui.Enabled=not gui.Enabled; return
    end
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.H then setActive(not state.clicking)
    elseif inp.KeyCode==Enum.KeyCode.C then
        if state.useFixedPos then applyUnlock() else applyLock() end
    elseif inp.KeyCode==Enum.KeyCode.L then toggleLag()
    elseif inp.KeyCode==Enum.KeyCode.B then setBlack(not blackEnabled); refreshBlk()
    end
end)

-- =====================================================================
-- DRAGGABLE TITLE BAR
-- =====================================================================
local dragging,dragStart,dragSP=false,nil,nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=inp.Position; dragSP=frame.Position
        inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
        local d=inp.Position-dragStart
        frame.Position=UDim2.new(dragSP.X.Scale,dragSP.X.Offset+d.X,dragSP.Y.Scale,dragSP.Y.Offset+d.Y)
    end
end)

-- =====================================================================
-- CLICK LOOP
-- =====================================================================
task.spawn(function()
    while true do
        if state.clicking then
            local cx=state.useFixedPos and state.fixedX or UserInputService:GetMouseLocation().X
            local cy=state.useFixedPos and state.fixedY or UserInputService:GetMouseLocation().Y
            local ok1=pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx,cy,0,true,game,0)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(cx,cy,0,false,game,0)
            end)
            if not ok1 then
                local ok2=pcall(function() mouse1click() end)
                if not ok2 then
                    pcall(function()
                        local ray=workspace.CurrentCamera:ScreenPointToRay(cx,cy)
                        local res=workspace:Raycast(ray.Origin,ray.Direction*1000)
                        if res and res.Instance then
                            local cd=res.Instance:FindFirstChildOfClass("ClickDetector")
                            if cd then fireclickdetector(cd) end
                        end
                    end)
                end
            end
            if state.clicking then
                local ms=math.floor(state.delay*1000)
                statusLbl.Text="ACTIVE · "..ms.."ms"..(state.useFixedPos and (" @"..state.fixedX..","..state.fixedY) or " · cursor")
            end
            task.wait(state.delay)
        else task.wait(0.05) end
    end
end)

print("✅ Auto Clicker by Merciful v8 | 3-tab compact UI | Sky+textures+grass+bricks stripped | H/C/L/B/CTRL")
