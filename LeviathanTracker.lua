--[[
    BLOX FRUITS — Live Materials -> Discord Webhook
    --------------------------------------------------------------------
    Posts your live counts to a Discord webhook every 60 seconds:
      Beli, Fragments, Mythical Scrolls, Legendary Scrolls,
      Fool's Gold, Terror Eyes, Leviathan Heart, Leviathan Scale

    HOW TO RUN
      1. Discord: Channel settings -> Integrations -> Webhooks -> New Webhook -> Copy URL
      2. Paste that URL into CONFIG.WebhookURL below.
      3. Join Blox Fruits, pick a team, then execute this whole file.

    WHERE THE NUMBERS COME FROM
      Beli / Fragments  -> LocalPlayer.Data.Beli / .Fragments (live, updates instantly)
      Scrolls/materials -> Blox Fruits' ItemReplicationService (the system the inventory UI uses):
                           Modules.Net["RF/GetAllItemValues"] returns {ItemId, NetworkedUID, Key, Value}
                           records; counts are Key == "Quantity". RE/OnItemValueChanged pushes changes
                           live. Fallback: RF/GetCraftPlayerData().EtcItems (name-keyed).
                           (getInventory stopped returning materials — it now returns nil.)

    The first read prints item IDs, counts, and a cross-check against the crafting
    data to the F9 console.
--]]

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local CONFIG = {
    -- ================================================================
    -- EDIT THESE TWO VALUES
    -- ================================================================


    SendEvery        = 60,
    InventoryRefresh = 15,
    EditSameMessage  = false,
    ShowPanel        = true,
    Debug            = true,

    -- webhook branding
    WebhookUsername  = "Merciful Blox Fruits Tracker",
    WebhookAvatarURL = "https://i.imgur.com/WUuVA9l.jpeg",
    WebhookGifURL    = "https://i.imgur.com/4jxdn8Z.gif",
}

-- ================================================================
-- KEY CHECK
-- Case-insensitive: MercifulPapa / mercifulpapa / MERCIFULPAPA
-- ================================================================
local REQUIRED_KEY = "MercifulPapa"

if tostring(CONFIG.Key or ""):lower() ~= REQUIRED_KEY:lower() then
    warn("[BF Webhook] Invalid key. Script stopped.")

    -- Show a visible error banner at the very top of the screen.
    pcall(function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer

        local parent
        pcall(function()
            parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        parent = parent or player:WaitForChild("PlayerGui")

        local old = parent:FindFirstChild("BF_KeyError")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "BF_KeyError"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10000000
        gui.Parent = parent

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.new(0.5, 0, 0, 12)
        frame.Size = UDim2.fromOffset(360, 58)
        frame.BackgroundColor3 = Color3.fromRGB(105, 25, 30)
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 85, 95)
        stroke.Thickness = 1.5
        stroke.Parent = frame

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(14, 7)
        title.Size = UDim2.new(1, -28, 0, 22)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 15
        title.TextColor3 = Color3.fromRGB(255, 235, 235)
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.Text = "⚠ INVALID KEY"
        title.Parent = frame

        local detail = Instance.new("TextLabel")
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(14, 30)
        detail.Size = UDim2.new(1, -28, 0, 18)
        detail.Font = Enum.Font.GothamMedium
        detail.TextSize = 10
        detail.TextColor3 = Color3.fromRGB(255, 195, 200)
        detail.TextXAlignment = Enum.TextXAlignment.Center
        detail.Text = "Skill Issue Nigga"
        detail.Parent = frame

        -- Remove the error banner automatically after 10 seconds.
        task.delay(10, function()
            if gui and gui.Parent then
                gui:Destroy()
            end
        end)
    end)

    return
end


