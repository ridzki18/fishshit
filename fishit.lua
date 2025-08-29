-- fisheet.lua — FishShit Notifier (Fluent UI) — NO-HTTP thumbnail resolver
-- Ikon diambil dari ReplicatedStorage.Items[Fish].(Data.)Icon -> dibentuk jadi URL asset-thumbnail (tanpa request).
-- Tambah opsi CustomIconURL supaya bisa pakai gambar CDN kamu sendiri.

-- ====== DEPENDENCIES (Fluent) ======
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ====== SERVICES ======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService") -- hanya untuk JSON payload ke Discord
local LP = Players.LocalPlayer
pcall(function() HttpService.HttpEnabled = true end)

-- ====== CONFIG ======
local Config = {
  WebhookURL      = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC",
  UserID          = "905231281128898570",
  RetryAttempts   = 5,
  RetryDelay      = 2,
  -- Optional: kalau kamu isi dengan URL PNG sendiri, akan dipakai untuk SEMUA notifikasi
  -- (paling aman kalau environment memblokir HTTP).
  CustomIconURL   = "",  -- contoh: "https://raw.githubusercontent.com/ridzki18/fishshit/main/icons/robot_kraken.png"
  FallbackIconURL = "https://raw.githubusercontent.com/github/explore/main/topics/fish/fish.png"
}

-- ====== UTILS ======
local function fmt_int(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local k; repeat s,k = s:gsub("^(-?%d+)(%d%d%d)","%1,%2") until k==0; return s
end

-- Ambil assetId angka dari Items module
local function get_asset_id_from_items(fishName)
  local items = ReplicatedStorage:FindFirstChild("Items")
  if not items then return nil end
  local mod = items:FindFirstChild(fishName)
  if not mod then return nil end
  local ok, data = pcall(function() return require(mod) end)
  if not ok or type(data) ~= "table" then return nil end
  local icon = (data.Data and data.Data.Icon) or data.Icon
  if not icon then return nil end
  return tostring(icon):match("(%d+)")
end

-- Tanpa HTTP: bentuk URL roblox asset-thumbnail.
local function build_asset_thumb_url(assetId)
  if not assetId then return nil end
  -- endpoint gambar yang umum dipakai (Discord sering bisa fetch ini)
  return ("https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=420&height=420&format=png"):format(assetId)
end

-- Resolver ikon TANPA HTTP external call: CustomIconURL > Items asset-thumbnail > Fallback
local function resolve_icon_url_nohttp(fishName)
  if type(Config.CustomIconURL) == "string" and Config.CustomIconURL:match("^https?://") and #Config.CustomIconURL > 8 then
    print("[Icon] Using CustomIconURL:", Config.CustomIconURL)
    return Config.CustomIconURL
  end
  local id = get_asset_id_from_items(fishName)
  if id then
    local url = build_asset_thumb_url(id)
    print(("[Icon] Using asset-thumbnail for %s (id=%s): %s"):format(fishName, id, url))
    return url
  end
  print("[Icon] Using FallbackIconURL:", Config.FallbackIconURL)
  return Config.FallbackIconURL
end

-- Kirim payload ke Discord (boleh lewat request() dari executor, atau PostAsync)
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
    image     = { url = args.iconUrl or "" }, -- kirim besar juga, kalau Discord mau tampilkan
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

-- ====== FLUENT UI ======
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

-- Webhook & Icon override tab
do
  Tabs.Webhook:AddInput("WebhookURL",{Title="Discord Webhook URL",Default=Config.WebhookURL,Callback=function(v) Config.WebhookURL=v end})
  Tabs.Webhook:AddInput("UserID",{Title="Discord User ID (optional)",Default=Config.UserID,Callback=function(v) Config.UserID=v end})
  Tabs.Webhook:AddInput("CustomIconURL",{
    Title="Custom Icon URL (optional, overrides thumbnail)",
    Description="Isi dengan URL PNG/JPG untuk dipakai sebagai ikon.",
    Default=Config.CustomIconURL,
    Callback=function(v) Config.CustomIconURL=v end
  })
end

-- Status & Test
do
  local StatusLabel = Tabs.Status:AddParagraph({ Title="System Status", Content="Ready." })

  Tabs.Status:AddButton({
    Title = " Test Webhook (Robot Kraken)",
    Description = "Send styled embed + icon from Items/Robot Kraken (no HTTP resolver)",
    Callback = function()
      StatusLabel:SetDesc("Testing webhook with Robot Kraken…")

      local fishName  = "Robot Kraken"
      local tier      = 7
      local sellPrice = 327500
      local weightStr = string.format("%.2f kg", math.random(259820,389730)/1000)
      local rarityStr = "1 in 3,500,000"

      local iconUrl = resolve_icon_url_nohttp(fishName)
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
    Title = " Debug Icon URL",
    Description = "Print and send an embed showing the final icon URL used",
    Callback = function()
      local fishName = "Robot Kraken"
      local url = resolve_icon_url_nohttp(fishName)
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
end
