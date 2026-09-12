--[[
	GarageUI.client.lua
	LocalScript — place in StarterGui

	Builds the entire Garage/Dealership UI via code:
		- A persistent cash display (top-left)
		- A "Garage" toggle button
		- A browsable panel: brand tabs (Honda / BMW / Ferrari / Lamborghini),
		  each showing its models as cards with price, stats, abilities,
		  and a Buy / Select / Current Car button

	Reads car data directly from CarConfig (ReplicatedStorage ModuleScript) —
	no extra remote needed for that part, since it's static shared data.

	Talks to EconomyRemotes (created by EconomyBootstrap.server.lua):
		RemoteEvent    CashUpdated    -> (newCash)
		RemoteFunction PurchaseCar    -> (brand, model) -> success, message
		RemoteFunction SelectCar      -> (brand, model) -> success, message
		RemoteFunction GetPlayerData  -> () -> full data table {Cash, OwnedCars, CurrentCar}
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local CarConfig = require(ReplicatedStorage:WaitForChild("CarConfig"))

local economyRemotes = ReplicatedStorage:WaitForChild("EconomyRemotes")
local cashUpdatedEvent = economyRemotes:WaitForChild("CashUpdated")
local purchaseCarFunction = economyRemotes:WaitForChild("PurchaseCar")
local selectCarFunction = economyRemotes:WaitForChild("SelectCar")
local getPlayerDataFunction = economyRemotes:WaitForChild("GetPlayerData")

-- === Local cache of player data, refreshed on open and after purchases/selects ===
local localData = {
	Cash = 0,
	OwnedCars = {},
	CurrentCar = { Brand = "Honda", Model = "Civic 2001" },
}

local selectedBrand = CarConfig.BrandOrder[1]

-- === Build the UI shell ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GarageUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- --- Cash display (top-left, always visible) ---
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.Size = UDim2.new(0, 160, 0, 44)
cashFrame.Position = UDim2.new(0, 20, 0, 20)
cashFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
cashFrame.BackgroundTransparency = 0.15
cashFrame.Parent = screenGui

local cashCorner = Instance.new("UICorner")
cashCorner.CornerRadius = UDim.new(0, 10)
cashCorner.Parent = cashFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -16, 1, 0)
cashLabel.Position = UDim2.new(0, 8, 0, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "$0"
cashLabel.TextColor3 = Color3.fromRGB(90, 220, 120)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextSize = 22
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = cashFrame

-- --- Garage toggle button (below cash display) ---
local garageToggleButton = Instance.new("TextButton")
garageToggleButton.Name = "GarageToggleButton"
garageToggleButton.Size = UDim2.new(0, 160, 0, 40)
garageToggleButton.Position = UDim2.new(0, 20, 0, 72)
garageToggleButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
garageToggleButton.Text = "🚗 Garage"
garageToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
garageToggleButton.Font = Enum.Font.GothamBold
garageToggleButton.TextSize = 18
garageToggleButton.Parent = screenGui

local garageToggleCorner = Instance.new("UICorner")
garageToggleCorner.CornerRadius = UDim.new(0, 8)
garageToggleCorner.Parent = garageToggleButton

-- --- Main Garage panel (hidden by default) ---
local garageFrame = Instance.new("Frame")
garageFrame.Name = "GarageFrame"
garageFrame.Size = UDim2.new(0, 640, 0, 480)
garageFrame.Position = UDim2.new(0.5, -320, 0.5, -240)
garageFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
garageFrame.Visible = false
garageFrame.Parent = screenGui

local garageCorner = Instance.new("UICorner")
garageCorner.CornerRadius = UDim.new(0, 14)
garageCorner.Parent = garageFrame

-- Header
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 50)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = garageFrame

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -60, 1, 0)
headerTitle.Position = UDim2.new(0, 16, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "GARAGE"
headerTitle.TextColor3 = Color3.fromRGB(255, 200, 60)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 22
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = headerFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 36, 0, 36)
closeButton.Position = UDim2.new(1, -46, 0, 7)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = headerFrame

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

-- === Make the panel draggable by clicking/dragging the header ===
headerFrame.Active = true

local dragging = false
local dragInput, dragStartMousePos, dragStartFramePos

headerFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStartMousePos = input.Position
		dragStartFramePos = garageFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

headerFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local delta = input.Position - dragStartMousePos
		garageFrame.Position = UDim2.new(
			dragStartFramePos.X.Scale, dragStartFramePos.X.Offset + delta.X,
			dragStartFramePos.Y.Scale, dragStartFramePos.Y.Offset + delta.Y
		)
	end
end)

-- Brand tab bar
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -32, 0, 40)
tabBar.Position = UDim2.new(0, 16, 0, 54)
tabBar.BackgroundTransparency = 1
tabBar.Parent = garageFrame

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.Padding = UDim.new(0, 8)
tabBarLayout.Parent = tabBar

local tabButtons = {} -- [brandName] = button, for highlight state

