--[[
	CardMatchingUI.client.lua
	LocalScript — place in StarterPlayerScripts

	Listens for the OpenJobMinigame RemoteEvent (fired by JobStationInteraction
	when a player interacts with a "Card Matching" job station). Shows a 4x4
	flip-and-match card grid. All the actual game logic runs client-side
	(nothing here is sensitive), but the payout is validated server-side by
	JobMinigameService — this script just reports how many moves it took.

	Talks to JobRemotes (created by JobStationInteraction / JobMinigameService):
		RemoteEvent    OpenJobMinigame -> (jobType)
		RemoteFunction StartJob        -> (jobType) -> success, message
		RemoteFunction CompleteJob     -> (jobType, movesUsed) -> success, message, payout
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local jobRemotes = ReplicatedStorage:WaitForChild("JobRemotes")
local openJobMinigameEvent = jobRemotes:WaitForChild("OpenJobMinigame")
local startJobFunction = jobRemotes:WaitForChild("StartJob")
local completeJobFunction = jobRemotes:WaitForChild("CompleteJob")
local cancelJobEvent = jobRemotes:WaitForChild("CancelJob")
local sessionToken = nil
local sessionVersion = 0
local starting = false
local function cancelSession()
 sessionVersion += 1
 if sessionToken then cancelJobEvent:FireServer(sessionToken) end
 sessionToken = nil
end
local function completeSession(job, score)
 local token = sessionToken
 if not token then return false, "No active job." end
 sessionToken = nil -- a completed session can only be submitted once
 local ok, success, message, payout = pcall(function()
  return completeJobFunction:InvokeServer(job, score, token)
 end)
 if not ok then
  cancelJobEvent:FireServer(token)
  return false, "Connection interrupted. Please start again."
 end
 return success, message, payout
end


-- === Game constants ===
local GRID_SIZE = 4 -- 4x4 = 16 cards = 8 pairs
local TOTAL_PAIRS = (GRID_SIZE * GRID_SIZE) / 2
local FLIP_BACK_DELAY = 0.6 -- seconds a mismatched pair stays visible before flipping back

local CARD_COLORS = {
	Color3.fromRGB(220, 60, 60),   -- red
	Color3.fromRGB(60, 140, 220),  -- blue
	Color3.fromRGB(60, 200, 100),  -- green
	Color3.fromRGB(230, 200, 40),  -- yellow
	Color3.fromRGB(200, 100, 220), -- purple
	Color3.fromRGB(240, 150, 40),  -- orange
	Color3.fromRGB(80, 220, 200),  -- teal
	Color3.fromRGB(230, 230, 230), -- white
}

local CARD_BACK_COLOR = Color3.fromRGB(45, 45, 52)

-- === Build the UI shell (hidden until triggered) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CardMatchingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local gameFrame = Instance.new("Frame")
gameFrame.Name = "GameFrame"
gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
gameFrame.Size = UDim2.new(0.34, 0, 0.68, 0)
gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
gameFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
gameFrame.Visible = false
gameFrame.Parent = screenGui

local gameFrameSizeConstraint = Instance.new("UISizeConstraint")
gameFrameSizeConstraint.MinSize = Vector2.new(340, 440)
gameFrameSizeConstraint.MaxSize = Vector2.new(460, 580)
gameFrameSizeConstraint.Parent = gameFrame

local gameFrameCorner = Instance.new("UICorner")
gameFrameCorner.CornerRadius = UDim.new(0, 14)
gameFrameCorner.Parent = gameFrame

-- Header
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 0, 40)
titleLabel.Position = UDim2.new(0, 16, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CARD MATCHING"
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = gameFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 36, 0, 36)
closeButton.Position = UDim2.new(1, -46, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = gameFrame

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

local movesLabel = Instance.new("TextLabel")
movesLabel.Size = UDim2.new(1, -32, 0, 24)
movesLabel.Position = UDim2.new(0, 16, 0, 48)
movesLabel.BackgroundTransparency = 1
movesLabel.Text = "Moves: 0"
movesLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
movesLabel.Font = Enum.Font.Gotham
movesLabel.TextSize = 15
movesLabel.TextXAlignment = Enum.TextXAlignment.Left
movesLabel.Parent = gameFrame

-- Grid container
local gridFrame = Instance.new("Frame")
gridFrame.Name = "GridFrame"
gridFrame.Size = UDim2.new(1, -32, 1, -160)
gridFrame.Position = UDim2.new(0, 16, 0, 80)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = gameFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.23, 0, 0.23, 0)
gridLayout.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

-- Result message (shown briefly after completion)
local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, -32, 0, 24)
resultLabel.Position = UDim2.new(0, 16, 1, -34)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = ""
resultLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 15
resultLabel.TextXAlignment = Enum.TextXAlignment.Left
resultLabel.Parent = gameFrame

