--[[

    EGOY RIDE A PET - Eggs ESP Menu v2.3

    By ThiAez

    FEATURES:
    - ESP with aura + name + distance
    - Individual green ESP
    - Egg counter
    - Auto-updating list
    - Improved search
    - Sort by name or distance
    - Safer TP
    - Auto Best Egg (resistant)
    - AutoFarm per Egg + red stop button
    - Egg icons from Index > EggsHolder
    - Smooth button / menu animations
    - PC / Mobile (compact, fits small screens)
    - Minimize + drag anywhere on top bar
    - Configurable keybind for TP Home

    NOTE:
    The structure is split by systems so it stays easy to read / tweak.

]]

--==================================================
-- SERVICES
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--==================================================
-- EASY CONFIG
--==================================================
local Config = {
    -- ESP
    ESPFillTransparency = 0.50,
    ESPOutlineTransparency = 0,
    ESPNameSize = 13,
    ESPDistanceSize = 11,

    -- Colors
    GlobalESPColor = Color3.fromRGB(255, 255, 0),
    CustomESPColor = Color3.fromRGB(0, 255, 0),
    AccentColor = Color3.fromRGB(255, 90, 130),
    AccentColor2 = Color3.fromRGB(255, 180, 60),
    SuccessColor = Color3.fromRGB(0, 220, 120),
    DangerColor = Color3.fromRGB(220, 60, 60),

    -- TP
    TPHeight = 3,
    MovementSpeed = 500,

    -- Auto Egg
    BestEggName = "cherub",
    AutoEggHoldTime = 3,
    AutoFarmHoldTime = 2,
    AutoEggDelay = 0.8,

    -- UI
    PCWidth = 340,
    PCHeight = 520,
    MobileWidth = 280,
    MobileHeight = 440,
    AnimationTime = 0.18,
}

--==================================================
-- MAIN FOLDERS / OBJECTS
--==================================================
local TargetParent = LocalPlayer:WaitForChild("PlayerGui")
local RenderedEggsFolder = Workspace:WaitForChild("RenderedEggs", 10)

if not RenderedEggsFolder then
    warn("[EGOY RIDE A PET] Workspace.RenderedEggs not found. GUI will still open.")
end

--==================================================
-- STATES
--==================================================
local mainESPActive = false
local autoBestEggActive = false
local autoBestEggThread = nil

local autoFarmActive = false
local autoFarmThread = nil
local autoFarmEggs = {}
local autoFarmProcessed = {}
local autoFarmCurrentName = nil

local StopAutoFarmBtn
local StatusLabel

local currentSearchQuery = ""
local sortMode = "Name"

local tpKeybind = Enum.KeyCode.T
local listeningForKey = false

local isMobileMode = false
local isMinimized = false

local movementMode = "AutoFarm"
local movementActive = false
local movementHumanoid = nil
local movementPartsState = nil
local ModeAutoFarmBtn
local ModeTeleportBtn

-- [Egg] = {
--     Highlight = Highlight,
--     NameBillboard = BillboardGui,
--     CustomActive = true/false,
--     CustomColor = Color3
-- }
local eggData = {}

--==================================================
-- SMALL HELPERS
--==================================================
local function getCharacter()
    return LocalPlayer.Character
end

local function getRootPart()
    local character = getCharacter()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