-- Scrolling car list
local carListFrame = Instance.new("ScrollingFrame")
carListFrame.Name = "CarList"
carListFrame.Size = UDim2.new(1, -32, 1, -174)
carListFrame.Position = UDim2.new(0, 16, 0, 114)
carListFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
carListFrame.BorderSizePixel = 0
carListFrame.ScrollBarThickness = 6
carListFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-updated below
carListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
carListFrame.Parent = garageFrame

local carListCorner = Instance.new("UICorner")
carListCorner.CornerRadius = UDim.new(0, 10)
carListCorner.Parent = carListFrame

local carListLayout = Instance.new("UIListLayout")
carListLayout.Padding = UDim.new(0, 8)
carListLayout.Parent = carListFrame

local carListPadding = Instance.new("UIPadding")
carListPadding.PaddingTop = UDim.new(0, 8)
carListPadding.PaddingLeft = UDim.new(0, 8)
carListPadding.PaddingRight = UDim.new(0, 8)
carListPadding.PaddingBottom = UDim.new(0, 8)
carListPadding.Parent = carListFrame

-- Status/feedback message (e.g. "Purchased Civic Si!")
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -32, 0, 30)
statusLabel.Position = UDim2.new(0, 16, 1, -40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = garageFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(1, -32, 0, 16)
hintLabel.Position = UDim2.new(0, 16, 0, 96)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = "Own it here, then visit the dealership in the world to actually drive it."
hintLabel.TextColor3 = Color3.fromRGB(140, 140, 148)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = garageFrame

-- === Helpers ===

local function formatMoney(amount)
	-- adds comma separators, e.g. 120000 -> "120,000"
	local formatted = tostring(math.floor(amount))
	local result = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	result = result:gsub("^,", "")
	return "$" .. result
end

--[[ Builds a short human-readable line describing a car's abilities ]]
local function describeAbilities(abilities)
	local parts = {}

	if abilities.autoCorrectCase and abilities.autoCorrectCase > 0 then
		table.insert(parts, string.format("Auto-fixes capitalization (%d%%)", abilities.autoCorrectCase * 100))
	end

	if abilities.skipPunctuation and abilities.skipPunctuation ~= "none" then
		local punctDescriptions = {
			period = "Skips periods",
			period_comma = "Skips periods & commas",
			all = "Skips all punctuation",
		}
		table.insert(parts, punctDescriptions[abilities.skipPunctuation] or "Skips punctuation")
	end

	if abilities.typoForgiveness and abilities.typoForgiveness > 0 then
		table.insert(parts, string.format("%d%% typo forgiveness", abilities.typoForgiveness * 100))
	end

	if abilities.skipWord and abilities.skipWord > 0 then
		table.insert(parts, "Skip " .. abilities.skipWord .. " word/race")
	end

	if abilities.skipSentence and abilities.skipSentence > 0 then
		table.insert(parts, "Skip " .. abilities.skipSentence .. " sentence/race")
	end

	if #parts == 0 then
		return "No special abilities yet"
	end

	return table.concat(parts, " • ")
end

local function isOwned(brand, modelName)
	return localData.OwnedCars[brand .. "_" .. modelName] == true
end

local function isCurrent(brand, modelName)
	return localData.CurrentCar
		and localData.CurrentCar.Brand == brand
		and localData.CurrentCar.Model == modelName
end

local function showStatus(text, isError)
	statusLabel.Text = text
	statusLabel.TextColor3 = isError and Color3.fromRGB(230, 100, 100) or Color3.fromRGB(120, 220, 140)
end

--[[ Top-of-screen toast — always renders in front of the Garage panel (and
     everything else), regardless of scroll position or panel dragging.
     Used for feedback like "Not enough cash" so it can't get missed/covered. ]]
local activeToast = nil

local function showToast(text, isError)
	-- If a toast is already showing, remove it instantly so they don't stack
	if activeToast then
		activeToast:Destroy()
		activeToast = nil
	end

	local font = Enum.Font.GothamBold
	local textSize = 16
	local maxWidth = 380
	local horizontalPadding = 24
	local verticalPadding = 14

	local textBounds = TextService:GetTextSize(text, textSize, font, Vector2.new(maxWidth, math.huge))
	local toastWidth = math.min(maxWidth, textBounds.X + horizontalPadding * 2)
	local toastHeight = textBounds.Y + verticalPadding * 2

	local toast = Instance.new("TextLabel")
	toast.ZIndex = 100 -- guaranteed to render above the Garage panel and everything else
	toast.Size = UDim2.new(0, toastWidth, 0, toastHeight)
	toast.Position = UDim2.new(0.5, -toastWidth / 2, 0, -toastHeight - 20)
	toast.BackgroundColor3 = isError and Color3.fromRGB(150, 45, 45) or Color3.fromRGB(40, 120, 60)
	toast.BackgroundTransparency = 0.05
	toast.Text = text
	toast.TextWrapped = true
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.Font = font
	toast.TextSize = textSize
	toast.Parent = screenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	activeToast = toast

	local slideIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -toastWidth / 2, 0, 20),
	})
	slideIn:Play()

	task.delay(2.5, function()
		if activeToast ~= toast then return end -- a newer toast already replaced this one
		local slideOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -toastWidth / 2, 0, -toastHeight - 20),
		})
		slideOut:Play()
		slideOut.Completed:Wait()
		if activeToast == toast then
			activeToast = nil
		end
		toast:Destroy()
	end)
