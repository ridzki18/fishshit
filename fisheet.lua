-- fisheet.lua — FishShit Notifier (Fluent UI)
-- Embed rapi + ikon ikan pasti muncul via thumbnails.roblox.com => tr.rbxcdn.com

-- ====== DEPENDENCIES (Fluent) ======
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ====== SERVICES ======
local Players, ReplicatedStorage, HttpService =
    game:GetService("Players"), game:GetService("ReplicatedStorage"), game:GetService("HttpService")
local LP = Players.LocalPlayer
pcall(function() HttpService.HttpEnabled = true end)

-- ====== CONFIG ======
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"
local Config = {
    WebhookURL    = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC",
    UserID        = "905231281128898570",
    RetryAttempts = 5,
    RetryDelay    = 2,
    FallbackIcon  = "https://i.imgur.com/1r4rX0M.png" -- jaga-jaga kalau API thumbnail gagal
}

-- ====== UTILS ======
local function fmt_int(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local k; repeat s,k = s:gsub("^(-?%d+)(%d%d%d)","%1,%2") until k==0; return s
end

-- Ambil URL gambar FINAL (tr.rbxcdn.com) dari thumbnails.roblox.com
local function resolve_icon_url(asset)
    local s = tostring(asset or "")
    if s:match("^https?://") then return s end
    local id = s:match("rbxassetid://(%d+)") or s:match("(%d+)")
    if not id then
        return Config.FallbackIcon
    end

    local ok, body = pcall(function()
        local url = ("https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=420x420&format=Png&isCircular=false"):format(id)
        return HttpService:GetAsync(url)
    end)
    if ok and body then
        local ok2, json = pcall(function() return HttpService:JSONDecode(body) end)
        if ok2 and json and json.data and json.data[1] and type(json.data[1].imageUrl)=="string" and #json.data[1].imageUrl>0 then
            return json.data[1].imageUrl -- contoh: https://tr.rbxcdn.com/<hash>/420/420/Image/Png
        end
    end
    return Config.FallbackIcon
end

local function http_post_json(url, json)
    if typeof(request) == "function" then
        local ok,res = pcall(function()
            return request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=json })
        end)
        if ok and res and res.StatusCode and res.StatusCode>=200 and res.StatusCode<300 then return true,res.Body end
        return false, res and (res.StatusMessage or res.StatusCode) or "request() failed"
    else
        local ok, body = pcall(function() return HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson) end)
        return ok, body
    end
end

-- ====== FISH LIST (opsional dari repo) ======
local FishMap
local function load_fish_map()
    if FishMap then return FishMap end
    local ok,src = pcall(function() return game:HttpGet(FISH_LIST_URL) end)
    if not ok or not src then FishMap = {}; return FishMap end
    local chunk = loadstring(src)
    local ok2,tbl = pcall(chunk)
    FishMap = (ok2 and type(tbl)=="table") and tbl or {}
    return FishMap
end

