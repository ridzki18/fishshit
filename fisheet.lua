--[[
   FishShit Notifier (v3, uses external fish list)
   - Source of truth for fish Icon/Tier/Probability: list.lua (GitHub raw)
   - Icon via Roblox Thumbnail API (works on Discord)
   - Embed pills, pretty console log, draggable + minimize bubble
   - Test Webhook: Robot Kraken
]]--

-- ====== CONFIG: daftar ikan kamu ======
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"
-- ======================================

--// Services
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")

local LP  = Players.LocalPlayer
local PG  = LP:FindFirstChildOfClass("PlayerGui")

--// Utils
local function prefer_ui_parent()
    return (gethui and gethui()) or game:FindFirstChildOfClass("CoreGui") or PG
end

local function fmt_int(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local k
    while true do
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

-- public thumbnail (works in Discord)
local function asset_to_thumb_url(idOrStr, w, h)
    local id = tostring(idOrStr or ""):match("%d+") or tostring(idOrStr or "")
    if id == "" then return "https://tr.rbxcdn.com/8e8f9a6b6f9fe4d2b8f/352/352/Image/Png" end -- tiny fallback
    w, h = w or 420, h or 420
    return ("https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=%d&height=%d&format=png"):format(id, w, h)
end

local function pill(v) return ("`%s`"):format(tostring(v)) end

local function http_post_json(url, json)
    if typeof(request) == "function" then
        local ok, res = pcall(function()
            return request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=json })
        end)
        if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then
            return true, res.Body
        end
        return false, (res and (res.StatusMessage or res.StatusCode)) or "request() failed"
    end
    local ok, body = pcall(function()
        return HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson)
    end)
    return ok, body
end

-- =========================================================
--  CONFIG
-- =========================================================
local Config = {
    WebhookURL    = "",
    UserID        = "",
    SelectedTiers = {5,6,7}, -- Legendary+Mythic+SECRET
    Enabled       = true,
    RetryAttempts = 8,
    RetryDelay    = 2,
}