end

-- Forward-declared so buttons can trigger a re-render after purchase/select
local renderBrand

--[[ Builds one car "card" row inside the scrolling list ]]
local function createCarCard(brand, model)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 84)
	card.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
	card.Parent = carListFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.6, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = model.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(0.6, 0, 0, 18)
	statsLabel.Position = UDim2.new(0, 12, 0, 32)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = string.format("Speed x%.2f", model.baseSpeedMult)
	statsLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 13
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Parent = card

	local abilitiesLabel = Instance.new("TextLabel")
	abilitiesLabel.Size = UDim2.new(0.6, 0, 0, 18)
	abilitiesLabel.Position = UDim2.new(0, 12, 0, 52)
	abilitiesLabel.BackgroundTransparency = 1
	abilitiesLabel.Text = describeAbilities(model.abilities)
	abilitiesLabel.TextColor3 = Color3.fromRGB(120, 170, 220)
	abilitiesLabel.Font = Enum.Font.Gotham
	abilitiesLabel.TextSize = 12
	abilitiesLabel.TextXAlignment = Enum.TextXAlignment.Left
	abilitiesLabel.TextWrapped = true
	abilitiesLabel.Parent = card

	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(0, 150, 0, 40)
	actionButton.Position = UDim2.new(1, -162, 0.5, -20)
	actionButton.Font = Enum.Font.GothamBold
	actionButton.TextSize = 15
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Parent = card

	local actionButtonCorner = Instance.new("UICorner")
	actionButtonCorner.CornerRadius = UDim.new(0, 8)
	actionButtonCorner.Parent = actionButton

	if isCurrent(brand, model.name) then
		actionButton.Text = "CURRENT CAR"
		actionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
		actionButton.Active = false
	elseif isOwned(brand, model.name) then
		actionButton.Text = "OWNED"
		actionButton.BackgroundColor3 = Color3.fromRGB(60, 90, 110)
		actionButton.Active = false
		-- Player already owns this car, but picking it as their current ride
		-- now happens physically at the dealership (ProximityPrompt), not here.
	else
		actionButton.Text = model.price == 0 and "FREE" or ("BUY " .. formatMoney(model.price))
		actionButton.BackgroundColor3 = Color3.fromRGB(210, 160, 40)
		actionButton.MouseButton1Click:Connect(function()
			actionButton.Active = false
			local success, message = purchaseCarFunction:InvokeServer(brand, model.name)
			showStatus(message, not success)
			showToast(message, not success)
			if success then
				localData.OwnedCars[brand .. "_" .. model.name] = true
				renderBrand(selectedBrand) -- refresh so it now shows OWNED
			end
			actionButton.Active = true
		end)
	end

	return card
end

--[[ Clears and rebuilds the car list for the given brand ]]
renderBrand = function(brandName)
	selectedBrand = brandName

	-- Highlight the active tab
	for name, button in pairs(tabButtons) do
		if name == brandName then
			button.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
		else
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		end
	end

	-- Clear existing cards
	for _, child in ipairs(carListFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local brand = CarConfig.Brands[brandName]
	for _, model in ipairs(brand.models) do
		createCarCard(brandName, model)
	end
end

-- === Build brand tab buttons ===
for _, brandName in ipairs(CarConfig.BrandOrder) do
	local tabButton = Instance.new("TextButton")
	tabButton.Name = brandName .. "Tab"
	tabButton.Size = UDim2.new(0, 120, 1, 0)
	tabButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	tabButton.Text = CarConfig.Brands[brandName].displayName
	tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabButton.Font = Enum.Font.GothamBold
	tabButton.TextSize = 15
	tabButton.Parent = tabBar

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 8)
	tabCorner.Parent = tabButton

	tabButton.MouseButton1Click:Connect(function()
		statusLabel.Text = ""
		renderBrand(brandName)
	end)

	tabButtons[brandName] = tabButton
end

-- === Open / close handlers ===
local function refreshPlayerDataAndOpen()
	local data = getPlayerDataFunction:InvokeServer()
	if data then
		localData = data
	end
	cashLabel.Text = formatMoney(localData.Cash)
	statusLabel.Text = ""
	garageFrame.Visible = true
	renderBrand(selectedBrand)
end

garageToggleButton.MouseButton1Click:Connect(function()
	if garageFrame.Visible then
		garageFrame.Visible = false
	else
		refreshPlayerDataAndOpen()
	end
end)

closeButton.MouseButton1Click:Connect(function()
	garageFrame.Visible = false
end)

-- === Keep cash display live at all times, not just while garage is open ===
cashUpdatedEvent.OnClientEvent:Connect(function(newCash)
	localData.Cash = newCash
	cashLabel.Text = formatMoney(newCash)
end)

-- === Initial cash load on join ===
task.spawn(function()
	local data = getPlayerDataFunction:InvokeServer()
	if data then
		localData = data
		cashLabel.Text = formatMoney(localData.Cash)
	end
end)
