--[[
   FishShit Notifier (revamped UI)
   - Draggable window
   - Minimize to bubble & restore
   - Test Webhook uses Robot Kraken sample (with fish icon)
   - Fallback parent to gethui/CoreGui, request() preferred for Discord
]]--

--// Services
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")

local LP  = Players.LocalPlayer
local PG  = LP:FindFirstChildOfClass("PlayerGui")

--// Helpers
local function prefer_ui_parent()
    return (gethui and gethui()) or game:FindFirstChildOfClass("CoreGui") or PG
end

local function http_post_json(url, json)
    if typeof(request) == "function" then
        local ok, res = pcall(function()
            return request({
                Url = url, Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = json
            })
        end)
        if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then
            return true, res.Body
        end
        return false, (res and (res.StatusMessage or res.StatusCode)) or "request() failed"
    end
    -- Fallback (sering diblok Discord)
    local ok, body = pcall(function()
        return HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson)
    end)
    return ok, body
end

local function fmt_int(n)
    local s = tostring(math.floor(n))
    local k
    while true do
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

local function asset_to_url(idOrStr)
    local id = tostring(idOrStr):match("%d+") or tostring(idOrStr)
    return "https://assetdelivery.roblox.com/v1/asset/?id="..id
end

--// Config
local Config = {
    WebhookURL    = "",
    UserID        = "",
    SelectedTiers = {5,6,7}, -- default: Legendary+Mythic+SECRET
    Enabled       = true,
    RetryAttempts = 8,
    RetryDelay    = 2,
}

local TierNames = {
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "SECRET",
}

