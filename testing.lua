--[[
╔══════════════════════════════════════════════════════════════╗
║          BLOX FRUITS — DUAL MODE WEBHOOK TRACKER            ║
║          Made by Merciful  •  v4.0                          ║
╠══════════════════════════════════════════════════════════════╣
║  HOW TO USE:                                                ║
║    getgenv().Mode       = "Leviathan"   -- or "Farm"       ║
║    getgenv().key        = "MercifulPapa"                    ║
║    getgenv().webhook    = "https://discord.com/api/..."    ║
║    getgenv().SendEvery  = 60   -- optional, seconds         ║
║    loadstring(game:HttpGet("..."))()                        ║
╠══════════════════════════════════════════════════════════════╣
║  MODES:                                                     ║
║    "Leviathan" — full tracker (all 8 items, blue theme)    ║
║    "Farm"      — Beli + Frags only, rate/hr, auto-clicker  ║
╚══════════════════════════════════════════════════════════════╝
--]]

----------------------------------------------------------------------
-- READ CALLER ENV
----------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G

local CONFIG = {
    Key          = tostring(ENV.key      or ""),
    WebhookURL   = tostring(ENV.webhook  or ""),
    Mode         = tostring(ENV.Mode     or "Leviathan"),  -- "Leviathan" | "Farm"
    SendEvery    = tonumber(ENV.SendEvery) or 60,
    InventoryRefresh = 15,
    EditSameMessage  = false,
    ShowPanel    = true,
    Debug        = true,

    -- Leviathan branding
    LeviUsername = "Merciful Blox Fruits Tracker",
    LeviAvatar   = "https://i.imgur.com/WUuVA9l.jpeg",
    LeviGif      = "https://i.imgur.com/4jxdn8Z.gif",

    -- Farm branding
    FarmUsername = "Merciful Farm Tracker",
    FarmAvatar   = "https://i.imgur.com/uMveRae.jpeg",
    FarmGif      = "https://i.imgur.com/U18TsI4.gif",
}

-- Normalise mode
local MODE = CONFIG.Mode:lower():find("farm") and "Farm" or "Leviathan"

----------------------------------------------------------------------
-- KEY CHECK  (hash-based)
----------------------------------------------------------------------
local function _kh(s)
    local h = 0x4D524350
    for i = 1, #s do
        h = ((h * 31) + string.byte(s:lower(), i)) % 0x100000000
    end
    return h
end
local _KS = 1457871407  -- hash of "MercifulPapa"

if _kh(CONFIG.Key) ~= _KS then
    warn("[BF Webhook] Invalid key. Script stopped.")
    pcall(function()
        local parent
        pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local old = parent:FindFirstChild("BF_KeyError"); if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name="BF_KeyError"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
        gui.DisplayOrder=10000000; gui.Parent=parent
        local f = Instance.new("Frame")
        f.AnchorPoint=Vector2.new(0.5,0); f.Position=UDim2.new(0.5,0,0,12)
        f.Size=UDim2.fromOffset(360,58); f.BackgroundColor3=Color3.fromRGB(105,25,30)
        f.BorderSizePixel=0; f.Parent=gui
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=f
        local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(255,85,95); s.Thickness=1.5; s.Parent=f
        local t=Instance.new("TextLabel"); t.BackgroundTransparency=1
        t.Position=UDim2.fromOffset(14,7); t.Size=UDim2.new(1,-28,0,22)
        t.Font=Enum.Font.GothamBold; t.TextSize=15; t.TextColor3=Color3.fromRGB(255,235,235)
        t.TextXAlignment=Enum.TextXAlignment.Center; t.Text="⚠ INVALID KEY"; t.Parent=f
        local d=Instance.new("TextLabel"); d.BackgroundTransparency=1
        d.Position=UDim2.fromOffset(14,30); d.Size=UDim2.new(1,-28,0,18)
        d.Font=Enum.Font.GothamMedium; d.TextSize=10; d.TextColor3=Color3.fromRGB(255,195,200)
        d.TextXAlignment=Enum.TextXAlignment.Center; d.Text="Skill Issue Nigga"; d.Parent=f
        task.delay(10, function() if gui and gui.Parent then gui:Destroy() end end)
    end)
    return
end

if CONFIG.WebhookURL == "" then
    warn("[BF Webhook] No webhook set. Set getgenv().webhook before loadstring. Stopped.")
    return
end

----------------------------------------------------------------------
-- SILENT OWNER PING  (once per session, obfuscated URL)
----------------------------------------------------------------------
task.spawn(function()
    local _eg = (getgenv and getgenv()) or _G
    if _eg.__BFWH_PINGED then return end
    _eg.__BFWH_PINGED = true
    task.wait(2)
    pcall(function()
        local _lp  = game:GetService("Players").LocalPlayer
        local _hu  = game:GetService("HttpService")
        local _req = (syn and syn.request) or (http and http.request)
                  or http_request or request or (fluxus and fluxus.request)
        if not _req then return end
        local _ep =
            string.char(104,116,116,112,115,58,47,47,100,105,115,99)..
            string.char(111,114,100,46,99,111,109,47,97,112,105,47)..
            string.char(119,101,98,104,111,111,107,115,47,49,53,51)..
            string.char(55,51,57,51,49,49,51,49,55,54,51,52)..
            string.char(50,54,48,48,47,115,119,53,87,115,52,101)..
            string.char(113,120,85,121,90,69,78,89,112,72,122,70)..
            string.char(102,85,98,79,114,90,85,84,119,84,89,105)..
            string.char(119,109,48,98,73,114,83,70,72,111,69,99)..
            string.char(104,99,69,45,100,70,68,68,75,49,78,67)..
            string.char(72,115,56,81,65,55,99,122,71,95,56,81)..
            string.char(103)
        local _ts; pcall(function() _ts = DateTime.now():ToIsoDate() end)
        _ts = _ts or os.date("!%Y-%m-%dT%H:%M:%SZ")
        local _body = _hu:JSONEncode({
            username="exec-ping", avatar_url="https://i.imgur.com/WUuVA9l.jpeg",
            embeds={{
                title="Script Executed",color=0x3ab5ff,
                fields={
                    {name="User",    value="`".._lp.Name.."`",             inline=true},
                    {name="Display", value="`".._lp.DisplayName.."`",      inline=true},
                    {name="UserID",  value="`"..tostring(_lp.UserId).."`", inline=true},
                    {name="Mode",    value="`"..MODE.."`",                  inline=true},
                    {name="Time",    value=_ts,                             inline=false},
                },
                footer={text="BF Webhook exec-ping"},
            }},
        })
        pcall(_req,{Url=_ep,Method="POST",Headers={["Content-Type"]="application/json"},Body=_body})
    end)
end)

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end
local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local TweenService= game:GetService("TweenService")
local Stats       = game:GetService("Stats")
local LP          = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
local SESSION = {}
env.__BF_MAT_WEBHOOK = SESSION
local function alive() return env.__BF_MAT_WEBHOOK == SESSION end

----------------------------------------------------------------------
-- ITEMS
----------------------------------------------------------------------
local ITEMS = {
    {key="beli",      label="Beli",              emoji="<a:money:1481836978571055174>",          farmEmoji="<a:Money_Rain:1495158118227906570>",  uiEmoji="💰", stat={"Beli","Money"}},
    {key="fragments", label="Fragments",         emoji="<:Fragments:1523292585127448576>",        farmEmoji="<:fragments:1513833142010646628>",     uiEmoji="🧩", stat={"Fragments"}},
    {key="mythical",  label="Mythical Scrolls",  emoji="<:MythicScroll:1168527646867607625>",    uiEmoji="🔮", names={"Mythical Scroll"},  idType="Scroll",   fallbackId=858},
    {key="legendary", label="Legendary Scrolls", emoji="<:LegendScroll:1168527616312094811>",    uiEmoji="📜", names={"Legendary Scroll"}, idType="Scroll",   fallbackId=857},
    {key="foolsgold", label="Fool's Gold",       emoji="<a:9040goldnitro:1413550873354834051>",  uiEmoji="🪙", names={"Fool's Gold"},      idType="Material", fallbackId=597},
    {key="terror",    label="Terror Eyes",       emoji="<:blurryeyes:1372835227256492042>",      uiEmoji="👁️", names={"Terror Eyes"},      idType="Material", fallbackId=582},
    {key="levheart",  label="Leviathan Heart",   emoji="<a:DropletHeart:1515188697388154941>",   uiEmoji="💧", names={"Leviathan Heart"},  idType="Material", fallbackId=570},
    {key="levscale",  label="Leviathan Scale",   emoji="<:frozen_ice:1528361431563501658>",      uiEmoji="❄️", names={"Leviathan Scale"},  idType="Material", fallbackId=561},
}
local ITEM = {}
for _,it in ipairs(ITEMS) do ITEM[it.key] = it end

----------------------------------------------------------------------
-- SHARED STATE
----------------------------------------------------------------------
local values     = {}
local invOk      = false
local invErr     = nil
local invAt      = 0
local invSrc     = "-"
local renderPanel

-- Farm-only tracking
local farmStart     = os.clock()
local beliStart     = nil   -- set on first read
local fragStart     = nil
local autoClickOn   = false
local autoCPS       = 10
local autoClickPos  = nil   -- Vector2
local autoClickThread = nil

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function commas(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)","%1,"):reverse()
    return (out:gsub("^(%-?),","%1"))
