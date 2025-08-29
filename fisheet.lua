--[[
   FishShit Notifier (v4, Fixed UI & Discord Output)
   - Modern UI similar to ArcvourHUB style
   - Discord webhook with proper fish icons and embed format
   - Draggable interface with smooth animations
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
local TierColors = { 
    [1] = Color3.fromRGB(155, 155, 155), -- Common - Gray
    [2] = Color3.fromRGB(30, 255, 0),    -- Uncommon - Green  
    [3] = Color3.fromRGB(0, 112, 255),   -- Rare - Blue
    [4] = Color3.fromRGB(163, 53, 238),  -- Epic - Purple
    [5] = Color3.fromRGB(255, 128, 0),   -- Legendary - Orange
    [6] = Color3.fromRGB(255, 0, 0),     -- Mythic - Red
    [7] = Color3.fromRGB(255, 215, 0)    -- SECRET - Gold
}

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
    if x >= 1000 then
        return "1 in "..string.format("%.0fK", x/1000)
    else
        return "1 in "..fmt_int(x)
    end
end

-- =========================================================
--  MODERN UI (ArcvourHUB Style)
-- =========================================================
local GUI = {}
do
    local parentUi = prefer_ui_parent()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FishShitNotifier"
    sg.ResetOnSpawn = false
    sg.Parent = parentUi

    -- Main window with modern styling
    local win = Instance.new("Frame")
    win.Size = UDim2.fromOffset(380, 480)
    win.Position = UDim2.new(0.5, -190, 0.5, -240)
    win.BackgroundColor3 = Color3.fromRGB(24, 25, 39) -- Dark purple similar to ArcvourHUB
    win.BorderSizePixel = 0
    win.Parent = sg
    
    local winCorner = Instance.new("UICorner", win)
    winCorner.CornerRadius = UDim.new(0, 12)
    
    -- Add subtle border/shadow effect
    local border = Instance.new("UIStroke", win)
    border.Color = Color3.fromRGB(60, 65, 100)
    border.Thickness = 1
    border.Transparency = 0.7

    -- Header bar
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
    header.BorderSizePixel = 0
    header.Parent = win
    
    local headerCorner = Instance.new("UICorner", header)
    headerCorner.CornerRadius = UDim.new(0, 12)
    
    -- Fix header corners to only round top
    local headerBottomCover = Instance.new("Frame")
    headerBottomCover.Size = UDim2.new(1, 0, 0, 12)
    headerBottomCover.Position = UDim2.new(0, 0, 1, -12)
    headerBottomCover.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
    headerBottomCover.BorderSizePixel = 0
    headerBottomCover.Parent = header

    -- Title with icon
    local titleIcon = Instance.new("TextLabel")
    titleIcon.BackgroundTransparency = 1
    titleIcon.Position = UDim2.fromOffset(15, 12)
    titleIcon.Size = UDim2.fromOffset(26, 26)
    titleIcon.Text = "🐟"
    titleIcon.TextScaled = true
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.TextColor3 = Color3.fromRGB(120, 180, 255)
    titleIcon.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(50, 0)
    title.Size = UDim2.new(1, -130, 1, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Fish!t"
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = header

    -- Close button (modern style)
    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(24, 24)
    close.Position = UDim2.new(1, -35, 0, 13)
    close.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
    close.Text = "×"
    close.TextScaled = true
    close.Font = Enum.Font.GothamBold
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Parent = header
    
    local closeCorner = Instance.new("UICorner", close)
    closeCorner.CornerRadius = UDim.new(1, 0)

    -- Minimize button
    local mini = Instance.new("TextButton")
    mini.Size = UDim2.fromOffset(24, 24)
    mini.Position = UDim2.new(1, -65, 0, 13)
    mini.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    mini.Text = "_"
    mini.TextScaled = true
    mini.Font = Enum.Font.GothamBold
    mini.TextColor3 = Color3.new(1, 1, 1)
    mini.Parent = header
    
    local miniCorner = Instance.new("UICorner", mini)
    miniCorner.CornerRadius = UDim.new(1, 0)

    -- Content area with scroll
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, -50)
    content.Position = UDim2.new(0, 0, 0, 50)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(120, 180, 255)
    content.CanvasSize = UDim2.fromOffset(0, 500)
    content.Parent = win

    local y = 20
    
    -- Helper function to create labels
    local function label(text, size)
        size = size or 14
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Position = UDim2.fromOffset(20, y)
        l.Size = UDim2.new(1, -40, 0, 20)
        l.Font = Enum.Font.Gotham
        l.TextSize = size
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(180, 185, 200)
        l.Text = text
        l.Parent = content
        y += 25
        return l
    end

    -- Helper function to create textboxes
    local function textbox(placeholder)
        local container = Instance.new("Frame")
        container.Position = UDim2.fromOffset(20, y)
        container.Size = UDim2.new(1, -40, 0, 36)
        container.BackgroundColor3 = Color3.fromRGB(35, 37, 56)
        container.BorderSizePixel = 0
        container.Parent = content
        
        local containerCorner = Instance.new("UICorner", container)
        containerCorner.CornerRadius = UDim.new(0, 8)
        
        local containerStroke = Instance.new("UIStroke", container)
        containerStroke.Color = Color3.fromRGB(55, 60, 85)
        containerStroke.Thickness = 1
        containerStroke.Transparency = 0.5

        local t = Instance.new("TextBox")
        t.Size = UDim2.new(1, -20, 1, 0)
        t.Position = UDim2.fromOffset(10, 0)
        t.BackgroundTransparency = 1
        t.BorderSizePixel = 0
        t.Text = ""
        t.PlaceholderText = placeholder
        t.TextColor3 = Color3.new(1, 1, 1)
        t.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
        t.Font = Enum.Font.Gotham
        t.TextSize = 12
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = container
        
        -- Focus animations
        t.Focused:Connect(function()
            TweenService:Create(containerStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(120, 180, 255),
                Transparency = 0
            }):Play()
        end)
        
        t.FocusLost:Connect(function()
            TweenService:Create(containerStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(55, 60, 85),
                Transparency = 0.5
            }):Play()
        end)
        
        y += 46
        return t
    end

    -- Webhook URL input
    label("Discord Webhook URL")
    local tbWebhook = textbox("Enter your Discord webhook URL...")

    -- User ID input  
    label("Discord User ID (Optional)")
    local tbUserId = textbox("Enter your Discord User ID...")

    -- Tier selector
    label("Select Tiers to Notify")
    label("(None = All Legendary+)", 12)
    
    local tierFrame = Instance.new("Frame")
    tierFrame.Position = UDim2.fromOffset(20, y)
    tierFrame.Size = UDim2.new(1, -40, 0, 36)
    tierFrame.BackgroundColor3 = Color3.fromRGB(35, 37, 56)
    tierFrame.BorderSizePixel = 0
    tierFrame.Parent = content
    
    local tierCorner = Instance.new("UICorner", tierFrame)
    tierCorner.CornerRadius = UDim.new(0, 8)
    
    local tierStroke = Instance.new("UIStroke", tierFrame)
    tierStroke.Color = Color3.fromRGB(55, 60, 85)
    tierStroke.Thickness = 1
    tierStroke.Transparency = 0.5

    local tierText = Instance.new("TextLabel")
    tierText.BackgroundTransparency = 1
    tierText.Size = UDim2.new(1, -35, 1, 0)
    tierText.Position = UDim2.fromOffset(12, 0)
    tierText.TextXAlignment = Enum.TextXAlignment.Left
    tierText.Font = Enum.Font.Gotham
    tierText.TextSize = 12
    tierText.TextColor3 = Color3.new(1, 1, 1)
    tierText.Text = "Legendary + Mythic + SECRET"
    tierText.Parent = tierFrame

    local tierArrow = Instance.new("TextLabel")
    tierArrow.BackgroundTransparency = 1
    tierArrow.Size = UDim2.fromOffset(20, 36)
    tierArrow.Position = UDim2.new(1, -25, 0, 0)
    tierArrow.Text = "▼"
    tierArrow.Font = Enum.Font.Gotham
    tierArrow.TextSize = 10
    tierArrow.TextColor3 = Color3.fromRGB(180, 185, 200)
    tierArrow.Parent = tierFrame

    local dropdown = Instance.new("Frame")
    dropdown.Visible = false
    dropdown.Position = UDim2.new(0, 0, 1, 4)
    dropdown.Size = UDim2.new(1, 0, 0, 140)
    dropdown.BackgroundColor3 = Color3.fromRGB(35, 37, 56)
    dropdown.BorderSizePixel = 0
    dropdown.ZIndex = 10
    dropdown.Parent = tierFrame
    
    local dropCorner = Instance.new("UICorner", dropdown)
    dropCorner.CornerRadius = UDim.new(0, 8)
    
    local dropStroke = Instance.new("UIStroke", dropdown)
    dropStroke.Color = Color3.fromRGB(55, 60, 85)
    dropStroke.Thickness = 1
    dropStroke.Transparency = 0.5

    local options = {
        {"Mythic Only", {6}},
        {"SECRET Only", {7}},
        {"Legendary + Mythic", {5,6}},
        {"Legendary + Mythic + SECRET", {5,6,7}}
    }
    
    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 28)
        btn.Position = UDim2.fromOffset(4, (i-1)*32 + 6)
        btn.BackgroundColor3 = Color3.fromRGB(40, 42, 65)
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = "   "..opt[1]
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Parent = dropdown
        
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 6)
        
        -- Hover effect
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(50, 55, 80)
            }):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(40, 42, 65)
            }):Play()
        end)
        
        btn.MouseButton1Click:Connect(function()
            Config.SelectedTiers = opt[2]
            tierText.Text = opt[1]
            dropdown.Visible = false
            TweenService:Create(tierArrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
        end)
    end

    local tierBtn = Instance.new("TextButton")
    tierBtn.BackgroundTransparency = 1
    tierBtn.Size = UDim2.fromScale(1, 1)
    tierBtn.Text = ""
    tierBtn.Parent = tierFrame
    
    tierBtn.MouseButton1Click:Connect(function()
        dropdown.Visible = not dropdown.Visible
        local rotation = dropdown.Visible and 180 or 0
        TweenService:Create(tierArrow, TweenInfo.new(0.2), {Rotation = rotation}):Play()
    end)

    y += 50

    -- Toggle switch for notifications
    label("Enable Fish Catch Notifications")
    
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Position = UDim2.fromOffset(20, y)
    toggleFrame.Size = UDim2.fromOffset(60, 28)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = content
    
    local toggleCorner = Instance.new("UICorner", toggleFrame)
    toggleCorner.CornerRadius = UDim.new(0, 14)

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.fromOffset(22, 22)
    toggleKnob.Position = UDim2.fromOffset(32, 3)
    toggleKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleFrame
    
    local knobCorner = Instance.new("UICorner", toggleKnob)
    knobCorner.CornerRadius = UDim.new(1, 0)

    y += 50

    -- Advanced Settings section (like image 4)
    label("Advanced Settings (Optional)", 16)
    y += 10
    
    -- Custom Webhook URL (optional override)
    label("Custom Webhook URL", 12)
    label("(Optional)", 10)
    local tbCustomWebhook = textbox("Enter your own Discord webhook...")
    
    y += 20

    -- Status indicator
    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.fromOffset(20, y)
    statusLabel.Size = UDim2.new(1, -40, 0, 22)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Text = "Status: Webhook sent successfully!"
    statusLabel.TextColor3 = Color3.fromRGB(110, 255, 140)
    statusLabel.Parent = content

    y += 35

    -- Test webhook button
    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(1, -40, 0, 40)
    testBtn.Position = UDim2.fromOffset(20, y)
    testBtn.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    testBtn.BorderSizePixel = 0
    testBtn.Text = "Test Webhook (Robot Kraken)"
    testBtn.TextColor3 = Color3.new(1, 1, 1)
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 13
    testBtn.Parent = content
    
    local btnCorner = Instance.new("UICorner", testBtn)
    btnCorner.CornerRadius = UDim.new(0, 8)
    
    -- Button hover effects
    testBtn.MouseEnter:Connect(function()
        TweenService:Create(testBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(140, 200, 255)
        }):Play()
    end)
    
    testBtn.MouseLeave:Connect(function()
        TweenService:Create(testBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(120, 180, 255)
        }):Play()
    end)

    -- Bubble (minimized state)
    local bubble = Instance.new("TextButton")
    bubble.Visible = false
    bubble.Size = UDim2.fromOffset(50, 50)
    bubble.Position = UDim2.new(0.5, -25, 0.2, 0)
    bubble.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
    bubble.Text = "🐟"
    bubble.TextScaled = true
    bubble.Font = Enum.Font.GothamBold
    bubble.TextColor3 = Color3.fromRGB(120, 180, 255)
    bubble.Parent = sg
    
    local bubbleCorner = Instance.new("UICorner", bubble)
    bubbleCorner.CornerRadius = UDim.new(1, 0)
    
    local bubbleStroke = Instance.new("UIStroke", bubble)
    bubbleStroke.Color = Color3.fromRGB(120, 180, 255)
    bubbleStroke.Thickness = 2

    -- Event handlers
    tbWebhook.FocusLost:Connect(function() 
        Config.WebhookURL = tbWebhook.Text 
    end)
    tbUserId.FocusLost:Connect(function() 
        Config.UserID = tbUserId.Text 
    end)
    tbCustomWebhook.FocusLost:Connect(function()
        if tbCustomWebhook.Text ~= "" then
            Config.WebhookURL = tbCustomWebhook.Text
        end
    end)

    local function setEnabled(enabled)
        Config.Enabled = enabled
        if enabled then
            TweenService:Create(toggleFrame, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(120, 180, 255)
            }):Play()
            TweenService:Create(toggleKnob, TweenInfo.new(0.3), {
                Position = UDim2.fromOffset(32, 3)
            }):Play()
            statusLabel.Text = "Status: Active - Monitoring chat..."
            statusLabel.TextColor3 = Color3.fromRGB(110, 255, 140)
        else
            TweenService:Create(toggleFrame, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(80, 85, 100)
            }):Play()
            TweenService:Create(toggleKnob, TweenInfo.new(0.3), {
                Position = UDim2.fromOffset(6, 3)
            }):Play()
            statusLabel.Text = "Status: Disabled"
            statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        end
    end
    
    setEnabled(true)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Size = UDim2.fromScale(1, 1)
    toggleBtn.Text = ""
    toggleBtn.Parent = toggleFrame
    
    toggleBtn.MouseButton1Click:Connect(function()
        setEnabled(not Config.Enabled)
    end)

    close.MouseButton1Click:Connect(function() 
        TweenService:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.fromOffset(0, 0)
        }):Play()
        wait(0.3)
        sg:Destroy() 
    end)
    
    local function minimize(toBubble)
        if toBubble then
            TweenService:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                Size = UDim2.fromOffset(0, 0)
            }):Play()
            wait(0.3)
            win.Visible = false
            bubble.Visible = true
            TweenService:Create(bubble, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                Size = UDim2.fromOffset(50, 50)
            }):Play()
        else
            TweenService:Create(bubble, TweenInfo.new(0.2), {
                Size = UDim2.fromOffset(0, 0)
            }):Play()
            wait(0.2)
            bubble.Visible = false
            win.Visible = true
            TweenService:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                Size = UDim2.fromOffset(380, 480)
            }):Play()
        end
    end
    
    mini.MouseButton1Click:Connect(function() minimize(true) end)
    bubble.MouseButton1Click:Connect(function() minimize(false) end)

    -- Smooth dragging for main window
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Smooth dragging for bubble
    local bubbleDragging, bubbleDragStart, bubbleStartPos
    bubble.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bubbleDragging = true
            bubbleDragStart = input.Position
            bubbleStartPos = bubble.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if bubbleDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - bubbleDragStart
            bubble.Position = UDim2.new(
                bubbleStartPos.X.Scale, 
                bubbleStartPos.X.Offset + delta.X, 
                bubbleStartPos.Y.Scale, 
                bubbleStartPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bubbleDragging = false
        end
    end)

    GUI.ScreenGui  = sg
    GUI.Window     = win
    GUI.Status     = statusLabel
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
--  ENHANCED DISCORD WEBHOOK (Like Image 3)
-- =========================================================
local function build_discord_embed(data)
    -- Get fish icon URL from the fish data
    local fishIconUrl = asset_to_thumb_url(data.fishIcon)
    
    -- Create compact embed similar to image 3
    local embed = {
        color = 0x1ABC9C, -- Teal color like in image 3
        thumbnail = {
            url = fishIconUrl
        },
        fields = {
            {
                name = "Fish Name 🐟",
                value = "**" .. data.fishName .. "**",
                inline = false
            },
            {
                name = "Weight ⚖️",
                value = data.weightStr,
                inline = true
            },
            {
                name = "Rarity ✨",
                value = data.rarityStr,
                inline = true
            },
            {
                name = "Tier 🏆",
                value = tier_name(data.tierNumber),
                inline = true
            },
            {
                name = "Sell Price 🪙",
                value = fmt_int(data.sellPrice),
                inline = true
            }
        },
        footer = {
            text = "ArcvourHUB Notifier • Today at " .. os.date("%H:%M")
        }
    }
    
    -- Add optional stats fields if available
    if data.totalCaught then
        table.insert(embed.fields, {
            name = "Total Caught 🐟", 
            value = fmt_int(data.totalCaught), 
            inline = true
        })
    end
    
    if data.bagSize then
        table.insert(embed.fields, {
            name = "Bag Size 🧺", 
            value = data.bagSize, 
            inline = true
        })
    end
    
    return embed
