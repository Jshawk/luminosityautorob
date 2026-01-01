-- Luminosity Auto Rob Script
local LUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jshawk/luminosity-lite/refs/heads/main/Luminosity%20Lite%20UI.lua"))()
-- OR if you have it locally: local LUI = require(script.Parent.AutorubUILib)

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")

-- Local player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Variables
local autoRobberyEnabled = false
local tweening = false
local currentTween
local noclipEnabled = false
local noclipConnection
local currentSpeed = 35 -- studs per second
local db = true -- debounce for actions
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")

-- functions

-- Use VirtualInputManager to simulate Q press and left mouse click
local function SimulateQAndClick()
    local VirtualInput = game:GetService("VirtualInputManager")
    -- Press Q (toggle)
    VirtualInput:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
    wait(0.05)
    VirtualInput:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
    wait(0.05)
    -- Left mouse button down at center of screen
    local viewport = Workspace.CurrentCamera.ViewportSize
    local centerX, centerY = math.floor(viewport.X/2), math.floor(viewport.Y/2)
    VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
    wait(0.1)
    VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
end

-- Event IDs
local PICKUP_EVENT = "7a985dd7-2744-4a3e-a4cd-7904f9a36418"
local BUY_BOMB_EVENT = "64084741-be8f-4afd-8a31-b0bc1c709bee"
local SELL_EVENT = "67993222-e592-4017-9bdb-5e29e21caa9b"
local EQUIP_BOMB_EVENT = "6f1bcb4a-5f97-40b7-9cfd-f18a2b49dc88"
local THROW_BOMB_EVENT = "378e7a3e-df44-48dd-94d8-ecc6f94922fb"
local DETONATE_BOMB_EVENT = "13b18c39-ae98-4b46-b8f3-eca379d3b7fc"

-- Bank locations
local BANK_LOCATIONS = {
    VaultDoor = Vector3.new(-1242.76245, 10.7318954, 3143.84448),
    VaultLeft = Vector3.new(-1249.96887, 4.8947525, 3103.28906),
    VaultRight = Vector3.new(-1232.76245, 10.7318954, 3122.84448)
}

-- Dealer location (will be auto-detected)
local DEALER_POSITION = nil

-- Camera control
local camera = Workspace.CurrentCamera

-- Mouse object for simulation
local mouse = player:GetMouse()

-- Noclip functions
local function enableNoclip()
    if noclipEnabled then return end
    noclipEnabled = true
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    noclipConnection = RunService.Stepped:Connect(function()
        if character and noclipEnabled then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

local function disableNoclip()
    if not noclipEnabled then return end
    noclipEnabled = false
    if noclipConnection then noclipConnection:Disconnect() end
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- Auto-find dealer function
local function findDealerPosition()
    print("🔍 Searching for dealer...")
    
    for _, npc in pairs(Workspace:GetDescendants()) do
        if npc:IsA("Model") and npc.Name:lower():find("dealer") then
            if npc:FindFirstChild("HumanoidRootPart") then
                DEALER_POSITION = npc.HumanoidRootPart.Position
                print("✅ Found dealer NPC:", npc.Name)
                return true
            elseif npc.PrimaryPart then
                DEALER_POSITION = npc.PrimaryPart.Position
                print("✅ Found dealer NPC:", npc.Name)
                return true
            end
        end
    end
    
    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower():find("dealer") then
            DEALER_POSITION = part.Position
            print("✅ Found dealer part:", part.Name)
            return true
        end
    end
    
    print("❌ Could not auto-find dealer")
    return false
end

-- Save current position as dealer
local function saveCurrentPositionAsDealer()
    DEALER_POSITION = humanoidRootPart.Position
    print("✅ Saved current position as dealer!")
end

-- Camera look at function
local function lookAtTarget(targetPosition)
    -- Calculate direction to look
    local direction = (targetPosition - humanoidRootPart.Position).Unit
    
    -- Create a CFrame looking at the target
    local lookCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)
    
    -- Smoothly rotate character
    local tween = TweenService:Create(humanoidRootPart,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = lookCFrame}
    )
    tween:Play()
    tween.Completed:Wait()
    
    -- Also point camera at target
    camera.CFrame = CFrame.new(camera.CFrame.Position, targetPosition)
end

-- Updated bomb throwing sequence
local function throwBombAtVault()
    print("💣 Starting bomb throw sequence...")
    -- Step 1: Look at vault door
    print("  1. Looking at vault door...")
    lookAtTarget(BANK_LOCATIONS.VaultDoor)
    wait(0.5)
    -- Step 2: Equip bomb (if not already equipped)
    print("  2. Equipping bomb...")
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(EQUIP_BOMB_EVENT)
    local args = {"Bomb"}
    event:FireServer(unpack(args))
    wait(0.5)
    -- Step 3: Throw bomb
    print("  3. Throwing bomb...")
    SimulateQAndClick()
    wait(0.5)
    -- Step 4: Tween back 10 studs
    print("  4. Moving back 10 studs...")
    local backwardDirection = (humanoidRootPart.Position - BANK_LOCATIONS.VaultDoor).Unit
    local safePosition = humanoidRootPart.Position + (backwardDirection * 10)
    local tween = TweenService:Create(humanoidRootPart,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = CFrame.new(safePosition)}
    )
    tween:Play()
    tween.Completed:Wait()
    -- Step 5: Detonate bomb
    print("  5. Detonating bomb...")
    local detonateEvent = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(DETONATE_BOMB_EVENT)
    detonateEvent:FireServer()
    print("✅ Bomb sequence complete!")
    wait(2) -- Wait for explosion
    return throwSuccess