--==================================================
-- EGG IMAGE
--==================================================
local function getEggImage(eggName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return "" end

    local main = playerGui:FindFirstChild("Main")
    local index = main and main:FindFirstChild("Index")
    local holders = index and index:FindFirstChild("Holders")
    local eggsHolder = holders and holders:FindFirstChild("EggsHolder")
    if not eggsHolder then return "" end

    local eggFrame = eggsHolder:FindFirstChild(eggName)
    if not eggFrame then return "" end

    local imageLabel = eggFrame:FindFirstChild("ImageLabel")
    if imageLabel and imageLabel:IsA("ImageLabel") then
        return imageLabel.Image or ""
    end
    return ""
end

local function getTargetCFrame(target)
    if not target or not target.Parent then return nil end
    if target:IsA("Model") then return target:GetPivot() end
    if target:IsA("BasePart") then return target.CFrame end
    return nil
end

local function getTargetPosition(target)
    local cf = getTargetCFrame(target)
    if not cf then return nil end
    return cf.Position
end

local function getDistanceToTarget(target)
    local root = getRootPart()
    local targetPosition = getTargetPosition(target)
    if not root or not targetPosition then return math.huge end
    return (root.Position - targetPosition).Magnitude
end

local function tween(object, properties, duration)
    if not object or not object.Parent then return end
    local info = TweenInfo.new(
        duration or Config.AnimationTime,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    TweenService:Create(object, info, properties):Play()
end

--==================================================
-- ESP: CREATE NAME + DISTANCE
--==================================================
local function createEggLabel(egg)
    local data = eggData[egg]
    if not data then return end
    if data.NameBillboard and data.NameBillboard.Parent then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EggESP_Info"
    billboard.Size = UDim2.new(0, 180, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Enabled = false
    billboard.Parent = egg

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "EggName"
    nameLabel.Size = UDim2.new(1, 0, 0, 23)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = egg.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.35
    nameLabel.TextSize = Config.ESPNameSize
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = billboard

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "Distance"
    distanceLabel.Size = UDim2.new(1, 0, 0, 18)
    distanceLabel.Position = UDim2.new(0, 0, 0, 22)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0 studs"
    distanceLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    distanceLabel.TextStrokeTransparency = 0.4
    distanceLabel.TextSize = Config.ESPDistanceSize
    distanceLabel.Font = Enum.Font.SourceSans
    distanceLabel.Parent = billboard

    data.NameBillboard = billboard
end

local function updateEggLabel(egg)
    local data = eggData[egg]
    if not data or not data.NameBillboard then return end

    local billboard = data.NameBillboard
    if not billboard.Parent then return end

    local nameLabel = billboard:FindFirstChild("EggName")
    local distanceLabel = billboard:FindFirstChild("Distance")

    if nameLabel then
        nameLabel.Text = egg.Name
    end

    if distanceLabel then
        local distance = getDistanceToTarget(egg)
        if distance == math.huge then
            distanceLabel.Text = "?"
        else
            distanceLabel.Text = string.format("%d studs", math.floor(distance + 0.5))
        end
    end
end

--==================================================
-- ESP: UPDATE ONE EGG
--==================================================
local function updateEggESP(egg)
    if not egg then return end
    if not egg:IsA("Model") and not egg:IsA("BasePart") then return end

    if not eggData[egg] then
        eggData[egg] = {
            Highlight = nil,
            NameBillboard = nil,
            CustomColor = Config.CustomESPColor,
            CustomActive = false
        }
    end

    local data = eggData[egg]
    local shouldShow = false
    local color = Config.GlobalESPColor

    if data.CustomActive then
        shouldShow = true
        color = data.CustomColor or Config.CustomESPColor
    elseif mainESPActive then
        shouldShow = true
        color = Config.GlobalESPColor
    end

    if shouldShow then
        if not data.Highlight or not data.Highlight.Parent then
            local highlight = Instance.new("Highlight")
            highlight.Name = "EggESP_Highlight"
            highlight.Adornee = egg
            highlight.FillTransparency = Config.ESPFillTransparency
            highlight.OutlineTransparency = Config.ESPOutlineTransparency
            highlight.Parent = egg
            data.Highlight = highlight
        end

        data.Highlight.FillColor = color
        data.Highlight.OutlineColor = color
        data.Highlight.Enabled = true

        createEggLabel(egg)
        if data.NameBillboard then
            data.NameBillboard.Enabled = true
        end
        updateEggLabel(egg)
    else
        if data.Highlight then data.Highlight.Enabled = false end
        if data.NameBillboard then data.NameBillboard.Enabled = false end
    end
end

local function updateAllESP()
    if not RenderedEggsFolder then return end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        updateEggESP(egg)
    end
end

local function applyGlobalESP(state)
    mainESPActive = state
    updateAllESP()
end

local function removeEggData(egg)
    local data = eggData[egg]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.NameBillboard then data.NameBillboard:Destroy() end
    eggData[egg] = nil
end

--==================================================
-- TELEPORT TO A MODEL
--==================================================
local function teleportToModel(target)
    local root = getRootPart()
    if not root then return false end
    local targetCFrame = getTargetCFrame(target)
    if not targetCFrame then return false end
    root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
    return true
end

--==================================================
-- NOCLIP + MOVEMENT
--==================================================
local function setNoclip(enabled)
    local character = getCharacter()
    if not character then return end

    if enabled then
        movementPartsState = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                movementPartsState[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    elseif movementPartsState then
        for part, oldCanCollide in pairs(movementPartsState) do
            if part and part.Parent then part.CanCollide = oldCanCollide end
        end
        movementPartsState = nil
    end
end

local function moveToModel(target)
    if movementMode == "Teleport" then return teleportToModel(target) end
    if movementActive then return false end

    local character = getCharacter()
    local root = getRootPart()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local targetCFrame = getTargetCFrame(target)
    if not root or not humanoid or not targetCFrame then return false end

    local destination = targetCFrame.Position + Vector3.new(0, Config.TPHeight, 0)
    local startDistance = (root.Position - destination).Magnitude
    if startDistance <= 2 then
        root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
        return true
    end

    movementActive = true
    movementHumanoid = humanoid
    local oldAutoRotate = humanoid.AutoRotate
    local success = false
    local startTime = os.clock()
    local maxTime = math.max(3, (startDistance / Config.MovementSpeed) + 2)

    setNoclip(true)
    humanoid.AutoRotate = false

    while movementActive and os.clock() - startTime <= maxTime do
        if not target or not target.Parent then break end
        if getRootPart() ~= root then break end

        local offset = destination - root.Position
        local distance = offset.Magnitude

        if distance <= 2 then
            root.CFrame = targetCFrame * CFrame.new(0, Config.TPHeight, 0)
            success = true
            break
        end

        local dt = RunService.Heartbeat:Wait()
        local step = math.min(distance, Config.MovementSpeed * dt)
        root.CFrame = root.CFrame + offset.Unit * step
    end

    movementActive = false
    if humanoid.Parent then humanoid.AutoRotate = oldAutoRotate end
    movementHumanoid = nil
    setNoclip(false)
    return success
end

local function stopMovement()
    movementActive = false
    if movementHumanoid and movementHumanoid.Parent then
        movementHumanoid.AutoRotate = true
    end
    movementHumanoid = nil
    setNoclip(false)
end

local function updateMovementModeButtons()
    if not ModeAutoFarmBtn or not ModeTeleportBtn then return end

    if movementMode == "AutoFarm" then
        ModeAutoFarmBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ModeTeleportBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        ModeTeleportBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    else
        ModeAutoFarmBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
        ModeTeleportBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 190)
        ModeTeleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function setMovementMode(mode)
    if mode ~= "AutoFarm" and mode ~= "Teleport" then return end
    stopMovement()
    movementMode = mode
    updateMovementModeButtons()

    if StatusLabel then
        StatusLabel.Text = mode == "AutoFarm"
            and "● AutoFarm Mode: move + noclip"
            or  "● Teleport Mode: instant TP"
        StatusLabel.TextColor3 = Config.SuccessColor
    end
end

--==================================================
-- TELEPORT TO HOME PLOT
--==================================================
local function teleportToHomePlot()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return false end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local dataFolder = plot:FindFirstChild("Data")
        if dataFolder then
            local ownerValue = dataFolder:FindFirstChild("Owner")
            if ownerValue then
                local isOwner = false

                if ownerValue:IsA("StringValue") then
                    isOwner = ownerValue.Value == LocalPlayer.Name
                elseif ownerValue:IsA("ObjectValue") then
                    isOwner = ownerValue.Value == LocalPlayer
                else
                    isOwner = tostring(ownerValue.Value) == LocalPlayer.Name
                end

                if isOwner then
                    return moveToModel(plot)
                end
            end
        end
    end
    return false
end

--==================================================
-- AUTO BEST EGG
--==================================================
local function holdEKey(duration)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function findBestEgg()
    if not RenderedEggsFolder then return nil end
    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if string.find(egg.Name:lower(), Config.BestEggName:lower(), 1, true) then
            return egg
        end
    end
    return nil
end

local function stopAutoBestEgg()
    autoBestEggActive = false
    stopMovement()
    if autoBestEggThread then
        task.cancel(autoBestEggThread)
        autoBestEggThread = nil
    end
end

local function startAutoBestEgg()
    stopAutoBestEgg()
    autoBestEggActive = true

    autoBestEggThread = task.spawn(function()
        while autoBestEggActive do
            local egg = findBestEgg()
            if egg and egg.Parent then
                local teleported = moveToModel(egg)
                if teleported then
                    task.wait(0.3)
                    if autoBestEggActive and egg.Parent then
                        holdEKey(Config.AutoEggHoldTime)
                    end
                    task.wait(0.2)
                    if autoBestEggActive then
                        teleportToHomePlot()
                    end
                    task.wait(Config.AutoEggDelay)
                end
            else
                task.wait(0.5)
            end
        end
    end)
end

--==================================================
-- AUTOFARM (selected eggs)
--==================================================
local function setAutoFarmButtonState(button, active)
    if not button then return end
    if active then
        button.Text = "Farm ON"
        button.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    else
        button.Text = "Farm"
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end

local function isValidEgg(egg)
    return egg
        and egg.Parent == RenderedEggsFolder
        and (egg:IsA("Model") or egg:IsA("BasePart"))
end

local function getAutoFarmEggs()
    local found = {}
    if not RenderedEggsFolder then return found end

    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if isValidEgg(egg) and autoFarmEggs[egg.Name] and not autoFarmProcessed[egg] then
            table.insert(found, egg)
        end
    end

    table.sort(found, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    return found
end

local function stopAutoFarm()
    autoFarmActive = false
    stopMovement()
    autoFarmCurrentName = nil
    if autoFarmThread then
        task.cancel(autoFarmThread)
        autoFarmThread = nil
    end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function startAutoFarm()
    stopAutoFarm()
    autoFarmActive = true

    if StopAutoFarmBtn then StopAutoFarmBtn.Visible = true end

    autoFarmThread = task.spawn(function()
        while autoFarmActive do
            local eggs = getAutoFarmEggs()
            if #eggs == 0 then
                autoFarmActive = false
                autoFarmCurrentName = nil
                autoFarmThread = nil
                if StopAutoFarmBtn then StopAutoFarmBtn.Visible = false end
                break
            end

            local didWork = false

            for _, egg in ipairs(eggs) do
                if not autoFarmActive then break end

                if isValidEgg(egg) and not autoFarmProcessed[egg] then
                    didWork = true
                    autoFarmCurrentName = egg.Name

                    if StatusLabel then
                        StatusLabel.Text = "● AutoFarm: " .. egg.Name
                        StatusLabel.TextColor3 = Config.SuccessColor
                    end

                    local success = moveToModel(egg)
                    if success and autoFarmActive then
                        task.wait(0.3)
                        if autoFarmActive and isValidEgg(egg) then
                            holdEKey(Config.AutoFarmHoldTime)
                        end
                        if autoFarmActive then
                            task.wait(0.2)
                            teleportToHomePlot()
                        end

                        autoFarmProcessed[egg] = true
                        task.wait(0.2)
                    end
                end
            end

            autoFarmCurrentName = nil

            if not didWork then
                autoFarmActive = false
                autoFarmThread = nil
                if StopAutoFarmBtn then StopAutoFarmBtn.Visible = false end
                break
            end

            task.wait(0.2)
        end

        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        if not autoFarmActive and StatusLabel then
            StatusLabel.Text = "● AutoFarm finished: no eggs left"
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end)
end

--==================================================
-- MAIN GUI
--==================================================
local oldGui = nil
pcall(function()
    oldGui = TargetParent:FindFirstChild("EGOY_RIDE_A_PET_Menu")
end)
if oldGui then pcall(function() oldGui:Destroy() end) end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EGOY_RIDE_A_PET_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = TargetParent

--==================================================
-- DEVICE PICKER
--==================================================
local DeviceFrame = Instance.new("Frame")
DeviceFrame.Name = "DeviceSelectionFrame"
DeviceFrame.Size = UDim2.new(0, 260, 0, 130)
DeviceFrame.Position = UDim2.new(0.5, -130, 0.5, -65)
DeviceFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
DeviceFrame.BackgroundTransparency = 0.05
DeviceFrame.BorderSizePixel = 0
DeviceFrame.Active = true
DeviceFrame.Parent = ScreenGui

local DeviceCorner = Instance.new("UICorner")
DeviceCorner.CornerRadius = UDim.new(0, 12)
DeviceCorner.Parent = DeviceFrame

local DeviceStroke = Instance.new("UIStroke")
DeviceStroke.Color = Config.AccentColor
DeviceStroke.Thickness = 1.4
DeviceStroke.Transparency = 0.3
DeviceStroke.Parent = DeviceFrame

local DeviceTitle = Instance.new("TextLabel")
DeviceTitle.Size = UDim2.new(1, 0, 0, 32)
DeviceTitle.Position = UDim2.new(0, 0, 0, 10)
DeviceTitle.BackgroundTransparency = 1
DeviceTitle.Text = "EGOY RIDE A PET"
DeviceTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
DeviceTitle.TextSize = 16
DeviceTitle.Font = Enum.Font.GothamBold
DeviceTitle.Parent = DeviceFrame

local DeviceSub = Instance.new("TextLabel")
DeviceSub.Size = UDim2.new(1, 0, 0, 14)
DeviceSub.Position = UDim2.new(0, 0, 0, 40)
DeviceSub.BackgroundTransparency = 1
DeviceSub.Text = "Choose your device"
DeviceSub.TextColor3 = Color3.fromRGB(180, 180, 200)
DeviceSub.TextSize = 11
DeviceSub.Font = Enum.Font.Gotham
DeviceSub.Parent = DeviceFrame

local function makeDeviceButton(text, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 105, 0, 40)
    b.Position = UDim2.new(0, x, 0, 72)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    b.BackgroundTransparency = 0.1
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Parent = DeviceFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    return b
end

local PCBtn = makeDeviceButton("PC", 18)
local MobileBtn = makeDeviceButton("Mobile", 137)

--==================================================
-- MAIN FRAME
--==================================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, Config.PCWidth, 0, Config.PCHeight)
MainFrame.Position = UDim2.new(0.5, -Config.PCWidth / 2, 0.4, -Config.PCHeight / 2)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Config.AccentColor
MainStroke.Thickness = 1.4
MainStroke.Transparency = 0.35
MainStroke.Parent = MainFrame

--==================================================
-- TOP BAR
--==================================================
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 50)
TopBar.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TopGradient = Instance.new("UIGradient")
TopGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Config.AccentColor),
    ColorSequenceKeypoint.new(1, Config.AccentColor2),
})
TopGradient.Rotation = 35
TopGradient.Parent = TopBar

