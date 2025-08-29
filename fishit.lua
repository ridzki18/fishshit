-- Fish It Discord Webhook Notifier
-- Created for catching fish notifications and sending to Discord

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Configuration
local Config = {
    WebhookURL = "",
    UserID = "",
    SelectedTiers = {7}, -- Default: SECRET only
    Enabled = false,
    RetryAttempts = 10,
    RetryDelay = 2
}

-- Tier mappings
local TierNames = {
    [5] = "Legendary",
    [6] = "Mythic", 
    [7] = "SECRET"
}

-- Create GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FishHookNotifier"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ResetOnSpawn = false
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    MainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    -- Corner rounding
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    Title.BorderSizePixel = 0
    Title.Text = "🎣 FishHook Notifier"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -40, 0, 10)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextScaled = true
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = Title
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton
    
    -- Webhook URL Input
    local WebhookLabel = Instance.new("TextLabel")
    WebhookLabel.Size = UDim2.new(1, -20, 0, 25)
    WebhookLabel.Position = UDim2.new(0, 10, 0, 70)
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.Text = "Discord Webhook URL"
    WebhookLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left
    WebhookLabel.Font = Enum.Font.Gotham
    WebhookLabel.TextSize = 14
    WebhookLabel.Parent = MainFrame
    
    local WebhookInput = Instance.new("TextBox")
    WebhookInput.Size = UDim2.new(1, -20, 0, 35)
    WebhookInput.Position = UDim2.new(0, 10, 0, 95)
    WebhookInput.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    WebhookInput.BorderSizePixel = 0
    WebhookInput.Text = ""
    WebhookInput.PlaceholderText = "Enter your Discord webhook URL..."
    WebhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    WebhookInput.Font = Enum.Font.Gotham
    WebhookInput.TextSize = 12
    WebhookInput.Parent = MainFrame
    
    local WebhookCorner = Instance.new("UICorner")
    WebhookCorner.CornerRadius = UDim.new(0, 6)
    WebhookCorner.Parent = WebhookInput
    
    -- User ID Input
    local UserIDLabel = Instance.new("TextLabel")
    UserIDLabel.Size = UDim2.new(1, -20, 0, 25)
    UserIDLabel.Position = UDim2.new(0, 10, 0, 145)
    UserIDLabel.BackgroundTransparency = 1
    UserIDLabel.Text = "Discord User ID (Optional)"
    UserIDLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    UserIDLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserIDLabel.Font = Enum.Font.Gotham
    UserIDLabel.TextSize = 14
    UserIDLabel.Parent = MainFrame
    
    local UserIDInput = Instance.new("TextBox")
    UserIDInput.Size = UDim2.new(1, -20, 0, 35)
    UserIDInput.Position = UDim2.new(0, 10, 0, 170)
    UserIDInput.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    UserIDInput.BorderSizePixel = 0
    UserIDInput.Text = ""
    UserIDInput.PlaceholderText = "Enter your Discord User ID..."
    UserIDInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    UserIDInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    UserIDInput.Font = Enum.Font.Gotham
    UserIDInput.TextSize = 12
    UserIDInput.Parent = MainFrame
    
    local UserIDCorner = Instance.new("UICorner")
    UserIDCorner.CornerRadius = UDim.new(0, 6)
    UserIDCorner.Parent = UserIDInput
    
    -- Tier Selection
    local TierLabel = Instance.new("TextLabel")
    TierLabel.Size = UDim2.new(1, -20, 0, 25)
    TierLabel.Position = UDim2.new(0, 10, 0, 220)
    TierLabel.BackgroundTransparency = 1
    TierLabel.Text = "Select Tiers to Notify"
    TierLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TierLabel.TextXAlignment = Enum.TextXAlignment.Left
    TierLabel.Font = Enum.Font.Gotham
    TierLabel.TextSize = 14
    TierLabel.Parent = MainFrame
    
    -- Tier Dropdown Frame
    local TierDropdown = Instance.new("Frame")
    TierDropdown.Size = UDim2.new(1, -20, 0, 35)
    TierDropdown.Position = UDim2.new(0, 10, 0, 245)
    TierDropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    TierDropdown.BorderSizePixel = 0
    TierDropdown.Parent = MainFrame
    
    local TierDropdownCorner = Instance.new("UICorner")
    TierDropdownCorner.CornerRadius = UDim.new(0, 6)
    TierDropdownCorner.Parent = TierDropdown
    
    local TierText = Instance.new("TextLabel")
    TierText.Size = UDim2.new(1, -30, 1, 0)
    TierText.Position = UDim2.new(0, 10, 0, 0)
    TierText.BackgroundTransparency = 1
    TierText.Text = "SECRET Only"
    TierText.TextColor3 = Color3.fromRGB(255, 255, 255)
    TierText.TextXAlignment = Enum.TextXAlignment.Left
    TierText.Font = Enum.Font.Gotham
    TierText.TextSize = 12
    TierText.Parent = TierDropdown
    
    local TierArrow = Instance.new("TextLabel")
    TierArrow.Size = UDim2.new(0, 20, 1, 0)
    TierArrow.Position = UDim2.new(1, -25, 0, 0)
    TierArrow.BackgroundTransparency = 1
    TierArrow.Text = "▼"
    TierArrow.TextColor3 = Color3.fromRGB(200, 200, 200)
    TierArrow.TextXAlignment = Enum.TextXAlignment.Center
    TierArrow.Font = Enum.Font.Gotham
    TierArrow.TextSize = 10
    TierArrow.Parent = TierDropdown
    
    -- Tier Options (Initially hidden)
    local TierOptions = Instance.new("Frame")
    TierOptions.Size = UDim2.new(1, 0, 0, 105)
    TierOptions.Position = UDim2.new(0, 0, 1, 5)
    TierOptions.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    TierOptions.BorderSizePixel = 0
    TierOptions.Visible = false
    TierOptions.Parent = TierDropdown
    
    local TierOptionsCorner = Instance.new("UICorner")
    TierOptionsCorner.CornerRadius = UDim.new(0, 6)
    TierOptionsCorner.Parent = TierOptions
    
    -- Tier Option Buttons
    local tierOptions = {
        {name = "Legendary Only", tiers = {5}},
        {name = "Mythic Only", tiers = {6}},
        {name = "SECRET Only", tiers = {7}},
        {name = "Legendary + Mythic + SECRET", tiers = {5, 6, 7}}
    }
    
    for i, option in ipairs(tierOptions) do
        local OptionButton = Instance.new("TextButton")
        OptionButton.Size = UDim2.new(1, -10, 0, 20)
        OptionButton.Position = UDim2.new(0, 5, 0, (i-1) * 25 + 5)
        OptionButton.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
        OptionButton.BorderSizePixel = 0
        OptionButton.Text = option.name
        OptionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        OptionButton.TextXAlignment = Enum.TextXAlignment.Left
        OptionButton.Font = Enum.Font.Gotham
        OptionButton.TextSize = 11
        OptionButton.Parent = TierOptions
        
        local OptionCorner = Instance.new("UICorner")
        OptionCorner.CornerRadius = UDim.new(0, 4)
        OptionCorner.Parent = OptionButton
        
        OptionButton.MouseButton1Click:Connect(function()
            Config.SelectedTiers = option.tiers
            TierText.Text = option.name
            TierOptions.Visible = false
        end)
    end
    
    -- Toggle Dropdown
    local TierButton = Instance.new("TextButton")
    TierButton.Size = UDim2.new(1, 0, 1, 0)
    TierButton.BackgroundTransparency = 1
    TierButton.Text = ""
    TierButton.Parent = TierDropdown
    
    TierButton.MouseButton1Click:Connect(function()
        TierOptions.Visible = not TierOptions.Visible
    end)
    
    -- Enable Toggle
    local EnableLabel = Instance.new("TextLabel")
    EnableLabel.Size = UDim2.new(1, -20, 0, 25)
    EnableLabel.Position = UDim2.new(0, 10, 0, 295)
    EnableLabel.BackgroundTransparency = 1
    EnableLabel.Text = "Enable Fish Catch Notifications"
    EnableLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    EnableLabel.TextXAlignment = Enum.TextXAlignment.Left
    EnableLabel.Font = Enum.Font.Gotham
    EnableLabel.TextSize = 14
    EnableLabel.Parent = MainFrame
    
    local EnableToggle = Instance.new("Frame")
    EnableToggle.Size = UDim2.new(0, 60, 0, 30)
    EnableToggle.Position = UDim2.new(1, -70, 0, 320)
    EnableToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    EnableToggle.BorderSizePixel = 0
    EnableToggle.Parent = MainFrame
    
    local EnableToggleCorner = Instance.new("UICorner")
    EnableToggleCorner.CornerRadius = UDim.new(0, 15)
    EnableToggleCorner.Parent = EnableToggle
    
    local EnableButton = Instance.new("Frame")
    EnableButton.Size = UDim2.new(0, 26, 0, 26)
    EnableButton.Position = UDim2.new(0, 2, 0, 2)
    EnableButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    EnableButton.BorderSizePixel = 0
    EnableButton.Parent = EnableToggle
    
    local EnableButtonCorner = Instance.new("UICorner")
    EnableButtonCorner.CornerRadius = UDim.new(0, 13)
    EnableButtonCorner.Parent = EnableButton
    
    local EnableClickButton = Instance.new("TextButton")
    EnableClickButton.Size = UDim2.new(1, 0, 1, 0)
    EnableClickButton.BackgroundTransparency = 1
    EnableClickButton.Text = ""
    EnableClickButton.Parent = EnableToggle
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 0, 25)
    StatusLabel.Position = UDim2.new(0, 10, 0, 365)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Status: Disabled"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 12
    StatusLabel.Parent = MainFrame
    
    -- Test Button
    local TestButton = Instance.new("TextButton")
    TestButton.Size = UDim2.new(1, -20, 0, 40)
    TestButton.Position = UDim2.new(0, 10, 0, 395)
    TestButton.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    TestButton.BorderSizePixel = 0
    TestButton.Text = "Test Webhook"
    TestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestButton.Font = Enum.Font.GothamBold
    TestButton.TextSize = 14
    TestButton.Parent = MainFrame
    
    local TestCorner = Instance.new("UICorner")
    TestCorner.CornerRadius = UDim.new(0, 6)
    TestCorner.Parent = TestButton
    
    -- Event Handlers
    WebhookInput.FocusLost:Connect(function()
        Config.WebhookURL = WebhookInput.Text
    end)
    
    UserIDInput.FocusLost:Connect(function()
        Config.UserID = UserIDInput.Text
    end)
    
    EnableClickButton.MouseButton1Click:Connect(function()
        Config.Enabled = not Config.Enabled
        
        if Config.Enabled then
            EnableToggle.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            local tween = TweenService:Create(EnableButton, TweenInfo.new(0.3), {Position = UDim2.new(0, 32, 0, 2)})
            tween:Play()
            StatusLabel.Text = "Status: Active - Monitoring chat..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            EnableToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            local tween = TweenService:Create(EnableButton, TweenInfo.new(0.3), {Position = UDim2.new(0, 2, 0, 2)})
            tween:Play()
            StatusLabel.Text = "Status: Disabled"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    TestButton.MouseButton1Click:Connect(function()
        if Config.WebhookURL == "" then
            StatusLabel.Text = "Status: Error - No webhook URL set!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        StatusLabel.Text = "Status: Testing webhook..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        
        -- Test webhook
        testWebhook()
    end)
    
    -- Make draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    return {
        Frame = MainFrame,
        StatusLabel = StatusLabel,
        WebhookInput = WebhookInput,
        UserIDInput = UserIDInput
    }
end

-- Get fish data from ReplicatedStorage
local function getFishData(fishName)
    local success, fishData = pcall(function()
        return require(ReplicatedStorage.Items[fishName])
    end)
    
    if success and fishData then
        return fishData
    end
    return nil
end

-- Get tier name from tier number
local function getTierName(tierNumber)
    return TierNames[tierNumber] or "Unknown"
end

-- Send webhook with retry
local function sendWebhook(data, retryCount)
    retryCount = retryCount or 0
    
    if retryCount >= Config.RetryAttempts then
        GUI.StatusLabel.Text = "Status: Failed to send after " .. Config.RetryAttempts .. " attempts"
        GUI.StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local webhookData = {
        content = Config.UserID ~= "" and "<@" .. Config.UserID .. ">" or "",
        embeds = {{
            title = "🎣 High-tier fish was caught by " .. data.playerName .. "!",
            description = "",
            color = 0x00ff00,
            fields = {
                {name = "Fish Name 🐟", value = data.fishName, inline = true},
                {name = "Weight ⚖️", value = data.weight, inline = true},
                {name = "Rarity ✨", value = data.rarity, inline = true},
                {name = "Tier 🏆", value = data.tier, inline = true},
                {name = "Sell Price 💰", value = data.sellPrice, inline = true},
                {name = "​", value = "​", inline = true} -- Empty field for formatting
            },
            thumbnail = {
                url = data.icon
            },
            footer = {
                text = "FishHook Notifier • " .. os.date("%X")
            }
        }}
    }
    
    local jsonData = HttpService:JSONEncode(webhookData)
    
    local success, response = pcall(function()
        return HttpService:PostAsync(Config.WebhookURL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)
    
    if success then
        GUI.StatusLabel.Text = "Status: Webhook sent successfully! 🎣"
        GUI.StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        GUI.StatusLabel.Text = "Status: Retrying... (" .. (retryCount + 1) .. "/" .. Config.RetryAttempts .. ")"
        GUI.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        
        wait(Config.RetryDelay)
        sendWebhook(data, retryCount + 1)
    end
end

-- Test webhook function
function testWebhook()
    local testData = {
        playerName = "TestPlayer",
        fishName = "Test Fish",
        weight = "1.23kg",
        rarity = "1 in 999K",
        tier = "SECRET",
        sellPrice = "50,000",
        icon = "https://cdn.discordapp.com/emojis/123456789.png"
    }
    
    sendWebhook(testData)
end

-- Parse chat message for fish catch
local function parseFishCatch(message)
    -- Pattern: [Server]: playername obtained a FishName (weight) with a 1 in XK chance!
    local pattern = "%[Server%]: (.+) obtained a (.+) %((.+)%) with a 1 in (.+) chance!"
    local playerName, fishName, weight, rarity = message:match(pattern)
    
    if playerName and fishName and weight and rarity then
        return {
            playerName = playerName,
            fishName = fishName,
            weight = weight,
            rarity = "1 in " .. rarity
        }
    end
    
    return nil
end

-- Monitor chat messages
local function monitorChat()
    local success, chatService = pcall(function()
        return game:GetService("Chat")
    end)
    
    if success and chatService then
        -- Method 1: Try to hook into Chat service
        chatService.Chatted:Connect(function(part, message, color)
            if not Config.Enabled then return end
            
            local fishCatch = parseFishCatch(message)
            if fishCatch then
                processFishCatch(fishCatch)
            end
        end)
    else
        -- Method 2: Monitor PlayerGui Chat
        local function hookChat()
            local chatGui = PlayerGui:WaitForChild("Chat", 5)
            if chatGui then
                local chatFrame = chatGui:WaitForChild("Frame", 5)
                if chatFrame then
                    local chatChannelParentFrame = chatFrame:WaitForChild("ChatChannelParentFrame", 5)
                    if chatChannelParentFrame then
                        local frame = chatChannelParentFrame:WaitForChild("Frame_MessageLogDisplay", 5)
                        if frame then
                            local scrollingFrame = frame:WaitForChild("Scroller", 5)
                            if scrollingFrame then
                                scrollingFrame.ChildAdded:Connect(function(child)
                                    if not Config.Enabled then return end
                                    
                                    wait(0.1) -- Wait for message to load
                                    local messageFrame = child:FindFirstChild("TextLabel")
                                    if messageFrame and messageFrame.Text then
                                        local fishCatch = parseFishCatch(messageFrame.Text)
                                        if fishCatch then
                                            processFishCatch(fishCatch)
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        
        spawn(hookChat)
    end
end

-- Process fish catch data
function processFishCatch(fishCatch)
    local fishData = getFishData(fishCatch.fishName)
    
    if not fishData then
        print("Fish data not found for:", fishCatch.fishName)
        return
    end
    
    local tierNumber = fishData.Data.Tier
    local tierName = getTierName(tierNumber)
    
    -- Check if tier is in selected tiers
    local shouldNotify = false
    for _, selectedTier in ipairs(Config.SelectedTiers) do
        if tierNumber == selectedTier then
            shouldNotify = true
            break
        end
    end
    
    if not shouldNotify then
        return
    end
    
    -- Format data for webhook
    local webhookData = {
        playerName = fishCatch.playerName,
        fishName = fishCatch.fishName,
        weight = fishCatch.weight,
        rarity = fishCatch.rarity,
        tier = tierName,
        sellPrice = tostring(fishData.SellPrice):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
        icon = "https://assetdelivery.roblox.com/v1/asset/?id=" .. fishData.Data.Icon:match("%d+")
    }
    
    GUI.StatusLabel.Text = "Status: Fish caught! Sending webhook..."
    GUI.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    sendWebhook(webhookData)
end

-- Initialize
GUI = createGUI()
monitorChat()

print("🎣 FishHook Notifier loaded successfully!")
print("Configure your webhook URL and enable notifications to start!")
