-- GABRIEL • Discord Webhook Test (UI by x2zu, customized)
-- Hanya 1 panel untuk test send. Title + logo diganti.
-- Usage: isi webhook URL → klik "Test Send".

-- ========= HTTP compat (executor) =========
local http = (syn and syn.request) or http_request or request
local function HAS_HTTP() return typeof(http) == "function" end
local HttpService = game:GetService("HttpService")

-- ========= Load x2zu UI library =========
local LIB_URL = "https://raw.githubusercontent.com/x2zu/OPEN-SOURCE-UI-ROBLOX/refs/heads/main/X2ZU%20UI%20ROBLOX%20OPEN%20SOURCE/ExampleNewUI.lua"
local okLib, Library = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
if not okLib then
    warn("[GABRIEL] gagal load UI library:", Library)
    return
end

-- ========= Create minimal window =========
local Window = Library:CreateWindow("GABRIEL")   -- text di header (akan di-patch juga di bawah)
-- Buat satu tab saja (namanya bebas, tidak tampil sebagai list banyak)
local Tab = Window:CreateTab("Webhook")

-- ---- Patch tampilan (hapus menu default, ganti judul & logo) ----
task.defer(function()
    -- coba cari ScreenGui/Frame dari library, lalu modifikasi
    local player = game:GetService("Players").LocalPlayer
    local pg = player:WaitForChild("PlayerGui", 10)
    if not pg then return end

    local function isString(x) return typeof(x)=="string" end
    local function deepPatch(gui)
        for _,inst in ipairs(gui:GetDescendants()) do
            -- Ganti judul "STELLAR x2zu Project" menjadi "GABRIEL"
            if inst:IsA("TextLabel") or inst:IsA("TextButton") then
                local t = inst.Text
                if isString(t) then
                    if t:lower():find("stellar") or t:lower():find("x2zu") then
                        inst.Text = "GABRIEL"
                    end
                    -- sembunyikan item sidebar default
                    local low = t:lower()
                    if low == "information" or low=="main" or low=="farming" or low=="items"
                        or low=="setting" or low=="local player" or low=="localplayer" then
                        inst.Parent.Visible = false
                        inst.Visible = false
                    end
                end
            elseif inst:IsA("ImageLabel") then
                -- ganti logo header kalau ada icon default
                if (inst.Image and #inst.Image > 0) then
                    -- heuristik: header icon sering di pojok; pokoknya set semua ImageLabel di header pertama
                    inst.Image = "https://i.pinimg.com/736x/f8/ba/35/f8ba35d0f641058d208e2427af242e6c.jpg"
                end
            end
        end
    end
    -- cari ScreenGui buatan library (biasanya 1 yang baru muncul)
    for _,sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") then
            pcall(deepPatch, sg)
        end
    end
end)

-- ========= Simple form controls =========
local State = { webhook = "", userId = "" }

Tab:CreateBox("Webhook URL", function(val)
    State.webhook = val or ""
end)

Tab:CreateBox("Discord User ID (optional)", function(val)
    State.userId = val or ""
end)

Tab:CreateButton("Test Send", function()
    if not HAS_HTTP() then
        Library:Notify("❌ Executor tidak support HTTP (syn.request/http_request).", 4)
        warn("[GABRIEL] HTTP not available")
        return
    end
    if State.webhook == "" then
        Library:Notify("Masukkan Webhook URL dulu.", 3)
        return
    end

    local embed = {
        title = "Test Send ✅",
        description = "If you see this, webhook works!",
        color = 0x2ECC71,
        thumbnail = { url = "https://i.pinimg.com/736x/f8/ba/35/f8ba35d0f641058d208e2427af242e6c.jpg" },
        fields = {
            { name = "Sample", value = "Blob Fish", inline = true },
            { name = "Tier",   value = "Mythic",   inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "GABRIEL • test" },
    }
    local payload = {
        username = "Fish Notifier",
        content = (State.userId ~= "" and ("<@"..State.userId..">") or ""),
        embeds  = { embed },
    }

    local ok, err = pcall(function()
        http({
            Url = State.webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)

    if ok then
        Library:Notify("✅ Test terkirim ke Discord!", 4)
        print("[GABRIEL] test sent")
    else
        Library:Notify("❌ Gagal kirim: "..tostring(err), 5)
        warn("[GABRIEL] send failed:", err)
    end
end)

-- kosmetik kecil: info cara pakai
Tab:CreateLabel("Isi Webhook URL → klik Test Send.")

print("[GABRIEL] UI siap. Ganti judul & logo sudah diterapkan. Isi webhook dan klik Test Send.")