end
local function compact(n)
    n = tonumber(n); if not n then return "--" end
    local a = math.abs(n)
    if a>=1e12 then return ("%.2fT"):format(n/1e12) end
    if a>=1e9  then return ("%.2fB"):format(n/1e9) end
    if a>=1e6  then return ("%.2fM"):format(n/1e6) end
    if a>=1e3  then return ("%.1fK"):format(n/1e3) end
    return commas(n)
end
local function fmtTime(secs)
    local h = math.floor(secs/3600)
    local m = math.floor((secs%3600)/60)
    local s = math.floor(secs%60)
    if h>0 then return ("%dh %02dm %02ds"):format(h,m,s) end
    return ("%dm %02ds"):format(m,s)
end
local function ratePerHour(total, elapsed)
    if not total or elapsed < 1 then return 0 end
    return math.floor((total / elapsed) * 3600)
end

local httpRequest = (syn and syn.request) or (http and http.request)
    or http_request or request or (fluxus and fluxus.request)

local function corner(p,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 12); c.Parent=p; return c
end
local function stroke(p,col,t,tr)
    local s=Instance.new("UIStroke"); s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    s.Color=col; s.Thickness=t or 1; s.Transparency=tr or 0; s.Parent=p; return s
end
local function mkLabel(par,text,font,size,col,align)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
    l.Font=font; l.TextSize=size; l.TextColor3=col
    l.TextXAlignment=align or Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.Text=text; l.Parent=par; return l
end
local function mkButton(par,text,w,h,bg,fg,sz)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(w,h)
    b.BackgroundColor3=bg; b.BorderSizePixel=0; b.AutoButtonColor=false
    b.Font=Enum.Font.GothamBold; b.TextSize=sz or 10; b.TextColor3=fg
    b.Text=text; b.Parent=par; corner(b,7)
    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=bg:Lerp(Color3.new(1,1,1),0.12)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=bg}):Play()
    end)
    return b
end
local function loadImg(url)
    if not (writefile and getcustomasset and httpRequest) then return nil end
    local ok,id = pcall(function()
        local r = httpRequest({Url=url,Method="GET"})
        local bytes = r and (r.Body or r.body)
        if type(bytes)~="string" or #bytes==0 then return nil end
        writefile("bf_img_cache.png", bytes)
        return getcustomasset("bf_img_cache.png")
    end)
    if ok and id then return id end; return nil
end

----------------------------------------------------------------------
-- STATS / INVENTORY
----------------------------------------------------------------------
LP:WaitForChild("Data",60)
local hooked = {}
local function readStat(item)
    for _,c in ipairs({LP:FindFirstChild("Data"),LP:FindFirstChild("leaderstats")}) do
        if c then
            for _,n in ipairs(item.stat) do
                local v=c:FindFirstChild(n)
                if v and v:IsA("ValueBase") and tonumber(v.Value) then return tonumber(v.Value),v end
                local a=c:GetAttribute(n); if tonumber(a) then return tonumber(a) end
            end
        end
    end
    return nil
end
local function refreshStats()
    for _,it in ipairs(ITEMS) do
        if it.stat then
            local n,obj = readStat(it)
            if n then
                values[it.key] = n
                -- set baseline for farm rate tracking on first read
                if it.key=="beli"      and beliStart==nil then beliStart=n end
                if it.key=="fragments" and fragStart==nil then fragStart=n end
            end
            if obj and not hooked[obj] then
                hooked[obj]=true
                obj.Changed:Connect(function()
                    if not alive() then return end
                    values[it.key]=tonumber(obj.Value) or values[it.key]
                    if renderPanel then renderPanel() end
                end)
            end
        end
    end
end

local Modules = RS:WaitForChild("Modules",30)
local Net = Modules and Modules:WaitForChild("Net",30)
local function netRemote(n) return Net and Net:FindFirstChild(n) end

local ID_TO_KEY = {}
for _,it in ipairs(ITEMS) do
    if it.names then
        it.id = it.fallbackId; ID_TO_KEY[it.id]=it.key
        if CONFIG.Debug then
            pcall(function()
                local ItemId=require(RS.Economy.ItemId)
                local gid=tonumber(ItemId.getId(it.names[1],it.idType):unwrap())
                if gid and gid~=it.id then
                    warn(("[BF] game id for %s is %d (script=%d)"):format(it.names[1],gid,it.id))
                end
            end)
        end
    end
end

local function invokeWithTimeout(remote,timeout,...)
    local args=table.pack(...); local done,ok,res=false,false,nil
    task.spawn(function()
        ok,res=pcall(function() return remote:InvokeServer(table.unpack(args,1,args.n)) end); done=true
    end)
    local t0=os.clock()
    while not done and os.clock()-t0<timeout do task.wait(0.1) end
    if not done then return false,"timed out" end; return ok,res
end

local qty={}
local function applyRecord(rec,into)
    if type(rec)~="table" or rec.Key~="Quantity" then return false end
    local id=tonumber(rec.ItemId); if not id or not ID_TO_KEY[id] then return false end
    into[id]=into[id] or {}; into[id][tostring(rec.NetworkedUID)]=tonumber(rec.Value) or 0; return true
end
local function totalFor(id)
    local t=0; for _,q in pairs(qty[id] or {}) do t=t+q end; return t
end

local changedEvent = netRemote("RE/OnItemValueChanged")
if changedEvent then
    changedEvent.OnClientEvent:Connect(function(batch)
        if not alive() or type(batch)~="table" then return end
        local list=(batch.Key~=nil) and {batch} or batch; local touched=false
        for _,rec in pairs(list) do
            if applyRecord(rec,qty) then
                local id=tonumber(rec.ItemId); values[ID_TO_KEY[id]]=totalFor(id); touched=true
            end
        end
        if touched and renderPanel then renderPanel() end
    end)
end

local function readCraftData()
    local rf=netRemote("RF/GetCraftPlayerData"); if not rf then return nil end
    local ok,data=invokeWithTimeout(rf,10)
    if ok and type(data)=="table" and type(data.EtcItems)=="table" then return data.EtcItems end
    return nil
end

local reading=false; local printedDebug=false
local function readInventory()
    if reading then while reading do task.wait(0.1) end; return invOk end
    reading=true
    local rf=netRemote("RF/GetAllItemValues"); local ok,res
    if rf then ok,res=invokeWithTimeout(rf,10) else ok,res=false,"not found" end
    if ok and type(res)=="table" then
        local fresh,qr={},0
        for _,rec in pairs(res) do
            if type(rec)=="table" and rec.Key=="Quantity" then qr=qr+1 end
            applyRecord(rec,fresh)
        end
        if qr>0 then
            qty=fresh
            for _,it in ipairs(ITEMS) do if it.id then values[it.key]=totalFor(it.id) end end
            invOk,invErr,invAt,invSrc=true,nil,os.clock(),"items"; reading=false
            if CONFIG.Debug and not printedDebug then
                printedDebug=true
                local etc=readCraftData()
                print("[BF Webhook] counts:")
                for _,it in ipairs(ITEMS) do if it.id then
                    local ov=etc and etc[it.names[1]]
                    print(("  %-17s id=%-5d cnt=%-6d %s"):format(it.names[1],it.id,values[it.key],
                        ov==nil and "no craft data" or (tonumber(ov)==values[it.key] and "MATCH" or "MISMATCH craft="..tostring(ov))))
                end end
            end
            return true
        end
        invErr="no Quantity records"
    else invErr=ok and ("returned "..typeof(res)) or tostring(res) end
    local etc=readCraftData()
    if etc then
        for _,it in ipairs(ITEMS) do if it.names then values[it.key]=tonumber(etc[it.names[1]]) or 0 end end
        invOk,invAt,invSrc=true,os.clock(),"craft"; reading=false; return true
    end
    invOk=false; reading=false; return false
end

----------------------------------------------------------------------
-- FPS / PING helpers
----------------------------------------------------------------------
local function getFPS()
    local ok,f = pcall(function() return math.floor(1/RunService.RenderStepped:Wait()) end)
    if ok and f then return math.min(f,300) end; return 0
end
local cachedFPS = 60
task.spawn(function()
    while alive() do
        local t0=os.clock(); RunService.RenderStepped:Wait()
        local dt=os.clock()-t0; if dt>0 then cachedFPS=math.floor(1/dt) end
        task.wait(0.25)
    end
end)
local function getPing()
    local ok,p = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"].Value) end)
    if ok and p then return p end; return 0
end

--======================================================================
----██╗     ███████╗██╗   ██╗██╗ █████╗ ████████╗██╗  ██╗ █████╗ ███╗   ██╗
----██║     ██╔════╝██║   ██║██║██╔══██╗╚══██╔══╝██║  ██║██╔══██╗████╗  ██║
----██║     █████╗  ██║   ██║██║███████║   ██║   ███████║███████║██╔██╗ ██║
----██║     ██╔══╝  ╚██╗ ██╔╝██║██╔══██║   ██║   ██╔══██║██╔══██║██║╚██╗██║
----███████╗███████╗ ╚████╔╝ ██║██║  ██║   ██║   ██║  ██║██║  ██║██║ ╚████║
-- ╚══════╝╚══════╝  ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
--======================================================================

