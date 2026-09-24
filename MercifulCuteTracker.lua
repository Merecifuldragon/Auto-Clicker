--[[
    BLOX FRUITS — DUAL MODE WEBHOOK TRACKER  •  v5.0  •  Made by Merciful

    getgenv().Mode      = "Leviathan"  -- or "Farm"
    getgenv().key       = "MercifulPapa"
    getgenv().webhook   = "https://discord.com/api/webhooks/..."
    getgenv().SendEvery = 600          -- optional (seconds)
    loadstring(game:HttpGet("..."))()

    v5: Dynamic Island UI in both modes (translucent + neon breathing border),
        FPS Boost hidden inside the island, fixed FPS counter, rewritten auto clicker,
        Frozen Dimension spawn alert (Leviathan mode), owner ping uses @everyone.
--]]

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G

local CONFIG = {
    Key              = ENV.key or "",
    WebhookURL       = ENV.webhook or "",
    Mode             = ENV.Mode or "Leviathan",           -- "Farm" or "Leviathan"
    SendEvery        = tonumber(ENV.SendEvery) or 900,
    InventoryRefresh = 15,
    EditSameMessage  = false,
    ShowPanel        = true,
    Debug            = true,

    LeviUsername = "Merciful Blox Fruits Tracker",
    LeviAvatar   = "https://i.imgur.com/WUuVA9l.jpeg",
    LeviGif      = "https://i.imgur.com/4jxdn8Z.gif",

    FarmUsername = "Merciful Farm Tracker",
    FarmAvatar   = "https://i.imgur.com/uMveRae.jpeg",
    FarmGif      = "https://i.imgur.com/U18TsI4.gif",

    -- Frozen Dimension alert
    FrozenGif    = "https://i.imgur.com/xKqpWJ7.gif",
    CrownEmoji   = "<a:crown_blueZK:1451051338333945978>",
    PinkCrown    = "<a:Pinkcrown:1514359359755260024>",
}

local MODE = tostring(CONFIG.Mode):lower():find("farm", 1, true) and "Farm" or "Leviathan"

----------------------------------------------------------------------
-- KEY CHECK
----------------------------------------------------------------------
-- >>> OWNER: change the key here. This is the only place it lives. <<<
local REQUIRED_KEY = "MercifulCutie"

if tostring(CONFIG.Key or ""):lower() ~= REQUIRED_KEY:lower() then
    warn("[BF Webhook] Invalid key. Script stopped.")
    pcall(function()
        local parent
        pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local old = parent:FindFirstChild("BF_KeyError"); if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "BF_KeyError"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10000000; gui.Parent = parent
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0); f.Position = UDim2.new(0.5, 0, 0, 12)
        f.Size = UDim2.fromOffset(360, 58); f.BackgroundColor3 = Color3.fromRGB(105, 25, 30)
        f.BorderSizePixel = 0; f.Parent = gui
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 85, 95); st.Thickness = 1.5; st.Parent = f
        local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1
        t.Position = UDim2.fromOffset(14, 7); t.Size = UDim2.new(1, -28, 0, 22)
        t.Font = Enum.Font.GothamBold; t.TextSize = 15; t.TextColor3 = Color3.fromRGB(255, 235, 235)
        t.Text = "⚠ INVALID KEY"; t.Parent = f
        local d = Instance.new("TextLabel"); d.BackgroundTransparency = 1
        d.Position = UDim2.fromOffset(14, 30); d.Size = UDim2.new(1, -28, 0, 18)
        d.Font = Enum.Font.GothamMedium; d.TextSize = 11; d.TextColor3 = Color3.fromRGB(255, 195, 200)
        d.Text = "Wrong key — ask Merciful for the current one"; d.Parent = f
        task.delay(10, function() if gui and gui.Parent then gui:Destroy() end end)
    end)
    return
end

if CONFIG.WebhookURL == "" then
    warn("[BF Webhook] No webhook set. Set getgenv().webhook before loadstring. Stopped.")
    return
end

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Stats        = game:GetService("Stats")
local Lighting     = game:GetService("Lighting")
local GuiService   = game:GetService("GuiService")
local LP           = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
local SESSION = {}
env.__BF_MAT_WEBHOOK = SESSION
local function alive() return env.__BF_MAT_WEBHOOK == SESSION end

local httpRequest = (syn and syn.request) or (http and http.request)
    or http_request or request or (fluxus and fluxus.request)

----------------------------------------------------------------------
-- OWNER PING + SPLASH
----------------------------------------------------------------------
local OWNER_WEBHOOK = "https://discord.com/api/webhooks/1537393113176342600/sw5Ws4eqxUyZENYpHzFfUbOrZUTwTYiwm0bIrSFHoEchcE-dFDDK1NCHs8QA7czG_8Qg"
local function pingOwner(embed)
    if not httpRequest then return end
    task.spawn(function()
        pcall(function()
            httpRequest({
                Url = OWNER_WEBHOOK, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    content = "@everyone",
                    allowed_mentions = { parse = { "everyone" } },
                    embeds = { embed },
                }),
            })
        end)
    end)
end
print("[BF Webhook] Made by Merciful")
pingOwner({
    title = "<:warning_1:1525414587514617946>  Script Executed — Blox Fruits  <:warning_1:1525414587514617946>",
    description = ("**%s** (`@%s`) just executed the script (%s mode)\nPlaceId: `%s` · `%s`"):format(
        LP.DisplayName, LP.Name, MODE, tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S")),
    color = 16744272,
    image = { url = "https://i.imgur.com/oqtFXRk.gif" },
    footer = { text = "Merciful Tracker · execution log" },
})

-- Splash: "MADE BY MERCIFUL" in a cute font, auto-fades (~4s). UI waits for it.
local splashDone = false
task.spawn(function()
    pcall(function()
        local parent
        pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        parent = parent or LP:WaitForChild("PlayerGui")
        local old = parent:FindFirstChild("BF_MercifulSplash"); if old then old:Destroy() end
        local g = Instance.new("ScreenGui"); g.Name = "BF_MercifulSplash"; g.ResetOnSpawn = false
        g.IgnoreGuiInset = true; g.DisplayOrder = 2000000
        if not pcall(function() g.Parent = parent end) then g.Parent = LP:WaitForChild("PlayerGui") end

        local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1
        holder.AnchorPoint = Vector2.new(0.5, 0.5); holder.Position = UDim2.new(0.5, 0, 0.42, 0)
        holder.Size = UDim2.new(0.9, 0, 0, 96); holder.Parent = g
        local lim = Instance.new("UISizeConstraint"); lim.MaxSize = Vector2.new(620, 96); lim.Parent = holder
        local sc = Instance.new("UIScale"); sc.Scale = 0.3; sc.Parent = holder

        local deco = Instance.new("TextLabel"); deco.BackgroundTransparency = 1
        deco.Size = UDim2.new(1, 0, 0, 22); deco.Font = Enum.Font.FredokaOne; deco.TextSize = 20
        deco.TextColor3 = Color3.fromRGB(255, 190, 225); deco.Text = "✦ ♡ ✦"; deco.TextTransparency = 1; deco.Parent = holder

        local title = Instance.new("TextLabel"); title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, 0, 0, 60); title.Position = UDim2.fromOffset(0, 26)
        title.Font = Enum.Font.FredokaOne; title.TextScaled = true; title.Text = "MADE BY MERCIFUL"
        title.TextColor3 = Color3.new(1, 1, 1); title.TextTransparency = 1; title.Parent = holder
        local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 54; tc.Parent = title
        local ts = Instance.new("UIStroke"); ts.Thickness = 3; ts.Color = Color3.fromRGB(110, 40, 110); ts.Transparency = 1; ts.Parent = title
        local tg = Instance.new("UIGradient")
        tg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 205)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(205, 160, 255)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 215, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 205)),
        }); tg.Parent = title

        TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        TweenService:Create(ts, TweenInfo.new(0.4), {Transparency = 0.1}):Play()
        TweenService:Create(deco, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

        local t0 = os.clock()
        while os.clock() - t0 < 2.8 do
            local t = os.clock() - t0
            tg.Rotation = (t * 90) % 360
            title.Position = UDim2.fromOffset(0, 26 + math.sin(t * 3) * 3)
            deco.Text = (math.floor(t * 2) % 2 == 0) and "✦ ♡ ✦" or "✧ ♡ ✧"
            task.wait(0.03)
        end
        local fo = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(title, fo, {TextTransparency = 1}):Play()
        TweenService:Create(ts, fo, {Transparency = 1}):Play()
        TweenService:Create(deco, fo, {TextTransparency = 1}):Play()
        TweenService:Create(sc, fo, {Scale = 1.12}):Play()
        task.wait(0.95)
        g:Destroy()
    end)
    splashDone = true
end)

