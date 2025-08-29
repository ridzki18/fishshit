--// Fish It → Discord Webhook Notifier (single-file, executor)
--// UI + draggable icon + chat parser + enrichment + Discord POST + Test Send
--// Icon: https://i.pinimg.com/736x/f8/ba/35/f8ba35d0f641058d208e2427af242e6c.jpg

----------------------------- Compat / Services -----------------------------
local http = (syn and syn.request) or http_request or request
local function hasHttp() return typeof(http) == "function" end

local HttpService = game:GetService("HttpService")
local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local LP          = Players.LocalPlayer

----------------------------- Config + Save/Load ----------------------------
local CAN_SAVE = (writefile and readfile and isfile) and true or false
local SAVE_PATH = "fishit_webhook_config.json"

local CFG = {
    enable = false,
    webhook = "",
    discordUserId = "",
    tiers = { Legendary=true, Mythic=true, SECRET=true },
    ui   = { x = 0.5, y = 0.5 },
    icon = { x = 0.05, y = 0.25 },
}

local function loadCfg()
    if not CAN_SAVE or not isfile(SAVE_PATH) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_PATH)) end)
    if ok and typeof(data) == "table" then
        for k,v in pairs(data) do
            if typeof(v) == "table" then
                CFG[k] = table.clone(v)
            else
                CFG[k] = v
            end
        end
    end
end
local function saveCfg()
    if not CAN_SAVE then return end
    local ok, j = pcall(function() return HttpService:JSONEncode(CFG) end)
    if ok then writefile(SAVE_PATH, j) end
end
loadCfg()

----------------------------- Tiers / Items -----------------------------
local TIERS_BY_INDEX = {}
do
    local ok, tiers = pcall(function() return require(RS:WaitForChild("Tiers")) end)
    if ok and typeof(tiers) == "table" then
        for _,t in ipairs(tiers) do TIERS_BY_INDEX[t.Tier] = t end
    end
end
local function c3ToInt(c)
    local r,g,b = math.floor((c.R or 0)*255), math.floor((c.G or 0)*255), math.floor((c.B or 0)*255)
    return r*65536 + g*256 + b
end
local function firstColor(cs)
    if typeof(cs)=="ColorSequence" and cs.Keypoints and cs.Keypoints[1] then
        return cs.Keypoints[1].Value
    elseif typeof(cs)=="Color3" then
        return cs
    end
    return Color3.fromRGB(88,101,242)
end
local function lookupFish(fishName)
    local folder = RS:FindFirstChild("Items"); if not folder then return {} end
    local ms = folder:FindFirstChild(fishName)
    if not ms or not ms:IsA("ModuleScript") then return {} end
    local ok, data = pcall(require, ms)
    if not ok or typeof(data) ~= "table" then return {} end
    local tierIdx = data.Data and data.Data.Tier
    local tierInfo = tierIdx and TIERS_BY_INDEX[tierIdx]
    return {
        sellPrice = data.SellPrice,
        icon      = data.Data and data.Data.Icon or "",
        tierName  = tierInfo and tierInfo.Name or ("Tier "..tostring(tierIdx or "?")),
        color     = tierInfo and c3ToInt(firstColor(tierInfo.TierColor)) or 0x5865F2,
    }
end

