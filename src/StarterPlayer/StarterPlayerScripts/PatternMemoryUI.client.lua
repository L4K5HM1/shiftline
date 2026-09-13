--[[
	PatternMemoryUI.client.lua
	LocalScript — place in StarterPlayerScripts

	Listens for the OpenJobMinigame RemoteEvent (fired when a player interacts
	with a "Pattern Memory" job station). Classic Simon Says: watch a growing
	sequence of colored pads light up, then repeat it back by clicking the
	pads in the same order. One mistake ends the game. Submits how many
	rounds were survived to the server for a validated, performance-based payout.

	Talks to JobRemotes (same remotes the other two job minigames use):
		RemoteEvent    OpenJobMinigame -> (jobType)
		RemoteFunction StartJob        -> (jobType) -> success, message
		RemoteFunction CompleteJob     -> (jobType, score) -> success, message, payout
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local TARGET_ROUNDS = 10 -- surviving all 10 rounds = perfect score
local FLASH_ON_TIME = 0.4
local FLASH_GAP_TIME = 0.2
local ROUND_TRANSITION_DELAY = 0.8

-- Classic 4-pad Simon layout: each has a dim (resting) and lit (flashed) color
local PADS = {
	{ dim = Color3.fromRGB(160, 40, 40), lit = Color3.fromRGB(255, 70, 70) },   -- red
	{ dim = Color3.fromRGB(40, 130, 60), lit = Color3.fromRGB(70, 220, 100) },  -- green
	{ dim = Color3.fromRGB(40, 90, 170), lit = Color3.fromRGB(80, 150, 255) },  -- blue
	{ dim = Color3.fromRGB(180, 150, 30), lit = Color3.fromRGB(255, 220, 60) }, -- yellow
}

-- === Build the UI shell (hidden until triggered) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PatternMemoryUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local gameFrame = Instance.new("Frame")
gameFrame.Name = "GameFrame"
gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
gameFrame.Size = UDim2.new(0.28, 0, 0.55, 0)
gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
gameFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
gameFrame.Visible = false
gameFrame.Parent = screenGui

local gameFrameSizeConstraint = Instance.new("UISizeConstraint")
gameFrameSizeConstraint.MinSize = Vector2.new(320, 420)
gameFrameSizeConstraint.MaxSize = Vector2.new(420, 520)
gameFrameSizeConstraint.Parent = gameFrame

local gameFrameCorner = Instance.new("UICorner")
gameFrameCorner.CornerRadius = UDim.new(0, 14)
gameFrameCorner.Parent = gameFrame

-- Header
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 0, 40)
titleLabel.Position = UDim2.new(0, 16, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "PATTERN MEMORY"
titleLabel.TextColor3 = Color3.fromRGB(180, 120, 230)
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

closeButton.MouseButton1Click:Connect(function()
	cancelSession()
	gameFrame.Visible = false
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -32, 0, 24)
statusLabel.Position = UDim2.new(0, 16, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Round 1 / " .. TARGET_ROUNDS
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 15
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = gameFrame

-- Pad grid (2x2)
local padGridFrame = Instance.new("Frame")
padGridFrame.Name = "PadGrid"
padGridFrame.Size = UDim2.new(1, -32, 1, -160)
padGridFrame.Position = UDim2.new(0, 16, 0, 80)
padGridFrame.BackgroundTransparency = 1
padGridFrame.Parent = gameFrame

local padGridLayout = Instance.new("UIGridLayout")
padGridLayout.CellSize = UDim2.new(0.47, 0, 0.47, 0)
padGridLayout.CellPadding = UDim2.new(0.06, 0, 0.06, 0)
padGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
padGridLayout.Parent = padGridFrame

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

-- === Build the 4 pad buttons ===
local padButtons = {}
for i, padInfo in ipairs(PADS) do
	local pad = Instance.new("TextButton")
	pad.Name = "Pad" .. i
	pad.LayoutOrder = i
	pad.Text = ""
	pad.BackgroundColor3 = padInfo.dim
	pad.AutoButtonColor = false
	pad.Parent = padGridFrame

	local padCorner = Instance.new("UICorner")
	padCorner.CornerRadius = UDim.new(0, 14)
	padCorner.Parent = pad

	padButtons[i] = pad
end

-- === Game state ===
local sequence = {}          -- array of pad indices (1-4), grows each round
local currentRound = 0
local playerInputIndex = 0
local acceptingInput = false
local isPlayingBack = false

--[[ Briefly lights up one pad ]]
local function flashPad(padIndex)
	local runVersion = sessionVersion
	local pad = padButtons[padIndex]
	pad.BackgroundColor3 = PADS[padIndex].lit
	task.wait(FLASH_ON_TIME)
	if runVersion ~= sessionVersion then return end
	pad.BackgroundColor3 = PADS[padIndex].dim
	task.wait(FLASH_GAP_TIME)
	if runVersion ~= sessionVersion then return end
end

--[[ Plays back the entire sequence so far, then opens up player input ]]
local function playbackSequence()
	local runVersion = sessionVersion
	acceptingInput = false
	isPlayingBack = true
	statusLabel.Text = "Watch closely... (Round " .. currentRound .. " / " .. TARGET_ROUNDS .. ")"

	task.wait(0.5) -- brief pause before playback so the player can get ready
	if runVersion ~= sessionVersion then return end

	for _, padIndex in ipairs(sequence) do
		flashPad(padIndex)
		if runVersion ~= sessionVersion then return end
	end

	isPlayingBack = false
	playerInputIndex = 0
	acceptingInput = true
	statusLabel.Text = "Your turn! (Round " .. currentRound .. " / " .. TARGET_ROUNDS .. ")"
end

--[[ Ends the game (success or failure) and submits the score ]]
local function finishGame(scoreAchieved)
	local runVersion = sessionVersion
	acceptingInput = false

	task.spawn(function()
		resultLabel.Text = "Submitting..."
		resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

		local success, message = completeSession("Pattern Memory", scoreAchieved)
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

--[[ Starts the next round: adds one more random pad to the sequence ]]
local function startNextRound()
	currentRound += 1
	table.insert(sequence, math.random(1, #PADS))
	task.spawn(playbackSequence)
end

local function onPadClicked(padIndex)
	local runVersion = sessionVersion
	if not sessionToken or not acceptingInput or isPlayingBack then return end

	playerInputIndex += 1
	local expectedPad = sequence[playerInputIndex]

	if padIndex ~= expectedPad then
		-- Wrong pad — game over. Score = rounds fully completed before this mistake.
		acceptingInput = false
		local pad = padButtons[padIndex]
		pad.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
		task.wait(0.4)
		if runVersion ~= sessionVersion then return end
		pad.BackgroundColor3 = PADS[padIndex].dim

		statusLabel.Text = "Wrong! Survived " .. (currentRound - 1) .. " round(s)."
		finishGame(currentRound - 1)
		return
	end

	-- Correct pad — brief visual confirmation
	local pad = padButtons[padIndex]
	pad.BackgroundColor3 = PADS[padIndex].lit
	task.wait(0.15)
	if runVersion ~= sessionVersion then return end
	pad.BackgroundColor3 = PADS[padIndex].dim

	if playerInputIndex >= #sequence then
		-- Finished repeating the whole sequence correctly
		acceptingInput = false

		if currentRound >= TARGET_ROUNDS then
			statusLabel.Text = "Perfect! All " .. TARGET_ROUNDS .. " rounds cleared!"
			finishGame(TARGET_ROUNDS)
		else
			statusLabel.Text = "Correct! Next round incoming..."
			task.wait(ROUND_TRANSITION_DELAY)
			if runVersion ~= sessionVersion then return end
			startNextRound()
		end
	end
end

for i, pad in ipairs(padButtons) do
	pad.MouseButton1Click:Connect(function()
		onPadClicked(i)
	end)
end

--[[ Resets everything and starts a brand new game ]]
local function startNewGame()
 if starting or sessionToken then return end
 starting = true
 sessionVersion += 1
 local version = sessionVersion
 resultLabel.Text = "Starting..."
 local ok, accepted, message, token = pcall(function()
  return startJobFunction:InvokeServer("Pattern Memory")
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

	sequence = {}
	currentRound = 0
	playerInputIndex = 0
	acceptingInput = false
	isPlayingBack = false
	resultLabel.Text = ""

	for i, pad in ipairs(padButtons) do
		pad.BackgroundColor3 = PADS[i].dim
	end

	-- Tell the server a session is starting (used to validate the eventual payout)


	startNextRound()
end

-- === Listen for the job station interaction ===
openJobMinigameEvent.OnClientEvent:Connect(function(jobType)
	if jobType ~= "Pattern Memory" then
		return -- not our game — Card Matching / Quick Math have their own scripts
	end

	if gameFrame.Visible then return end
	gameFrame.Visible = true
	startNewGame()
end)