--// GUI BUILD
local GUI = {}
do
    local parentUi = prefer_ui_parent()

    local sg = Instance.new("ScreenGui")
    sg.Name = "FishShitNotifier"
    sg.ResetOnSpawn = false
    sg.Parent = parentUi

    -- MAIN WINDOW
    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.fromOffset(420, 520)
    win.Position = UDim2.new(0.5, -210, 0.5, -260)
    win.BackgroundColor3 = Color3.fromRGB(38,40,56)
    win.BorderSizePixel = 0
    win.Parent = sg

    local winCorner = Instance.new("UICorner", win)
    winCorner.CornerRadius = UDim.new(0, 14)

    local shadow = Instance.new("ImageLabel", win) -- soft shadow look
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5028857084"
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(24,24,276,276)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -10)
    shadow.ImageTransparency = 0.4
    shadow.ZIndex = 0

    -- TITLE BAR
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,56)
    bar.BackgroundColor3 = Color3.fromRGB(54,57,79)
    bar.BorderSizePixel = 0
    bar.Parent = win
    local barCorner = Instance.new("UICorner", bar)
    barCorner.CornerRadius = UDim.new(0,14)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1,-120,1,0)
    title.Position = UDim2.fromOffset(16,0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Text = "FishShit Notifier"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Parent = bar

    -- Minimize button
    local mini = Instance.new("TextButton")
    mini.Size = UDim2.fromOffset(28,28)
    mini.Position = UDim2.new(1,-70,0,14)
    mini.BackgroundColor3 = Color3.fromRGB(80,180,255)
    mini.Text = "–"
    mini.TextScaled = true
    mini.Font = Enum.Font.GothamBold
    mini.TextColor3 = Color3.new(1,1,1)
    mini.AutoButtonColor = true
    mini.Parent = bar
    Instance.new("UICorner", mini).CornerRadius = UDim.new(0,8)

    -- Close button
    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(28,28)
    close.Position = UDim2.new(1,-36,0,14)
    close.BackgroundColor3 = Color3.fromRGB(255,95,95)
    close.Text = "✕"
    close.TextScaled = true
    close.Font = Enum.Font.GothamBold
    close.TextColor3 = Color3.new(1,1,1)
    close.Parent = bar
    Instance.new("UICorner", close).CornerRadius = UDim.new(0,8)

    -- CONTENT
    local y = 70
    local function label(text)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Position = UDim2.fromOffset(16, y)
        l.Size = UDim2.new(1,-32,0,22)
        l.Font = Enum.Font.Gotham
        l.TextSize = 14
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(210,210,220)
        l.Text = text
        l.Parent = win
        y += 25
        return l
    end
    local function textbox(ph)
        local t = Instance.new("TextBox")
        t.Position = UDim2.fromOffset(16, y)
        t.Size = UDim2.new(1,-32,0,36)
        t.BackgroundColor3 = Color3.fromRGB(30,32,46)
        t.BorderSizePixel = 0
        t.Text = ""
        t.PlaceholderText = ph
        t.TextColor3 = Color3.fromRGB(255,255,255)
        t.PlaceholderColor3 = Color3.fromRGB(160,160,170)
        t.Font = Enum.Font.Gotham
        t.TextSize = 12
        t.Parent = win
        Instance.new("UICorner", t).CornerRadius = UDim.new(0,8)
        y += 46
        return t
    end

    label("Discord Webhook URL")
    local tbWebhook = textbox("Enter your Discord webhook URL...")

    label("Discord User ID (Optional)")
    local tbUserId = textbox("Enter your Discord User ID...")

    label("Select Tiers to Notify")
    local dd = Instance.new("Frame")
    dd.Position = UDim2.fromOffset(16,y)
    dd.Size = UDim2.new(1,-32,0,36)
    dd.BackgroundColor3 = Color3.fromRGB(30,32,46)
    dd.BorderSizePixel = 0
    dd.Parent = win
    Instance.new("UICorner", dd).CornerRadius = UDim.new(0,8)
    y += 46

    local ddText = Instance.new("TextLabel")
    ddText.BackgroundTransparency = 1
    ddText.Size = UDim2.new(1,-26,1,0)
    ddText.Position = UDim2.fromOffset(10,0)
    ddText.TextXAlignment = Enum.TextXAlignment.Left
    ddText.Font = Enum.Font.Gotham
    ddText.TextSize = 12
    ddText.TextColor3 = Color3.fromRGB(255,255,255)
    ddText.Text = "Legendary + Mythic + SECRET"
    ddText.Parent = dd

    local ddArrow = Instance.new("TextLabel")
    ddArrow.BackgroundTransparency = 1
    ddArrow.Size = UDim2.fromOffset(18,36)
    ddArrow.Position = UDim2.new(1,-22,0,0)
    ddArrow.Text = "▼"
    ddArrow.Font = Enum.Font.Gotham
    ddArrow.TextSize = 12
    ddArrow.TextColor3 = Color3.fromRGB(200,200,210)
    ddArrow.Parent = dd

    local ddList = Instance.new("Frame")
    ddList.Visible = false
    ddList.Position = UDim2.new(0,0,1,6)
    ddList.Size = UDim2.new(1,0,0,120)
    ddList.BackgroundColor3 = Color3.fromRGB(30,32,46)
    ddList.BorderSizePixel = 0
    ddList.Parent = dd
    Instance.new("UICorner", ddList).CornerRadius = UDim.new(0,8)

    local options = {
        {"Legendary Only", {5}},
        {"Mythic Only",    {6}},
        {"SECRET Only",    {7}},
        {"Legendary + Mythic + SECRET", {5,6,7}}
    }
    for i, opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,-10,0,24)
        b.Position = UDim2.fromOffset(5,(i-1)*28+6)
        b.BackgroundColor3 = Color3.fromRGB(45,48,66)
        b.BorderSizePixel = 0
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Text = "  "..opt[1]
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Parent = ddList
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        b.MouseButton1Click:Connect(function()
            Config.SelectedTiers = opt[2]
            ddText.Text = opt[1]
            ddList.Visible = false
        end)
    end

    local ddBtn = Instance.new("TextButton")
    ddBtn.BackgroundTransparency = 1
    ddBtn.Text = ""
    ddBtn.Size = UDim2.fromScale(1,1)
    ddBtn.Parent = dd
    ddBtn.MouseButton1Click:Connect(function()
        ddList.Visible = not ddList.Visible
    end)

    label("Enable Fish Catch Notifications")
    local toggle = Instance.new("Frame")
    toggle.Position = UDim2.fromOffset(16,y)
    toggle.Size = UDim2.fromOffset(64,30)
    toggle.BackgroundColor3 = Color3.fromRGB(110,110,120)
    toggle.BorderSizePixel = 0
    toggle.Parent = win
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,16)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(26,26)
    knob.Position = UDim2.fromOffset(2,2)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0,13)

    y += 46

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(16,y-6)
    status.Size = UDim2.new(1,-32,0,22)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = "Status: Active - Monitoring chat..."
    status.TextColor3 = Color3.fromRGB(110,255,140)
    status.Parent = win

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(1,-32,0,42)
    testBtn.Position = UDim2.fromOffset(16,y+24)
    testBtn.BackgroundColor3 = Color3.fromRGB(95,135,255)
    testBtn.BorderSizePixel = 0
    testBtn.Text = "Test Webhook (Robot Kraken)"
    testBtn.TextColor3 = Color3.new(1,1,1)
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 14
    testBtn.Parent = win
    Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0,8)

    -- Bubble (minimized)
    local bubble = Instance.new("TextButton")
    bubble.Visible = false
    bubble.Name = "Bubble"
    bubble.Size = UDim2.fromOffset(56,56)
    bubble.Position = UDim2.new(0.5,-28,0.2,0)
    bubble.BackgroundColor3 = Color3.fromRGB(54,57,79)
    bubble.Text = "🐟"
    bubble.TextScaled = true
    bubble.Font = Enum.Font.GothamBold
    bubble.TextColor3 = Color3.new(1,1,1)
    bubble.Parent = sg
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(1,0)

    -- Bindings
    tbWebhook.FocusLost:Connect(function()
        Config.WebhookURL = tbWebhook.Text
    end)
    tbUserId.FocusLost:Connect(function()
        Config.UserID = tbUserId.Text
    end)

    local function setEnabled(on)
        Config.Enabled = on
        if on then
            toggle.BackgroundColor3 = Color3.fromRGB(90,205,120)
            TweenService:Create(knob, TweenInfo.new(0.25), {Position = UDim2.fromOffset(36,2)}):Play()
            status.Text = "Status: Active - Monitoring chat..."
            status.TextColor3 = Color3.fromRGB(110,255,140)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(110,110,120)
            TweenService:Create(knob, TweenInfo.new(0.25), {Position = UDim2.fromOffset(2,2)}):Play()
            status.Text = "Status: Disabled"
            status.TextColor3 = Color3.fromRGB(255,120,120)
        end
    end
    setEnabled(Config.Enabled)

    local toggleBtn = Instance.new("TextButton", toggle)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Size = UDim2.fromScale(1,1)
    toggleBtn.Text = ""
    toggleBtn.MouseButton1Click:Connect(function()
        setEnabled(not Config.Enabled)
    end)

    close.MouseButton1Click:Connect(function() sg:Destroy() end)

    local function minimize(toBubble)
        if toBubble then
            win.Visible = false
            bubble.Visible = true
        else
            bubble.Visible = false
            win.Visible = true
        end
    end
    mini.MouseButton1Click:Connect(function() minimize(true) end)
    bubble.MouseButton1Click:Connect(function() minimize(false) end)

    -- Drag window
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Drag bubble
    local bdrag, bStart, bPos
    bubble.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            bdrag = true; bStart = i.Position; bPos = bubble.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if bdrag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - bStart
            bubble.Position = UDim2.new(bPos.X.Scale, bPos.X.Offset + d.X, bPos.Y.Scale, bPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then bdrag = false end
    end)

    GUI.ScreenGui     = sg
    GUI.Window        = win
    GUI.Status        = status
    GUI.WebhookInput  = tbWebhook
    GUI.UserIdInput   = tbUserId
    GUI.MinimizeBtn   = mini
    GUI.Bubble        = bubble
    GUI.SetEnabled    = setEnabled
