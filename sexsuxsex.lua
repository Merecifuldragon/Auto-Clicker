-- Blox Fruits | Crew Tools
-- Owner/Creator: Merciful
-- Modified sync build: replacement snapshots + distributed cancel

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LogService         = game:GetService("LogService")
local HttpService        = game:GetService("HttpService")

local LocalPlayer  = Players.LocalPlayer
local INVITE_DELAY = 0.5
local SYNC_FILE    = "bf_crew_sync.txt"
local hasFS        = type(writefile) == "function" and type(readfile) == "function"
SCRIPT_READY = true

local W, H, MH = 430, 840, 64   -- window width, full height, mini height

local THEME = {
    BG      = Color3.fromRGB(8,    8,   16),
    PANEL   = Color3.fromRGB(14,  14,   26),
    CARD    = Color3.fromRGB(20,  20,   38),
    CARD2   = Color3.fromRGB(28,  28,   50),
    ACCENT  = Color3.fromRGB(99,  102, 241),
    ACCENT2 = Color3.fromRGB(168,  85, 247),
    TEXT    = Color3.fromRGB(248, 248, 255),
    SUB     = Color3.fromRGB(148, 148, 185),
    DIM     = Color3.fromRGB(72,   72, 108),
    SUCCESS = Color3.fromRGB(52,  211, 153),
    ERROR   = Color3.fromRGB(248, 113, 113),
    WARN    = Color3.fromRGB(251, 191,  36),
    BORDER  = Color3.fromRGB(42,   42,  72),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- PERFORMANCE MODE — cuts render/memory overhead so the GUI + sync logic stay
-- smooth on low-end devices or when running several accounts side by side.
-- Runs once at script start, before the GUI is built.
-- ══════════════════════════════════════════════════════════════════════════════
local function PerformanceMode()
    if setfpscap then
        pcall(setfpscap, 10)
    end

    -- Keep the client capped at exactly 10 FPS for the whole session.
    -- Some environments can reset the cap, so re-apply it periodically.
    task.spawn(function()
        while true do
            pcall(function()
                if setfpscap then
                    setfpscap(10)
                end
            end)
            task.wait(1)
        end
    end)

    task.spawn(function()
        pcall(function() RunService:Set3dRenderingEnabled(false) end)
    end)
    task.spawn(function()
        pcall(function()
            settings().Rendering.QualityLevel        = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)
        pcall(function() workspace.Terrain:Clear() end)
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = false
            Lighting:ClearAllChildren()
        end)
    end)
end
PerformanceMode()

-- periodic memory / log cleanup — cheap, runs every 30s
task.spawn(function()
    while true do
        task.wait(30)
        collectgarbage("collect")
        pcall(function()
            if setmemoryunit then setmemoryunit("VideoMemory", 0) end
        end)
        pcall(function() LogService:Clear() end)
    end
end)

-- anti-idle: jump every 30–50s (randomized) instead of a fixed long timer.
-- Uses Humanoid.Jump when a character exists (cheap, no input simulation
-- overhead); falls back to a simulated Space press if there's no character yet.
task.spawn(function()
    pcall(function()
        if getconnections then
            for _, connection in pairs(getconnections(LocalPlayer.Idled)) do
                connection:Disable()
            end
        end
    end)
    while true do
        task.wait(math.random(30, 50))
        pcall(function()
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true
            else
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
        end)
    end
end)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function tw(o, p, t, s, d)
    TweenService:Create(o, TweenInfo.new(t or 0.2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
end
local function corner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 10) c.Parent=p return c end
local function stroke(p, col, th) local s=Instance.new("UIStroke") s.Color=col or THEME.BORDER s.Thickness=th or 1 s.Parent=p return s end
local function grad(p, c0, c1, r) local g=Instance.new("UIGradient") g.Color=ColorSequence.new(c0,c1) g.Rotation=r or 0 g.Parent=p return g end
local function pad(p, l, r, t, b) local u=Instance.new("UIPadding") u.PaddingLeft=UDim.new(0,l) u.PaddingRight=UDim.new(0,r) u.PaddingTop=UDim.new(0,t) u.PaddingBottom=UDim.new(0,b) u.Parent=p end
local function vlist(p, gap) local l=Instance.new("UIListLayout") l.SortOrder=Enum.SortOrder.LayoutOrder l.Padding=UDim.new(0,gap or 8) l.Parent=p return l end
local function hlist(p, gap) local l=Instance.new("UIListLayout") l.FillDirection=Enum.FillDirection.Horizontal l.SortOrder=Enum.SortOrder.LayoutOrder l.Padding=UDim.new(0,gap or 8) l.Parent=p return l end
local function trim(s) return s:match("^%s*(.-)%s*$") end
function newSyncId()
    return string.format("%.0f-%06d", os.time()*1000, math.random(0,999999))
end

SYNC_TMP_FILE = "bf_crew_sync.tmp"
SYNC_MIRROR_FILE = "bf_crew_sync_mirror.txt"

local function writeSharedSync(raw)
    if not hasFS then return false,"file API unavailable" end
    -- Write the replacement first, then remove the old snapshot and immediately
    -- recreate it. This keeps the original file-based multi-instance architecture.
    local okTmp = pcall(writefile, SYNC_TMP_FILE, raw)
    if not okTmp then
        pcall(function() if type(delfile)=="function" then delfile(SYNC_FILE) end end)
        local okDirect, errDirect = pcall(writefile, SYNC_FILE, raw)
        if not okDirect then return false, errDirect end
        pcall(function() if type(delfile)=="function" then delfile(SYNC_TMP_FILE) end end)
        pcall(function() if type(delfile)=="function" then delfile(SYNC_MIRROR_FILE) end end)
        pcall(writefile, SYNC_MIRROR_FILE, raw)
        return true
    end
    pcall(function() if type(delfile)=="function" then delfile(SYNC_FILE) end end)
    local ok, err = pcall(writefile, SYNC_FILE, raw)
    pcall(function() if type(delfile)=="function" then delfile(SYNC_TMP_FILE) end end)
    if not ok then return false, err end
    pcall(function() if type(delfile)=="function" then delfile(SYNC_MIRROR_FILE) end end)
    pcall(writefile, SYNC_MIRROR_FILE, raw)
    return true
end

local function readSharedSync()
    if not hasFS then return "" end
    local ok,data=pcall(readfile,SYNC_FILE)
    if ok and type(data)=="string" and data~="" then return data end
    local ok2,data2=pcall(readfile,SYNC_MIRROR_FILE)
    if ok2 and type(data2)=="string" then return data2 end
    return ""
end

-- ── Remotes ───────────────────────────────────────────────────────────────────
local function deepFind(root, fn)
    for _,v in ipairs(root:GetDescendants()) do if fn(v) then return v end end
end

-- Confirmed Blox Fruits remote: ReplicatedStorage.Remotes.Crew (RemoteFunction)
local function getCrewRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then return remotes:FindFirstChild("Crew") end
    return nil
end

-- ── Logic ─────────────────────────────────────────────────────────────────────
local inviting = false
local invitedPlayers = {}   -- username → true when we successfully invited them

-- returns true if res looks like a server success (not false/nil/"failed"/etc.)
local function resIsSuccess(res)
    if res == nil   then return false end
    if res == false then return false end
    local s = tostring(res):lower()
    if s == "false" or s:find("fail") or s:find("error") or s:find("invalid")
       or s:find("no invite") or s:find("already") then return false end
    return true
end

local function invitePlayer(username, logFn)
    local t = Players:FindFirstChild(username)
    if not t then logFn("NOT IN SERVER: "..username, THEME.WARN) return false end
    if t == LocalPlayer then logFn("SKIPPED SELF: "..username, THEME.DIM) return false end

    local crew = getCrewRemote()
    if not crew then logFn("Remotes.Crew not found", THEME.ERROR) return false end

    local attempts = {
        function() return crew:InvokeServer("Invite", {UserID = t.UserId}) end,
        function() return crew:InvokeServer("Invite", t.UserId) end,
        function() return crew:InvokeServer("Invite", t) end,
        function() return crew:InvokeServer("SendInvite", {UserID = t.UserId}) end,
    }
    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        logFn("Invite res ["..username.."]: "..tostring(res), THEME.DIM)
        if ok and resIsSuccess(res) then
            invitedPlayers[username] = true
            logFn("INVITED: "..username, THEME.SUCCESS)
            return true
        end
    end

    logFn("FAILED: "..username.." — server rejected all invite formats", THEME.ERROR)
    return false
end

local function joinCrew(crewId, logFn)
    local crew = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Crew")

    crewId = tostring(crewId):gsub("%s+", "")
    if crewId == "" then logFn("Invalid Crew ID", THEME.ERROR) return false end

    logFn("Joining: "..crewId, THEME.SUB)

    local attempts = {
        function() return crew:InvokeServer("Join",     {CrewID = crewId}) end,
        function() return crew:InvokeServer("Join",     crewId)            end,
        function() return crew:InvokeServer("JoinCrew", {CrewID = crewId}) end,
        function() return crew:InvokeServer("JoinCrew", crewId)            end,
    }

    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        -- always log the real server response so the user can see what the server says
        logFn("Server res: "..tostring(res), ok and THEME.SUB or THEME.DIM)
        if ok and resIsSuccess(res) then
            logFn("Joined crew!", THEME.SUCCESS)
            return true
        end
        task.wait(0.3)  -- brief gap between attempts — avoids anti-spam
    end

    -- one retry after a short pause (server may need time between requests)
    task.wait(1.5)
    logFn("Retrying after pause...", THEME.WARN)
    local ok, res = pcall(function()
        return crew:InvokeServer("Join", {CrewID = crewId})
    end)
    logFn("Retry res: "..tostring(res), THEME.SUB)
    if ok and resIsSuccess(res) then
        logFn("Joined crew on retry!", THEME.SUCCESS)
        return true
    end

    logFn("Join failed — server response: "..tostring(res), THEME.ERROR)
    return false
end

-- ── Webhook sender ────────────────────────────────────────────────────────────
local function httpPost(url, bodyTable)
    local body = HttpService:JSONEncode(bodyTable)
    local reqFn = (syn and syn.request) or http_request or request or (http and http.request)
    if reqFn then
        local ok, res = pcall(reqFn, {
            Url = url, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
        if ok then return res end
    end
    local ok2, res2 = pcall(function()
        return HttpService:RequestAsync({
            Url = url, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)
    if ok2 then return res2 end
    return nil
end

local function sendCrewWebhook(url, logFn)
    url = tostring(url):match("^%s*(.-)%s*$")
    if url == "" then logFn("Enter a webhook URL first", THEME.ERROR) return false end
    if not url:match("^https?://") then logFn("That doesn't look like a valid URL", THEME.ERROR) return false end

    local ok, membersGui = pcall(function()
        return LocalPlayer.PlayerGui.Main.Crew.Main.Members
    end)
    if not ok or not membersGui then
        logFn("Couldn't find the crew Members GUI — open the Crew menu in-game first", THEME.ERROR)
        return false
    end

    local crewList = {}
    for _, entry in ipairs(membersGui:GetDescendants()) do
        if (entry:IsA("Frame") or entry:IsA("ScrollingFrame")) and entry:FindFirstChild("Name") then
            local nameObj   = entry:FindFirstChild("Name")
            local levelObj  = entry:FindFirstChild("Level")
            local bountyObj = entry:FindFirstChild("Bounty")
            if nameObj then
                table.insert(crewList, {
                    name   = nameObj.Text,
                    level  = levelObj and levelObj.Text or "N/A",
                    bounty = bountyObj and bountyObj.Text or "0",
                })
            end
        end
    end

    if #crewList == 0 then
        logFn("No crew members found — is the Crew menu open?", THEME.WARN)
        return false
    end

    local headers, perfect30M, others = {}, {}, {}
    for _, m in ipairs(crewList) do
        local cleanBounty = m.bounty:gsub("%$", ""):gsub(" ", "")
        if m.name:lower() == "name" or m.bounty:lower():find("bounty") then
            table.insert(headers, m)
        elseif cleanBounty:find("30%.00M") or cleanBounty:find("30M") then
            table.insert(perfect30M, m)
        else
            table.insert(others, m)
        end
    end
    table.sort(perfect30M, function(a,b) return a.name:lower() < b.name:lower() end)
    table.sort(others,     function(a,b) return a.name:lower() < b.name:lower() end)

    local embeds = {}
    if #headers > 0 then
        local desc = "**Name** │ **Level** │ **Bounty**\n"
        for _, h in ipairs(headers) do
            desc = desc..h.name.." │ "..h.level.." │ "..h.bounty.."\n"
        end
        table.insert(embeds, { title = "📋 Crew List Header", description = desc, color = 0x7289DA })
    end
    if #perfect30M > 0 then
        local desc = ""
        for i, m in ipairs(perfect30M) do
            desc = desc..string.format("**%d.** %s • **Lv.%s** • `%s`\n", i, m.name, m.level, m.bounty)
        end
        table.insert(embeds, { title = "🌟 Perfect 30M Members", description = desc, color = 0x00FF88, footer = { text = "Total: "..#perfect30M } })
    end
    if #others > 0 then
        local desc = ""
        for i, m in ipairs(others) do
            desc = desc..string.format("**%d.** %s • **Lv.%s** • `%s`\n", i, m.name, m.level, m.bounty)
        end
        table.insert(embeds, { title = "📌 Other Members", description = desc, color = 0xFFAA00, footer = { text = "Total: "..#others } })
    end

    local payload = {
        username = "Crew Tracker",
        content  = "**Crew Snapshot** • **Total Members:** "..#crewList,
        embeds   = embeds,
    }

    logFn("Sending webhook — "..#crewList.." member(s)...", THEME.SUB)
    local res = httpPost(url, payload)
    if res and (res.StatusCode == 200 or res.StatusCode == 204) then
        logFn("Webhook sent successfully!", THEME.SUCCESS)
        return true
    else
        logFn("Failed to send webhook — check the URL and try again", THEME.ERROR)
        return false
    end
end

-- ── GUI root ──────────────────────────────────────────────────────────────────
local old = LocalPlayer.PlayerGui:FindFirstChild("CrewToolsGui")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name="CrewToolsGui" Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Gui.ResetOnSpawn=false Gui.IgnoreGuiInset=true Gui.Parent=LocalPlayer.PlayerGui

-- Full-screen black backdrop.
-- It is a separate sibling behind the script window, so it never covers the UI.
local BlackBackground = Instance.new("Frame")
BlackBackground.Name = "BlackBackground"
BlackBackground.Size = UDim2.new(1,0,1,0)
BlackBackground.Position = UDim2.new(0,0,0,0)
BlackBackground.BackgroundColor3 = Color3.new(0,0,0)
BlackBackground.BackgroundTransparency = 0
BlackBackground.BorderSizePixel = 0
BlackBackground.ZIndex = 0
BlackBackground.Active = false
BlackBackground.Parent = Gui

local Window = Instance.new("Frame")
Window.Name="Window"
Window.Size=UDim2.new(0,W,0,H)
Window.Position=UDim2.new(0.5,-W/2,0.5,-H/2)
Window.BackgroundColor3=THEME.BG
Window.BorderSizePixel=0
Window.ClipsDescendants=true
Window.BackgroundTransparency=1
Window.ZIndex=1
Window.Parent=Gui
corner(Window,18)
local winStroke = stroke(Window, THEME.BORDER, 1.5)

-- ── Header ────────────────────────────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size=UDim2.new(1,0,0,MH) Header.BackgroundColor3=THEME.PANEL Header.BorderSizePixel=0 Header.ZIndex=10 Header.Parent=Window
corner(Header,18)
local hFix=Instance.new("Frame") hFix.Size=UDim2.new(1,0,0,18) hFix.Position=UDim2.new(0,0,1,-18) hFix.BackgroundColor3=THEME.PANEL hFix.BorderSizePixel=0 hFix.ZIndex=10 hFix.Parent=Header

-- animated rainbow strip
local RainbowBar=Instance.new("Frame")
RainbowBar.Size=UDim2.new(1,0,0,3) RainbowBar.BackgroundColor3=Color3.new(1,1,1) RainbowBar.BorderSizePixel=0 RainbowBar.ZIndex=11 RainbowBar.Parent=Header
corner(RainbowBar,2)
local rbGrad=Instance.new("UIGradient")
rbGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0.7,1,1)),ColorSequenceKeypoint.new(0.5,Color3.fromHSV(0.85,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))})
rbGrad.Rotation=0 rbGrad.Parent=RainbowBar

-- icon
local TitleIcon=Instance.new("TextLabel")
TitleIcon.Size=UDim2.new(0,36,0,36) TitleIcon.Position=UDim2.new(0,14,0.5,-18)
TitleIcon.BackgroundTransparency=1 TitleIcon.Text="⚔" TitleIcon.TextColor3=THEME.ACCENT
TitleIcon.TextSize=24 TitleIcon.Font=Enum.Font.GothamBold TitleIcon.ZIndex=11 TitleIcon.Parent=Header

-- titles
local TitleLbl=Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(1,-180,0,20) TitleLbl.Position=UDim2.new(0,56,0,10)
TitleLbl.BackgroundTransparency=1 TitleLbl.Text="Crew Tools" TitleLbl.TextColor3=THEME.TEXT
TitleLbl.TextSize=15 TitleLbl.Font=Enum.Font.GothamBold TitleLbl.TextXAlignment=Enum.TextXAlignment.Left TitleLbl.ZIndex=11 TitleLbl.Parent=Header

local SubLbl=Instance.new("TextLabel")
SubLbl.Size=UDim2.new(1,-180,0,13) SubLbl.Position=UDim2.new(0,56,0,34)
SubLbl.BackgroundTransparency=1 SubLbl.Text="World Clock Crew Sync  •  Merciful"
SubLbl.TextColor3=THEME.SUB SubLbl.TextSize=10 SubLbl.Font=Enum.Font.Gotham
SubLbl.TextXAlignment=Enum.TextXAlignment.Left SubLbl.ZIndex=11 SubLbl.Parent=Header

-- minimize button
local MinBtn=Instance.new("TextButton")
MinBtn.Size=UDim2.new(0,32,0,28) MinBtn.Position=UDim2.new(1,-128,0.5,-14)
MinBtn.BackgroundColor3=Color3.fromRGB(28,32,52) MinBtn.Text="─"
MinBtn.TextColor3=THEME.SUB MinBtn.TextSize=18 MinBtn.Font=Enum.Font.GothamBold MinBtn.ZIndex=11 MinBtn.Parent=Header
corner(MinBtn,7)
MinBtn.MouseEnter:Connect(function() tw(MinBtn,{BackgroundColor3=Color3.fromRGB(45,52,90)}) end)
MinBtn.MouseLeave:Connect(function() tw(MinBtn,{BackgroundColor3=Color3.fromRGB(28,32,52)}) end)

-- close button
local CloseBtn=Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0,80,0,28) CloseBtn.Position=UDim2.new(1,-90,0.5,-14)
CloseBtn.BackgroundColor3=Color3.fromRGB(52,20,32) CloseBtn.Text="✕  Close"
CloseBtn.TextColor3=THEME.ERROR CloseBtn.TextSize=12 CloseBtn.Font=Enum.Font.GothamBold CloseBtn.ZIndex=11 CloseBtn.Parent=Header
corner(CloseBtn,7)
CloseBtn.MouseEnter:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(90,22,38)}) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(52,20,32)}) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Window,{Position=UDim2.new(0.5,-W/2,1.4,0),BackgroundTransparency=1},0.3,Enum.EasingStyle.Quart)
    task.delay(0.35,function() Gui:Destroy() end)
end)

local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    if minimized then
        tw(Window,{Size=UDim2.new(0,W,0,MH)},0.32,Enum.EasingStyle.Quart)
        MinBtn.Text="□"
    else
        tw(Window,{Size=UDim2.new(0,W,0,H)},0.4,Enum.EasingStyle.Back)
        MinBtn.Text="─"
    end
end)