end

local function send_webhook(embedData)
    local webhookUrl = Config.WebhookURL
    if webhookUrl == "" then
        GUI.Status.Text = "Status: Error - Webhook URL empty"
        GUI.Status.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end
    
    -- Create message content similar to image 3
    local messageContent = string.format("A high-tier fish was caught by %s!", embedData.playerName or "someone")
    if Config.UserID ~= "" then
        messageContent = string.format("<@%s>\n%s", Config.UserID, messageContent)
    end
    
    local payload = {
        content = messageContent,
        embeds = {embedData}
    }
    
    local json = HttpService:JSONEncode(payload)
    
    GUI.Status.Text = "Status: Sending webhook..."
    GUI.Status.TextColor3 = Color3.fromRGB(255, 230, 120)
    
    local success, response = http_post_json(webhookUrl, json)
    
    if success then
        GUI.Status.Text = "Status: Webhook sent successfully!"
        GUI.Status.TextColor3 = Color3.fromRGB(110, 255, 140)
    else
        GUI.Status.Text = "Status: Failed to send webhook"
        GUI.Status.TextColor3 = Color3.fromRGB(255, 120, 120)
        warn("[FishShit] Webhook failed:", response)
    end
end

-- =========================================================
--  TEST WEBHOOK (Robot Kraken)
-- =========================================================
GUI.TestButton.MouseButton1Click:Connect(function()
    GUI.Status.Text = "Status: Testing Robot Kraken..."
    GUI.Status.TextColor3 = Color3.fromRGB(255, 230, 120)

    -- Robot Kraken data (from list.lua)
    local robotKraken = {
        Name = "Robot Kraken",
        Icon = "rbxassetid://80927639907406",
        Tier = 7,
        SellPrice = 327500,
        Probability = 2.857142857142857e-07
    }
    
    -- Generate random weight similar to the real game
    local weight = math.random(259820, 389730) / 1000
    local weightStr = string.format("%.2f kg", weight)
    local rarityStr = prob_to_rarity_str(robotKraken.Probability)

    -- Build embed data
    local embedData = build_discord_embed({
        playerName = LP.DisplayName or LP.Name,
        fishName = robotKraken.Name,
        fishIcon = robotKraken.Icon,
        weightStr = weightStr,
        rarityStr = rarityStr,
        tierNumber = robotKraken.Tier,
        sellPrice = robotKraken.SellPrice,
        totalCaught = nil,
        bagSize = nil
    })

    console_box({
        player = LP.DisplayName or LP.Name,
        fish = robotKraken.Name,
        weight = weightStr,
        rarity = rarityStr,
        tier = tier_name(robotKraken.Tier),
        price = fmt_int(robotKraken.SellPrice)
    })

    send_webhook(embedData)
end)

