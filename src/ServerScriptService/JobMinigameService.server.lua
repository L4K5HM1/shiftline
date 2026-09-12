--[[
	JobMinigameService.server.lua
	Script — place in ServerScriptService

	Validates job minigame sessions and pays out cash on completion.
	Currently configured for "Card Matching" — more job types (Quick Math,
	Pattern Memory) will register their own entry in PAYOUT_CONFIG later.

	FLOW:
		1. Client opens a minigame (after interacting with a job station)
		2. Client calls StartJob(jobType) -> server records a session with a start time
		3. Client plays the game itself (all game logic is client-side for
		   Card Matching, since there's nothing sensitive to hide — the payout
		   is what actually needs protecting, which is why it's validated here)
		4. Client calls CompleteJob(jobType, movesUsed) when finished
		5. Server checks:
			- a session actually exists and matches jobType
			- enough time has passed (blocks instant/scripted completions)
			- not too much time has passed (session expired)
			- movesUsed is a plausible number for that game (blocks fake low scores)
		6. If valid, pays out cash via PlayerDataService and clears the session

	RemoteFunctions (created in ReplicatedStorage.JobRemotes, alongside the
	OpenJobMinigame RemoteEvent from JobStationInteraction.server.lua):
		StartJob(jobType)               -> success (bool), message (string)
		CompleteJob(jobType, movesUsed) -> success (bool), message (string), payout (number)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))

-- === Per-job payout tuning ===
-- basePayout = what you earn for a "perfect" run
-- floorPayout = minimum you still earn even if you barely scrape by
-- minMoves = the best possible score (used as the zero-penalty baseline)
-- maxMoves = anything above this is treated as implausible and rejected
-- minSeconds = fastest a real human could plausibly finish (anti-instant-complete)
-- maxSeconds = session expires after this long
local PAYOUT_CONFIG = {
	["Card Matching"] = {
		basePayout = 25,
		floorPayout = 10,
		minMoves = 8,   -- 8 pairs = 8 perfect moves
		maxMoves = 60,
		minSeconds = 3,
		maxSeconds = 300,
	},
}

-- === RemoteFunctions setup ===
local jobRemotesFolder = ReplicatedStorage:FindFirstChild("JobRemotes")
if not jobRemotesFolder then
	jobRemotesFolder = Instance.new("Folder")
	jobRemotesFolder.Name = "JobRemotes"
	jobRemotesFolder.Parent = ReplicatedStorage
end

local startJobFunction = jobRemotesFolder:FindFirstChild("StartJob")
if not startJobFunction then
	startJobFunction = Instance.new("RemoteFunction")
	startJobFunction.Name = "StartJob"
	startJobFunction.Parent = jobRemotesFolder
end

local completeJobFunction = jobRemotesFolder:FindFirstChild("CompleteJob")
if not completeJobFunction then
	completeJobFunction = Instance.new("RemoteFunction")
	completeJobFunction.Name = "CompleteJob"
	completeJobFunction.Parent = jobRemotesFolder
end

-- === Active sessions: [player] = { jobType = string, startTime = number } ===
local activeSessions = {}

startJobFunction.OnServerInvoke = function(player, jobType)
	local config = PAYOUT_CONFIG[jobType]
	if not config then
		return false, "Unknown job type."
	end

	activeSessions[player] = {
		jobType = jobType,
		startTime = os.clock(),
	}

	return true, "Job started."
end

completeJobFunction.OnServerInvoke = function(player, jobType, movesUsed)
	local config = PAYOUT_CONFIG[jobType]
	if not config then
		return false, "Unknown job type.", 0
	end

	local session = activeSessions[player]
	if not session or session.jobType ~= jobType then
		return false, "No active session for this job.", 0
	end

	local elapsed = os.clock() - session.startTime

	if elapsed < config.minSeconds then
		activeSessions[player] = nil
		return false, "That was too fast to be real — try again.", 0
	end

	if elapsed > config.maxSeconds then
		activeSessions[player] = nil
		return false, "Session expired — start the job again.", 0
	end

	if type(movesUsed) ~= "number" or movesUsed < config.minMoves or movesUsed > config.maxMoves then
		activeSessions[player] = nil
		return false, "Invalid result — try again.", 0
	end

	-- Payout scales down from basePayout as moves increase past the perfect score
	local penalty = movesUsed - config.minMoves
	local payout = math.clamp(config.basePayout - penalty, config.floorPayout, config.basePayout)

	PlayerDataService.AddCash(player, payout)
	activeSessions[player] = nil

	return true, ("Earned $%d!"):format(payout), payout
end

-- === Clean up if a player disconnects mid-job ===
Players.PlayerRemoving:Connect(function(player)
	activeSessions[player] = nil
end)

print("[JobMinigameService] Ready — handling job session validation and payouts.")