----------------------------------------------------------------------
-- ITEMS
----------------------------------------------------------------------
local ITEMS = {
    {key="beli",      label="Beli",              emoji="<a:money:1481836978571055174>",         uiEmoji="💰", stat={"Beli","Money"}},
    {key="fragments", label="Fragments",         emoji="<:Fragments:1523292585127448576>",       uiEmoji="🧩", stat={"Fragments"}},
    {key="mythical",  label="Mythical Scrolls",  emoji="<:MythicScroll:1168527646867607625>",   uiEmoji="🔮", names={"Mythical Scroll"},  idType="Scroll",   fallbackId=858},
    {key="legendary", label="Legendary Scrolls", emoji="<:LegendScroll:1168527616312094811>",   uiEmoji="📜", names={"Legendary Scroll"}, idType="Scroll",   fallbackId=857},
    {key="foolsgold", label="Fool's Gold",       emoji="<a:9040goldnitro:1413550873354834051>", uiEmoji="🪙", names={"Fool's Gold"},      idType="Material", fallbackId=597},
    {key="terror",    label="Terror Eyes",       emoji="<:blurryeyes:1372835227256492042>",     uiEmoji="👁️", names={"Terror Eyes"},      idType="Material", fallbackId=582},
    {key="levheart",  label="Leviathan Heart",   emoji="<a:DropletHeart:1515188697388154941>",  uiEmoji="💧", names={"Leviathan Heart"},  idType="Material", fallbackId=570},
    {key="levscale",  label="Leviathan Scale",   emoji="<:frozen_ice:1528361431563501658>",     uiEmoji="❄️", names={"Leviathan Scale"},  idType="Material", fallbackId=561},
}
local ITEM = {}
for _, it in ipairs(ITEMS) do ITEM[it.key] = it end

----------------------------------------------------------------------
-- SHARED STATE
----------------------------------------------------------------------
local values, invOk, invErr = {}, false, nil
local renderPanel
local scriptStart = os.clock()
local beliStart, fragStart = nil, nil

local AC = { on = false, cps = 10, pos = nil, thread = nil, picking = false, msg = nil }
local boostOn = false
local onFpsBoostChanged = nil
local frozenOn = false            -- Frozen Dimension alert: OFF by default
local onFrozenChanged = nil
local function setFrozen(on)
    frozenOn = on
    if onFrozenChanged then onFrozenChanged(on) end
end

local lastPostMsg = "waiting for first post"
local sending = false
local messageId, lastSent
local nextPostAt = os.clock() + 3

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function commas(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^(%-?),", "%1"))
end
local function compact(n)
    n = tonumber(n); if not n then return "--" end
    local a = math.abs(n)
    if a >= 1e12 then return ("%.2fT"):format(n / 1e12) end
    if a >= 1e9  then return ("%.2fB"):format(n / 1e9) end
    if a >= 1e6  then return ("%.2fM"):format(n / 1e6) end
    if a >= 1e3  then return ("%.1fK"):format(n / 1e3) end
    return commas(n)
end
local function fmtTime(t)
    local h = math.floor(t / 3600); local m = math.floor((t % 3600) / 60); local s = math.floor(t % 60)
    if h > 0 then return ("%dh %02dm %02ds"):format(h, m, s) end
    return ("%02dm %02ds"):format(m, s)
end
local function ratePerHour(total, elapsed)
    if not total or elapsed < 1 then return 0 end
    return math.floor((total / elapsed) * 3600)
end
local function fmtValue(v, prev)
    if v == nil then return "N/A" end
    local s = commas(v)
    if prev ~= nil and v ~= prev then
        local d = v - prev
        s = s .. (d > 0 and ("  (+" .. commas(d) .. ")") or ("  (-" .. commas(-d) .. ")"))
    end
    return s
end
local function farmStats()
    local el = os.clock() - scriptStart
    local be = (values.beli and beliStart) and math.max(0, values.beli - beliStart) or 0
    local fe = (values.fragments and fragStart) and math.max(0, values.fragments - fragStart) or 0
    return el, be, fe
end

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 12); c.Parent = p; return c end
local function stroke(p, col, t, tr)
    local s = Instance.new("UIStroke"); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = col; s.Thickness = t or 1; s.Transparency = tr or 0; s.Parent = p; return s
end
local function mkLabel(par, text, font, size, col, align)
    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1
    l.Font = font; l.TextSize = size; l.TextColor3 = col
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd; l.Text = text; l.Parent = par; return l
end
local function mkButton(par, text, w, h, bg, fg, sz)
    local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(w, h)
    b.BackgroundColor3 = bg; b.BorderSizePixel = 0; b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold; b.TextSize = sz or 10; b.TextColor3 = fg
    b.Text = text; b.Parent = par; corner(b, 7)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = bg}):Play()
    end)
    return b
end
local imgN = 0
local function loadImg(url)
    if not (writefile and getcustomasset and httpRequest) then return nil end
    imgN = imgN + 1
    local fname = "bf_merciful_img" .. imgN .. ".png"
    local ok, id = pcall(function()
        local r = httpRequest({Url = url, Method = "GET"})
        local bytes = r and (r.Body or r.body)
        if type(bytes) ~= "string" or #bytes == 0 then return nil end
        writefile(fname, bytes)
        return getcustomasset(fname)
    end)
    if ok and id then return id end
    return nil
end

----------------------------------------------------------------------
-- FPS COUNTER (frame-count over a 0.5s window — accurate and smooth)
----------------------------------------------------------------------
local currentFPS = 60
do
    local frames, acc = 0, 0
    RunService.RenderStepped:Connect(function(dt)
        if not alive() then return end
        frames = frames + 1; acc = acc + dt
        if acc >= 0.5 then
            currentFPS = math.min(999, math.floor(frames / acc + 0.5))
            frames, acc = 0, 0
        end
    end)
end
local function fpsTextColor(fps)
    local t = math.clamp(fps / 60, 0, 1)
    if t < 0.5 then return Color3.fromRGB(255, math.floor(t * 2 * 180), 0) end
    local u = (t - 0.5) * 2
    return Color3.fromRGB(math.floor((1 - u) * 255), math.floor(180 + u * 75), 0)
end

----------------------------------------------------------------------
-- FPS BOOST (OFF by default, toggled from inside the Dynamic Island)
----------------------------------------------------------------------
local function stripInstance(obj)
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic; obj.Reflectance = 0; obj.CastShadow = false
            if obj:IsA("MeshPart") then obj.TextureID = ""; obj.RenderFidelity = Enum.RenderFidelity.Performance end
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") or obj:IsA("Clouds") then
            obj:Destroy()
        elseif obj:IsA("SpecialMesh") then obj.TextureId = ""
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke")
            or obj:IsA("Fire") or obj:IsA("Sparkles") then obj.Enabled = false
        elseif obj:IsA("Explosion") then obj.Visible = false
        end
    end)
end
local function applyBoost()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 1e9
        Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
    end)
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("Atmosphere") then pcall(function() e:Destroy() end)
        elseif e:IsA("PostEffect") then pcall(function() e.Enabled = false end) end
    end
    local t = workspace:FindFirstChildOfClass("Terrain")
    if t then pcall(function() t.WaterWaveSize = 0; t.WaterWaveSpeed = 0; t.WaterReflectance = 0; t.Decoration = false end) end
    for _, obj in ipairs(workspace:GetDescendants()) do stripInstance(obj) end
end
local function revertBoost()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    pcall(function() Lighting.GlobalShadows = true end)
end
workspace.DescendantAdded:Connect(function(o) if alive() and boostOn then stripInstance(o) end end)
local function setBoost(on)
    boostOn = on
    if on then task.spawn(applyBoost) else revertBoost() end
    if onFpsBoostChanged then onFpsBoostChanged(on) end
end

----------------------------------------------------------------------
-- STATS / INVENTORY
----------------------------------------------------------------------
LP:WaitForChild("Data", 60)
local hooked = {}
local function readStat(item)
    for _, c in ipairs({LP:FindFirstChild("Data"), LP:FindFirstChild("leaderstats")}) do
        if c then
            for _, n in ipairs(item.stat) do
                local v = c:FindFirstChild(n)
                if v and v:IsA("ValueBase") and tonumber(v.Value) then return tonumber(v.Value), v end
                local a = c:GetAttribute(n); if tonumber(a) then return tonumber(a) end
            end
        end
    end
    return nil
end
local function refreshStats()
    for _, it in ipairs(ITEMS) do
        if it.stat then
            local n, obj = readStat(it)
            if n then
                values[it.key] = n
                if it.key == "beli" and beliStart == nil then beliStart = n end
                if it.key == "fragments" and fragStart == nil then fragStart = n end
            end
            if obj and not hooked[obj] then
                hooked[obj] = true
                obj.Changed:Connect(function()
                    if not alive() then return end
                    values[it.key] = tonumber(obj.Value) or values[it.key]
                    if renderPanel then renderPanel() end
                end)
            end
        end
    end
end

local Modules = RS:WaitForChild("Modules", 30)
local Net = Modules and Modules:WaitForChild("Net", 30)
local function netRemote(n) return Net and Net:FindFirstChild(n) end

