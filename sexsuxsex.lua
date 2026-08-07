-- Blox Fruits | Spam Crew Join
-- Press H to toggle spam-joining a crew. Keeps spamming until you press H again.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local HOTKEY      = Enum.KeyCode.H
local ATTEMPT_DELAY = 0.005  -- seconds between join attempts while spamming (~20/sec)

-- Set a Crew ID here if you always join the same crew, e.g. "3569141797|53623713".
-- Leave it blank ("") and the script will auto-scan the server for it instead.
local CREW_ID = ""

local W, H_, MH = 320, 310, 56

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

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function tw(o, p, t, s, d)
    return TweenService:Create(o, TweenInfo.new(t or 0.2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p)
end
local function corner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 10) c.Parent=p return c end
local function stroke(p, col, th) local s=Instance.new("UIStroke") s.Color=col or THEME.BORDER s.Thickness=th or 1 s.Parent=p return s end
local function grad(p, c0, c1, r) local g=Instance.new("UIGradient") g.Color=ColorSequence.new(c0,c1) g.Rotation=r or 0 g.Parent=p return g end
local function pad(p, l, r, t, b) local u=Instance.new("UIPadding") u.PaddingLeft=UDim.new(0,l) u.PaddingRight=UDim.new(0,r) u.PaddingTop=UDim.new(0,t) u.PaddingBottom=UDim.new(0,b) u.Parent=p end
local function vlist(p, gap) local l=Instance.new("UIListLayout") l.SortOrder=Enum.SortOrder.LayoutOrder l.Padding=UDim.new(0,gap or 8) l.Parent=p return l end

-- ── Remote + join logic (same pattern as Crew Tools) ───────────────────────────
local function getCrewRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then return remotes:FindFirstChild("Crew") end
    return nil
end

local function resIsSuccess(res)
    if res == nil or res == false then return false end
    local s = tostring(res):lower()
    if s == "false" or s:find("fail") or s:find("error") or s:find("invalid")
       or s:find("no invite") or s:find("already") then return false end
    return true
end

local function tryJoinOnce(crewId, logFn)
    local crew = getCrewRemote()
    if not crew then logFn("Remotes.Crew not found", THEME.ERROR) return false end

    local attempts = {
        function() return crew:InvokeServer("Join",     {CrewID = crewId}) end,
        function() return crew:InvokeServer("Join",     crewId)            end,
        function() return crew:InvokeServer("JoinCrew", {CrewID = crewId}) end,
        function() return crew:InvokeServer("JoinCrew", crewId)            end,
    }
    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        if ok and resIsSuccess(res) then
            logFn("Joined! Server res: "..tostring(res), THEME.SUCCESS)
            return true
        end
    end
    return false
end

-- Auto-scan for a crew ID on the server (same approach as Crew Tools) — used
-- whenever CREW_ID is left blank so you never have to type one in manually.
local function scanCrewId(logFn)
    local crew = getCrewRemote()
    if not crew then return nil end

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

    for _, action in ipairs({"GetData","GetCrewData","GetPlayerData","GetCrewInfo"}) do
        local ok, res = pcall(function() return crew:InvokeServer(action) end)
        if ok and type(res) == "table" then
            local id = findId(res, 0)
            if id then return id end
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        for _, obj in ipairs(p:GetDescendants()) do
            if obj:IsA("StringValue") and obj.Value:match("%d+|%d+") then
                local n = obj.Name:lower()
                if n:find("crew") or n:find("id") then
                    return obj.Value
                end
            end
        end
    end

    return nil
end

-- ── GUI root ──────────────────────────────────────────────────────────────────
local old = LocalPlayer.PlayerGui:FindFirstChild("SpamJoinGui")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name="SpamJoinGui" Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Gui.ResetOnSpawn=false Gui.IgnoreGuiInset=true Gui.Parent=LocalPlayer.PlayerGui