-- ── Tab bar ───────────────────────────────────────────────────────────────────
local TabBar=Instance.new("Frame")
TabBar.Size=UDim2.new(1,-24,0,38) TabBar.Position=UDim2.new(0,12,0,MH+8)
TabBar.BackgroundColor3=THEME.CARD TabBar.BorderSizePixel=0 TabBar.ZIndex=8 TabBar.Parent=Window
corner(TabBar,10) stroke(TabBar,THEME.BORDER)
hlist(TabBar,0)

-- sliding underline indicator — parented to Window so it doesn't disrupt TabBar's UIListLayout
local TabLine=Instance.new("Frame")
TabLine.Size=UDim2.new(0,(W-24)/4-10,0,3)
TabLine.Position=UDim2.new(0,16,0,MH+8+38-3)
TabLine.BackgroundColor3=THEME.ACCENT TabLine.BorderSizePixel=0 TabLine.ZIndex=10 TabLine.Parent=Window
corner(TabLine,2) grad(TabLine,THEME.ACCENT,THEME.ACCENT2,0)

local function makeTab(lbl,order)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1/4,0,1,0) b.LayoutOrder=order
    b.BackgroundColor3=THEME.CARD b.BorderSizePixel=0
    b.Text=lbl b.TextColor3=THEME.DIM b.TextSize=11 b.Font=Enum.Font.GothamBold b.ZIndex=9 b.Parent=TabBar
    corner(b,10) return b
end
local TabInviter =makeTab("⚡ INVITE",  1)
local TabSync    =makeTab("⏱ SYNC",    2)
local TabWebhook =makeTab("🔔 HOOK",   3)
local TabNotes   =makeTab("📋 NOTES",  4)

-- ── Content ───────────────────────────────────────────────────────────────────
local CY = MH+8+38+8
local ContentArea=Instance.new("Frame")
ContentArea.Size=UDim2.new(1,0,0,H-CY) ContentArea.Position=UDim2.new(0,0,0,CY)
ContentArea.BackgroundTransparency=1 ContentArea.ZIndex=6 ContentArea.Parent=Window

local function makePanel()
    local f=Instance.new("Frame") f.Size=UDim2.new(1,0,1,0) f.BackgroundTransparency=1 f.ZIndex=6 f.Parent=ContentArea
    pad(f,14,14,10,10) vlist(f,8)
    return f
end

-- forward declarations — bodies assigned after Sync panel UI variables exist
local refreshStatus
local parseSyncCode

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 1  MASS INVITER
-- ══════════════════════════════════════════════════════════════════════════════
local InviterPanel=makePanel()

-- label row with live count badge
local InputRow=Instance.new("Frame")
InputRow.Size=UDim2.new(1,0,0,16) InputRow.LayoutOrder=1 InputRow.BackgroundTransparency=1 InputRow.ZIndex=7 InputRow.Parent=InviterPanel

local InputLbl=Instance.new("TextLabel")
InputLbl.Size=UDim2.new(1,-56,1,0) InputLbl.BackgroundTransparency=1 InputLbl.Text="USERNAMES  (one per line)"
InputLbl.TextColor3=THEME.SUB InputLbl.TextSize=10 InputLbl.Font=Enum.Font.GothamBold
InputLbl.TextXAlignment=Enum.TextXAlignment.Left InputLbl.ZIndex=7 InputLbl.Parent=InputRow

local CountBadge=Instance.new("TextLabel")
CountBadge.Size=UDim2.new(0,50,0,16) CountBadge.Position=UDim2.new(1,-50,0,0)
CountBadge.BackgroundColor3=THEME.CARD2 CountBadge.Text="0 users"
CountBadge.TextColor3=THEME.ACCENT CountBadge.TextSize=9 CountBadge.Font=Enum.Font.GothamBold CountBadge.ZIndex=7 CountBadge.Parent=InputRow
corner(CountBadge,5)

-- input box
local InputFrame=Instance.new("Frame")
InputFrame.Size=UDim2.new(1,0,0,155) InputFrame.LayoutOrder=2
InputFrame.BackgroundColor3=THEME.CARD InputFrame.ZIndex=7 InputFrame.Parent=InviterPanel
corner(InputFrame,10)
local inputStroke=stroke(InputFrame,THEME.BORDER)

local UsernameInput=Instance.new("TextBox")
UsernameInput.Size=UDim2.new(1,0,1,0) UsernameInput.BackgroundTransparency=1
UsernameInput.Text="" UsernameInput.PlaceholderText="Player1\nPlayer2\nPlayer3\n..."
UsernameInput.PlaceholderColor3=THEME.DIM UsernameInput.TextColor3=THEME.TEXT
UsernameInput.TextSize=13 UsernameInput.Font=Enum.Font.Gotham
UsernameInput.MultiLine=true UsernameInput.ClearTextOnFocus=false
UsernameInput.TextYAlignment=Enum.TextYAlignment.Top UsernameInput.TextXAlignment=Enum.TextXAlignment.Left
UsernameInput.ZIndex=7 UsernameInput.Parent=InputFrame
pad(UsernameInput,12,12,10,10)

UsernameInput:GetPropertyChangedSignal("Text"):Connect(function()
    local n=0 for line in (UsernameInput.Text.."\n"):gmatch("([^\n]*)\n") do if #trim(line)>0 then n=n+1 end end
    CountBadge.Text=n..(n==1 and " user" or " users")
end)
UsernameInput.Focused:Connect(function() tw(InputFrame,{BackgroundColor3=THEME.CARD2}) tw(inputStroke,{Color=THEME.ACCENT,Thickness=1.5}) end)
UsernameInput.FocusLost:Connect(function() tw(InputFrame,{BackgroundColor3=THEME.CARD}) tw(inputStroke,{Color=THEME.BORDER,Thickness=1}) end)

-- invite button (shimmer wrapper)
local InviteWrap=Instance.new("Frame")
InviteWrap.Size=UDim2.new(1,0,0,46) InviteWrap.LayoutOrder=3
InviteWrap.BackgroundColor3=THEME.ACCENT InviteWrap.ClipsDescendants=true InviteWrap.ZIndex=7 InviteWrap.Parent=InviterPanel
corner(InviteWrap,11) grad(InviteWrap,THEME.ACCENT,THEME.ACCENT2,0) stroke(InviteWrap,Color3.fromRGB(130,110,255),1)

local InviteBtn=Instance.new("TextButton")
InviteBtn.Size=UDim2.new(1,0,1,0) InviteBtn.BackgroundTransparency=1
InviteBtn.Text="⚡  INVITE ALL" InviteBtn.TextColor3=Color3.new(1,1,1)
InviteBtn.TextSize=14 InviteBtn.Font=Enum.Font.GothamBold InviteBtn.ZIndex=8 InviteBtn.Parent=InviteWrap

local Shimmer=Instance.new("Frame")
Shimmer.Size=UDim2.new(0.35,0,1,0) Shimmer.Position=UDim2.new(-0.4,0,0,0)
Shimmer.BackgroundColor3=Color3.new(1,1,1) Shimmer.BackgroundTransparency=0.8 Shimmer.BorderSizePixel=0 Shimmer.ZIndex=8 Shimmer.Parent=InviteWrap
local shGrad=Instance.new("UIGradient")
shGrad.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.6),NumberSequenceKeypoint.new(1,1)})
shGrad.Rotation=90 shGrad.Parent=Shimmer

