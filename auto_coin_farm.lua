task.wait(10)

-- БЫСТРЫЙ СБОР МОНЕТ + НОКЛИП + ЧЁРНЫЙ СПИСОК
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

local COLLECTIBLE_NAME = "Coin_Server"
local FLY_SPEED = 30
local STOP_DISTANCE = 1
local SEARCH_RADIUS = 80
local NOCLIP_RADIUS = 400
local BLACKLIST_TIME = 3  -- игнорируем монету 3 секунду после подлёта
local COIN_COLLECTED = 0

local bodyVelocity = nil
local noclipActive = false
local blacklist = {}  -- чёрный список монет

-- Анти-АФК
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- НОКЛИП В РАДИУСЕ
local function setNoclipInRadius(enabled)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(char) then
            local dist = (root.Position - obj.Position).Magnitude
            if dist < NOCLIP_RADIUS then
                obj.CanCollide = not enabled
            end
        end
    end
    noclipActive = enabled
end

-- ПОЛЁТ
local function setFly(enabled)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    
    if enabled then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid.PlatformStand = true
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(1e8, 1e8, 1e8)
            bodyVelocity.Parent = root
        end
    else
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid.PlatformStand = false
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
end

-- ЧЁРНЫЙ СПИСОК
local function isBlacklisted(coin)
    local expire = blacklist[coin]
    if expire and tick() < expire then
        return true
    end
    return false
end

local function addToBlacklist(coin)
    blacklist[coin] = tick() + BLACKLIST_TIME
end

-- ПОИСК МОНЕТЫ (с учётом чёрного списка)
local function getClosestCoin()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local closest = nil
    local minDist = math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == COLLECTIBLE_NAME and obj:IsA("BasePart") and obj.Parent then
            if not isBlacklisted(obj) then
                local dist = (root.Position - obj.Position).Magnitude
                if dist < minDist and dist < SEARCH_RADIUS then
                    minDist = dist
                    closest = obj
                end
            end
        end
    end
    return closest, minDist
end

-- ОСНОВНОЙ ЦИКЛ
task.spawn(function()
    while true do
        local coin, dist = getClosestCoin()
        
        if coin then
            -- Включаем ноклип и полёт (если ещё не включены)
            if not noclipActive then
                setNoclipInRadius(true)
                setFly(true)
            end
            
            -- Летим к монете
            if dist > STOP_DISTANCE then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root and bodyVelocity then
                    local dir = (coin.Position - root.Position).Unit
                    bodyVelocity.Velocity = dir * FLY_SPEED
                end
            else
                -- Достигли монеты → добавляем в чёрный список
                addToBlacklist(coin)
                if bodyVelocity then
                    bodyVelocity.Velocity = Vector3.new()
                end
                COIN_COLLECTED = COIN_COLLECTED + 1
                task.wait(0.2)
                if COIN_COLLECTED > 39 then
                    COIN_COLLECTED = 0
                    local char = game:GetService("Players").LocalPlayer.Character
                    if char then
                        local humanoid = char:FindFirstChild("Humanoid")
                        if humanoid then
                            humanoid.Health = 0
                            task.wait(2)
                        end
                    end
                end
            end
            task.wait()
        else
            -- Нет монет → выключаем ноклип и полёт
            if noclipActive then
                setNoclipInRadius(false)
                setFly(false)
            end
            task.wait(1)
        end
    end
end)