-- what gets tracked. `stat` = read from Player.Data, `names`/IDs = read from the item replication system
-- `emoji`   = Discord custom emoji, used in the WEBHOOK embed only (Discord renders these fine)
-- `uiEmoji` = plain Unicode emoji, used in the IN-GAME panel only (Roblox can't render Discord's
--             custom `<:name:id>` emoji codes, so the panel needs real Unicode characters instead)
local ITEMS = {
    { key = "beli",      label = "Beli",              emoji = "<a:money:1481836978571055174>", uiEmoji = "💰", stat  = { "Beli", "Money" } },
    { key = "fragments", label = "Fragments",         emoji = "<:Fragments:1523292585127448576>", uiEmoji = "🧩", stat  = { "Fragments" } },
    -- idType/fallbackId: item IDs read from the game's Economy.ItemId table on 2026-09-13
    { key = "mythical",  label = "Mythical Scrolls",  emoji = "<:MythicScroll:1168527646867607625>", uiEmoji = "🔮", names = { "Mythical Scroll" },  idType = "Scroll",   fallbackId = 858 },
    { key = "legendary", label = "Legendary Scrolls", emoji = "<:LegendScroll:1168527616312094811>", uiEmoji = "📜", names = { "Legendary Scroll" }, idType = "Scroll",   fallbackId = 857 },
    { key = "foolsgold", label = "Fool's Gold",       emoji = "<a:9040goldnitro:1413550873354834051>", uiEmoji = "🪙", names = { "Fool's Gold" },      idType = "Material", fallbackId = 597 },
    { key = "terror",    label = "Terror Eyes",       emoji = "<:blurryeyes:1372835227256492042>", uiEmoji = "👁️", names = { "Terror Eyes" },      idType = "Material", fallbackId = 582 },
    { key = "levheart",  label = "Leviathan Heart",   emoji = "<a:DropletHeart:1515188697388154941>", uiEmoji = "💧", names = { "Leviathan Heart" },  idType = "Material", fallbackId = 570 },
    { key = "levscale",  label = "Leviathan Scale",   emoji = "<:frozen_ice:1528361431563501658>", uiEmoji = "❄️", names = { "Leviathan Scale" },  idType = "Material", fallbackId = 561 },
}

----------------------------------------------------------------------
-- SETUP
----------------------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local LP          = Players.LocalPlayer

-- re-executing the script stops the previous copy's loops
local env = (getgenv and getgenv()) or _G
local SESSION = {}
env.__BF_MAT_WEBHOOK = SESSION
local function alive() return env.__BF_MAT_WEBHOOK == SESSION end

local ITEM = {}
for _, it in ipairs(ITEMS) do ITEM[it.key] = it end

local values   = {}      -- key -> number (nil until first successful read)
local invOk    = false   -- last inventory read succeeded
local invErr   = nil
local invAt    = 0       -- os.clock() of last good inventory read
local invSrc   = "-"     -- which source produced the numbers
local renderPanel        -- set by the panel below (if enabled)
local setStatus = function(_) end

----------------------------------------------------------------------
-- BELI / FRAGMENTS  (replicated values, live)
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
                if v and v:IsA("ValueBase") and tonumber(v.Value) then
                    return tonumber(v.Value), v
                end
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
-- INVENTORY  (scrolls + materials via ItemReplicationService)
----------------------------------------------------------------------
local Modules = RS:WaitForChild("Modules", 30)
local Net = Modules and Modules:WaitForChild("Net", 30)
local function netRemote(name) return Net and Net:FindFirstChild(name) end

-- item IDs: the verified ones; the game's own lookup is only used to warn if an update renumbers them
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
                    warn(("[BF Webhook] game lists %s as id %d (script uses %d) — check the cross-check below")
                        :format(it.names[1], gameId, it.id))
                end
            end)
        end
    end
end

-- InvokeServer can hang forever if the server never answers; cap it
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

local qty = {}   -- itemId -> { [networkedUID] = quantity }

-- store one {ItemId, NetworkedUID, Key, Value} record if it's a quantity for a tracked item
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

-- live pushes: the server batches changed records to this event
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
local reading = false