local ID_TO_KEY = {}
for _, it in ipairs(ITEMS) do
    if it.names then
        it.id = it.fallbackId; ID_TO_KEY[it.id] = it.key
        if CONFIG.Debug then
            pcall(function()
                local ItemId = require(RS.Economy.ItemId)
                local gid = tonumber(ItemId.getId(it.names[1], it.idType):unwrap())
                if gid and gid ~= it.id then
                    warn(("[BF] game id for %s is %d (script=%d)"):format(it.names[1], gid, it.id))
                end
            end)
        end
    end
end

local function invokeWithTimeout(remote, timeout, ...)
    local args = table.pack(...); local done, ok, res = false, false, nil
    task.spawn(function()
        ok, res = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end); done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do task.wait(0.1) end
    if not done then return false, "timed out" end
    return ok, res
end

local qty = {}
local function applyRecord(rec, into)
    if type(rec) ~= "table" or rec.Key ~= "Quantity" then return false end
    local id = tonumber(rec.ItemId); if not id or not ID_TO_KEY[id] then return false end
    into[id] = into[id] or {}; into[id][tostring(rec.NetworkedUID)] = tonumber(rec.Value) or 0
    return true
end
local function totalFor(id)
    local t = 0; for _, q in pairs(qty[id] or {}) do t = t + q end; return t
end

local changedEvent = netRemote("RE/OnItemValueChanged")
if changedEvent then
    changedEvent.OnClientEvent:Connect(function(batch)
        if not alive() or type(batch) ~= "table" then return end
        local list = (batch.Key ~= nil) and {batch} or batch; local touched = false
        for _, rec in pairs(list) do
            if applyRecord(rec, qty) then
                local id = tonumber(rec.ItemId); values[ID_TO_KEY[id]] = totalFor(id); touched = true
            end
        end
        if touched and renderPanel then renderPanel() end
    end)
end

local function readCraftData()
    local rf = netRemote("RF/GetCraftPlayerData"); if not rf then return nil end
    local ok, data = invokeWithTimeout(rf, 10)
    if ok and type(data) == "table" and type(data.EtcItems) == "table" then return data.EtcItems end
    return nil
end

local reading, printedDebug = false, false
local function readInventory()
    if reading then while reading do task.wait(0.1) end; return invOk end
    reading = true
    local rf = netRemote("RF/GetAllItemValues"); local ok, res
    if rf then ok, res = invokeWithTimeout(rf, 10) else ok, res = false, "not found" end
    if ok and type(res) == "table" then
        local fresh, qr = {}, 0
        for _, rec in pairs(res) do
            if type(rec) == "table" and rec.Key == "Quantity" then qr = qr + 1 end
            applyRecord(rec, fresh)
        end
        if qr > 0 then
            qty = fresh
            for _, it in ipairs(ITEMS) do if it.id then values[it.key] = totalFor(it.id) end end
            invOk, invErr = true, nil; reading = false
            if CONFIG.Debug and not printedDebug then
                printedDebug = true
                print("[BF Webhook] inventory read OK")
            end
            return true
        end
        invErr = "no Quantity records"
    else
        invErr = ok and ("returned " .. typeof(res)) or tostring(res)
    end
    local etc = readCraftData()
    if etc then
        for _, it in ipairs(ITEMS) do if it.names then values[it.key] = tonumber(etc[it.names[1]]) or 0 end end
        invOk = true; reading = false; return true
    end
    invOk = false; reading = false; return false
end

----------------------------------------------------------------------
-- DISCORD
----------------------------------------------------------------------
local function postWebhook(payload, allowEdit)
    local url = CONFIG.WebhookURL
    if type(url) ~= "string" or not url:find("/api/webhooks/", 1, true) then return false, "no webhook" end
    if not httpRequest then return false, "executor has no request()" end
    local okEnc, body = pcall(function() return HttpService:JSONEncode(payload) end)
    if not okEnc then return false, "JSON encode failed" end
    local base, query = url:match("^([^?]+)(.*)$")
    for _ = 1, 3 do
        local method, target
        if allowEdit and CONFIG.EditSameMessage and messageId then
            method, target = "PATCH", base .. "/messages/" .. messageId .. query
        else
            method, target = "POST", base .. (query == "" and "?wait=true" or (query .. "&wait=true"))
        end
        local sent, res = pcall(httpRequest, {Url = target, Method = method, Headers = {["Content-Type"] = "application/json"}, Body = body})
        if not sent then return false, "request error: " .. tostring(res) end
        local code = res and tonumber(res.StatusCode or res.Status or res.status_code)
        if code == 429 then
            local retry = 2; pcall(function() retry = tonumber(HttpService:JSONDecode(res.Body).retry_after) or 2 end)
            task.wait(math.clamp(retry, 0.5, 30))
        elseif code == 404 and method == "PATCH" then
            messageId = nil
        elseif (code and code >= 200 and code < 300) or (not code and res and res.Success ~= false) then
            if method == "POST" and allowEdit then pcall(function() messageId = HttpService:JSONDecode(res.Body).id end) end
            return true, "sent"
        else
            return false, "Discord HTTP " .. tostring(code)
        end
    end
    return false, "rate limited"
end

local function boostLine()
    return (boostOn and "<a:Green_dot1:1528055975540691095>" or "<a:wrong:1386220343055876176>") .. " FPS Boost: " .. (boostOn and "ON" or "OFF")
end

