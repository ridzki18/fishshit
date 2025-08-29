-- fisheet.lua — FishShit Notifier (Fluent UI)
-- Versi: gunakan list.lua + kirim ikon ke embed.thumbnail.url (bukan image)
-- Tampilan embed rapi (fields) seperti contoh #2.

-- ====== DEPENDENCIES (Fluent UI) ======
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ====== SERVICES ======
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local LP                 = Players.LocalPlayer
pcall(function() HttpService.HttpEnabled = true end)

-- ====== CONFIG ======
local FISH_LIST_URL = "https://raw.githubusercontent.com/ridzki18/fishshit/refs/heads/main/list.lua"
local Config = {
  WebhookURL       = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC",
  UserID           = "905231281128898570",
  RetryAttempts    = 5,
  RetryDelay       = 2,
  UseBigImageAlso  = false, -- kalau true, selain thumbnail juga kirim embed.image
  FallbackIconURL  = "https://raw.githubusercontent.com/github/explore/main/topics/fish/fish.png" -- aman kalau icon tidak ketemu
}

-- ====== HELPERS ======
local function fmt_int(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local k; repeat s,k = s:gsub("^(-?%d+)(%d%d%d)","%1,%2") until k==0; return s
end

-- Load fish list dari repo (berisi mapping "Nama Ikan" -> { Icon=..., Tier=..., SellPrice=..., ... })
local FishMap
local function load_fish_map()
  local ok,src = pcall(function() return game:HttpGet(FISH_LIST_URL) end)
  if not ok or not src then FishMap = {}; return FishMap end
  local chunk = loadstring(src)
  local ok2, tbl = pcall(chunk)
  FishMap = (ok2 and type(tbl)=="table") and tbl or {}
  return FishMap
end

-- Ambil record ikan dari list.lua; kalau tidak ada, coba module di ReplicatedStorage.Items
local function get_fish_record(fishName)
  local map = FishMap or load_fish_map()
  local rec = map[fishName]
  if rec then return rec end

  -- fallback: require Items module
  local items = ReplicatedStorage:FindFirstChild("Items")
  local mod   = items and items:FindFirstChild(fishName)
  if not mod then return nil end
  local ok, data = pcall(function() return require(mod) end)
  if not ok or type(data) ~= "table" then return nil end

  local icon = (data.Data and data.Data.Icon) or data.Icon
  local tier = (data.Data and data.Data.Tier) or data.Tier
  local sp   = data.SellPrice
  return { Icon = icon, Tier = tier, SellPrice = sp }
end

-- Bangun URL thumbnail:
-- 1) Jika rec.HttpIcon/CDN ada (URL langsung), pakai itu
-- 2) Jika Icon berupa rbxassetid://<id>, bentuk URL asset-thumbnail (tanpa HTTP GET)
local function resolve_icon_url(rec)
  if type(rec)=="table" then
    if type(rec.HttpIcon)=="string" and rec.HttpIcon:match("^https?://") then
      return rec.HttpIcon
    end
    if type(rec.CDN)=="string" and rec.CDN:match("^https?://") then
      return rec.CDN
    end
    if rec.Icon then
      local id = tostring(rec.Icon):match("(%d+)")
      if id then
        return ("https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=420&height=420&format=png"):format(id)
      end
    end
  end
  return Config.FallbackIconURL
end

-- Kirim payload ke Discord
local function http_post_json(url, json)
  if typeof(request)=="function" then
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