----------------------------- Discord Sender -----------------------------
local function sendDiscordEmbed(payload)
    if not hasHttp() then
        warn("[fishit] Executor HTTP (syn.request/http_request/request) tidak tersedia.")
        return false, "no-http"
    end
    if CFG.webhook == "" then
        warn("[fishit] Webhook URL belum diisi.")
        return false, "no-webhook"
    end
    local ok, err = pcall(function()
        http({
            Url = CFG.webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
    if not ok then warn("[fishit] send failed:", err) end
    return ok, err
end

local function sendCatch(playerName, fishName, weightStr, chanceN)
    local info = lookupFish(fishName)
    local tiersOk = true
    -- filter tier (kosong = Legendary+)
    local any=false; for _,v in pairs(CFG.tiers) do if v then any=true break end end
    local tierName = info.tierName or ""
    if any then tiersOk = CFG.tiers[tierName] == true
    else tiersOk = (tierName=="Legendary" or tierName=="Mythic" or tierName=="SECRET") end
    if not tiersOk then return end

    local embed = {
        title = string.format("A high-tier fish was caught by %s!", playerName or "Someone"),
        color = info.color or 0x5865F2,
        thumbnail = { url = info.icon or "" },
        fields = {
            { name="Fish Name 🐟",  value = fishName,                              inline=false },
            { name="Weight ⚖️",     value = weightStr or "-",                      inline=true  },
            { name="Rarity ✨",     value = (chanceN and chanceN>0 and ("1 in "..chanceN) or "-"), inline=true  },
            { name="Tier 🏆",       value = tierName ~= "" and tierName or "-",    inline=true  },
            { name="Sell Price 💰", value = info.sellPrice and tostring(info.sellPrice) or "-", inline=true },
        },
        footer = { text = "ArcvourHUB Notifier" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    local payload = {
        username = "Fish Notifier",
        content  = (CFG.discordUserId ~= "" and ("<@"..CFG.discordUserId..">") or ""),
        embeds   = { embed },
    }
    return sendDiscordEmbed(payload)
end

local function sendTest()
    local embed = {
        title = "Test Send ✅",
        description = "If you see this, webhook works!",
        color = 0x2ECC71,
        fields = {
            { name="Sample", value="Blob Fish", inline=true },
            { name="Rarity", value="1 in 50K", inline=true },
            { name="Tier",   value="Mythic",   inline=true },
        },
        thumbnail = { url = "https://i.pinimg.com/736x/f8/ba/35/f8ba35d0f641058d208e2427af242e6c.jpg" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "ArcvourHUB Notifier • test" },
    }
    local payload = {
        username = "Fish Notifier",
        content  = (CFG.discordUserId ~= "" and ("<@"..CFG.discordUserId..">") or ""),
        embeds   = { embed },
    }
    return sendDiscordEmbed(payload)
end

----------------------------- Chat Parser -----------------------------
local ChatEvents = RS:FindFirstChild("DefaultChatSystemChatEvents")
local OnMsg      = ChatEvents and ChatEvents:FindFirstChild("OnMessageDoneFiltering")

local function stripTags(s) return (s or ""):gsub("<[^>]->",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","") end
-- [Server]: name obtained a Blob Fish (2.45kg) with a 1 in 50K chance!
local PATTERN = "%[Server%]%:%s*([%w_%-]+)%s+obtained an?%s+(.+)%s+%(([%d%.]+%a)%)%s+with a 1 in%s+([%d,%.KkMm]+)%s+chance"
local function normalizeN(str)
    str = (str or ""):gsub(",", "")
    local k = str:match("^([%d%.]+)[Kk]$"); if k then return math.floor(tonumber(k)*1e3+0.5) end
    local m = str:match("^([%d%.]+)[Mm]$"); if m then return math.floor(tonumber(m)*1e6+0.5) end
    return tonumber(str) or 0
end

if OnMsg then
    OnMsg.OnClientEvent:Connect(function(d)
        if not CFG.enable then return end
        local msg = stripTags(d.Message or "")
        local who, fish, weight, nstr = msg:match(PATTERN)
        if fish then
            local ok, err = sendCatch(who, fish, weight, normalizeN(nstr))
            if ok then print("[fishit] sent:", fish, weight) else warn("[fishit] send error:", err) end
        end
    end)
else
    warn("[fishit] DefaultChatSystemChatEvents.OnMessageDoneFiltering tidak ditemukan (tunggu chat siap, lalu execute lagi).")
end

----------------------------- UI (Panel + Icon) -----------------------------
local function mkCorner(obj, r) local c=Instance.new("UICorner",obj) c.CornerRadius=UDim.new(0,r or 8) return c end

local sg = Instance.new("ScreenGui")
sg.Name = "FishWebhookUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
sg.Parent = LP:WaitForChild("PlayerGui")

-- Panel
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 340)
frame.Position = UDim2.new(CFG.ui.x or 0.5, -210, CFG.ui.y or 0.5, -170)
frame.BackgroundColor3 = Color3.fromRGB(24,26,33)
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = sg
mkCorner(frame, 12)

local title = Instance.new("TextLabel")
title.Text = "Webhook"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.fromOffset(200, 24)
title.Parent = frame

-- Status label
local statusL = Instance.new("TextLabel")
statusL.BackgroundTransparency = 1
statusL.Font = Enum.Font.Gotham
statusL.TextSize = 13
statusL.TextXAlignment = Enum.TextXAlignment.Right
statusL.TextColor3 = Color3.fromRGB(180,180,180)
statusL.Text = ""
statusL.Position = UDim2.new(1, -200, 0, 14)
statusL.Size = UDim2.fromOffset(180, 20)
statusL.Parent = frame

-- Minimize button
local minimize = Instance.new("TextButton")
minimize.Text = "_"
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 20
minimize.TextColor3 = Color3.new(1,1,1)
minimize.BackgroundColor3 = Color3.fromRGB(80,80,80)
minimize.Size = UDim2.fromOffset(28,28)
minimize.Position = UDim2.new(1,-36,0,8)
minimize.Parent = frame
mkCorner(minimize, 6)

-- Icon (draggable)
local icon = Instance.new("ImageButton")
icon.Name = "WebhookIcon"
icon.Image = "https://i.pinimg.com/736x/f8/ba/35/f8ba35d0f641058d208e2427af242e6c.jpg"
icon.Size = UDim2.fromOffset(60,60)
icon.Position = UDim2.new(CFG.icon.x or 0.05, 0, CFG.icon.y or 0.25, 0)
icon.BackgroundTransparency = 1
icon.Visible = false
icon.Parent = sg

-- Icon dragging
do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        CFG.icon.x, CFG.icon.y = icon.Position.X.Scale, icon.Position.Y.Scale
    end
    icon.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = icon.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false; saveCfg() end
            end)
        end
    end)
    icon.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input==dragInput then update(input) end
    end)
end
icon.MouseButton1Click:Connect(function() frame.Visible=true; icon.Visible=false end)
minimize.MouseButton1Click:Connect(function() frame.Visible=false; icon.Visible=true; saveCfg() end)

-- Make panel draggable by title
do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset + delta.X, frame.Position.Y.Scale, frame.Position.Y.Offset + delta.Y)
        CFG.ui.x, CFG.ui.y = frame.Position.X.Scale, frame.Position.Y.Scale
    end
    title.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=frame.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false; saveCfg() end
            end)
        end
    end)
    title.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UIS.InputChanged:Connect(function(input) if dragging and input==dragInput then update(input) end end)