end

-- Detonate bomb function (separate)
local function detonateBomb()
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(DETONATE_BOMB_EVENT)
    event:FireServer()
    print("💥 Bomb detonated!")
end

-- Check functions
local function isBankRobbable()
    local robberies = Workspace:FindFirstChild("Robberies")
    if not robberies then return false end
    
    local bankRobbery = robberies:FindFirstChild("BankRobbery")
    if not bankRobbery then return false end
    
    local lightGreen = bankRobbery:FindFirstChild("LightGreen")
    if not lightGreen then return false end
    
    local light = lightGreen:FindFirstChild("Light")
    if not light then return false end
    
    return light.Enabled
end

local function isVaultDestroyable()
    local robberies = Workspace:FindFirstChild("Robberies")
    if not robberies then return false end
    
    local bankRobbery = robberies:FindFirstChild("BankRobbery")
    if not bankRobbery then return false end
    
    local doors = bankRobbery:FindFirstChild("Doors")
    if not doors then return false end
    
    local destroyableDoor = doors:FindFirstChild("Destroyable Door")
    if not destroyableDoor then return false end
    
    local main = destroyableDoor:FindFirstChild("Main")
    if not main then return false end
    
    local doorWeld = main:FindFirstChild("DoorWeld")
    if not doorWeld then return false end
    
    return doorWeld.Enabled
end

-- Event functions
local function buyBomb()
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(BUY_BOMB_EVENT)
    local args = {"Bomb", "Dealer"}
    event:FireServer(unpack(args))
    print("✓ Bought bomb from dealer")
end

local function equipBomb()
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(EQUIP_BOMB_EVENT)
    local args = {"Bomb"}
    event:FireServer(unpack(args))
    print("✓ Equipped bomb")
end

local function sellItem(itemType)
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(SELL_EVENT)
    local args = {itemType, "Dealer"}
    event:FireServer(unpack(args))
    print("✓ Sold", itemType, "to dealer")
end

local function pickupGold(goldPart)
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(PICKUP_EVENT)
    local args = {goldPart, "yvo", true}
    event:FireServer(unpack(args))
    print("✓ Picked up gold")
end

local function pickupMoney(moneyPart)
    local event = ReplicatedStorage:WaitForChild("WvO"):WaitForChild(PICKUP_EVENT)
    local args = {moneyPart, "EbZ", false}
    event:FireServer(unpack(args))
    print("✓ Picked up money")
end

-- Find and pick up all loot
local function collectAllLoot()
    local robberies = Workspace:FindFirstChild("Robberies")
    if not robberies then return 0 end
    
    local bankRobbery = robberies:FindFirstChild("BankRobbery")
    if not bankRobbery then return 0 end
    
    local totalCollected = 0
    
    -- Collect gold
    local goldFolder = bankRobbery:FindFirstChild("Gold")
    if goldFolder then
        for _, gold in pairs(goldFolder:GetChildren()) do
            if gold.Enabled and gold:IsA("BasePart") then
                local targetPos = gold.Position + Vector3.new(0, 3, 0)
                tweenToLocation(targetPos, true)
                wait(0.8)
                pickupGold(gold)
                totalCollected = totalCollected + 1
                wait(0.5)
            end
        end
    end
    
    -- Collect money
    local moneyFolder = bankRobbery:FindFirstChild("Money")
    if moneyFolder then
        for _, money in pairs(moneyFolder:GetChildren()) do
            if money.Enabled and money:IsA("BasePart") then
                local targetPos = money.Position + Vector3.new(0, 3, 0)
                tweenToLocation(targetPos, true)
                wait(0.8)
                pickupMoney(money)
                totalCollected = totalCollected + 1
                wait(0.5)
            end
        end
    end
    
    return totalCollected
end

-- Tween functions
local function calculateDuration(distance, speed)
    local duration = distance / speed
    return math.clamp(duration, 0.5, 30)
end

-- Pathfinding-based movement to avoid hazards
local PathfindingService = game:GetService("PathfindingService")
local function tweenToLocation(targetPosition, useNoclip)
    if useNoclip then enableNoclip() end
    -- Instantly teleport above the target position
    local aboveTarget = targetPosition + Vector3.new(0, 5, 0)
    humanoidRootPart.CFrame = CFrame.new(aboveTarget)
    if useNoclip then disableNoclip() end
end

local function stopTween()
    if currentTween then currentTween:Cancel() end
    tweening = false
    disableNoclip()
end