local Window = Instance.new("Frame")
Window.Size=UDim2.new(0,W,0,H_)
Window.Position=UDim2.new(0.5,-W/2,0.5,-H_/2)
Window.BackgroundColor3=THEME.BG
Window.BorderSizePixel=0
Window.BackgroundTransparency=1
Window.Parent=Gui
corner(Window,18)
local winStroke = stroke(Window, THEME.BORDER, 1.5)

-- Header
local Header = Instance.new("Frame")
Header.Size=UDim2.new(1,0,0,MH) Header.BackgroundColor3=THEME.PANEL Header.BorderSizePixel=0 Header.ZIndex=10 Header.Parent=Window
corner(Header,18)
local hFix=Instance.new("Frame") hFix.Size=UDim2.new(1,0,0,18) hFix.Position=UDim2.new(0,0,1,-18) hFix.BackgroundColor3=THEME.PANEL hFix.BorderSizePixel=0 hFix.ZIndex=10 hFix.Parent=Header

local TitleIcon=Instance.new("TextLabel")
TitleIcon.Size=UDim2.new(0,30,0,30) TitleIcon.Position=UDim2.new(0,12,0.5,-15)
TitleIcon.BackgroundTransparency=1 TitleIcon.Text="⚡" TitleIcon.TextColor3=THEME.ACCENT
TitleIcon.TextSize=20 TitleIcon.Font=Enum.Font.GothamBold TitleIcon.ZIndex=11 TitleIcon.Parent=Header

local TitleLbl=Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(1,-130,0,18) TitleLbl.Position=UDim2.new(0,48,0,10)
TitleLbl.BackgroundTransparency=1 TitleLbl.Text="Spam Crew Join" TitleLbl.TextColor3=THEME.TEXT
TitleLbl.TextSize=14 TitleLbl.Font=Enum.Font.GothamBold TitleLbl.TextXAlignment=Enum.TextXAlignment.Left TitleLbl.ZIndex=11 TitleLbl.Parent=Header

local SubLbl=Instance.new("TextLabel")
SubLbl.Size=UDim2.new(1,-130,0,13) SubLbl.Position=UDim2.new(0,48,0,30)
SubLbl.BackgroundTransparency=1 SubLbl.Text="Hotkey: H  •  toggles spam-join"
SubLbl.TextColor3=THEME.SUB SubLbl.TextSize=10 SubLbl.Font=Enum.Font.Gotham
SubLbl.TextXAlignment=Enum.TextXAlignment.Left SubLbl.ZIndex=11 SubLbl.Parent=Header

local CloseBtn=Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0,26,0,26) CloseBtn.Position=UDim2.new(1,-36,0.5,-13)
CloseBtn.BackgroundColor3=Color3.fromRGB(52,20,32) CloseBtn.Text="✕"
CloseBtn.TextColor3=THEME.ERROR CloseBtn.TextSize=13 CloseBtn.Font=Enum.Font.GothamBold CloseBtn.ZIndex=11 CloseBtn.Parent=Header
corner(CloseBtn,7)

-- Body
local Body=Instance.new("Frame")
Body.Size=UDim2.new(1,0,1,-MH) Body.Position=UDim2.new(0,0,0,MH)
Body.BackgroundTransparency=1 Body.ZIndex=6 Body.Parent=Window
pad(Body,14,14,12,12) vlist(Body,10)

-- Status card (animated)
local StatusCard=Instance.new("Frame")
StatusCard.Size=UDim2.new(1,0,0,64) StatusCard.LayoutOrder=1
StatusCard.BackgroundColor3=THEME.CARD StatusCard.ZIndex=7 StatusCard.Parent=Body
corner(StatusCard,12) local statusStroke=stroke(StatusCard,THEME.BORDER,1.5)

local StatusDot=Instance.new("Frame")
StatusDot.Size=UDim2.new(0,12,0,12) StatusDot.Position=UDim2.new(0,16,0,14)
StatusDot.BackgroundColor3=THEME.DIM StatusDot.BorderSizePixel=0 StatusDot.ZIndex=8 StatusDot.Parent=StatusCard
corner(StatusDot,6)

