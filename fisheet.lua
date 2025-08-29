-- fisheet.lua — FishShit Notifier (Fluent UI)
-- Embed rapi + icon ikan: prefer HttpIcon/CDN (list.lua) → Roblox thumbnail (poll) → safe PNG fallback
-- Tambah tombol "Debug Kraken Icon" utk lihat URL gambar yang dipakai

-- ========= DEPENDENCIES (Fluent) =========
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ========= SERVICES =========
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
pcall(function() HttpService.HttpEnabled = true end)

-- ========= CONFIG =========
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"
local Config = {
    WebhookURL    = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC",
    UserID        = "905231281128898570",
    RetryAttempts = 5,
    RetryDelay    = 2,
    -- Fallback PNG yang stabil (bukan Imgur)
    FallbackIcon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Emoji_u1f41f.svg/240px-Emoji_u1f41f.svg.png"
}

-- ========= UTILS =========
local function fmt_int(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local k; repeat s,k = s:gsub("^(-?%d+)(%d%d%d)","%1,%2") until k==0; return s
end

-- Muat fish list (boleh diberi kolom HttpIcon/CDN = URL langsung)
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

-- Coba ambil Icon dari Items module (fallback terakhir jika list.lua tak ada)
local function get_game_module_icon(name)
    local ok, mod = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Items")
        return folder and folder:FindFirstChild(name)
    end)
    if not ok or not mod then return nil end
    local ok2, data = pcall(function() return require(mod) end)
    if not ok2 or not data then return nil end
    local icon = (data.Data and data.Data.Icon) or data.Icon
    return icon
end

-- Poll thumbnails.roblox.com → tr.rbxcdn.com (direct image)
local function roblox_thumbnail_url(assetIdStr)
    local id = tostring(assetIdStr or ""):match("(%d+)")
    if not id then return nil end
    local attempts, maxAttempts = 0, 10
    local delaySec = 0.7
    while attempts < maxAttempts do
        attempts += 1
        local ok, body = pcall(function()
            local url = ("https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=420x420&format=Png&isCircular=false"):format(id)
            return HttpService:GetAsync(url)
        end)
        if not ok then
            warn(("[Icon] API error (try %d/%d): %s"):format(attempts, maxAttempts, tostring(body)))
        else
            local ok2, json = pcall(function() return HttpService:JSONDecode(body) end)
            if ok2 and json and json.data and json.data[1] then
                local row = json.data[1]
                local state = tostring(row.state or "Unknown")
                local imageUrl = row.imageUrl
                print(("[Icon] assetId=%s state=%s try=%d"):format(id, state, attempts))
                if state == "Completed" and type(imageUrl) == "string" and #imageUrl > 0 then
                    print("[Icon] Completed →", imageUrl)
                    return imageUrl
                elseif state == "Blocked" or state == "Error" then
                    warn("[Icon] State "..state..", stop polling.")
                    return nil
                end
            else
                warn(("[Icon] Decode error (try %d/%d)"):format(attempts, maxAttempts))
            end
        end
        task.wait(delaySec)
    end
    return nil
end

-- Resolver utama: HttpIcon/CDN → Roblox thumbnail → fallback PNG
local function resolve_icon_url(fishName, defaultAssetId)
    -- 1) Cek list.lua
    local map = load_fish_map()
    local rec = map[fishName]
    if type(rec) == "table" then
        -- Kalau kamu tambahkan HttpIcon/CDN (URL langsung), pakai ini
        if type(rec.HttpIcon) == "string" and rec.HttpIcon:match("^https?://") then
            print("[Icon] Using HttpIcon from list.lua:", rec.HttpIcon)
            return rec.HttpIcon
        end
        if type(rec.CDN) == "string" and rec.CDN:match("^https?://") then
            print("[Icon] Using CDN from list.lua:", rec.CDN)
            return rec.CDN
        end
        -- Kalau tidak ada URL langsung, ambil Icon id-nya
        if type(rec.Icon) == "string" then
            local url = roblox_thumbnail_url(rec.Icon)
            if url then return url end
        end
    end

    -- 2) Coba dari Items module
    local modIcon = get_game_module_icon(fishName)
    if modIcon then
        local url = roblox_thumbnail_url(modIcon)
        if url then return url end
    end

    -- 3) Coba dari default asset id yang kamu kasih
    if defaultAssetId then
        local url = roblox_thumbnail_url(defaultAssetId)
        if url then return url end
    end

    -- 4) Fallback aman
    print("[Icon] Fallback PNG used:", Config.FallbackIcon)
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
        local ok = pcall(function() HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson) end)
        return ok
    end