closeButton.MouseButton1Click:Connect(function()
	cancelSession()
	gameFrame.Visible = false
end)

-- === Game state ===
local cardButtons = {}   -- array of { button = TextButton, value = number, matched = bool }
local flippedIndices = {}
local isBusy = false
local movesCount = 0
local matchesFound = 0

--[[ Fisher-Yates shuffle ]]
local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

--[[ Clears the grid so a fresh game can be built ]]
local function clearGrid()
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	cardButtons = {}
	flippedIndices = {}
	isBusy = false
	movesCount = 0
	matchesFound = 0
	movesLabel.Text = "Moves: 0"
	resultLabel.Text = ""
end

local function setCardFace(cardData, faceUp)
	if faceUp then
		cardData.button.BackgroundColor3 = CARD_COLORS[cardData.value]
	else
		cardData.button.BackgroundColor3 = CARD_BACK_COLOR
	end
end

--[[ Called once two cards are flipped — checks for a match ]]
local function resolveFlippedPair()
	local runVersion = sessionVersion
	isBusy = true
	movesCount += 1
	movesLabel.Text = "Moves: " .. movesCount

	local firstIndex, secondIndex = flippedIndices[1], flippedIndices[2]
	local first, second = cardButtons[firstIndex], cardButtons[secondIndex]

	if first.value == second.value then
		-- Match! Keep both face-up and lock them
		first.matched = true
		second.matched = true
		first.button.Active = false
		second.button.Active = false

		local matchTween1 = TweenService:Create(first.button, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 })
		local matchTween2 = TweenService:Create(second.button, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 })
		matchTween1:Play()
		matchTween2:Play()

		matchesFound += 1
		flippedIndices = {}
		isBusy = false

		if matchesFound >= TOTAL_PAIRS then
			-- Player finished the whole grid — submit the result
			task.spawn(function()
				resultLabel.Text = "Submitting..."
				resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

				local success, message, payout = completeSession("Card Matching", movesCount)
				if runVersion ~= sessionVersion then return end

				if success then
					resultLabel.Text = message
					resultLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
				else
					resultLabel.Text = message
					resultLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
				end

				task.wait(2)
				if runVersion ~= sessionVersion then return end
				gameFrame.Visible = false
			end)
		end
	else
		-- No match — flip both back after a short delay so the player can see them
		task.wait(FLIP_BACK_DELAY)
		if runVersion ~= sessionVersion then return end
		setCardFace(first, false)
		setCardFace(second, false)
		flippedIndices = {}
		isBusy = false
	end
end

local function onCardClicked(index)
	if isBusy or not sessionToken then return end

	local cardData = cardButtons[index]
	if cardData.matched then return end

	-- Ignore clicking the same card twice, or a third card while resolving
	for _, flippedIndex in ipairs(flippedIndices) do
		if flippedIndex == index then
			return
		end
	end
	if #flippedIndices >= 2 then return end

	setCardFace(cardData, true)
	table.insert(flippedIndices, index)

	if #flippedIndices == 2 then
		task.spawn(resolveFlippedPair)
	end
end

--[[ Builds a brand new shuffled grid and starts the server-side session ]]
local function startNewGame()
 if starting or sessionToken then return end
 starting = true
 sessionVersion += 1
 local version = sessionVersion
 resultLabel.Text = "Starting..."
 local ok, accepted, message, token = pcall(function()
  return startJobFunction:InvokeServer("Card Matching")
 end)
 starting = false
 if version ~= sessionVersion or not gameFrame.Visible then
  if ok and accepted and token then cancelJobEvent:FireServer(token) end
  return
 end
 if not ok or not accepted then
  resultLabel.Text = ok and message or "Unable to start. Please try again."
  resultLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
  return
 end
 sessionToken = token

	clearGrid()

	-- Build the deck: each color value appears exactly twice
	local deck = {}
	for colorIndex = 1, TOTAL_PAIRS do
		table.insert(deck, colorIndex)
		table.insert(deck, colorIndex)
	end
	shuffle(deck)

	for i, value in ipairs(deck) do
		local button = Instance.new("TextButton")
		button.Name = "Card" .. i
		button.LayoutOrder = i
		button.Text = ""
		button.BackgroundColor3 = CARD_BACK_COLOR
		button.AutoButtonColor = false
		button.Parent = gridFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = button

		local cardData = { button = button, value = value, matched = false }
		cardButtons[i] = cardData

		button.MouseButton1Click:Connect(function()
			onCardClicked(i)
		end)
	end

	-- Tell the server a session is starting (used to validate the eventual payout)

end

-- === Listen for the job station interaction ===
openJobMinigameEvent.OnClientEvent:Connect(function(jobType)
	if jobType ~= "Card Matching" then
		return -- not our game — Quick Math / Pattern Memory will have their own scripts
	end

	if gameFrame.Visible then return end
	gameFrame.Visible = true
	startNewGame()
end)