-- returns true if fresh numbers were read, false if we're holding the last known values
local function readInventory()
    if reading then                          -- another read in flight: just wait for it
        while reading do task.wait(0.1) end
        return invOk
    end
    reading = true

    -- primary: full item snapshot
    local rf = netRemote("RF/GetAllItemValues")
    local ok, res
    if rf then ok, res = invokeWithTimeout(rf, 10) else ok, res = false, "RF/GetAllItemValues not found" end

    if ok and type(res) == "table" then
        local fresh, quantityRecords = {}, 0
        for _, rec in pairs(res) do
            if type(rec) == "table" and rec.Key == "Quantity" then quantityRecords = quantityRecords + 1 end
            applyRecord(rec, fresh)
        end
        if quantityRecords > 0 then
            qty = fresh
            for _, it in ipairs(ITEMS) do
                if it.id then values[it.key] = totalFor(it.id) end   -- not owned -> 0
            end
            invOk, invErr, invAt, invSrc = true, nil, os.clock(), "items"
            reading = false

            if CONFIG.Debug and not printedDebug then
                printedDebug = true
                local etc = readCraftData()
                print("[BF Webhook] item counts (GetAllItemValues) vs crafting data:")
                for _, it in ipairs(ITEMS) do
                    if it.id then
                        local other = etc and etc[it.names[1]]
                        local verdict = (other == nil) and "not listed in craft data"
                            or (tonumber(other) == values[it.key] and "MATCH" or ("MISMATCH craft=" .. tostring(other)))
                        print(("   %-17s id=%-5d count=%-6d %s"):format(it.names[1], it.id, values[it.key], verdict))
                    end
                end
            end
            return true
        end
        invErr = "no Quantity records in GetAllItemValues"
    else
        invErr = ok and ("GetAllItemValues returned " .. typeof(res)) or tostring(res)
    end

    -- fallback: crafting data keyed by item name
    local etc = readCraftData()
    if etc then
        for _, it in ipairs(ITEMS) do
            if it.names then values[it.key] = tonumber(etc[it.names[1]]) or 0 end
        end
        invOk, invAt, invSrc = true, os.clock(), "craft data"
        reading = false
        return true
    end

    invOk = false
    reading = false
    return false
end

----------------------------------------------------------------------
-- DISCORD
----------------------------------------------------------------------
local httpRequest = (syn and syn.request) or (http and http.request) or http_request
    or request or (fluxus and fluxus.request)

