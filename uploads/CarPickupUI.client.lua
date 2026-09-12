--[[
	CarPickupUI.client.lua
	LocalScript — place in StarterGui

	Listens for the OpenCarPickup RemoteEvent (fired by DealershipInteraction
	when a player interacts with a dealership ProximityPrompt). Shows a small
	popup listing every car the player owns for that brand, with a "Drive"
	button for each — clicking one calls the existing SelectCar RemoteFunction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local CarConfig = require(ReplicatedStorage:WaitForChild("CarConfig"))

local dealershipRemotes = ReplicatedStorage:WaitForChild("DealershipRemotes")
local openCarPickupEvent = dealershipRemotes:WaitForChild("OpenCarPickup")

local economyRemotes = ReplicatedStorage:WaitForChild("EconomyRemotes")
local selectCarFunction = economyRemotes:WaitForChild("SelectCar")

-- === Build the UI shell (hidden until triggered) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CarPickupUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local pickupFrame = Instance.new("Frame")
pickupFrame.Name = "PickupFrame"
pickupFrame.Size = UDim2.new(0, 340, 0, 300)
pickupFrame.Position = UDim2.new(0.5, -170, 0.5, -150)
pickupFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
pickupFrame.Visible = false
pickupFrame.Parent = screenGui

local pickupCorner = Instance.new("UICorner")
pickupCorner.CornerRadius = UDim.new(0, 14)
pickupCorner.Parent = pickupFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 0, 44)
titleLabel.Position = UDim2.new(0, 16, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "PICK A CAR"
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = pickupFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -42, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.Parent = pickupFrame

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	pickupFrame.Visible = false
end)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "ListFrame"
listFrame.Size = UDim2.new(1, -32, 1, -64)
listFrame.Position = UDim2.new(0, 16, 0, 52)
listFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = pickupFrame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = listFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 8)
listPadding.PaddingLeft = UDim.new(0, 8)
listPadding.PaddingRight = UDim.new(0, 8)
listPadding.PaddingBottom = UDim.new(0, 8)
listPadding.Parent = listFrame

--[[ Creates one row for a car the player can choose to drive ]]
local function createPickupRow(brand, modelName)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
	row.Parent = listFrame

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = modelName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local driveButton = Instance.new("TextButton")
	driveButton.Size = UDim2.new(0, 110, 0, 36)
	driveButton.Position = UDim2.new(1, -120, 0.5, -18)
	driveButton.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
	driveButton.Text = "DRIVE"
	driveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	driveButton.Font = Enum.Font.GothamBold
	driveButton.TextSize = 14
	driveButton.Parent = row

	local driveButtonCorner = Instance.new("UICorner")
	driveButtonCorner.CornerRadius = UDim.new(0, 8)
	driveButtonCorner.Parent = driveButton

	driveButton.MouseButton1Click:Connect(function()
		driveButton.Active = false
		local success, message = selectCarFunction:InvokeServer(brand, modelName)
		if success then
			pickupFrame.Visible = false
		else
			driveButton.Text = "FAILED"
			task.wait(1.2)
			driveButton.Text = "DRIVE"
		end
		driveButton.Active = true
	end)
end

--[[ Shows a message when the player owns nothing from this brand yet ]]
local function createEmptyMessage(brand)
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Size = UDim2.new(1, 0, 0, 80)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "You don't own any " .. brand .. " cars yet.\nBuy one from the Garage first!"
	emptyLabel.TextWrapped = true
	emptyLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextSize = 14
	emptyLabel.Parent = listFrame
end

-- === Listen for the server telling us to open this UI ===
openCarPickupEvent.OnClientEvent:Connect(function(brand, ownedModels)
	-- Clear any previous rows
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	titleLabel.Text = "PICK A " .. brand:upper() .. " TO DRIVE"

	if #ownedModels == 0 then
		createEmptyMessage(brand)
	else
		for _, modelName in ipairs(ownedModels) do
			createPickupRow(brand, modelName)
		end
	end

	pickupFrame.Visible = true
end)
