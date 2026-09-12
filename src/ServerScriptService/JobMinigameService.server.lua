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
-- type = "lowerIsBetter" (e.g. Card Matching moves — fewer is better)
--        or "higherIsBetter" (e.g. Quick Math correct answers — more is better)
-- basePayout = what you earn for a perfect run
-- floorPayout = minimum you still earn even if you barely scrape by
-- minValue/maxValue = the plausible range for the submitted score (used both
--   to calculate payout and to reject implausible/faked results)
-- minSeconds = fastest a real human could plausibly finish (anti-instant-complete)
-- maxSeconds = session expires after this long
local PAYOUT_CONFIG = {
	["Card Matching"] = {
		type = "lowerIsBetter",
		basePayout = 25,
		floorPayout = 10,
		minValue = 8,   -- 8 pairs = 8 perfect moves
		maxValue = 60,
		minSeconds = 3,
		maxSeconds = 300,
	},
	["Quick Math"] = {
		type = "higherIsBetter",
		basePayout = 25,
		floorPayout = 8,
		minValue = 0,   -- 0 correct out of 10
		maxValue = 10,  -- all 10 correct
		minSeconds = 5, -- can't legitimately solve 10 problems faster than this
		maxSeconds = 180,
	},
	["Pattern Memory"] = {
		type = "higherIsBetter",
		basePayout = 25,
		floorPayout = 8,
		minValue = 0,   -- failed on round 1 (or never got past it)
		maxValue = 10,  -- survived all 10 rounds
		minSeconds = 5, -- can't legitimately clear multiple rounds faster than this
		maxSeconds = 240,
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

completeJobFunction.OnServerInvoke = function(player, jobType, score)
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

	if type(score) ~= "number" or score < config.minValue or score > config.maxValue then
		activeSessions[player] = nil
		return false, "Invalid result — try again.", 0
	end

	local payout
	if config.type == "lowerIsBetter" then
		-- e.g. Card Matching: fewer moves = closer to minValue = better
		local penalty = score - config.minValue
		payout = math.clamp(config.basePayout - penalty, config.floorPayout, config.basePayout)
	else
		-- "higherIsBetter", e.g. Quick Math: more correct = closer to maxValue = better
		local fraction = (score - config.minValue) / (config.maxValue - config.minValue)
		payout = math.clamp(
			math.floor(config.floorPayout + (config.basePayout - config.floorPayout) * fraction),
			config.floorPayout,
			config.basePayout
		)
	end

	PlayerDataService.AddCash(player, payout)
	activeSessions[player] = nil

	return true, ("Earned $%d!"):format(payout), payout
end

-- === Clean up if a player disconnects mid-job ===
Players.PlayerRemoving:Connect(function(player)
	activeSessions[player] = nil
end)

print("[JobMinigameService] Ready — handling job session validation and payouts.")