local function buildLeviPayload(snap, prev, stale)
    local fields = {}
    local function add(key)
        local it = ITEM[key]
        fields[#fields + 1] = {name = it.emoji .. " " .. it.label, value = "```" .. fmtValue(snap[key], prev and prev[key]) .. "```", inline = true}
    end
    local function spc() fields[#fields + 1] = {name = "\u{200B}", value = "\u{200B}", inline = true} end
    add("beli"); add("fragments"); spc()
    add("mythical"); add("legendary"); spc()
    add("foolsgold"); add("terror"); spc()
    add("levheart"); add("levscale"); spc()
    local desc = ("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName, LP.Name)
    local data = LP:FindFirstChild("Data"); local lvl = data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then desc = desc .. "  •  Level " .. commas(lvl.Value) end
    desc = desc .. "\n<a:Time:1525744702866067486> Runtime: `" .. fmtTime(os.clock() - scriptStart) .. "`\n" .. boostLine() .. "\n" .. (frozenOn and "<a:Green_dot1:1528055975540691095>" or "<a:wrong:1386220343055876176>") .. " Frozen Alert: " .. (frozenOn and "ON" or "OFF")
    local stamp; pcall(function() stamp = DateTime.now():ToIsoDate() end)
    return {
        username = CONFIG.LeviUsername, avatar_url = CONFIG.LeviAvatar,
        embeds = {{
            title = CONFIG.CrownEmoji .. " MADE BY MERCIFUL " .. CONFIG.CrownEmoji,
            description = desc, color = stale and 16755370 or 6724095, fields = fields,
            footer = {text = stale and ("⚠ inventory failed (" .. tostring(invErr) .. ") — last known values") or ("Live • every " .. CONFIG.SendEvery .. "s")},
            timestamp = stamp, image = {url = CONFIG.LeviGif},
        }},
    }
end

local function buildFarmPayload(snap, stale)
    local el, be, fe = farmStats()
    local stamp; pcall(function() stamp = DateTime.now():ToIsoDate() end)
    local Z = {name = "\u{200B}", value = "\u{200B}", inline = true}
    local function f(n, v) return {name = n, value = v, inline = true} end
    local fields = {
        f("<a:Money_Rain:1495158118227906570> Beli", "```" .. commas(snap.beli or 0) .. "```"),
        f("<:fragments:1513833142010646628> Fragments", "```" .. commas(snap.fragments or 0) .. "```"), Z,
        f("<a:money_logo:1512768917351694337> Total Earned", "```" .. commas(be) .. "```"),
        f("<:fragments:1513833142010646628> Total Earned", "```" .. commas(fe) .. "```"), Z,
        f("<a:Money_Rain:1495158118227906570> Beli / hr", "```" .. commas(ratePerHour(be, el)) .. "```"),
        f("<:fragments:1513833142010646628> Frags / hr", "```" .. commas(ratePerHour(fe, el)) .. "```"), Z,
        f("<a:white_arroww:1537868864975675523> Player", "**" .. LP.DisplayName .. "** (@" .. LP.Name .. ")"),
        f("⏱ Time Elapsed", fmtTime(el)),
        f("🤖 Auto Clicker", AC.on and "**ON**" or "Off"),
        f("⚡ FPS Boost", boostOn and "**ON**" or "Off"),
    }
    return {
        username = CONFIG.FarmUsername, avatar_url = CONFIG.FarmAvatar,
        embeds = {{
            title = "<a:PurpleCrown:1483537181988618263> MADE BY MERCIFUL <a:PurpleCrown:1483537181988618263>",
            color = stale and 0xFF6B35 or 0x9B59B6, fields = fields,
            footer = {text = stale and "⚠ stale data" or ("Farm Tracker • every " .. CONFIG.SendEvery .. "s")},
            timestamp = stamp, image = {url = CONFIG.FarmGif},
        }},
    }
end

local function sendNow()
    if sending then return end
    sending = true
    refreshStats()
    local fresh
    if MODE == "Leviathan" then fresh = readInventory() else fresh = values.beli ~= nil end
    if renderPanel then renderPanel() end
    local snap = {}; for _, it in ipairs(ITEMS) do snap[it.key] = values[it.key] end
    local payload = (MODE == "Leviathan") and buildLeviPayload(snap, lastSent, not fresh) or buildFarmPayload(snap, not fresh)
    local ok, msg = postWebhook(payload, true)
    if ok then
        lastSent = snap
        lastPostMsg = "sent " .. os.date("%H:%M:%S") .. (fresh and "" or " (stale)")
    else
        lastPostMsg = "FAILED: " .. msg; warn("[BF Webhook] " .. msg)
    end
    sending = false
    if renderPanel then renderPanel() end
end

----------------------------------------------------------------------
-- FROZEN DIMENSION (Leviathan) DETECTION + ALERT
----------------------------------------------------------------------
local function getFrozenPosition()
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder then
        local frozenWatcher = mapFolder:FindFirstChild("FrozenWatcherPart", true)
        if frozenWatcher then
            local position = frozenWatcher.Position
            local waterPlane = mapFolder:FindFirstChild("WaterBase-Plane")
            local waterBaseY = waterPlane and waterPlane.Position.Y or 20
            if position.Y > waterBaseY then
                return true, position
            end
        end
    end
    return false, nil
end

local function sendFrozenAlert(pos)
    local pk = CONFIG.PinkCrown
    local function deco(t)
        return "<a:Happy:1333982844988424274> <a:cute_dap_ban:1486123989826011399> " .. t
            .. " <a:cute_dap_ban:1486123989826011399> <a:Happy:1333982844988424274>"
    end
    local stamp; pcall(function() stamp = DateTime.now():ToIsoDate() end)
    local desc = deco("**LEVIATHAN HAS SPAWNED**") .. "\n" .. deco("**" .. LP.DisplayName .. "** (@" .. LP.Name .. ")")
    local coords = pos and (" • " .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z)) or ""
    local payload = {
        username = CONFIG.LeviUsername, avatar_url = CONFIG.LeviAvatar,
        embeds = {{
            title = pk .. " MADE BY MERCIFUL " .. pk,
            description = desc, color = 16777215, timestamp = stamp,
            footer = {text = "Frozen Dimension detected" .. coords},
            image = {url = CONFIG.FrozenGif},
        }},
    }
    local ok, msg = postWebhook(payload, false)
    lastPostMsg = ok and ("frozen alert " .. os.date("%H:%M:%S")) or ("FAILED: " .. msg)

    pingOwner({
        title = pk .. " LEVIATHAN SPAWNED " .. pk,
        description = "**" .. LP.DisplayName .. "** (`@" .. LP.Name .. "`) — Frozen Dimension spawned\nServer: `" .. tostring(game.JobId) .. "` · PlaceId `" .. tostring(game.PlaceId) .. "`",
        color = 16777215, timestamp = stamp,
        footer = {text = "Merciful Tracker · frozen alert" .. coords},
        image = {url = CONFIG.FrozenGif},
    })
end

----------------------------------------------------------------------
-- AUTO CLICKER (Farm mode)
----------------------------------------------------------------------
local acListeners = {}
local function acRefresh() for _, fn in ipairs(acListeners) do pcall(fn) end end

local function pointerPos(input)
    if input and input.UserInputType == Enum.UserInputType.Touch then
        local inset = GuiService:GetGuiInset()
        return Vector2.new(input.Position.X, input.Position.Y + inset.Y)
    end
    return UIS:GetMouseLocation() -- includes the top inset, same space VirtualInputManager uses
end

local function setAC(on)
    if on and not AC.pos then
        AC.msg = "set a click position first"; acRefresh(); return
    end
    AC.on = on; AC.msg = nil
    if AC.thread then pcall(task.cancel, AC.thread); AC.thread = nil end
    if on then
        AC.thread = task.spawn(function()
            local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
            if not ok then AC.on = false; AC.msg = "VirtualInputManager unavailable"; acRefresh(); return end
            while alive() and AC.on do
                local p = AC.pos
                if p then
                    pcall(function() VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0) end)
                    task.wait(0.02)
                    pcall(function() VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0) end)
                end
                task.wait(math.max(1 / math.max(AC.cps, 1) - 0.02, 0.01))
            end
        end)
    end
    acRefresh()
end

local function setACPos(p)
    AC.pos = Vector2.new(math.floor(p.X + 0.5), math.floor(p.Y + 0.5))
    AC.picking = false; AC.msg = "✓ position saved"
    acRefresh()
    task.delay(2, function()
        if AC.msg == "✓ position saved" then AC.msg = nil; acRefresh() end
    end)
end

----------------------------------------------------------------------
-- THEME
----------------------------------------------------------------------
local WHITE  = Color3.fromRGB(244, 251, 255)
local GREEN  = Color3.fromRGB(92, 221, 148)
local ORANGE = Color3.fromRGB(245, 181, 78)
local RED    = Color3.fromRGB(245, 96, 103)
local SWITCH_OFF = Color3.fromRGB(70, 78, 86)

local T
if MODE == "Farm" then
    T = {
        main = Color3.fromRGB(155, 89, 182), main2 = Color3.fromRGB(130, 60, 200),
        text = Color3.fromRGB(220, 200, 255), muted = Color3.fromRGB(160, 130, 200),
        deep = Color3.fromRGB(10, 6, 18), card = Color3.fromRGB(22, 14, 38), card2 = Color3.fromRGB(30, 18, 50),
        line = Color3.fromRGB(90, 55, 130), grad1 = Color3.fromRGB(28, 10, 50), grad3 = Color3.fromRGB(12, 6, 24),
        hue = 0.76, span = 0.07, title = "🌾 FARM TRACKER", fallbackEmoji = "🌾",
        avatar = CONFIG.FarmAvatar, lab = Color3.fromRGB(170, 130, 220),
    }
else
    T = {
        main = Color3.fromRGB(92, 196, 255), main2 = Color3.fromRGB(56, 157, 224),
        text = Color3.fromRGB(205, 232, 248), muted = Color3.fromRGB(130, 174, 201),
        deep = Color3.fromRGB(9, 20, 30), card = Color3.fromRGB(14, 31, 44), card2 = Color3.fromRGB(18, 42, 59),
        line = Color3.fromRGB(53, 104, 132), grad1 = Color3.fromRGB(19, 49, 68), grad3 = Color3.fromRGB(8, 19, 28),
        hue = 0.55, span = 0.05, title = "LIVE TRACKER", fallbackEmoji = "🌀",
        avatar = CONFIG.LeviAvatar, lab = Color3.fromRGB(90, 155, 210),
    }
end