local TopFix = Instance.new("Frame")
TopFix.Size = UDim2.new(1, 0, 0, 10)
TopFix.Position = UDim2.new(0, 0, 1, -10)
TopFix.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
TopFix.BorderSizePixel = 0
TopFix.ZIndex = 0
TopFix.Parent = TopBar

local AuthorLabel = Instance.new("TextLabel")
AuthorLabel.Size = UDim2.new(1, -55, 0, 14)
AuthorLabel.Position = UDim2.new(0, 12, 0, 3)
AuthorLabel.BackgroundTransparency = 1
AuthorLabel.Text = "By ThiAez"
AuthorLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
AuthorLabel.TextSize = 11
AuthorLabel.Font = Enum.Font.Gotham
AuthorLabel.TextXAlignment = Enum.TextXAlignment.Left
AuthorLabel.ZIndex = 2
AuthorLabel.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -55, 0, 16)
TitleLabel.Position = UDim2.new(0, 12, 0, 17)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🐾 EGOY RIDE A PET"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 2
TitleLabel.Parent = TopBar

local GameLabel = Instance.new("TextLabel")
GameLabel.Size = UDim2.new(1, -55, 0, 12)
GameLabel.Position = UDim2.new(0, 12, 0, 34)
GameLabel.BackgroundTransparency = 1
GameLabel.Text = "Ride A Pet - Eggs ESP"
GameLabel.TextColor3 = Color3.fromRGB(210, 210, 240)
GameLabel.TextSize = 10
GameLabel.Font = Enum.Font.Gotham
GameLabel.TextXAlignment = Enum.TextXAlignment.Left
GameLabel.ZIndex = 2
GameLabel.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -38, 0, 10)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MinimizeBtn.BackgroundTransparency = 0.5
MinimizeBtn.Text = "–"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 18
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.ZIndex = 3
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinimizeBtn

