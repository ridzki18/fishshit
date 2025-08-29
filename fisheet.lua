--[[
   FishShit Notifier (v4, Fluent UI Edition)
   - Modern Fluent UI interface
   - Source of truth for fish Icon/Tier/Probability: list.lua (GitHub raw)
   - Icon via Roblox Thumbnail API (works on Discord)
   - Embed pills, pretty console log
]]--

-- ====== FLUENT UI LIBRARY ======
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ====== CONFIG: daftar ikan kamu ======
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"
-- ======================================

--// Services
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local UserInputService   = game:GetService("UserInputService")

local LP  = Players.LocalPlayer
local PG  = LP:FindFirstChildOfClass("PlayerGui")

--// Utils
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
--  FLUENT UI CREATION
-- =========================================================
local Window = Fluent:CreateWindow({
    Title = "FishShit Notifier v4.0",
    SubTitle = "Discord Fish Catch Notifications",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl -- Uses the Left Control key to minimize the UI
})

--Fluent provides Lucide Icons https://lucide.dev/icons/ for the tabs, icons are optional
local Tabs = {
    Main = Window:AddTab({ Title = "Main Settings", Icon = "settings" }),
    Webhook = Window:AddTab({ Title = "Webhook Config", Icon = "globe" }),
    Filters = Window:AddTab({ Title = "Fish Filters", Icon = "filter" }),
    Status = Window:AddTab({ Title = "Status & Test", Icon = "activity" })
}

local Options = Fluent.Options

-- =========================================================
--  MAIN SETTINGS TAB
-- =========================================================
do
    local Toggle = Tabs.Main:AddToggle("MainToggle", {
        Title = "Enable Fish Notifications", 
        Description = "Turn on/off the fish catch monitoring",
        Default = true 
    })

    Toggle:OnChanged(function(Value)
        Config.Enabled = Value
        if Value then
            Fluent:Notify({
                Title = "FishShit Enabled",
                Content = "Now monitoring fish catches!",
                Duration = 3
            })
        else
            Fluent:Notify({
                Title = "FishShit Disabled",
                Content = "Fish monitoring stopped.",
                Duration = 3
            })
        end
    end)

    Tabs.Main:AddParagraph({
        Title = "How it works",
        Content = "This script monitors the chat for fish catch messages and sends notifications to your Discord webhook when high-tier fish are caught. Configure your webhook URL and select which fish tiers you want to be notified about."
    })

    local Slider = Tabs.Main:AddSlider("RetryAttempts", {
        Title = "Retry Attempts",
        Description = "Number of times to retry failed webhook sends",
        Default = 8,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Callback = function(Value)
            Config.RetryAttempts = Value
        end
    })

    local DelaySlider = Tabs.Main:AddSlider("RetryDelay", {
        Title = "Retry Delay (seconds)",
        Description = "Delay between webhook retry attempts",
        Default = 2,
        Min = 1,
        Max = 10,
        Rounding = 1,
        Callback = function(Value)
            Config.RetryDelay = Value
        end
    })
end

-- =========================================================
--  WEBHOOK CONFIG TAB
-- =========================================================
do
    local Input = Tabs.Webhook:AddInput("WebhookURL", {
        Title = "Discord Webhook URL",
        Description = "Enter your Discord webhook URL here",
        Default = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC",
        Placeholder = "https://discord.com/api/webhooks/...",
        Numeric = false,
        Finished = false,
        Callback = function(Value)
            Config.WebhookURL = Value
            -- Auto-test webhook when URL is set
            if Value and Value ~= "" and Value:match("discord%.com/api/webhooks/") then
                Fluent:Notify({
                    Title = "Webhook Updated",
                    Content = "Webhook URL has been updated successfully!",
                    Duration = 3
                })
            end
        end
    })

    local UserInput = Tabs.Webhook:AddInput("UserID", {
        Title = "Discord User ID (Optional)",
        Description = "Your Discord User ID for mentions",
        Default = "905231281128898570",
        Placeholder = "123456789012345678",
        Numeric = false,
        Finished = false,
        Callback = function(Value)
            Config.UserID = Value
        end
    })
    
    -- Initialize config with default values
    Config.WebhookURL = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC"
    Config.UserID = "905231281128898570"

    Tabs.Webhook:AddParagraph({
        Title = "How to get Webhook URL:",
        Content = "1. Go to your Discord server\n2. Right-click on the channel\n3. Edit Channel > Integrations > Webhooks\n4. Create New Webhook\n5. Copy Webhook URL"
    })

    Tabs.Webhook:AddParagraph({
        Title = "How to get User ID:",
        Content = "1. Enable Developer Mode in Discord\n2. Right-click your username\n3. Copy ID"
    })