local function runShimmer()
    Shimmer.Position=UDim2.new(-0.4,0,0,0)
    tw(Shimmer,{Position=UDim2.new(1.4,0,0,0)},1.0,Enum.EasingStyle.Linear)
end

InviteBtn.MouseEnter:Connect(function() if not inviting then tw(InviteWrap,{BackgroundColor3=Color3.fromRGB(115,118,255)}) end end)
InviteBtn.MouseLeave:Connect(function() if not inviting then tw(InviteWrap,{BackgroundColor3=THEME.ACCENT}) end end)

-- progress bar
local ProgBg=Instance.new("Frame")
ProgBg.Size=UDim2.new(1,0,0,5) ProgBg.LayoutOrder=4
ProgBg.BackgroundColor3=THEME.CARD ProgBg.ZIndex=7 ProgBg.Parent=InviterPanel
corner(ProgBg,3)
local ProgBar=Instance.new("Frame")
ProgBar.Size=UDim2.new(0,0,1,0) ProgBar.BackgroundColor3=THEME.ACCENT ProgBar.BorderSizePixel=0 ProgBar.ZIndex=8 ProgBar.Parent=ProgBg
corner(ProgBar,3) grad(ProgBar,THEME.ACCENT,THEME.SUCCESS,0)

-- status bar
local IStatBg=Instance.new("Frame")
IStatBg.Size=UDim2.new(1,0,0,24) IStatBg.LayoutOrder=5
IStatBg.BackgroundColor3=THEME.CARD IStatBg.ZIndex=7 IStatBg.Parent=InviterPanel
corner(IStatBg,7)
local IStatLbl=Instance.new("TextLabel")
IStatLbl.Size=UDim2.new(1,-16,1,0) IStatLbl.Position=UDim2.new(0,8,0,0)
IStatLbl.BackgroundTransparency=1 IStatLbl.Text="●  Ready — enter usernames above"
IStatLbl.TextColor3=THEME.DIM IStatLbl.TextSize=11 IStatLbl.Font=Enum.Font.Gotham
IStatLbl.TextXAlignment=Enum.TextXAlignment.Left IStatLbl.ZIndex=7 IStatLbl.Parent=IStatBg

-- log
local LogHdr=Instance.new("TextLabel")
LogHdr.Size=UDim2.new(1,0,0,13) LogHdr.LayoutOrder=6 LogHdr.BackgroundTransparency=1
LogHdr.Text="ACTIVITY LOG" LogHdr.TextColor3=THEME.DIM LogHdr.TextSize=9
LogHdr.Font=Enum.Font.GothamBold LogHdr.TextXAlignment=Enum.TextXAlignment.Left LogHdr.ZIndex=7 LogHdr.Parent=InviterPanel

local LogFrame=Instance.new("ScrollingFrame")
LogFrame.Size=UDim2.new(1,0,0,152) LogFrame.LayoutOrder=7
LogFrame.BackgroundColor3=THEME.CARD LogFrame.BorderSizePixel=0
LogFrame.ScrollBarThickness=3 LogFrame.ScrollBarImageColor3=THEME.ACCENT
LogFrame.CanvasSize=UDim2.new(0,0,0,0) LogFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y
LogFrame.ZIndex=7 LogFrame.Parent=InviterPanel
corner(LogFrame,10) stroke(LogFrame,THEME.BORDER)
vlist(LogFrame,3) pad(LogFrame,10,10,8,8)

local logCount=0
local function addLog(msg,color)
    logCount=logCount+1
    local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,18) row.BackgroundTransparency=1 row.LayoutOrder=logCount row.ZIndex=8 row.Parent=LogFrame
    local dot=Instance.new("Frame") dot.Size=UDim2.new(0,3,0,11) dot.Position=UDim2.new(0,0,0.5,-5.5) dot.BackgroundColor3=color or THEME.SUB dot.BorderSizePixel=0 dot.ZIndex=8 dot.Parent=row corner(dot,2)
    local e=Instance.new("TextLabel") e.Size=UDim2.new(1,-10,1,0) e.Position=UDim2.new(0,8,0,0) e.BackgroundTransparency=1
    e.Text=os.date("%H:%M:%S").."  "..msg e.TextColor3=color or THEME.TEXT e.TextSize=11 e.Font=Enum.Font.Code
    e.TextXAlignment=Enum.TextXAlignment.Left e.TextTruncate=Enum.TextTruncate.AtEnd e.ZIndex=8 e.Parent=row
    task.defer(function() LogFrame.CanvasPosition=Vector2.new(0,math.huge) end)
end
addLog("Crew Tools loaded — owner: Merciful",THEME.ACCENT)