--==================================================
-- CONTENT CONTAINER
--==================================================
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -20, 1, -60)
ContentContainer.Position = UDim2.new(0, 10, 0, 55)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

--==================================================
-- STATUS TEXT
--==================================================
StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -110, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● EGOY ready"
StatusLabel.TextColor3 = Config.SuccessColor
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Parent = ContentContainer

--==================================================
-- BUTTON STYLER
--==================================================
local function styleButton(button)
    if button:FindFirstChildOfClass("UICorner") == nil then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = button
    end

    if button:FindFirstChildOfClass("UIStroke") == nil then
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(80, 80, 100)
        stroke.Transparency = 0.6
        stroke.Thickness = 1
        stroke.Parent = button
    end

    button.AutoButtonColor = false

    button.MouseEnter:Connect(function()
        tween(button, {
            BackgroundTransparency = math.max(0, button.BackgroundTransparency - 0.10)
        }, 0.10)
    end)

    button.MouseLeave:Connect(function()
        tween(button, {
            BackgroundTransparency = math.min(0.5, button.BackgroundTransparency + 0.10)
        }, 0.10)
    end)
end

--==================================================
-- MODE BUTTONS
--==================================================
ModeAutoFarmBtn = Instance.new("TextButton")
ModeAutoFarmBtn.Name = "ModeAutoFarm"
ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 30)
ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 22)
ModeAutoFarmBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
ModeAutoFarmBtn.BackgroundTransparency = 0.1
ModeAutoFarmBtn.Text = "🚶 AutoFarm Mode"
ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ModeAutoFarmBtn.TextSize = 11
ModeAutoFarmBtn.Font = Enum.Font.GothamBold
ModeAutoFarmBtn.Parent = ContentContainer
styleButton(ModeAutoFarmBtn)

ModeTeleportBtn = Instance.new("TextButton")
ModeTeleportBtn.Name = "ModeTeleport"
ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 30)
ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 22)
ModeTeleportBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ModeTeleportBtn.BackgroundTransparency = 0.15
ModeTeleportBtn.Text = "⚡ Teleport Mode"
ModeTeleportBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
ModeTeleportBtn.TextSize = 11
ModeTeleportBtn.Font = Enum.Font.GothamBold
ModeTeleportBtn.Parent = ContentContainer
styleButton(ModeTeleportBtn)

ModeAutoFarmBtn.MouseButton1Click:Connect(function() setMovementMode("AutoFarm") end)
ModeTeleportBtn.MouseButton1Click:Connect(function() setMovementMode("Teleport") end)
updateMovementModeButtons()

--==================================================
-- STOP AUTOFARM
--==================================================
StopAutoFarmBtn = Instance.new("TextButton")
StopAutoFarmBtn.Name = "StopAutoFarm"
StopAutoFarmBtn.Size = UDim2.new(0, 105, 0, 20)
StopAutoFarmBtn.Position = UDim2.new(1, -105, 0, 0)
StopAutoFarmBtn.BackgroundColor3 = Config.DangerColor
StopAutoFarmBtn.BackgroundTransparency = 0.05
StopAutoFarmBtn.Text = "■ Stop AutoFarm"
StopAutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopAutoFarmBtn.TextSize = 10
StopAutoFarmBtn.Font = Enum.Font.GothamBold
StopAutoFarmBtn.Visible = false
StopAutoFarmBtn.Parent = ContentContainer
styleButton(StopAutoFarmBtn)

StopAutoFarmBtn.MouseButton1Click:Connect(function()
    stopAutoFarm()
    StopAutoFarmBtn.Visible = false
    StatusLabel.Text = "● AutoFarm stopped"
    StatusLabel.TextColor3 = Config.DangerColor
end)

--==================================================
-- ESP TOGGLE
--==================================================
local ToggleGlobalESPBtn = Instance.new("TextButton")
ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 32)
ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 56)
ToggleGlobalESPBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleGlobalESPBtn.BackgroundTransparency = 0.15
ToggleGlobalESPBtn.Text = "ESP All: OFF"
ToggleGlobalESPBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
ToggleGlobalESPBtn.TextSize = 13
ToggleGlobalESPBtn.Font = Enum.Font.GothamBold
ToggleGlobalESPBtn.Parent = ContentContainer
styleButton(ToggleGlobalESPBtn)