-- =========================================================
--  LIVE CHAT MONITOR
-- =========================================================
local function should_notify(tierNum)
    for _, t in ipairs(Config.SelectedTiers) do 
        if t == tierNum then return true end 
    end
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
        for _, stat in ipairs(ls:GetChildren()) do
            local statName = stat.Name:lower()
            if stat.Value ~= nil then
                if statName:find("total") and statName:find("caught") then
                    stats.totalCaught = tonumber(stat.Value)
                elseif statName:find("bag") and statName:find("size") then
                    stats.bagSize = tostring(stat.Value)
                end
            end
        end
    end
    return stats
end

local function process_fish_catch(playerName, fishName, weightStr, rarityFromChat)
    local fishData = getFishDataByName(fishName)
    if not fishData then 
        warn("[FishShit] Fish data not found for:", fishName)
        return 
    end
    
    if not should_notify(fishData.tier) then 
        return 
    end

    local rarityStr = rarityFromChat or prob_to_rarity_str(fishData.prob) or "Unknown"
    local stats = read_leaderstats_for(LP)

    local embedData = {
        playerName = playerName,
        fishName = fishData.name,
        fishIcon = fishData.icon,
        weightStr = weightStr,
        rarityStr = rarityStr,
        tierNumber = fishData.tier,
        sellPrice = fishData.sell or 0,
        totalCaught = stats.totalCaught,
        bagSize = stats.bagSize
    }

    local embed = build_discord_embed(embedData)

    console_box({
        player = playerName,
        fish = fishData.name,
        weight = weightStr,
        rarity = rarityStr,
        tier = tier_name(fishData.tier),
        price = fmt_int(tonumber(fishData.sell or 0)),
        totalCaught = stats.totalCaught and fmt_int(stats.totalCaught) or nil,
        bagSize = stats.bagSize
    })

    send_webhook(embed)
end

-- Monitor chat for fish catches
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
            local playerName, fishName, weight, rarity = parse_fish_message(lbl.Text)
            if playerName then 
                process_fish_catch(playerName, fishName, weight, rarity)
            end
        end
    end)
end)

print("[FishShit] Enhanced Notifier ready ✔️")
print("[FishShit] • Modern UI with smooth animations")
print("[FishShit] • Discord embeds with fish icons") 
print("[FishShit] • Draggable interface")
print("[FishShit] Loading fish data from GitHub...")