local function commas(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^(%-?),", "%1"))
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

local function buildPayload(snap, prev, stale)
    local fields = {}
    local function add(key)
        local it = ITEM[key]
        fields[#fields + 1] = {
            name   = it.emoji .. " " .. it.label,
            value  = "```" .. fmtValue(snap[key], prev and prev[key]) .. "```",
            inline = true,
        }
    end
    local function spacer()
        fields[#fields + 1] = { name = "\u{200B}", value = "\u{200B}", inline = true }
    end

    add("beli"); add("fragments"); spacer()
    add("mythical"); add("legendary"); spacer()
    add("foolsgold"); add("terror"); spacer()
    add("levheart"); add("levscale"); spacer()

    local desc = ("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName, LP.Name)
    local data = LP:FindFirstChild("Data")
    local lvl = data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then desc = desc .. "  •  Level " .. commas(lvl.Value) end

    local stamp
    pcall(function() stamp = DateTime.now():ToIsoDate() end)

    local embed = {
        title       = "<a:crown_blueZK:1451051338333945978> MADE BY MERCIFUL <a:crown_blueZK:1451051338333945978>",
        description = desc,
        color       = stale and 16755370 or 6724095,     -- warning orange if stale, light blue if live
        fields      = fields,
        footer      = { text = stale
            and ("⚠ inventory read failed (" .. tostring(invErr) .. ") — showing last known values")
            or  ("Live • updates every " .. CONFIG.SendEvery .. "s") },
        timestamp   = stamp,
    }

    if type(CONFIG.WebhookGifURL) == "string" and CONFIG.WebhookGifURL ~= "" then
        embed.image = { url = CONFIG.WebhookGifURL }
    end

    return {
        username   = CONFIG.WebhookUsername,
        avatar_url = CONFIG.WebhookAvatarURL,
        embeds     = { embed },
    }
end

local messageId
local function postWebhook(payload)
    local url = CONFIG.WebhookURL
    if type(url) ~= "string" or not url:find("/api/webhooks/", 1, true) then
        return false, "WebhookURL not set"
    end
    if not httpRequest then return false, "executor has no request() function" end

    local okEnc, body = pcall(function() return HttpService:JSONEncode(payload) end)
    if not okEnc then return false, "JSON encode failed" end

    local base, query = url:match("^([^?]+)(.*)$")
    for _ = 1, 3 do
        local method, target
        if CONFIG.EditSameMessage and messageId then
            method, target = "PATCH", base .. "/messages/" .. messageId .. query
        else
            method, target = "POST", base .. (query == "" and "?wait=true" or (query .. "&wait=true"))
        end

        local sent, res = pcall(httpRequest, {
            Url = target, Method = method,
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if not sent then return false, "request error: " .. tostring(res) end

        local code = res and tonumber(res.StatusCode or res.Status or res.status_code)
        if code == 429 then
            local retry = 2
            pcall(function() retry = tonumber(HttpService:JSONDecode(res.Body).retry_after) or 2 end)
            task.wait(math.clamp(retry, 0.5, 30))
        elseif code == 404 and method == "PATCH" then
            messageId = nil                      -- message was deleted; post a fresh one
        elseif (code and code >= 200 and code < 300) or (not code and res and res.Success ~= false) then
            if method == "POST" then
                pcall(function() messageId = HttpService:JSONDecode(res.Body).id end)
            end
            return true, "sent"
        else
            return false, "Discord HTTP " .. tostring(code)
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
    local fresh = readInventory()            -- always a fresh read right before posting
    if renderPanel then renderPanel() end

    local snap = {}
    for _, it in ipairs(ITEMS) do snap[it.key] = values[it.key] end

    local ok, msg = postWebhook(buildPayload(snap, lastSent, not fresh))
    if ok then
        lastSent = snap
        lastPostMsg = "sent " .. os.date("%H:%M:%S") .. (fresh and "" or " (stale)")
    else
        lastPostMsg = "FAILED: " .. msg
        warn("[BF Webhook] " .. msg)
    end
    lastPostAt = os.clock()
    sending = false
end

----------------------------------------------------------------------
-- ----------------------------------------------------------------------
-- PANEL  (revamped light-blue UI)
-- ----------------------------------------------------------------------
local nextPostAt = os.clock() + 3

local function compact(n)
    n = tonumber(n)
    if not n then return "--" end
    local a = math.abs(n)
    if a >= 1e12 then return ("%.2fT"):format(n / 1e12) end
    if a >= 1e9  then return ("%.2fB"):format(n / 1e9) end
    if a >= 1e6  then return ("%.2fM"):format(n / 1e6) end
    if a >= 1e3  then return ("%.1fK"):format(n / 1e3) end
    return commas(n)
end

if CONFIG.ShowPanel then
    local TweenService = game:GetService("TweenService")

    local parent
    pcall(function()
        parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    parent = parent or LP:WaitForChild("PlayerGui")

    local old = parent:FindFirstChild("BF_MaterialsWebhook")
    if old then old:Destroy() end

    -- Light-blue palette.
    local WHITE  = Color3.fromRGB(244, 251, 255)
    local TEXT   = Color3.fromRGB(205, 232, 248)
    local MUTED  = Color3.fromRGB(130, 174, 201)
    local BLUE   = Color3.fromRGB(92, 196, 255)
    local BLUE2  = Color3.fromRGB(56, 157, 224)
    local DEEP   = Color3.fromRGB(9, 20, 30)
    local CARD   = Color3.fromRGB(14, 31, 44)
    local CARD2  = Color3.fromRGB(18, 42, 59)
    local LINE   = Color3.fromRGB(53, 104, 132)
    local GREEN  = Color3.fromRGB(92, 221, 148)
    local ORANGE = Color3.fromRGB(245, 181, 78)
    local RED    = Color3.fromRGB(245, 96, 103)

    local ICON, PANEL_W, ROW_H, GAP = 64, 250, 28, 7

    local function corner(p, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r)
        c.Parent = p
    end

    local function stroke(p, col, t, trans)
        local s = Instance.new("UIStroke")
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Color = col
        s.Thickness = t or 1
        s.Transparency = trans or 0
        s.Parent = p
        return s
    end

    local function label(parentObj, text, font, size, color, align)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = font
        l.TextSize = size
        l.TextColor3 = color
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = text
        l.Parent = parentObj
        return l
    end

    local function button(parentObj, text, w, h, bg, fg, size)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(w, h)
        b.BackgroundColor3 = bg
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.GothamBold
        b.TextSize = size or 10
        b.TextColor3 = fg or WHITE
        b.Text = text
        b.Parent = parentObj
        corner(b, 7)
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.10)
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = bg
            }):Play()
        end)
        return b
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BF_MaterialsWebhook"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000000
    if not pcall(function() gui.Parent = parent end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    -- Fetches an external image and hands back a rbxassetid Roblox can display, for executors
    -- that support writefile/getcustomasset. Returns nil (caller falls back to an emoji) otherwise.
    local function loadRemoteImage(url)
        if not (writefile and getcustomasset and httpRequest) then return nil end
        local ok, assetId = pcall(function()
            local resp = httpRequest({ Url = url, Method = "GET" })
            local bytes = resp and (resp.Body or resp.body)
            if type(bytes) ~= "string" or #bytes == 0 then return nil end
            writefile("bf_logo_cache.png", bytes)
            return getcustomasset("bf_logo_cache.png")
        end)
        if ok and assetId then return assetId end
        return nil
    end

    local logoAssetId = loadRemoteImage(CONFIG.WebhookAvatarURL) -- same ice-bear pfp as the webhook

    -- Top-middle creator credit.
    local credit = Instance.new("Frame")
    credit.Name = "CreatorCredit"
    credit.AnchorPoint = Vector2.new(0.5, 0)
    credit.Position = UDim2.new(0.5, 0, 0, 12)
    credit.Size = UDim2.fromOffset(310, 24)
    credit.BackgroundColor3 = DEEP
    credit.BackgroundTransparency = 0.08
    credit.BorderSizePixel = 0
    credit.Parent = gui
    corner(credit, 12)
    stroke(credit, BLUE, 1.2, 0.15)

    local creditText = Instance.new("TextLabel")
    creditText.BackgroundTransparency = 1
    creditText.Font = Enum.Font.GothamBold
    creditText.TextSize = 11
    creditText.TextColor3 = WHITE
    creditText.TextXAlignment = Enum.TextXAlignment.Left
    creditText.Text = "MADE BY MERCIFUL"
    creditText.Parent = credit

    if logoAssetId then
        local creditLogo = Instance.new("ImageLabel")
        creditLogo.BackgroundTransparency = 1
        creditLogo.Size = UDim2.fromOffset(18, 18)
        creditLogo.Position = UDim2.fromOffset(9, 3)
        creditLogo.Image = logoAssetId
        creditLogo.Parent = credit
        corner(creditLogo, 9)

        creditText.Position = UDim2.fromOffset(33, 0)
        creditText.Size = UDim2.new(1, -37, 1, 0)
    else
        -- image couldn't be fetched/cached on this executor — fall back to a plain emoji
        creditText.Text = "🐻  MADE BY MERCIFUL"
        creditText.Position = UDim2.fromOffset(9, 0)
        creditText.Size = UDim2.new(1, -17, 1, 0)
    end

    local creditGradient = Instance.new("UIGradient")
    creditGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, BLUE2),
        ColorSequenceKeypoint.new(0.5, BLUE),
        ColorSequenceKeypoint.new(1, BLUE2),
    })
    creditGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.80),
        NumberSequenceKeypoint.new(0.5, 0.60),
        NumberSequenceKeypoint.new(1, 0.80),
    })
    creditGradient.Parent = credit

    -- Holder = icon + popout, dragged as one piece.
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(ICON, ICON)
    holder.Position = UDim2.new(0, 14, 0.5, -ICON / 2)
    holder.Parent = gui

    ------------------------------------------------------------------
    -- floating icon
    ------------------------------------------------------------------
    local icon = Instance.new("TextButton")
    icon.Size = UDim2.fromOffset(ICON, ICON)
    icon.BackgroundColor3 = CARD
    icon.BorderSizePixel = 0
    icon.AutoButtonColor = false
    icon.Font = Enum.Font.GothamBold
    icon.Text = logoAssetId and "" or "🌀" -- fallback emoji only if the logo image couldn't be loaded
    icon.TextSize = 20
    icon.TextColor3 = WHITE
    icon.ZIndex = 2
    icon.Parent = holder
    corner(icon, ICON / 2)
    stroke(icon, BLUE, 1.6, 0.05)

    if logoAssetId then
        -- same ice-bear logo used in the credit banner, filling the toggle circle
        local iconImage = Instance.new("ImageLabel")
        iconImage.BackgroundTransparency = 1
        iconImage.Size = UDim2.new(1, -6, 1, -6)
        iconImage.Position = UDim2.fromOffset(3, 3)
        iconImage.Image = logoAssetId
        iconImage.ScaleType = Enum.ScaleType.Crop
        iconImage.ZIndex = 2
        iconImage.Parent = icon
        corner(iconImage, ICON / 2)
    end

    local iconGradient = Instance.new("UIGradient")
    iconGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CARD2),
        ColorSequenceKeypoint.new(1, DEEP),
    })
    iconGradient.Rotation = 45
    iconGradient.Parent = icon

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(1, 0)
    dot.Position = UDim2.new(1, 2, 0, -2)
    dot.Size = UDim2.fromOffset(10, 10)
    dot.BackgroundColor3 = ORANGE
    dot.BorderSizePixel = 0
    dot.ZIndex = 3
    dot.Parent = icon
    corner(dot, 5)
    stroke(dot, DEEP, 1.5)

    ------------------------------------------------------------------
    -- popout panel
    ------------------------------------------------------------------
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(PANEL_W, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Position = UDim2.fromOffset(ICON + GAP, 0)
    panel.BackgroundColor3 = DEEP
    panel.BackgroundTransparency = 0.03
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = holder
    corner(panel, 14)
    stroke(panel, LINE, 1.2, 0.10)

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(19, 49, 68)),
        ColorSequenceKeypoint.new(0.55, CARD),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 19, 28)),
    })
    panelGradient.Rotation = 90
    panelGradient.Parent = panel

    local popScale = Instance.new("UIScale")
    popScale.Parent = panel

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = panel

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 4)
    list.Parent = panel

    -- Header.
    local header = Instance.new("Frame")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 34)
    header.LayoutOrder = 0
    header.Parent = panel

    local title = label(header, "LIVE TRACKER", Enum.Font.GothamBold, 13, WHITE)
    title.Size = UDim2.new(1, -92, 0, 18)

    local subtitle = label(header, "BLOX FRUITS • DISCORD", Enum.Font.GothamMedium, 8, MUTED)
    subtitle.Position = UDim2.fromOffset(0, 18)
    subtitle.Size = UDim2.new(1, -92, 0, 12)

    local sendBtn = button(header, "SEND", 43, 24, BLUE2, WHITE, 9)
    sendBtn.AnchorPoint = Vector2.new(1, 0.5)
    sendBtn.Position = UDim2.new(1, -28, 0.5, 0)

    local closeBtn = button(header, "×", 22, 24, CARD2, MUTED, 16)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, 0, 0.5, 0)

    -- Highlighted player username card.
    local playerCard = Instance.new("Frame")
    playerCard.Size = UDim2.new(1, 0, 0, 42)
    playerCard.BackgroundColor3 = CARD2
    playerCard.BackgroundTransparency = 0.10
    playerCard.BorderSizePixel = 0
    playerCard.LayoutOrder = 1
    playerCard.Parent = panel
    corner(playerCard, 9)
    stroke(playerCard, BLUE, 0.8, 0.55)

    local playerName = label(
        playerCard,
        "👤  " .. LP.DisplayName,
        Enum.Font.GothamBold, 11, WHITE
    )
    playerName.Position = UDim2.fromOffset(10, 4)
    playerName.Size = UDim2.new(1, -20, 0, 17)

    local playerTag = label(playerCard, "@" .. LP.Name, Enum.Font.Gotham, 8, MUTED)
    playerTag.Position = UDim2.fromOffset(28, 22)
    playerTag.Size = UDim2.new(1, -38, 0, 12)

    local SHORT = {
        beli = "Beli", fragments = "Fragments",
        mythical = "Mythical Scrolls", legendary = "Legendary Scrolls",
        foolsgold = "Fool's Gold", terror = "Terror Eyes",
        levheart = "Leviathan Heart", levscale = "Leviathan Scale",
    }

    local valueLabels = {}
    local order = 2

    for _, it in ipairs(ITEMS) do
        if it.key == "mythical" then
            local div = Instance.new("Frame")
            div.Size = UDim2.new(1, 0, 0, 1)
            div.BackgroundColor3 = LINE
            div.BackgroundTransparency = 0.25
            div.BorderSizePixel = 0
            div.LayoutOrder = order
            div.Parent = panel
            order = order + 1
        end

        local row = Instance.new("Frame")
        row.BackgroundColor3 = CARD
        row.BackgroundTransparency = 0.18
        row.Size = UDim2.new(1, 0, 0, ROW_H)
        row.LayoutOrder = order
        row.Parent = panel
        corner(row, 8)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.fromOffset(3, 16)
        accent.Position = UDim2.fromOffset(7, 6)
        accent.BackgroundColor3 = BLUE
        accent.BorderSizePixel = 0
        accent.Parent = row
        corner(accent, 2)

        local n = label(
            row,
            it.uiEmoji .. "  " .. (SHORT[it.key] or it.label),
            Enum.Font.GothamMedium, 9, TEXT
        )
        n.Position = UDim2.fromOffset(17, 0)
        n.Size = UDim2.new(0.62, -17, 1, 0)

        local v = label(row, "--", Enum.Font.GothamBold, 10, WHITE, Enum.TextXAlignment.Right)
        v.AnchorPoint = Vector2.new(1, 0)
        v.Position = UDim2.new(1, -9, 0, 0)
        v.Size = UDim2.new(0.38, 0, 1, 0)
        valueLabels[it.key] = v

        order = order + 1
    end

    -- Footer.
    local footer = Instance.new("Frame")
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 28)
    footer.LayoutOrder = 1000
    footer.Parent = panel

    local status = label(footer, "● starting…", Enum.Font.GothamMedium, 8, ORANGE)
    status.Size = UDim2.new(1, -54, 1, 0)

    local stopBtn = button(
        footer, "STOP", 42, 22,
        Color3.fromRGB(91, 34, 42),
        Color3.fromRGB(255, 175, 180), 8
    )
    stopBtn.AnchorPoint = Vector2.new(1, 0.5)
    stopBtn.Position = UDim2.new(1, 0, 0.5, 0)

    renderPanel = function()
        for key, lbl in pairs(valueLabels) do
            lbl.Text = compact(values[key])
        end

        local failed = lastPostMsg:find("FAILED", 1, true) ~= nil
        local color = failed and RED or (invOk and GREEN or ORANGE)
        dot.BackgroundColor3 = color

        local statusText
        if failed then
            statusText = lastPostMsg
        elseif not invOk then
            statusText = "inventory: " .. (invErr or "reading…")
        else
            statusText = ("live · next post %ds"):format(
                math.max(0, math.ceil(nextPostAt - os.clock()))
            )
        end

        status.Text = "● " .. statusText
        status.TextColor3 = color
    end

    ------------------------------------------------------------------
    -- open / close
    ------------------------------------------------------------------
    local isOpen = false

    local function setOpen(v)
        isOpen = v

        if v then
            renderPanel()

            local screen = gui.AbsoluteSize
            local hp = holder.AbsolutePosition
            local toLeft = hp.X + ICON + GAP + PANEL_W > screen.X
            local panelH = math.max(panel.AbsoluteSize.Y, 300)
            local shiftUp = math.max(0, hp.Y + panelH - screen.Y + 8)

            panel.AnchorPoint = toLeft and Vector2.new(1, 0) or Vector2.new(0, 0)
            panel.Position = UDim2.fromOffset(
                toLeft and -GAP or (ICON + GAP),
                -shiftUp
            )

            popScale.Scale = 0.82
            panel.Visible = true

            TweenService:Create(
                popScale,
                TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Scale = 1 }
            ):Play()
        else
            local tw = TweenService:Create(
                popScale,
                TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Scale = 0.82 }
            )
            tw.Completed:Connect(function()
                if not isOpen then panel.Visible = false end
            end)
            tw:Play()
        end
    end

    closeBtn.Activated:Connect(function()
        setOpen(false)
    end)

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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end

            if moved then
                holder.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + d.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + d.Y
                )
            end
        end
    end)

    icon.Activated:Connect(function()
        if moved then
            moved = false
            return
        end
        setOpen(not isOpen)
    end)

    task.spawn(function()
        while alive() and gui.Parent do
            renderPanel()
            task.wait(1)
        end
    end)
end

-- LOOPS
----------------------------------------------------------------------
refreshStats()

-- panel refresh: inventory every CONFIG.InventoryRefresh seconds
task.spawn(function()
    while alive() do
        refreshStats()
        readInventory()
        if renderPanel then renderPanel() end
        task.wait(CONFIG.InventoryRefresh)
    end
end)

-- Discord: first post ~3s after load, then every CONFIG.SendEvery seconds (no drift)
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

print(("[BF Webhook] running — posting every %ds. Re-execute to restart, X on the panel to stop."):format(CONFIG.SendEvery))