end

-- =========================================================
--  FISH FILTERS TAB
-- =========================================================
do
    Tabs.Filters:AddParagraph({
        Title = "Fish Tier Selection",
        Content = "Choose which fish tiers you want to receive notifications for. Higher tiers are rarer and more valuable."
    })

    local tierToggles = {}
    local tierData = {
        {1, "Common", "Most frequent catches"},
        {2, "Uncommon", "Fairly common catches"},
        {3, "Rare", "Less common catches"},
        {4, "Epic", "Uncommon valuable catches"},
        {5, "Legendary", "Very rare and valuable"},
        {6, "Mythic", "Extremely rare catches"},
        {7, "SECRET", "Ultra rare secret fish"}
    }

    for _, data in ipairs(tierData) do
        local tier, name, desc = data[1], data[2], data[3]
        local isDefaultEnabled = table.find(Config.SelectedTiers, tier) ~= nil
        
        tierToggles[tier] = Tabs.Filters:AddToggle("Tier"..tier, {
            Title = name.." (Tier "..tier..")",
            Description = desc,
            Default = isDefaultEnabled
        })

        tierToggles[tier]:OnChanged(function(Value)
            local pos = table.find(Config.SelectedTiers, tier)
            if Value and not pos then
                table.insert(Config.SelectedTiers, tier)
            elseif not Value and pos then
                table.remove(Config.SelectedTiers, pos)
            end
        end)
    end

    -- Quick preset buttons
    Tabs.Filters:AddButton({
        Title = "Rare+ Only (Tier 3-7)",
        Description = "Enable notifications for Rare, Epic, Legendary, Mythic, and SECRET fish",
        Callback = function()
            Config.SelectedTiers = {3,4,5,6,7}
            for tier, toggle in pairs(tierToggles) do
                toggle:SetValue(tier >= 3)
            end
            Fluent:Notify({
                Title = "Filter Updated",
                Content = "Now monitoring Tier 3+ fish",
                Duration = 3
            })
        end
    })

    Tabs.Filters:AddButton({
        Title = "High-Tier Only (Tier 5-7)",
        Description = "Enable notifications for Legendary, Mythic, and SECRET fish only",
        Callback = function()
            Config.SelectedTiers = {5,6,7}
            for tier, toggle in pairs(tierToggles) do
                toggle:SetValue(tier >= 5)
            end
            Fluent:Notify({
                Title = "Filter Updated", 
                Content = "Now monitoring Tier 5+ fish only",
                Duration = 3
            })
        end
    })

    Tabs.Filters:AddButton({
        Title = "SECRET Only (Tier 7)",
        Description = "Enable notifications for SECRET fish only",
        Callback = function()
            Config.SelectedTiers = {7}
            for tier, toggle in pairs(tierToggles) do
                toggle:SetValue(tier == 7)
            end
            Fluent:Notify({
                Title = "Filter Updated",
                Content = "Now monitoring SECRET fish only",
                Duration = 3
            })
        end
    })
end

