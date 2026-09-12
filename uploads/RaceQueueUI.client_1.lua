--[[
	RaceQueueUI.client.lua
	LocalScript — place in StarterGui

	Builds the entire race queue UI via code (no manual Frame/Button creation
	needed in Studio). Shows:
		- Live countdown to the next race
		- How many players are currently queued
		- A Join Queue / Leave Queue button that talks to the server

	Reads from RaceRemotes (created by RaceQueueBootstrap.server.lua):
		RemoteEvent    QueueTick    -> (timeRemaining, queueCount)
		RemoteEvent    RaceStarted  -> (raceId, botCount)   [fires only to players who got in]
		RemoteFunction JoinQueue    -> () -> success, message
		RemoteFunction LeaveQueue   -> () -> success, message
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local queueTickEvent = raceRemotes:WaitForChild("QueueTick")
local raceStartedEvent = raceRemotes:WaitForChild("RaceStarted")
local joinQueueFunction = raceRemotes:WaitForChild("JoinQueue")
local leaveQueueFunction = raceRemotes:WaitForChild("LeaveQueue")

-- === Local state ===
local isQueued = false
local isWaitingForServer = false -- prevents spam-clicking while a request is in flight

-- === Build the UI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RaceQueueUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "RaceQueueFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 130)
mainFrame.Position = UDim2.new(1, -260, 0, 20) -- top-right corner
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -26, 0, 22)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "NEXT RACE"
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 22, 0, 22)
minimizeButton.Position = UDim2.new(1, -22, 0, 0)
minimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.Parent = mainFrame

local minimizeButtonCorner = Instance.new("UICorner")
minimizeButtonCorner.CornerRadius = UDim.new(0, 6)
minimizeButtonCorner.Parent = minimizeButton

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, 0, 0, 34)
timerLabel.Position = UDim2.new(0, 0, 0, 24)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "5:00"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 28
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = mainFrame

local queueCountLabel = Instance.new("TextLabel")
queueCountLabel.Name = "QueueCount"
queueCountLabel.Size = UDim2.new(1, 0, 0, 18)
queueCountLabel.Position = UDim2.new(0, 0, 0, 60)
queueCountLabel.BackgroundTransparency = 1
queueCountLabel.Text = "0 players queued"
queueCountLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
queueCountLabel.Font = Enum.Font.Gotham
queueCountLabel.TextSize = 14
queueCountLabel.TextXAlignment = Enum.TextXAlignment.Left
queueCountLabel.Parent = mainFrame

local joinButton = Instance.new("TextButton")
joinButton.Name = "JoinButton"
joinButton.Size = UDim2.new(1, 0, 0, 34)
joinButton.Position = UDim2.new(0, 0, 0, 84)
joinButton.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
joinButton.Text = "Join Queue"
joinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
joinButton.Font = Enum.Font.GothamBold
joinButton.TextSize = 16
joinButton.AutoButtonColor = true
joinButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = joinButton

-- === Collapsed / minimized icon (bottom-right corner) ===
local minimizedFrame = Instance.new("Frame")
minimizedFrame.Name = "MinimizedIcon"
minimizedFrame.Size = UDim2.new(0, 70, 0, 70)
minimizedFrame.Position = UDim2.new(1, -90, 1, -90) -- bottom-right corner
minimizedFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
minimizedFrame.BackgroundTransparency = 0.15
minimizedFrame.BorderSizePixel = 0
minimizedFrame.Visible = false
minimizedFrame.Parent = screenGui

local minimizedCorner = Instance.new("UICorner")
minimizedCorner.CornerRadius = UDim.new(1, 0) -- fully round pill/circle
minimizedCorner.Parent = minimizedFrame

local minimizedButton = Instance.new("TextButton")
minimizedButton.Name = "RestoreButton"
minimizedButton.Size = UDim2.new(1, 0, 1, 0)
minimizedButton.BackgroundTransparency = 1
minimizedButton.Text = ""
minimizedButton.Parent = minimizedFrame

local minimizedTimerLabel = Instance.new("TextLabel")
minimizedTimerLabel.Name = "MiniTimer"
minimizedTimerLabel.Size = UDim2.new(1, 0, 0, 20)
minimizedTimerLabel.Position = UDim2.new(0, 0, 0, 14)
minimizedTimerLabel.BackgroundTransparency = 1
minimizedTimerLabel.Text = "5:00"
minimizedTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizedTimerLabel.Font = Enum.Font.GothamBold
minimizedTimerLabel.TextSize = 16
minimizedTimerLabel.Parent = minimizedFrame

