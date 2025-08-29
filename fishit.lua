-- fisheet.lua
-- FishShit Notifier – Webhook Test Fixed

----------------------------
-- CONFIG TEST (HARDCODE) --
----------------------------
local TEST_WEBHOOK = "https://discord.com/api/webhooks/1410933804805128263/sR-Bjsr7xuXrIfU2w6qqSXNnJB9z8Xnc_hPNbnLm6FzRn3GiRFjviL-eJsaZ7I9pMSNC"
local TEST_USER_ID  = "905231281128898570"

-------------------------
-- SERVICES & HELPERS  --
-------------------------
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local StarterGui  = game:GetService("StarterGui")
local CoreGui     = game:GetService("CoreGui")
local UIS         = game:GetService("UserInputService")

-- Wrapper HTTP request: support executor (syn/fluxus/krnl) dan Roblox Studio
local function getHttpRequest()
    local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (krnl and krnl.request) or request
    if req then
        return function(opts)
            local res = req({ Url = opts.Url, Method = opts.Method or "GET", Headers = opts.Headers or {}, Body = opts.Body })
            return { StatusCode = (res.StatusCode or res.Status or 0), Body = (res.Body or res.body or "") }
        end
    else
        return function(opts)
            local r = HttpService:RequestAsync({ Url = opts.Url, Method = opts.Method or "GET", Headers = opts.Headers or {}, Body = opts.Body })
            return { StatusCode = r.StatusCode, Body = r.Body }
        end
    end
end
local httpRequest = getHttpRequest()

local function notify(title, text, duration)
    pcall(function() StarterGui:SetCore("SendNotification", { Title = title or "FishShit", Text = text or "", Duration = duration or 4 }) end)
    print(string.format("[FishShit] %s - %s", tostring(title), tostring(text)))
end

--------------------------------
-- CORE: SEND WEBHOOK (JSON)  --
--------------------------------
local function sendWebhook(url, payload)
    assert(type(url) == "string" and url:match("^https://discord%.com/api/webhooks/"), "Invalid Discord webhook URL")
    local body = HttpService:JSONEncode(payload)
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end)
    if not ok then return false, ("request pcall failed: %s"):format(tostring(res)) end
    if not res then return false, "no response" end
    local code = tonumber(res.StatusCode or 0) or 0
    if code >= 200 and code < 300 then return true, ("HTTP %d OK"):format(code) end
    return false, ("HTTP %d; body: %s"):format(code, tostring(res.Body))
end

----------------------------
-- PUBLIC: TEST WEBHOOK   --
----------------------------
local function buildTestEmbed()
    local player   = Players.LocalPlayer
    local username = (player and player.Name) or "Unknown Player"
    return {
        ["title"]       = "🎣 Test Webhook - Robot Kraken",
        ["description"] = "Notifikasi uji dari FishShit Notifier.",
        ["color"]       = 3447003,
        ["fields"]      = { { name = "Player", value = ("`%s`"):format(username), inline = true }, { name = "Mode", value = "`Test Only`", inline = true }, },
        ["footer"]      = { ["text"] = "FishShit Notifier" },
        ["timestamp"]   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

local function TestWebhook()
    notify("Testing Webhook", "Sending Robot Kraken test notification...", 3)
    local payload = { content = "<@" .. TEST_USER_ID .. "> Test notification!", embeds = { buildTestEmbed() } }
    local ok, info = sendWebhook(TEST_WEBHOOK, payload)
    if ok then
        notify("Webhook", "✅ Test terkirim", 4)
        print("[FishShit] Test webhook sent:", info)
    else
        notify("Webhook", "❌ Gagal kirim (cek Output)", 6)
        warn("[FishShit] Test webhook failed:", info)
    end
end

------------------------------------------------
-- OPTIONAL: SIMPLE UI (untuk jalankan langsung)
------------------------------------------------
local function ensureSimpleUI()
    local guiName = "FishShitNotifierUI"
    local root = CoreGui:FindFirstChild(guiName)
    if not root then
        root = Instance.new("ScreenGui")
        root.Name = guiName
        root.ResetOnSpawn = false
        root.IgnoreGuiInset = true
        root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        root.Parent = CoreGui
    end

    local frame = Instance.new("Frame")
    frame.Name = "Window"
    frame.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    frame.Size = UDim2.fromOffset(420, 160)
    frame.Position = UDim2.fromScale(0.5, 0.2)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Parent = root
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Text = "FishShit Notifier – Status & Test"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(235, 240, 255)
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.fromOffset(380, 24)
    title.Parent = frame

    -- draggable
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local btn = Instance.new("TextButton")
    btn.Text = "🧪 Test Webhook (Robot Kraken)"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 16
    btn.TextColor3 = Color3.fromRGB(20, 22, 28)
    btn.BackgroundColor3 = Color3.fromRGB(115, 225, 160)
    btn.Size = UDim2.fromOffset(380, 40)
    btn.Position = UDim2.fromOffset(20, 60)
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(TestWebhook)

    local note = Instance.new("TextLabel")
    note.Text = "Config test hardcoded – hanya untuk pengujian."
    note.Font = Enum.Font.Gotham
    note.TextSize = 13
    note.TextColor3 = Color3.fromRGB(180, 190, 210)
    note.BackgroundTransparency = 1
    note.Position = UDim2.fromOffset(20, 110)
    note.Size = UDim2.fromOffset(380, 20)
    note.Parent = frame
end

------------------------
-- MODULE / EXECUTION --
------------------------
local FishShit = {}
FishShit.TestWebhook = TestWebhook
FishShit.SendWebhook = sendWebhook

-- Jika skrip ini dieksekusi langsung (bukan require), tampilkan UI sederhana:
local ranAsModule = false
pcall(function() ranAsModule = (getfenv and getfenv(2) ~= nil) end)
if not ranAsModule then
    ensureSimpleUI()
end

return FishShit