end

--// Game fish data helpers
local function getFishModule(name)
    local ok, mod = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Items")
        return folder and folder:FindFirstChild(name)
    end)
    if not ok or not mod then return nil end
    local ok2, data = pcall(function() return require(mod) end)
    return ok2 and data or nil
end

local function tier_name(n) return TierNames[n] or tostring(n) end

--// Webhook
local function send_webhook(embedData, retry)
    retry = retry or 0
    if Config.WebhookURL == "" then
        GUI.Status.Text = "Status: Error - Webhook URL empty"
        GUI.Status.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end
    local payload = {
        username   = "FishShit",
        avatar_url = "https://i.imgur.com/7J6Nf8h.png", -- optional: small fish avatar; change if mau
        content    = (Config.UserID ~= "" and ("<@"..Config.UserID..">") or ""),
        embeds     = {embedData},
    }
    local json = HttpService:JSONEncode(payload)
    local ok = http_post_json(Config.WebhookURL, json)
    if ok then
        GUI.Status.Text = "Status: Webhook sent successfully!"
        GUI.Status.TextColor3 = Color3.fromRGB(110,255,140)
    else
        if retry < Config.RetryAttempts then
            GUI.Status.Text = ("Status: Retrying... (%d/%d)"):format(retry+1, Config.RetryAttempts)
            GUI.Status.TextColor3 = Color3.fromRGB(255,230,120)
            task.wait(Config.RetryDelay)
            return send_webhook(embedData, retry+1)
        else
            GUI.Status.Text = "Status: Failed to send."
            GUI.Status.TextColor3 = Color3.fromRGB(255,120,120)
        end
    end
end

local function build_embed(data)
    -- data: {playerName, fishName, weightStr, tierNumber, sellPrice, iconUrl, rarityStr}
    local color = 0x20C997 -- greenish
    local embed = {
        title = ("A high-tier fish was caught by %s!"):format(data.playerName),
        description = "",
        color = color,
        fields = {
            {name = "Fish Name 🐟", value = ("**%s**"):format(data.fishName), inline = false},
            {name = "Weight ⚖️",   value = data.weightStr, inline = true},
            {name = "Rarity ✨",    value = data.rarityStr, inline = true},
            {name = "Tier 🏆",      value = tier_name(data.tierNumber), inline = true},
            {name = "Sell Price 🪙",value = fmt_int(data.sellPrice), inline = true},
        },
        thumbnail = { url = data.iconUrl },
        footer = { text = "FishShit Notifier • "..os.date("%X") },
    }
    return embed