end

-- ========= EMBED BUILDER (gaya contoh #2) =========
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
        image     = { url = args.iconUrl or "" }, -- tampil besar juga
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

-- ========= SENDER =========
local function send_webhook(embed)
    local payload = {
        username   = "FishShit Notifier",
        avatar_url = "https://i.imgur.com/9w3x9fN.png",
        content    = (Config.UserID ~= "" and "<@"..Config.UserID..">") or nil,
        allowed_mentions = { parse = {"users"} },
        embeds     = { embed },
    }
    local body = HttpService:JSONEncode(payload)
    for i=1,Config.RetryAttempts do
        local ok = http_post_json(Config.WebhookURL, body)
        if ok then return true end
        task.wait(Config.RetryDelay)
    end
    return false
end

-- ========= FLUENT UI =========
local Window = Fluent:CreateWindow({
    Title="FishShit Notifier v4.0",
    SubTitle="Discord Fish Catch Notifications",
    TabWidth=160,
    Size=UDim2.fromOffset(580,460),
    Acrylic=true,
    Theme="Dark",
    MinimizeKey=Enum.KeyCode.LeftControl
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

            -- PRIORITAS: HttpIcon/CDN → Roblox thumbnail → fallback
            local iconUrl = resolve_icon_url(fishName, "80927639907406")
            print("[FishShit] Icon URL:", iconUrl)

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

    -- DEBUG: kirim embed yang menampilkan URL ikon
    Tabs.Status:AddButton({
        Title = " Debug Kraken Icon",
        Description = "Resolve icon URL and send debug embed showing it",
        Callback = function()
            local fishName = "Robot Kraken"
            local url = resolve_icon_url(fishName, "80927639907406")
            print("[Debug] Final icon URL:", url)

            local embed = {
                title = "[DEBUG] Icon "..fishName,
                description = ("Resolved URL:\n`%s`"):format(url),
                color = 0x00ffd5,
                thumbnail = { url = url },
                image     = { url = url },
                footer = { text = "FishShit Notifier • Debug Thumbnail" },
                timestamp = DateTime.now():ToIsoDate(),
            }

            local payload = {
                username = "FishShit Notifier",
                avatar_url = "https://i.imgur.com/9w3x9fN.png",
                content = (Config.UserID ~= "" and "<@"..Config.UserID..">") or nil,
                embeds = { embed }
            }
            local body = HttpService:JSONEncode(payload)
            local ok
            if typeof(request)=="function" then
                local res = request({ Url=Config.WebhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
                ok = res and res.StatusCode and res.StatusCode>=200 and res.StatusCode<300
            else
                ok = pcall(function() HttpService:PostAsync(Config.WebhookURL, body, Enum.HttpContentType.ApplicationJson) end)
            end
            Fluent:Notify({ Title="Debug", Content= ok and "Sent debug embed." or "Failed to send debug embed.", Duration=4 })
        end
    })

    Tabs.Status:AddButton({
        Title = " Reload Fish Data",
        Description = "Reload list.lua from repo",
        Callback = function()
            FishMap=nil; load_fish_map()
            Fluent:Notify({Title="Fish Data Reloaded",Content="OK",Duration=3})
        end
    })
end