InviteBtn.MouseButton1Click:Connect(function()
    if inviting then return end
    local names={}
    for line in (UsernameInput.Text.."\n"):gmatch("([^\n]*)\n") do local n=trim(line) if #n>0 then table.insert(names,n) end end
    if #names==0 then IStatLbl.Text="●  Enter at least one username!" IStatLbl.TextColor3=THEME.WARN addLog("No usernames entered",THEME.WARN) return end
    inviting=true InviteBtn.Text="⏳  INVITING..." tw(InviteWrap,{BackgroundColor3=Color3.fromRGB(50,50,100)})
    local invited,failed=0,0
    addLog("Starting — "..(#names).." username(s)",THEME.ACCENT)
    for i,name in ipairs(names) do
        IStatLbl.Text="●  "..i.."/"..#names.." → "..name IStatLbl.TextColor3=THEME.TEXT
        tw(ProgBar,{Size=UDim2.new((i-1)/#names,0,1,0)},0.25)
        if invitePlayer(name,addLog) then invited=invited+1 else failed=failed+1 end
        task.wait(INVITE_DELAY)
    end
    tw(ProgBar,{Size=UDim2.new(1,0,1,0)},0.25) task.wait(0.6) tw(ProgBar,{Size=UDim2.new(0,0,1,0)},0.9)
    local s=("Done — ✓ %d invited  ✗ %d failed"):format(invited,failed)
    IStatLbl.Text="●  "..s IStatLbl.TextColor3=invited>0 and THEME.SUCCESS or THEME.ERROR
    addLog(s,invited>0 and THEME.SUCCESS or THEME.ERROR)
    inviting=false InviteBtn.Text="⚡  INVITE ALL" tw(InviteWrap,{BackgroundColor3=THEME.ACCENT})
    refreshStatus()
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 2  SYNC JOIN  (controls top | terminal console always-visible bottom)
-- ══════════════════════════════════════════════════════════════════════════════
local CTRL_H = 450  -- px height for the controls section

local SyncPanel=Instance.new("Frame")
SyncPanel.Size=UDim2.new(1,0,1,0) SyncPanel.BackgroundTransparency=1
SyncPanel.ZIndex=6 SyncPanel.Visible=false SyncPanel.Parent=ContentArea

-- ── Controls area ─────────────────────────────────────────────────────────────
local CtrlPart=Instance.new("Frame")
CtrlPart.Size=UDim2.new(1,0,0,CTRL_H) CtrlPart.BackgroundTransparency=1
CtrlPart.ZIndex=6 CtrlPart.Parent=SyncPanel
pad(CtrlPart,14,14,10,6) vlist(CtrlPart,7)

local StepsCard=Instance.new("Frame")
StepsCard.Size=UDim2.new(1,0,0,34) StepsCard.LayoutOrder=1
StepsCard.BackgroundColor3=THEME.CARD StepsCard.ZIndex=7 StepsCard.Parent=CtrlPart
corner(StepsCard,9) stroke(StepsCard,THEME.BORDER)
local StepsLbl=Instance.new("TextLabel")
StepsLbl.Size=UDim2.new(1,-20,1,0) StepsLbl.Position=UDim2.new(0,10,0,0) StepsLbl.BackgroundTransparency=1
StepsLbl.Text="① Set an IST target time & Crew ID   ──►   ② SET SYNC\nAll instances join the crew at that exact IST moment"
StepsLbl.TextColor3=THEME.SUB StepsLbl.TextSize=10 StepsLbl.Font=Enum.Font.Gotham
StepsLbl.TextWrapped=true StepsLbl.TextXAlignment=Enum.TextXAlignment.Center StepsLbl.ZIndex=7 StepsLbl.Parent=StepsCard

local CrewIdRow=Instance.new("Frame")
CrewIdRow.Size=UDim2.new(1,0,0,40) CrewIdRow.LayoutOrder=2 CrewIdRow.BackgroundTransparency=1 CrewIdRow.ZIndex=7 CrewIdRow.Parent=CtrlPart
local CrewIdLbl=Instance.new("TextLabel")
CrewIdLbl.Size=UDim2.new(0,118,1,0) CrewIdLbl.BackgroundTransparency=1 CrewIdLbl.Text="CREW ID"
CrewIdLbl.TextColor3=THEME.SUB CrewIdLbl.TextSize=10 CrewIdLbl.Font=Enum.Font.GothamBold
CrewIdLbl.TextXAlignment=Enum.TextXAlignment.Left CrewIdLbl.ZIndex=7 CrewIdLbl.Parent=CrewIdRow
local CrewIdBox=Instance.new("Frame")
CrewIdBox.Size=UDim2.new(1,-126,1,0) CrewIdBox.Position=UDim2.new(0,126,0,0)
CrewIdBox.BackgroundColor3=THEME.CARD CrewIdBox.ZIndex=7 CrewIdBox.Parent=CrewIdRow
corner(CrewIdBox,9) local crewIdStroke=stroke(CrewIdBox,THEME.BORDER)
local CrewIdInput=Instance.new("TextBox")
CrewIdInput.Size=UDim2.new(1,-16,0,22) CrewIdInput.Position=UDim2.new(0,8,0,3)
CrewIdInput.BackgroundTransparency=1 CrewIdInput.Text="" CrewIdInput.PlaceholderText="3569141797|53623713"
CrewIdInput.PlaceholderColor3=THEME.DIM CrewIdInput.TextColor3=THEME.TEXT
CrewIdInput.TextSize=12 CrewIdInput.Font=Enum.Font.GothamBold
CrewIdInput.ClearTextOnFocus=false CrewIdInput.ZIndex=8 CrewIdInput.Parent=CrewIdBox
CrewIdInput.Focused:Connect(function() tw(CrewIdBox,{BackgroundColor3=THEME.CARD2}) tw(crewIdStroke,{Color=THEME.ACCENT}) end)
CrewIdInput.FocusLost:Connect(function() tw(CrewIdBox,{BackgroundColor3=THEME.CARD}) tw(crewIdStroke,{Color=THEME.BORDER}) end)

CrewOwnerLbl=Instance.new("TextLabel")
CrewOwnerLbl.Size=UDim2.new(1,-16,0,14) CrewOwnerLbl.Position=UDim2.new(0,8,1,-16)
CrewOwnerLbl.BackgroundTransparency=1 CrewOwnerLbl.Text="Owner: Not detected"
CrewOwnerLbl.TextColor3=THEME.SUCCESS CrewOwnerLbl.TextSize=9 CrewOwnerLbl.Font=Enum.Font.GothamBold
CrewOwnerLbl.TextXAlignment=Enum.TextXAlignment.Left CrewOwnerLbl.ZIndex=9 CrewOwnerLbl.Parent=CrewIdBox

local ScanCrewBtn=Instance.new("TextButton")
ScanCrewBtn.Size=UDim2.new(1,0,0,28) ScanCrewBtn.LayoutOrder=3
ScanCrewBtn.BackgroundColor3=THEME.CARD2 ScanCrewBtn.Text="🔍  Auto-Scan Crew ID"
ScanCrewBtn.TextColor3=THEME.TEXT ScanCrewBtn.TextSize=12 ScanCrewBtn.Font=Enum.Font.GothamBold
ScanCrewBtn.ZIndex=7 ScanCrewBtn.Parent=CtrlPart
corner(ScanCrewBtn,9) stroke(ScanCrewBtn,THEME.ACCENT)
ScanCrewBtn.MouseEnter:Connect(function() tw(ScanCrewBtn,{BackgroundColor3=Color3.fromRGB(40,40,70)}) end)
ScanCrewBtn.MouseLeave:Connect(function() tw(ScanCrewBtn,{BackgroundColor3=THEME.CARD2}) end)

local StatusCard=Instance.new("Frame")
StatusCard.Size=UDim2.new(1,0,0,28) StatusCard.LayoutOrder=4
StatusCard.BackgroundColor3=THEME.CARD StatusCard.ZIndex=7 StatusCard.Parent=CtrlPart
corner(StatusCard,8)
local scPad=Instance.new("UIPadding") scPad.PaddingLeft=UDim.new(0,10) scPad.PaddingRight=UDim.new(0,10) scPad.Parent=StatusCard
local StatusTitleLbl=Instance.new("TextLabel")
StatusTitleLbl.Size=UDim2.new(0,88,1,0) StatusTitleLbl.BackgroundTransparency=1
StatusTitleLbl.Text="INVITE STATUS" StatusTitleLbl.TextColor3=THEME.DIM
StatusTitleLbl.TextSize=9 StatusTitleLbl.Font=Enum.Font.GothamBold
StatusTitleLbl.TextXAlignment=Enum.TextXAlignment.Left StatusTitleLbl.ZIndex=8 StatusTitleLbl.Parent=StatusCard
local DotsFrame=Instance.new("Frame")
DotsFrame.Size=UDim2.new(1,-170,1,0) DotsFrame.Position=UDim2.new(0,92,0,0)
DotsFrame.BackgroundTransparency=1 DotsFrame.ZIndex=8 DotsFrame.Parent=StatusCard
local dotsLL=Instance.new("UIListLayout")
dotsLL.FillDirection=Enum.FillDirection.Horizontal dotsLL.SortOrder=Enum.SortOrder.LayoutOrder
dotsLL.Padding=UDim.new(0,4) dotsLL.VerticalAlignment=Enum.VerticalAlignment.Center dotsLL.Parent=DotsFrame
local StatusCountLbl=Instance.new("TextLabel")
StatusCountLbl.Size=UDim2.new(0,52,1,0) StatusCountLbl.Position=UDim2.new(1,-80,0,0)
StatusCountLbl.BackgroundTransparency=1 StatusCountLbl.Text="0 / 0"
StatusCountLbl.TextColor3=THEME.SUB StatusCountLbl.TextSize=11 StatusCountLbl.Font=Enum.Font.GothamBold
StatusCountLbl.TextXAlignment=Enum.TextXAlignment.Right StatusCountLbl.ZIndex=8 StatusCountLbl.Parent=StatusCard
local RefreshBtn=Instance.new("TextButton")
RefreshBtn.Size=UDim2.new(0,26,0,22) RefreshBtn.Position=UDim2.new(1,-26,0.5,-11)
RefreshBtn.BackgroundColor3=THEME.CARD2 RefreshBtn.Text="↺"
RefreshBtn.TextColor3=THEME.ACCENT RefreshBtn.TextSize=16 RefreshBtn.Font=Enum.Font.GothamBold
RefreshBtn.ZIndex=9 RefreshBtn.Parent=StatusCard corner(RefreshBtn,6)

-- ── World-clock (IST) target-time row ──────────────────────────────────────────
local ISTRow=Instance.new("Frame")
ISTRow.Size=UDim2.new(1,0,0,94) ISTRow.LayoutOrder=5 ISTRow.BackgroundTransparency=1 ISTRow.ZIndex=7 ISTRow.Parent=CtrlPart
local ISTLbl=Instance.new("TextLabel")
ISTLbl.Size=UDim2.new(0,118,0,18) ISTLbl.Position=UDim2.new(0,0,0,44) ISTLbl.BackgroundTransparency=1 ISTLbl.Text="TARGET TIME (IST)"
ISTLbl.TextColor3=THEME.SUB ISTLbl.TextSize=10 ISTLbl.Font=Enum.Font.GothamBold
ISTLbl.TextXAlignment=Enum.TextXAlignment.Left ISTLbl.ZIndex=7 ISTLbl.Parent=ISTRow
NowClockCard=Instance.new("Frame")
NowClockCard.Size=UDim2.new(1,0,0,40) NowClockCard.Position=UDim2.new(0,0,0,0)
NowClockCard.BackgroundColor3=THEME.CARD NowClockCard.ZIndex=7 NowClockCard.Parent=ISTRow
corner(NowClockCard,8) stroke(NowClockCard,THEME.ACCENT,1.2)
NowClockTitle=Instance.new("TextLabel")
NowClockTitle.Size=UDim2.new(0,110,1,0) NowClockTitle.Position=UDim2.new(0,12,0,0)
NowClockTitle.BackgroundTransparency=1 NowClockTitle.Text="CURRENT IST" NowClockTitle.TextColor3=THEME.SUB
NowClockTitle.TextSize=10 NowClockTitle.Font=Enum.Font.GothamBold NowClockTitle.TextXAlignment=Enum.TextXAlignment.Left
NowClockTitle.ZIndex=8 NowClockTitle.Parent=NowClockCard
local NowISTLbl=Instance.new("TextLabel")
NowISTLbl.Size=UDim2.new(1,-126,1,0) NowISTLbl.Position=UDim2.new(0,118,0,0) NowISTLbl.BackgroundTransparency=1
NowISTLbl.Text="--:--:--" NowISTLbl.TextColor3=THEME.SUCCESS NowISTLbl.TextSize=24 NowISTLbl.Font=Enum.Font.GothamBold
NowISTLbl.TextXAlignment=Enum.TextXAlignment.Right NowISTLbl.ZIndex=8 NowISTLbl.Parent=NowClockCard

local ISTBoxFrame=Instance.new("Frame")
ISTBoxFrame.Size=UDim2.new(1,-126,0,40) ISTBoxFrame.Position=UDim2.new(0,126,0,40)
ISTBoxFrame.BackgroundColor3=THEME.CARD ISTBoxFrame.ZIndex=7 ISTBoxFrame.Parent=ISTRow
corner(ISTBoxFrame,9) local istStroke=stroke(ISTBoxFrame,THEME.BORDER)
local istPad=Instance.new("UIPadding") istPad.PaddingLeft=UDim.new(0,10) istPad.Parent=ISTBoxFrame
hlist(ISTBoxFrame,4)

local function makeTimeBox(placeholder)
    local b=Instance.new("TextBox")
    b.Size=UDim2.new(0,46,1,0)
    b.BackgroundTransparency=1
    b.Text=""
    b.PlaceholderText=placeholder
    b.PlaceholderColor3=THEME.DIM
    b.TextColor3=THEME.TEXT
    b.TextSize=17
    b.Font=Enum.Font.GothamBold
    b.TextXAlignment=Enum.TextXAlignment.Center
    b.ClearTextOnFocus=false
    b.ZIndex=8
    b.Parent=ISTBoxFrame
    return b
end
local HourBox=makeTimeBox("HH")
local Colon1=Instance.new("TextLabel")
Colon1.Size=UDim2.new(0,8,1,0) Colon1.BackgroundTransparency=1 Colon1.Text=":" Colon1.TextColor3=THEME.SUB
Colon1.TextSize=17 Colon1.Font=Enum.Font.GothamBold Colon1.ZIndex=8 Colon1.Parent=ISTBoxFrame
local MinBox=makeTimeBox("MM")
local Colon2=Instance.new("TextLabel")
Colon2.Size=UDim2.new(0,8,1,0) Colon2.BackgroundTransparency=1 Colon2.Text=":" Colon2.TextColor3=THEME.SUB
Colon2.TextSize=17 Colon2.Font=Enum.Font.GothamBold Colon2.ZIndex=8 Colon2.Parent=ISTBoxFrame
local SecBox=makeTimeBox("SS")

local function focusTimeBox(box) box.Focused:Connect(function() tw(ISTBoxFrame,{BackgroundColor3=THEME.CARD2}) tw(istStroke,{Color=THEME.ACCENT}) end) end
local function blurTimeBox(box)  box.FocusLost:Connect(function() tw(ISTBoxFrame,{BackgroundColor3=THEME.CARD})  tw(istStroke,{Color=THEME.BORDER}) end) end
for _, b in ipairs({HourBox, MinBox, SecBox}) do focusTimeBox(b) blurTimeBox(b) end

local IST_OFFSET = 5*3600 + 30*60   -- India Standard Time is UTC+5:30, no DST

-- computes the next Unix timestamp at which the IST clock reads HH:MM:SS
-- (today if that moment is still ahead of "now", otherwise tomorrow)
local function getISTTargetTimestamp()
    local h = math.clamp(math.floor(tonumber(HourBox.Text) or 0), 0, 23)
    local m = math.clamp(math.floor(tonumber(MinBox.Text)  or 0), 0, 59)
    local s = math.clamp(math.floor(tonumber(SecBox.Text)  or 0), 0, 59)

    local nowIST       = os.time() + IST_OFFSET
    local todayStartIST= nowIST - (nowIST % 86400)
    local targetIST    = todayStartIST + h*3600 + m*60 + s
    local diff         = targetIST - nowIST
    if diff <= 0 then diff = diff + 86400 end  -- already passed today → tomorrow
    return os.time() + diff
end

-- live "current IST time" readout — cheap 1x/sec loop, not per-frame
task.spawn(function()
    while true do
        local ist=os.time()+IST_OFFSET
        local h24=math.floor(ist/3600)%24
        local m=math.floor(ist/60)%60
        local sec=ist%60
        local ap=h24>=12 and "PM" or "AM"
        local h=h24%12 if h==0 then h=12 end
        NowISTLbl.Text=string.format("%02d:%02d:%02d %s",h,m,sec,ap)
        task.wait(1)
    end
end)

local SyncBtnRow=Instance.new("Frame")
SyncBtnRow.Size=UDim2.new(1,0,0,44) SyncBtnRow.LayoutOrder=6 SyncBtnRow.BackgroundTransparency=1 SyncBtnRow.ZIndex=7 SyncBtnRow.Parent=CtrlPart
hlist(SyncBtnRow,8)
local SetSyncBtn=Instance.new("TextButton")
SetSyncBtn.Size=UDim2.new(1/3,-6,1,0) SetSyncBtn.LayoutOrder=1
SetSyncBtn.BackgroundColor3=THEME.ACCENT SetSyncBtn.Text="▶  SET SYNC"
SetSyncBtn.TextColor3=Color3.new(1,1,1) SetSyncBtn.TextSize=11 SetSyncBtn.Font=Enum.Font.GothamBold
SetSyncBtn.ZIndex=7 SetSyncBtn.Parent=SyncBtnRow
corner(SetSyncBtn,10) grad(SetSyncBtn,THEME.ACCENT,THEME.ACCENT2,0)
local LoadSyncBtn=Instance.new("TextButton")
LoadSyncBtn.Size=UDim2.new(1/3,-6,1,0) LoadSyncBtn.LayoutOrder=2
LoadSyncBtn.BackgroundColor3=THEME.CARD2 LoadSyncBtn.Text="⬇  LOAD"
LoadSyncBtn.TextColor3=THEME.TEXT LoadSyncBtn.TextSize=11 LoadSyncBtn.Font=Enum.Font.GothamBold
LoadSyncBtn.ZIndex=7 LoadSyncBtn.Parent=SyncBtnRow
corner(LoadSyncBtn,10) stroke(LoadSyncBtn,THEME.BORDER)
local AutoListenBtn=Instance.new("TextButton")
AutoListenBtn.Size=UDim2.new(1/3,-6,1,0) AutoListenBtn.LayoutOrder=3
AutoListenBtn.BackgroundColor3=THEME.CARD2 AutoListenBtn.Text="👂  AUTO"
AutoListenBtn.TextColor3=THEME.TEXT AutoListenBtn.TextSize=11 AutoListenBtn.Font=Enum.Font.GothamBold
AutoListenBtn.ZIndex=7 AutoListenBtn.Parent=SyncBtnRow
corner(AutoListenBtn,10) stroke(AutoListenBtn,THEME.BORDER)

local SyncCodeFrame=Instance.new("Frame")
SyncCodeFrame.Size=UDim2.new(1,0,0,34) SyncCodeFrame.LayoutOrder=7
SyncCodeFrame.BackgroundColor3=THEME.CARD SyncCodeFrame.ZIndex=7 SyncCodeFrame.Parent=CtrlPart
corner(SyncCodeFrame,9) stroke(SyncCodeFrame,THEME.BORDER)
local scfPad=Instance.new("UIPadding") scfPad.PaddingLeft=UDim.new(0,8) scfPad.PaddingRight=UDim.new(0,8) scfPad.PaddingTop=UDim.new(0,5) scfPad.PaddingBottom=UDim.new(0,5) scfPad.Parent=SyncCodeFrame
local SyncCodeLbl=Instance.new("TextLabel")
SyncCodeLbl.Size=UDim2.new(0,48,0,14) SyncCodeLbl.BackgroundTransparency=1
SyncCodeLbl.Text="SYNC CODE" SyncCodeLbl.TextColor3=THEME.DIM
SyncCodeLbl.TextSize=8 SyncCodeLbl.Font=Enum.Font.GothamBold
SyncCodeLbl.TextXAlignment=Enum.TextXAlignment.Left SyncCodeLbl.ZIndex=8 SyncCodeLbl.Parent=SyncCodeFrame
local SyncCodeBox=Instance.new("TextBox")
SyncCodeBox.Size=UDim2.new(1,-108,0,20) SyncCodeBox.Position=UDim2.new(0,0,1,-22)
SyncCodeBox.BackgroundColor3=THEME.CARD2 SyncCodeBox.Text=""
SyncCodeBox.PlaceholderText="Paste code from other instance here..."
SyncCodeBox.PlaceholderColor3=THEME.DIM SyncCodeBox.TextColor3=THEME.TEXT
SyncCodeBox.TextSize=10 SyncCodeBox.Font=Enum.Font.Code SyncCodeBox.ClearTextOnFocus=false
SyncCodeBox.TextXAlignment=Enum.TextXAlignment.Left SyncCodeBox.ZIndex=8 SyncCodeBox.Parent=SyncCodeFrame
corner(SyncCodeBox,5)
local scbPad=Instance.new("UIPadding") scbPad.PaddingLeft=UDim.new(0,6) scbPad.Parent=SyncCodeBox
local CopyCodeBtn=Instance.new("TextButton")
CopyCodeBtn.Size=UDim2.new(0,46,0,20) CopyCodeBtn.Position=UDim2.new(1,-100,1,-22)
CopyCodeBtn.BackgroundColor3=THEME.ACCENT CopyCodeBtn.Text="Copy"
CopyCodeBtn.TextColor3=Color3.new(1,1,1) CopyCodeBtn.TextSize=10 CopyCodeBtn.Font=Enum.Font.GothamBold
CopyCodeBtn.ZIndex=9 CopyCodeBtn.Parent=SyncCodeFrame corner(CopyCodeBtn,5)
local ApplyCodeBtn=Instance.new("TextButton")
ApplyCodeBtn.Size=UDim2.new(0,46,0,20) ApplyCodeBtn.Position=UDim2.new(1,-50,1,-22)
ApplyCodeBtn.BackgroundColor3=THEME.SUCCESS ApplyCodeBtn.Text="Apply"
ApplyCodeBtn.TextColor3=Color3.new(1,1,1) ApplyCodeBtn.TextSize=10 ApplyCodeBtn.Font=Enum.Font.GothamBold
ApplyCodeBtn.ZIndex=9 ApplyCodeBtn.Parent=SyncCodeFrame corner(ApplyCodeBtn,5)

local CDCard=Instance.new("Frame")
CDCard.Size=UDim2.new(1,0,0,90) CDCard.LayoutOrder=10
CDCard.BackgroundColor3=THEME.CARD CDCard.ZIndex=7 CDCard.Parent=CtrlPart
corner(CDCard,12) local cdStroke=stroke(CDCard,THEME.BORDER,1.5)
local CDGlow=Instance.new("TextLabel")
CDGlow.Size=UDim2.new(1,0,0,56) CDGlow.Position=UDim2.new(0,2,0,6)
CDGlow.BackgroundTransparency=1 CDGlow.Text="--:--" CDGlow.TextColor3=THEME.ACCENT
CDGlow.TextTransparency=0.72 CDGlow.TextSize=36 CDGlow.Font=Enum.Font.GothamBold
CDGlow.TextXAlignment=Enum.TextXAlignment.Center CDGlow.ZIndex=7 CDGlow.Parent=CDCard
local CDNum=Instance.new("TextLabel")
CDNum.Size=UDim2.new(1,0,0,56) CDNum.Position=UDim2.new(0,0,0,4)
CDNum.BackgroundTransparency=1 CDNum.Text="--:--" CDNum.TextColor3=THEME.TEXT
CDNum.TextSize=36 CDNum.Font=Enum.Font.GothamBold
CDNum.TextXAlignment=Enum.TextXAlignment.Center CDNum.ZIndex=8 CDNum.Parent=CDCard
local CDSub=Instance.new("TextLabel")
CDSub.Size=UDim2.new(1,0,0,18) CDSub.Position=UDim2.new(0,0,0,68)
CDSub.BackgroundTransparency=1 CDSub.Text="Waiting for sync..." CDSub.TextColor3=THEME.DIM
CDSub.TextSize=11 CDSub.Font=Enum.Font.Gotham CDSub.TextXAlignment=Enum.TextXAlignment.Center CDSub.ZIndex=8 CDSub.Parent=CDCard

-- ── Terminal console (fixed rectangle, always visible, fills rest of panel) ───
local ConsoleFrame=Instance.new("Frame")
ConsoleFrame.Size=UDim2.new(1,0,1,-CTRL_H)
ConsoleFrame.Position=UDim2.new(0,0,0,CTRL_H)
ConsoleFrame.BackgroundColor3=Color3.fromRGB(6,8,14)
ConsoleFrame.BorderSizePixel=0 ConsoleFrame.ZIndex=6 ConsoleFrame.Parent=SyncPanel
local cfC=Instance.new("UICorner") cfC.CornerRadius=UDim.new(0,14) cfC.Parent=ConsoleFrame

-- macOS-style title bar
local ConsoleHdr=Instance.new("Frame")
ConsoleHdr.Size=UDim2.new(1,0,0,30) ConsoleHdr.BackgroundColor3=Color3.fromRGB(18,20,32)
ConsoleHdr.BorderSizePixel=0 ConsoleHdr.ZIndex=7 ConsoleHdr.Parent=ConsoleFrame
local chC=Instance.new("UICorner") chC.CornerRadius=UDim.new(0,14) chC.Parent=ConsoleHdr
local chFix=Instance.new("Frame") chFix.Size=UDim2.new(1,0,0,14) chFix.Position=UDim2.new(0,0,1,-14)
chFix.BackgroundColor3=Color3.fromRGB(18,20,32) chFix.BorderSizePixel=0 chFix.ZIndex=7 chFix.Parent=ConsoleHdr

-- traffic light dots
for i,c in ipairs({Color3.fromRGB(255,95,86),Color3.fromRGB(255,189,46),Color3.fromRGB(39,201,63)}) do
    local d=Instance.new("Frame") d.Size=UDim2.new(0,9,0,9) d.Position=UDim2.new(0,6+(i-1)*14,0.5,-4.5)
    d.BackgroundColor3=c d.BorderSizePixel=0 d.ZIndex=8 d.Parent=ConsoleHdr corner(d,5)
end

local ConsoleTitleLbl=Instance.new("TextLabel")
ConsoleTitleLbl.Size=UDim2.new(1,-100,1,0) ConsoleTitleLbl.Position=UDim2.new(0,52,0,0)
ConsoleTitleLbl.BackgroundTransparency=1 ConsoleTitleLbl.Text="sync_console — Merciful"
ConsoleTitleLbl.TextColor3=Color3.fromRGB(100,110,140) ConsoleTitleLbl.TextSize=10 ConsoleTitleLbl.Font=Enum.Font.Code
ConsoleTitleLbl.TextXAlignment=Enum.TextXAlignment.Left ConsoleTitleLbl.ZIndex=8 ConsoleTitleLbl.Parent=ConsoleHdr

local ClearConsoleBtn=Instance.new("TextButton")
ClearConsoleBtn.Size=UDim2.new(0,46,0,20) ClearConsoleBtn.Position=UDim2.new(1,-50,0.5,-10)
ClearConsoleBtn.BackgroundColor3=Color3.fromRGB(26,28,44) ClearConsoleBtn.Text="CLEAR"
ClearConsoleBtn.TextColor3=Color3.fromRGB(80,90,120) ClearConsoleBtn.TextSize=8 ClearConsoleBtn.Font=Enum.Font.GothamBold
ClearConsoleBtn.ZIndex=8 ClearConsoleBtn.Parent=ConsoleHdr corner(ClearConsoleBtn,5)
ClearConsoleBtn.MouseEnter:Connect(function() tw(ClearConsoleBtn,{TextColor3=THEME.ERROR}) end)
ClearConsoleBtn.MouseLeave:Connect(function() tw(ClearConsoleBtn,{TextColor3=Color3.fromRGB(80,90,120)}) end)

-- the actual scrolling log
local SyncLog=Instance.new("ScrollingFrame")
SyncLog.Size=UDim2.new(1,-2,1,-30) SyncLog.Position=UDim2.new(0,1,0,30)
SyncLog.BackgroundTransparency=1 SyncLog.BorderSizePixel=0
SyncLog.ScrollBarThickness=3 SyncLog.ScrollBarImageColor3=Color3.fromRGB(50,60,100)
SyncLog.CanvasSize=UDim2.new(0,0,0,0) SyncLog.AutomaticCanvasSize=Enum.AutomaticSize.Y
SyncLog.ZIndex=7 SyncLog.Parent=ConsoleFrame
vlist(SyncLog,0) pad(SyncLog,8,8,6,6)

local slogCount=0
local function addSyncLog(msg,color)
    slogCount=slogCount+1
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,18) row.LayoutOrder=slogCount row.ZIndex=8 row.Parent=SyncLog
    row.BackgroundColor3=slogCount%2==0 and Color3.fromRGB(10,12,22) or Color3.fromRGB(6,8,14)
    row.BackgroundTransparency=0 row.BorderSizePixel=0
    local bar=Instance.new("Frame") bar.Size=UDim2.new(0,2,1,0) bar.BackgroundColor3=color or THEME.SUB
    bar.BorderSizePixel=0 bar.ZIndex=9 bar.Parent=row
    local e=Instance.new("TextLabel") e.Size=UDim2.new(1,-10,1,0) e.Position=UDim2.new(0,8,0,0)
    e.BackgroundTransparency=1 e.Text=os.date("%H:%M:%S").."  "..msg
    e.TextColor3=color or Color3.fromRGB(175,185,210) e.TextSize=11 e.Font=Enum.Font.Code
    e.TextXAlignment=Enum.TextXAlignment.Left e.TextTruncate=Enum.TextTruncate.AtEnd e.ZIndex=9 e.Parent=row
    task.defer(function() SyncLog.CanvasPosition=Vector2.new(0,math.huge) end)
end

ClearConsoleBtn.MouseButton1Click:Connect(function()
    for _,c in ipairs(SyncLog:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    slogCount=0 addSyncLog("Console cleared", THEME.DIM)
end)

addSyncLog(hasFS and "File sync ready" or "No file API — timer-only mode", hasFS and THEME.SUCCESS or THEME.WARN)

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 3  WEBHOOK
-- ══════════════════════════════════════════════════════════════════════════════
local WebhookPanel=makePanel()
WebhookPanel.Visible=false

local WHLbl=Instance.new("TextLabel")
WHLbl.Size=UDim2.new(1,0,0,16) WHLbl.LayoutOrder=1 WHLbl.BackgroundTransparency=1
WHLbl.Text="DISCORD WEBHOOK URL" WHLbl.TextColor3=THEME.SUB WHLbl.TextSize=10 WHLbl.Font=Enum.Font.GothamBold
WHLbl.TextXAlignment=Enum.TextXAlignment.Left WHLbl.ZIndex=7 WHLbl.Parent=WebhookPanel

local WHBoxFrame=Instance.new("Frame")
WHBoxFrame.Size=UDim2.new(1,0,0,40) WHBoxFrame.LayoutOrder=2
WHBoxFrame.BackgroundColor3=THEME.CARD WHBoxFrame.ZIndex=7 WHBoxFrame.Parent=WebhookPanel
corner(WHBoxFrame,9) local whStroke=stroke(WHBoxFrame,THEME.BORDER)
local WebhookUrlInput=Instance.new("TextBox")
WebhookUrlInput.Size=UDim2.new(1,-16,1,0) WebhookUrlInput.Position=UDim2.new(0,8,0,0)
WebhookUrlInput.BackgroundTransparency=1 WebhookUrlInput.Text=""
WebhookUrlInput.PlaceholderText="https://discord.com/api/webhooks/..."
WebhookUrlInput.PlaceholderColor3=THEME.DIM WebhookUrlInput.TextColor3=THEME.TEXT
WebhookUrlInput.TextSize=12 WebhookUrlInput.Font=Enum.Font.Code
WebhookUrlInput.ClearTextOnFocus=false WebhookUrlInput.ZIndex=8 WebhookUrlInput.Parent=WHBoxFrame
WebhookUrlInput.Focused:Connect(function() tw(WHBoxFrame,{BackgroundColor3=THEME.CARD2}) tw(whStroke,{Color=THEME.ACCENT}) end)
WebhookUrlInput.FocusLost:Connect(function() tw(WHBoxFrame,{BackgroundColor3=THEME.CARD}) tw(whStroke,{Color=THEME.BORDER}) end)

local SendWebhookWrap=Instance.new("Frame")
SendWebhookWrap.Size=UDim2.new(1,0,0,46) SendWebhookWrap.LayoutOrder=3
SendWebhookWrap.BackgroundColor3=THEME.ACCENT SendWebhookWrap.ClipsDescendants=true SendWebhookWrap.ZIndex=7 SendWebhookWrap.Parent=WebhookPanel
corner(SendWebhookWrap,11) grad(SendWebhookWrap,THEME.ACCENT,THEME.ACCENT2,0) stroke(SendWebhookWrap,Color3.fromRGB(130,110,255),1)
local SendWebhookBtn=Instance.new("TextButton")
SendWebhookBtn.Size=UDim2.new(1,0,1,0) SendWebhookBtn.BackgroundTransparency=1
SendWebhookBtn.Text="🔔  SEND WEBHOOK" SendWebhookBtn.TextColor3=Color3.new(1,1,1)
SendWebhookBtn.TextSize=14 SendWebhookBtn.Font=Enum.Font.GothamBold SendWebhookBtn.ZIndex=8 SendWebhookBtn.Parent=SendWebhookWrap
SendWebhookBtn.MouseEnter:Connect(function() tw(SendWebhookWrap,{BackgroundColor3=Color3.fromRGB(115,118,255)}) end)
SendWebhookBtn.MouseLeave:Connect(function() tw(SendWebhookWrap,{BackgroundColor3=THEME.ACCENT}) end)

local WHStatBg=Instance.new("Frame")
WHStatBg.Size=UDim2.new(1,0,0,24) WHStatBg.LayoutOrder=4
WHStatBg.BackgroundColor3=THEME.CARD WHStatBg.ZIndex=7 WHStatBg.Parent=WebhookPanel
corner(WHStatBg,7)
local WHStatLbl=Instance.new("TextLabel")
WHStatLbl.Size=UDim2.new(1,-16,1,0) WHStatLbl.Position=UDim2.new(0,8,0,0)
WHStatLbl.BackgroundTransparency=1 WHStatLbl.Text="●  Ready — enter your webhook URL above"
WHStatLbl.TextColor3=THEME.DIM WHStatLbl.TextSize=11 WHStatLbl.Font=Enum.Font.Gotham
WHStatLbl.TextXAlignment=Enum.TextXAlignment.Left WHStatLbl.ZIndex=7 WHStatLbl.Parent=WHStatBg

local WHLogHdr=Instance.new("TextLabel")
WHLogHdr.Size=UDim2.new(1,0,0,13) WHLogHdr.LayoutOrder=5 WHLogHdr.BackgroundTransparency=1
WHLogHdr.Text="WEBHOOK LOG" WHLogHdr.TextColor3=THEME.DIM WHLogHdr.TextSize=9
WHLogHdr.Font=Enum.Font.GothamBold WHLogHdr.TextXAlignment=Enum.TextXAlignment.Left WHLogHdr.ZIndex=7 WHLogHdr.Parent=WebhookPanel

local WHLogFrame=Instance.new("ScrollingFrame")
WHLogFrame.Size=UDim2.new(1,0,0,420) WHLogFrame.LayoutOrder=6
WHLogFrame.BackgroundColor3=THEME.CARD WHLogFrame.BorderSizePixel=0
WHLogFrame.ScrollBarThickness=3 WHLogFrame.ScrollBarImageColor3=THEME.ACCENT
WHLogFrame.CanvasSize=UDim2.new(0,0,0,0) WHLogFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y
WHLogFrame.ZIndex=7 WHLogFrame.Parent=WebhookPanel
corner(WHLogFrame,10) stroke(WHLogFrame,THEME.BORDER)
vlist(WHLogFrame,3) pad(WHLogFrame,10,10,8,8)

local whLogCount=0
local function addWHLog(msg,color)
    whLogCount=whLogCount+1
    local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,18) row.BackgroundTransparency=1 row.LayoutOrder=whLogCount row.ZIndex=8 row.Parent=WHLogFrame
    local dot=Instance.new("Frame") dot.Size=UDim2.new(0,3,0,11) dot.Position=UDim2.new(0,0,0.5,-5.5) dot.BackgroundColor3=color or THEME.SUB dot.BorderSizePixel=0 dot.ZIndex=8 dot.Parent=row corner(dot,2)
    local e=Instance.new("TextLabel") e.Size=UDim2.new(1,-10,1,0) e.Position=UDim2.new(0,8,0,0) e.BackgroundTransparency=1
    e.Text=os.date("%H:%M:%S").."  "..msg e.TextColor3=color or THEME.TEXT e.TextSize=11 e.Font=Enum.Font.Code
    e.TextXAlignment=Enum.TextXAlignment.Left e.TextTruncate=Enum.TextTruncate.AtEnd e.ZIndex=8 e.Parent=row
    task.defer(function() WHLogFrame.CanvasPosition=Vector2.new(0,math.huge) end)
end
addWHLog("Webhook tab ready — paste your Discord webhook URL above", THEME.ACCENT)

SendWebhookBtn.MouseButton1Click:Connect(function()
    SendWebhookBtn.Text = "⏳  SENDING..."
    WHStatLbl.Text = "●  Sending..." WHStatLbl.TextColor3 = THEME.TEXT
    local ok = sendCrewWebhook(WebhookUrlInput.Text, addWHLog)
    WHStatLbl.Text = ok and "●  Sent successfully!" or "●  Failed — see log below"
    WHStatLbl.TextColor3 = ok and THEME.SUCCESS or THEME.ERROR
    SendWebhookBtn.Text = "🔔  SEND WEBHOOK"
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 4  PATCH NOTES
-- ══════════════════════════════════════════════════════════════════════════════
local NotesPanel=Instance.new("Frame")
NotesPanel.Size=UDim2.new(1,0,1,0) NotesPanel.BackgroundTransparency=1
NotesPanel.ZIndex=6 NotesPanel.Visible=false NotesPanel.Parent=ContentArea

local NotesPad=Instance.new("UIPadding")
NotesPad.PaddingLeft=UDim.new(0,14) NotesPad.PaddingRight=UDim.new(0,14)
NotesPad.PaddingTop=UDim.new(0,10) NotesPad.PaddingBottom=UDim.new(0,10)
NotesPad.Parent=NotesPanel

local NotesScroll=Instance.new("ScrollingFrame")
NotesScroll.Size=UDim2.new(1,0,1,0) NotesScroll.BackgroundTransparency=1
NotesScroll.BorderSizePixel=0 NotesScroll.ScrollBarThickness=3
NotesScroll.ScrollBarImageColor3=THEME.ACCENT
NotesScroll.CanvasSize=UDim2.new(0,0,0,0) NotesScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
NotesScroll.ZIndex=7 NotesScroll.Parent=NotesPanel
local nsLL=Instance.new("UIListLayout") nsLL.SortOrder=Enum.SortOrder.LayoutOrder nsLL.Padding=UDim.new(0,10) nsLL.Parent=NotesScroll

local VERSIONS = {
    {ver="v2.3", title="World-Clock Sync + Webhook Tab", color=THEME.SUCCESS, latest=true, notes={
        "SYNC tab: replaced the relative seconds-delay timer with an absolute IST (India) target time",
        "Enter HH:MM:SS — the script computes the exact next Unix timestamp that moment occurs",
        "Live 'Now: HH:MM:SS' IST clock shown under the target-time inputs for reference",
        "SET SYNC / LOAD / AUTO watcher all continue to work exactly as before — same sync-code format",
        "New WEBHOOK tab: paste any Discord webhook URL and send a live crew snapshot",
        "Webhook groups members into Header / Perfect 30M / Others, matching the reference embed layout",
        "Webhook tab has its own status line + scrollable log, no hardcoded URL",
    }},
    {ver="v2.2", title="Performance Pass", color=THEME.ACCENT2, latest=false, notes={
        "SYNC tab is now the default tab on load",
        "Auto-Listen (watcher) now starts automatically on load",
        "Rainbow header/tab animation throttled to ~15 updates/sec (was 60/sec) — cuts GC churn",
        "Added Performance Mode: fps cap, 3D rendering off, terrain/lighting cleared",
        "Periodic garbage collection + log clearing every 30s",
        "Anti-idle now jumps every 30–50s (randomized) instead of a long fixed timer",
    }},
    {ver="v2.1", title="Terminal Console UI", color=THEME.ACCENT2, latest=false, notes={
        "Sync tab redesigned as a fixed split-layout rectangle",
        "Top half: all controls (crew ID, delay, buttons, countdown)",
        "Bottom half: permanent terminal-style console — never needs extending",
        "Console has macOS-style traffic-light dots + monospace font",
        "Alternating row colours for easy reading of long log output",
        "Coloured left bar per entry instead of dot (cleaner terminal look)",
        "CLEAR button wipes the console without reloading the script",
        "Default window height increased from 618 to 840px",
    }},
    {ver="v2.0", title="Server-Aware Joining", color=THEME.ACCENT2, latest=false, notes={
        "resIsSuccess() checks actual server response — not just 'no error'",
        "Logs every real server response so you see exactly what Blox Fruits says",
        "Random 0–1.2s stagger before each join — simultaneous hits get rejected",
        "Stagger is logged so you know exactly when this instance will fire",
        "0.3s gap between join format attempts — avoids anti-spam rejection",
        "Automatic retry after 1.5s if first attempts all fail",
        "Invite responses also logged per-player for debugging",
    }},
    {ver="v1.9", title="Auto-Listen — Zero-Click Sync", color=THEME.ACCENT2, latest=false, notes={
        "New 👂 AUTO button: polls sync file every 0.8s automatically",
        "Secondary instances join crew with ZERO button presses needed",
        "Just press SET SYNC on main — all AUTO-LISTEN instances fire together",
        "Auto-listener detects new file content only — ignores already-seen codes",
        "⏹ STOP button cancels the listener cleanly without crashing",
        "Fixed: removed 'continue' keyword — not valid in standard Lua executors",
        "Button row now has 3 equal buttons: SET SYNC / LOAD / AUTO",
    }},
    {ver="v1.8", title="Sync Code — Cross-Instance Fix", color=THEME.ACCENT2, latest=false, notes={
        "Root cause fixed: executors write files to different paths per-process",
        "New SYNC CODE box visible on Sync tab — no file system needed",
        "SET SYNC auto-copies code to clipboard (setclipboard) and shows it in box",
        "LOAD SYNC reads file OR falls back to whatever is pasted in the code box",
        "New APPLY button — paste code directly into box to sync without files",
        "Separator changed from '|' to '@@' — unambiguous even when crewID has '|'",
        "CDSub position fixed — no longer clipped by countdown card edge",
        "Countdown font size reduced to 40px so subtitle fits at 106px card height",
    }},
    {ver="v1.7", title="Resize + Invite Status", color=THEME.ACCENT2, latest=false, notes={
        "Drag the bottom edge of the window to resize it taller/shorter",
        "Resize range: 380px min to 900px max — sync log fully visible",
        "INVITE STATUS strip in Sync tab: coloured dot per player in server",
        "Green dot = successfully invited, Red = not yet, Yellow = self",
        "Auto-refreshes on tab open and after mass invite completes",
        "↺ refresh button to manually update dots at any time",
    }},
    {ver="v1.6", title="Correct Blox Fruits Remotes", color=THEME.ACCENT, latest=false, notes={
        "Switched to confirmed remote: ReplicatedStorage.Remotes.Crew (RemoteFunction)",
        "joinCrew uses WaitForChild — more reliable than FindFirstChild",
        "Crew ID fully sanitized (strips hidden whitespace/junk chars)",
        "Tries 4 join argument formats matching Cobalt-generated code",
        "0.5s delay before joinCrew fires — ensures invite is registered",
        "invitePlayer tries 4 argument formats against Remotes.Crew",
        "Auto-Scan button calls GetData/GetCrewData to find Crew ID",
        "Fallback scans StringValues on all players for crew ID pattern",
    }},
    {ver="v1.5", title="Crew ID + Sync Join Fix", color=THEME.ACCENT2, latest=false, notes={
        "Added Crew ID input to Sync Join (format: ownerID|crewID)",
        "SET SYNC now saves Crew ID alongside timestamp in sync file",
        "LOAD SYNC reads both — auto-fills Crew ID on all instances",
        "3 tabs now: INVITE / SYNC / NOTES — equal width thirds",
        "Tab underline indicator correctly parented to Window (not TabBar)",
        "Patch Notes tab with version history and coloured bullet points",
    }},
    {ver="v1.4", title="Stability & Thread Fixes", color=THEME.WARN, latest=false, notes={
        "Fixed 'cannot cancel thread' crash permanently",
        "Split resetUI (safe anywhere) from resetSync (external cancel only)",
        "Thread nils itself before calling resetUI — no self-cancel",
        "Remote scan logs each remote on its own line — no truncation",
        "Tried 7 remote + arg combinations for crew accept",
    }},
    {ver="v1.3", title="Layout Bugfixes",    color=THEME.ERROR, latest=false, notes={
        "Fixed SYNC JOIN tab completely invisible after launch",
        "TabLine moved out of TabBar's UIListLayout to Window",
        "Active tab highlights with background colour change",
        "Sliding indicator position recalculated for 3-tab layout",
    }},
    {ver="v1.2", title="Sync Join",          color=THEME.ACCENT,  latest=false, notes={
        "New SYNC JOIN tab — coordinate multi-account crew joins",
        "SET SYNC writes timestamp to shared file on disk",
        "LOAD SYNC reads it — all instances fire at the exact same second",
        "Countdown with animated glow + urgency colours (green→yellow→red)",
        "+/− stepper for delay (3s–300s range)",
        "Dedicated scrollable sync log with coloured dot entries",
    }},
    {ver="v1.1", title="Visual Overhaul",    color=THEME.ACCENT2, latest=false, notes={
        "Animated rainbow gradient strip across the header",
        "Window border and sword icon follow the same hue cycle",
        "Minimize button (─) collapses window to header only",
        "Shimmer sweep on Invite All button every 3 seconds",
        "Progress bar fills per-invite and drains on completion",
        "Live username count badge, entrance slide + fade animation",
    }},
    {ver="v1.0", title="Initial Release",    color=THEME.SUB,     latest=false, notes={
        "Mass invite tab with multi-line username input",
        "One-click invite all listed players to crew",
        "Activity log with timestamps and colour-coded entries",
        "Draggable window, close button with slide-out animation",
        "Owner/creator: Merciful",
    }},
}

for idx,v in ipairs(VERSIONS) do
    local card=Instance.new("Frame")
    card.Size=UDim2.new(1,0,0,0) card.AutomaticSize=Enum.AutomaticSize.Y
    card.BackgroundColor3=THEME.CARD card.BorderSizePixel=0
    card.LayoutOrder=idx card.ZIndex=7 card.Parent=NotesScroll
    corner(card,10) stroke(card,v.latest and v.color or THEME.BORDER, v.latest and 1.5 or 1)
    local cp=Instance.new("UIPadding")
    cp.PaddingLeft=UDim.new(0,12) cp.PaddingRight=UDim.new(0,12)
    cp.PaddingTop=UDim.new(0,10) cp.PaddingBottom=UDim.new(0,10) cp.Parent=card
    local cl=Instance.new("UIListLayout") cl.SortOrder=Enum.SortOrder.LayoutOrder cl.Padding=UDim.new(0,5) cl.Parent=card

    -- header row
    local hrow=Instance.new("Frame")
    hrow.Size=UDim2.new(1,0,0,22) hrow.BackgroundTransparency=1 hrow.LayoutOrder=1 hrow.ZIndex=8 hrow.Parent=card

    local badge=Instance.new("TextLabel")
    badge.Size=UDim2.new(0,v.latest and 50 or 38,1,0) badge.BackgroundColor3=v.color
    badge.Text=v.ver badge.TextColor3=Color3.new(1,1,1) badge.TextSize=10 badge.Font=Enum.Font.GothamBold
    badge.ZIndex=9 badge.Parent=hrow corner(badge,5)

    if v.latest then
        local newBadge=Instance.new("TextLabel")
        newBadge.Size=UDim2.new(0,38,1,0) newBadge.Position=UDim2.new(0,56,0,0)
        newBadge.BackgroundColor3=THEME.SUCCESS newBadge.Text="LATEST"
        newBadge.TextColor3=Color3.new(1,1,1) newBadge.TextSize=9 newBadge.Font=Enum.Font.GothamBold
        newBadge.ZIndex=9 newBadge.Parent=hrow corner(newBadge,5)
    end

    local titleOff = v.latest and 100 or 46
    local tlbl=Instance.new("TextLabel")
    tlbl.Size=UDim2.new(1,-titleOff,1,0) tlbl.Position=UDim2.new(0,titleOff,0,0)
    tlbl.BackgroundTransparency=1 tlbl.Text=v.title tlbl.TextColor3=THEME.TEXT
    tlbl.TextSize=13 tlbl.Font=Enum.Font.GothamBold tlbl.TextXAlignment=Enum.TextXAlignment.Left
    tlbl.ZIndex=8 tlbl.Parent=hrow

    -- divider
    local div=Instance.new("Frame")
    div.Size=UDim2.new(1,0,0,1) div.BackgroundColor3=THEME.BORDER div.BorderSizePixel=0
    div.LayoutOrder=2 div.ZIndex=8 div.Parent=card

    -- bullet notes
    for ni,note in ipairs(v.notes) do
        local brow=Instance.new("Frame")
        brow.Size=UDim2.new(1,0,0,0) brow.AutomaticSize=Enum.AutomaticSize.Y
        brow.BackgroundTransparency=1 brow.LayoutOrder=ni+2 brow.ZIndex=8 brow.Parent=card
        local dot=Instance.new("Frame")
        dot.Size=UDim2.new(0,4,0,4) dot.Position=UDim2.new(0,0,0,7)
        dot.BackgroundColor3=v.color dot.BorderSizePixel=0 dot.ZIndex=9 dot.Parent=brow corner(dot,2)
        local ntxt=Instance.new("TextLabel")
        ntxt.Size=UDim2.new(1,-12,0,0) ntxt.Position=UDim2.new(0,12,0,0)
        ntxt.AutomaticSize=Enum.AutomaticSize.Y ntxt.BackgroundTransparency=1
        ntxt.Text=note ntxt.TextColor3=THEME.SUB ntxt.TextSize=11 ntxt.Font=Enum.Font.Gotham
        ntxt.TextXAlignment=Enum.TextXAlignment.Left ntxt.TextWrapped=true
        ntxt.ZIndex=9 ntxt.Parent=brow
    end
end

-- sync logic
local syncThread,syncActive=nil,false

-- resetUI only touches visuals — safe to call from anywhere including inside the thread
local function resetUI()
    syncActive=false
    CDNum.Text="--:--" CDGlow.Text="--:--"
    CDNum.TextColor3=THEME.TEXT CDGlow.TextColor3=THEME.ACCENT CDGlow.TextTransparency=0.72
    CDSub.Text="Waiting for sync..." CDSub.TextColor3=THEME.DIM
    tw(cdStroke,{Color=THEME.BORDER})
    SetSyncBtn.Text="▶  SET SYNC" LoadSyncBtn.Text="⬇  LOAD SYNC"
end

-- resetSync cancels an external thread then resets UI — never call from inside syncThread
local function resetSync()
    if syncThread then
        local t=syncThread syncThread=nil
        pcall(task.cancel, t)
    end
    resetUI()
end

-- ── Crew ID auto-scanner ──────────────────────────────────────────────────────
local function scanCrewId(logFn)
    local crew = getCrewRemote()
    if not crew then logFn("Remotes.Crew not found", THEME.ERROR) return nil end

    local function findId(t, depth)
        if depth > 6 or type(t) ~= "table" then return nil end
        for k, v in pairs(t) do
            local ks = tostring(k):lower()
            local vs = tostring(v)
            if (ks:find("crewid") or ks:find("crew_id") or ks == "id") and vs:match("%d+|%d+") then
                return vs
            end
            if type(v) == "table" then local r=findId(v,depth+1) if r then return r end end
        end
        return nil
    end

    -- ask the server for data via every likely action name
    for _, action in ipairs({"GetData","GetCrewData","GetPlayerData","GetCrewInfo"}) do
        local ok, res = pcall(function() return crew:InvokeServer(action) end)
        if ok and type(res) == "table" then
            logFn("'"..action.."' responded — scanning table...", THEME.SUB)
            local id = findId(res, 0)
            if id then return id end
            for k,v in pairs(res) do logFn("  "..tostring(k).."="..tostring(v), THEME.DIM) end
        end
    end

    -- fallback: scan StringValues on all players in-server
    for _, p in ipairs(Players:GetPlayers()) do
        for _, obj in ipairs(p:GetDescendants()) do
            if obj:IsA("StringValue") and obj.Value:match("%d+|%d+") then
                local n = obj.Name:lower()
                if n:find("crew") or n:find("id") then
                    logFn("Found on "..p.Name.." ("..obj.Name.."): "..obj.Value, THEME.SUCCESS)
                    return obj.Value
                end
            end
        end
    end

    logFn("Auto-scan found nothing — ask crew owner for their ID", THEME.WARN)
    return nil
end

local function runSync(target, crewId, sub)
    syncActive=true tw(cdStroke,{Color=THEME.ACCENT})
    SetSyncBtn.Text="■  CANCEL" LoadSyncBtn.Text="■  CANCEL"
    CDSub.Text=sub or "Joining in..." CDSub.TextColor3=THEME.SUB
    syncThread=task.spawn(function()
        while true do
            local rem=target-os.time() if rem<=0 then break end
            local str=string.format("%02d:%02d",math.floor(rem/60),rem%60)
            CDNum.Text=str CDGlow.Text=str
            if rem<=5 then
                CDNum.TextColor3=THEME.ERROR CDGlow.TextColor3=THEME.ERROR CDGlow.TextTransparency=0.55
                CDSub.TextColor3=THEME.ERROR tw(cdStroke,{Color=THEME.ERROR})
            elseif rem<=10 then
                CDNum.TextColor3=THEME.WARN CDGlow.TextColor3=THEME.WARN CDGlow.TextTransparency=0.6
                CDSub.TextColor3=THEME.WARN tw(cdStroke,{Color=THEME.WARN})
            else
                CDNum.TextColor3=THEME.TEXT CDGlow.TextColor3=THEME.ACCENT CDGlow.TextTransparency=0.72
                tw(cdStroke,{Color=THEME.ACCENT})
            end
            task.wait(0.1)
        end
        CDNum.Text="JOIN!" CDGlow.Text="JOIN!"
        CDNum.TextColor3=THEME.SUCCESS CDGlow.TextColor3=THEME.SUCCESS CDGlow.TextTransparency=0.5
        CDSub.Text="Joining crew..." CDSub.TextColor3=THEME.SUCCESS
        tw(cdStroke,{Color=THEME.SUCCESS})
        addSyncLog("Timer hit 0 — joining crew: "..tostring(crewId), THEME.SUCCESS)
        -- stagger each instance by a small random amount (0–1.2s)
        -- simultaneous hits get rejected by the server; staggered ones go through
        local stagger = math.random(0, 12) * 0.1
        addSyncLog("Stagger: "..string.format("%.1f", stagger).."s (avoids server rejection)", THEME.DIM)
        task.wait(stagger)
        joinCrew(crewId, addSyncLog)
        syncThread=nil
        task.wait(2.5) resetUI()
    end)
end

-- ── Invite status refresh ─────────────────────────────────────────────────────
refreshStatus = function()
    for _, c in ipairs(DotsFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local all = Players:GetPlayers()
    local count = 0
    for i, p in ipairs(all) do
        local invited = invitedPlayers[p.Name] == true
        local isSelf  = p == LocalPlayer
        if invited then count = count + 1 end
        local col = isSelf and THEME.WARN or (invited and THEME.SUCCESS or THEME.ERROR)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 10, 0, 10)
        dot.BackgroundColor3 = col
        dot.BorderSizePixel = 0
        dot.LayoutOrder = i
        dot.ZIndex = 9
        dot.Parent = DotsFrame
        corner(dot, 5)
    end
    StatusCountLbl.Text = count.." / "..#all
    StatusCountLbl.TextColor3 = count == #all and THEME.SUCCESS or (count > 0 and THEME.WARN or THEME.ERROR)
end

RefreshBtn.MouseButton1Click:Connect(function()
    tw(RefreshBtn, {TextColor3 = THEME.SUCCESS})
    refreshStatus()
    task.delay(0.4, function() tw(RefreshBtn, {TextColor3 = THEME.ACCENT}) end)
end)
refreshStatus()

-- ── Auto-listen logic ─────────────────────────────────────────────────────────
local isListening=false
local listenThread=nil
local lastFileStamp=""
lastSyncId=""

function encodeSyncPayload(payload)
    return HttpService:JSONEncode(payload)
end

function decodeSyncPayload(raw)
    local ok,data=pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(data)=="table" then
        local action=tostring(data.action or "START"):upper()
        data.action=action
        data.syncId=tostring(data.syncId or "")
        if action=="CANCEL" then return data end
        if tonumber(data.targetEpoch) then
            data.targetEpoch=math.floor(tonumber(data.targetEpoch))
            return data
        end
    end
    local crewId,ts=tostring(raw):match("^(.+)@@(%d+)$")
    if crewId and ts then
        return {version=1,action="START",crewId=crewId,targetEpoch=tonumber(ts),syncId="legacy-"..ts}
    end
    return nil
end

function makeStartPayload(crewId,target)
    local ownerName="Unknown"
    local ownerId=tostring(crewId):match("^(%d+)|")
    if ownerId then
        local pid=tonumber(ownerId)
        local ok,name=pcall(function() return Players:GetNameFromUserIdAsync(pid) end)
        if ok and name then ownerName=name end
    end
    return {version=4,action="START",owner="Merciful",crewId=crewId,crewOwner=ownerName,targetEpoch=math.floor(target),generatedAt=os.time(),syncId=newSyncId()}
end

function makeCancelPayload()
    return {version=4,action="CANCEL",owner="Merciful",generatedAt=os.time(),syncId=newSyncId()}
end

function applyIncomingSync(payload,source)
    local action=tostring(payload.action or "START"):upper()
    if action=="CANCEL" then
        resetSync()
        addSyncLog("Synchronization detected: timer cancelled",THEME.WARN)
        if CrewOwnerLbl then CrewOwnerLbl.Text="Owner: --" end
        return true
    end
    local crewId=tostring(payload.crewId or "")
    local target=tonumber(payload.targetEpoch)
    if crewId=="" or not target then return false end
    if syncActive then resetSync() end
    CrewIdInput.Text=crewId
    local ownerName=tostring(payload.crewOwner or "")
    if ownerName=="" then
        local ownerId=crewId:match("^(%d+)|")
        if ownerId then
            local ok,name=pcall(function() return Players:GetNameFromUserIdAsync(tonumber(ownerId)) end)
            if ok and name then ownerName=name end
        end
    end
    CrewOwnerLbl.Text="Owner: "..((ownerName~="") and ownerName or "Unknown")
    addSyncLog("Synchronization detected",THEME.ACCENT)
    addSyncLog("Crew: "..crewId.." • Owner: "..((ownerName~="") and ownerName or "Unknown"),THEME.SUCCESS)
    local rem=target-os.time()
    if rem<=0 then
        addSyncLog("Detected sync is already expired",THEME.WARN)
        return false
    end
    SyncCodeBox.Text=encodeSyncPayload(payload)
    runSync(target,crewId,source or "Synced — joining in...")
    return true
end

local function stopListening()
    isListening=false
    if listenThread then pcall(task.cancel,listenThread) listenThread=nil end
    AutoListenBtn.Text="👂  AUTO"
    AutoListenBtn.BackgroundColor3=THEME.CARD2
    tw(AutoListenBtn,{TextColor3=THEME.TEXT})
    addSyncLog("Auto-listen stopped",THEME.WARN)
end

local function startListening()
    if isListening then return end
    if not hasFS then
        addSyncLog("Auto-listen needs writefile/readfile — not in this executor",THEME.ERROR)
        return
    end
    isListening=true
    AutoListenBtn.Text="⏹  STOP"
    AutoListenBtn.BackgroundColor3=Color3.fromRGB(160,30,30)
    tw(AutoListenBtn,{TextColor3=Color3.new(1,1,1)})
    addSyncLog("Auto-listen ON — watching for NEW sync snapshots...",THEME.SUCCESS)
    listenThread=task.spawn(function()
        while isListening do
            task.wait(0.20)
            local okRead,data=pcall(readSharedSync)
            if okRead and data~="" and data~=lastFileStamp then
                lastFileStamp=data
                local payload=decodeSyncPayload(data)
                if payload and payload.syncId~=lastSyncId then
                    lastSyncId=payload.syncId
                    if SCRIPT_READY then
                        applyIncomingSync(payload,"Shared sync detected")
                    end
                end
            end
        end
    end)
end

AutoListenBtn.MouseButton1Click:Connect(function()
    if isListening then stopListening() else startListening() end
end)

-- wire up the Scan button (defined in UI section, used here)
function showCrewOwner(id)
    local ownerName="Unknown"
    local ownerId=tostring(id or ""):match("^(%d+)|")
    if ownerId then
        local pid=tonumber(ownerId)
        local ok,name=pcall(function() return Players:GetNameFromUserIdAsync(pid) end)
        if ok and name then ownerName=name end
    end
    CrewOwnerLbl.Text="Owner: "..ownerName
    addSyncLog("Crew detected: "..tostring(id).." • Owner: "..ownerName,THEME.SUCCESS)
    return ownerName
end

ScanCrewBtn.MouseButton1Click:Connect(function()
    addSyncLog("Scanning for Crew ID...", THEME.ACCENT)
    local id = scanCrewId(addSyncLog)
    if id then
        CrewIdInput.Text = id
        showCrewOwner(id)
        addSyncLog("Auto-filled: "..id, THEME.SUCCESS)
    end
end)

-- parse a sync code string — format: "crewId@@timestamp"
parseSyncCode = function(raw)
    local d=decodeSyncPayload(raw)
    if not d then return nil,nil,nil end
    return d.crewId,tonumber(d.targetEpoch),d
end

CopyCodeBtn.MouseButton1Click:Connect(function()
    local code = SyncCodeBox.Text
    if code == "" then addSyncLog("No sync code yet — press SET SYNC first", THEME.WARN) return end
    if type(setclipboard) == "function" then
        pcall(setclipboard, code)
        addSyncLog("Code copied to clipboard!", THEME.SUCCESS)
    else
        addSyncLog("setclipboard not available — copy manually: "..code, THEME.WARN)
    end
end)

ApplyCodeBtn.MouseButton1Click:Connect(function()
    local raw = SyncCodeBox.Text:match("^%s*(.-)%s*$")
    if raw=="" then addSyncLog("Paste a sync code into the box first",THEME.ERROR) return end
    local crewId,target,payload=parseSyncCode(raw)
    if not crewId or not target then addSyncLog("Invalid sync code format",THEME.ERROR) return end
    local rem=target-os.time()
    if rem<=0 then addSyncLog("Sync code already expired — get a fresh one",THEME.ERROR) return end
    if syncActive then resetSync() end
    SyncCodeBox.Text=raw
    CrewIdInput.Text=crewId
    showCrewOwner(crewId)
    addSyncLog("Applied code — Crew: "..crewId.." — joining in "..rem.."s",THEME.ACCENT)
    runSync(target,crewId,"Code applied — joining in...")
end)

SetSyncBtn.MouseButton1Click:Connect(function()
    local crewId=CrewIdInput.Text:match("^%s*(.-)%s*$")
    if crewId=="" then addSyncLog("Enter or scan a Crew ID first",THEME.ERROR) return end
    local target=getISTTargetTimestamp()
    local payload=makeStartPayload(crewId,target)
    local raw=encodeSyncPayload(payload)
    SyncCodeBox.Text=raw
    if hasFS then
        local ok,err=writeSharedSync(raw)
        if not ok then addSyncLog("Sync file write failed: "..tostring(err),THEME.ERROR) return end
        lastFileStamp=raw
        lastSyncId=payload.syncId
        addSyncLog(syncActive and "Previous sync replaced — new workspace snapshot written" or "Workspace sync data written",THEME.SUCCESS)
    end
    if syncActive then resetSync() end
    showCrewOwner(crewId)
    if type(setclipboard)=="function" then pcall(setclipboard,raw) end
    local rem=target-os.time()
    addSyncLog(string.format("Target set: %02d:%02d:%02d IST — joining in %ds",math.floor(((target+IST_OFFSET)%86400)/3600),math.floor(((target+IST_OFFSET)%3600)/60),(target+IST_OFFSET)%60,rem),THEME.TEXT)
    runSync(target,crewId,"Joining in...")
end)

LoadSyncBtn.MouseButton1Click:Connect(function()
    local raw=readSharedSync()
    if raw=="" then raw=SyncCodeBox.Text:match("^%s*(.-)%s*$") end
    if raw=="" then addSyncLog("No sync data found",THEME.ERROR) return end
    local payload=decodeSyncPayload(raw)
    if not payload then addSyncLog("Invalid sync data",THEME.ERROR) return end
    lastFileStamp=raw
    lastSyncId=tostring(payload.syncId or "")
    SyncCodeBox.Text=raw
    if tostring(payload.action or "START"):upper()=="CANCEL" then
        resetSync()
        addSyncLog("Loaded shared CANCEL state",THEME.WARN)
        return
    end
    applyIncomingSync(payload,"Shared settings loaded")
end)

-- Dedicated distributed-cancel button.
CancelSyncBtn=Instance.new("TextButton")
CancelSyncBtn.Size=UDim2.new(1,0,0,30) CancelSyncBtn.LayoutOrder=9
CancelSyncBtn.BackgroundColor3=THEME.CARD2 CancelSyncBtn.Text="✖  CANCEL SYNC FOR ALL INSTANCES"
CancelSyncBtn.TextColor3=THEME.ERROR CancelSyncBtn.TextSize=10 CancelSyncBtn.Font=Enum.Font.GothamBold
CancelSyncBtn.ZIndex=8 CancelSyncBtn.Parent=CtrlPart corner(CancelSyncBtn,8) stroke(CancelSyncBtn,THEME.ERROR)
CancelSyncBtn.MouseButton1Click:Connect(function()
    local payload=makeCancelPayload()
    local raw=encodeSyncPayload(payload)
    if hasFS then
        local ok,err=writeSharedSync(raw)
        if not ok then addSyncLog("Cancel sync write failed: "..tostring(err),THEME.ERROR) return end
        lastFileStamp=raw
        lastSyncId=payload.syncId
        addSyncLog("Previous sync deleted/replaced with CANCEL snapshot — all listeners will cancel",THEME.WARN)
    else
        addSyncLog("No file API — cancellation cannot be propagated",THEME.WARN)
    end
    resetSync()
    addSyncLog("Timer cancelled locally and published globally",THEME.WARN)
end)

-- ── Tab switch ────────────────────────────────────────────────────────────────
local TW          = (W-24)/4
local TAB_INVITE  = UDim2.new(0, 16,        0, MH+8+38-3)
local TAB_SYNC    = UDim2.new(0, 16+TW,     0, MH+8+38-3)
local TAB_WEBHOOK = UDim2.new(0, 16+TW*2,   0, MH+8+38-3)
local TAB_NOTES   = UDim2.new(0, 16+TW*3,   0, MH+8+38-3)

local function switchTab(tab)
    InviterPanel.Visible=(tab=="inviter")
    SyncPanel.Visible   =(tab=="sync")
    WebhookPanel.Visible=(tab=="webhook")
    NotesPanel.Visible  =(tab=="notes")
    local pos = tab=="inviter" and TAB_INVITE
        or tab=="sync"    and TAB_SYNC
        or tab=="webhook" and TAB_WEBHOOK
        or TAB_NOTES
    tw(TabLine,     {Position=pos})
    tw(TabInviter,  {BackgroundColor3=tab=="inviter"  and THEME.ACCENT or THEME.CARD, TextColor3=tab=="inviter"  and THEME.TEXT or THEME.DIM})
    tw(TabSync,     {BackgroundColor3=tab=="sync"     and THEME.ACCENT or THEME.CARD, TextColor3=tab=="sync"     and THEME.TEXT or THEME.DIM})
    tw(TabWebhook,  {BackgroundColor3=tab=="webhook"  and THEME.ACCENT or THEME.CARD, TextColor3=tab=="webhook"  and THEME.TEXT or THEME.DIM})
    tw(TabNotes,    {BackgroundColor3=tab=="notes"    and THEME.ACCENT or THEME.CARD, TextColor3=tab=="notes"    and THEME.TEXT or THEME.DIM})
end

-- SYNC is the default tab on load
switchTab("sync")
refreshStatus()

TabInviter.MouseButton1Click:Connect(function()  switchTab("inviter")  end)
TabSync.MouseButton1Click:Connect(function()     switchTab("sync") refreshStatus() end)
TabWebhook.MouseButton1Click:Connect(function()  switchTab("webhook")  end)
TabNotes.MouseButton1Click:Connect(function()    switchTab("notes")    end)

-- ── Drag ──────────────────────────────────────────────────────────────────────
local dragging,dragStart,startPos
Header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true dragStart=i.Position startPos=Window.Position end
end)
Header.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        Window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- ── RunService: rainbow + shimmer (throttled) ─────────────────────────────────
-- Colour math + ColorSequence allocation now only runs ~15x/sec instead of
-- every single frame — same look, far less GC pressure over a long session.
local hue,shimTimer=0,0
local hbAccum = 0
local HEARTBEAT_INTERVAL = 1/15
RunService.Heartbeat:Connect(function(dt)
    shimTimer=shimTimer+dt
    if shimTimer>=3 and not inviting then shimTimer=0 runShimmer() end

    hbAccum=hbAccum+dt
    if hbAccum<HEARTBEAT_INTERVAL then return end
    local step=hbAccum
    hbAccum=0

    hue=(hue+step*0.07)%1
    rbGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,  Color3.fromHSV(hue,             0.9,1)),
        ColorSequenceKeypoint.new(0.33,Color3.fromHSV((hue+0.12)%1,  0.9,1)),
        ColorSequenceKeypoint.new(0.66,Color3.fromHSV((hue+0.25)%1,  0.88,1)),
        ColorSequenceKeypoint.new(1,  Color3.fromHSV((hue+0.38)%1,  0.85,1)),
    })
    winStroke.Color=Color3.fromHSV(hue,0.55,0.7)
    TitleIcon.TextColor3=Color3.fromHSV(hue,0.85,1)
    -- tab indicator follows hue too
    TabLine.BackgroundColor3=Color3.fromHSV(hue,0.7,1)
end)

-- ── Resize handle (drag bottom edge to make window taller) ───────────────────
local ResizeHandle=Instance.new("TextButton")
ResizeHandle.Size=UDim2.new(1,-20,0,10)
ResizeHandle.Position=UDim2.new(0,10,1,-10)
ResizeHandle.BackgroundColor3=THEME.DIM
ResizeHandle.BorderSizePixel=0
ResizeHandle.Text=""
ResizeHandle.AutoButtonColor=false
ResizeHandle.ZIndex=12
ResizeHandle.Parent=Window
corner(ResizeHandle,3)

local resizing,resizeStartY,resizeStartH=false,0,H
local MIN_H,MAX_H=380,900

ResizeHandle.MouseEnter:Connect(function() tw(ResizeHandle,{BackgroundColor3=THEME.ACCENT}) end)
ResizeHandle.MouseLeave:Connect(function() if not resizing then tw(ResizeHandle,{BackgroundColor3=THEME.DIM}) end end)

ResizeHandle.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        resizing=true
        resizeStartY=i.Position.Y
        resizeStartH=Window.AbsoluteSize.Y
    end
end)
ResizeHandle.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        resizing=false
        tw(ResizeHandle,{BackgroundColor3=THEME.DIM})
        -- sync H for minimize/restore
        H=Window.AbsoluteSize.Y
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if resizing and i.UserInputType==Enum.UserInputType.MouseMovement then
        local newH=math.clamp(resizeStartH+(i.Position.Y-resizeStartY),MIN_H,MAX_H)
        Window.Size=UDim2.new(0,W,0,newH)
        ContentArea.Size=UDim2.new(1,0,0,newH-CY)
    end
end)