ToggleGlobalESPBtn.MouseButton1Click:Connect(function()
    mainESPActive = not mainESPActive
    if mainESPActive then
        ToggleGlobalESPBtn.Text = "ESP All: ON"
        ToggleGlobalESPBtn.TextColor3 = Config.SuccessColor
        StatusLabel.Text = "● ESP active"
        StatusLabel.TextColor3 = Config.SuccessColor
    else
        ToggleGlobalESPBtn.Text = "ESP All: OFF"
        ToggleGlobalESPBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
        StatusLabel.Text = "● ESP disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
    applyGlobalESP(mainESPActive)
end)

--==================================================
-- AUTO BEST EGG
--==================================================
local AutoBestEggBtn = Instance.new("TextButton")
AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 32)
AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 92)
AutoBestEggBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AutoBestEggBtn.BackgroundTransparency = 0.15
AutoBestEggBtn.Text = "Auto Best Egg: OFF"
AutoBestEggBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
AutoBestEggBtn.TextSize = 13
AutoBestEggBtn.Font = Enum.Font.GothamBold
AutoBestEggBtn.Parent = ContentContainer
styleButton(AutoBestEggBtn)

AutoBestEggBtn.MouseButton1Click:Connect(function()
    autoBestEggActive = not autoBestEggActive

    if autoBestEggActive then
        AutoBestEggBtn.Text = "Auto Best Egg: ON"
        AutoBestEggBtn.TextColor3 = Config.SuccessColor
        StatusLabel.Text = "● Auto Best Egg active"
        StatusLabel.TextColor3 = Config.SuccessColor
        startAutoBestEgg()
    else
        AutoBestEggBtn.Text = "Auto Best Egg: OFF"
        AutoBestEggBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
        StatusLabel.Text = "● EGOY ready"
        StatusLabel.TextColor3 = Config.SuccessColor
        stopAutoBestEgg()
    end
end)

--==================================================
-- TP HOME
--==================================================
local TPHomeBtn = Instance.new("TextButton")
TPHomeBtn.Size = UDim2.new(1, 0, 0, 32)
TPHomeBtn.Position = UDim2.new(0, 0, 0, 128)
TPHomeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TPHomeBtn.BackgroundTransparency = 0.15
TPHomeBtn.Text = "🏠 TP Home"
TPHomeBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
TPHomeBtn.TextSize = 13
TPHomeBtn.Font = Enum.Font.GothamBold
TPHomeBtn.Parent = ContentContainer
styleButton(TPHomeBtn)

TPHomeBtn.MouseButton1Click:Connect(function()
    local success = teleportToHomePlot()
    if success then
        StatusLabel.Text = movementMode == "AutoFarm"
            and "● Moved Home (move + noclip)"
            or  "● Teleported Home"
        StatusLabel.TextColor3 = Config.SuccessColor
    else
        StatusLabel.Text = "● Your plot not found"
        StatusLabel.TextColor3 = Config.DangerColor
    end
end)

--==================================================
-- KEYBIND
--==================================================
local KeybindBtn = Instance.new("TextButton")
KeybindBtn.Size = UDim2.new(1, 0, 0, 24)
KeybindBtn.Position = UDim2.new(0, 0, 0, 164)
KeybindBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
KeybindBtn.BackgroundTransparency = 0.2
KeybindBtn.Text = "TP Home Key: [" .. tpKeybind.Name .. "]"
KeybindBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
KeybindBtn.TextSize = 11
KeybindBtn.Font = Enum.Font.Gotham
KeybindBtn.Parent = ContentContainer
styleButton(KeybindBtn)

KeybindBtn.MouseButton1Click:Connect(function()
    listeningForKey = true
    KeybindBtn.Text = "Press a key..."
    KeybindBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
end)

--==================================================
-- LIST TOGGLE
--==================================================
local ToggleListBtn = Instance.new("TextButton")
ToggleListBtn.Size = UDim2.new(1, 0, 0, 30)
ToggleListBtn.Position = UDim2.new(0, 0, 0, 192)
ToggleListBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleListBtn.BackgroundTransparency = 0.15
ToggleListBtn.Text = "Show Egg List ▼"
ToggleListBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
ToggleListBtn.TextSize = 12
ToggleListBtn.Font = Enum.Font.GothamBold
ToggleListBtn.Parent = ContentContainer
styleButton(ToggleListBtn)

--==================================================
-- LIST CONTAINER
--==================================================
local ListContainerFrame = Instance.new("Frame")
ListContainerFrame.Size = UDim2.new(1, 0, 0, 230)
ListContainerFrame.Position = UDim2.new(0, 0, 0, 226)
ListContainerFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ListContainerFrame.BackgroundTransparency = 0.15
ListContainerFrame.Visible = false
ListContainerFrame.Parent = ContentContainer

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = ListContainerFrame

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = Color3.fromRGB(70, 70, 90)
ListStroke.Transparency = 0.5
ListStroke.Parent = ListContainerFrame

--==================================================
-- EGG COUNTER
--==================================================
local EggCountLabel = Instance.new("TextLabel")
EggCountLabel.Size = UDim2.new(1, -10, 0, 20)
EggCountLabel.Position = UDim2.new(0, 5, 0, 5)
EggCountLabel.BackgroundTransparency = 1
EggCountLabel.Text = "Eggs detected: 0"
EggCountLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
EggCountLabel.TextSize = 11
EggCountLabel.Font = Enum.Font.GothamBold
EggCountLabel.TextXAlignment = Enum.TextXAlignment.Left
EggCountLabel.Parent = ListContainerFrame

--==================================================
-- REFRESH
--==================================================
local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0.48, -5, 0, 25)
RefreshBtn.Position = UDim2.new(0, 5, 0, 27)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
RefreshBtn.BackgroundTransparency = 0.1
RefreshBtn.Text = "🔄 Refresh"
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.TextSize = 12
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.Parent = ListContainerFrame
styleButton(RefreshBtn)

--==================================================
-- SORT
--==================================================
local SortBtn = Instance.new("TextButton")
SortBtn.Size = UDim2.new(0.48, -5, 0, 25)
SortBtn.Position = UDim2.new(0.52, 0, 0, 27)
SortBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
SortBtn.BackgroundTransparency = 0.1
SortBtn.Text = "Sort: Name"
SortBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SortBtn.TextSize = 12
SortBtn.Font = Enum.Font.GothamBold
SortBtn.Parent = ListContainerFrame
styleButton(SortBtn)

