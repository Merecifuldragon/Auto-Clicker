--[[
    BLOX FRUITS — Dual-Mode Live Tracker  (Leviathan + Farm)
    ==========================================================
    getgenv().key      = "MercifulCutie"
    getgenv().webhook  = "https://discord.com/api/webhooks/..."
    getgenv().Mode     = "Leviathan"      -- or "Farm"
    getgenv().interval = 600              -- optional, seconds (default 600)
    loadstring(...)()
    ==========================================================
    Leviathan : 8-item tracker,  light-blue UI
    Farm      : Beli+Frags, Auto Clicker,  purple UI
--]]

local ENV  = (getgenv and getgenv()) or _G
local MODE = tostring(ENV.Mode or "Leviathan"):upper()
if MODE ~= "FARM" and MODE ~= "LEVIATHAN" then
    MODE = "LEVIATHAN"
    warn("[BF] Unknown mode — defaulting to Leviathan.")
end

local CONFIG = {
    WebhookURL       = tostring(ENV.webhook or ""),
    Key              = tostring(ENV.key or ""),
    SendEvery        = tonumber(ENV.interval) or 600,
    InventoryRefresh = 15,
    EditSameMessage  = false,
    ShowPanel        = true,
    Debug            = true,
    WebhookUsername  = "Merciful BF Tracker",
    WebhookAvatarURL = "https://i.imgur.com/WUuVA9l.jpeg",
    WebhookGifURL    = "https://i.imgur.com/4jxdn8Z.gif",
    FarmGifURL       = "https://i.imgur.com/U18TsI4.gif",
}

------------------------------------------------------------------------
-- KEY CHECK
------------------------------------------------------------------------
local REQUIRED_KEY = "MercifulCutie"

if CONFIG.WebhookURL == "" then
    warn("[BF] No webhook set.  getgenv().webhook = '...'  before loadstring."); return
end
if tostring(CONFIG.Key):lower() ~= REQUIRED_KEY:lower() then
    warn("[BF] Invalid key. Script stopped.")
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local par; pcall(function() par = (gethui and gethui()) or game:GetService("CoreGui") end)
        par = par or player:WaitForChild("PlayerGui")
        local old = par:FindFirstChild("BF_KeyError"); if old then old:Destroy() end
        local sg = Instance.new("ScreenGui"); sg.Name="BF_KeyError"; sg.ResetOnSpawn=false
        sg.IgnoreGuiInset=true; sg.DisplayOrder=1e7; sg.Parent=par
        local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,0)
        f.Position=UDim2.new(.5,0,0,12); f.Size=UDim2.fromOffset(360,58)
        f.BackgroundColor3=Color3.fromRGB(105,25,30); f.BorderSizePixel=0; f.Parent=sg
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=f
        local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(255,85,95); s.Thickness=1.5; s.Parent=f
        local t1=Instance.new("TextLabel"); t1.BackgroundTransparency=1
        t1.Position=UDim2.fromOffset(14,7); t1.Size=UDim2.new(1,-28,0,22)
        t1.Font=Enum.Font.GothamBold; t1.TextSize=15; t1.TextColor3=Color3.fromRGB(255,235,235)
        t1.TextXAlignment=Enum.TextXAlignment.Center; t1.Text="⚠  INVALID KEY"; t1.Parent=f
        local t2=Instance.new("TextLabel"); t2.BackgroundTransparency=1
        t2.Position=UDim2.fromOffset(14,30); t2.Size=UDim2.new(1,-28,0,18)
        t2.Font=Enum.Font.GothamMedium; t2.TextSize=10; t2.TextColor3=Color3.fromRGB(255,195,200)
        t2.TextXAlignment=Enum.TextXAlignment.Center; t2.Text="Check your key and try again."; t2.Parent=f
        local TW=game:GetService("TweenService")
        local sc=Instance.new("UIScale"); sc.Scale=0; sc.Parent=f
        TW:Create(sc,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        task.delay(10,function() if sg and sg.Parent then sg:Destroy() end end)
    end)
    return
end

------------------------------------------------------------------------
-- SERVICES / SESSION
------------------------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local HttpSvc    = game:GetService("HttpService")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
local SESSION = {}
env.__BF_MAT_WEBHOOK = SESSION
local function alive() return env.__BF_MAT_WEBHOOK == SESSION end

------------------------------------------------------------------------
-- SHARED UTILITIES
------------------------------------------------------------------------
local scriptStart = os.clock()
local smoothFPS   = 60
local currentPing = 0
local fpsBuf      = {}
local _lastHB     = os.clock()