-- =========================================================
--  STATUS & TEST TAB
-- =========================================================
do
    local StatusLabel = Tabs.Status:AddParagraph({
        Title = "System Status",
        Content = "✅ Active - Monitoring chat for fish catches..."
    })

    local StatsLabel = Tabs.Status:AddParagraph({
        Title = "Session Statistics",
        Content = "Fish notifications sent: 0\nLast notification: Never"
    })

    local sessionStats = {
        notificationsSent = 0,
        lastNotification = "Never"
    }

    -- Test webhook button with better error handling
    Tabs.Status:AddButton({
        Title = "🔧 Test Webhook (Robot Kraken)",
        Description = "Send a test notification with Robot Kraken fish data",
        Callback = function()
            -- Validate webhook URL first
            if Config.WebhookURL == "" or not Config.WebhookURL:match("discord%.com/api/webhooks/") then
                Fluent:Notify({
                    Title = "Invalid Webhook",
                    Content = "Please set a valid Discord webhook URL first!",
                    Duration = 5
                })
                if _G.UpdateFishStatus then
                    _G.UpdateFishStatus("Error - Invalid webhook URL", true)
                end
                return
            end

            Fluent:Notify({
                Title = "Testing Webhook",
                Content = "Sending Robot Kraken test notification...",
                Duration = 3
            })

            if _G.UpdateFishStatus then
                _G.UpdateFishStatus("🟡 Testing webhook with Robot Kraken...", false)
            end

            -- Robot Kraken test data (protected from errors)
            local robot = {
                Name  = "Robot Kraken",
                Icon  = "rbxassetid://80927639907406",
                Tier  = 7,
                SellPrice = 327500,
                WeightDefaultMin = 259820,
                WeightDefaultMax = 389730,
                Chance = 2.857142857142857e-07, -- ≈ 1 in 3,500,000
            }
            
            local weight, weightStr, rarityStr, iconUrl
            
            -- Safe calculations with error handling
            pcall(function()
                weight = math.random(robot.WeightDefaultMin, robot.WeightDefaultMax) / 1000
                weightStr = string.format("%.2f kg", weight)
                rarityStr = "1 in "..fmt_int(math.max(1, math.floor(1/robot.Chance + 0.5)))
                iconUrl = asset_to_thumb_url(robot.Icon)
            end)
            
            -- Fallback values if calculations fail
            weightStr = weightStr or "324.82 kg"
            rarityStr = rarityStr or "1 in 3,500,000"
            iconUrl = iconUrl or ""

            local embedData = {
                playerName = LP.DisplayName or LP.Name or "Test Player",
                fishName   = robot.Name,
                weightStr  = weightStr,
                rarityStr  = rarityStr,
                tierNumber = robot.Tier,
                sellPrice  = robot.SellPrice,
                iconUrl    = iconUrl,
                totalCaught= nil,
                bagSize    = nil,
            }

            -- Safe embed building
            local embed
            pcall(function()
                embed = build_embed(embedData)
            end)
            
            if not embed then
                if _G.UpdateFishStatus then
                    _G.UpdateFishStatus("Error - Failed to build embed", true)
                end
                return
            end

            -- Safe console logging
            pcall(function()
                console_box({
                    player = LP.DisplayName or LP.Name,
                    fish   = robot.Name,
                    weight = weightStr,
                    rarity = rarityStr,
                    tier   = tier_name(robot.Tier),
                    price  = fmt_int(robot.SellPrice),
                })
            end)

            -- Send webhook with retry
            send_webhook(embed)
        end
    })

    -- Reload fish data button
    Tabs.Status:AddButton({
        Title = "🔄 Reload Fish Data",
        Description = "Refresh fish data from GitHub repository",
        Callback = function()
            FishMap = nil -- Clear cache
            load_fish_map()
            Fluent:Notify({
                Title = "Fish Data Reloaded",
                Content = "Fish data has been refreshed from repository",
                Duration = 3
            })
        end
    })

    -- Function to update status
    _G.UpdateFishStatus = function(status, isError)
        local color = isError and "🔴" or "✅"
        StatusLabel:SetDesc(color.." "..status)
        
        if not isError then
            sessionStats.notificationsSent = sessionStats.notificationsSent + 1
            sessionStats.lastNotification = os.date("%H:%M:%S")
        end
        
        StatsLabel:SetDesc("Fish notifications sent: "..sessionStats.notificationsSent.."\nLast notification: "..sessionStats.lastNotification)
    end
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
--  IMPROVED WEBHOOK WITH RETRY LOGIC
-- =========================================================
local function build_embed(data)
    -- Safely build embed with nil checks
    local fields = {}
    
    -- Ensure all required data exists
    local fishName = tostring(data.fishName or "Unknown Fish")
    local weightStr = tostring(data.weightStr or "0 kg")
    local rarityStr = tostring(data.rarityStr or "Unknown")
    local tierNumber = tonumber(data.tierNumber) or 1
    local sellPrice = tonumber(data.sellPrice) or 0
    local playerName = tostring(data.playerName or "Unknown Player")
    
    table.insert(fields, {name = "Fish Name 🐟", value = "**"..fishName.."**", inline = false})
    table.insert(fields, {name = "Weight ⚖️", value = pill(weightStr), inline = true})
    table.insert(fields, {name = "Rarity ✨", value = pill(rarityStr), inline = true})
    table.insert(fields, {name = "Tier 🏆", value = pill(tier_name(tierNumber)), inline = true})
    table.insert(fields, {name = "Sell Price 🪙", value = pill(fmt_int(sellPrice)), inline = true})
    
    if data.totalCaught and tonumber(data.totalCaught) then 
        table.insert(fields, {name="Total Caught 🐟", value=pill(fmt_int(data.totalCaught)), inline=true}) 
    end
    if data.bagSize and tostring(data.bagSize) ~= "" then 
        table.insert(fields, {name="Bag Size 🧺", value=pill(data.bagSize), inline=true}) 
    end
    
    return {
        title      = ("A high-tier fish was caught by %s!"):format(playerName),
        color      = 0x20C997,
        fields     = fields,
        thumbnail  = { url = tostring(data.iconUrl or "") },
        footer     = { text = "FishShit Notifier • "..os.date("%X") },
    }