end

-- Helpers
local function mkLabel(text, y)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.Gotham
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(200,200,200)
    l.Position = UDim2.fromOffset(16, y)
    l.Size = UDim2.fromOffset(380, 20)
    l.Parent = frame
    return l
end

-- Enable toggle
mkLabel("Enable Fish Catch Notifications", 44)
local toggle = Instance.new("TextButton")
toggle.Text = CFG.enable and "ON" or "OFF"
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.TextColor3 = Color3.new(1,1,1)
toggle.Size = UDim2.fromOffset(80,28)
toggle.Position = UDim2.fromOffset(16, 66)
toggle.BackgroundColor3 = CFG.enable and Color3.fromRGB(65,160,90) or Color3.fromRGB(60,60,60)
toggle.Parent = frame
mkCorner(toggle, 8)
toggle.MouseButton1Click:Connect(function()
    CFG.enable = not CFG.enable
    toggle.Text = CFG.enable and "ON" or "OFF"
    toggle.BackgroundColor3 = CFG.enable and Color3.fromRGB(65,160,90) or Color3.fromRGB(60,60,60)
    saveCfg()
end)

-- Tier buttons
mkLabel("Notify for Tiers (None = Legendary+)", 104)
local tierNames = {"Legendary","Mythic","SECRET"}
for i,name in ipairs(tierNames) do
    local b = Instance.new("TextButton")
    b.Text = name
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.TextColor3 = Color3.new(1,1,1)
    b.Size = UDim2.fromOffset(120,28)
    b.Position = UDim2.fromOffset(16 + (i-1)*130, 126)
    b.BackgroundColor3 = (CFG.tiers[name] and Color3.fromRGB(65,160,90)) or Color3.fromRGB(55,55,55)
    b.Parent = frame
    mkCorner(b, 8)
    b.MouseButton1Click:Connect(function()
        CFG.tiers[name] = not CFG.tiers[name]
        b.BackgroundColor3 = (CFG.tiers[name] and Color3.fromRGB(65,160,90)) or Color3.fromRGB(55,55,55)
        saveCfg()
    end)