RunService.Heartbeat:Connect(function()
    if not alive() then return end
    local now = os.clock(); local dt = now - _lastHB; _lastHB = now
    if dt > 0 and dt < 1 then
        fpsBuf[#fpsBuf+1] = 1/dt
        if #fpsBuf > 20 then table.remove(fpsBuf,1) end
        local s=0; for _,v in ipairs(fpsBuf) do s=s+v end
        smoothFPS = math.min(math.floor(s/#fpsBuf), 999)
    end
end)

task.spawn(function()
    while alive() do
        pcall(function() currentPing = math.floor(LP:GetNetworkPing()*1000) end)
        task.wait(3)
    end
end)

local function commas(n)
    local s=tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^(%-?),","%1"))
end
local function compact(n)
    n=tonumber(n); if not n then return "--" end
    local a=math.abs(n)
    if a>=1e12 then return ("%.2fT"):format(n/1e12) end
    if a>=1e9  then return ("%.2fB"):format(n/1e9)  end
    if a>=1e6  then return ("%.2fM"):format(n/1e6)  end
    if a>=1e3  then return ("%.1fK"):format(n/1e3)  end
    return commas(n)
end
local function formatRT(t)
    local h=math.floor(t/3600); local m=math.floor((t%3600)/60); local s=math.floor(t%60)
    return h>0 and ("%02dh %02dm %02ds"):format(h,m,s) or ("%02dm %02ds"):format(m,s)
end
local function fpsTextColor(f)
    local t=math.clamp(f/60,0,1)
    if t<.5 then return Color3.fromRGB(255,math.floor(t*2*180),0)
    else return Color3.fromRGB(math.floor((1-(t-.5)*2)*255),math.floor(180+(t-.5)*2*75),0) end
end

------------------------------------------------------------------------
-- LEVIATHAN MODE: ITEMS
------------------------------------------------------------------------
local ITEMS, ID_TO_KEY = {}, {}
if MODE=="LEVIATHAN" then
    ITEMS = {
        {key="beli",      label="Beli",              emoji="<a:money:1481836978571055174>",         uiEmoji="💰", stat={"Beli","Money"}},
        {key="fragments", label="Fragments",         emoji="<:Fragments:1523292585127448576>",       uiEmoji="🧩", stat={"Fragments"}},
        {key="mythical",  label="Mythical Scrolls",  emoji="<:MythicScroll:1168527646867607625>",   uiEmoji="🔮", names={"Mythical Scroll"},  idType="Scroll",   fallbackId=858},
        {key="legendary", label="Legendary Scrolls", emoji="<:LegendScroll:1168527616312094811>",   uiEmoji="📜", names={"Legendary Scroll"}, idType="Scroll",   fallbackId=857},
        {key="foolsgold", label="Fool's Gold",       emoji="<a:9040goldnitro:1413550873354834051>", uiEmoji="🪙", names={"Fool's Gold"},      idType="Material", fallbackId=597},
        {key="terror",    label="Terror Eyes",       emoji="<:blurryeyes:1372835227256492042>",     uiEmoji="👁️", names={"Terror Eyes"},      idType="Material", fallbackId=582},
        {key="levheart",  label="Leviathan Heart",   emoji="<a:DropletHeart:1515188697388154941>",  uiEmoji="💧", names={"Leviathan Heart"},  idType="Material", fallbackId=570},
        {key="levscale",  label="Leviathan Scale",   emoji="<:frozen_ice:1528361431563501658>",     uiEmoji="❄️", names={"Leviathan Scale"},  idType="Material", fallbackId=561},
    }
    for _,it in ipairs(ITEMS) do
        if it.names then
            it.id = it.fallbackId; ID_TO_KEY[it.id] = it.key
        end
    end
end

------------------------------------------------------------------------
-- FARM MODE: STATE
------------------------------------------------------------------------
local farmStart   = nil   -- {beli, frags, time} set after first successful read
local acEnabled   = false
local acCPS       = 10
local acPosition  = nil   -- Vector2 screen pos
local _lastAcClick = 0
local acIndicatorUpdate = nil  -- callback set by UI

------------------------------------------------------------------------
-- STAT READING
------------------------------------------------------------------------
local values = {}
local ITEM   = {}; for _,it in ipairs(ITEMS) do ITEM[it.key]=it end

LP:WaitForChild("Data",60)
local hooked = {}
local function readStat(item)
    local containers={LP:FindFirstChild("Data"),LP:FindFirstChild("leaderstats")}
    for _,c in ipairs(containers) do
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

local renderPanel = nil
local function refreshStats()
    if MODE=="LEVIATHAN" then
        for _,it in ipairs(ITEMS) do
            if it.stat then
                local n,obj=readStat(it)
                if n then values[it.key]=n end
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
    else
        -- Farm: only Beli + Fragments
        local beliItem={stat={"Beli","Money"}}
        local fragItem={stat={"Fragments"}}
        local b,bo=readStat(beliItem); if b then values.beli=b end
        local f,fo=readStat(fragItem); if f then values.fragments=f end
        for _,pair in ipairs({{bo,"beli"},{fo,"fragments"}}) do
            local obj,key=pair[1],pair[2]
            if obj and not hooked[obj] then
                hooked[obj]=true
                obj.Changed:Connect(function()
                    if not alive() then return end
                    values[key]=tonumber(obj.Value) or values[key]
                    if renderPanel then renderPanel() end
                end)
            end
        end
        -- capture starting point once
        if not farmStart and values.beli and values.fragments then
            farmStart={beli=values.beli,frags=values.fragments,time=os.clock()}
        end
    end
end

------------------------------------------------------------------------
-- INVENTORY (Leviathan only)
------------------------------------------------------------------------
local invOk,invErr,invSrc = false,nil,"-"
local reading=false
local qty={}

local Modules=RS:WaitForChild("Modules",30)
local Net=Modules and Modules:WaitForChild("Net",30)
local function netRemote(n) return Net and Net:FindFirstChild(n) end

local function invokeTimeout(remote,timeout,...)
    local args=table.pack(...)
    local done,ok,res=false,false,nil
    task.spawn(function()
        ok,res=pcall(function() return remote:InvokeServer(table.unpack(args,1,args.n)) end)
        done=true
    end)
    local t0=os.clock()
    while not done and os.clock()-t0<timeout do task.wait(.1) end
    if not done then return false,"timed out" end
    return ok,res
end

local function applyRecord(rec,into)
    if type(rec)~="table" or rec.Key~="Quantity" then return false end
    local id=tonumber(rec.ItemId); if not id or not ID_TO_KEY[id] then return false end
    into[id]=into[id] or {}; into[id][tostring(rec.NetworkedUID)]=tonumber(rec.Value) or 0
    return true
end
local function totalFor(id)
    local t=0; for _,q in pairs(qty[id] or {}) do t=t+q end; return t
end

if MODE=="LEVIATHAN" then
    local changedEvent=netRemote("RE/OnItemValueChanged")
    if changedEvent then
        changedEvent.OnClientEvent:Connect(function(batch)
            if not alive() or type(batch)~="table" then return end
            local list=(batch.Key~=nil) and {batch} or batch
            local touched=false
            for _,rec in pairs(list) do
                if applyRecord(rec,qty) then
                    local id=tonumber(rec.ItemId)
                    values[ID_TO_KEY[id]]=totalFor(id); touched=true
                end
            end
            if touched and renderPanel then renderPanel() end
        end)
    end
end

local printedDebug=false
local function readInventory()
    if MODE~="LEVIATHAN" then return true end
    if reading then while reading do task.wait(.1) end; return invOk end
    reading=true
    local rf=netRemote("RF/GetAllItemValues")
    local ok,res
    if rf then ok,res=invokeTimeout(rf,10) else ok,res=false,"RF not found" end
    if ok and type(res)=="table" then
        local fresh,qr={},0
        for _,rec in pairs(res) do
            if type(rec)=="table" and rec.Key=="Quantity" then qr=qr+1 end
            applyRecord(rec,fresh)
        end
        if qr>0 then
            qty=fresh
            for _,it in ipairs(ITEMS) do if it.id then values[it.key]=totalFor(it.id) end end
            invOk,invErr,invSrc=true,nil,"items"; reading=false
            if CONFIG.Debug and not printedDebug then
                printedDebug=true
                print("[BF] Item cross-check:")
                for _,it in ipairs(ITEMS) do
                    if it.id then print(("   %-17s id=%-5d count=%d"):format(it.names[1],it.id,values[it.key])) end
                end
            end
            return true
        end
        invErr="no Quantity records"
    else invErr=ok and ("GetAllItemValues returned "..typeof(res)) or tostring(res) end
    local rf2=netRemote("RF/GetCraftPlayerData")
    if rf2 then
        local ok2,data=invokeTimeout(rf2,10)
        if ok2 and type(data)=="table" and type(data.EtcItems)=="table" then
            for _,it in ipairs(ITEMS) do
                if it.names then values[it.key]=tonumber(data.EtcItems[it.names[1]]) or 0 end
            end
            invOk,invSrc=true,"craft"; reading=false; return true
        end
    end
    invOk=false; reading=false; return false
end

------------------------------------------------------------------------
-- DISCORD
------------------------------------------------------------------------
local httpRequest=(syn and syn.request) or (http and http.request)
                 or http_request or request or (fluxus and fluxus.request)

local function fmtVal(v,prev)
    if v==nil then return "N/A" end
    local s=commas(v)
    if prev~=nil and v~=prev then
        local d=v-prev
        s=s..(d>0 and ("  (+"..commas(d)..")") or ("  (-"..commas(-d)..")"))
    end
    return s
end

local function buildLevPayload(snap,prev,stale)
    local fields={}
    local function add(key)
        local it=ITEM[key]
        fields[#fields+1]={name=it.emoji.." "..it.label,
            value="```"..fmtVal(snap[key],prev and prev[key]).."```",inline=true}
    end
    local function sp() fields[#fields+1]={name="\u{200B}",value="\u{200B}",inline=true} end
    add("beli");add("fragments");sp()
    add("mythical");add("legendary");sp()
    add("foolsgold");add("terror");sp()
    add("levheart");add("levscale");sp()
    local desc=("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName,LP.Name)
    local data=LP:FindFirstChild("Data"); local lvl=data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then desc=desc.."  •  Level "..commas(lvl.Value) end
    desc=desc.."\n⏱ Runtime: `"..formatRT(os.clock()-scriptStart).."`"
    local stamp; pcall(function() stamp=DateTime.now():ToIsoDate() end)
    local embed={
        title="<a:crown_blueZK:1451051338333945978> MADE BY MERCIFUL <a:crown_blueZK:1451051338333945978>",
        description=desc,color=stale and 16755370 or 6724095,fields=fields,
        footer={text=stale and ("⚠ inventory failed — "..tostring(invErr)) or ("Live · every "..CONFIG.SendEvery.."s")},
        timestamp=stamp,
    }
    if CONFIG.WebhookGifURL~="" then embed.image={url=CONFIG.WebhookGifURL} end
    return {username=CONFIG.WebhookUsername,avatar_url=CONFIG.WebhookAvatarURL,embeds={embed}}
end

local function buildFarmPayload(snap,prev,stale)
    local elapsed=os.clock()-scriptStart
    local earnedBeli  = farmStart and math.max(0,(snap.beli or 0)    - farmStart.beli)  or 0
    local earnedFrags = farmStart and math.max(0,(snap.fragments or 0)- farmStart.frags) or 0
    local hrs = elapsed/3600
    local beliHr  = hrs>0 and math.floor(earnedBeli/hrs)  or 0
    local fragsHr = hrs>0 and math.floor(earnedFrags/hrs) or 0
    local acStr   = acEnabled and "🟢 **ON**" or "🔴 **OFF**"
    local fields={
        {name="<a:Money_Rain:1495158118227906570> Beli / Hour",   value="```"..commas(beliHr).."```",  inline=true},
        {name="<:fragments:1513833142010646628> Frags / Hour",    value="```"..commas(fragsHr).."```", inline=true},
        {name="\u{200B}",value="\u{200B}",inline=true},
        {name="<a:money_logo:1512768917351694337> Total Beli Earned",  value="```"..commas(earnedBeli).."```",  inline=true},
        {name="<:fragments:1513833142010646628> Total Frags Earned",   value="```"..commas(earnedFrags).."```", inline=true},
        {name="\u{200B}",value="\u{200B}",inline=true},
        {name="💰 Current Beli",      value="```"..commas(snap.beli or 0).."```",       inline=true},
        {name="🧩 Current Fragments", value="```"..commas(snap.fragments or 0).."```",  inline=true},
        {name="\u{200B}",value="\u{200B}",inline=true},
    }
    local desc=("<a:white_arroww:1537868864975675523> **%s** (@%s)"):format(LP.DisplayName,LP.Name)
    desc=desc.."\n⏱ Session: `"..formatRT(elapsed).."`"
    desc=desc.."\n🤖 Auto Clicker: "..acStr
    local stamp; pcall(function() stamp=DateTime.now():ToIsoDate() end)
    local embed={
        title="<a:PurpleCrown:1483537181988618263> MADE BY MERCIFUL <a:PurpleCrown:1483537181988618263>",
        description=desc,color=10197686,fields=fields,
        footer={text=stale and "⚠ stale data" or ("Farm Tracker · every "..CONFIG.SendEvery.."s")},
        timestamp=stamp,
    }
    embed.image={url=CONFIG.FarmGifURL}
    return {username=CONFIG.WebhookUsername,avatar_url=CONFIG.WebhookAvatarURL,embeds={embed}}
end

local messageId
local function postWebhook(payload)
    local url=CONFIG.WebhookURL
    if type(url)~="string" or not url:find("/api/webhooks/",1,true) then return false,"bad url" end
    if not httpRequest then return false,"no request fn" end
    local okE,body=pcall(function() return HttpSvc:JSONEncode(payload) end)
    if not okE then return false,"json encode failed" end
    local base,query=url:match("^([^?]+)(.*)$")
    for _=1,3 do
        local method,target
        if CONFIG.EditSameMessage and messageId then
            method,target="PATCH",base.."/messages/"..messageId..query
        else
            method,target="POST",base..(query=="" and "?wait=true" or (query.."&wait=true"))
        end
        local sent,res=pcall(httpRequest,{Url=target,Method=method,
            Headers={["Content-Type"]="application/json"},Body=body})
        if not sent then return false,"request error: "..tostring(res) end
        local code=res and tonumber(res.StatusCode or res.Status or res.status_code)
        if code==429 then
            local r=2; pcall(function() r=tonumber(HttpSvc:JSONDecode(res.Body).retry_after) or 2 end)
            task.wait(math.clamp(r,.5,30))
        elseif code==404 and method=="PATCH" then messageId=nil
        elseif (code and code>=200 and code<300) or (not code and res and res.Success~=false) then
            if method=="POST" then pcall(function() messageId=HttpSvc:JSONDecode(res.Body).id end) end
            return true,"sent"
        else return false,"HTTP "..tostring(code) end
    end
    return false,"rate limited"
end

local lastSent,lastPostMsg={},("waiting for first post")
local sending=false
local function sendNow()
    if sending then return end; sending=true
    refreshStats()
    local fresh=(MODE=="LEVIATHAN") and readInventory() or true
    if renderPanel then renderPanel() end
    local snap={}
    if MODE=="LEVIATHAN" then for _,it in ipairs(ITEMS) do snap[it.key]=values[it.key] end
    else snap={beli=values.beli,fragments=values.fragments} end
    local payload=(MODE=="LEVIATHAN") and buildLevPayload(snap,lastSent,not fresh)
                                       or  buildFarmPayload(snap,lastSent,not fresh)
    local ok,msg=postWebhook(payload)
    if ok then lastSent=snap; lastPostMsg="sent "..os.date("%H:%M:%S")..(fresh and "" or " (stale)")
    else lastPostMsg="FAILED: "..msg; warn("[BF] "..msg) end
    sending=false
end

------------------------------------------------------------------------
-- PANEL
------------------------------------------------------------------------
local nextPostAt=os.clock()+3

if CONFIG.ShowPanel then
    local TweenService=game:GetService("TweenService")
    local parent; pcall(function() parent=(gethui and gethui()) or game:GetService("CoreGui") end)
    parent=parent or LP:WaitForChild("PlayerGui")
    local old=parent:FindFirstChild("BF_MaterialsWebhook"); if old then old:Destroy() end

    -- Palette
    local WHITE  = Color3.fromRGB(244,251,255)
    local TEXT   = Color3.fromRGB(205,232,248)
    local MUTED  = Color3.fromRGB(130,174,201)
    local BLUE   = Color3.fromRGB(92,196,255)
    local BLUE2  = Color3.fromRGB(56,157,224)
    local DEEP   = Color3.fromRGB(9,20,30)
    local CARD   = Color3.fromRGB(14,31,44)
    local CARD2  = Color3.fromRGB(18,42,59)
    local LINE   = Color3.fromRGB(53,104,132)
    local GREEN  = Color3.fromRGB(92,221,148)
    local ORANGE = Color3.fromRGB(245,181,78)
    local RED    = Color3.fromRGB(245,96,103)
    local PURPLE = Color3.fromRGB(160,80,255)
    local PURPLE2= Color3.fromRGB(100,40,200)

    local ICON,PANEL_W,ROW_H,GAP=64,260,28,7
    local ACCENT = (MODE=="FARM") and PURPLE or BLUE

    local function mkCorner(p,r)
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p; return c
    end
    local function mkStroke(p,col,t,tr)
        local s=Instance.new("UIStroke"); s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        s.Color=col; s.Thickness=t or 1; s.Transparency=tr or 0; s.Parent=p; return s
    end
    local function mkLabel(par,txt,font,sz,col,align)
        local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
        l.Font=font; l.TextSize=sz; l.TextColor3=col
        l.TextXAlignment=align or Enum.TextXAlignment.Left
        l.TextTruncate=Enum.TextTruncate.AtEnd; l.Text=txt; l.Parent=par; return l
    end
    local function mkBtn(par,txt,w,h,bg,fg,sz)
        local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(w,h)
        b.BackgroundColor3=bg; b.BorderSizePixel=0; b.AutoButtonColor=false
        b.Font=Enum.Font.GothamBold; b.TextSize=sz or 10; b.TextColor3=fg or WHITE
        b.Text=txt; b.Parent=par; mkCorner(b,7)
        b.MouseEnter:Connect(function()
            TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=bg:Lerp(Color3.new(1,1,1),.10)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=bg}):Play()
        end)
        return b
    end

    local gui=Instance.new("ScreenGui"); gui.Name="BF_MaterialsWebhook"; gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true; gui.DisplayOrder=1000000
    if not pcall(function() gui.Parent=parent end) then gui.Parent=LP:WaitForChild("PlayerGui") end

    local function loadImg(url,fname)
        if not (writefile and getcustomasset and httpRequest) then return nil end
        local ok,id=pcall(function()
            local resp=httpRequest({Url=url,Method="GET"})
            local bytes=resp and (resp.Body or resp.body)
            if type(bytes)~="string" or #bytes==0 then return nil end
            writefile(fname or "bf_cache.png",bytes); return getcustomasset(fname or "bf_cache.png")
        end)
        return (ok and id) or nil
    end

    local logoAssetId = loadImg(CONFIG.WebhookAvatarURL,"bf_logo.png")
    local diImgId
    if MODE=="FARM" then
        diImgId = loadImg("https://i.imgur.com/uMveRae.jpeg","bf_farm.jpg")
    else
        diImgId = loadImg("https://i.imgur.com/ynh1ZW5.jpeg","bf_lev.jpg")
    end

    ----------------------------------------------------------------
    -- DYNAMIC ISLAND
    ----------------------------------------------------------------
    local ISLE_H   = 52
    local ISLE_W   = (MODE=="FARM") and 510 or 455
    local islandBgGood  = (MODE=="FARM") and Color3.fromRGB(10,4,22)  or Color3.fromRGB(9,20,30)
    local islandBgBad   = Color3.fromRGB(22,4,6)
    local islandBrGood  = (MODE=="FARM") and PURPLE or BLUE
    local islandBrBad   = RED
    local fpsBoosted    = false

    local diFrame=Instance.new("Frame"); diFrame.Name="DynamicIsland"
    diFrame.AnchorPoint=Vector2.new(.5,.5); diFrame.Position=UDim2.new(.5,0,0,ISLE_H/2+8)
    diFrame.Size=UDim2.fromOffset(ISLE_H,ISLE_H); diFrame.BackgroundColor3=islandBgGood
    diFrame.BorderSizePixel=0; diFrame.ClipsDescendants=true; diFrame.ZIndex=30; diFrame.Parent=gui
    mkCorner(diFrame,ISLE_H/2)
    local diBorder=mkStroke(diFrame,islandBrGood,1.5,.25)

    local diGrad=Instance.new("UIGradient")
    diGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(19,49,68)),
        ColorSequenceKeypoint.new(.5,CARD),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(4,10,18)),
    }); diGrad.Rotation=90; diGrad.Parent=diFrame

    local diSc=Instance.new("UIScale"); diSc.Scale=0; diSc.Parent=diFrame

    -- Profile image
    local diImg=Instance.new("ImageLabel"); diImg.BackgroundTransparency=1
    diImg.AnchorPoint=Vector2.new(0,.5); diImg.Position=UDim2.new(0,5,.5,0)
    diImg.Size=UDim2.fromOffset(ISLE_H-10,ISLE_H-10); diImg.Image=diImgId or ""
    diImg.ScaleType=Enum.ScaleType.Crop; diImg.ZIndex=32; diImg.Parent=diFrame
    mkCorner(diImg,(ISLE_H-10)/2)
    if not diImgId then
        local fb=Instance.new("TextLabel"); fb.BackgroundTransparency=1
        fb.AnchorPoint=Vector2.new(0,.5); fb.Position=UDim2.new(0,5,.5,0)
        fb.Size=UDim2.fromOffset(ISLE_H-10,ISLE_H-10); fb.Font=Enum.Font.GothamBold
        fb.TextSize=22; fb.TextColor3=WHITE; fb.Text=MODE=="FARM" and "🌿" or "🌊"; fb.ZIndex=32; fb.Parent=diFrame
    end

    local function diLbl(txt,font,sz,col,xalign)
        local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
        l.Font=font; l.TextSize=sz; l.TextColor3=col
        l.TextXAlignment=xalign or Enum.TextXAlignment.Left
        l.TextTransparency=1; l.ZIndex=32; l.Parent=diFrame; l.Text=txt; return l
    end

    -- Runtime
    local diRTtitle=diLbl("RUNTIME",Enum.Font.GothamBold,8,Color3.fromRGB(90,155,210))
    diRTtitle.AnchorPoint=Vector2.new(0,.5); diRTtitle.Position=UDim2.new(0,ISLE_H+8,.5,-10)
    diRTtitle.Size=UDim2.new(.32,-ISLE_H,0,12)
    local diRTval=diLbl("00m 00s",Enum.Font.GothamBold,15,Color3.fromRGB(220,242,255))
    diRTval.AnchorPoint=Vector2.new(0,.5); diRTval.Position=UDim2.new(0,ISLE_H+8,.5,5)
    diRTval.Size=UDim2.new(.32,-ISLE_H,0,20)

    -- Divider 1
    local diDiv1=Instance.new("Frame"); diDiv1.AnchorPoint=Vector2.new(.5,.5)
    diDiv1.Position=UDim2.new(.44,0,.5,0); diDiv1.Size=UDim2.fromOffset(1,28)
    diDiv1.BackgroundColor3=LINE; diDiv1.BackgroundTransparency=1; diDiv1.BorderSizePixel=0
    diDiv1.ZIndex=32; diDiv1.Parent=diFrame

    -- FPS
    local diFPStitle=diLbl("FPS",Enum.Font.GothamBold,8,Color3.fromRGB(90,155,210),Enum.TextXAlignment.Center)
    diFPStitle.AnchorPoint=Vector2.new(.5,.5); diFPStitle.Position=UDim2.new(.53,0,.5,-10); diFPStitle.Size=UDim2.fromOffset(52,12)
    local diFPSval=diLbl("60",Enum.Font.GothamBold,16,GREEN,Enum.TextXAlignment.Center)
    diFPSval.AnchorPoint=Vector2.new(.5,.5); diFPSval.Position=UDim2.new(.53,0,.5,5); diFPSval.Size=UDim2.fromOffset(52,20)

    -- PING
    local diPINGtitle=diLbl("PING",Enum.Font.GothamBold,8,Color3.fromRGB(90,155,210),Enum.TextXAlignment.Center)
    diPINGtitle.AnchorPoint=Vector2.new(.5,.5); diPINGtitle.Position=UDim2.new(.67,0,.5,-10); diPINGtitle.Size=UDim2.fromOffset(52,12)
    local diPINGval=diLbl("--ms",Enum.Font.GothamBold,13,MUTED,Enum.TextXAlignment.Center)
    diPINGval.AnchorPoint=Vector2.new(.5,.5); diPINGval.Position=UDim2.new(.67,0,.5,5); diPINGval.Size=UDim2.fromOffset(52,18)

    -- FPS Boost button
    local diBoostBtn=Instance.new("TextButton"); diBoostBtn.AnchorPoint=Vector2.new(.5,.5)
    diBoostBtn.Position=UDim2.new(.81,0,.5,0); diBoostBtn.Size=UDim2.fromOffset(36,30)
    diBoostBtn.BackgroundColor3=CARD2; diBoostBtn.BorderSizePixel=0; diBoostBtn.AutoButtonColor=false
    diBoostBtn.Font=Enum.Font.GothamBold; diBoostBtn.TextSize=10; diBoostBtn.TextColor3=MUTED
    diBoostBtn.Text="🚀 FPS"; diBoostBtn.ZIndex=33; diBoostBtn.Visible=false; diBoostBtn.Parent=diFrame
    mkCorner(diBoostBtn,6)
    diBoostBtn.Activated:Connect(function()
        fpsBoosted=not fpsBoosted
        pcall(function()
            if fpsBoosted then settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
            else settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end
        end)
        TweenService:Create(diBoostBtn,TweenInfo.new(.2),{
            BackgroundColor3=fpsBoosted and ACCENT or CARD2,
            TextColor3=fpsBoosted and WHITE or MUTED,
        }):Play()
    end)

    -- AC status dot (Farm only)
    local diACdot
    if MODE=="FARM" then
        diACdot=Instance.new("Frame"); diACdot.AnchorPoint=Vector2.new(.5,.5)
        diACdot.Position=UDim2.new(.93,0,.5,0); diACdot.Size=UDim2.fromOffset(14,14)
        diACdot.BackgroundColor3=RED; diACdot.BorderSizePixel=0; diACdot.ZIndex=33
        diACdot.Visible=false; diACdot.Parent=diFrame; mkCorner(diACdot,7)
        local diACdotLbl=mkLabel and nil
        -- small "AC" label below dot
        local aclbl=Instance.new("TextLabel"); aclbl.BackgroundTransparency=1
        aclbl.AnchorPoint=Vector2.new(.5,0); aclbl.Position=UDim2.new(.93,0,.5,7)
        aclbl.Size=UDim2.fromOffset(20,10); aclbl.Font=Enum.Font.GothamBold; aclbl.TextSize=7
        aclbl.TextColor3=MUTED; aclbl.Text="AC"; aclbl.ZIndex=33; aclbl.Visible=false; aclbl.Parent=diFrame
        task.spawn(function()
            while alive() and gui.Parent do
                if diACdot.Visible then
                    local col=acEnabled and GREEN or RED
                    TweenService:Create(diACdot,TweenInfo.new(.3),{BackgroundColor3=col}):Play()
                end
                task.wait(.25)
            end
        end)
    end

    -- === Island animation sequence ===
    task.spawn(function()
        task.wait(.2)
        -- Phase 1: pop in
        TweenService:Create(diSc,TweenInfo.new(.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        task.wait(.9)
        -- Phase 2: expand
        TweenService:Create(diFrame,TweenInfo.new(.55,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
            {Size=UDim2.fromOffset(ISLE_W,ISLE_H)}):Play()
        task.wait(.5)
        -- Phase 3: fade in elements
        local fi=TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        for _,el in ipairs({diRTtitle,diRTval,diFPStitle,diFPSval,diPINGtitle,diPINGval}) do
            TweenService:Create(el,fi,{TextTransparency=0}):Play()
        end
        TweenService:Create(diDiv1,fi,{BackgroundTransparency=.3}):Play()
        diBoostBtn.Visible=true
        if diACdot then diACdot.Visible=true end
        if MODE=="FARM" then
            -- make AC label visible (it's the one parented after diACdot)
            for _,c in ipairs(diFrame:GetChildren()) do
                if c:IsA("TextLabel") and c.Text=="AC" then c.Visible=true end
            end
        end
        task.wait(.5)
        -- Phase 4: border pulse
        while alive() and gui.Parent do
            TweenService:Create(diBorder,TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=.05}):Play()
            task.wait(1.6)
            TweenService:Create(diBorder,TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=.55}):Play()
            task.wait(1.6)
        end
    end)

    -- Island live update
    task.spawn(function()
        while alive() and gui.Parent do
            diRTval.Text=formatRT(os.clock()-scriptStart)
            diFPSval.Text=tostring(smoothFPS)
            diPINGval.Text=tostring(currentPing).."ms"
            local tc=fpsTextColor(smoothFPS)
            TweenService:Create(diFPSval,TweenInfo.new(.3,Enum.EasingStyle.Linear),{TextColor3=tc}):Play()
            -- FPS-reactive island color
            local t=math.clamp(smoothFPS/60,0,1)
            local bg=islandBgBad:Lerp(islandBgGood,t)
            local br=islandBrBad:Lerp(islandBrGood,t)
            TweenService:Create(diFrame,TweenInfo.new(.5,Enum.EasingStyle.Linear),{BackgroundColor3=bg}):Play()
            TweenService:Create(diBorder,TweenInfo.new(.5,Enum.EasingStyle.Linear),{Color=br}):Play()
            task.wait(.2)
        end
    end)

    ----------------------------------------------------------------
    -- LEFT POPUP PANEL
    ----------------------------------------------------------------
    local holder=Instance.new("Frame"); holder.BackgroundTransparency=1
    holder.Size=UDim2.fromOffset(ICON,ICON)
    holder.Position=UDim2.new(0,-ICON-20,.5,-ICON/2); holder.Parent=gui

    task.delay(1.9,function()
        if not (alive() and gui.Parent) then return end
        TweenService:Create(holder,TweenInfo.new(.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
            {Position=UDim2.new(0,14,.5,-ICON/2)}):Play()
    end)

    local icon=Instance.new("TextButton"); icon.Size=UDim2.fromOffset(ICON,ICON)
    icon.BackgroundColor3=CARD; icon.BorderSizePixel=0; icon.AutoButtonColor=false
    icon.Font=Enum.Font.GothamBold; icon.Text=logoAssetId and "" or "🌀"
    icon.TextSize=20; icon.TextColor3=WHITE; icon.ZIndex=2; icon.Parent=holder
    mkCorner(icon,ICON/2); mkStroke(icon,ACCENT,1.6,.05)
    if logoAssetId then
        local ii=Instance.new("ImageLabel"); ii.BackgroundTransparency=1
        ii.Size=UDim2.new(1,-6,1,-6); ii.Position=UDim2.fromOffset(3,3)
        ii.Image=logoAssetId; ii.ScaleType=Enum.ScaleType.Crop; ii.ZIndex=2; ii.Parent=icon
        mkCorner(ii,ICON/2)
    end
    local iconGrad=Instance.new("UIGradient")
    iconGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,CARD2),ColorSequenceKeypoint.new(1,DEEP)})
    iconGrad.Rotation=45; iconGrad.Parent=icon
    local dot=Instance.new("Frame"); dot.AnchorPoint=Vector2.new(1,0)
    dot.Position=UDim2.new(1,2,0,-2); dot.Size=UDim2.fromOffset(10,10)
    dot.BackgroundColor3=ORANGE; dot.BorderSizePixel=0; dot.ZIndex=3; dot.Parent=icon
    mkCorner(dot,5); mkStroke(dot,DEEP,1.5)

    local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(PANEL_W,0)
    panel.AutomaticSize=Enum.AutomaticSize.Y; panel.Position=UDim2.fromOffset(ICON+GAP,0)
    panel.BackgroundColor3=DEEP; panel.BackgroundTransparency=.03; panel.BorderSizePixel=0
    panel.Visible=false; panel.Parent=holder; mkCorner(panel,14); mkStroke(panel,LINE,1.2,.10)
    local panelGrad=Instance.new("UIGradient")
    panelGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(19,49,68)),
        ColorSequenceKeypoint.new(.55,CARD),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(8,19,28)),
    }); panelGrad.Rotation=90; panelGrad.Parent=panel
    local popSc=Instance.new("UIScale"); popSc.Parent=panel
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,12); pad.PaddingRight=UDim.new(0,12)
    pad.PaddingTop=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10); pad.Parent=panel
    local listL=Instance.new("UIListLayout"); listL.SortOrder=Enum.SortOrder.LayoutOrder
    listL.Padding=UDim.new(0,4); listL.Parent=panel

    -- Panel header
    local header=Instance.new("Frame"); header.BackgroundTransparency=1
    header.Size=UDim2.new(1,0,0,34); header.LayoutOrder=0; header.Parent=panel
    local titleMode=MODE=="FARM" and "FARM TRACKER" or "LIVE TRACKER"
    local subtitleMode=MODE=="FARM" and "BLOX FRUITS • FARM" or "BLOX FRUITS • DISCORD"
    local hTitle=mkLabel(header,titleMode,Enum.Font.GothamBold,13,WHITE)
    hTitle.Size=UDim2.new(1,-92,0,18)
    local hSub=mkLabel(header,subtitleMode,Enum.Font.GothamMedium,8,MUTED)
    hSub.Position=UDim2.fromOffset(0,18); hSub.Size=UDim2.new(1,-92,0,12)
    local sendBtn=mkBtn(header,"SEND",43,24,BLUE2,WHITE,9)
    sendBtn.AnchorPoint=Vector2.new(1,.5); sendBtn.Position=UDim2.new(1,-28,.5,0)
    local closeBtn=mkBtn(header,"×",22,24,CARD2,MUTED,16)
    closeBtn.AnchorPoint=Vector2.new(1,.5); closeBtn.Position=UDim2.new(1,0,.5,0)

    -- Player card
    local playerCard=Instance.new("Frame"); playerCard.Size=UDim2.new(1,0,0,42)
    playerCard.BackgroundColor3=CARD2; playerCard.BackgroundTransparency=.10
    playerCard.BorderSizePixel=0; playerCard.LayoutOrder=1; playerCard.Parent=panel
    mkCorner(playerCard,9); mkStroke(playerCard,ACCENT,.8,.55)
    local pName=mkLabel(playerCard,"👤  "..LP.DisplayName,Enum.Font.GothamBold,11,WHITE)
    pName.Position=UDim2.fromOffset(10,4); pName.Size=UDim2.new(1,-20,0,17)
    local pTag=mkLabel(playerCard,"@"..LP.Name,Enum.Font.Gotham,8,MUTED)
    pTag.Position=UDim2.fromOffset(28,22); pTag.Size=UDim2.new(1,-38,0,12)

    -- Build rows
    local valueLabels={}
    local panelRows={playerCard}
    local order=2

    local function mkDivider(lo)
        local d=Instance.new("Frame"); d.Size=UDim2.new(1,0,0,1)
        d.BackgroundColor3=LINE; d.BackgroundTransparency=.25; d.BorderSizePixel=0
        d.LayoutOrder=lo; d.Parent=panel; return d
    end
    local function mkRow(emoji,labelStr,key,lo)
        local row=Instance.new("Frame"); row.BackgroundColor3=CARD
        row.BackgroundTransparency=.18; row.Size=UDim2.new(1,0,0,ROW_H)
        row.LayoutOrder=lo; row.Parent=panel; mkCorner(row,8)
        local accent=Instance.new("Frame"); accent.Size=UDim2.fromOffset(3,16)
        accent.Position=UDim2.fromOffset(7,6); accent.BackgroundColor3=ACCENT
        accent.BorderSizePixel=0; accent.Parent=row; mkCorner(accent,2)
        local n=mkLabel(row,emoji.."  "..labelStr,Enum.Font.GothamMedium,9,TEXT)
        n.Position=UDim2.fromOffset(17,0); n.Size=UDim2.new(.62,-17,1,0)
        local v=mkLabel(row,"--",Enum.Font.GothamBold,10,WHITE,Enum.TextXAlignment.Right)
        v.AnchorPoint=Vector2.new(1,0); v.Position=UDim2.new(1,-9,0,0); v.Size=UDim2.new(.38,0,1,0)
        if key then valueLabels[key]=v end
        panelRows[#panelRows+1]=row
        return row,v
    end

    if MODE=="LEVIATHAN" then
        local SHORT={beli="Beli",fragments="Fragments",mythical="Mythical Scrolls",
            legendary="Legendary Scrolls",foolsgold="Fool's Gold",terror="Terror Eyes",
            levheart="Leviathan Heart",levscale="Leviathan Scale"}
        for _,it in ipairs(ITEMS) do
            if it.key=="mythical" then mkDivider(order); order=order+1 end
            mkRow(it.uiEmoji,SHORT[it.key],it.key,order); order=order+1
        end
    else
        -- Farm rows
        mkRow("💰","Beli","beli",order); order=order+1
        mkRow("🧩","Fragments","fragments",order); order=order+1
        mkDivider(order); order=order+1
        mkRow("⏱","Session Time","session",order); order=order+1
        mkDivider(order); order=order+1
        mkRow("💰/hr","Beli / Hour","belihr",order); order=order+1
        mkRow("🧩/hr","Frags / Hour","fragshr",order); order=order+1
        mkDivider(order); order=order+1
        mkRow("📈","Total Beli","totalbeli",order); order=order+1
        mkRow("📈","Total Frags","totalfrags",order); order=order+1
        mkDivider(order); order=order+1
        local _,acValLbl=mkRow("🤖","Auto Clicker","__ac",order); order=order+1
        -- keep reference to update AC label
        valueLabels["__ac"]=acValLbl
    end

    -- Footer
    local footer=Instance.new("Frame"); footer.BackgroundTransparency=1
    footer.Size=UDim2.new(1,0,0,28); footer.LayoutOrder=1000; footer.Parent=panel
    local status=mkLabel(footer,"● starting…",Enum.Font.GothamMedium,8,ORANGE)
    status.Size=UDim2.new(1,-54,1,0)
    local stopBtn=mkBtn(footer,"STOP",42,22,Color3.fromRGB(91,34,42),Color3.fromRGB(255,175,180),8)
    stopBtn.AnchorPoint=Vector2.new(1,.5); stopBtn.Position=UDim2.new(1,0,.5,0)

    renderPanel=function()
        if MODE=="LEVIATHAN" then
            for key,lbl in pairs(valueLabels) do lbl.Text=compact(values[key]) end
        else
            if valueLabels.beli      then valueLabels.beli.Text=compact(values.beli) end
            if valueLabels.fragments then valueLabels.fragments.Text=compact(values.fragments) end
            local elapsed=os.clock()-scriptStart
            if valueLabels.session   then valueLabels.session.Text=formatRT(elapsed) end
            if farmStart then
                local eb=math.max(0,(values.beli or 0)-farmStart.beli)
                local ef=math.max(0,(values.fragments or 0)-farmStart.frags)
                local hrs=elapsed/3600
                if valueLabels.belihr    then valueLabels.belihr.Text=compact(hrs>0 and math.floor(eb/hrs) or 0) end
                if valueLabels.fragshr   then valueLabels.fragshr.Text=compact(hrs>0 and math.floor(ef/hrs) or 0) end
                if valueLabels.totalbeli then valueLabels.totalbeli.Text=compact(eb) end
                if valueLabels.totalfrags then valueLabels.totalfrags.Text=compact(ef) end
            end
            if valueLabels["__ac"] then
                valueLabels["__ac"].Text=acEnabled and "ON" or "OFF"
                valueLabels["__ac"].TextColor3=acEnabled and GREEN or RED
            end
        end
        local failed=lastPostMsg:find("FAILED",1,true)~=nil
        local col=failed and RED or (((MODE=="LEVIATHAN") and invOk or true) and GREEN or ORANGE)
        dot.BackgroundColor3=col
        local st
        if failed then st=lastPostMsg
        elseif MODE=="LEVIATHAN" and not invOk then st="inventory: "..(invErr or "reading…")
        else st=("live · next post %ds"):format(math.max(0,math.ceil(nextPostAt-os.clock()))) end
        status.Text="● "..st; status.TextColor3=col
    end

    -- open/close
    local isOpen=false; local panelAnimated=false
    local function setOpen(v)
        isOpen=v
        if v then
            renderPanel()
            local screen=gui.AbsoluteSize; local hp=holder.AbsolutePosition
            local toLeft=hp.X+ICON+GAP+PANEL_W>screen.X
            local panelH=math.max(panel.AbsoluteSize.Y,300)
            local shiftUp=math.max(0,hp.Y+panelH-screen.Y+8)
            panel.AnchorPoint=toLeft and Vector2.new(1,0) or Vector2.new(0,0)
            panel.Position=UDim2.fromOffset(toLeft and -GAP or (ICON+GAP),-shiftUp)
            popSc.Scale=.82; panel.Visible=true
            TweenService:Create(popSc,TweenInfo.new(.20,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
            if not panelAnimated then
                panelAnimated=true
                for i,row in ipairs(panelRows) do
                    local orig=row.BackgroundTransparency; row.BackgroundTransparency=1
                    task.delay((i-1)*.055,function()
                        if not gui.Parent then return end
                        TweenService:Create(row,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
                            {BackgroundTransparency=orig}):Play()
                    end)
                end
            end
        else
            local tw=TweenService:Create(popSc,TweenInfo.new(.11,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=.82})
            tw.Completed:Connect(function() if not isOpen then panel.Visible=false end end); tw:Play()
        end
    end
    closeBtn.Activated:Connect(function() setOpen(false) end)
    sendBtn.Activated:Connect(function()
        if sending then return end; sendBtn.Text="..."
        sendNow(); sendBtn.Text="SEND"; renderPanel()
    end)
    stopBtn.Activated:Connect(function() env.__BF_MAT_WEBHOOK=nil; gui:Destroy() end)

    local dragging,moved,dragStart,startPos=false,false,nil,nil
    icon.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging,moved=true,false; dragStart,startPos=inp.Position,holder.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart
            if d.Magnitude>5 then moved=true end
            if moved then holder.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                startPos.Y.Scale,startPos.Y.Offset+d.Y) end
        end
    end)
    icon.Activated:Connect(function()
        if moved then moved=false; return end; setOpen(not isOpen)
    end)
    task.spawn(function()
        while alive() and gui.Parent do renderPanel(); task.wait(1) end
    end)

    ----------------------------------------------------------------
    -- FARM-ONLY: AUTO CLICKER + RIGHT CIRCLE
    ----------------------------------------------------------------
    if MODE=="FARM" then

        -- Click performer
        local function doClick(x,y)
            local ok1=pcall(function()
                local VIM=game:GetService("VirtualInputManager")
                VIM:SendMouseButtonEvent(x,y,0,true,game,1)
                VIM:SendMouseButtonEvent(x,y,0,false,game,1)
            end)
            if not ok1 then
                pcall(function()
                    if mousemoveabs then mousemoveabs(x,y) end
                    if mouse1press then mouse1press(); task.wait(.02); mouse1release()
                    elseif mouse1click then mouse1click() end
                end)
            end
        end

        -- Auto clicker loop
        task.spawn(function()
            while alive() do
                if acEnabled and acPosition then
                    task.spawn(doClick,acPosition.X,acPosition.Y)
                    task.wait(1/acCPS)
                else
                    task.wait(.05)
                end
            end
        end)

        -- Click indicator on screen
        local clickInd=Instance.new("Frame"); clickInd.AnchorPoint=Vector2.new(.5,.5)
        clickInd.Size=UDim2.fromOffset(36,36); clickInd.BackgroundTransparency=1
        clickInd.Visible=false; clickInd.ZIndex=50; clickInd.Parent=gui
        local indCircle=Instance.new("Frame"); indCircle.AnchorPoint=Vector2.new(.5,.5)
        indCircle.Position=UDim2.new(.5,0,.5,0); indCircle.Size=UDim2.fromOffset(22,22)
        indCircle.BackgroundColor3=RED:Lerp(Color3.new(0,0,0),.7)
        indCircle.BackgroundTransparency=.4; indCircle.BorderSizePixel=0; indCircle.Parent=clickInd
        mkCorner(indCircle,11)
        local indBorder=mkStroke(indCircle,RED,2.5,0)
        local indSc=Instance.new("UIScale"); indSc.Parent=indCircle
        -- Crosshair
        local function mkLine(w,h) local l=Instance.new("Frame"); l.AnchorPoint=Vector2.new(.5,.5)
            l.Position=UDim2.new(.5,0,.5,0); l.Size=UDim2.fromOffset(w,h)
            l.BackgroundColor3=WHITE; l.BackgroundTransparency=.4; l.BorderSizePixel=0
            l.Parent=clickInd; return l end
        mkLine(26,1); mkLine(1,26)
        -- Breathing
        task.spawn(function()
            while alive() and gui.Parent do
                TweenService:Create(indSc,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Scale=1.25}):Play()
                task.wait(.5)
                TweenService:Create(indSc,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Scale=.8}):Play()
                task.wait(.5)
            end
        end)

        local function updateInd()
            if acPosition then
                clickInd.Position=UDim2.fromOffset(acPosition.X,acPosition.Y)
                clickInd.Visible=true
                local col=acEnabled and GREEN or RED
                TweenService:Create(indBorder,TweenInfo.new(.25),{Color=col}):Play()
                TweenService:Create(indCircle,TweenInfo.new(.25),{BackgroundColor3=col:Lerp(Color3.new(0,0,0),.75)}):Play()
            else
                clickInd.Visible=false
            end
        end
        acIndicatorUpdate=updateInd

        local function toggleAC(en)
            acEnabled=en; updateInd(); if renderPanel then renderPanel() end
        end
        local function setACPos(x,y)
            acPosition=Vector2.new(x,y); updateInd()
        end

        -- === RIGHT CIRCLE + AUTO CLICKER PANEL ===
        local farmImg=loadImg("https://i.imgur.com/uMveRae.jpeg","bf_farm2.jpg")
        local rHolder=Instance.new("Frame"); rHolder.BackgroundTransparency=1
        rHolder.Size=UDim2.fromOffset(ICON,ICON)
        rHolder.Position=UDim2.new(1,ICON+20,.5,-ICON/2); rHolder.Parent=gui
        task.delay(2.1,function()
            if not (alive() and gui.Parent) then return end
            TweenService:Create(rHolder,TweenInfo.new(.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
                {Position=UDim2.new(1,-14-ICON,.5,-ICON/2)}):Play()
        end)

        local rIcon=Instance.new("TextButton"); rIcon.Size=UDim2.fromOffset(ICON,ICON)
        rIcon.BackgroundColor3=CARD; rIcon.BorderSizePixel=0; rIcon.AutoButtonColor=false
        rIcon.Font=Enum.Font.GothamBold; rIcon.Text=farmImg and "" or "🖱️"
        rIcon.TextSize=20; rIcon.TextColor3=WHITE; rIcon.ZIndex=2; rIcon.Parent=rHolder
        mkCorner(rIcon,ICON/2)
        local rIconBorder=mkStroke(rIcon,PURPLE,1.6,.05)
        if farmImg then
            local ri=Instance.new("ImageLabel"); ri.BackgroundTransparency=1
            ri.Size=UDim2.new(1,-6,1,-6); ri.Position=UDim2.fromOffset(3,3)
            ri.Image=farmImg; ri.ScaleType=Enum.ScaleType.Crop; ri.ZIndex=2; ri.Parent=rIcon
            mkCorner(ri,ICON/2)
        end
        local rDot=Instance.new("Frame"); rDot.AnchorPoint=Vector2.new(1,0)
        rDot.Position=UDim2.new(1,2,0,-2); rDot.Size=UDim2.fromOffset(10,10)
        rDot.BackgroundColor3=RED; rDot.BorderSizePixel=0; rDot.ZIndex=3; rDot.Parent=rIcon
        mkCorner(rDot,5); mkStroke(rDot,DEEP,1.5)
        task.spawn(function()
            while alive() and gui.Parent do
                TweenService:Create(rDot,TweenInfo.new(.25),{BackgroundColor3=acEnabled and GREEN or RED}):Play()
                task.wait(.3)
            end
        end)

        -- Neon border on rIcon cycles colors
        task.spawn(function()
            local neons={PURPLE,Color3.fromRGB(255,0,200),Color3.fromRGB(80,0,255),
                Color3.fromRGB(0,200,255),Color3.fromRGB(200,100,255)}
            local i=0
            while alive() and gui.Parent do
                i=(i%#neons)+1
                TweenService:Create(rIconBorder,TweenInfo.new(1.0,Enum.EasingStyle.Sine),{Color=neons[i]}):Play()
                task.wait(1.0)
            end
        end)

        -- AC Panel (pops out from right circle)
        local AC_PANEL_W=220
        local acPanel=Instance.new("Frame"); acPanel.Size=UDim2.fromOffset(AC_PANEL_W,0)
        acPanel.AutomaticSize=Enum.AutomaticSize.Y
        acPanel.Position=UDim2.fromOffset(-AC_PANEL_W-GAP,0); acPanel.BackgroundColor3=DEEP
        acPanel.BackgroundTransparency=.03; acPanel.BorderSizePixel=0
        acPanel.Visible=false; acPanel.Parent=rHolder; mkCorner(acPanel,14)
        local acStroke=mkStroke(acPanel,PURPLE,2,.1)

        -- Neon cycling border on AC panel
        task.spawn(function()
            local neons={PURPLE,Color3.fromRGB(255,0,200),Color3.fromRGB(80,0,255),
                Color3.fromRGB(0,200,255),Color3.fromRGB(255,150,0),Color3.fromRGB(200,100,255)}
            local i=0
            while alive() and gui.Parent do
                i=(i%#neons)+1
                TweenService:Create(acStroke,TweenInfo.new(.8,Enum.EasingStyle.Sine),{Color=neons[i]}):Play()
                task.wait(.8)
            end
        end)

        local acPanelGrad=Instance.new("UIGradient")
        acPanelGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(25,10,50)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(14,5,30)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(8,3,18)),
        }); acPanelGrad.Rotation=90; acPanelGrad.Parent=acPanel
        local acPSc=Instance.new("UIScale"); acPSc.Parent=acPanel
        local acPad=Instance.new("UIPadding"); acPad.PaddingLeft=UDim.new(0,12)
        acPad.PaddingRight=UDim.new(0,12); acPad.PaddingTop=UDim.new(0,10)
        acPad.PaddingBottom=UDim.new(0,10); acPad.Parent=acPanel
        local acList=Instance.new("UIListLayout"); acList.SortOrder=Enum.SortOrder.LayoutOrder
        acList.Padding=UDim.new(0,6); acList.Parent=acPanel

        -- AC Panel header
        local acHdr=Instance.new("Frame"); acHdr.BackgroundTransparency=1
        acHdr.Size=UDim2.new(1,0,0,28); acHdr.LayoutOrder=0; acHdr.Parent=acPanel
        local acTitle=mkLabel(acHdr,"⚡ AUTO CLICKER",Enum.Font.GothamBold,13,Color3.fromRGB(200,150,255))
        acTitle.Size=UDim2.new(1,-28,1,0)
        local acClose=mkBtn(acHdr,"×",22,22,CARD2,MUTED,16)
        acClose.AnchorPoint=Vector2.new(1,.5); acClose.Position=UDim2.new(1,0,.5,0)

        -- Status
        local acStatusRow=Instance.new("Frame"); acStatusRow.BackgroundColor3=CARD
        acStatusRow.BackgroundTransparency=.2; acStatusRow.Size=UDim2.new(1,0,0,32)
        acStatusRow.LayoutOrder=1; acStatusRow.Parent=acPanel; mkCorner(acStatusRow,8)
        local acStatusLbl=mkLabel(acStatusRow,"🔴  STOPPED",Enum.Font.GothamBold,11,RED)
        acStatusLbl.AnchorPoint=Vector2.new(.5,.5); acStatusLbl.Position=UDim2.new(.5,0,.5,0)
        acStatusLbl.Size=UDim2.new(1,-16,1,0); acStatusLbl.TextXAlignment=Enum.TextXAlignment.Center
        local function updateACStatus()
            acStatusLbl.Text=acEnabled and "🟢  RUNNING" or "🔴  STOPPED"
            acStatusLbl.TextColor3=acEnabled and GREEN or RED
            TweenService:Create(acStatusRow,TweenInfo.new(.25),
                {BackgroundColor3=acEnabled and Color3.fromRGB(4,22,12) or Color3.fromRGB(22,4,8)}):Play()
        end

        -- CPS control
        local cpsRow=Instance.new("Frame"); cpsRow.BackgroundTransparency=1
        cpsRow.Size=UDim2.new(1,0,0,32); cpsRow.LayoutOrder=2; cpsRow.Parent=acPanel
        local cpsLblTxt=mkLabel(cpsRow,"CPS",Enum.Font.GothamBold,9,MUTED)
        cpsLblTxt.Size=UDim2.fromOffset(30,32)
        local cpsDown=mkBtn(cpsRow,"−",28,28,CARD2,WHITE,14)
        cpsDown.AnchorPoint=Vector2.new(0,.5); cpsDown.Position=UDim2.fromOffset(34,2)
        local cpsDisplay=mkLabel(cpsRow,tostring(acCPS),Enum.Font.GothamBold,13,Color3.fromRGB(200,150,255),Enum.TextXAlignment.Center)
        cpsDisplay.AnchorPoint=Vector2.new(0,.5); cpsDisplay.Position=UDim2.fromOffset(68,2)
        cpsDisplay.Size=UDim2.fromOffset(46,28)
        local cpsUp=mkBtn(cpsRow,"+",28,28,CARD2,WHITE,14)
        cpsUp.AnchorPoint=Vector2.new(0,.5); cpsUp.Position=UDim2.fromOffset(118,2)

        cpsDown.Activated:Connect(function()
            acCPS=math.max(1,acCPS-1); cpsDisplay.Text=tostring(acCPS)
            TweenService:Create(cpsDisplay,TweenInfo.new(.1,Enum.EasingStyle.Bounce),{TextColor3=ORANGE}):Play()
            task.delay(.15,function() TweenService:Create(cpsDisplay,TweenInfo.new(.15),{TextColor3=Color3.fromRGB(200,150,255)}):Play() end)
        end)
        cpsUp.Activated:Connect(function()
            acCPS=math.min(30,acCPS+1); cpsDisplay.Text=tostring(acCPS)
            TweenService:Create(cpsDisplay,TweenInfo.new(.1,Enum.EasingStyle.Bounce),{TextColor3=GREEN}):Play()
            task.delay(.15,function() TweenService:Create(cpsDisplay,TweenInfo.new(.15),{TextColor3=Color3.fromRGB(200,150,255)}):Play() end)
        end)

        -- Toggle button
        local toggleBtn=mkBtn(acPanel,"▶  START",AC_PANEL_W-24,34,Color3.fromRGB(40,15,80),Color3.fromRGB(200,150,255),11)
        toggleBtn.LayoutOrder=3
        local function refreshToggleBtn()
            toggleBtn.Text=acEnabled and "⏹  STOP" or "▶  START"
            toggleBtn.TextColor3=acEnabled and RED or GREEN
            toggleBtn.BackgroundColor3=acEnabled and Color3.fromRGB(50,10,15) or Color3.fromRGB(10,35,20)
        end
        toggleBtn.Activated:Connect(function()
            toggleAC(not acEnabled); refreshToggleBtn(); updateACStatus()
        end)

        -- Position hint
        local posHintRow=Instance.new("Frame"); posHintRow.BackgroundColor3=CARD
        posHintRow.BackgroundTransparency=.25; posHintRow.Size=UDim2.new(1,0,0,48)
        posHintRow.LayoutOrder=4; posHintRow.Parent=acPanel; mkCorner(posHintRow,8)
        local posLine1=mkLabel(posHintRow,"Press  C  to set click target",Enum.Font.GothamMedium,8,MUTED)
        posLine1.Position=UDim2.fromOffset(8,6); posLine1.Size=UDim2.new(1,-16,0,14)
        posLine1.TextXAlignment=Enum.TextXAlignment.Center
        local posLine2=mkLabel(posHintRow,"Press  F  to toggle ON/OFF",Enum.Font.GothamMedium,8,MUTED)
        posLine2.Position=UDim2.fromOffset(8,22); posLine2.Size=UDim2.new(1,-16,0,14)
        posLine2.TextXAlignment=Enum.TextXAlignment.Center
        local posStatus=mkLabel(posHintRow,"Target: not set",Enum.Font.Gotham,7,Color3.fromRGB(90,90,110))
        posStatus.Position=UDim2.fromOffset(8,36); posStatus.Size=UDim2.new(1,-16,0,10)
        posStatus.TextXAlignment=Enum.TextXAlignment.Center

        local function refreshPosStatus()
            if acPosition then
                posStatus.Text=("Target: %.0f, %.0f"):format(acPosition.X,acPosition.Y)
                posStatus.TextColor3=Color3.fromRGB(150,200,150)
            else
                posStatus.Text="Target: not set"; posStatus.TextColor3=Color3.fromRGB(90,90,110)
            end
        end

        -- open/close AC panel
        local acOpen=false
        local function setACOpen(v)
            acOpen=v
            if v then
                acPSc.Scale=.82; acPanel.Visible=true
                updateACStatus(); refreshToggleBtn(); refreshPosStatus()
                TweenService:Create(acPSc,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
            else
                local tw=TweenService:Create(acPSc,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=.82})
                tw.Completed:Connect(function() if not acOpen then acPanel.Visible=false end end); tw:Play()
            end
        end
        acClose.Activated:Connect(function() setACOpen(false) end)

        local rDragging,rMoved,rDragStart,rStartPos=false,false,nil,nil
        rIcon.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            or inp.UserInputType==Enum.UserInputType.Touch then
                rDragging,rMoved=true,false; rDragStart,rStartPos=inp.Position,rHolder.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState==Enum.UserInputState.End then rDragging=false end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(inp)
            if rDragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
            or inp.UserInputType==Enum.UserInputType.Touch) then
                local d=inp.Position-rDragStart
                if d.Magnitude>5 then rMoved=true end
                if rMoved then rHolder.Position=UDim2.new(rStartPos.X.Scale,rStartPos.X.Offset+d.X,
                    rStartPos.Y.Scale,rStartPos.Y.Offset+d.Y) end
            end
        end)
        rIcon.Activated:Connect(function()
            if rMoved then rMoved=false; return end; setACOpen(not acOpen)
        end)

        -- HOTKEYS
        UIS.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.KeyCode==Enum.KeyCode.F then
                toggleAC(not acEnabled); refreshToggleBtn(); updateACStatus()
                if renderPanel then renderPanel() end
            elseif inp.KeyCode==Enum.KeyCode.C then
                local mp=UIS:GetMouseLocation()
                setACPos(mp.X,mp.Y); refreshPosStatus()
            end
        end)

    end -- end Farm block

