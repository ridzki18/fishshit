--[[ 
  FishShit Notifier (v4, Fluent UI Edition)
  - Perbaikan: error "Interface Callback error: attempt to call a nil value" saat Test Webhook.
  - Penyebab: callback memanggil fungsi yang dideklarasikan setelahnya sebagai `local function ...` → nil di saat binding.
  - Solusi: deklarasi/definisi fungsi utility (build_embed, console_box, send_webhook) sebelum UI & callback.
  - Juga memastikan ikon rbxassetid:// dikonversi jadi URL yang bisa dipakai Discord.
]]--

-- ====== FLUENT UI LIBRARY ======
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ====== CONFIG: daftar ikan kamu ======
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"

--// Services
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local LP                 = Players.LocalPlayer

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
    if id == "" then
        return "https://tr.rbxcdn.com/8e8f9a6b6f9fe4d2b8f/352/352/Image/Png" -- tiny fallback
    end
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
-- CONFIG
-- =========================================================
local Config = {
    WebhookURL   = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC", -- <<< TEST WEBHOOK MU
    UserID       = "905231281128898570", -- <<< TEST USER ID MU (optional mention)
    SelectedTiers= {5,6,7}, -- Legendary+Mythic+SECRET
    Enabled      = true,
    RetryAttempts= 8,
    RetryDelay   = 2,
}

local TierNames = {
    [1]="Common",[2]="Uncommon",[3]="Rare",
    [4]="Epic",[5]="Legendary",[6]="Mythic",[7]="SECRET"
}
local function tier_name(n) return TierNames[tonumber(n) or n] or tostring(n) end

-- =========================================================
-- FISH LIST (GitHub raw) + FALLBACK
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
-- >>> FUNCTIONS YANG DIPAKAI CALLBACK (DIDEFINISIKAN DI AWAL)
-- =========================================================