local minimizedSubLabel = Instance.new("TextLabel")
minimizedSubLabel.Name = "MiniLabel"
minimizedSubLabel.Size = UDim2.new(1, 0, 0, 14)
minimizedSubLabel.Position = UDim2.new(0, 0, 0, 36)
minimizedSubLabel.BackgroundTransparency = 1
minimizedSubLabel.Text = "RACE"
minimizedSubLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
minimizedSubLabel.Font = Enum.Font.GothamBold
minimizedSubLabel.TextSize = 11
minimizedSubLabel.Parent = minimizedFrame

-- === A small toast notification for "Race starting!" (since no race scene yet) ===
local TextService = game:GetService("TextService")

local function showToast(text, color)
	local font = Enum.Font.GothamBold
	local textSize = 16
	local maxWidth = 380
	local horizontalPadding = 24
	local verticalPadding = 14

	-- Measure the text so the toast always fits it, up to maxWidth, then wraps
	local textBounds = TextService:GetTextSize(text, textSize, font, Vector2.new(maxWidth, math.huge))
	local toastWidth = math.min(maxWidth, textBounds.X + horizontalPadding * 2)
	local toastHeight = textBounds.Y + verticalPadding * 2

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, toastWidth, 0, toastHeight)
	toast.Position = UDim2.new(0.5, -toastWidth / 2, 0, -toastHeight - 20)
	toast.BackgroundColor3 = color or Color3.fromRGB(40, 40, 45)
	toast.BackgroundTransparency = 0.1
	toast.Text = text
	toast.TextWrapped = true
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.Font = font
	toast.TextSize = textSize
	toast.Parent = screenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local slideIn = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -toastWidth / 2, 0, 20),
	})
	slideIn:Play()

	task.wait(3)

	local slideOut = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -toastWidth / 2, 0, -toastHeight - 20),
	})
	slideOut:Play()
	slideOut.Completed:Wait()
	toast:Destroy()
end

-- === Format seconds as m:ss ===
local function formatTime(seconds)
	seconds = math.max(0, seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

-- === Update button appearance based on queued state ===
local function updateButtonVisual()
	if isQueued then
		joinButton.Text = "Leave Queue"
		joinButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	else
		joinButton.Text = "Join Queue"
		joinButton.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
	end
end

-- === Minimize / restore handlers ===
minimizeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	minimizedFrame.Visible = true
end)

minimizedButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	minimizedFrame.Visible = false
end)

-- === Button click handler ===
joinButton.MouseButton1Click:Connect(function()
	if isWaitingForServer then return end
	isWaitingForServer = true
	joinButton.AutoButtonColor = false

	local success, message
	if isQueued then
		success, message = leaveQueueFunction:InvokeServer()
	else
		success, message = joinQueueFunction:InvokeServer()
	end

	if success then
		isQueued = not isQueued
		updateButtonVisual()
	else
		-- Server rejected it (e.g. already queued) — show why
		task.spawn(showToast, message, Color3.fromRGB(120, 40, 40))
	end

	isWaitingForServer = false
	joinButton.AutoButtonColor = true
end)

-- === Live countdown + queue count updates ===
queueTickEvent.OnClientEvent:Connect(function(timeRemaining, queueCount)
	local formatted = formatTime(timeRemaining)
	timerLabel.Text = formatted
	minimizedTimerLabel.Text = formatted
	queueCountLabel.Text = queueCount .. (queueCount == 1 and " player queued" or " players queued")

	-- Flash red in the last 10 seconds so it feels urgent
	local urgentColor = timeRemaining <= 10
	timerLabel.TextColor3 = urgentColor and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
	minimizedTimerLabel.TextColor3 = urgentColor and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
end)

-- === Race started — only fires for players who actually got into a race group ===
raceStartedEvent.OnClientEvent:Connect(function(raceId, botCount)
	isQueued = false
	updateButtonVisual()
	task.spawn(showToast, "Race starting! (" .. botCount .. " bot" .. (botCount == 1 and "" or "s") .. " filling remaining seats)", Color3.fromRGB(40, 120, 60))
	-- NOTE: this is a placeholder notification. Once the Race Engine is built,
	-- this is where we'll actually teleport the player into the race instance.
end)