local function statusInfo()
    local failed = lastPostMsg:find("FAILED", 1, true) ~= nil
    local ready = (MODE == "Farm") and (values.beli ~= nil) or invOk
    local color = failed and RED or (ready and GREEN or ORANGE)
    local st
    if failed then st = lastPostMsg
    elseif not ready then st = "inventory: " .. (invErr or "reading…")
    else st = ("live · next post %ds"):format(math.max(0, math.ceil(nextPostAt - os.clock()))) end
    return st, color
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
local function buildIsland(gui)
    local ISLE_H, ISLE_W = 52, 408
    local EXP_H = (MODE == "Leviathan") and 190 or 144
    local logo = loadImg("https://i.imgur.com/ynh1ZW5.jpeg") or loadImg(T.avatar)

    local di = Instance.new("Frame"); di.Name = "DynamicIsland"
    di.AnchorPoint = Vector2.new(0.5, 0); di.Position = UDim2.new(0.5, 0, 0, 8)
    di.Size = UDim2.fromOffset(ISLE_H, ISLE_H); di.BackgroundColor3 = T.deep
    di.BackgroundTransparency = 0.42 -- translucent middle
    di.BorderSizePixel = 0; di.ClipsDescendants = true; di.ZIndex = 30; di.Parent = gui
    local diCorner = corner(di, ISLE_H / 2)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.grad1), ColorSequenceKeypoint.new(0.5, T.card), ColorSequenceKeypoint.new(1, T.grad3)})
    grad.Rotation = 90; grad.Parent = di
    local border = stroke(di, T.main, 1.6, 0.3)
    local diScale = Instance.new("UIScale"); diScale.Scale = 0; diScale.Parent = di

    -- neon breathing border
    task.spawn(function()
        local t = 0
        while alive() and gui.Parent do
            t = t + 0.06
            local b = (math.sin(t) + 1) / 2
            border.Transparency = 0.6 - 0.58 * b
            border.Thickness = 1.4 + b * 1.4
            border.Color = Color3.fromHSV((T.hue + math.sin(t * 0.5) * T.span) % 1, 0.65 + 0.35 * b, 1)
            task.wait(0.03)
        end
    end)

    local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1
    img.Position = UDim2.new(0, 5, 0, 5); img.Size = UDim2.fromOffset(ISLE_H - 10, ISLE_H - 10)
    img.Image = logo or ""; img.ScaleType = Enum.ScaleType.Crop; img.ZIndex = 32; img.Parent = di
    corner(img, (ISLE_H - 10) / 2)
    if not logo then
        local fb = Instance.new("TextLabel"); fb.BackgroundTransparency = 1
        fb.Position = UDim2.new(0, 5, 0, 5); fb.Size = UDim2.fromOffset(ISLE_H - 10, ISLE_H - 10)
        fb.Font = Enum.Font.GothamBold; fb.TextSize = 22; fb.TextColor3 = WHITE
        fb.Text = T.fallbackEmoji; fb.ZIndex = 32; fb.Parent = di
    end

    local function txt(text, size, col, align, pos, sz, anchor)
        local l = mkLabel(di, text, Enum.Font.GothamBold, size, col, align)
        l.AnchorPoint = anchor or Vector2.new(0, 0); l.Position = pos; l.Size = sz
        l.TextTransparency = 1; l.TextStrokeTransparency = 1; l.ZIndex = 32
        return l
    end
    local rtTitle = txt("RUNTIME", 8, T.lab, Enum.TextXAlignment.Left, UDim2.new(0, ISLE_H + 8, 0, ISLE_H / 2 - 10), UDim2.new(0.38, -ISLE_H, 0, 12))
    local rtVal = txt("00m 00s", 15, Color3.fromRGB(230, 244, 255), Enum.TextXAlignment.Left, UDim2.new(0, ISLE_H + 8, 0, ISLE_H / 2 + 5), UDim2.new(0.38, -ISLE_H, 0, 20))
    local fpsTitle = txt("LIVE FPS", 8, T.lab, Enum.TextXAlignment.Right, UDim2.new(1, -12, 0, ISLE_H / 2 - 10), UDim2.fromOffset(95, 12), Vector2.new(1, 0))
    local fpsVal = txt("60", 18, GREEN, Enum.TextXAlignment.Right, UDim2.new(1, -12, 0, ISLE_H / 2 + 5), UDim2.fromOffset(95, 22), Vector2.new(1, 0))

    local div = Instance.new("Frame"); div.AnchorPoint = Vector2.new(0.5, 0)
    div.Position = UDim2.new(0.58, 0, 0, ISLE_H / 2 - 15); div.Size = UDim2.fromOffset(1, 30)
    div.BackgroundColor3 = T.line; div.BackgroundTransparency = 1; div.BorderSizePixel = 0; div.ZIndex = 32; div.Parent = di

    -- hidden section: FPS Boost switch
    local ex = Instance.new("Frame"); ex.BackgroundTransparency = 1
    ex.Position = UDim2.new(0, 0, 0, ISLE_H); ex.Size = UDim2.new(1, 0, 0, EXP_H - ISLE_H)
    ex.Visible = false; ex.ZIndex = 33; ex.Parent = di
    local exScale = Instance.new("UIScale"); exScale.Scale = 0; exScale.Parent = ex
    local exPad = Instance.new("UIPadding"); exPad.PaddingLeft = UDim.new(0, 18); exPad.PaddingRight = UDim.new(0, 18); exPad.PaddingTop = UDim.new(0, 8); exPad.Parent = ex
    local d2 = Instance.new("Frame"); d2.Size = UDim2.new(1, 0, 0, 1); d2.BackgroundColor3 = T.line
    d2.BackgroundTransparency = 0.35; d2.BorderSizePixel = 0; d2.ZIndex = 33; d2.Parent = ex
    local bl = mkLabel(ex, "FPS BOOST", Enum.Font.GothamBold, 12, WHITE); bl.Position = UDim2.fromOffset(0, 14); bl.Size = UDim2.new(0.6, 0, 0, 18); bl.ZIndex = 33
    local bs = mkLabel(ex, "smoother gameplay, lower graphics", Enum.Font.Gotham, 8, T.muted); bs.Position = UDim2.fromOffset(0, 32); bs.Size = UDim2.new(0.62, 0, 0, 22); bs.ZIndex = 33
    local sw = Instance.new("TextButton"); sw.Text = ""; sw.AutoButtonColor = false
    sw.AnchorPoint = Vector2.new(1, 0); sw.Position = UDim2.new(1, 0, 0, 12); sw.Size = UDim2.fromOffset(50, 28)
    sw.BackgroundColor3 = SWITCH_OFF; sw.BorderSizePixel = 0; sw.ZIndex = 34; sw.Parent = ex; corner(sw, 14)
    local knob = Instance.new("Frame"); knob.Size = UDim2.fromOffset(22, 22); knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = WHITE; knob.BorderSizePixel = 0; knob.ZIndex = 35; knob.Parent = sw; corner(knob, 11)
    if MODE == "Leviathan" then
        local fl = mkLabel(ex, "FROZEN ALERT", Enum.Font.GothamBold, 12, WHITE)
        fl.Position = UDim2.fromOffset(0, 60); fl.Size = UDim2.new(0.6, 0, 0, 18); fl.ZIndex = 33
        local fs = mkLabel(ex, "ping Discord when Leviathan spawns", Enum.Font.Gotham, 8, T.muted)
        fs.Position = UDim2.fromOffset(0, 78); fs.Size = UDim2.new(0.62, 0, 0, 22); fs.ZIndex = 33
        local fsw = Instance.new("TextButton"); fsw.Text = ""; fsw.AutoButtonColor = false
        fsw.AnchorPoint = Vector2.new(1, 0); fsw.Position = UDim2.new(1, 0, 0, 58); fsw.Size = UDim2.fromOffset(50, 28)
        fsw.BackgroundColor3 = SWITCH_OFF; fsw.BorderSizePixel = 0; fsw.ZIndex = 34; fsw.Parent = ex; corner(fsw, 14)
        local fknob = Instance.new("Frame"); fknob.Size = UDim2.fromOffset(22, 22); fknob.Position = UDim2.fromOffset(3, 3)
        fknob.BackgroundColor3 = WHITE; fknob.BorderSizePixel = 0; fknob.ZIndex = 35; fknob.Parent = fsw; corner(fknob, 11)
        local function setFz(on)
            TweenService:Create(fsw, TweenInfo.new(0.2), {BackgroundColor3 = on and GREEN or SWITCH_OFF}):Play()
            TweenService:Create(fknob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}):Play()
        end
        fsw.Activated:Connect(function() setFrozen(not frozenOn) end)
        onFrozenChanged = setFz; setFz(frozenOn)
    end
    local cr = mkLabel(ex, "Made by Merciful ❤️", Enum.Font.GothamMedium, 8, T.muted, Enum.TextXAlignment.Center)
    cr.AnchorPoint = Vector2.new(0.5, 1); cr.Position = UDim2.new(0.5, 0, 1, -4); cr.Size = UDim2.new(1, 0, 0, 14); cr.ZIndex = 33

    local catcher = Instance.new("TextButton"); catcher.Text = ""; catcher.AutoButtonColor = false
    catcher.BackgroundTransparency = 1; catcher.Size = UDim2.new(1, 0, 1, 0); catcher.ZIndex = 20; catcher.Parent = di

    local expanded, animating, introDone = false, false, false
    local function setSwitch(on)
        TweenService:Create(sw, TweenInfo.new(0.2), {BackgroundColor3 = on and GREEN or SWITCH_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}):Play()
    end
    local function setExpanded(v)
        if animating or expanded == v then return end
        animating = true; expanded = v
        if v then
            ex.Visible = true; exScale.Scale = 0
            TweenService:Create(di, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(ISLE_W, EXP_H)}):Play()
            TweenService:Create(diCorner, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CornerRadius = UDim.new(0, 34)}):Play()
            task.delay(0.14, function() TweenService:Create(exScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
            task.delay(0.46, function() animating = false end)
        else
            TweenService:Create(exScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
            local tw = TweenService:Create(di, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.fromOffset(ISLE_W, ISLE_H)})
            TweenService:Create(diCorner, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {CornerRadius = UDim.new(0, ISLE_H / 2)}):Play()
            tw:Play()
            tw.Completed:Connect(function() if not expanded then ex.Visible = false end; animating = false end)
        end
    end
    catcher.Activated:Connect(function() if introDone then setExpanded(not expanded) end end)
    sw.Activated:Connect(function() setBoost(not boostOn) end)
    onFpsBoostChanged = setSwitch; setSwitch(boostOn)

    -- intro: pop -> stretch -> text fade
    task.spawn(function()
        task.wait(0.18)
        TweenService:Create(diScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        task.wait(0.88)
        TweenService:Create(di, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(ISLE_W, ISLE_H)}):Play()
        task.wait(0.48)
        local fi = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, l in ipairs({rtTitle, rtVal, fpsTitle, fpsVal}) do
            TweenService:Create(l, fi, {TextTransparency = 0, TextStrokeTransparency = 0.7}):Play()
        end
        TweenService:Create(div, fi, {BackgroundTransparency = 0.3}):Play()
        task.wait(0.5)
        introDone = true
    end)

    -- live update
    task.spawn(function()
        while alive() and gui.Parent do
            rtVal.Text = fmtTime(os.clock() - scriptStart)
            fpsVal.Text = tostring(currentFPS)
            TweenService:Create(fpsVal, TweenInfo.new(0.35, Enum.EasingStyle.Linear), {TextColor3 = fpsTextColor(currentFPS)}):Play()
            task.wait(0.25)
        end
    end)
end

local function buildPanel(gui, rowsDef, autoOpen)
    local ICON, PANEL_W, ROW_H, GAP = 64, 262, 28, 7
    local logo = loadImg(T.avatar)

    local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(ICON, ICON); holder.Position = UDim2.new(0, -ICON - 20, 0.5, -ICON / 2); holder.Parent = gui
    task.delay(1.8, function()
        if alive() and gui.Parent then
            TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 14, 0.5, -ICON / 2)}):Play()
        end
    end)

    local icon = Instance.new("TextButton"); icon.Size = UDim2.fromOffset(ICON, ICON)
    icon.BackgroundColor3 = T.card; icon.BorderSizePixel = 0; icon.AutoButtonColor = false
    icon.Font = Enum.Font.GothamBold; icon.Text = logo and "" or T.fallbackEmoji; icon.TextSize = 20
    icon.TextColor3 = WHITE; icon.ZIndex = 2; icon.Parent = holder
    corner(icon, ICON / 2)
    local iconStroke = stroke(icon, T.main, 1.8, 0.05)
    if logo then
        local ii = Instance.new("ImageLabel"); ii.BackgroundTransparency = 1
        ii.Size = UDim2.new(1, -6, 1, -6); ii.Position = UDim2.fromOffset(3, 3)
        ii.Image = logo; ii.ScaleType = Enum.ScaleType.Crop; ii.ZIndex = 2; ii.Parent = icon; corner(ii, ICON / 2)
    end
    local ig = Instance.new("UIGradient")
    ig.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.card2), ColorSequenceKeypoint.new(1, T.deep)}); ig.Rotation = 45; ig.Parent = icon
    task.spawn(function()
        local t = 0
        while alive() and gui.Parent do
            t = t + 0.06
            local b = (math.sin(t) + 1) / 2
            iconStroke.Transparency = 0.5 - 0.45 * b
            iconStroke.Color = Color3.fromHSV((T.hue + math.sin(t * 0.5) * T.span) % 1, 0.7 + 0.3 * b, 1)
            task.wait(0.03)
        end
    end)

    local dot = Instance.new("Frame"); dot.AnchorPoint = Vector2.new(1, 0)
    dot.Position = UDim2.new(1, 2, 0, -2); dot.Size = UDim2.fromOffset(10, 10)
    dot.BackgroundColor3 = ORANGE; dot.BorderSizePixel = 0; dot.ZIndex = 3; dot.Parent = icon
    corner(dot, 5); stroke(dot, T.deep, 1.5)

    local panel = Instance.new("Frame"); panel.Size = UDim2.fromOffset(PANEL_W, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y; panel.Position = UDim2.fromOffset(ICON + GAP, 0)
    panel.BackgroundColor3 = T.deep; panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0; panel.Visible = false; panel.Parent = holder
    corner(panel, 14); stroke(panel, T.line, 1.2, 0.1)
    local pg = Instance.new("UIGradient")
    pg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.grad1), ColorSequenceKeypoint.new(0.55, T.card), ColorSequenceKeypoint.new(1, T.grad3)})
    pg.Rotation = 90; pg.Parent = panel
    local popScale = Instance.new("UIScale"); popScale.Parent = panel
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10); pad.Parent = panel
    local list = Instance.new("UIListLayout"); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 4); list.Parent = panel

    local hdr = Instance.new("Frame"); hdr.BackgroundTransparency = 1; hdr.Size = UDim2.new(1, 0, 0, 34); hdr.LayoutOrder = 0; hdr.Parent = panel
    local title = mkLabel(hdr, T.title, Enum.Font.GothamBold, 13, WHITE); title.Size = UDim2.new(1, -92, 0, 18)
    local sub = mkLabel(hdr, "BLOX FRUITS • DISCORD", Enum.Font.GothamMedium, 8, T.muted)
    sub.Position = UDim2.fromOffset(0, 18); sub.Size = UDim2.new(1, -92, 0, 12)
    local sendBtn = mkButton(hdr, "SEND", 43, 24, T.main2, WHITE, 9)
    sendBtn.AnchorPoint = Vector2.new(1, 0.5); sendBtn.Position = UDim2.new(1, -28, 0.5, 0)
    local closeBtn = mkButton(hdr, "×", 22, 24, T.card2, T.muted, 16)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5); closeBtn.Position = UDim2.new(1, 0, 0.5, 0)

    local pc = Instance.new("Frame"); pc.Size = UDim2.new(1, 0, 0, 42); pc.BackgroundColor3 = T.card2
    pc.BackgroundTransparency = 0.1; pc.BorderSizePixel = 0; pc.LayoutOrder = 1; pc.Parent = panel
    corner(pc, 9); stroke(pc, T.main, 0.8, 0.55)
    local pn = mkLabel(pc, "👤  " .. LP.DisplayName, Enum.Font.GothamBold, 11, WHITE); pn.Position = UDim2.fromOffset(10, 4); pn.Size = UDim2.new(1, -20, 0, 17)
    local pt = mkLabel(pc, "@" .. LP.Name, Enum.Font.Gotham, 8, T.muted); pt.Position = UDim2.fromOffset(28, 22); pt.Size = UDim2.new(1, -38, 0, 12)

    local getters, animRows = {}, {pc}
    for i, r in ipairs(rowsDef) do
        if r.div then
            local d = Instance.new("Frame"); d.Size = UDim2.new(1, 0, 0, 1); d.BackgroundColor3 = T.line
            d.BackgroundTransparency = 0.25; d.BorderSizePixel = 0; d.LayoutOrder = i + 1; d.Parent = panel
        else
            local row = Instance.new("Frame"); row.BackgroundColor3 = T.card; row.BackgroundTransparency = 0.18
            row.Size = UDim2.new(1, 0, 0, ROW_H); row.LayoutOrder = i + 1; row.Parent = panel; corner(row, 8)
            local ac = Instance.new("Frame"); ac.Size = UDim2.fromOffset(3, 16); ac.Position = UDim2.fromOffset(7, 6)
            ac.BackgroundColor3 = T.main; ac.BorderSizePixel = 0; ac.Parent = row; corner(ac, 2)
            local n = mkLabel(row, r.emoji .. "  " .. r.label, Enum.Font.GothamMedium, 9, T.text)
            n.Position = UDim2.fromOffset(17, 0); n.Size = UDim2.new(0.6, -17, 1, 0)
            local v = mkLabel(row, "--", Enum.Font.GothamBold, 10, WHITE, Enum.TextXAlignment.Right)
            v.AnchorPoint = Vector2.new(1, 0); v.Position = UDim2.new(1, -9, 0, 0); v.Size = UDim2.new(0.4, 0, 1, 0)
            getters[#getters + 1] = {v, r.get}
            animRows[#animRows + 1] = row
        end
    end

    local footer = Instance.new("Frame"); footer.BackgroundTransparency = 1; footer.Size = UDim2.new(1, 0, 0, 28); footer.LayoutOrder = 1000; footer.Parent = panel
    local status = mkLabel(footer, "● starting…", Enum.Font.GothamMedium, 8, ORANGE); status.Size = UDim2.new(1, -54, 1, 0)
    local stopBtn = mkButton(footer, "STOP", 42, 22, Color3.fromRGB(91, 34, 42), Color3.fromRGB(255, 175, 180), 8)
    stopBtn.AnchorPoint = Vector2.new(1, 0.5); stopBtn.Position = UDim2.new(1, 0, 0.5, 0)

    renderPanel = function()
        for _, g in ipairs(getters) do g[1].Text = g[2]() end
        local st, col = statusInfo()
        status.Text = "● " .. st; status.TextColor3 = col; dot.BackgroundColor3 = col
    end

    local isOpen, animated = false, false
    local function setOpen(v)
        isOpen = v
        if v then
            renderPanel()
            local sc = gui.AbsoluteSize; local hp = holder.AbsolutePosition
            local toLeft = hp.X + ICON + GAP + PANEL_W > sc.X
            local pH = math.max(panel.AbsoluteSize.Y, 300); local shiftUp = math.max(0, hp.Y + pH - sc.Y + 8)
            panel.AnchorPoint = toLeft and Vector2.new(1, 0) or Vector2.new(0, 0)
            panel.Position = UDim2.fromOffset(toLeft and -GAP or (ICON + GAP), -shiftUp)
            popScale.Scale = 0.82; panel.Visible = true
            TweenService:Create(popScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
            if not animated then
                animated = true
                for i, rf in ipairs(animRows) do
                    local orig = rf.BackgroundTransparency; rf.BackgroundTransparency = 1
                    task.delay((i - 1) * 0.055, function()
                        if gui.Parent then TweenService:Create(rf, TweenInfo.new(0.28), {BackgroundTransparency = orig}):Play() end
                    end)
                end
            end
        else
            local tw = TweenService:Create(popScale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.82})
            tw.Completed:Connect(function() if not isOpen then panel.Visible = false end end); tw:Play()
        end
    end

    closeBtn.Activated:Connect(function() setOpen(false) end)
    sendBtn.Activated:Connect(function()
        if sending then return end
        sendBtn.Text = "..."; task.spawn(function() sendNow(); sendBtn.Text = "SEND" end)
    end)
    stopBtn.Activated:Connect(function()
        AC.on = false
        if AC.thread then pcall(task.cancel, AC.thread) end
        if boostOn then revertBoost() end
        env.__BF_MAT_WEBHOOK = nil; gui:Destroy()
    end)

    local dragging, moved, dragStart, startPos = false, false, nil, nil
    icon.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false; dragStart, startPos = inp.Position, holder.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart; if d.Magnitude > 5 then moved = true end
            if moved then holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
        end
    end)
    icon.Activated:Connect(function() if moved then moved = false; return end; setOpen(not isOpen) end)

    if autoOpen then task.delay(2.4, function() if alive() and gui.Parent then setOpen(true) end end) end
    task.spawn(function() while alive() and gui.Parent do renderPanel(); task.wait(1) end end)
end

local function buildAutoClickerUI(gui)
    local ICON, AC_W, GAP = 64, 240, 7
    local logo = loadImg(CONFIG.FarmAvatar)

    local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(ICON, ICON); holder.Position = UDim2.new(1, 20, 0.5, -ICON / 2); holder.Parent = gui
    task.delay(2.0, function()
        if alive() and gui.Parent then
            TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(1, -ICON - 14, 0.5, -ICON / 2)}):Play()
        end
    end)

    local icon = Instance.new("TextButton"); icon.Size = UDim2.fromOffset(ICON, ICON)
    icon.BackgroundColor3 = T.card; icon.BorderSizePixel = 0; icon.AutoButtonColor = false
    icon.Font = Enum.Font.GothamBold; icon.Text = logo and "" or "🤖"; icon.TextSize = 22
    icon.TextColor3 = WHITE; icon.ZIndex = 2; icon.Parent = holder; corner(icon, ICON / 2)
    local iStroke = stroke(icon, T.main2, 1.8, 0.05)
    if logo then
        local ii = Instance.new("ImageLabel"); ii.BackgroundTransparency = 1
        ii.Size = UDim2.new(1, -6, 1, -6); ii.Position = UDim2.fromOffset(3, 3)
        ii.Image = logo; ii.ScaleType = Enum.ScaleType.Crop; ii.ZIndex = 2; ii.Parent = icon; corner(ii, ICON / 2)
    end
    local badge = Instance.new("Frame"); badge.AnchorPoint = Vector2.new(1, 0); badge.Position = UDim2.new(1, 2, 0, -2)
    badge.Size = UDim2.fromOffset(12, 12); badge.BackgroundColor3 = RED; badge.BorderSizePixel = 0; badge.ZIndex = 3; badge.Parent = icon
    corner(badge, 6); stroke(badge, T.deep, 1.5)
    task.spawn(function()
        local t = math.pi
        while alive() and gui.Parent do
            t = t + 0.06
            local b = (math.sin(t) + 1) / 2
            iStroke.Transparency = 0.5 - 0.45 * b
            iStroke.Color = Color3.fromHSV((T.hue + math.sin(t * 0.5) * T.span) % 1, 0.7 + 0.3 * b, 1)
            task.wait(0.03)
        end
    end)

    local panel = Instance.new("Frame"); panel.Size = UDim2.fromOffset(AC_W, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Position = UDim2.fromOffset(-(AC_W + GAP), 0); panel.BackgroundColor3 = T.deep; panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0; panel.Visible = false; panel.Parent = holder; corner(panel, 16)
    local pStroke = stroke(panel, T.main2, 1.5, 0.2)
    task.spawn(function()
        local t = 0
        while alive() and gui.Parent do
            t = t + 0.06
            pStroke.Color = Color3.fromHSV((T.hue + math.sin(t * 0.5) * T.span) % 1, 0.85, 1)
            pStroke.Transparency = 0.45 - 0.35 * ((math.sin(t) + 1) / 2)
            task.wait(0.03)
        end
    end)
    local pg = Instance.new("UIGradient")
    pg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.grad1), ColorSequenceKeypoint.new(1, T.grad3)}); pg.Rotation = 90; pg.Parent = panel
    local pScale = Instance.new("UIScale"); pScale.Parent = panel
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 12); pad.Parent = panel
    local ll = Instance.new("UIListLayout"); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0, 6); ll.Parent = panel

    local h = Instance.new("Frame"); h.BackgroundTransparency = 1; h.Size = UDim2.new(1, 0, 0, 28); h.LayoutOrder = 0; h.Parent = panel
    local ht = mkLabel(h, "🤖 AUTO CLICKER", Enum.Font.GothamBold, 12, WHITE); ht.Size = UDim2.new(1, -26, 1, 0)
    local closeBtn = mkButton(h, "×", 22, 22, T.card2, T.muted, 14)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5); closeBtn.Position = UDim2.new(1, 0, 0.5, 0)

    local tw = Instance.new("Frame"); tw.Size = UDim2.new(1, 0, 0, 44); tw.BackgroundColor3 = Color3.fromRGB(50, 12, 18)
    tw.BorderSizePixel = 0; tw.LayoutOrder = 1; tw.Parent = panel; corner(tw, 10)
    local tStroke = stroke(tw, RED, 1.5, 0.1)
    local tb = Instance.new("TextButton"); tb.Size = UDim2.new(1, 0, 1, 0); tb.BackgroundTransparency = 1
    tb.Font = Enum.Font.GothamBold; tb.TextSize = 14; tb.TextColor3 = RED; tb.Text = "🔴  AUTO CLICK: OFF"; tb.Parent = tw

    local MAXCPS = 200
    local cpsCard = Instance.new("Frame"); cpsCard.Size = UDim2.new(1, 0, 0, 44)
    cpsCard.BackgroundColor3 = T.card2; cpsCard.BackgroundTransparency = 0.15; cpsCard.BorderSizePixel = 0
    cpsCard.LayoutOrder = 2; cpsCard.Parent = panel; corner(cpsCard, 10); stroke(cpsCard, T.line, 1, 0.3)
    local cl = mkLabel(cpsCard, "⚡ CLICKS/SEC", Enum.Font.GothamBold, 9, T.text)
    cl.Position = UDim2.fromOffset(10, 0); cl.Size = UDim2.fromOffset(84, 44)
    local minus = mkButton(cpsCard, "−", 26, 26, T.card, T.muted, 16); minus.Position = UDim2.fromOffset(98, 9)
    local box = Instance.new("TextBox"); box.Size = UDim2.fromOffset(48, 28); box.Position = UDim2.fromOffset(127, 8)
    box.BackgroundColor3 = T.deep; box.BackgroundTransparency = 0.2; box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold; box.TextSize = 14; box.TextColor3 = WHITE
    box.PlaceholderText = "10"; box.PlaceholderColor3 = T.muted; box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center; box.Text = tostring(AC.cps); box.Parent = cpsCard
    corner(box, 7)
    local boxStroke = stroke(box, T.line, 1.2, 0.2)
    local plus = mkButton(cpsCard, "+", 26, 26, T.card, T.muted, 14); plus.Position = UDim2.fromOffset(178, 9)

    local chipRow = Instance.new("Frame"); chipRow.BackgroundTransparency = 1; chipRow.Size = UDim2.new(1, 0, 0, 26)
    chipRow.LayoutOrder = 3; chipRow.Parent = panel
    local chl = Instance.new("UIListLayout"); chl.FillDirection = Enum.FillDirection.Horizontal
    chl.Padding = UDim.new(0, 6); chl.SortOrder = Enum.SortOrder.LayoutOrder; chl.Parent = chipRow
    local chips = {}

    local function updateChips()
        for n, b in pairs(chips) do
            local active = (AC.cps == n)
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = active and T.main2 or T.card2}):Play()
            b.TextColor3 = active and WHITE or T.muted
        end
    end
    local function applyCps(n)
        AC.cps = math.clamp(math.floor(tonumber(n) or AC.cps), 1, MAXCPS)
        box.Text = tostring(AC.cps); updateChips()
    end
    for i, n in ipairs({5, 10, 20, 50}) do
        local b = mkButton(chipRow, tostring(n) .. "/s", 49, 26, T.card2, T.muted, 9)
        b.Size = UDim2.new(0.25, -4.5, 1, 0); b.LayoutOrder = i
        b.Activated:Connect(function() applyCps(n) end)
        chips[n] = b
    end

    box.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.15), {Color = T.main, Transparency = 0}):Play()
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local clean = (box.Text:gsub("%D", ""))
        if #clean > 3 then clean = clean:sub(1, 3) end
        if clean ~= box.Text then box.Text = clean end
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.15), {Color = T.line, Transparency = 0.2}):Play()
        applyCps(tonumber(box.Text) or AC.cps)
    end)
    minus.Activated:Connect(function() applyCps(AC.cps - 1) end)
    plus.Activated:Connect(function() applyCps(AC.cps + 1) end)
    updateChips()

    local posRow = Instance.new("Frame"); posRow.BackgroundTransparency = 1; posRow.Size = UDim2.new(1, 0, 0, 30); posRow.LayoutOrder = 4; posRow.Parent = panel
    local pl = mkLabel(posRow, "📍 Position", Enum.Font.GothamMedium, 9, T.muted); pl.Size = UDim2.fromOffset(60, 30)
    local pv = mkLabel(posRow, "not set", Enum.Font.Gotham, 9, T.text); pv.Position = UDim2.fromOffset(62, 0); pv.Size = UDim2.new(1, -122, 1, 0)
    local setBtn = mkButton(posRow, "SET", 54, 24, T.main2, WHITE, 9)
    setBtn.AnchorPoint = Vector2.new(1, 0.5); setBtn.Position = UDim2.new(1, 0, 0.5, 0)

    local hint = mkLabel(panel, "F = on/off  •  C = set pos at cursor", Enum.Font.GothamMedium, 8, T.muted, Enum.TextXAlignment.Center)
    hint.Size = UDim2.new(1, 0, 0, 14); hint.LayoutOrder = 5
    local msgLbl = mkLabel(panel, "", Enum.Font.GothamMedium, 8, ORANGE, Enum.TextXAlignment.Center)
    msgLbl.Size = UDim2.new(1, 0, 0, 12); msgLbl.LayoutOrder = 6

    -- on-screen marker for the click position
    local ind = Instance.new("Frame"); ind.AnchorPoint = Vector2.new(0.5, 0.5); ind.Size = UDim2.fromOffset(22, 22)
    ind.BackgroundColor3 = RED; ind.BackgroundTransparency = 0.45; ind.BorderSizePixel = 0; ind.Visible = false
    ind.ZIndex = 100; ind.Active = false; ind.Parent = gui; corner(ind, 11)
    local indStroke = stroke(ind, RED, 2, 0.1)
    task.spawn(function()
        local t = 0
        while alive() and gui.Parent do
            t = t + 0.08
            local s = 22 + math.sin(t) * 5
            ind.Size = UDim2.fromOffset(s, s)
            task.wait(0.03)
        end
    end)

    local function refresh()
        local on = AC.on
        tb.Text = on and "🟢  AUTO CLICK: ON" or "🔴  AUTO CLICK: OFF"
        tb.TextColor3 = on and GREEN or RED; tStroke.Color = on and GREEN or RED
        tw.BackgroundColor3 = on and Color3.fromRGB(15, 50, 25) or Color3.fromRGB(50, 12, 18)
        badge.BackgroundColor3 = on and GREEN or RED
        ind.BackgroundColor3 = on and GREEN or RED; indStroke.Color = on and GREEN or RED
        if AC.pos then
            pv.Text = ("(%d, %d)"):format(AC.pos.X, AC.pos.Y)
            ind.Position = UDim2.fromOffset(AC.pos.X, AC.pos.Y); ind.Visible = true
        else pv.Text = "not set"; ind.Visible = false end
        updateChips()
        if not box:IsFocused() then box.Text = tostring(AC.cps) end
        setBtn.Text = AC.picking and "TAP…" or "SET"
        msgLbl.Text = AC.picking and "tap / click where you want it to click" or (AC.msg or "")
        if renderPanel then renderPanel() end
    end
    acListeners[#acListeners + 1] = refresh

    tb.Activated:Connect(function() setAC(not AC.on) end)
    setBtn.Activated:Connect(function() AC.picking = not AC.picking; refresh() end)

    -- single input handler: F toggles, C sets at cursor, pick mode sets on next tap/click
    UIS.InputBegan:Connect(function(inp, gpe)
        if not alive() then return end
        if UIS:GetFocusedTextBox() then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            if inp.KeyCode == Enum.KeyCode.F then
                setAC(not AC.on)
            elseif inp.KeyCode == Enum.KeyCode.C then
                setACPos(UIS:GetMouseLocation())
            end
        elseif AC.picking and not gpe and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
            setACPos(pointerPos(inp))
        end
    end)

    local open = false
    local function setOpen(v)
        open = v
        if v then
            local toRight = holder.AbsolutePosition.X - AC_W - GAP < 0
            panel.Position = UDim2.fromOffset(toRight and (ICON + GAP) or -(AC_W + GAP), 0)
            pScale.Scale = 0.82; panel.Visible = true
            TweenService:Create(pScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        else
            local t2 = TweenService:Create(pScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.82})
            t2.Completed:Connect(function() if not open then panel.Visible = false end end); t2:Play()
        end
    end
    closeBtn.Activated:Connect(function() setOpen(false) end)

    local drag, mv, ds, sp = false, false, nil, nil
    icon.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag, mv = true, false; ds, sp = inp.Position, holder.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - ds; if d.Magnitude > 5 then mv = true end
            if mv then holder.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end
        end
    end)
    icon.Activated:Connect(function() if mv then mv = false; return end; setOpen(not open) end)
    refresh()