local TierNames = { [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary", [6]="Mythic", [7]="SECRET" }
local function tier_name(n) return TierNames[tonumber(n) or n] or tostring(n) end

-- =========================================================
--  FISH LIST (GitHub raw) + FALLBACK
-- =========================================================
local FishMap -- cache

local function load_fish_map()
    if FishMap then return FishMap end
    local ok, body = pcall(function() return game:HttpGet(FISH_LIST_URL) end)
    if not ok or not body or #body < 10 then
        warn("[FishShit] Gagal memuat fish list dari URL → fallback Items/")
        FishMap = {}
        return FishMap
    end
    local chunk, err = loadstring(body)
    if not chunk then
        warn("[FishShit] parse fish list error: ", err)
        FishMap = {}
        return FishMap
    end
    local ok2, tbl = pcall(chunk)
    if not ok2 or type(tbl) ~= "table" then
        warn("[FishShit] fish list bukan table Lua yang valid")
        FishMap = {}
        return FishMap
    end
    FishMap = tbl
    return FishMap
end

local function get_game_module_data(name)
    local ok, mod = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Items")
        return folder and folder:FindFirstChild(name)
    end)
    if not ok or not mod then return nil end
    local ok2, data = pcall(function() return require(mod) end)
    if not ok2 or not data then return nil end
    return {
        name = (data.Data and data.Data.Name) or name,
        icon = (data.Data and data.Data.Icon) or data.Icon or "",
        tier = (data.Data and data.Data.Tier) or data.Tier or 0,
        sell = data.SellPrice or 0,
        prob = (data.Probability and data.Probability.Chance) or nil,
    }
end

local function getFishDataByName(name)
    local map = load_fish_map()
    local rec = map[name]
    if rec then
        return {
            name = name,
            icon = rec.Icon or "",
            tier = tonumber(rec.Tier) or rec.Tier,
            sell = tonumber(rec.SellPrice or 0) or 0,
            prob = tonumber(rec.Probability or rec.Chance or 0) or nil,
        }
    end
    return get_game_module_data(name)
end

local function prob_to_rarity_str(p)
    if not p or p <= 0 then return nil end
    local x = math.max(1, math.floor(1/p + 0.5))
    return "1 in "..fmt_int(x)
end

-- =========================================================
--  UI
-- =========================================================
local GUI = {}
do
    local parentUi = prefer_ui_parent()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FishShitNotifier"
    sg.ResetOnSpawn = false
    sg.Parent = parentUi

    local win = Instance.new("Frame")
    win.Size = UDim2.fromOffset(420, 520)
    win.Position = UDim2.new(0.5, -210, 0.5, -260)
    win.BackgroundColor3 = Color3.fromRGB(38,40,56)
    win.BorderSizePixel = 0
    win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0,14)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,56)
    bar.BackgroundColor3 = Color3.fromRGB(54,57,79)
    bar.BorderSizePixel = 0
    bar.Parent = win
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,14)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(16,0)
    title.Size = UDim2.new(1,-120,1,0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "FishShit Notifier"
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = bar

    local mini = Instance.new("TextButton")
    mini.Size = UDim2.fromOffset(28,28)
    mini.Position = UDim2.new(1,-70,0,14)
    mini.BackgroundColor3 = Color3.fromRGB(80,180,255)
    mini.Text = "–"
    mini.TextScaled = true
    mini.Font = Enum.Font.GothamBold
    mini.TextColor3 = Color3.new(1,1,1)
    mini.Parent = bar
    Instance.new("UICorner", mini).CornerRadius = UDim.new(0,8)

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

    local y = 70
    local function label(t)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Position = UDim2.fromOffset(16,y)
        l.Size = UDim2.new(1,-32,0,22)
        l.Font = Enum.Font.Gotham
        l.TextSize = 14
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(210,210,220)
        l.Text = t
        l.Parent = win
        y += 25
        return l
    end
    local function textbox(ph)
        local t = Instance.new("TextBox")
        t.Position = UDim2.fromOffset(16,y)
        t.Size = UDim2.new(1,-32,0,36)
        t.BackgroundColor3 = Color3.fromRGB(30,32,46)
        t.BorderSizePixel = 0
        t.Text = ""
        t.PlaceholderText = ph
        t.TextColor3 = Color3.new(1,1,1)
        t.PlaceholderColor3 = Color3.fromRGB(160,160,170)
        t.Font = Enum.Font.Gotham
        t.TextSize = 12
        t.Parent = win
        Instance.new("UICorner", t).CornerRadius = UDim.new(0,8)
        y += 46
        return t
    end

    label("Discord Webhook URL"); local tbWebhook = textbox("Enter your Discord webhook URL...")
    label("Discord User ID (Optional)"); local tbUserId = textbox("Enter your Discord User ID...")

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
    ddText.TextColor3 = Color3.new(1,1,1)
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
    for i,opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,-10,0,24)
        b.Position = UDim2.fromOffset(5,(i-1)*28+6)
        b.BackgroundColor3 = Color3.fromRGB(45,48,66)
        b.BorderSizePixel = 0
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Text = "  "..opt[1]
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextColor3 = Color3.new(1,1,1)
        b.Parent = ddList
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        b.MouseButton1Click:Connect(function()
            Config.SelectedTiers = opt[2]; ddText.Text = opt[1]; ddList.Visible = false
        end)
    end
    local ddBtn = Instance.new("TextButton", dd)
    ddBtn.BackgroundTransparency = 1; ddBtn.Size = UDim2.fromScale(1,1); ddBtn.Text = ""
    ddBtn.MouseButton1Click:Connect(function() ddList.Visible = not ddList.Visible end)

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

    -- bubble
    local bubble = Instance.new("TextButton")
    bubble.Visible = false
    bubble.Size = UDim2.fromOffset(56,56)
    bubble.Position = UDim2.new(0.5,-28,0.2,0)
    bubble.BackgroundColor3 = Color3.fromRGB(54,57,79)
    bubble.Text = "🐟"
    bubble.TextScaled = true
    bubble.Font = Enum.Font.GothamBold
    bubble.TextColor3 = Color3.new(1,1,1)
    bubble.Parent = sg
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(1,0)

    tbWebhook.FocusLost:Connect(function() Config.WebhookURL = tbWebhook.Text end)
    tbUserId.FocusLost:Connect(function() Config.UserID = tbUserId.Text end)

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
    setEnabled(true)

    local tBtn = Instance.new("TextButton", toggle)
    tBtn.BackgroundTransparency = 1; tBtn.Size = UDim2.fromScale(1,1); tBtn.Text = ""
    tBtn.MouseButton1Click:Connect(function() setEnabled(not Config.Enabled) end)

    close.MouseButton1Click:Connect(function() sg:Destroy() end)
    local function minimize(toBubble) win.Visible = not toBubble; bubble.Visible = toBubble end
    mini.MouseButton1Click:Connect(function() minimize(true) end)
    bubble.MouseButton1Click:Connect(function() minimize(false) end)

    -- drag window
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- drag bubble
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

    GUI.ScreenGui  = sg
    GUI.Window     = win
    GUI.Status     = status
    GUI.TestButton = testBtn