--==================================================
-- SEARCH
--==================================================
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -10, 0, 25)
SearchBox.Position = UDim2.new(0, 5, 0, 57)
SearchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
SearchBox.BackgroundTransparency = 0.1
SearchBox.PlaceholderText = "🔍 Search egg..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.TextSize = 12
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = ListContainerFrame

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBox

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 8)
SearchPadding.Parent = SearchBox

--==================================================
-- SCROLL LIST
--==================================================
local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -10, 1, -87)
ScrollList.Position = UDim2.new(0, 5, 0, 87)
ScrollList.BackgroundTransparency = 1
ScrollList.BorderSizePixel = 0
ScrollList.ScrollBarThickness = 4
ScrollList.ScrollBarImageColor3 = Config.AccentColor
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.Parent = ListContainerFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ScrollList

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 6)
end)

--==================================================
-- GET EGGS FOR LIST
--==================================================
local function getEggsForList()
    local eggs = {}
    if not RenderedEggsFolder then return eggs end

    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            table.insert(eggs, egg)
        end
    end

    table.sort(eggs, function(a, b)
        if sortMode == "Distance" then
            return getDistanceToTarget(a) < getDistanceToTarget(b)
        end
        return a.Name:lower() < b.Name:lower()
    end)

    return eggs
end

--==================================================
-- CREATE LIST ITEM
--==================================================
local function createEggListItem(egg, itemHeight, textSize)
    local ItemFrame = Instance.new("Frame")
    ItemFrame.Size = UDim2.new(1, -6, 0, itemHeight)
    ItemFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    ItemFrame.BackgroundTransparency = 0.15
    ItemFrame.Parent = ScrollList

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = ItemFrame

    local iconSize = itemHeight - 8

    local eggIcon = Instance.new("ImageLabel")
    eggIcon.Name = "EggIcon"
    eggIcon.Size = UDim2.new(0, iconSize, 0, iconSize)
    eggIcon.Position = UDim2.new(0, 5, 0.5, -iconSize / 2)
    eggIcon.BackgroundTransparency = 1
    eggIcon.Image = getEggImage(egg.Name)
    eggIcon.ScaleType = Enum.ScaleType.Fit
    eggIcon.Parent = ItemFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -(itemHeight + 130), 1, 0)
    nameLabel.Position = UDim2.new(0, itemHeight + 2, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    nameLabel.TextSize = textSize
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = ItemFrame

    local distance = getDistanceToTarget(egg)
    local distStr = distance ~= math.huge
        and string.format(" (%dm)", math.floor(distance + 0.5))
        or  ""
    nameLabel.Text = egg.Name .. distStr

    local TPBtn = Instance.new("TextButton")
    TPBtn.Size = UDim2.new(0, 28, 0, itemHeight - 8)
    TPBtn.Position = UDim2.new(1, -120, 0.5, -(itemHeight - 8) / 2)
    TPBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    TPBtn.BackgroundTransparency = 0.1
    TPBtn.Text = "TP"
    TPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TPBtn.TextSize = 10
    TPBtn.Font = Enum.Font.GothamBold
    TPBtn.Parent = ItemFrame
    styleButton(TPBtn)

    TPBtn.MouseButton1Click:Connect(function()
        if not egg.Parent then return end
        local success = teleportToModel(egg)
        if success then
            StatusLabel.Text = "● TP: " .. egg.Name
            StatusLabel.TextColor3 = Config.SuccessColor
        end
    end)

    local AutoFarmBtn = Instance.new("TextButton")
    AutoFarmBtn.Name = "AutoFarmButton"
    AutoFarmBtn.Size = UDim2.new(0, 46, 0, itemHeight - 8)
    AutoFarmBtn.Position = UDim2.new(1, -88, 0.5, -(itemHeight - 8) / 2)
    AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    AutoFarmBtn.BackgroundTransparency = 0.1
    AutoFarmBtn.Text = "Farm"
    AutoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoFarmBtn.TextSize = 9
    AutoFarmBtn.Font = Enum.Font.GothamBold
    AutoFarmBtn.Parent = ItemFrame
    styleButton(AutoFarmBtn)

    setAutoFarmButtonState(AutoFarmBtn, autoFarmEggs[egg.Name] == true)

    AutoFarmBtn.MouseButton1Click:Connect(function()
        if not egg.Parent then return end

        local name = egg.Name
        autoFarmEggs[name] = not autoFarmEggs[name]

        for processedEgg in pairs(autoFarmProcessed) do
            if processedEgg and processedEgg.Name == name then
                autoFarmProcessed[processedEgg] = nil
            end
        end

        setAutoFarmButtonState(AutoFarmBtn, autoFarmEggs[name] == true)

        if autoFarmEggs[name] then
            StatusLabel.Text = "● AutoFarm added: " .. name
            StatusLabel.TextColor3 = Config.SuccessColor
            if not autoFarmActive then
                startAutoFarm()
            end
        else
            StatusLabel.Text = "● AutoFarm removed: " .. name
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)

            local anySelected = false
            for _ in pairs(autoFarmEggs) do anySelected = true; break end
            if not anySelected then
                stopAutoFarm()
                StopAutoFarmBtn.Visible = false
            end
        end

        StopAutoFarmBtn.Visible = autoFarmActive
    end)

    local GreenESPBtn = Instance.new("TextButton")
    GreenESPBtn.Size = UDim2.new(0, 34, 0, itemHeight - 8)
    GreenESPBtn.Position = UDim2.new(1, -38, 0.5, -(itemHeight - 8) / 2)
    GreenESPBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    GreenESPBtn.BackgroundTransparency = 0.15
    GreenESPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    GreenESPBtn.TextSize = 9
    GreenESPBtn.Font = Enum.Font.GothamBold
    GreenESPBtn.Parent = ItemFrame
    styleButton(GreenESPBtn)

    local data = eggData[egg]
    if data and data.CustomActive then
        GreenESPBtn.Text = "ON"
        GreenESPBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
    else
        GreenESPBtn.Text = "ESP"
    end

    GreenESPBtn.MouseButton1Click:Connect(function()
        if not eggData[egg] then
            eggData[egg] = {
                Highlight = nil,
                NameBillboard = nil,
                CustomColor = Config.CustomESPColor,
                CustomActive = false
            }
        end

        local eggInfo = eggData[egg]
        eggInfo.CustomActive = not eggInfo.CustomActive
        eggInfo.CustomColor = Config.CustomESPColor

        if eggInfo.CustomActive then
            GreenESPBtn.Text = "ON"
            GreenESPBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
            StatusLabel.Text = "● Green ESP: " .. egg.Name
            StatusLabel.TextColor3 = Config.SuccessColor
        else
            GreenESPBtn.Text = "ESP"
            GreenESPBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
            StatusLabel.Text = "● Green ESP off"
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end

        updateEggESP(egg)
    end)