-- ── Entrance ──────────────────────────────────────────────────────────────────
Window.Position=UDim2.new(0.5,-W/2,-0.9,0)
tw(Window,{Position=UDim2.new(0.5,-W/2,0.5,-H/2),BackgroundTransparency=0},0.5,Enum.EasingStyle.Back)

-- Establish an initial baseline BEFORE starting the watcher so an old snapshot
-- never arms the timer automatically when this script first loads.
if hasFS then
    local existing=readSharedSync()
    if existing~="" then
        lastFileStamp=existing
        local baseline=decodeSyncPayload(existing)
        lastSyncId=baseline and tostring(baseline.syncId or "") or ""
        addSyncLog("Existing sync snapshot found — waiting for a NEW sync event",THEME.DIM)
    end
    startListening()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AUTO JOIN: PIRATES
-- Runs in the background, ~7s after this script starts, so team-select
-- automation doesn't fight the GUI build / Performance Mode init for frames.
-- Does not block anything above — GUI stays responsive the whole time.
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    task.wait(7)

    local ajPlayers = game:GetService("Players")
    local lp = ajPlayers.LocalPlayer or ajPlayers:GetPropertyChangedSignal("LocalPlayer"):Wait() and ajPlayers.LocalPlayer

    local TEAM = "Pirates" -- change to "Marines" if you ever want the other side

    print("[AutoJoin] Waiting for character/team-select state...")

    -- If we already have a character with a HumanoidRootPart, a team was
    -- already picked (e.g. rejoin mid-session) — nothing to do.
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        print("[AutoJoin] Character already spawned — team already selected, skipping.")
        return
    end

    local playerGui = lp:WaitForChild("PlayerGui")
    local mainGui = playerGui:WaitForChild("Main (minimal)", 30)

    if not mainGui then
        warn("[AutoJoin] Could not find 'Main (minimal)' GUI — team select screen not found.")
        return
    end

    -- Drill down to the exact button for the chosen team
    local btn
    local searchStart = tick()
    repeat
        task.wait()
        btn = mainGui:FindFirstChild("ChooseTeam")
            and mainGui.ChooseTeam:FindFirstChild("Container")
            and mainGui.ChooseTeam.Container:FindFirstChild(TEAM)
            and mainGui.ChooseTeam.Container[TEAM]:FindFirstChild("Frame")
            and mainGui.ChooseTeam.Container[TEAM].Frame:FindFirstChild("TextButton")
    until btn or (tick() - searchStart > 15)

    if not btn then
        warn("[AutoJoin] Could not locate the " .. TEAM .. " button in the GUI.")
        return
    end

    print("[AutoJoin] Found " .. TEAM .. " button — firing selection...")

    -- Try several methods for compatibility across executors, and a real
    -- click fallback via VirtualInputManager if signal-firing isn't available.
    local function pressButton()
        local fired = false

        pcall(function()
            if firesignal then
                firesignal(btn.Activated)
                firesignal(btn.MouseButton1Click)
                fired = true
            end
        end)

        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(btn.Activated)) do
                    conn:Fire()
                    fired = true
                end
                for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                    conn:Fire()
                    fired = true
                end
            end
        end)

        if not fired then
            -- Fallback: simulate a real click at the button's screen position
            pcall(function()
                local pos = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                local cx = pos.X + size.X / 2
                local cy = pos.Y + size.Y / 2
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end

    -- Keep pressing every 0.25s until a character actually spawns
    local attempts = 0
    repeat
        pressButton()
        task.wait(0.25)
        attempts = attempts + 1
        if attempts % 8 == 0 then
            print("[AutoJoin] Still waiting for spawn... (" .. attempts .. " attempts)")
        end
    until (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) or attempts > 80

    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        print("[AutoJoin] ✅ Joined " .. TEAM .. " — character spawned.")
    else
        warn("[AutoJoin] ❌ Gave up after " .. attempts .. " attempts. Select the team manually.")
    end
end)