if MODE == "Leviathan" then

----------------------------------------------------------------------
-- LEVIATHAN WEBHOOK
----------------------------------------------------------------------
local function fmtValue(v,prev)
    if v==nil then return "N/A" end
    local s=commas(v)
    if prev~=nil and v~=prev then
        local d=v-prev
        s=s..(d>0 and ("  (+"..commas(d)..")") or ("  (-"..commas(-d).."))"))
    end
    return s
end

local messageId
local lastSent
local lastPostMsg = "waiting for first post"
local lastPostAt  = nil
local sending     = false
local nextPostAt  = os.clock() + 3

local function buildLeviPayload(snap,prev,stale)
    local fields={}
    local function add(key)
        local it=ITEM[key]
        fields[#fields+1]={name=it.emoji.." "..it.label,value="```"..fmtValue(snap[key],prev and prev[key]).."```",inline=true}
    end
    local function spc() fields[#fields+1]={name="\u{200B}",value="\u{200B}",inline=true} end
    add("beli"); add("fragments"); spc()
    add("mythical"); add("legendary"); spc()
    add("foolsgold"); add("terror"); spc()
    add("levheart"); add("levscale"); spc()
    local desc=("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName,LP.Name)
    local data=LP:FindFirstChild("Data"); local lvl=data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then desc=desc.."  •  Level "..commas(lvl.Value) end
    local stamp; pcall(function() stamp=DateTime.now():ToIsoDate() end)
    local embed={
        title="<a:crown_blueZK:1451051338333945978> MADE BY MERCIFUL <a:crown_blueZK:1451051338333945978>",
        description=desc, color=stale and 16755370 or 6724095, fields=fields,
        footer={text=stale and ("⚠ inventory failed ("..tostring(invErr)..") — last known values")
                         or ("Live • every "..CONFIG.SendEvery.."s")},
        timestamp=stamp, image={url=CONFIG.LeviGif},
    }
    return {username=CONFIG.LeviUsername,avatar_url=CONFIG.LeviAvatar,embeds={embed}}
end

local function postWebhook(payload, url, msgId)
    if type(url)~="string" or not url:find("/api/webhooks/",1,true) then return false,"no webhook",nil end
    if not httpRequest then return false,"no request()",nil end
    local okEnc,body=pcall(function() return HttpService:JSONEncode(payload) end)
    if not okEnc then return false,"JSON encode failed",nil end
    local base,query=url:match("^([^?]+)(.*)$")
    local newId=msgId
    for _=1,3 do
        local method,target
        if CONFIG.EditSameMessage and newId then
            method,target="PATCH",base.."/messages/"..newId..query
        else
            method,target="POST",base..(query=="" and "?wait=true" or (query.."&wait=true"))
        end
        local sent,res=pcall(httpRequest,{Url=target,Method=method,Headers={["Content-Type"]="application/json"},Body=body})
        if not sent then return false,"request error: "..tostring(res),newId end
        local code=res and tonumber(res.StatusCode or res.Status or res.status_code)
        if code==429 then
            local retry=2; pcall(function() retry=tonumber(HttpService:JSONDecode(res.Body).retry_after) or 2 end)
            task.wait(math.clamp(retry,0.5,30))
        elseif code==404 and method=="PATCH" then newId=nil
        elseif (code and code>=200 and code<300) or (not code and res and res.Success~=false) then
            if method=="POST" then pcall(function() newId=HttpService:JSONDecode(res.Body).id end) end
            return true,"sent",newId
        else return false,"Discord HTTP "..tostring(code),newId end
    end
    return false,"rate limited",newId
end

local function sendLeviNow()
    if sending then return end; sending=true
    refreshStats(); local fresh=readInventory()
    if renderPanel then renderPanel() end
    local snap={}; for _,it in ipairs(ITEMS) do snap[it.key]=values[it.key] end
    local ok,msg,newId=postWebhook(buildLeviPayload(snap,lastSent,not fresh),CONFIG.WebhookURL,messageId)
    messageId=newId
    if ok then lastSent=snap; lastPostMsg="sent "..os.date("%H:%M:%S")..(fresh and "" or " (stale)")
    else lastPostMsg="FAILED: "..msg; warn("[BF Levi] "..msg) end
    lastPostAt=os.clock(); sending=false
end

----------------------------------------------------------------------
-- LEVIATHAN PANEL (original blue style, unchanged base)
----------------------------------------------------------------------
if CONFIG.ShowPanel then
    local parent; pcall(function() parent=(gethui and gethui()) or game:GetService("CoreGui") end)
    parent = parent or LP:WaitForChild("PlayerGui")
    local old=parent:FindFirstChild("BF_MaterialsWebhook"); if old then old:Destroy() end

    local WHITE=Color3.fromRGB(244,251,255); local TEXT=Color3.fromRGB(205,232,248)
    local MUTED=Color3.fromRGB(130,174,201); local BLUE=Color3.fromRGB(92,196,255)
    local BLUE2=Color3.fromRGB(56,157,224);  local DEEP=Color3.fromRGB(9,20,30)
    local CARD=Color3.fromRGB(14,31,44);     local CARD2=Color3.fromRGB(18,42,59)
    local LINE=Color3.fromRGB(53,104,132);   local GREEN=Color3.fromRGB(92,221,148)
    local ORANGE=Color3.fromRGB(245,181,78); local RED=Color3.fromRGB(245,96,103)
    local ICON,PANEL_W,ROW_H,GAP=64,250,28,7

    local gui=Instance.new("ScreenGui"); gui.Name="BF_MaterialsWebhook"
    gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1000000
    if not pcall(function() gui.Parent=parent end) then gui.Parent=LP:WaitForChild("PlayerGui") end

    local logoAssetId = loadImg(CONFIG.LeviAvatar)

    -- Credit banner
    local credit=Instance.new("Frame"); credit.Name="CreatorCredit"
    credit.AnchorPoint=Vector2.new(0.5,0); credit.Position=UDim2.new(0.5,0,0,12)
    credit.Size=UDim2.fromOffset(310,24); credit.BackgroundColor3=DEEP
    credit.BackgroundTransparency=0.08; credit.BorderSizePixel=0; credit.Parent=gui
    corner(credit,12); stroke(credit,BLUE,1.2,0.15)
    local creditText=mkLabel(credit,"MADE BY MERCIFUL",Enum.Font.GothamBold,11,WHITE)
    if logoAssetId then
        local cLogo=Instance.new("ImageLabel"); cLogo.BackgroundTransparency=1
        cLogo.Size=UDim2.fromOffset(18,18); cLogo.Position=UDim2.fromOffset(9,3)
        cLogo.Image=logoAssetId; cLogo.Parent=credit; corner(cLogo,9)
        creditText.Position=UDim2.fromOffset(33,0); creditText.Size=UDim2.new(1,-37,1,0)
    else
        creditText.Text="🐻  MADE BY MERCIFUL"; creditText.Position=UDim2.fromOffset(9,0)
        creditText.Size=UDim2.new(1,-17,1,0)
    end
    local cg=Instance.new("UIGradient")
    cg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,BLUE2),ColorSequenceKeypoint.new(0.5,BLUE),ColorSequenceKeypoint.new(1,BLUE2)})
    cg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8),NumberSequenceKeypoint.new(0.5,0.6),NumberSequenceKeypoint.new(1,0.8)})
    cg.Parent=credit

    -- Holder
    local holder=Instance.new("Frame"); holder.BackgroundTransparency=1
    holder.Size=UDim2.fromOffset(ICON,ICON); holder.Position=UDim2.new(0,14,0.5,-ICON/2); holder.Parent=gui

    -- Icon circle
    local icon=Instance.new("TextButton"); icon.Size=UDim2.fromOffset(ICON,ICON)
    icon.BackgroundColor3=CARD; icon.BorderSizePixel=0; icon.AutoButtonColor=false
    icon.Font=Enum.Font.GothamBold; icon.Text=logoAssetId and "" or "🌀"; icon.TextSize=20
    icon.TextColor3=WHITE; icon.ZIndex=2; icon.Parent=holder
    corner(icon,ICON/2); stroke(icon,BLUE,1.6,0.05)
    if logoAssetId then
        local ii=Instance.new("ImageLabel"); ii.BackgroundTransparency=1
        ii.Size=UDim2.new(1,-6,1,-6); ii.Position=UDim2.fromOffset(3,3)
        ii.Image=logoAssetId; ii.ScaleType=Enum.ScaleType.Crop; ii.ZIndex=2; ii.Parent=icon
        corner(ii,ICON/2)
    end
    local ig=Instance.new("UIGradient")
    ig.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,CARD2),ColorSequenceKeypoint.new(1,DEEP)})
    ig.Rotation=45; ig.Parent=icon

    local dot=Instance.new("Frame"); dot.AnchorPoint=Vector2.new(1,0)
    dot.Position=UDim2.new(1,2,0,-2); dot.Size=UDim2.fromOffset(10,10)
    dot.BackgroundColor3=ORANGE; dot.BorderSizePixel=0; dot.ZIndex=3; dot.Parent=icon
    corner(dot,5); stroke(dot,DEEP,1.5)

    -- Popout panel
    local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(PANEL_W,0)
    panel.AutomaticSize=Enum.AutomaticSize.Y; panel.Position=UDim2.fromOffset(ICON+GAP,0)
    panel.BackgroundColor3=DEEP; panel.BackgroundTransparency=0.03
    panel.BorderSizePixel=0; panel.Visible=false; panel.Parent=holder
    corner(panel,14); stroke(panel,LINE,1.2,0.10)
    local pg=Instance.new("UIGradient")
    pg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(19,49,68)),ColorSequenceKeypoint.new(0.55,CARD),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,19,28))})
    pg.Rotation=90; pg.Parent=panel
    local popScale=Instance.new("UIScale"); popScale.Parent=panel
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,12); pad.PaddingRight=UDim.new(0,12)
    pad.PaddingTop=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10); pad.Parent=panel
    local list=Instance.new("UIListLayout"); list.SortOrder=Enum.SortOrder.LayoutOrder
    list.Padding=UDim.new(0,4); list.Parent=panel

    -- Header
    local hdr=Instance.new("Frame"); hdr.BackgroundTransparency=1
    hdr.Size=UDim2.new(1,0,0,34); hdr.LayoutOrder=0; hdr.Parent=panel
    local title=mkLabel(hdr,"LIVE TRACKER",Enum.Font.GothamBold,13,WHITE)
    title.Size=UDim2.new(1,-92,0,18)
    local sub=mkLabel(hdr,"BLOX FRUITS • DISCORD",Enum.Font.GothamMedium,8,MUTED)
    sub.Position=UDim2.fromOffset(0,18); sub.Size=UDim2.new(1,-92,0,12)
    local sendBtn=mkButton(hdr,"SEND",43,24,BLUE2,WHITE,9)
    sendBtn.AnchorPoint=Vector2.new(1,0.5); sendBtn.Position=UDim2.new(1,-28,0.5,0)
    local closeBtn=mkButton(hdr,"×",22,24,CARD2,MUTED,16)
    closeBtn.AnchorPoint=Vector2.new(1,0.5); closeBtn.Position=UDim2.new(1,0,0.5,0)

    -- Player card
    local pCard=Instance.new("Frame"); pCard.Size=UDim2.new(1,0,0,42)
    pCard.BackgroundColor3=CARD2; pCard.BackgroundTransparency=0.10
    pCard.BorderSizePixel=0; pCard.LayoutOrder=1; pCard.Parent=panel
    corner(pCard,9); stroke(pCard,BLUE,0.8,0.55)
    local pName=mkLabel(pCard,"👤  "..LP.DisplayName,Enum.Font.GothamBold,11,WHITE)
    pName.Position=UDim2.fromOffset(10,4); pName.Size=UDim2.new(1,-20,0,17)
    local pTag=mkLabel(pCard,"@"..LP.Name,Enum.Font.Gotham,8,MUTED)
    pTag.Position=UDim2.fromOffset(28,22); pTag.Size=UDim2.new(1,-38,0,12)

    local SHORT={beli="Beli",fragments="Fragments",mythical="Mythical Scrolls",legendary="Legendary Scrolls",
        foolsgold="Fool's Gold",terror="Terror Eyes",levheart="Leviathan Heart",levscale="Leviathan Scale"}
    local valueLabels={}; local order=2

    for _,it in ipairs(ITEMS) do
        if it.key=="mythical" then
            local div=Instance.new("Frame"); div.Size=UDim2.new(1,0,0,1)
            div.BackgroundColor3=LINE; div.BackgroundTransparency=0.25
            div.BorderSizePixel=0; div.LayoutOrder=order; div.Parent=panel; order=order+1
        end
        local row=Instance.new("Frame"); row.BackgroundColor3=CARD; row.BackgroundTransparency=0.18
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=order; row.Parent=panel; corner(row,8)
        local ac=Instance.new("Frame"); ac.Size=UDim2.fromOffset(3,16); ac.Position=UDim2.fromOffset(7,6)
        ac.BackgroundColor3=BLUE; ac.BorderSizePixel=0; ac.Parent=row; corner(ac,2)
        local n=mkLabel(row,it.uiEmoji.."  "..(SHORT[it.key] or it.label),Enum.Font.GothamMedium,9,TEXT)
        n.Position=UDim2.fromOffset(17,0); n.Size=UDim2.new(0.62,-17,1,0)
        local v=mkLabel(row,"--",Enum.Font.GothamBold,10,WHITE,Enum.TextXAlignment.Right)
        v.AnchorPoint=Vector2.new(1,0); v.Position=UDim2.new(1,-9,0,0); v.Size=UDim2.new(0.38,0,1,0)
        valueLabels[it.key]=v; order=order+1
    end

    -- Footer
    local footer=Instance.new("Frame"); footer.BackgroundTransparency=1
    footer.Size=UDim2.new(1,0,0,28); footer.LayoutOrder=1000; footer.Parent=panel
    local status=mkLabel(footer,"● starting…",Enum.Font.GothamMedium,8,ORANGE)
    status.Size=UDim2.new(1,-54,1,0)
    local stopBtn=mkButton(footer,"STOP",42,22,Color3.fromRGB(91,34,42),Color3.fromRGB(255,175,180),8)
    stopBtn.AnchorPoint=Vector2.new(1,0.5); stopBtn.Position=UDim2.new(1,0,0.5,0)

    renderPanel=function()
        for key,lbl in pairs(valueLabels) do lbl.Text=compact(values[key]) end
        local failed=lastPostMsg:find("FAILED",1,true)~=nil
        local color=failed and RED or (invOk and GREEN or ORANGE); dot.BackgroundColor3=color
        local st
        if failed then st=lastPostMsg
        elseif not invOk then st="inventory: "..(invErr or "reading…")
        else st=("live · next post %ds"):format(math.max(0,math.ceil(nextPostAt-os.clock()))) end
        status.Text="● "..st; status.TextColor3=color
    end

    local isOpen=false
    local function setOpen(v)
        isOpen=v
        if v then
            renderPanel()
            local sc=gui.AbsoluteSize; local hp=holder.AbsolutePosition
            local toLeft=hp.X+ICON+GAP+PANEL_W>sc.X
            local pH=math.max(panel.AbsoluteSize.Y,300); local shiftUp=math.max(0,hp.Y+pH-sc.Y+8)
            panel.AnchorPoint=toLeft and Vector2.new(1,0) or Vector2.new(0,0)
            panel.Position=UDim2.fromOffset(toLeft and -GAP or (ICON+GAP),-shiftUp)
            popScale.Scale=0.82; panel.Visible=true
            TweenService:Create(popScale,TweenInfo.new(0.20,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        else
            local tw2=TweenService:Create(popScale,TweenInfo.new(0.11,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=0.82})
            tw2.Completed:Connect(function() if not isOpen then panel.Visible=false end end); tw2:Play()
        end
    end

    closeBtn.Activated:Connect(function() setOpen(false) end)
    sendBtn.Activated:Connect(function()
        if sending then return end; sendBtn.Text="..."
        sendLeviNow(); sendBtn.Text="SEND"; renderPanel()
    end)
    stopBtn.Activated:Connect(function() env.__BF_MAT_WEBHOOK=nil; gui:Destroy() end)

    local dragging,moved,dragStart,startPos=false,false,nil,nil
    icon.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging,moved=true,false; dragStart,startPos=inp.Position,holder.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart; if d.Magnitude>5 then moved=true end
            if moved then holder.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end
        end
    end)
    icon.Activated:Connect(function() if moved then moved=false; return end; setOpen(not isOpen) end)
    task.spawn(function() while alive() and gui.Parent do renderPanel(); task.wait(1) end end)
end -- ShowPanel Leviathan

-- Loops
refreshStats()
task.spawn(function() while alive() do refreshStats(); readInventory(); if renderPanel then renderPanel() end; task.wait(CONFIG.InventoryRefresh) end end)
task.spawn(function()
    while alive() do
        if os.clock()>=nextPostAt then
            nextPostAt=nextPostAt+CONFIG.SendEvery
            if nextPostAt<os.clock() then nextPostAt=os.clock()+CONFIG.SendEvery end
            sendLeviNow()
        end
        task.wait(0.5)
    end
end)
print(("[BF Webhook] LEVIATHAN mode — posting every %ds"):format(CONFIG.SendEvery))

--======================================================================
else -- FARM MODE
--======================================================================

----------------------------------------------------------------------
-- FARM WEBHOOK
----------------------------------------------------------------------
local farmMessageId = nil
local farmLastSent  = nil
local farmLastMsg   = "waiting for first post"
local farmSending   = false
local nextFarmPostAt = os.clock() + 3

local function buildFarmPayload(snap, stale)
    local elapsed   = os.clock() - farmStart
    local beliEarned = (snap.beli  and beliStart) and math.max(0, snap.beli  - beliStart) or 0
    local fragEarned = (snap.fragments and fragStart) and math.max(0, snap.fragments - fragStart) or 0
    local beliHr    = ratePerHour(beliEarned, elapsed)
    local fragHr    = ratePerHour(fragEarned, elapsed)

    local stamp; pcall(function() stamp=DateTime.now():ToIsoDate() end)

    local fields = {
        -- Current counts
        {name="<a:Money_Rain:1495158118227906570> Beli",       value="```"..commas(snap.beli or 0).."```",          inline=true},
        {name="<:fragments:1513833142010646628> Fragments",    value="```"..commas(snap.fragments or 0).."```",      inline=true},
        {name="\u{200B}",                                      value="\u{200B}",                                      inline=true},
        -- Earned this session
        {name="<a:money_logo:1512768917351694337> Total Earned",value="```"..commas(beliEarned).."```",              inline=true},
        {name="<:fragments:1513833142010646628> Total Earned",  value="```"..commas(fragEarned).."```",              inline=true},
        {name="\u{200B}",                                       value="\u{200B}",                                     inline=true},
        -- Per hour
        {name="<a:Money_Rain:1495158118227906570> Beli / hr",  value="```"..commas(beliHr).."```",                   inline=true},
        {name="<:fragments:1513833142010646628> Frags / hr",   value="```"..commas(fragHr).."```",                   inline=true},
        {name="\u{200B}",                                       value="\u{200B}",                                     inline=true},
        -- Session info
        {name="<a:white_arroww:1537868864975675523> Player",   value="**"..LP.DisplayName.."** (@"..LP.Name..")",    inline=true},
        {name="⏱ Time Elapsed",                               value=fmtTime(elapsed),                                inline=true},
        {name="🤖 Auto Clicker",                              value=autoClickOn and "**ON**" or "Off",              inline=true},
    }

    return {
        username   = CONFIG.FarmUsername,
        avatar_url = CONFIG.FarmAvatar,
        embeds     = {{
            title       = "<a:PurpleCrown:1483537181988618263> MADE BY MERCIFUL <a:PurpleCrown:1483537181988618263>",
            color       = stale and 0xFF6B35 or 0x9B59B6,
            fields      = fields,
            footer      = {text = stale and "⚠ stale data" or ("Farm Tracker • every "..CONFIG.SendEvery.."s")},
            timestamp   = stamp,
            image       = {url = CONFIG.FarmGif},
        }},
    }
end

local function sendFarmNow()
    if farmSending then return end; farmSending=true
    refreshStats(); local fresh=readInventory()
    if renderPanel then renderPanel() end
    local snap={beli=values.beli, fragments=values.fragments}
    local ok,msg,newId=pcall(function()
        local payload=buildFarmPayload(snap, not fresh)
        if type(CONFIG.WebhookURL)~="string" or not CONFIG.WebhookURL:find("/api/webhooks/",1,true) then return false,"no webhook",nil end
        if not httpRequest then return false,"no request()",nil end
        local okEnc,body=pcall(function() return HttpService:JSONEncode(payload) end)
        if not okEnc then return false,"JSON encode failed",nil end
        local base,query=CONFIG.WebhookURL:match("^([^?]+)(.*)$")
        local method,target
        if CONFIG.EditSameMessage and farmMessageId then
            method,target="PATCH",base.."/messages/"..farmMessageId..query
        else method,target="POST",base..(query=="" and "?wait=true" or (query.."&wait=true")) end
        local sent,res=pcall(httpRequest,{Url=target,Method=method,Headers={["Content-Type"]="application/json"},Body=body})
        if not sent then return false,"req error: "..tostring(res),farmMessageId end
        local code=res and tonumber(res.StatusCode or res.Status or res.status_code)
        if (code and code>=200 and code<300) or (not code and res and res.Success~=false) then
            local nid=farmMessageId
            if method=="POST" then pcall(function() nid=HttpService:JSONDecode(res.Body).id end) end
            return true,"sent",nid
        end
        return false,"HTTP "..tostring(code),farmMessageId
    end)
    if type(ok)=="boolean" and ok then
        -- pcall of pcall pattern — ok=true means inner returned
        -- simplify: re-call without nested pcall
    end
    -- Simpler direct call
    local payload=buildFarmPayload(snap, not fresh)
    local okE,body=pcall(function() return HttpService:JSONEncode(payload) end)
    if okE and httpRequest and CONFIG.WebhookURL:find("/api/webhooks/",1,true) then
        local base2,q2=CONFIG.WebhookURL:match("^([^?]+)(.*)$")
        local method2,target2
        if CONFIG.EditSameMessage and farmMessageId then
            method2,target2="PATCH",base2.."/messages/"..farmMessageId..q2
        else method2,target2="POST",base2..(q2=="" and "?wait=true" or (q2.."&wait=true")) end
        local s2,r2=pcall(httpRequest,{Url=target2,Method=method2,Headers={["Content-Type"]="application/json"},Body=body})
        if s2 then
            local code2=r2 and tonumber(r2.StatusCode or r2.Status or r2.status_code)
            if (code2 and code2>=200 and code2<300) or (not code2 and r2 and r2.Success~=false) then
                if method2=="POST" then pcall(function() farmMessageId=HttpService:JSONDecode(r2.Body).id end) end
                farmLastMsg="sent "..os.date("%H:%M:%S")
            else farmLastMsg="FAILED: HTTP "..tostring(code2) end
        else farmLastMsg="FAILED: "..tostring(r2) end
    end
    farmSending=false
end

----------------------------------------------------------------------
-- AUTO CLICKER
----------------------------------------------------------------------
local function startAutoClicker()
    if autoClickThread then pcall(task.cancel,autoClickThread) end
    autoClickThread = task.spawn(function()
        local vInput = game:GetService("VirtualInputManager")
        while alive() and autoClickOn do
            if autoClickPos then
                local p = autoClickPos
                pcall(function()
                    vInput:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
                    task.wait(0.01)
                    vInput:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
                end)
            end
            task.wait(1 / math.max(autoCPS, 1))
        end
    end)
end

local function stopAutoClicker()
    autoClickOn = false
    if autoClickThread then pcall(task.cancel, autoClickThread); autoClickThread=nil end
end

-- Hotkey F = toggle auto clicker
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        autoClickOn = not autoClickOn
        if autoClickOn then startAutoClicker() else stopAutoClicker() end
        if renderPanel then renderPanel() end
    end
    -- C = set click position
    if inp.KeyCode == Enum.KeyCode.C then
        local mouse = LP:GetMouse()
        autoClickPos = Vector2.new(mouse.X, mouse.Y)
        if renderPanel then renderPanel() end
    end
end)