end

-- Webhook URL
mkLabel("Custom Webhook URL", 164)
local urlBox = Instance.new("TextBox")
urlBox.PlaceholderText = "https://discord.com/api/webhooks/..."
urlBox.Text = CFG.webhook or ""
urlBox.TextColor3 = Color3.new(1,1,1)
urlBox.Font = Enum.Font.Gotham
urlBox.TextSize = 14
urlBox.TextXAlignment = Enum.TextXAlignment.Left
urlBox.ClearTextOnFocus = false
urlBox.BackgroundColor3 = Color3.fromRGB(35,38,45)
urlBox.Size = UDim2.fromOffset(388,30)
urlBox.Position = UDim2.fromOffset(16, 186)
urlBox.Parent = frame
mkCorner(urlBox, 8)
urlBox.FocusLost:Connect(function() CFG.webhook = urlBox.Text; saveCfg() end)

-- Discord User ID
mkLabel("Discord User ID (optional)", 220)
local idBox = Instance.new("TextBox")
idBox.PlaceholderText = "e.g. 123456789012345678"
idBox.Text = CFG.discordUserId or ""
idBox.TextColor3 = Color3.new(1,1,1)
idBox.Font = Enum.Font.Gotham
idBox.TextSize = 14
idBox.TextXAlignment = Enum.TextXAlignment.Left
idBox.ClearTextOnFocus = false
idBox.BackgroundColor3 = Color3.fromRGB(35,38,45)
idBox.Size = UDim2.fromOffset(388,30)
idBox.Position = UDim2.fromOffset(16, 242)
idBox.Parent = frame
mkCorner(idBox, 8)
idBox.FocusLost:Connect(function() CFG.discordUserId = idBox.Text; saveCfg() end)

-- Test Send button
local testBtn = Instance.new("TextButton")
testBtn.Text = "Test Send"
testBtn.Font = Enum.Font.GothamBold
testBtn.TextSize = 14
testBtn.TextColor3 = Color3.new(1,1,1)
testBtn.Size = UDim2.fromOffset(120, 30)
testBtn.Position = UDim2.fromOffset(284, 282)
testBtn.BackgroundColor3 = Color3.fromRGB(70,110,200)
testBtn.Parent = frame
mkCorner(testBtn, 8)

testBtn.MouseButton1Click:Connect(function()
    statusL.TextColor3 = Color3.fromRGB(200,200,120)
    statusL.Text = "Testing..."
    local ok, err = sendTest()
    if ok then
        statusL.TextColor3 = Color3.fromRGB(120,220,120)
        statusL.Text = "✅ Test sent"
        print("[fishit] Test sent ✅")
    else
        statusL.TextColor3 = Color3.fromRGB(220,120,120)
        statusL.Text = "❌ "..tostring(err)
        warn("[fishit] Test failed ❌", err)
    end
    task.delay(3, function() statusL.Text = "" end)
end)

print("[fishit] Webhook notifier loaded. Isi Webhook URL, klik Test Send untuk debug, lalu ON-kan toggle. Minimize → ikon muncul & bisa di-drag.")
