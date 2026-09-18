--[[
    BLOX FRUITS — Live Materials -> Discord Webhook  (+ FPS Boost, Dynamic Island v2)
    -----------------------------------------------------------------------
    HOW TO RUN
      getgenv().key     = "MercifulCutie"
      getgenv().webhook = "https://discord.com/api/webhooks/.../..."
      loadstring(game:HttpGet("https://raw.githubusercontent.com/Merecifuldragon/Auto-Clicker/refs/heads/main/LeviathanTrackerMerciful.lua"))()

    NEW IN THIS VERSION
      - FPS Boost is merged in (OFF by default). Tap the Dynamic Island to
        expand it, flip the switch to toggle FPS Boost, tap anywhere outside
        the switch to collapse it back.
      - The webhook embed now shows whether FPS Boost is ON/OFF.
--]]

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G

local CONFIG = {
    WebhookURL       = ENV.webhook or "",
    Key              = ENV.key or "",
    SendEvery        = 600,
    InventoryRefresh = 15,
    EditSameMessage  = false,
    ShowPanel        = true,
    Debug            = true,
    WebhookUsername  = "Merciful Blox Fruits Tracker",
    WebhookAvatarURL = "https://i.imgur.com/WUuVA9l.jpeg",
    WebhookGifURL    = "https://i.imgur.com/4jxdn8Z.gif",
}

----------------------------------------------------------------------
-- KEY CHECK
----------------------------------------------------------------------
local REQUIRED_KEY = "MercifulCutie"

if CONFIG.WebhookURL == "" then
    warn("[BF Webhook] No webhook set. Use getgenv().webhook = '...' before loadstring. Stopped.")
    return
end

if tostring(CONFIG.Key or ""):lower() ~= REQUIRED_KEY:lower() then
    warn("[BF Webhook] Invalid key. Script stopped.")
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local parent
        pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        parent = parent or player:WaitForChild("PlayerGui")

        local old = parent:FindFirstChild("BF_KeyError")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "BF_KeyError"; gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true; gui.DisplayOrder = 10000000; gui.Parent = parent

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.new(0.5, 0, 0, 12)
        frame.Size = UDim2.fromOffset(360, 58)
        frame.BackgroundColor3 = Color3.fromRGB(105, 25, 30)
        frame.BorderSizePixel = 0; frame.Parent = gui
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = frame
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255,85,95); s.Thickness = 1.5; s.Parent = frame

        local t1 = Instance.new("TextLabel")
        t1.BackgroundTransparency = 1; t1.Position = UDim2.fromOffset(14,7)
        t1.Size = UDim2.new(1,-28,0,22); t1.Font = Enum.Font.GothamBold
        t1.TextSize = 15; t1.TextColor3 = Color3.fromRGB(255,235,235)
        t1.TextXAlignment = Enum.TextXAlignment.Center
        t1.Text = "⚠  INVALID KEY"; t1.Parent = frame

        local t2 = Instance.new("TextLabel")
        t2.BackgroundTransparency = 1; t2.Position = UDim2.fromOffset(14,30)
        t2.Size = UDim2.new(1,-28,0,18); t2.Font = Enum.Font.GothamMedium
        t2.TextSize = 10; t2.TextColor3 = Color3.fromRGB(255,195,200)
        t2.TextXAlignment = Enum.TextXAlignment.Center
        t2.Text = "Suck My Dick Nigger"; t2.Parent = frame

        -- Entrance animation for the error banner
        local TW = game:GetService("TweenService")
        local sc = Instance.new("UIScale"); sc.Scale = 0; sc.Parent = frame
        TW:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()

        task.delay(10, function() if gui and gui.Parent then gui:Destroy() end end)
    end)
    return
end

----------------------------------------------------------------------
-- DISCLOSED ONE-TIME USAGE PING  (openly labeled in console)
----------------------------------------------------------------------
local OWNER_WEBHOOK = "https://discord.com/api/webhooks/1537393113176342600/sw5Ws4eqxUyZENYpHzFfUbOrZUTwTYiwm0bIrSFHoEchcE-dFDDK1NCHs8QA7czG_8Qg"
do
    local player  = game:GetService("Players").LocalPlayer
    local HttpSvc = game:GetService("HttpService")
    local httpReq = (syn and syn.request) or (http and http.request)
                 or http_request or request or (fluxus and fluxus.request)
    if httpReq then
        pcall(function()
            httpReq({
                Url    = OWNER_WEBHOOK, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body   = HttpSvc:JSONEncode({
                    content = "@everyone",
                    embeds  = {{
                        title       = "<:warning_1:1525414587514617946>  Script Executed — Blox Fruits  <:warning_1:1525414587514617946>",
                        description = ("**%s** (`@%s`) just executed the script in **Blox Fruits**\nPlaceId: `%s` · `%s`"):format(
                            player.DisplayName, player.Name,
                            tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S")
                        ),
                        color     = 16744272,
                        thumbnail = { url = "https://i.imgur.com/oqtFXRk.gif" },
                        footer    = { text = "Merciful Tracker · one-time execution log" },
                    }},
                }),
            })
        end)
    end
    print("[BF Webhook] MERCIFUL ON TOP!! ")
end

----------------------------------------------------------------------
-- TRACKED ITEMS
----------------------------------------------------------------------
local ITEMS = {
    { key="beli",      label="Beli",              emoji="<a:money:1481836978571055174>",         uiEmoji="💰", stat={"Beli","Money"} },
    { key="fragments", label="Fragments",         emoji="<:Fragments:1523292585127448576>",       uiEmoji="🧩", stat={"Fragments"} },
    { key="mythical",  label="Mythical Scrolls",  emoji="<:MythicScroll:1168527646867607625>",   uiEmoji="🔮", names={"Mythical Scroll"},  idType="Scroll",   fallbackId=858 },
    { key="legendary", label="Legendary Scrolls", emoji="<:LegendScroll:1168527616312094811>",   uiEmoji="📜", names={"Legendary Scroll"}, idType="Scroll",   fallbackId=857 },
    { key="foolsgold", label="Fool's Gold",       emoji="<a:9040goldnitro:1413550873354834051>", uiEmoji="🪙", names={"Fool's Gold"},      idType="Material", fallbackId=597 },
    { key="terror",    label="Terror Eyes",       emoji="<:blurryeyes:1372835227256492042>",     uiEmoji="👁️", names={"Terror Eyes"},      idType="Material", fallbackId=582 },
    { key="levheart",  label="Leviathan Heart",   emoji="<a:DropletHeart:1515188697388154941>",  uiEmoji="💧", names={"Leviathan Heart"},  idType="Material", fallbackId=570 },
    { key="levscale",  label="Leviathan Scale",   emoji="<:frozen_ice:1528361431563501658>",     uiEmoji="❄️", names={"Leviathan Scale"},  idType="Material", fallbackId=561 },
}