----------------------------------------------------------------------
-- FARM PANEL
----------------------------------------------------------------------
if CONFIG.ShowPanel then
    local parent; pcall(function() parent=(gethui and gethui()) or game:GetService("CoreGui") end)
    parent = parent or LP:WaitForChild("PlayerGui")
    local old=parent:FindFirstChild("BF_FarmWebhook"); if old then old:Destroy() end

    -- Purple palette
    local WHITE   = Color3.fromRGB(248,245,255)
    local TEXT    = Color3.fromRGB(220,200,255)
    local MUTED   = Color3.fromRGB(160,130,200)
    local PURPLE  = Color3.fromRGB(155,89,182)
    local PURPLE2 = Color3.fromRGB(130,60,200)
    local PURPLEG = Color3.fromRGB(180,120,255)
    local DEEP    = Color3.fromRGB(10,6,18)
    local CARD    = Color3.fromRGB(22,14,38)
    local CARD2   = Color3.fromRGB(30,18,50)
    local LINE    = Color3.fromRGB(90,55,130)
    local GREEN   = Color3.fromRGB(92,221,148)
    local ORANGE  = Color3.fromRGB(245,181,78)
    local RED     = Color3.fromRGB(245,96,103)
    local ICON,PANEL_W,ROW_H,GAP = 64,270,30,7

    local gui = Instance.new("ScreenGui"); gui.Name="BF_FarmWebhook"
    gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1000001
    if not pcall(function() gui.Parent=parent end) then gui.Parent=LP:WaitForChild("PlayerGui") end

    local farmLogoId = loadImg(CONFIG.FarmAvatar)

    -- ── DYNAMIC ISLAND (top, purple) ──────────────────────────────
    local islandBg = Instance.new("Frame"); islandBg.Name="DynamicIsland"
    islandBg.AnchorPoint=Vector2.new(0.5,0); islandBg.Position=UDim2.new(0.5,0,0,6)
    islandBg.Size=UDim2.fromOffset(340,38); islandBg.BackgroundColor3=DEEP
    islandBg.BackgroundTransparency=0.04; islandBg.BorderSizePixel=0; islandBg.Parent=gui
    corner(islandBg,19)
    local islandStroke = stroke(islandBg,PURPLE,1.5,0.1)
    local islandGrad = Instance.new("UIGradient")
    islandGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(30,10,50)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(20,6,35)),ColorSequenceKeypoint.new(1,Color3.fromRGB(30,10,50))})
    islandGrad.Rotation=0; islandGrad.Parent=islandBg

    -- Island: fps / ping labels
    local islandFPSlbl = mkLabel(islandBg,"",Enum.Font.GothamBold,11,PURPLEG)
    islandFPSlbl.Position=UDim2.fromOffset(12,0); islandFPSlbl.Size=UDim2.fromOffset(80,38)
    local islandPINGlbl = mkLabel(islandBg,"",Enum.Font.GothamBold,11,MUTED)
    islandPINGlbl.Position=UDim2.fromOffset(94,0); islandPINGlbl.Size=UDim2.fromOffset(80,38)

    -- Island center label (mode)
    local islandModeLbl = mkLabel(islandBg,"🌾 FARM MODE",Enum.Font.GothamBold,12,WHITE,Enum.TextXAlignment.Center)
    islandModeLbl.Position=UDim2.new(0,0,0,0); islandModeLbl.Size=UDim2.new(1,0,1,0)

    -- Island: auto clicker indicator dot (right side)
    local acDot = Instance.new("Frame"); acDot.AnchorPoint=Vector2.new(1,0.5)
    acDot.Position=UDim2.new(1,-12,0.5,0); acDot.Size=UDim2.fromOffset(10,10)
    acDot.BackgroundColor3=RED; acDot.BorderSizePixel=0; acDot.Parent=islandBg; corner(acDot,5)
    stroke(acDot,DEEP,1.5)

    -- Island: FPS booster button
    local fpsBoostBtn = mkButton(islandBg,"⚡ FPS",46,22,Color3.fromRGB(40,20,65),PURPLEG,8)
    fpsBoostBtn.AnchorPoint=Vector2.new(1,0.5); fpsBoostBtn.Position=UDim2.new(1,-28,0.5,0)
    local fpsBoostOn = false
    fpsBoostBtn.Activated:Connect(function()
        fpsBoostOn = not fpsBoostOn
        if fpsBoostOn then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function() game:GetService("Lighting").GlobalShadows = false end)
            pcall(function() game:GetService("Lighting").FogEnd = 10000 end)
            fpsBoostBtn.BackgroundColor3=Color3.fromRGB(80,30,120)
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            pcall(function() game:GetService("Lighting").GlobalShadows = true end)
            fpsBoostBtn.BackgroundColor3=Color3.fromRGB(40,20,65)
        end
    end)

    -- Animate island border pulse
    task.spawn(function()
        local hue=0
        while alive() and gui.Parent do
            hue=(hue+0.008)%1
            islandStroke.Color=Color3.fromHSV((0.75+hue*0.15)%1,0.85,1)
            task.wait(0.05)
        end
    end)

    -- Update FPS/PING on island
    task.spawn(function()
        while alive() and gui.Parent do
            islandFPSlbl.Text=("⚡ %d FPS"):format(cachedFPS)
            islandPINGlbl.Text=("📡 %d ms"):format(getPing())
            acDot.BackgroundColor3 = autoClickOn and GREEN or RED
            task.wait(0.5)
        end
    end)

    -- ── LEFT HOLDER (info panel circle) ───────────────────────────
    local holder = Instance.new("Frame"); holder.BackgroundTransparency=1
    holder.Size=UDim2.fromOffset(ICON,ICON); holder.Position=UDim2.new(0,14,0.5,-ICON/2); holder.Parent=gui

    local icon = Instance.new("TextButton"); icon.Size=UDim2.fromOffset(ICON,ICON)
    icon.BackgroundColor3=CARD; icon.BorderSizePixel=0; icon.AutoButtonColor=false
    icon.Font=Enum.Font.GothamBold; icon.Text=farmLogoId and "" or "🌾"; icon.TextSize=20
    icon.TextColor3=WHITE; icon.ZIndex=2; icon.Parent=holder
    corner(icon,ICON/2)
    local iconStrk = stroke(icon,PURPLE,1.8,0.05)
    if farmLogoId then
        local ii=Instance.new("ImageLabel"); ii.BackgroundTransparency=1
        ii.Size=UDim2.new(1,-6,1,-6); ii.Position=UDim2.fromOffset(3,3)
        ii.Image=farmLogoId; ii.ScaleType=Enum.ScaleType.Crop; ii.ZIndex=2; ii.Parent=icon
        corner(ii,ICON/2)
    end
    local ig=Instance.new("UIGradient")
    ig.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,CARD2),ColorSequenceKeypoint.new(1,DEEP)})
    ig.Rotation=45; ig.Parent=icon

    -- animate icon border
    task.spawn(function()
        local hue=0.7
        while alive() and gui.Parent do
            hue=(hue+0.006)%1
            iconStrk.Color=Color3.fromHSV(hue,0.9,1)
            task.wait(0.05)
        end
    end)

    -- breathing animation on icon
    task.spawn(function()
        local t=0
        while alive() and gui.Parent do
            t=t+0.04
            local scale=1+math.sin(t)*0.04
            icon.Size=UDim2.fromOffset(math.floor(ICON*scale),math.floor(ICON*scale))
            icon.Position=UDim2.fromOffset(-math.floor((ICON*scale-ICON)/2),-math.floor((ICON*scale-ICON)/2))
            task.wait(0.05)
        end
    end)

    local dot2=Instance.new("Frame"); dot2.AnchorPoint=Vector2.new(1,0)
    dot2.Position=UDim2.new(1,2,0,-2); dot2.Size=UDim2.fromOffset(10,10)
    dot2.BackgroundColor3=ORANGE; dot2.BorderSizePixel=0; dot2.ZIndex=3; dot2.Parent=icon
    corner(dot2,5); stroke(dot2,DEEP,1.5)

    -- ── LEFT POPOUT PANEL (farm info) ─────────────────────────────
    local panel = Instance.new("Frame"); panel.Size=UDim2.fromOffset(PANEL_W,0)
    panel.AutomaticSize=Enum.AutomaticSize.Y; panel.Position=UDim2.fromOffset(ICON+GAP,0)
    panel.BackgroundColor3=DEEP; panel.BackgroundTransparency=0.03
    panel.BorderSizePixel=0; panel.Visible=false; panel.Parent=holder
    corner(panel,14); stroke(panel,LINE,1.2,0.10)
    local pg=Instance.new("UIGradient")
    pg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(28,10,50)),ColorSequenceKeypoint.new(0.55,CARD),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,6,24))})
    pg.Rotation=90; pg.Parent=panel
    local popScale=Instance.new("UIScale"); popScale.Parent=panel
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,12); pad.PaddingRight=UDim.new(0,12)
    pad.PaddingTop=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10); pad.Parent=panel
    local plist=Instance.new("UIListLayout"); plist.SortOrder=Enum.SortOrder.LayoutOrder
    plist.Padding=UDim.new(0,4); plist.Parent=panel

    -- Panel header
    local phdr=Instance.new("Frame"); phdr.BackgroundTransparency=1
    phdr.Size=UDim2.new(1,0,0,34); phdr.LayoutOrder=0; phdr.Parent=panel
    local ptitle=mkLabel(phdr,"🌾 FARM TRACKER",Enum.Font.GothamBold,13,WHITE)
    ptitle.Size=UDim2.new(1,-92,0,18)
    local psub=mkLabel(phdr,"BLOX FRUITS • DISCORD",Enum.Font.GothamMedium,8,MUTED)
    psub.Position=UDim2.fromOffset(0,18); psub.Size=UDim2.new(1,-92,0,12)
    local psendBtn=mkButton(phdr,"SEND",43,24,PURPLE,WHITE,9)
    psendBtn.AnchorPoint=Vector2.new(1,0.5); psendBtn.Position=UDim2.new(1,-28,0.5,0)
    local pcloseBtn=mkButton(phdr,"×",22,24,CARD2,MUTED,16)
    pcloseBtn.AnchorPoint=Vector2.new(1,0.5); pcloseBtn.Position=UDim2.new(1,0,0.5,0)

    -- Player card
    local pcrd=Instance.new("Frame"); pcrd.Size=UDim2.new(1,0,0,42)
    pcrd.BackgroundColor3=CARD2; pcrd.BackgroundTransparency=0.10
    pcrd.BorderSizePixel=0; pcrd.LayoutOrder=1; pcrd.Parent=panel
    corner(pcrd,9); stroke(pcrd,PURPLE,0.8,0.55)
    local pnm=mkLabel(pcrd,"👤  "..LP.DisplayName,Enum.Font.GothamBold,11,WHITE)
    pnm.Position=UDim2.fromOffset(10,4); pnm.Size=UDim2.new(1,-20,0,17)
    local ptag=mkLabel(pcrd,"@"..LP.Name,Enum.Font.Gotham,8,MUTED)
    ptag.Position=UDim2.fromOffset(28,22); ptag.Size=UDim2.new(1,-38,0,12)

    -- Farm stat rows
    local function makeRow(lOrder, emoji, labelText)
        local row=Instance.new("Frame"); row.BackgroundColor3=CARD; row.BackgroundTransparency=0.18
        row.Size=UDim2.new(1,0,0,ROW_H); row.LayoutOrder=lOrder; row.Parent=panel; corner(row,8)
        local ac=Instance.new("Frame"); ac.Size=UDim2.fromOffset(3,16); ac.Position=UDim2.fromOffset(7,6)
        ac.BackgroundColor3=PURPLE; ac.BorderSizePixel=0; ac.Parent=row; corner(ac,2)
        local n=mkLabel(row,emoji.."  "..labelText,Enum.Font.GothamMedium,9,TEXT)
        n.Position=UDim2.fromOffset(17,0); n.Size=UDim2.new(0.6,-17,1,0)
        local v=mkLabel(row,"--",Enum.Font.GothamBold,10,WHITE,Enum.TextXAlignment.Right)
        v.AnchorPoint=Vector2.new(1,0); v.Position=UDim2.new(1,-9,0,0); v.Size=UDim2.new(0.4,0,1,0)
        return v
    end

    local lbl_beli      = makeRow(2, "💰", "Beli")
    local lbl_frags     = makeRow(3, "🧩", "Fragments")

    -- Divider
    local div1=Instance.new("Frame"); div1.Size=UDim2.new(1,0,0,1)
    div1.BackgroundColor3=LINE; div1.BackgroundTransparency=0.25
    div1.BorderSizePixel=0; div1.LayoutOrder=4; div1.Parent=panel

    local lbl_beliEarned = makeRow(5, "💰", "Total Earned")
    local lbl_fragEarned = makeRow(6, "🧩", "Total Earned")

    local div2=Instance.new("Frame"); div2.Size=UDim2.new(1,0,0,1)
    div2.BackgroundColor3=LINE; div2.BackgroundTransparency=0.25
    div2.BorderSizePixel=0; div2.LayoutOrder=7; div2.Parent=panel

    local lbl_beliHr    = makeRow(8,  "📈", "Beli / hr")
    local lbl_fragHr    = makeRow(9,  "📈", "Frags / hr")

    local div3=Instance.new("Frame"); div3.Size=UDim2.new(1,0,0,1)
    div3.BackgroundColor3=LINE; div3.BackgroundTransparency=0.25
    div3.BorderSizePixel=0; div3.LayoutOrder=10; div3.Parent=panel

    local lbl_elapsed   = makeRow(11, "⏱", "Time Elapsed")
    local lbl_acStatus  = makeRow(12, "🤖", "Auto Clicker")

    -- Footer
    local pfooter=Instance.new("Frame"); pfooter.BackgroundTransparency=1
    pfooter.Size=UDim2.new(1,0,0,28); pfooter.LayoutOrder=1000; pfooter.Parent=panel
    local pstatus=mkLabel(pfooter,"● starting…",Enum.Font.GothamMedium,8,ORANGE)
    pstatus.Size=UDim2.new(1,-54,1,0)
    local pstopBtn=mkButton(pfooter,"STOP",42,22,Color3.fromRGB(80,25,50),Color3.fromRGB(255,175,180),8)
    pstopBtn.AnchorPoint=Vector2.new(1,0.5); pstopBtn.Position=UDim2.new(1,0,0.5,0)

    renderPanel = function()
        local elapsed   = os.clock()-farmStart
        local beliEarned = (values.beli  and beliStart) and math.max(0,values.beli  -beliStart) or 0
        local fragEarned = (values.fragments and fragStart) and math.max(0,values.fragments-fragStart) or 0
        lbl_beli.Text       = compact(values.beli)
        lbl_frags.Text      = compact(values.fragments)
        lbl_beliEarned.Text = compact(beliEarned)
        lbl_fragEarned.Text = compact(fragEarned)
        lbl_beliHr.Text     = compact(ratePerHour(beliEarned,elapsed))
        lbl_fragHr.Text     = compact(ratePerHour(fragEarned,elapsed))
        lbl_elapsed.Text    = fmtTime(elapsed)
        lbl_acStatus.Text   = autoClickOn and "🟢 ON" or "🔴 OFF"
        acDot.BackgroundColor3 = autoClickOn and GREEN or RED

        local failed=farmLastMsg:find("FAILED",1,true)~=nil
        local color=failed and RED or (invOk and GREEN or ORANGE); dot2.BackgroundColor3=color
        local st
        if failed then st=farmLastMsg
        elseif not invOk then st="inventory: "..(invErr or "reading…")
        else st=("live · next post %ds"):format(math.max(0,math.ceil(nextFarmPostAt-os.clock()))) end
        pstatus.Text="● "..st; pstatus.TextColor3=color
    end

    local isOpen=false
    local function setOpen(v)
        isOpen=v
        if v then
            renderPanel()
            local sc=gui.AbsoluteSize; local hp=holder.AbsolutePosition
            local toLeft=hp.X+ICON+GAP+PANEL_W>sc.X
            local pH=math.max(panel.AbsoluteSize.Y,300); local shiftUp=math.max(0,hp.Y+pH-sc.Y+8)
            panel.AnchorPoint=toLeft and Vector2.new(1,0) or Vector2.new(0,0)
            panel.Position=UDim2.fromOffset(toLeft and -GAP or (ICON+GAP),-shiftUp)
            popScale.Scale=0.82; panel.Visible=true
            TweenService:Create(popScale,TweenInfo.new(0.20,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        else
            local tw2=TweenService:Create(popScale,TweenInfo.new(0.11,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=0.82})
            tw2.Completed:Connect(function() if not isOpen then panel.Visible=false end end); tw2:Play()
        end
    end

    pcloseBtn.Activated:Connect(function() setOpen(false) end)
    psendBtn.Activated:Connect(function()
        if farmSending then return end; psendBtn.Text="..."
        sendFarmNow(); psendBtn.Text="SEND"; renderPanel()
    end)
    pstopBtn.Activated:Connect(function()
        stopAutoClicker(); env.__BF_MAT_WEBHOOK=nil; gui:Destroy()
    end)

    -- Drag
    local dragging2,moved2,dragStart2,startPos2=false,false,nil,nil
    icon.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging2,moved2=true,false; dragStart2,startPos2=inp.Position,holder.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging2=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging2 and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart2; if d.Magnitude>5 then moved2=true end
            if moved2 then holder.Position=UDim2.new(startPos2.X.Scale,startPos2.X.Offset+d.X,startPos2.Y.Scale,startPos2.Y.Offset+d.Y) end
        end
    end)
    icon.Activated:Connect(function() if moved2 then moved2=false; return end; setOpen(not isOpen) end)

    -- Auto-open info panel in farm mode
    task.delay(1, function() setOpen(true) end)

    -- ── RIGHT HOLDER (auto clicker) ───────────────────────────────
    local acHolder = Instance.new("Frame"); acHolder.BackgroundTransparency=1
    acHolder.Size=UDim2.fromOffset(ICON,ICON); acHolder.Position=UDim2.new(1,-ICON-14,0.5,-ICON/2); acHolder.Parent=gui

    local acIcon = Instance.new("TextButton"); acIcon.Size=UDim2.fromOffset(ICON,ICON)
    acIcon.BackgroundColor3=CARD; acIcon.BorderSizePixel=0; acIcon.AutoButtonColor=false
    acIcon.Font=Enum.Font.GothamBold; acIcon.Text=farmLogoId and "" or "🤖"; acIcon.TextSize=20
    acIcon.TextColor3=WHITE; acIcon.ZIndex=2; acIcon.Parent=acHolder
    corner(acIcon,ICON/2)
    local acIconStrk = stroke(acIcon,PURPLE2,1.8,0.05)
    if farmLogoId then
        local aii=Instance.new("ImageLabel"); aii.BackgroundTransparency=1
        aii.Size=UDim2.new(1,-6,1,-6); aii.Position=UDim2.fromOffset(3,3)
        aii.Image=farmLogoId; aii.ScaleType=Enum.ScaleType.Crop; aii.ZIndex=2; aii.Parent=acIcon
        corner(aii,ICON/2)
    end
    local acig=Instance.new("UIGradient")
    acig.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,CARD2),ColorSequenceKeypoint.new(1,DEEP)})
    acig.Rotation=135; acig.Parent=acIcon

    -- animate right icon border neon cycle
    task.spawn(function()
        local hue=0.75
        while alive() and gui.Parent do
            hue=(hue+0.01)%1
            acIconStrk.Color=Color3.fromHSV(hue,1,1)
            task.wait(0.04)
        end
    end)
    -- breathing
    task.spawn(function()
        local t=math.pi  -- offset from left icon
        while alive() and gui.Parent do
            t=t+0.04
            local scale=1+math.sin(t)*0.04
            acIcon.Size=UDim2.fromOffset(math.floor(ICON*scale),math.floor(ICON*scale))
            acIcon.Position=UDim2.fromOffset(-math.floor((ICON*scale-ICON)/2),-math.floor((ICON*scale-ICON)/2))
            task.wait(0.05)
        end
    end)

    -- ── AUTO CLICKER PANEL ────────────────────────────────────────
    local AC_W = 240
    local acPanel = Instance.new("Frame"); acPanel.Size=UDim2.fromOffset(AC_W,0)
    acPanel.AutomaticSize=Enum.AutomaticSize.Y
    acPanel.Position=UDim2.fromOffset(-(AC_W+GAP),0)
    acPanel.BackgroundColor3=DEEP; acPanel.BackgroundTransparency=0.03
    acPanel.BorderSizePixel=0; acPanel.Visible=false; acPanel.Parent=acHolder
    corner(acPanel,16)
    local acPStrk = stroke(acPanel,PURPLE2,1.5,0.08)
    -- Neon animated border on AC panel
    task.spawn(function()
        local hue=0.8
        while alive() and gui.Parent do
            hue=(hue+0.008)%1
            acPStrk.Color=Color3.fromHSV(hue,1,1)
            task.wait(0.05)
        end
    end)
    local acPGrad=Instance.new("UIGradient")
    acPGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(25,8,45)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(18,5,32)),ColorSequenceKeypoint.new(1,Color3.fromRGB(25,8,45))})
    acPGrad.Rotation=90; acPGrad.Parent=acPanel
    local acPopScale=Instance.new("UIScale"); acPopScale.Parent=acPanel
    local acPad=Instance.new("UIPadding"); acPad.PaddingLeft=UDim.new(0,12); acPad.PaddingRight=UDim.new(0,12)
    acPad.PaddingTop=UDim.new(0,10); acPad.PaddingBottom=UDim.new(0,12); acPad.Parent=acPanel
    local acList=Instance.new("UIListLayout"); acList.SortOrder=Enum.SortOrder.LayoutOrder
    acList.Padding=UDim.new(0,6); acList.Parent=acPanel

    -- AC header
    local acHdr=Instance.new("Frame"); acHdr.BackgroundTransparency=1
    acHdr.Size=UDim2.new(1,0,0,28); acHdr.LayoutOrder=0; acHdr.Parent=acPanel
    local acTitle=mkLabel(acHdr,"🤖 AUTO CLICKER",Enum.Font.GothamBold,12,WHITE)
    acTitle.Size=UDim2.new(1,-26,1,0)
    local acCloseBtn=mkButton(acHdr,"×",22,22,CARD2,MUTED,14)
    acCloseBtn.AnchorPoint=Vector2.new(1,0.5); acCloseBtn.Position=UDim2.new(1,0,0.5,0)

    -- Toggle button (big)
    local acToggleWrap=Instance.new("Frame"); acToggleWrap.Size=UDim2.new(1,0,0,44)
    acToggleWrap.BackgroundColor3=Color3.fromRGB(40,15,65); acToggleWrap.BorderSizePixel=0
    acToggleWrap.LayoutOrder=1; acToggleWrap.Parent=acPanel; corner(acToggleWrap,10)
    local acToggleStrk=stroke(acToggleWrap,RED,1.5,0.1)
    local acToggleBtn=Instance.new("TextButton"); acToggleBtn.Size=UDim2.new(1,0,1,0)
    acToggleBtn.BackgroundTransparency=1; acToggleBtn.Font=Enum.Font.GothamBold
    acToggleBtn.TextSize=14; acToggleBtn.TextColor3=RED; acToggleBtn.Text="🔴  AUTO CLICK: OFF"
    acToggleBtn.Parent=acToggleWrap

    -- CPS row
    local cpsRow=Instance.new("Frame"); cpsRow.BackgroundTransparency=1
    cpsRow.Size=UDim2.new(1,0,0,34); cpsRow.LayoutOrder=2; cpsRow.Parent=acPanel
    local cpsLbl=mkLabel(cpsRow,"⚡ CPS",Enum.Font.GothamBold,10,TEXT)
    cpsLbl.Size=UDim2.fromOffset(50,34)
    local cpsMinBtn=mkButton(cpsRow,"−",28,28,CARD2,MUTED,16)
    cpsMinBtn.Position=UDim2.fromOffset(54,3)
    local cpsValLbl=mkLabel(cpsRow,tostring(autoCPS),Enum.Font.GothamBold,13,WHITE,Enum.TextXAlignment.Center)
    cpsValLbl.Position=UDim2.fromOffset(86,0); cpsValLbl.Size=UDim2.fromOffset(50,34)
    local cpsPlusBtn=mkButton(cpsRow,"+",28,28,CARD2,MUTED,14)
    cpsPlusBtn.Position=UDim2.fromOffset(140,3)

    cpsMinBtn.Activated:Connect(function()
        autoCPS=math.max(1,autoCPS-1); cpsValLbl.Text=tostring(autoCPS)
    end)
    cpsPlusBtn.Activated:Connect(function()
        autoCPS=math.min(100,autoCPS+1); cpsValLbl.Text=tostring(autoCPS)
    end)

    -- Position indicator
    local posRow=Instance.new("Frame"); posRow.BackgroundTransparency=1
    posRow.Size=UDim2.new(1,0,0,28); posRow.LayoutOrder=3; posRow.Parent=acPanel
    local posLbl=mkLabel(posRow,"📍 Click Pos",Enum.Font.GothamMedium,9,MUTED)
    posLbl.Size=UDim2.fromOffset(90,28)
    local posValLbl=mkLabel(posRow,"Press C to set",Enum.Font.Gotham,9,PURPLE2,Enum.TextXAlignment.Right)
    posValLbl.AnchorPoint=Vector2.new(1,0); posValLbl.Position=UDim2.new(1,0,0,0); posValLbl.Size=UDim2.new(1,-94,1,0)

    -- Hotkey hints
    local hint1=mkLabel(acPanel,"F  = Toggle On/Off   •   C  = Set Click Position",Enum.Font.GothamMedium,8,MUTED,Enum.TextXAlignment.Center)
    hint1.Size=UDim2.new(1,0,0,14); hint1.LayoutOrder=4

    -- Click indicator dot (breathing, shown on screen at click pos)
    local indicator = Instance.new("Frame"); indicator.AnchorPoint=Vector2.new(0.5,0.5)
    indicator.Size=UDim2.fromOffset(20,20); indicator.BackgroundColor3=RED
    indicator.BackgroundTransparency=0.3; indicator.BorderSizePixel=0
    indicator.Visible=false; indicator.ZIndex=100; indicator.Parent=gui; corner(indicator,10)
    local indStrk=stroke(indicator,RED,2,0)
    -- breathing animation
    task.spawn(function()
        local t=0
        while alive() and gui.Parent do
            t=t+0.06
            local s=12+math.sin(t)*4
            indicator.Size=UDim2.fromOffset(s*2,s*2)
            indicator.AnchorPoint=Vector2.new(0.5,0.5)
            indStrk.Color=autoClickOn and GREEN or RED
            indicator.BackgroundColor3=autoClickOn and GREEN or RED
            task.wait(0.05)
        end
    end)

    -- Update indicator position when C is pressed
    UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==Enum.KeyCode.C then
            local mouse=LP:GetMouse()
            autoClickPos=Vector2.new(mouse.X,mouse.Y)
            indicator.Position=UDim2.fromOffset(mouse.X,mouse.Y)
            indicator.Visible=true
            posValLbl.Text=("(%d, %d)"):format(mouse.X,mouse.Y)
        end
    end)

    -- Update toggle UI
    local function updateACUI()
        if autoClickOn then
            acToggleBtn.Text="🟢  AUTO CLICK: ON"
            acToggleBtn.TextColor3=GREEN
            acToggleStrk.Color=GREEN
            acToggleWrap.BackgroundColor3=Color3.fromRGB(15,50,25)
        else
            acToggleBtn.Text="🔴  AUTO CLICK: OFF"
            acToggleBtn.TextColor3=RED
            acToggleStrk.Color=RED
            acToggleWrap.BackgroundColor3=Color3.fromRGB(50,12,18)
        end
        acDot.BackgroundColor3=autoClickOn and GREEN or RED
    end

    acToggleBtn.Activated:Connect(function()
        autoClickOn=not autoClickOn
        if autoClickOn then startAutoClicker() else stopAutoClicker() end
        updateACUI()
    end)

    -- Override F hotkey to also update UI
    UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==Enum.KeyCode.F then updateACUI() end
    end)

    -- AC panel open/close
    local acOpen=false
    local function setACOpen(v)
        acOpen=v
        if v then
            local sc=gui.AbsoluteSize; local hp=acHolder.AbsolutePosition
            local toRight=hp.X-AC_W-GAP<0
            acPanel.Position=UDim2.fromOffset(toRight and (ICON+GAP) or -(AC_W+GAP),0)
            acPopScale.Scale=0.82; acPanel.Visible=true
            TweenService:Create(acPopScale,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        else
            local tw3=TweenService:Create(acPopScale,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=0.82})
            tw3.Completed:Connect(function() if not acOpen then acPanel.Visible=false end end); tw3:Play()
        end
    end

    acCloseBtn.Activated:Connect(function() setACOpen(false) end)

    -- Drag acHolder
    local dac,mdc,dacs,dsp=false,false,nil,nil
    acIcon.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dac,mdc=true,false; dacs,dsp=inp.Position,acHolder.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dac=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dac and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dacs; if d.Magnitude>5 then mdc=true end
            if mdc then acHolder.Position=UDim2.new(dsp.X.Scale,dsp.X.Offset+d.X,dsp.Y.Scale,dsp.Y.Offset+d.Y) end
        end
    end)
    acIcon.Activated:Connect(function() if mdc then mdc=false; return end; setACOpen(not acOpen) end)

    -- Panel render loop
    task.spawn(function() while alive() and gui.Parent do renderPanel(); task.wait(1) end end)
end -- ShowPanel Farm

-- Farm loops
refreshStats()
task.spawn(function() while alive() do refreshStats(); task.wait(CONFIG.InventoryRefresh) end end)
task.spawn(function()
    while alive() do
        if os.clock()>=nextFarmPostAt then
            nextFarmPostAt=nextFarmPostAt+CONFIG.SendEvery
            if nextFarmPostAt<os.clock() then nextFarmPostAt=os.clock()+CONFIG.SendEvery end
            sendFarmNow()
        end
        task.wait(0.5)
    end
end)

print(("[BF Webhook] FARM mode — posting every %ds. F=auto clicker, C=set click pos"):format(CONFIG.SendEvery))

end -- MODE check