-- Pretty console box untuk contoh output
local function console_box(info)
    local lines = {}
    local function add(s) table.insert(lines, s) end
    local function pad(s, n) s = tostring(s); if #s < n then s = s .. string.rep(" ", n-#s) end; return s end

    add("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    add("┃ FishShit • Webhook Test                         ┃")
    add("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫")
    add("┃ Player : " .. pad(info.player or "-", 30) .. "┃")
    add("┃ Fish   : " .. pad(info.fish or "-", 30) .. "┃")
    add("┃ Weight : " .. pad(info.weight or "-", 30) .. "┃")
    add("┃ Rarity : " .. pad(info.rarity or "-", 30) .. "┃")
    add("┃ Tier   : " .. pad(info.tier or "-", 30) .. "┃")
    add("┃ Price  : " .. pad(info.price or "-", 30) .. "┃")
    add("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")

    print(table.concat(lines, "\n"))
end

-- Membangun embed untuk Discord
local function build_embed(args)
    local colorByTier = {
        [1]=0x9ea7b3,[2]=0x86c06c,[3]=0x3b82f6,[4]=0xa855f7,[5]=0xf59e0b,[6]=0xef4444,[7]=0x00ffd5
    }
    local title = ("🎣 %s"):format(args.fishName or "Unknown Fish")
    local desc  = table.concat({
        ("**Player:** %s"):format(args.playerName or "-"),
        ("**Weight:** %s"):format(args.weightStr or "-"),
        args.rarityStr and ("**Rarity:** %s"):format(args.rarityStr) or nil,
        args.sellPrice and ("**Value:** %s"):format(fmt_int(args.sellPrice)) or nil,
        (args.totalCaught and args.bagSize) and ("**Bag:** %s / %s"):format(args.totalCaught, args.bagSize) or nil
    }, "\n")

    local embed = {
        title = title,
        description = desc,
        color = colorByTier[tonumber(args.tierNumber or 5)] or 0x3b82f6,
        thumbnail = { url = args.iconUrl or "" },
        footer = { text = "FishShit Notifier • Test Webhook (Robot Kraken)" },
        timestamp = DateTime.now():ToIsoDate(),
    }
    return embed
end

-- Kirim ke Discord webhook (dengan retry sesuai Config)
local function send_webhook(embed)
    local payload = {
        username   = "FishShit Notifier",
        avatar_url = "https://i.imgur.com/9w3x9fN.png",
        embeds     = { embed },
        content    = (Config.UserID ~= "" and "<@"..Config.UserID..">") or nil
    }
    local body = HttpService:JSONEncode(payload)

    for attempt = 1, (Config.RetryAttempts or 1) do
        local ok, res = http_post_json(Config.WebhookURL, body)
        if ok then
            if _G.UpdateFishStatus then
                _G.UpdateFishStatus(("Webhook sent (%s/%s)"):format(attempt, Config.RetryAttempts), false)
            end
            return true
        else
            if _G.UpdateFishStatus then
                _G.UpdateFishStatus(("Webhook failed (try %s/%s): %s"):format(attempt, Config.RetryAttempts, tostring(res)), true)
            end
            task.wait(Config.RetryDelay or 1)
        end
    end
    return false
end

-- =========================================================
-- FLUENT UI CREATION (setelah fungsi2 di atas aman dipanggil)
-- =========================================================
local Window = Fluent:CreateWindow({
    Title = "FishShit Notifier v4.0",
    SubTitle = "Discord Fish Catch Notifications",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main    = Window:AddTab({ Title = "Main Settings",   Icon = "settings" }),
    Webhook = Window:AddTab({ Title = "Webhook Config",  Icon = "globe" }),
    Filters = Window:AddTab({ Title = "Fish Filters",    Icon = "filter" }),
    Status  = Window:AddTab({ Title = "Status & Test",   Icon = "activity" })
}

-- =========================================================
-- MAIN SETTINGS TAB
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
            Fluent:Notify({ Title = "FishShit Enabled", Content = "Now monitoring fish catches!", Duration = 3 })
        else
            Fluent:Notify({ Title = "FishShit Disabled", Content = "Fish monitoring stopped.", Duration = 3 })
        end
    end)

    Tabs.Main:AddParagraph({
        Title = "How it works",
        Content = "This script monitors the chat for fish catch messages and sends notifications to your Discord webhook when high-tier fish are caught.\nConfigure your webhook URL and select which fish tiers you want to be notified about."
    })

    Tabs.Main:AddSlider("RetryAttempts", {
        Title = "Retry Attempts",
        Description = "Number of times to retry failed webhook sends",
        Default = Config.RetryAttempts, Min = 1, Max = 20, Rounding = 0,
        Callback = function(Value) Config.RetryAttempts = Value end
    })

    Tabs.Main:AddSlider("RetryDelay", {
        Title = "Retry Delay (seconds)",
        Description = "Delay between webhook retry attempts",
        Default = Config.RetryDelay, Min = 1, Max = 10, Rounding = 1,
        Callback = function(Value) Config.RetryDelay = Value end
    })
end

-- =========================================================
-- WEBHOOK CONFIG TAB
-- =========================================================
do
    Tabs.Webhook:AddInput("WebhookURL", {
        Title = "Discord Webhook URL",
        Description = "Enter your Discord webhook URL here",
        Default = Config.WebhookURL,
        Placeholder = "https://discord.com/api/webhooks/...",
        Numeric = false, Finished = false,
        Callback = function(Value) Config.WebhookURL = Value end
    })

    Tabs.Webhook:AddInput("UserID", {
        Title = "Discord User ID (Optional)",
        Description = "Your Discord User ID for mentions",
        Default = Config.UserID,
        Placeholder = "123456789012345678",
        Numeric = false, Finished = false,
        Callback = function(Value) Config.UserID = Value end
    })

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
-- FISH FILTERS TAB (tetap sama)
-- =========================================================
do
    Tabs.Filters:AddParagraph({
        Title = "Fish Tier Selection",
        Content = "Choose which fish tiers you want to receive notifications for.\nHigher tiers are rarer and more valuable."
    })

    local tierToggles = {}
    local tierData = {
        {1,"Common","Most frequent catches"},
        {2,"Uncommon","Fairly common catches"},
        {3,"Rare","Less common catches"},
        {4,"Epic","Uncommon valuable catches"},
        {5,"Legendary","Very rare and valuable"},
        {6,"Mythic","Extremely rare catches"},
        {7,"SECRET","Ultra rare secret fish"}
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
            if Value and not pos then table.insert(Config.SelectedTiers, tier)
            elseif not Value and pos then table.remove(Config.SelectedTiers, pos) end
        end)
    end

    Tabs.Filters:AddButton({
        Title = "Rare+ Only (Tier 3-7)",
        Description = "Enable notifications for Rare, Epic, Legendary, Mythic, and SECRET fish",
        Callback = function()
            Config.SelectedTiers = {3,4,5,6,7}
            for tier, toggle in pairs(tierToggles) do toggle:SetValue(tier >= 3) end
            Fluent:Notify({ Title = "Filter Updated", Content = "Now monitoring Tier 3+ fish", Duration = 3 })
        end
    })

    Tabs.Filters:AddButton({
        Title = "High-Tier Only (Tier 5-7)",
        Description = "Enable notifications for Legendary, Mythic, and SECRET fish only",
        Callback = function()
            Config.SelectedTiers = {5,6,7}
            for tier, toggle in pairs(tierToggles) do toggle:SetValue(tier >= 5) end
            Fluent:Notify({ Title = "Filter Updated", Content = "Now monitoring Tier 5+ fish only", Duration = 3 })
        end
    })

    Tabs.Filters:AddButton({
        Title = "SECRET Only (Tier 7)",
        Description = "Enable notifications for SECRET fish only",
        Callback = function()
            Config.SelectedTiers = {7}
            for tier, toggle in pairs(tierToggles) do toggle:SetValue(tier == 7) end
            Fluent:Notify({ Title = "Filter Updated", Content = "Now monitoring SECRET fish only", Duration = 3 })
        end
    })
end

-- =========================================================
-- STATUS & TEST TAB  (callback sekarang aman)
-- =========================================================
do
    local StatusLabel = Tabs.Status:AddParagraph({ Title = "System Status",  Content = "✅ Active - Monitoring chat for fish catches..." })
    local StatsLabel  = Tabs.Status:AddParagraph({ Title = "Session Statistics", Content = "Fish notifications sent: 0\nLast notification: Never" })
    local sessionStats = { notificationsSent = 0, lastNotification = "Never" }

    Tabs.Status:AddButton({
        Title = " Test Webhook (Robot Kraken)",
        Description = "Send a test notification with Robot Kraken fish data",
        Callback = function()
            if Config.WebhookURL == "" then
                Fluent:Notify({ Title = "Error", Content = "Please set your webhook URL first!", Duration = 5 })
                return
            end

            Fluent:Notify({ Title = "Testing Webhook", Content = "Sending Robot Kraken test notification...", Duration = 3 })
            StatusLabel:SetDesc(" Testing webhook with Robot Kraken...")

            local robot = {
                Name = "Robot Kraken",
                Icon = "rbxassetid://80927639907406",
                Tier = 7,
                SellPrice = 327500,
                WeightDefaultMin = 259820,
                WeightDefaultMax = 389730,
                Chance = 2.857142857142857e-07, -- ≈ 1 in 3,500,000
            }

            local weight = math.random(robot.WeightDefaultMin, robot.WeightDefaultMax) / 1000
            local weightStr = string.format("%.2f kg", weight)
            local rarityStr = "1 in "..fmt_int(math.max(1, math.floor(1/robot.Chance + 0.5)))
            local iconUrl   = asset_to_thumb_url(robot.Icon)

            local embed = build_embed({
                playerName  = LP.DisplayName or LP.Name,
                fishName    = robot.Name,
                weightStr   = weightStr,
                rarityStr   = rarityStr,
                tierNumber  = robot.Tier,
                sellPrice   = robot.SellPrice,
                iconUrl     = iconUrl,
                totalCaught = nil,
                bagSize     = nil,
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
        end
    })

    Tabs.Status:AddButton({
        Title = " Reload Fish Data",
        Description = "Refresh fish data from GitHub repository",
        Callback = function()
            FishMap = nil
            load_fish_map()
            Fluent:Notify({ Title = "Fish Data Reloaded", Content = "Fish data has been refreshed from repository", Duration = 3 })
        end
    })

    _G.UpdateFishStatus = function(status, isError)
        local icon = isError and "" or "✅"
        StatusLabel:SetDesc(icon.." "..status)
        if not isError then
            sessionStats.notificationsSent += 1
            sessionStats.lastNotification = os.date("%H:%M:%S")
        end
        StatsLabel:SetDesc("Fish notifications sent: "..sessionStats.notificationsSent.."\nLast notification: "..sessionStats.lastNotification)
    end
end