-- Main robbery sequence
local function autoRejoin()
    print("🔄 Attempting to auto rejoin to a server with 15 or fewer players...")
    local TeleportService = game:GetService("TeleportService")
    local player = game.Players.LocalPlayer
    local placeId = game.PlaceId
    if queue_on_teleport then
        queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/Jshawk/luminosityautorob/refs/heads/main/Luminosity%20AutoRob.lua"))()')
    end
    print("Teleporting to a new server...")
    TeleportService:Teleport(placeId, player)
    return -- Immediately stop further execution after teleport
end


local function executeRobbery()
    if not DEALER_POSITION then
        print("❌ Dealer position not set!")
        return false
    end
    -- Check if bank is robbable
    if not isBankRobbable() then
        print("❌ Bank not robbable")
        if autoRobberyEnabled then
            print("[AutoRob] Bank not robbable, auto rejoining...")
            autoRejoin()
        end
        return false
    end
    if not isVaultDestroyable() then
        print("❌ Vault already destroyed")
        return false
    end
    print("✅ Starting robbery sequence...")
    -- Step 1: Go to dealer
    tweenToLocation(DEALER_POSITION, true)
    -- Step 2: Sell all bombs
    sellItem("Bomb")
    wait(1.5)
    -- Step 3: Buy bomb
    buyBomb()
    wait(1.5)
    -- Step 4: Go to vault door
    tweenToLocation(BANK_LOCATIONS.VaultDoor, true)
    -- Step 5: Throw bomb (complete sequence)
    throwBombAtVault()
    -- Step 6: Check if vault is now open
    if not isVaultDestroyable() then
        print("✅ Vault door destroyed!")
        -- Step 7: Go inside vault
        tweenToLocation(BANK_LOCATIONS.VaultLeft, true)
        -- Step 8: Collect all loot
        collectAllLoot()
        -- Step 9: Return to dealer
        tweenToLocation(DEALER_POSITION, true)
        -- Step 10: Sell all gold
        sellItem("Gold")
        return true
    else
        print("❌ Failed to destroy vault door!")
        return false
    end
end

-- Auto-robbery loop
local function autoRobberyLoop()
    while autoRobberyEnabled do
        local success = executeRobbery()
        
        if success then
            wait(30)
        else
            wait(10)
        end
    end
end

-- CREATE SIMPLE MENU
local window = LUI:CreateWindow("Luminosity Auto Rob")
window:SetWatermarkPosition("right")
window:SetTheme("Dark")

-- Create tabs
local mainTab = window:AddTab("Main")

-- Add status section
mainTab:AddLabel("Status: Ready", 14, "center")

-- Try to auto-find dealer when script starts
task.spawn(function()
    wait(2)
    
    if findDealerPosition() then
        mainTab:AddLabel("✅ Dealer auto-detected", 12, "center")
    else
        mainTab:AddLabel("❌ Dealer not found", 12, "center")
        mainTab:AddLabel("Go to dealer and click below", 10, "center")
        
        mainTab:AddButton("Save Current Position as Dealer", function()
            saveCurrentPositionAsDealer()
            mainTab:AddLabel("✅ Dealer position saved!", 12, "center")
        end)
    end
end)


mainTab:AddSection("Auto Robbery")

-- Start auto robbery automatically if dealer position is set
local function tryStartAutoRobbery()
    if DEALER_POSITION then
        autoRobberyEnabled = true
        print("✅ Auto robbery started (auto mode)")
        task.spawn(autoRobberyLoop)
    else
        print("❌ Cannot start: No dealer position set!")
    end
end

-- Try to start auto robbery after dealer is found or set
task.spawn(function()
    wait(2.5)
    tryStartAutoRobbery()
end)

mainTab:AddButton("Check Bank Status", function()
    local robbable = isBankRobbable()
    local destroyable = isVaultDestroyable()
    
    if robbable and destroyable then
        mainTab:AddLabel("✅ Bank is robbable", 12, "center")
    else
        mainTab:AddLabel("❌ Bank not robbable", 12, "center")
    end
end)

mainTab:AddSeparator()
mainTab:AddSection("Manual Controls")

mainTab:AddButton("Test Bomb Throw Sequence", function()
    task.spawn(throwBombAtVault)
end)

mainTab:AddButton("Detonate Bomb", function()
    detonateBomb()
end)

mainTab:AddButton("Collect Loot Once", function()
    collectAllLoot()
end)

-- Mouse test section
mainTab:AddSeparator()
mainTab:AddSection("Mouse Test")

-- Removed right click test button



mainTab:AddButton("Test Aim and Throw", function()
    SimulateQAndClick()
end)

-- Settings tab
local settingsTab = window:AddTab("Settings")
settingsTab:AddSection("Speed")
local speedSlider = settingsTab:AddSlider("Tween Speed", 10, 500, 50, function(value)
    currentSpeed = value
end)

-- Initialize
print("\n" .. string.rep("=", 50))
print("LUMINOSITY AUTO ROB - BOMB SEQUENCE LOADED")
print("Mouse simulation using Mouse object events")
print(string.rep("=", 50))

-- Auto-dealer detection runs on startup