end

--==================================================
-- POPULATE LIST
--==================================================
local function clearEggList()
    for _, child in ipairs(ScrollList:GetChildren()) do
        if child ~= UIListLayout then
            child:Destroy()
        end
    end
end

local function populateList()
    clearEggList()

    if not RenderedEggsFolder then
        EggCountLabel.Text = "Eggs: 0  |  Results: 0"
        return
    end

    local query = currentSearchQuery:lower()
    local eggs = getEggsForList()
    local visibleCount = 0

    local itemHeight = isMobileMode and 28 or 30
    local textSize = isMobileMode and 10 or 11

    for _, egg in ipairs(eggs) do
        local matches = query == ""
            or string.find(egg.Name:lower(), query, 1, true)

        if matches then
            visibleCount += 1
            createEggListItem(egg, itemHeight, textSize)
        end
    end

    EggCountLabel.Text = "Eggs: " .. tostring(#eggs)
        .. "  |  Results: " .. tostring(visibleCount)

    if visibleCount == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Name = "NoResultsLabel"
        emptyLabel.Size = UDim2.new(1, -10, 0, 35)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "No Eggs found"
        emptyLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
        emptyLabel.TextSize = 12
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Parent = ScrollList
    end
end

--==================================================
-- SEARCH
--==================================================
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local newQuery = SearchBox.Text
    if newQuery == currentSearchQuery then return end
    currentSearchQuery = newQuery
    populateList()
end)

--==================================================
-- REFRESH
--==================================================
RefreshBtn.MouseButton1Click:Connect(function()
    populateList()
    updateAllESP()
    StatusLabel.Text = "● List refreshed"
    StatusLabel.TextColor3 = Config.SuccessColor
end)

--==================================================
-- SORT TOGGLE
--==================================================
SortBtn.MouseButton1Click:Connect(function()
    if sortMode == "Name" then
        sortMode = "Distance"
        SortBtn.Text = "Sort: Distance"
    else
        sortMode = "Name"
        SortBtn.Text = "Sort: Name"
    end
    populateList()
end)

--==================================================
-- SHOW / HIDE LIST
--==================================================
ToggleListBtn.MouseButton1Click:Connect(function()
    ListContainerFrame.Visible = not ListContainerFrame.Visible

    if ListContainerFrame.Visible then
        ToggleListBtn.Text = "Hide Egg List ▲"
        populateList()
    else
        ToggleListBtn.Text = "Show Egg List ▼"
    end
end)

--==================================================
-- MINIMIZE
--==================================================
local currentExpandedWidth = Config.PCWidth
local currentExpandedHeight = Config.PCHeight

MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized

    if isMinimized then
        ContentContainer.Visible = false
        tween(MainFrame, {
            Size = UDim2.new(0, currentExpandedWidth, 0, TopBar.Size.Y.Offset)
        }, 0.20)
        MinimizeBtn.Text = "+"
    else
        tween(MainFrame, {
            Size = UDim2.new(0, currentExpandedWidth, 0, currentExpandedHeight)
        }, 0.20)
        task.delay(0.12, function()
            if not isMinimized then
                ContentContainer.Visible = true
            end
        end)
        MinimizeBtn.Text = "–"
    end
end)

--==================================================
-- DRAG
--==================================================
local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

--==================================================
-- KEYBIND TP
--==================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if listeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            tpKeybind = input.KeyCode
            listeningForKey = false
            KeybindBtn.Text = "TP Home Key: [" .. tpKeybind.Name .. "]"
            KeybindBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
        return
    end

    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == tpKeybind then
            teleportToHomePlot()
        end
    end
end)

--==================================================
-- AUTO ESP UPDATER
--==================================================
task.spawn(function()
    while ScreenGui.Parent do
        if mainESPActive then
            for egg, data in pairs(eggData) do
                if egg and egg.Parent then
                    if data.NameBillboard and data.NameBillboard.Enabled then
                        updateEggLabel(egg)
                    end
                end
            end
        end
        task.wait(0.20)
    end
end)

--==================================================
-- WATCH NEW / REMOVED EGGS
--==================================================
if RenderedEggsFolder then
    RenderedEggsFolder.ChildAdded:Connect(function(egg)
        autoFarmProcessed[egg] = nil
        task.wait(0.05)
        updateEggESP(egg)
        if ListContainerFrame.Visible then
            populateList()
        end
    end)

    RenderedEggsFolder.ChildRemoved:Connect(function(egg)
        removeEggData(egg)
        if ListContainerFrame.Visible then
            populateList()
        end
    end)

    for _, egg in ipairs(RenderedEggsFolder:GetChildren()) do
        updateEggESP(egg)
    end
end