local StatusLbl=Instance.new("TextLabel")
StatusLbl.Size=UDim2.new(1,-40,0,18) StatusLbl.Position=UDim2.new(0,36,0,10)
StatusLbl.BackgroundTransparency=1 StatusLbl.Text="IDLE" StatusLbl.TextColor3=THEME.TEXT
StatusLbl.TextSize=15 StatusLbl.Font=Enum.Font.GothamBold StatusLbl.TextXAlignment=Enum.TextXAlignment.Left
StatusLbl.ZIndex=8 StatusLbl.Parent=StatusCard

local StatsLbl=Instance.new("TextLabel")
StatsLbl.Size=UDim2.new(1,-40,0,16) StatsLbl.Position=UDim2.new(0,36,0,32)
StatsLbl.BackgroundTransparency=1 StatsLbl.Text="0 attempts  •  press H to start"
StatsLbl.TextColor3=THEME.SUB StatsLbl.TextSize=10 StatsLbl.Font=Enum.Font.Gotham
StatsLbl.TextXAlignment=Enum.TextXAlignment.Left StatsLbl.ZIndex=8 StatsLbl.Parent=StatusCard

-- Start/Stop button (mirrors the hotkey)
local ToggleBtn=Instance.new("TextButton")
ToggleBtn.Size=UDim2.new(0,64,0,44) ToggleBtn.Position=UDim2.new(1,-78,0,10)
ToggleBtn.BackgroundColor3=THEME.ACCENT ToggleBtn.Text="H"
ToggleBtn.TextColor3=Color3.new(1,1,1) ToggleBtn.TextSize=20 ToggleBtn.Font=Enum.Font.GothamBold
ToggleBtn.ZIndex=9 ToggleBtn.Parent=StatusCard
corner(ToggleBtn,10) grad(ToggleBtn,THEME.ACCENT,THEME.ACCENT2,0)

-- Console log (compact terminal style)
local ConsoleFrame=Instance.new("Frame")
ConsoleFrame.Size=UDim2.new(1,0,1,-84) ConsoleFrame.LayoutOrder=2
ConsoleFrame.BackgroundColor3=Color3.fromRGB(6,8,14) ConsoleFrame.BorderSizePixel=0
ConsoleFrame.ZIndex=6 ConsoleFrame.Parent=Body
corner(ConsoleFrame,12)

local Console=Instance.new("ScrollingFrame")
Console.Size=UDim2.new(1,-4,1,-4) Console.Position=UDim2.new(0,2,0,2)
Console.BackgroundTransparency=1 Console.BorderSizePixel=0
Console.ScrollBarThickness=3 Console.ScrollBarImageColor3=Color3.fromRGB(50,60,100)
Console.CanvasSize=UDim2.new(0,0,0,0) Console.AutomaticCanvasSize=Enum.AutomaticSize.Y
Console.ZIndex=7 Console.Parent=ConsoleFrame
vlist(Console,0) pad(Console,8,8,6,6)

local logCount=0
local function addLog(msg,color)
    logCount=logCount+1
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,17) row.LayoutOrder=logCount row.ZIndex=8 row.Parent=Console
    row.BackgroundColor3=logCount%2==0 and Color3.fromRGB(10,12,22) or Color3.fromRGB(6,8,14)
    row.BorderSizePixel=0
    local bar=Instance.new("Frame") bar.Size=UDim2.new(0,2,1,0) bar.BackgroundColor3=color or THEME.SUB
    bar.BorderSizePixel=0 bar.ZIndex=9 bar.Parent=row
    local e=Instance.new("TextLabel") e.Size=UDim2.new(1,-10,1,0) e.Position=UDim2.new(0,8,0,0)
    e.BackgroundTransparency=1 e.Text=os.date("%H:%M:%S").."  "..msg
    e.TextColor3=color or Color3.fromRGB(175,185,210) e.TextSize=10 e.Font=Enum.Font.Code
    e.TextXAlignment=Enum.TextXAlignment.Left e.TextTruncate=Enum.TextTruncate.AtEnd e.ZIndex=9 e.Parent=row
    task.defer(function() Console.CanvasPosition=Vector2.new(0,math.huge) end)