-- ====== EMBED BUILDER (gaya contoh #2) ======
local TierName  = { [1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary",[6]="Mythic",[7]="SECRET" }
local TierColor = { [1]=0x9ea7b3,[2]=0x86c06c,[3]=0x3b82f6,[4]=0xa855f7,[5]=0xf59e0b,[6]=0xef4444,[7]=0x00ffd5 }

local function build_embed(args)
    local tier  = tonumber(args.tierNumber or 5) or 5
    local color = TierColor[tier] or 0x3b82f6
    local tname = TierName[tier] or tostring(tier)

    return {
        title = ("A high-tier fish was caught by %s!"):format(args.playerName or "-"),
        color = color,
        thumbnail = { url = args.iconUrl or "" },
        image     = { url = args.iconUrl or "" }, -- tampil besar juga, supaya pasti terlihat
        fields = {
            { name = "Fish Name 🐟", value = ("`%s`"):format(args.fishName or "-"), inline = false },
            { name = "Weight ⚖️",    value = ("`%s`"):format(args.weightStr or "-"), inline = true },
            { name = "Rarity ✨",    value = ("`%s`"):format(args.rarityStr or "-"), inline = true },
            { name = "Tier 🏆",      value = ("`%s`"):format(tname), inline = true },
            { name = "Sell Price 🪙",value = ("`%s`"):format(fmt_int(args.sellPrice or 0)), inline = true },
        },
        footer = { text = "FishShit Notifier" },
        timestamp = DateTime.now():ToIsoDate(),
    }
end

-- ====== SENDER ======
local function send_webhook(embed)
    local payload = {
        username   = "FishShit Notifier",
        avatar_url = "https://i.imgur.com/9w3x9fN.png",
        embeds     = { embed },
        content    = (Config.UserID ~= "" and "<@"..Config.UserID..">") or nil,
        allowed_mentions = { parse = {"users"} }
    }
    local body = HttpService:JSONEncode(payload)
    for i=1,Config.RetryAttempts do
        local ok = http_post_json(Config.WebhookURL, body)
        if ok then return true end
        task.wait(Config.RetryDelay)
    end
    return false
end

-- ====== FLUENT UI ======
local Window = Fluent:CreateWindow({
    Title="FishShit Notifier v4.0", SubTitle="Discord Fish Catch Notifications",
    TabWidth=160, Size=UDim2.fromOffset(580,460), Acrylic=true, Theme="Dark", MinimizeKey=Enum.KeyCode.LeftControl
})
local Tabs = {
    Main    = Window:AddTab({ Title="Main Settings", Icon="settings" }),
    Webhook = Window:AddTab({ Title="Webhook Config", Icon="globe" }),
    Filters = Window:AddTab({ Title="Fish Filters", Icon="filter" }),
    Status  = Window:AddTab({ Title="Status & Test", Icon="activity" })
}

-- Webhook tab
do
    Tabs.Webhook:AddInput("WebhookURL",{Title="Discord Webhook URL",Default=Config.WebhookURL,Callback=function(v) Config.WebhookURL=v end})
    Tabs.Webhook:AddInput("UserID",{Title="Discord User ID (optional)",Default=Config.UserID,Callback=function(v) Config.UserID=v end})
end

-- Status & Test
do
    local StatusLabel = Tabs.Status:AddParagraph({ Title="System Status", Content="Ready." })

    Tabs.Status:AddButton({
        Title = " Test Webhook (Robot Kraken)",
        Description = "Send styled embed + show fish image",
        Callback = function()
            StatusLabel:SetDesc("Testing webhook with Robot Kraken…")

            local fishName  = "Robot Kraken"
            local tier      = 7
            local sellPrice = 327500
            local weightStr = string.format("%.2f kg", math.random(259820,389730)/1000)
            local rarityStr = "1 in 3,500,000"

            -- Ambil icon dari list.lua bila ada; fallback id ini
            local iconSrc = "rbxassetid://80927639907406"
            local map = load_fish_map()
            if type(map)=="table" and map[fishName] and map[fishName].Icon then
                iconSrc = tostring(map[fishName].Icon)
            end
            local iconUrl = resolve_icon_url(iconSrc)

            -- log url (untuk debug cepat di output)
            print("[FishShit] Icon URL: ", iconUrl)

            local embed = build_embed({
                playerName = LP.DisplayName or LP.Name,
                fishName   = fishName,
                weightStr  = weightStr,
                rarityStr  = rarityStr,
                tierNumber = tier,
                sellPrice  = sellPrice,
                iconUrl    = iconUrl
            })

            local ok = send_webhook(embed)
            StatusLabel:SetDesc(ok and "✅ Webhook sent." or "❌ Webhook failed.")
        end
    })

    Tabs.Status:AddButton({
        Title = " Reload Fish Data",
        Description = "Reload list.lua from repo",
        Callback = function() FishMap=nil; load_fish_map(); Fluent:Notify({Title="Fish Data Reloaded",Content="OK",Duration=3}) end
    })
end