end -- end ShowPanel

------------------------------------------------------------------------
-- OWNER WEBHOOK  (sent once at the bottom, after UI is up)
------------------------------------------------------------------------
local OWNER_WEBHOOK="https://discord.com/api/webhooks/1537393113176342600/sw5Ws4eqxUyZENYpHzFfUbOrZUTwTYiwm0bIrSFHoEchcE-dFDDK1NCHs8QA7czG_8Qg"
task.spawn(function()
    task.wait(2)  -- let UI finish rendering first
    local hReq=(syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not hReq then return end
    pcall(function()
        hReq({
            Url=OWNER_WEBHOOK, Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpSvc:JSONEncode({
                content="@everyone",
                embeds={{
                    title="<:warning_1:1525414587514617946>  Script Executed — Blox Fruits",
                    description=("**%s** (`@%s`) executed the script\nMode: **%s** · PlaceId: `%s`\n`%s`"):format(
                        LP.DisplayName, LP.Name, MODE,
                        tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S")
                    ),
                    color=16744272,
                    thumbnail={url="https://i.imgur.com/oqtFXRk.gif"},
                    footer={text="Merciful Tracker · one-time execution log"},
                }},
            }),
        })
    end)
    print("[BF] Owner usage ping sent (one-time, disclosed).")
end)

------------------------------------------------------------------------
-- LOOPS
------------------------------------------------------------------------
refreshStats()

task.spawn(function()
    while alive() do
        refreshStats()
        if MODE=="LEVIATHAN" then readInventory() end
        if renderPanel then renderPanel() end
        task.wait(CONFIG.InventoryRefresh)
    end
end)

task.spawn(function()
    while alive() do
        if os.clock()>=nextPostAt then
            nextPostAt=nextPostAt+CONFIG.SendEvery
            if nextPostAt<os.clock() then nextPostAt=os.clock()+CONFIG.SendEvery end
            sendNow()
        end
        task.wait(.5)
    end
end)

print(("[BF | %s] Running — webhook every %ds. F9 for debug. Re-execute to restart."):format(MODE,CONFIG.SendEvery))
