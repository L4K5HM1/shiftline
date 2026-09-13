--[[
	QuickMathUI.client.lua
	LocalScript — place in StarterPlayerScripts

	Listens for the OpenJobMinigame RemoteEvent (fired when a player interacts
	with a "Quick Math" job station). Shows 10 simple math problems, one at a
	time. Tracks how many were answered correctly and submits that to the
	server (JobMinigameService) for a validated, performance-based payout.

	Talks to JobRemotes (same remotes Card Matching uses):
		RemoteEvent    OpenJobMinigame -> (jobType)
		RemoteFunction StartJob        -> (jobType) -> success, message
		RemoteFunction CompleteJob     -> (jobType, score) -> success, message, payout
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
local TOTAL_PROBLEMS = 10
local FEEDBACK_DELAY = 0.5 -- seconds to show correct/wrong flash before next problem

-- === Build the UI shell (hidden until triggered) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuickMathUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local gameFrame = Instance.new("Frame")
gameFrame.Name = "GameFrame"
gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
gameFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
gameFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
gameFrame.Visible = false
gameFrame.Parent = screenGui

local gameFrameSizeConstraint = Instance.new("UISizeConstraint")
gameFrameSizeConstraint.MinSize = Vector2.new(320, 300)
gameFrameSizeConstraint.MaxSize = Vector2.new(440, 400)
gameFrameSizeConstraint.Parent = gameFrame

local gameFrameCorner = Instance.new("UICorner")
gameFrameCorner.CornerRadius = UDim.new(0, 14)
gameFrameCorner.Parent = gameFrame

-- Header
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 0, 40)
titleLabel.Position = UDim2.new(0, 16, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "QUICK MATH"
titleLabel.TextColor3 = Color3.fromRGB(90, 220, 160)
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

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -32, 0, 24)
progressLabel.Position = UDim2.new(0, 16, 0, 48)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Problem 1 / " .. TOTAL_PROBLEMS
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 15
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = gameFrame

-- Problem display
local problemFrame = Instance.new("Frame")
problemFrame.Name = "ProblemFrame"
problemFrame.Size = UDim2.new(1, -32, 0, 90)
problemFrame.Position = UDim2.new(0, 16, 0, 84)
problemFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
problemFrame.Parent = gameFrame

local problemFrameCorner = Instance.new("UICorner")
problemFrameCorner.CornerRadius = UDim.new(0, 10)
problemFrameCorner.Parent = problemFrame

local problemLabel = Instance.new("TextLabel")
problemLabel.Size = UDim2.new(1, 0, 1, 0)
problemLabel.BackgroundTransparency = 1
problemLabel.Text = "0 + 0 = ?"
problemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
problemLabel.Font = Enum.Font.GothamBold
problemLabel.TextSize = 32
problemLabel.Parent = problemFrame

-- Answer input
local answerBox = Instance.new("TextBox")
answerBox.Name = "AnswerBox"
answerBox.Size = UDim2.new(1, -32, 0, 50)
answerBox.Position = UDim2.new(0, 16, 0, 188)
answerBox.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
answerBox.Text = ""
answerBox.PlaceholderText = "Type your answer..."
answerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
answerBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 135)
answerBox.Font = Enum.Font.GothamBold
answerBox.TextSize = 20
answerBox.ClearTextOnFocus = true
answerBox.Parent = gameFrame

local answerBoxCorner = Instance.new("UICorner")
answerBoxCorner.CornerRadius = UDim.new(0, 10)
answerBoxCorner.Parent = answerBox

local submitButton = Instance.new("TextButton")
submitButton.Size = UDim2.new(1, -32, 0, 44)
submitButton.Position = UDim2.new(0, 16, 0, 246)
submitButton.BackgroundColor3 = Color3.fromRGB(90, 220, 160)
submitButton.Text = "SUBMIT"
submitButton.TextColor3 = Color3.fromRGB(20, 40, 30)
submitButton.Font = Enum.Font.GothamBold
submitButton.TextSize = 16
submitButton.Parent = gameFrame

local submitButtonCorner = Instance.new("UICorner")
submitButtonCorner.CornerRadius = UDim.new(0, 10)
submitButtonCorner.Parent = submitButton

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

-- === Game state ===
local currentProblemIndex = 1
local correctCount = 0
local currentAnswer = 0
local isBusy = false

--[[ Generates one random simple math problem and returns its display text + answer ]]
local function generateProblem()
	local operation = ({ "+", "-", "x" })[math.random(1, 3)]
	local a, b, text, answer

	if operation == "+" then
		a = math.random(1, 50)
		b = math.random(1, 50)
		answer = a + b
		text = a .. " + " .. b
	elseif operation == "-" then
		a = math.random(10, 60)
		b = math.random(1, a) -- keep it non-negative
		answer = a - b
		text = a .. " - " .. b
	else
		a = math.random(2, 12)
		b = math.random(2, 12)
		answer = a * b
		text = a .. " x " .. b
	end

	return text .. " = ?", answer
end

local function loadNextProblem()
	local runVersion = sessionVersion
	if currentProblemIndex > TOTAL_PROBLEMS then
		-- Finished all problems — submit the result
		task.spawn(function()
			resultLabel.Text = "Submitting..."
			resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			submitButton.Active = false
			answerBox.TextEditable = false

			local success, message = completeSession("Quick Math", correctCount)
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
		return
	end

	progressLabel.Text = "Problem " .. currentProblemIndex .. " / " .. TOTAL_PROBLEMS
	local text, answer = generateProblem()
	problemLabel.Text = text
	currentAnswer = answer
	answerBox.Text = ""
	problemFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
end

local function submitAnswer()
	local runVersion = sessionVersion
	if isBusy or not sessionToken then return end

	local typedAnswer = tonumber(answerBox.Text)
	if typedAnswer == nil then
		return -- ignore empty/invalid input instead of wasting a problem on it
	end

	isBusy = true

	if typedAnswer == currentAnswer then
		correctCount += 1
		problemFrame.BackgroundColor3 = Color3.fromRGB(30, 70, 45) -- green flash
	else
		problemFrame.BackgroundColor3 = Color3.fromRGB(80, 30, 30) -- red flash
	end

	task.wait(FEEDBACK_DELAY)
	if runVersion ~= sessionVersion then return end

	currentProblemIndex += 1
	if runVersion ~= sessionVersion then return end
	isBusy = false
	loadNextProblem()
end

submitButton.MouseButton1Click:Connect(submitAnswer)

answerBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitAnswer()
	end
end)

--[[ Builds a brand new problem set and starts the server-side session ]]
local function startNewGame()
 if starting or sessionToken then return end
 starting = true
 sessionVersion += 1
 local version = sessionVersion
 resultLabel.Text = "Starting..."
 local ok, accepted, message, token = pcall(function()
  return startJobFunction:InvokeServer("Quick Math")
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

	currentProblemIndex = 1
	correctCount = 0
	isBusy = false
	resultLabel.Text = ""
	submitButton.Active = true
	answerBox.TextEditable = true

	loadNextProblem()

	-- Tell the server a session is starting (used to validate the eventual payout)

end

-- === Listen for the job station interaction ===
openJobMinigameEvent.OnClientEvent:Connect(function(jobType)
	if jobType ~= "Quick Math" then
		return -- not our game — Card Matching / Pattern Memory have their own scripts
	end

	if gameFrame.Visible then return end
	gameFrame.Visible = true
	startNewGame()
end)
