--// Fish It Webhook Notifier + X2ZU Open Source UI
--// jalankan: loadstring(game:HttpGet("https://raw.githubusercontent.com/<username>/<repo>/main/fishit_x2zu.lua"))()

---------------- HTTP Compat ----------------
local http = (syn and syn.request) or http_request or request
local function hasHttp() return typeof(http)=="function" end
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

---------------- Config ----------------
local CFG = {
    enable = false,
    webhook = "",
    discordUserId = "",
    tiers = {Legendary=true, Mythic=true, SECRET=true},
}

---------------- Load UI Library ----------------
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/x2zu/OPEN-SOURCE-UI-ROBLOX/refs/heads/main/X2ZU%20UI%20ROBLOX%20OPEN%20SOURCE/ExampleNewUI.lua"))()

local Win = Library:CreateWindow("FishIt Webhook")
local Main = Win:CreateTab("Main")

---------------- UI Elements ----------------
Main:CreateToggle("Enable Notifications", CFG.enable, function(val)
    CFG.enable = val
end)

Main:CreateToggle("Notify Legendary", CFG.tiers.Legendary, function(val)
    CFG.tiers.Legendary = val
end)
Main:CreateToggle("Notify Mythic", CFG.tiers.Mythic, function(val)
    CFG.tiers.Mythic = val
end)
Main:CreateToggle("Notify SECRET", CFG.tiers.SECRET, function(val)
    CFG.tiers.SECRET = val
end)

Main:CreateBox("Webhook URL", function(val)
    CFG.webhook = val
end)

Main:CreateBox("Discord User ID", function(val)
    CFG.discordUserId = val
end)

Main:CreateButton("Test Send", function()
    if not hasHttp() then return warn("executor tidak support http") end
    if CFG.webhook=="" then return warn("isi webhook dulu") end
    local embed = {
        title="Test Send ✅",
        description="If you see this, webhook works!",
        color=0x2ECC71,
        timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    local payload = {
        username="Fish Notifier",
        content=(CFG.discordUserId~="" and "<@"..CFG.discordUserId..">" or ""),
        embeds={embed},
    }
    http({Url=CFG.webhook,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(payload)})
    print("[fishit] ✅ Test sent")
end)

---------------- Tiers/Items lookup ----------------
local TIERS_BY_INDEX={}
do
    local ok,tiers=pcall(function() return require(RS:WaitForChild("Tiers")) end)
    if ok then for _,t in ipairs(tiers) do TIERS_BY_INDEX[t.Tier]=t end end
end
local function c3ToInt(c) return math.floor(c.R*255)*65536+math.floor(c.G*255)*256+math.floor(c.B*255) end
local function firstColor(cs) return (typeof(cs)=="ColorSequence" and cs.Keypoints[1] and cs.Keypoints[1].Value) or cs or Color3.fromRGB(88,101,242) end
local function lookupFish(name)
    local f=RS:FindFirstChild("Items"); if not f then return{} end
    local ms=f:FindFirstChild(name); if not (ms and ms:IsA("ModuleScript")) then return{} end
    local ok,d=pcall(require,ms); if not ok then return{} end
    local t=TIERS_BY_INDEX[d.Data and d.Data.Tier]; return {
        sellPrice=d.SellPrice, icon=d.Data and d.Data.Icon or "",
        tierName=t and t.Name or ("Tier "..tostring(d.Data.Tier)),
        color=t and c3ToInt(firstColor(t.TierColor)) or 0x5865F2,
    }
end

---------------- Discord Sender ----------------
local function sendCatch(pName,fName,weight,chanceN)
    if CFG.webhook=="" or not CFG.enable then return end
    local info=lookupFish(fName)
    -- filter tier
    if not CFG.tiers[info.tierName] then return end
    local embed={
        title=string.format("A high-tier fish was caught by %s!",pName or "Someone"),
        color=info.color,thumbnail={url=info.icon},
        fields={
            {name="Fish Name",value=fName,inline=false},
            {name="Weight",value=weight or "-",inline=true},
            {name="Rarity",value=(chanceN>0 and "1 in "..chanceN or "-"),inline=true},
            {name="Tier",value=info.tierName or "-",inline=true},
            {name="Sell Price",value=info.sellPrice and tostring(info.sellPrice) or "-",inline=true},
        },
        timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    local payload={username="Fish Notifier",content=(CFG.discordUserId~="" and "<@"..CFG.discordUserId..">" or ""),embeds={embed}}
    http({Url=CFG.webhook,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(payload)})
end

---------------- Chat Parser ----------------
local ChatEvents=RS:FindFirstChild("DefaultChatSystemChatEvents")
local OnMsg=ChatEvents and ChatEvents:FindFirstChild("OnMessageDoneFiltering")
local PATTERN="%[Server%]%:%s*([%w_%-]+)%s+obtained an?%s+(.+)%s+%(([%d%.]+%a)%)%s+with a 1 in%s+([%d,%.KkMm]+)%s+chance"
local function normalizeN(str) str=str:gsub(",",""); local k=str:match("^([%d%.]+)[Kk]$"); if k then return math.floor(tonumber(k)*1e3+0.5) end; local m=str:match("^([%d%.]+)[Mm]$"); if m then return math.floor(tonumber(m)*1e6+0.5) end; return tonumber(str) or 0 end
if OnMsg then
    OnMsg.OnClientEvent:Connect(function(d)
        if not CFG.enable then return end
        local who,f,w,n=d.Message:match(PATTERN)
        if f then sendCatch(who,f,w,normalizeN(n)) end
    end)
else
    warn("[fishit] Chat events not found; wait until DefaultChatSystemChatEvents exists.")
end

print("[fishit] Webhook notifier w/ X2ZU UI loaded. Isi Webhook URL, klik Test Send untuk debug, lalu ON-kan toggle.")