-- ====== EMBED BUILDER (seperti contoh #2) ======
local TierName  = { [1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary",[6]="Mythic",[7]="SECRET" }
local TierColor = { [1]=0x9ea7b3,[2]=0x86c06c,[3]=0x3b82f6,[4]=0xa855f7,[5]=0xf59e0b,[6]=0xef4444,[7]=0x00ffd5 }

local function build_embed(args)
  local tier  = tonumber(args.tierNumber or 5) or 5
  local color = TierColor[tier] or 0x3b82f6
  local tname = TierName[tier] or tostring(tier)

  local e = {
    title     = ("A high-tier fish was caught by %s!"):format(args.playerName or "-"),
    color     = color,
    thumbnail = { url = args.iconUrl or "" },                  -- <- penting: thumbnail
    fields    = {
      { name = "Fish Name 🐟", value = ("`%s`"):format(args.fishName or "-"), inline = false },
      { name = "Weight ⚖️",    value = ("`%s`"):format(args.weightStr or "-"), inline = true },
      { name = "Rarity ✨",    value = ("`%s`"):format(args.rarityStr or "-"), inline = true },
      { name = "Tier 🏆",      value = ("`%s`"):format(tname), inline = true },
      { name = "Sell Price 🪙",value = ("`%s`"):format(fmt_int(args.sellPrice or 0)), inline = true },
    },
    footer    = { text = "FishShit Notifier" },
    timestamp = DateTime.now():ToIsoDate(),
  }

  if Config.UseBigImageAlso and args.iconUrl and #args.iconUrl>0 then
    e.image = { url = args.iconUrl }                           -- opsional: gambar besar
  end

  return e
end

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

-- ====== UI (Fluent) ======
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
  Tabs.Webhook:AddToggle("UseBigImageAlso",{
    Title="Also send big image (embed.image)",
    Default=Config.UseBigImageAlso,
    Callback=function(v) Config.UseBigImageAlso = v end
  })
end

-- Status & Test
do
  local StatusLabel = Tabs.Status:AddParagraph({ Title="System Status", Content="Ready." })

  Tabs.Status:AddButton({
    Title = " Test Webhook (Robot Kraken)",
    Description = "Send styled embed (thumbnail from list.lua)",
    Callback = function()
      StatusLabel:SetDesc("Testing webhook with Robot Kraken…")

      local fishName  = "Robot Kraken"
      local rec       = get_fish_record(fishName) or {}
      local iconUrl   = resolve_icon_url(rec)
      local tier      = tonumber(rec.Tier) or 7
      local sellPrice = tonumber(rec.SellPrice) or 327500

      local minW, maxW = 259820, 389730
      local weightStr = string.format("%.2f kg", math.random(minW, maxW)/1000)
      local rarityStr = "1 in 3,500,000"

      print("[FishShit] Using icon URL:", iconUrl)

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
    Callback = function()
      FishMap = nil
      load_fish_map()
      Fluent:Notify({Title="Fish Data Reloaded", Content="OK", Duration=3})
    end
  })

  Tabs.Status:AddButton({
    Title = " Debug Icon (show URL)",
    Description = "Print and send embed showing the icon URL being used",
    Callback = function()
      local fishName  = "Robot Kraken"
      local rec       = get_fish_record(fishName) or {}
      local iconUrl   = resolve_icon_url(rec)

      local embed = {
        title = "[DEBUG] Icon "..fishName,
        description = ("Thumbnail URL:\n`%s`"):format(iconUrl),
        color = 0x00ffd5,
        thumbnail = { url = iconUrl },
        footer = { text = "FishShit Notifier • Debug Thumbnail" },
        timestamp = DateTime.now():ToIsoDate(),
      }

      local payload = {
        username   = "FishShit Notifier",
        avatar_url = "https://i.imgur.com/9w3x9fN.png",
        embeds     = { embed },
        content    = (Config.UserID ~= "" and "<@"..Config.UserID..">") or nil
      }
      local body = HttpService:JSONEncode(payload)
      local ok
      if typeof(request)=="function" then
        local res = request({ Url=Config.WebhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
        ok = res and res.StatusCode and res.StatusCode>=200 and res.StatusCode<300
      else
        ok = pcall(function() HttpService:PostAsync(Config.WebhookURL, body, Enum.HttpContentType.ApplicationJson) end)
      end
      Fluent:Notify({ Title="Debug", Content= ok and "Sent." or "Failed.", Duration=3 })
    end
  })
end