--==================================================
-- PC MODE
--==================================================
local function setPCMode()
    isMobileMode = false
    currentExpandedWidth = Config.PCWidth
    currentExpandedHeight = Config.PCHeight

    MainFrame.Size = UDim2.new(0, Config.PCWidth, 0, Config.PCHeight)
    MainFrame.Position = UDim2.new(0.5, -Config.PCWidth / 2, 0.4, -Config.PCHeight / 2)

    TopBar.Size = UDim2.new(1, 0, 0, 50)
    TopFix.Size = UDim2.new(1, 0, 0, 10)
    TopFix.Position = UDim2.new(0, 0, 1, -10)

    AuthorLabel.TextSize = 11
    AuthorLabel.Position = UDim2.new(0, 12, 0, 3)
    TitleLabel.TextSize = 14
    TitleLabel.Position = UDim2.new(0, 12, 0, 17)
    GameLabel.TextSize = 10
    GameLabel.Position = UDim2.new(0, 12, 0, 34)

    MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    MinimizeBtn.Position = UDim2.new(1, -38, 0, 10)
    MinimizeBtn.TextSize = 18

    ContentContainer.Size = UDim2.new(1, -20, 1, -60)
    ContentContainer.Position = UDim2.new(0, 10, 0, 55)

    StatusLabel.TextSize = 11
    StatusLabel.Size = UDim2.new(1, -110, 0, 20)

    StopAutoFarmBtn.Size = UDim2.new(0, 105, 0, 20)
    StopAutoFarmBtn.Position = UDim2.new(1, -105, 0, 0)
    StopAutoFarmBtn.TextSize = 10

    ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 22)
    ModeAutoFarmBtn.TextSize = 11
    ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 30)
    ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 22)
    ModeTeleportBtn.TextSize = 11

    ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 32)
    ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 56)
    ToggleGlobalESPBtn.TextSize = 13

    AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 32)
    AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 92)
    AutoBestEggBtn.TextSize = 13

    TPHomeBtn.Size = UDim2.new(1, 0, 0, 32)
    TPHomeBtn.Position = UDim2.new(0, 0, 0, 128)
    TPHomeBtn.TextSize = 13

    KeybindBtn.Size = UDim2.new(1, 0, 0, 24)
    KeybindBtn.Position = UDim2.new(0, 0, 0, 164)
    KeybindBtn.TextSize = 11

    ToggleListBtn.Size = UDim2.new(1, 0, 0, 30)
    ToggleListBtn.Position = UDim2.new(0, 0, 0, 192)
    ToggleListBtn.TextSize = 12

    ListContainerFrame.Size = UDim2.new(1, 0, 0, 230)
    ListContainerFrame.Position = UDim2.new(0, 0, 0, 226)

    RefreshBtn.TextSize = 12
    SortBtn.TextSize = 12
    SearchBox.TextSize = 12

    DeviceFrame:Destroy()
    MainFrame.Visible = true
    populateList()
end

--==================================================
-- MOBILE MODE
--==================================================
local function setMobileMode()
    isMobileMode = true
    currentExpandedWidth = Config.MobileWidth
    currentExpandedHeight = Config.MobileHeight

    MainFrame.Size = UDim2.new(0, Config.MobileWidth, 0, Config.MobileHeight)
    MainFrame.Position = UDim2.new(0.5, -Config.MobileWidth / 2, 0.5, -Config.MobileHeight / 2)

    TopBar.Size = UDim2.new(1, 0, 0, 42)
    TopFix.Size = UDim2.new(1, 0, 0, 8)
    TopFix.Position = UDim2.new(0, 0, 1, -8)

    AuthorLabel.TextSize = 9
    AuthorLabel.Position = UDim2.new(0, 10, 0, 3)
    TitleLabel.TextSize = 12
    TitleLabel.Position = UDim2.new(0, 10, 0, 14)
    GameLabel.TextSize = 9
    GameLabel.Position = UDim2.new(0, 10, 0, 27)

    MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    MinimizeBtn.Position = UDim2.new(1, -32, 0, 8)
    MinimizeBtn.TextSize = 16

    ContentContainer.Size = UDim2.new(1, -16, 1, -50)
    ContentContainer.Position = UDim2.new(0, 8, 0, 46)

    StatusLabel.TextSize = 10
    StatusLabel.Size = UDim2.new(1, -92, 0, 18)

    StopAutoFarmBtn.Size = UDim2.new(0, 88, 0, 18)
    StopAutoFarmBtn.Position = UDim2.new(1, -88, 0, 0)
    StopAutoFarmBtn.TextSize = 9

    ModeAutoFarmBtn.Size = UDim2.new(0.5, -3, 0, 26)
    ModeAutoFarmBtn.Position = UDim2.new(0, 0, 0, 20)
    ModeAutoFarmBtn.TextSize = 10
    ModeTeleportBtn.Size = UDim2.new(0.5, -3, 0, 26)
    ModeTeleportBtn.Position = UDim2.new(0.5, 3, 0, 20)
    ModeTeleportBtn.TextSize = 10

    ToggleGlobalESPBtn.Size = UDim2.new(1, 0, 0, 28)
    ToggleGlobalESPBtn.Position = UDim2.new(0, 0, 0, 50)
    ToggleGlobalESPBtn.TextSize = 11

    AutoBestEggBtn.Size = UDim2.new(1, 0, 0, 28)
    AutoBestEggBtn.Position = UDim2.new(0, 0, 0, 82)
    AutoBestEggBtn.TextSize = 11

    TPHomeBtn.Size = UDim2.new(1, 0, 0, 28)
    TPHomeBtn.Position = UDim2.new(0, 0, 0, 114)
    TPHomeBtn.TextSize = 11

    KeybindBtn.Size = UDim2.new(1, 0, 0, 22)
    KeybindBtn.Position = UDim2.new(0, 0, 0, 146)
    KeybindBtn.TextSize = 10

    ToggleListBtn.Size = UDim2.new(1, 0, 0, 28)
    ToggleListBtn.Position = UDim2.new(0, 0, 0, 172)
    ToggleListBtn.TextSize = 11

    ListContainerFrame.Size = UDim2.new(1, 0, 0, 184)
    ListContainerFrame.Position = UDim2.new(0, 0, 0, 204)

    EggCountLabel.TextSize = 10

    RefreshBtn.Size = UDim2.new(0.48, -5, 0, 22)
    RefreshBtn.Position = UDim2.new(0, 5, 0, 26)
    RefreshBtn.TextSize = 10

    SortBtn.Size = UDim2.new(0.48, -5, 0, 22)
    SortBtn.Position = UDim2.new(0.52, 0, 0, 26)
    SortBtn.TextSize = 10

    SearchBox.Size = UDim2.new(1, -10, 0, 22)
    SearchBox.Position = UDim2.new(0, 5, 0, 52)
    SearchBox.TextSize = 10

    ScrollList.Size = UDim2.new(1, -10, 1, -80)
    ScrollList.Position = UDim2.new(0, 5, 0, 80)

    DeviceFrame:Destroy()
    MainFrame.Visible = true
    populateList()
end

--==================================================
-- DEVICE BUTTONS
--==================================================
PCBtn.MouseButton1Click:Connect(setPCMode)
MobileBtn.MouseButton1Click:Connect(setMobileMode)

--==================================================
-- END
--==================================================
print("[EGOY RIDE A PET] Loaded successfully. 🐾")