end

-- =========================================================
--  CONSOLE LOG (pretty)
-- =========================================================
local function console_box(info)
    local lines = {}
    local function add(s) table.insert(lines, s) end
    local function pad(s, n) s = tostring(s); if #s < n then s = s .. string.rep(" ", n-#s) end; return s end
    add("+---------------------------------------------------------------+")
    add("| FishShit → Webhook Payload                                    |")
    add("+----------------------+----------------------------------------+")
    add("| Player               | "..pad(info.player, 38).."|")
    add("| Fish                 | "..pad(info.fish,   38).."|")
    add("| Weight               | "..pad(info.weight, 38).."|")
    add("| Rarity               | "..pad(info.rarity, 38).."|")
    add("| Tier                 | "..pad(info.tier,   38).."|")
    add("| Sell Price           | "..pad(info.price,  38).."|")
    if info.totalCaught then add("| Total Caught         | "..pad(info.totalCaught,38).."|") end
    if info.bagSize    then add("| Bag Size             | "..pad(info.bagSize,   38).."|") end
    add("+---------------------------------------------------------------+")
    print(table.concat(lines, "\n"))
end

-- =========================================================
--  WEBHOOK
-- =========================================================
local function build_embed(data)
    local fields = {
        {name = "Fish Name 🐟", value = "**"..data.fishName.."**", inline = false},
        {name = "Weight ⚖️",   value = pill(data.weightStr), inline = true},
        {name = "Rarity ✨",    value = pill(data.rarityStr), inline = true},
        {name = "Tier 🏆",      value = pill(tier_name(data.tierNumber)), inline = true},
        {name = "Sell Price 🪙",value = pill(fmt_int(data.sellPrice)), inline = true},
    }
    if data.totalCaught then table.insert(fields, {name="Total Caught 🐟", value=pill(fmt_int(data.totalCaught)), inline=true}) end
    if data.bagSize    then table.insert(fields, {name="Bag Size 🧺",     value=pill(data.bagSize), inline=true}) end
    return {
        title      = ("A high-tier fish was caught by %s!"):format(data.playerName),
        color      = 0x20C997,
        fields     = fields,
        thumbnail  = { url = data.iconUrl },
        footer     = { text = "FishShit Notifier • "..os.date("%X") },
    }
end

local function send_webhook(embedData)
    if Config.WebhookURL == "" then
        GUI.Status.Text = "Status: Error - Webhook URL empty"
        GUI.Status.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end
    local payload = {
        username = "FishShit",
        content  = (Config.UserID ~= "" and ("<@"..Config.UserID..">") or ""),
        embeds   = {embedData},
    }
    local json = HttpService:JSONEncode(payload)
    local ok = http_post_json(Config.WebhookURL, json)
    if ok then
        GUI.Status.Text = "Status: Webhook sent successfully!"
        GUI.Status.TextColor3 = Color3.fromRGB(110,255,140)
    else
        GUI.Status.Text = "Status: Failed to send."
        GUI.Status.TextColor3 = Color3.fromRGB(255,120,120)
    end
end