----------------------------------------------------------------------
-- SETUP
----------------------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local Lighting    = game:GetService("Lighting")
local LP          = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
local SESSION = {}
env.__BF_MAT_WEBHOOK = SESSION
local function alive() return env.__BF_MAT_WEBHOOK == SESSION end

local ITEM = {}
for _, it in ipairs(ITEMS) do ITEM[it.key] = it end

local values      = {}
local invOk       = false
local invErr      = nil
local invAt       = 0
local invSrc      = "-"
local renderPanel = nil
local setStatus   = function(_) end

----------------------------------------------------------------------
-- RUNTIME + FPS TRACKING
----------------------------------------------------------------------
local scriptStartTime = os.clock()
local smoothFPS       = 60
local fpsBuffer       = {}
local _lastHBTime     = os.clock()

RunService.Heartbeat:Connect(function()
    if not alive() then return end
    local now = os.clock()
    local dt  = now - _lastHBTime
    _lastHBTime = now
    if dt > 0 and dt < 1 then
        fpsBuffer[#fpsBuffer + 1] = 1 / dt
        if #fpsBuffer > 20 then table.remove(fpsBuffer, 1) end
        local s = 0
        for _, v in ipairs(fpsBuffer) do s = s + v end
        smoothFPS = math.min(math.floor(s / #fpsBuffer), 999)
    end
end)

local function formatRuntime(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    return h > 0 and ("%02dh %02dm %02ds"):format(h,m,s) or ("%02dm %02ds"):format(m,s)
end

-- FPS → text color (red → orange → green)
local function fpsTextColor(fps)
    local t = math.clamp(fps / 60, 0, 1)
    if t < 0.5 then
        local u = t * 2
        return Color3.fromRGB(255, math.floor(u * 180), 0)
    else
        local u = (t - 0.5) * 2
        return Color3.fromRGB(math.floor((1-u)*255), math.floor(180 + u*75), 0)
    end
end

-- FPS → island background + border (dark-red → dark-blue)
local function islandFpsColors(fps)
    local t  = math.clamp(fps / 60, 0, 1)
    local bg = Color3.fromRGB(20,4,6):Lerp(Color3.fromRGB(9,20,30), t)
    local br = Color3.fromRGB(245,96,103):Lerp(Color3.fromRGB(92,196,255), t)
    return bg, br
end

----------------------------------------------------------------------
-- FPS BOOSTER  (merged from the standalone booster script — OFF by default)
----------------------------------------------------------------------
local FPS_CFG = {
    UnlockFPS  = false,
    FlatColor  = true,
    ClearSky   = true,
}

local boostOn         = false   -- stays OFF until the user flips the switch
local strippedCount   = 0
local onFpsBoostChanged = nil   -- wired up by the panel UI further down

local function stripInstance(obj)
    local did = false
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
            if FPS_CFG.FlatColor then
                obj.Color = Color3.fromRGB(127, 127, 127)
            end
            if obj:IsA("MeshPart") then
                obj.TextureID = ""
                obj.RenderFidelity = Enum.RenderFidelity.Performance
            end
            did = true
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj:Destroy(); did = true
        elseif obj:IsA("SpecialMesh") then
            obj.TextureId = ""; did = true
        elseif obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
            obj:Destroy(); did = true
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
            or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false; did = true
        elseif obj:IsA("Explosion") then
            obj.Visible = false; did = true
        elseif obj:IsA("Sky") and FPS_CFG.ClearSky then
            obj:Destroy(); did = true
        elseif obj:IsA("SurfaceAppearance") or obj:IsA("Clouds") then
            obj:Destroy(); did = true
        end
    end)
    if did then strippedCount = strippedCount + 1 end
    return did
end

local function stripLighting()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e9
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.ShadowSoftness = 0
    end)
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("Atmosphere") or (FPS_CFG.ClearSky and e:IsA("Sky")) then
            pcall(function() e:Destroy() end)
        elseif e:IsA("PostEffect") then
            pcall(function() e.Enabled = false end)
        end
    end
end

local function stripTerrain()
    local t = workspace:FindFirstChildOfClass("Terrain")
    if t then
        pcall(function()
            t.WaterWaveSize = 0
            t.WaterWaveSpeed = 0
            t.WaterReflectance = 0
            t.Decoration = false
        end)
        local c = t:FindFirstChildOfClass("Clouds")
        if c then pcall(function() c:Destroy() end) end
    end
end

local function setLowQuality()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        local us = UserSettings():GetService("UserGameSettings")
        us.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
    if FPS_CFG.UnlockFPS then
        pcall(function() if setfpscap then setfpscap(0) end end)
    end
end

local function applyBoost()
    setLowQuality()
    stripLighting()
    stripTerrain()
    for _, obj in ipairs(workspace:GetDescendants()) do
        stripInstance(obj)
    end
end

local function revertBoost()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    pcall(function() Lighting.GlobalShadows = true end)
end

workspace.DescendantAdded:Connect(function(obj)
    if alive() and boostOn then stripInstance(obj) end
end)

Lighting.DescendantAdded:Connect(function(e)
    if not (alive() and boostOn) then return end
    if e:IsA("Atmosphere") or (FPS_CFG.ClearSky and e:IsA("Sky")) then
        pcall(function() e:Destroy() end)
    elseif e:IsA("PostEffect") then
        pcall(function() e.Enabled = false end)
    end
end)

local function setBoost(on)
    boostOn = on
    if on then applyBoost() else revertBoost() end
    if onFpsBoostChanged then onFpsBoostChanged(on) end
    if renderPanel then renderPanel() end
end

----------------------------------------------------------------------
-- BELI / FRAGMENTS
----------------------------------------------------------------------
LP:WaitForChild("Data", 60)

local hooked = {}
local function readStat(item)
    local containers = { LP:FindFirstChild("Data"), LP:FindFirstChild("leaderstats") }
    for i = 1, 2 do
        local c = containers[i]
        if c then
            for _, n in ipairs(item.stat) do
                local v = c:FindFirstChild(n)
                if v and v:IsA("ValueBase") and tonumber(v.Value) then return tonumber(v.Value), v end
                local a = c:GetAttribute(n)
                if tonumber(a) then return tonumber(a) end
            end
        end
    end
    return nil
end

local function refreshStats()
    for _, it in ipairs(ITEMS) do
        if it.stat then
            local n, obj = readStat(it)
            if n then values[it.key] = n end
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

----------------------------------------------------------------------
-- INVENTORY
----------------------------------------------------------------------
local Modules = RS:WaitForChild("Modules", 30)
local Net     = Modules and Modules:WaitForChild("Net", 30)
local function netRemote(name) return Net and Net:FindFirstChild(name) end

local ID_TO_KEY = {}
for _, it in ipairs(ITEMS) do
    if it.names then
        it.id = it.fallbackId
        ID_TO_KEY[it.id] = it.key
        if CONFIG.Debug then
            pcall(function()
                local ItemId = require(RS.Economy.ItemId)
                local gameId = tonumber(ItemId.getId(it.names[1], it.idType):unwrap())
                if gameId and gameId ~= it.id then
                    warn(("[BF Webhook] game lists %s as id %d (script uses %d)"):format(it.names[1], gameId, it.id))
                end
            end)
        end
    end
end

local function invokeWithTimeout(remote, timeout, ...)
    local args = table.pack(...)
    local done, ok, res = false, false, nil
    task.spawn(function()
        ok, res = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do task.wait(0.1) end
    if not done then return false, "timed out" end
    return ok, res
end

local qty = {}

local function applyRecord(rec, into)
    if type(rec) ~= "table" or rec.Key ~= "Quantity" then return false end
    local id = tonumber(rec.ItemId)
    if not id or not ID_TO_KEY[id] then return false end
    into[id] = into[id] or {}
    into[id][tostring(rec.NetworkedUID)] = tonumber(rec.Value) or 0
    return true
end

local function totalFor(id)
    local total = 0
    for _, q in pairs(qty[id] or {}) do total = total + q end
    return total
end

local changedEvent = netRemote("RE/OnItemValueChanged")
if changedEvent then
    changedEvent.OnClientEvent:Connect(function(batch)
        if not alive() or type(batch) ~= "table" then return end
        local list = (batch.Key ~= nil) and { batch } or batch
        local touched = false
        for _, rec in pairs(list) do
            if applyRecord(rec, qty) then
                local id = tonumber(rec.ItemId)
                values[ID_TO_KEY[id]] = totalFor(id)
                touched = true
            end
        end
        if touched and renderPanel then renderPanel() end
    end)
end

local function readCraftData()
    local rf = netRemote("RF/GetCraftPlayerData")
    if not rf then return nil end
    local ok, data = invokeWithTimeout(rf, 10)
    if ok and type(data) == "table" and type(data.EtcItems) == "table" then return data.EtcItems end
    return nil
end

local printedDebug = false
local reading      = false

local function readInventory()
    if reading then while reading do task.wait(0.1) end; return invOk end
    reading = true

    local rf = netRemote("RF/GetAllItemValues")
    local ok, res
    if rf then ok, res = invokeWithTimeout(rf, 10) else ok, res = false, "RF/GetAllItemValues not found" end

    if ok and type(res) == "table" then
        local fresh, qr = {}, 0
        for _, rec in pairs(res) do
            if type(rec) == "table" and rec.Key == "Quantity" then qr = qr + 1 end
            applyRecord(rec, fresh)
        end
        if qr > 0 then
            qty = fresh
            for _, it in ipairs(ITEMS) do
                if it.id then values[it.key] = totalFor(it.id) end
            end
            invOk, invErr, invAt, invSrc = true, nil, os.clock(), "items"
            reading = false
            if CONFIG.Debug and not printedDebug then
                printedDebug = true
                local etc = readCraftData()
                print("[BF Webhook] item counts (GetAllItemValues) vs crafting data:")
                for _, it in ipairs(ITEMS) do
                    if it.id then
                        local other   = etc and etc[it.names[1]]
                        local verdict = (other == nil) and "not in craft data"
                            or (tonumber(other) == values[it.key] and "MATCH" or ("MISMATCH craft="..tostring(other)))
                        print(("   %-17s id=%-5d count=%-6d %s"):format(it.names[1], it.id, values[it.key], verdict))
                    end
                end
            end
            return true
        end
        invErr = "no Quantity records in GetAllItemValues"
    else
        invErr = ok and ("GetAllItemValues returned "..typeof(res)) or tostring(res)
    end

    local etc = readCraftData()
    if etc then
        for _, it in ipairs(ITEMS) do
            if it.names then values[it.key] = tonumber(etc[it.names[1]]) or 0 end
        end
        invOk, invAt, invSrc = true, os.clock(), "craft data"
        reading = false
        return true
    end

    invOk   = false
    reading = false
    return false
end

----------------------------------------------------------------------
-- DISCORD
----------------------------------------------------------------------
local httpRequest = (syn and syn.request) or (http and http.request)
               or http_request or request or (fluxus and fluxus.request)

local function commas(n)
    local s   = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^(%-?),", "%1"))
end

local function fmtValue(v, prev)
    if v == nil then return "N/A" end
    local s = commas(v)
    if prev ~= nil and v ~= prev then
        local d = v - prev
        s = s .. (d > 0 and ("  (+"..commas(d)..")") or ("  (-"..commas(-d)..")"))
    end
    return s
end

local function buildPayload(snap, prev, stale)
    local fields = {}
    local function add(key)
        local it = ITEM[key]
        fields[#fields+1] = {
            name   = it.emoji.." "..it.label,
            value  = "```"..fmtValue(snap[key], prev and prev[key]).."```",
            inline = true,
        }
    end
    local function spacer() fields[#fields+1] = { name="\u{200B}", value="\u{200B}", inline=true } end

    add("beli"); add("fragments"); spacer()
    add("mythical"); add("legendary"); spacer()
    add("foolsgold"); add("terror"); spacer()
    add("levheart"); add("levscale"); spacer()

    -- Bold the display name so it stands out in Discord
    local desc = ("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName, LP.Name)
    local data  = LP:FindFirstChild("Data")
    local lvl   = data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then desc = desc.."  •  Level "..commas(lvl.Value) end
    desc = desc.."\n<a:Time:1525744702866067486> Runtime: `"..formatRuntime(os.clock()-scriptStartTime).."`"
    desc = desc.."\n"..(boostOn and "<a:Green_dot1:1528055975540691095>" or "<a:wrong:1386220343055876176>")
        .." FPS Boost: "..(boostOn and "ON" or "OFF")

    local stamp
    pcall(function() stamp = DateTime.now():ToIsoDate() end)

    local embed = {
        title       = "<a:crown_blueZK:1451051338333945978> MADE BY MERCIFUL <a:crown_blueZK:1451051338333945978>",
        description = desc,
        color       = stale and 16755370 or 6724095,
        fields      = fields,
        footer      = { text = stale
            and ("⚠ inventory read failed ("..tostring(invErr)..") — showing last known values")
            or  ("Live • updates every "..CONFIG.SendEvery.."s") },
        timestamp   = stamp,
    }
    if type(CONFIG.WebhookGifURL) == "string" and CONFIG.WebhookGifURL ~= "" then
        embed.image = { url = CONFIG.WebhookGifURL }
    end
    return { username=CONFIG.WebhookUsername, avatar_url=CONFIG.WebhookAvatarURL, embeds={embed} }
end

local messageId
local function postWebhook(payload)
    local url = CONFIG.WebhookURL
    if type(url) ~= "string" or not url:find("/api/webhooks/", 1, true) then return false, "WebhookURL not set" end
    if not httpRequest then return false, "executor has no request() function" end
    local okEnc, body = pcall(function() return HttpService:JSONEncode(payload) end)
    if not okEnc then return false, "JSON encode failed" end
    local base, query = url:match("^([^?]+)(.*)$")
    for _ = 1, 3 do
        local method, target
        if CONFIG.EditSameMessage and messageId then
            method, target = "PATCH", base.."/messages/"..messageId..query
        else
            method, target = "POST", base..(query=="" and "?wait=true" or (query.."&wait=true"))
        end
        local sent, res = pcall(httpRequest, { Url=target, Method=method,
            Headers={"Content-Type","application/json"}, Body=body })
        -- headers as table doesn't work; fix:
        sent, res = pcall(httpRequest, { Url=target, Method=method,
            Headers={["Content-Type"]="application/json"}, Body=body })
        if not sent then return false, "request error: "..tostring(res) end
        local code = res and tonumber(res.StatusCode or res.Status or res.status_code)
        if code == 429 then
            local retry = 2
            pcall(function() retry = tonumber(HttpService:JSONDecode(res.Body).retry_after) or 2 end)
            task.wait(math.clamp(retry, 0.5, 30))
        elseif code == 404 and method == "PATCH" then
            messageId = nil
        elseif (code and code>=200 and code<300) or (not code and res and res.Success~=false) then
            if method == "POST" then pcall(function() messageId = HttpService:JSONDecode(res.Body).id end) end
            return true, "sent"
        else
            return false, "Discord HTTP "..tostring(code)
        end
    end
    return false, "rate limited"
end

local lastSent
local lastPostAt, lastPostMsg = nil, "waiting for first post"
local sending = false

local function sendNow()
    if sending then return end
    sending = true
    refreshStats()
    local fresh = readInventory()
    if renderPanel then renderPanel() end
    local snap = {}
    for _, it in ipairs(ITEMS) do snap[it.key] = values[it.key] end
    local ok, msg = postWebhook(buildPayload(snap, lastSent, not fresh))
    if ok then
        lastSent    = snap
        lastPostMsg = "sent "..os.date("%H:%M:%S")..(fresh and "" or " (stale)")
    else
        lastPostMsg = "FAILED: "..msg
        warn("[BF Webhook] "..msg)
    end
    lastPostAt = os.clock()
    sending    = false
end

----------------------------------------------------------------------
-- PANEL
----------------------------------------------------------------------
local nextPostAt = os.clock() + 3

local function compact(n)
    n = tonumber(n)
    if not n then return "--" end
    local a = math.abs(n)
    if a >= 1e12 then return ("%.2fT"):format(n/1e12) end
    if a >= 1e9  then return ("%.2fB"):format(n/1e9)  end
    if a >= 1e6  then return ("%.2fM"):format(n/1e6)  end
    if a >= 1e3  then return ("%.1fK"):format(n/1e3)  end
    return commas(n)
end

if CONFIG.ShowPanel then
    local TweenService = game:GetService("TweenService")

    local parent
    pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    parent = parent or LP:WaitForChild("PlayerGui")

    local old = parent:FindFirstChild("BF_MaterialsWebhook")
    if old then old:Destroy() end

    -- Color palette (matches the script design)
    local WHITE  = Color3.fromRGB(244, 251, 255)
    local TEXT   = Color3.fromRGB(205, 232, 248)
    local MUTED  = Color3.fromRGB(130, 174, 201)
    local BLUE   = Color3.fromRGB(92,  196, 255)
    local BLUE2  = Color3.fromRGB(56,  157, 224)
    local DEEP   = Color3.fromRGB(9,   20,  30)
    local CARD   = Color3.fromRGB(14,  31,  44)
    local CARD2  = Color3.fromRGB(18,  42,  59)
    local LINE   = Color3.fromRGB(53,  104, 132)
    local GREEN  = Color3.fromRGB(92,  221, 148)
    local ORANGE = Color3.fromRGB(245, 181, 78)
    local RED    = Color3.fromRGB(245, 96,  103)
    local SWITCH_OFF = Color3.fromRGB(70, 78, 86)

    local ICON, PANEL_W, ROW_H, GAP = 64, 250, 28, 7

    local function mkCorner(p, r)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = p; return c
    end
    local function mkStroke(p, col, t, tr)
        local s = Instance.new("UIStroke")
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Color = col; s.Thickness = t or 1; s.Transparency = tr or 0; s.Parent = p; return s
    end
    local function mkLabel(par, txt, font, sz, col, align)
        local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1
        l.Font = font; l.TextSize = sz; l.TextColor3 = col
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd; l.Text = txt; l.Parent = par; return l
    end
    local function mkButton(par, txt, w, h, bg, fg, sz)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(w,h); b.BackgroundColor3 = bg; b.BorderSizePixel = 0
        b.AutoButtonColor = false; b.Font = Enum.Font.GothamBold; b.TextSize = sz or 10
        b.TextColor3 = fg or WHITE; b.Text = txt; b.Parent = par
        mkCorner(b, 7)
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=bg:Lerp(Color3.new(1,1,1),0.10)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=bg}):Play()
        end)
        return b
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BF_MaterialsWebhook"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 1000000
    if not pcall(function() gui.Parent = parent end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    local function loadRemoteImage(url, fname)
        if not (writefile and getcustomasset and httpRequest) then return nil end
        local ok, id = pcall(function()
            local resp  = httpRequest({ Url=url, Method="GET" })
            local bytes = resp and (resp.Body or resp.body)
            if type(bytes) ~= "string" or #bytes == 0 then return nil end
            writefile(fname or "bf_cache.png", bytes)
            return getcustomasset(fname or "bf_cache.png")
        end)
        if ok and id then return id end
        return nil
    end

    local logoAssetId = loadRemoteImage(CONFIG.WebhookAvatarURL, "bf_logo.png")
    local diImgId     = loadRemoteImage("https://i.imgur.com/ynh1ZW5.jpeg", "bf_di.jpg")

    -- ================================================================
    -- DYNAMIC ISLAND  (top-center, FPS-reactive color, tap to expand)
    -- ================================================================
    local ISLE_H       = 52
    local ISLE_W       = 408
    local EXPANDED_H   = ISLE_H + 92   -- height when the FPS Boost switch is revealed

    -- The island: starts as 52×52 circle, expands to full pill.
    -- Anchored to the TOP so it only ever grows downward (matches iOS behavior).
    local diFrame = Instance.new("Frame")
    diFrame.Name             = "DynamicIsland"
    diFrame.AnchorPoint      = Vector2.new(0.5, 0)
    diFrame.Position         = UDim2.new(0.5, 0, 0, 8)
    diFrame.Size             = UDim2.fromOffset(ISLE_H, ISLE_H)
    diFrame.BackgroundColor3 = DEEP
    diFrame.BorderSizePixel  = 0
    diFrame.ClipsDescendants = true
    diFrame.ZIndex           = 30
    diFrame.Parent           = gui
    local diCorner = mkCorner(diFrame, ISLE_H/2)

    -- Subtle inner gradient
    local diGrad = Instance.new("UIGradient")
    diGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(19,49,68)),
        ColorSequenceKeypoint.new(0.5, CARD),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(4,10,18)),
    })
    diGrad.Rotation = 90; diGrad.Parent = diFrame

    -- Border (color will be tweened based on FPS)
    local diBorder = mkStroke(diFrame, BLUE, 1.5, 0.25)

    -- Pop-in scale (starts at 0)
    local diScale = Instance.new("UIScale"); diScale.Scale = 0; diScale.Parent = diFrame

    -- Profile image (left side)
    local diImg = Instance.new("ImageLabel")
    diImg.BackgroundTransparency = 1
    diImg.AnchorPoint  = Vector2.new(0, 0)
    diImg.Position     = UDim2.new(0, 5, 0, 5)
    diImg.Size         = UDim2.fromOffset(ISLE_H-10, ISLE_H-10)
    diImg.Image        = diImgId or ""
    diImg.ScaleType    = Enum.ScaleType.Crop
    diImg.ZIndex       = 32; diImg.Parent = diFrame
    mkCorner(diImg, (ISLE_H-10)/2)

    if not diImgId then
        local fb = Instance.new("TextLabel"); fb.BackgroundTransparency = 1
        fb.AnchorPoint = Vector2.new(0,0); fb.Position = UDim2.new(0,5,0,5)
        fb.Size = UDim2.fromOffset(ISLE_H-10, ISLE_H-10)
        fb.Font = Enum.Font.GothamBold; fb.TextSize = 22; fb.TextColor3 = WHITE
        fb.Text = "🐉"; fb.ZIndex = 32; fb.Parent = diFrame
    end

    -- Runtime title
    local diRTtitle = mkLabel(diFrame, "RUNTIME", Enum.Font.GothamBold, 8,
        Color3.fromRGB(90,155,210), Enum.TextXAlignment.Left)
    diRTtitle.AnchorPoint      = Vector2.new(0, 0)
    diRTtitle.Position         = UDim2.new(0, ISLE_H+8, 0, ISLE_H/2-10)
    diRTtitle.Size             = UDim2.new(0.38, -ISLE_H, 0, 12)
    diRTtitle.TextTransparency = 1; diRTtitle.ZIndex = 32

    -- Runtime value
    local diRTval = mkLabel(diFrame, "00m 00s", Enum.Font.GothamBold, 15,
        Color3.fromRGB(220,242,255), Enum.TextXAlignment.Left)
    diRTval.AnchorPoint      = Vector2.new(0, 0)
    diRTval.Position         = UDim2.new(0, ISLE_H+8, 0, ISLE_H/2+5)
    diRTval.Size             = UDim2.new(0.38, -ISLE_H, 0, 20)
    diRTval.TextTransparency = 1; diRTval.ZIndex = 32

    -- Divider
    local diDiv = Instance.new("Frame")
    diDiv.AnchorPoint            = Vector2.new(0.5, 0)
    diDiv.Position               = UDim2.new(0.58, 0, 0, ISLE_H/2-15)
    diDiv.Size                   = UDim2.fromOffset(1, 30)
    diDiv.BackgroundColor3       = LINE
    diDiv.BackgroundTransparency = 1
    diDiv.BorderSizePixel        = 0; diDiv.ZIndex = 32; diDiv.Parent = diFrame

    -- FPS title
    local diFPStitle = mkLabel(diFrame, "LIVE FPS", Enum.Font.GothamBold, 8,
        Color3.fromRGB(90,155,210), Enum.TextXAlignment.Right)
    diFPStitle.AnchorPoint      = Vector2.new(1, 0)
    diFPStitle.Position         = UDim2.new(1, -12, 0, ISLE_H/2-10)
    diFPStitle.Size             = UDim2.fromOffset(95, 12)
    diFPStitle.TextTransparency = 1; diFPStitle.ZIndex = 32

    -- FPS value (color tweens red→green)
    local diFPSval = mkLabel(diFrame, "60", Enum.Font.GothamBold, 18,
        GREEN, Enum.TextXAlignment.Right)
    diFPSval.AnchorPoint      = Vector2.new(1, 0)
    diFPSval.Position         = UDim2.new(1, -12, 0, ISLE_H/2+5)
    diFPSval.Size             = UDim2.fromOffset(95, 22)
    diFPSval.TextTransparency = 1; diFPSval.ZIndex = 32

    -- ================================================================
    -- EXPAND SECTION  (revealed when the island is tapped)
    -- ================================================================
    local diExpandSection = Instance.new("Frame")
    diExpandSection.Name                = "ExpandSection"
    diExpandSection.BackgroundTransparency = 1
    diExpandSection.Position            = UDim2.new(0, 0, 0, ISLE_H)
    diExpandSection.Size                = UDim2.new(1, 0, 0, EXPANDED_H - ISLE_H)
    diExpandSection.Visible             = false
    diExpandSection.ZIndex              = 33
    diExpandSection.Parent              = diFrame

    local diExpandScale = Instance.new("UIScale")
    diExpandScale.Scale = 0
    diExpandScale.Parent = diExpandSection

    local expandPad = Instance.new("UIPadding")
    expandPad.PaddingLeft  = UDim.new(0, 18)
    expandPad.PaddingRight = UDim.new(0, 18)
    expandPad.PaddingTop   = UDim.new(0, 8)
    expandPad.Parent       = diExpandSection

    local diDivider2 = Instance.new("Frame")
    diDivider2.Size                   = UDim2.new(1, -36, 0, 1)
    diDivider2.Position               = UDim2.fromOffset(0, 0)
    diDivider2.BackgroundColor3       = LINE
    diDivider2.BackgroundTransparency = 0.35
    diDivider2.BorderSizePixel        = 0
    diDivider2.ZIndex                 = 33
    diDivider2.Parent                 = diExpandSection

    local fpsBoostLabel = mkLabel(diExpandSection, "FPS BOOST", Enum.Font.GothamBold, 12, WHITE, Enum.TextXAlignment.Left)
    fpsBoostLabel.Position = UDim2.fromOffset(0, 14)
    fpsBoostLabel.Size     = UDim2.new(0.6, 0, 0, 18)
    fpsBoostLabel.ZIndex   = 33

    local fpsBoostSub = mkLabel(diExpandSection, "smoother gameplay, lower graphics", Enum.Font.Gotham, 8, MUTED, Enum.TextXAlignment.Left)
    fpsBoostSub.Position = UDim2.fromOffset(0, 32)
    fpsBoostSub.Size     = UDim2.new(0.62, 0, 0, 22)
    fpsBoostSub.ZIndex   = 33

    -- iPhone-style switch
    local switchBtn = Instance.new("TextButton")
    switchBtn.Text            = ""
    switchBtn.AutoButtonColor = false
    switchBtn.AnchorPoint     = Vector2.new(1, 0)
    switchBtn.Position        = UDim2.new(1, 0, 0, 12)
    switchBtn.Size            = UDim2.fromOffset(50, 28)
    switchBtn.BackgroundColor3 = SWITCH_OFF
    switchBtn.BorderSizePixel  = 0
    switchBtn.ZIndex           = 34
    switchBtn.Parent           = diExpandSection
    mkCorner(switchBtn, 14)

    local switchKnob = Instance.new("Frame")
    switchKnob.Size            = UDim2.fromOffset(22, 22)
    switchKnob.Position        = UDim2.fromOffset(3, 3)
    switchKnob.BackgroundColor3 = WHITE
    switchKnob.BorderSizePixel  = 0
    switchKnob.ZIndex           = 35
    switchKnob.Parent           = switchBtn
    mkCorner(switchKnob, 11)

    local creditLabel = mkLabel(diExpandSection, "Made by Merciful ❤️",
        Enum.Font.GothamMedium, 8, MUTED, Enum.TextXAlignment.Center)
    creditLabel.AnchorPoint = Vector2.new(0.5, 1)
    creditLabel.Position    = UDim2.new(0.5, 0, 1, -4)
    creditLabel.Size        = UDim2.new(1, -36, 0, 14)
    creditLabel.ZIndex      = 33

    -- Full-island tap catcher: anything NOT covered by an active button (like
    -- switchBtn) falls through Frames/Labels down to this, so tapping empty
    -- space toggles expand/collapse while the switch keeps its own tap.
    local clickCatcher = Instance.new("TextButton")
    clickCatcher.Text                = ""
    clickCatcher.AutoButtonColor      = false
    clickCatcher.BackgroundTransparency = 1
    clickCatcher.Size                = UDim2.new(1, 0, 1, 0)
    clickCatcher.ZIndex              = 20
    clickCatcher.Parent              = diFrame

    local islandExpanded, expandAnimating, introDone = false, false, false

    local function setSwitchVisual(on)
        local col = on and GREEN or SWITCH_OFF
        TweenService:Create(switchBtn, TweenInfo.new(0.2), { BackgroundColor3 = col }):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) }):Play()
    end

    local function setIslandExpanded(v)
        if expandAnimating or islandExpanded == v then return end
        expandAnimating = true
        islandExpanded  = v
        if v then
            diExpandSection.Visible = true
            diExpandScale.Scale     = 0
            TweenService:Create(diFrame, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Size = UDim2.fromOffset(ISLE_W, EXPANDED_H) }):Play()
            TweenService:Create(diCorner, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { CornerRadius = UDim.new(0, 34) }):Play()
            task.delay(0.14, function()
                if diExpandSection.Parent then
                    TweenService:Create(diExpandScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        { Scale = 1 }):Play()
                end
            end)
            task.delay(0.46, function() expandAnimating = false end)
        else
            TweenService:Create(diExpandScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Scale = 0 }):Play()
            local tw = TweenService:Create(diFrame, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { Size = UDim2.fromOffset(ISLE_W, ISLE_H) })
            TweenService:Create(diCorner, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { CornerRadius = UDim.new(0, ISLE_H/2) }):Play()
            tw:Play()
            tw.Completed:Connect(function()
                if not islandExpanded then diExpandSection.Visible = false end
                expandAnimating = false
            end)
        end
    end

    clickCatcher.Activated:Connect(function()
        if not introDone then return end
        setIslandExpanded(not islandExpanded)
    end)

    switchBtn.Activated:Connect(function()
        setBoost(not boostOn)
    end)

    onFpsBoostChanged = function(on) setSwitchVisual(on) end
    setSwitchVisual(boostOn)

    -- === Animation sequence ===
    task.spawn(function()
        task.wait(0.18)

        -- Phase 1: circle pops in (springy Back ease)
        TweenService:Create(diScale,
            TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()

        task.wait(0.88)

        -- Phase 2: expand to full pill width
        TweenService:Create(diFrame,
            TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Size = UDim2.fromOffset(ISLE_W, ISLE_H) }
        ):Play()

        task.wait(0.48)

        -- Phase 3: fade all text + divider in together
        local fi = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(diRTtitle,  fi, { TextTransparency = 0        }):Play()
        TweenService:Create(diRTval,    fi, { TextTransparency = 0        }):Play()
        TweenService:Create(diFPStitle, fi, { TextTransparency = 0        }):Play()
        TweenService:Create(diFPSval,   fi, { TextTransparency = 0        }):Play()
        TweenService:Create(diDiv,      fi, { BackgroundTransparency = 0.3 }):Play()

        task.wait(0.5)
        introDone = true   -- only allow tap-to-expand once the intro has settled

        -- Phase 4: continuous border pulse
        while alive() and gui.Parent do
            TweenService:Create(diBorder, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.05 }):Play()
            task.wait(1.6)
            TweenService:Create(diBorder, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.55 }):Play()
            task.wait(1.6)
        end
    end)

    -- Live update: runtime, FPS text + full island color shift based on FPS
    task.spawn(function()
        while alive() and gui.Parent do
            local elapsed = os.clock() - scriptStartTime
            diRTval.Text  = formatRuntime(elapsed)
            diFPSval.Text = tostring(smoothFPS)

            local textCol        = fpsTextColor(smoothFPS)
            local islandBg, islandBr = islandFpsColors(smoothFPS)

            TweenService:Create(diFPSval, TweenInfo.new(0.35, Enum.EasingStyle.Linear), { TextColor3 = textCol        }):Play()
            TweenService:Create(diFrame,  TweenInfo.new(0.50, Enum.EasingStyle.Linear), { BackgroundColor3 = islandBg }):Play()
            TweenService:Create(diBorder, TweenInfo.new(0.50, Enum.EasingStyle.Linear), { Color = islandBr            }):Play()

            task.wait(0.2)
        end
    end)

    -- ================================================================
    -- FLOATING ICON (slides in from left after island finishes)
    -- ================================================================
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size     = UDim2.fromOffset(ICON, ICON)
    holder.Position = UDim2.new(0, -ICON - 20, 0.5, -ICON/2)  -- starts off-screen
    holder.Parent   = gui

    -- Slide icon in after island animation completes
    task.delay(1.8, function()
        if not (alive() and gui.Parent) then return end
        TweenService:Create(holder,
            TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Position = UDim2.new(0, 14, 0.5, -ICON/2) }
        ):Play()
    end)

    local icon = Instance.new("TextButton")
    icon.Size             = UDim2.fromOffset(ICON, ICON)
    icon.BackgroundColor3 = CARD
    icon.BorderSizePixel  = 0
    icon.AutoButtonColor  = false
    icon.Font             = Enum.Font.GothamBold
    icon.Text             = logoAssetId and "" or "🌀"
    icon.TextSize         = 20
    icon.TextColor3       = WHITE
    icon.ZIndex           = 2
    icon.Parent           = holder
    mkCorner(icon, ICON/2)
    mkStroke(icon, BLUE, 1.6, 0.05)

    if logoAssetId then
        local ii = Instance.new("ImageLabel"); ii.BackgroundTransparency = 1
        ii.Size = UDim2.new(1,-6,1,-6); ii.Position = UDim2.fromOffset(3,3)
        ii.Image = logoAssetId; ii.ScaleType = Enum.ScaleType.Crop; ii.ZIndex = 2; ii.Parent = icon
        mkCorner(ii, ICON/2)
    end

    local iconGrad = Instance.new("UIGradient")
    iconGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CARD2),
        ColorSequenceKeypoint.new(1, DEEP),
    })
    iconGrad.Rotation = 45; iconGrad.Parent = icon

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(1,0); dot.Position = UDim2.new(1,2,0,-2)
    dot.Size = UDim2.fromOffset(10,10); dot.BackgroundColor3 = ORANGE
    dot.BorderSizePixel = 0; dot.ZIndex = 3; dot.Parent = icon
    mkCorner(dot, 5); mkStroke(dot, DEEP, 1.5)

    -- ================================================================
    -- POPOUT PANEL
    -- ================================================================
    local panel = Instance.new("Frame")
    panel.Size                   = UDim2.fromOffset(PANEL_W, 0)
    panel.AutomaticSize          = Enum.AutomaticSize.Y
    panel.Position               = UDim2.fromOffset(ICON+GAP, 0)
    panel.BackgroundColor3       = DEEP
    panel.BackgroundTransparency = 0.03
    panel.BorderSizePixel        = 0
    panel.Visible                = false
    panel.Parent                 = holder
    mkCorner(panel, 14); mkStroke(panel, LINE, 1.2, 0.10)

    local panelGrad = Instance.new("UIGradient")
    panelGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(19,49,68)),
        ColorSequenceKeypoint.new(0.55, CARD),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(8,19,28)),
    })
    panelGrad.Rotation = 90; panelGrad.Parent = panel

    local popScale = Instance.new("UIScale"); popScale.Parent = panel

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0,12); pad.PaddingRight = UDim.new(0,12)
    pad.PaddingTop  = UDim.new(0,10); pad.PaddingBottom = UDim.new(0,10)
    pad.Parent = panel

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0,4); list.Parent = panel

    -- Header
    local header = Instance.new("Frame")
    header.BackgroundTransparency = 1; header.Size = UDim2.new(1,0,0,34)
    header.LayoutOrder = 0; header.Parent = panel

    local titleLbl = mkLabel(header, "LIVE TRACKER", Enum.Font.GothamBold, 13, WHITE)
    titleLbl.Size = UDim2.new(1,-92,0,18)

    local subtitleLbl = mkLabel(header, "BLOX FRUITS • DISCORD", Enum.Font.GothamMedium, 8, MUTED)
    subtitleLbl.Position = UDim2.fromOffset(0,18); subtitleLbl.Size = UDim2.new(1,-92,0,12)

    local sendBtn  = mkButton(header, "SEND", 43, 24, BLUE2, WHITE, 9)
    sendBtn.AnchorPoint = Vector2.new(1,0.5); sendBtn.Position = UDim2.new(1,-28,0.5,0)

    local closeBtn = mkButton(header, "×", 22, 24, CARD2, MUTED, 16)
    closeBtn.AnchorPoint = Vector2.new(1,0.5); closeBtn.Position = UDim2.new(1,0,0.5,0)

    -- Player card
    local playerCard = Instance.new("Frame")
    playerCard.Size = UDim2.new(1,0,0,42); playerCard.BackgroundColor3 = CARD2
    playerCard.BackgroundTransparency = 0.10; playerCard.BorderSizePixel = 0
    playerCard.LayoutOrder = 1; playerCard.Parent = panel
    mkCorner(playerCard, 9); mkStroke(playerCard, BLUE, 0.8, 0.55)

    local pName = mkLabel(playerCard, "👤  "..LP.DisplayName, Enum.Font.GothamBold, 11, WHITE)
    pName.Position = UDim2.fromOffset(10,4); pName.Size = UDim2.new(1,-20,0,17)

    local pTag = mkLabel(playerCard, "@"..LP.Name, Enum.Font.Gotham, 8, MUTED)
    pTag.Position = UDim2.fromOffset(28,22); pTag.Size = UDim2.new(1,-38,0,12)

    local SHORT = {
        beli="Beli", fragments="Fragments", mythical="Mythical Scrolls",
        legendary="Legendary Scrolls", foolsgold="Fool's Gold",
        terror="Terror Eyes", levheart="Leviathan Heart", levscale="Leviathan Scale",
    }

    local valueLabels = {}
    local panelRows   = { playerCard }   -- for stagger animation
    local order = 2

    for _, it in ipairs(ITEMS) do
        if it.key == "mythical" then
            local div = Instance.new("Frame")
            div.Size = UDim2.new(1,0,0,1); div.BackgroundColor3 = LINE
            div.BackgroundTransparency = 0.25; div.BorderSizePixel = 0
            div.LayoutOrder = order; div.Parent = panel; order = order + 1
        end

        local row = Instance.new("Frame")
        row.BackgroundColor3 = CARD; row.BackgroundTransparency = 0.18
        row.Size = UDim2.new(1,0,0,ROW_H); row.LayoutOrder = order
        row.Parent = panel
        mkCorner(row, 8)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.fromOffset(3,16); accent.Position = UDim2.fromOffset(7,6)
        accent.BackgroundColor3 = BLUE; accent.BorderSizePixel = 0; accent.Parent = row
        mkCorner(accent, 2)

        local n = mkLabel(row, it.uiEmoji.."  "..(SHORT[it.key] or it.label), Enum.Font.GothamMedium, 9, TEXT)
        n.Position = UDim2.fromOffset(17,0); n.Size = UDim2.new(0.62,-17,1,0)

        local v = mkLabel(row, "--", Enum.Font.GothamBold, 10, WHITE, Enum.TextXAlignment.Right)
        v.AnchorPoint = Vector2.new(1,0); v.Position = UDim2.new(1,-9,0,0); v.Size = UDim2.new(0.38,0,1,0)
        valueLabels[it.key] = v

        panelRows[#panelRows+1] = row
        order = order + 1
    end

    -- Footer
    local footer = Instance.new("Frame")
    footer.BackgroundTransparency = 1; footer.Size = UDim2.new(1,0,0,28)
    footer.LayoutOrder = 1000; footer.Parent = panel

    local status = mkLabel(footer, "● starting…", Enum.Font.GothamMedium, 8, ORANGE)
    status.Size = UDim2.new(1,-54,1,0)

    local stopBtn = mkButton(footer, "STOP", 42, 22,
        Color3.fromRGB(91,34,42), Color3.fromRGB(255,175,180), 8)
    stopBtn.AnchorPoint = Vector2.new(1,0.5); stopBtn.Position = UDim2.new(1,0,0.5,0)

    renderPanel = function()
        for key, lbl in pairs(valueLabels) do lbl.Text = compact(values[key]) end
        local failed    = lastPostMsg:find("FAILED", 1, true) ~= nil
        local color     = failed and RED or (invOk and GREEN or ORANGE)
        dot.BackgroundColor3 = color
        local statusText
        if failed then statusText = lastPostMsg
        elseif not invOk then statusText = "inventory: "..(invErr or "reading…")
        else statusText = ("live · next post %ds"):format(math.max(0, math.ceil(nextPostAt-os.clock()))) end
        status.Text = "● "..statusText; status.TextColor3 = color
    end

    ------------------------------------------------------------------
    -- open / close  (with row stagger on first open)
    ------------------------------------------------------------------
    local isOpen        = false
    local panelAnimated = false

    local function setOpen(v)
        isOpen = v
        if v then
            renderPanel()
            local screen  = gui.AbsoluteSize
            local hp      = holder.AbsolutePosition
            local toLeft  = hp.X + ICON + GAP + PANEL_W > screen.X
            local panelH  = math.max(panel.AbsoluteSize.Y, 300)
            local shiftUp = math.max(0, hp.Y + panelH - screen.Y + 8)

            panel.AnchorPoint = toLeft and Vector2.new(1,0) or Vector2.new(0,0)
            panel.Position = UDim2.fromOffset(toLeft and -GAP or (ICON+GAP), -shiftUp)
            popScale.Scale = 0.82; panel.Visible = true
            TweenService:Create(popScale,
                TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Scale = 1 }
            ):Play()

            -- Stagger row fade-in on first open
            if not panelAnimated then
                panelAnimated = true
                for i, rowFrame in ipairs(panelRows) do
                    local orig = rowFrame.BackgroundTransparency
                    rowFrame.BackgroundTransparency = 1
                    task.delay((i-1) * 0.055, function()
                        if not gui.Parent then return end
                        TweenService:Create(rowFrame,
                            TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { BackgroundTransparency = orig }
                        ):Play()
                    end)
                end
            end
        else
            local tw = TweenService:Create(popScale,
                TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Scale = 0.82 }
            )
            tw.Completed:Connect(function() if not isOpen then panel.Visible = false end end)
            tw:Play()
        end
    end

    closeBtn.Activated:Connect(function() setOpen(false) end)

    sendBtn.Activated:Connect(function()
        if sending then return end
        sendBtn.Text = "..."
        sendNow()
        sendBtn.Text = "SEND"
        renderPanel()
    end)

    stopBtn.Activated:Connect(function()
        env.__BF_MAT_WEBHOOK = nil
        gui:Destroy()
    end)

    ------------------------------------------------------------------
    -- icon: tap = toggle, drag = move
    ------------------------------------------------------------------
    local dragging, moved, dragStart, startPos = false, false, nil, nil

    icon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, holder.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            if moved then
                holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                            startPos.Y.Scale, startPos.Y.Offset+d.Y)
            end
        end
    end)

    icon.Activated:Connect(function()
        if moved then moved = false; return end
        setOpen(not isOpen)
    end)

    task.spawn(function()
        while alive() and gui.Parent do renderPanel(); task.wait(1) end
    end)
end

----------------------------------------------------------------------
-- LOOPS
----------------------------------------------------------------------
refreshStats()

task.spawn(function()
    while alive() do
        refreshStats(); readInventory()
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

print(("[BF Webhook] running — posting every %ds. FPS Boost is OFF by default; tap the Dynamic Island to toggle it. Re-execute to restart, X on the panel to stop."):format(CONFIG.SendEvery))