end
addLog("Spam Crew Join loaded — press H to start", THEME.ACCENT)

-- ── Spam-join state machine ─────────────────────────────────────────────────
local spamming   = false
local spamThread = nil
local attemptCnt = 0
local pulseTween = nil

local function stopPulse()
    if pulseTween then pulseTween:Cancel() pulseTween=nil end
    tw(StatusDot,{BackgroundColor3=THEME.DIM},0.2):Play()
    tw(statusStroke,{Color=THEME.BORDER},0.2):Play()
end

local function startPulse()
    tw(statusStroke,{Color=THEME.ACCENT},0.2):Play()
    pulseTween = tw(StatusDot,{BackgroundColor3=THEME.SUCCESS},0.6,Enum.EasingStyle.Sine)
    pulseTween.Completed:Connect(function()
        if spamming then
            pulseTween = tw(StatusDot,{BackgroundColor3=THEME.ACCENT},0.6,Enum.EasingStyle.Sine)
            pulseTween:Play()
        end
    end)
    -- simple infinite yoyo pulse
    local seq = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    if pulseTween then pulseTween:Cancel() end
    pulseTween = TweenService:Create(StatusDot, seq, {BackgroundColor3=THEME.SUCCESS})
    pulseTween:Play()
end

local function stopSpam(reason, color)
    spamming = false
    if spamThread then pcall(task.cancel, spamThread) spamThread=nil end
    stopPulse()
    StatusLbl.Text = "IDLE"
    ToggleBtn.BackgroundColor3 = THEME.ACCENT
    if reason then addLog(reason, color or THEME.WARN) end
end

local function startSpam()
    local crewId = CREW_ID:match("^%s*(.-)%s*$")
    if crewId == "" then
        addLog("No CREW_ID set — auto-scanning...", THEME.ACCENT)
        crewId = scanCrewId(addLog)
        if not crewId then
            addLog("Auto-scan failed — set CREW_ID at the top of the script", THEME.ERROR)
            return
        end
        addLog("Auto-detected Crew: "..crewId, THEME.SUCCESS)
    end

    spamming = true
    attemptCnt = 0
    local successCnt = 0
    StatusLbl.Text = "SPAMMING"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(160,30,30)
    startPulse()
    addLog("Spam-join started — Crew: "..crewId.." (~"..(1/ATTEMPT_DELAY).."/sec)", THEME.SUCCESS)

    -- Keeps firing until H is pressed again, even after a successful join —
    -- doesn't auto-stop, per your request.
    spamThread = task.spawn(function()
        while spamming do
            attemptCnt = attemptCnt + 1
            local ok = tryJoinOnce(crewId, addLog)
            if ok then successCnt = successCnt + 1 end
            StatsLbl.Text = attemptCnt.." attempts, "..successCnt.." ok  •  press H to stop"
            task.wait(ATTEMPT_DELAY)
        end
    end)
end

local function toggleSpam()
    if spamming then
        stopSpam("Stopped by user", THEME.WARN)
    else
        startSpam()
    end
end

ToggleBtn.MouseButton1Click:Connect(toggleSpam)
CloseBtn.MouseButton1Click:Connect(function()
    stopSpam()
    tw(Window,{Position=UDim2.new(0.5,-W/2,1.4,0),BackgroundTransparency=1},0.3):Play()
    task.delay(0.35,function() Gui:Destroy() end)
end)

-- Hotkey: H toggles spam-join.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == HOTKEY then
        toggleSpam()
    end
end)

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

-- ── Entrance ──────────────────────────────────────────────────────────────────
Window.Position=UDim2.new(0.5,-W/2,-0.9,0)
tw(Window,{Position=UDim2.new(0.5,-W/2,0.5,-H_/2),BackgroundTransparency=0},0.5,Enum.EasingStyle.Back):Play()