-- =========================================================
--  TEST WEBHOOK (Robot Kraken)
-- =========================================================
GUI.TestButton.MouseButton1Click:Connect(function()
    GUI.Status.Text = "Status: Testing Robot Kraken..."
    GUI.Status.TextColor3 = Color3.fromRGB(255,230,120)

    local robot = {
        Name  = "Robot Kraken",
        Icon  = "rbxassetid://80927639907406",
        Tier  = 7,
        SellPrice = 327500,
        WeightDefaultMin = 259820,
        WeightDefaultMax = 389730,
        Chance = 2.857142857142857e-07, -- ≈ 1 in 3,500,000
    }
    local weight = math.random(robot.WeightDefaultMin, robot.WeightDefaultMax) / 1000
    local weightStr = string.format("%.2f kg", weight)
    local rarityStr = "1 in "..fmt_int(math.max(1, math.floor(1/robot.Chance + 0.5)))
    local iconUrl = asset_to_thumb_url(robot.Icon)

    local embed = build_embed({
        playerName = LP.DisplayName or LP.Name,
        fishName   = robot.Name,
        weightStr  = weightStr,
        rarityStr  = rarityStr,
        tierNumber = robot.Tier,
        sellPrice  = robot.SellPrice,
        iconUrl    = iconUrl,
        totalCaught= nil,
        bagSize    = nil,
    })

    console_box({
        player = LP.DisplayName or LP.Name,
        fish   = robot.Name,
        weight = weightStr,
        rarity = rarityStr,
        tier   = tier_name(robot.Tier),
        price  = fmt_int(robot.SellPrice),
    })

    send_webhook(embed)
end)

-- =========================================================
--  LIVE CHAT MONITOR
-- =========================================================
local function should_notify(tierNum)
    for _,t in ipairs(Config.SelectedTiers) do if t==tierNum then return true end end
    return false
end

local function parse_fish_message(msg)
    -- [Server]: name obtained a Fish (1.23 kg) with a 1 in 5K chance!
    local pName, fishName, weight, rare = msg:match("%[Server%]: (.+) obtained a (.+) %((.+)%) with a 1 in (.+) chance!")
    if pName and fishName and weight and rare then
        return pName, fishName, weight, ("1 in "..rare)
    end
end

local function read_leaderstats_for(player)
    player = player or LP
    local stats = { totalCaught=nil, bagSize=nil }
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _,it in ipairs(ls:GetChildren()) do
            local n = it.Name:lower()
            if it.Value ~= nil then
                if n:find("total") and n:find("caught") then
                    stats.totalCaught = tonumber(it.Value)
                elseif n:find("bag") and n:find("size") then
                    stats.bagSize = tostring(it.Value)
                end
            end
        end
    end
    return stats
end

local function process_msg(pName, fishName, weightStr, rarityStrFromChat)
    local fish = getFishDataByName(fishName)
    if not fish then return end
    if not should_notify(fish.tier) then return end

    local rarityStr = rarityStrFromChat or prob_to_rarity_str(fish.prob) or "Unknown"
    local iconUrl   = asset_to_thumb_url(fish.icon or "")

    local stats = read_leaderstats_for(LP)
    local embed = build_embed({
        playerName = pName,
        fishName   = fish.name,
        weightStr  = weightStr,
        rarityStr  = rarityStr,
        tierNumber = fish.tier,
        sellPrice  = fish.sell or 0,
        iconUrl    = iconUrl,
        totalCaught= stats.totalCaught,
        bagSize    = stats.bagSize,
    })

    console_box({
        player = pName,
        fish   = fish.name,
        weight = weightStr,
        rarity = rarityStr,
        tier   = tier_name(fish.tier),
        price  = fmt_int(tonumber(fish.sell or 0)),
        totalCaught = stats.totalCaught and fmt_int(stats.totalCaught) or nil,
        bagSize = stats.bagSize
    })

    send_webhook(embed)
end

-- hook classic chat UI
task.spawn(function()
    local chatGui = PG and PG:WaitForChild("Chat", 8)
    if not chatGui then return end
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

print("[FishShit] Notifier ready ✔  (uses list.lua from GitHub for icons/tiers/probabilities)")