end

local function send_webhook_with_retry(embedData, retryCount)
    retryCount = retryCount or 0
    
    if Config.WebhookURL == "" then
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("Error - Webhook URL empty", true)
        end
        Fluent:Notify({
            Title = "Webhook Error",
            Content = "Please configure your webhook URL first!",
            Duration = 5
        })
        return false
    end
    
    local payload = {
        username = "FishShit Notifier",
        avatar_url = "https://cdn.discordapp.com/attachments/123456789/fish_avatar.png",
        content = (Config.UserID ~= "" and ("<@"..Config.UserID.."> ") or "") .. "🎣 **Fish Alert!**",
        embeds = {embedData}
    }
    
    local success, json = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    
    if not success then
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("Error - Failed to encode JSON", true)
        end
        return false
    end
    
    local ok, response = http_post_json(Config.WebhookURL, json)
    
    if ok then
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("Webhook sent successfully! ✅", false)
        end
        return true
    else
        -- Retry logic
        if retryCount < Config.RetryAttempts then
            if _G.UpdateFishStatus then
                _G.UpdateFishStatus(string.format("Retrying webhook... (%d/%d)", retryCount + 1, Config.RetryAttempts), true)
            end
            
            task.wait(Config.RetryDelay)
            return send_webhook_with_retry(embedData, retryCount + 1)
        else
            if _G.UpdateFishStatus then
                _G.UpdateFishStatus("Failed to send webhook after "..Config.RetryAttempts.." attempts", true)
            end
            
            Fluent:Notify({
                Title = "Webhook Failed",
                Content = "Failed to send after "..Config.RetryAttempts.." attempts",
                Duration = 5
            })
            return false
        end
    end
end

-- Wrapper function for compatibility
local function send_webhook(embedData)
    task.spawn(function()
        send_webhook_with_retry(embedData)
    end)