end

--// TEST WEBHOOK: Robot Kraken sample
local function test_robotkraken()
    -- From your snippet:
    local robot = {
        Name  = "Robot Kraken",
        Icon  = "rbxassetid://80927639907406",
        Tier  = 7,
        SellPrice = 327500,
        WeightDefaultMin = 259820,
        WeightDefaultMax = 389730,
        Chance = 2.857142857142857e-07, -- ≈ 1 in 3,500,000
    }
    local weight = math.random(robot.WeightDefaultMin, robot.WeightDefaultMax) / 100 -- turn to e.g. 1234.56?
    -- The game's formatting in your screenshots seems kg with decimals:
    local weightStr = string.format("%.2f kg", weight/10) -- tweak feel
    local rarityIn = math.max(1, math.floor(1/robot.Chance + 0.5))
    local rarityStr = ("1 in %s"):format(fmt_int(rarityIn))
    local iconUrl = asset_to_url(robot.Icon)

    local embed = build_embed({
        playerName = LP.DisplayName or LP.Name,
        fishName   = robot.Name,
        weightStr  = weightStr,
        tierNumber = robot.Tier,
        sellPrice  = robot.SellPrice,
        iconUrl    = iconUrl,
        rarityStr  = rarityStr,
    })
    send_webhook(embed)
end

-- Hook Test button
do
    local testBtn = GUI.Window:FindFirstChildOfClass("TextButton")
    -- our test button is the LAST one we created under window; safer search by text
    for _,v in ipairs(GUI.Window:GetChildren()) do
        if v:IsA("TextButton") and v.Text:find("Test Webhook") then
            testBtn = v
        end
    end
    if testBtn then
        testBtn.MouseButton1Click:Connect(function()
            GUI.Status.Text = "Status: Testing Robot Kraken..."
            GUI.Status.TextColor3 = Color3.fromRGB(255,230,120)
            test_robotkraken()
        end)
    end
end

-- =========================================================
--  CHAT MONITOR (tetap seperti sebelumnya, kirim kalau tier match)
-- =========================================================

local function getFishDataByName(name)
    local data = getFishModule(name)
    if not data then return nil end
    -- normalize repo module format
    local icon = data.Data and data.Data.Icon or data.Icon or data.icon or data.DataIcon
    local tier = (data.Data and data.Data.Tier) or data.Tier or 0
    local sp   = data.SellPrice or 0
    return {
        name = (data.Data and data.Data.Name) or name,
        icon = icon,
        tier = tier,
        sell = sp,
    }
end

local function should_notify(tierNum)
    for _,t in ipairs(Config.SelectedTiers) do
        if t == tierNum then return true end
    end
    return false
end

local function parse_fish_message(msg)
    -- Example: [Server]: aomine obtained a Big Deep Sea Crab (1.78K kg) with a 1 in 5K chance!
    local pName, fishName, weight, rare = msg:match("%[Server%]: (.+) obtained a (.+) %((.+)%) with a 1 in (.+) chance!")
    if pName and fishName and weight and rare then
        return pName, fishName, weight, ("1 in "..rare)
    end
end

local function process_msg(pName, fishName, weightStr, rarityStr)
    local fish = getFishDataByName(fishName)
    if not fish then return end
    if not should_notify(fish.tier) then return end
    local embed = build_embed({
        playerName = pName,
        fishName   = fish.name,
        weightStr  = weightStr,
        tierNumber = fish.tier,
        sellPrice  = fish.sell,
        iconUrl    = asset_to_url(fish.icon or ""),
        rarityStr  = rarityStr,
    })
    send_webhook(embed)
end

local function monitor_chat()
    -- try modern message labels in Classic Chat
    task.spawn(function()
        local ok, chatGui = pcall(function() return PG:WaitForChild("Chat", 8) end)
        if not ok or not chatGui then return end
        local frame = chatGui:WaitForChild("Frame", 5)
        if not frame then return end
        local log = frame:WaitForChild("ChatChannelParentFrame", 5)
        log = log and log:WaitForChild("Frame_MessageLogDisplay", 5)
        log = log and log:WaitForChild("Scroller", 5)
        if not log then return end

        log.ChildAdded:Connect(function(child)
            if not Config.Enabled then return end
            task.wait(0.1)
            local lbl = child:FindFirstChild("TextLabel")
            if lbl and lbl.Text then
                local pName, fishName, w, r = parse_fish_message(lbl.Text)
                if pName then process_msg(pName, fishName, w, r) end
            end
        end)
    end)
end

monitor_chat()
print("[FishShit] Notifier loaded ✔  Drag the window, click – to minimize (bubble), click bubble to restore.")