end

----------------------------------------------------------------------
-- BUILD UI
----------------------------------------------------------------------
while not splashDone do task.wait(0.1) end

if CONFIG.ShowPanel then
    local parent; pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    parent = parent or LP:WaitForChild("PlayerGui")
    local old = parent:FindFirstChild("BF_MercifulTracker"); if old then old:Destroy() end

    local gui = Instance.new("ScreenGui"); gui.Name = "BF_MercifulTracker"
    gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 1000000
    if not pcall(function() gui.Parent = parent end) then gui.Parent = LP:WaitForChild("PlayerGui") end

    buildIsland(gui)

    local rows = {}
    if MODE == "Leviathan" then
        for _, it in ipairs(ITEMS) do
            if it.key == "mythical" then rows[#rows + 1] = {div = true} end
            rows[#rows + 1] = {emoji = it.uiEmoji, label = it.label, get = function() return compact(values[it.key]) end}
        end
        buildPanel(gui, rows, false)
    else
        rows = {
            {emoji = "💰", label = "Beli",         get = function() return compact(values.beli) end},
            {emoji = "🧩", label = "Fragments",    get = function() return compact(values.fragments) end},
            {div = true},
            {emoji = "💰", label = "Total Earned", get = function() local _, b = farmStats(); return compact(b) end},
            {emoji = "🧩", label = "Total Earned", get = function() local _, _, f = farmStats(); return compact(f) end},
            {div = true},
            {emoji = "📈", label = "Beli / hr",    get = function() local e, b = farmStats(); return compact(ratePerHour(b, e)) end},
            {emoji = "📈", label = "Frags / hr",   get = function() local e, _, f = farmStats(); return compact(ratePerHour(f, e)) end},
            {div = true},
            {emoji = "⏱", label = "Time Elapsed",  get = function() return fmtTime(os.clock() - scriptStart) end},
            {emoji = "🤖", label = "Auto Clicker", get = function() return AC.on and "🟢 ON" or "🔴 OFF" end},
        }
        buildPanel(gui, rows, true)
        buildAutoClickerUI(gui)
    end
end

----------------------------------------------------------------------
-- LOOPS
----------------------------------------------------------------------
refreshStats()

task.spawn(function()
    while alive() do
        refreshStats()
        if MODE == "Leviathan" then readInventory() end
        if renderPanel then renderPanel() end
        task.wait(CONFIG.InventoryRefresh)
    end
end)

task.spawn(function()
    while alive() do
        if os.clock() >= nextPostAt then
            nextPostAt = nextPostAt + CONFIG.SendEvery
            if nextPostAt < os.clock() then nextPostAt = os.clock() + CONFIG.SendEvery end
            sendNow()
        end
        task.wait(0.5)
    end
end)

if MODE == "Leviathan" then
    task.spawn(function()
        local was = false
        while alive() do
            local ok, found, pos = pcall(getFrozenPosition)
            if ok then
                if found and not was then
                    was = true
                    if frozenOn then sendFrozenAlert(pos) end
                elseif not found then
                    was = false
                end
            end
            task.wait(2)
        end
    end)
end

print(("[BF Webhook] %s mode — posting every %ds.%s"):format(MODE, CONFIG.SendEvery,
    MODE == "Farm" and " F = auto clicker, C = set click pos." or " Frozen Dimension alerts enabled."))