end

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
    -- Wrap everything in pcall to prevent crashes
    local success, err = pcall(function()
        local fish = getFishDataByName(fishName)
        if not fish then 
            warn("[FishShit] Fish data not found for: "..tostring(fishName))
            return 
        end
        
        if not should_notify(fish.tier) then 
            return 
        end

        local rarityStr = rarityStrFromChat or prob_to_rarity_str(fish.prob) or "Unknown"
        local iconUrl   = asset_to_thumb_url(fish.icon or "")

        local stats = read_leaderstats_for(LP)
        local embedData = {
            playerName = pName,
            fishName   = fish.name,
            weightStr  = weightStr,
            rarityStr  = rarityStr,
            tierNumber = fish.tier,
            sellPrice  = fish.sell or 0,
            iconUrl    = iconUrl,
            totalCaught= stats.totalCaught,
            bagSize    = stats.bagSize,
        }

        local embed = build_embed(embedData)
        
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
        
        -- Show notification popup
        Fluent:Notify({
            Title = "🐟 "..fish.name.." Caught!",
            Content = "Tier "..fish.tier.." - "..rarityStr.." - Sending to Discord...",
            Duration = 5
        })
    end)
    
    if not success then
        warn("[FishShit] Error processing fish message:", err)
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("Error processing fish: "..tostring(err), true)
        end
    end
end

-- hook classic chat UI with improved error handling
task.spawn(function()
    local success, err = pcall(function()
        local chatGui = PG and PG:WaitForChild("Chat", 10)
        if not chatGui then 
            warn("[FishShit] Chat GUI not found")
            if _G.UpdateFishStatus then
                _G.UpdateFishStatus("Warning - Chat GUI not found", true)
            end
            return 
        end
        
        local frame = chatGui:WaitForChild("Frame", 8)
        if not frame then 
            warn("[FishShit] Chat Frame not found")
            return 
        end
        
        local log = frame:WaitForChild("ChatChannelParentFrame", 8)
        log = log and log:WaitForChild("Frame_MessageLogDisplay", 8)
        log = log and log:WaitForChild("Scroller", 8)
        
        if not log then 
            warn("[FishShit] Chat log scroller not found")
            return 
        end

        -- Successfully connected to chat
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("✅ Connected to chat - Monitoring fish catches...", false)
        end
        
        Fluent:Notify({
            Title = "Chat Connected!",
            Content = "Successfully connected to game chat. Ready to monitor fish catches!",
            Duration = 5
        })

        log.ChildAdded:Connect(function(child)
            if not Config.Enabled then return end
            
            task.spawn(function()
                task.wait(0.1)
                local success2, err2 = pcall(function()
                    local lbl = child:FindFirstChild("TextLabel")
                    if lbl and lbl.Text then
                        local pName, fishName, w, r = parse_fish_message(lbl.Text)
                        if pName then 
                            process_msg(pName, fishName, w, r) 
                        end
                    end
                end)
                
                if not success2 then
                    warn("[FishShit] Error processing chat message:", err2)
                end
            end)
        end)
    end)
    
    if not success then
        warn("[FishShit] Failed to connect to chat:", err)
        if _G.UpdateFishStatus then
            _G.UpdateFishStatus("❌ Failed to connect to chat: "..tostring(err), true)
        end
        
        Fluent:Notify({
            Title = "Chat Connection Failed",
            Content = "Could not connect to game chat. Please rejoin the game.",
            Duration = 8
        })
    end
end)

-- =========================================================
--  SAVE MANAGER SETUP
-- =========================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings() 

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes({}) 

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("FishShitNotifier")
SaveManager:SetFolder("FishShitNotifier/configs")

SaveManager:BuildConfigSection(Tabs.Status) 

-- =========================================================
--  THEME MANAGER
-- =========================================================
InterfaceManager:BuildInterfaceSection(Tabs.Status)

-- =========================================================
--  WINDOW SETUP & NOTIFICATIONS
-- =========================================================
Window:SelectTab(1)

Fluent:Notify({
    Title = "FishShit Loaded!",
    Content = "The script has been loaded successfully. Configure your settings and start fishing!",
    Duration = 8
})

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which will load the first file in your configs folder, or configs/autoload

print("[FishShit] Fluent UI Notifier ready ✔ (uses list.lua from GitHub for icons/tiers/probabilities)")
print("[FishShit] Press Left Control to minimize the UI")
