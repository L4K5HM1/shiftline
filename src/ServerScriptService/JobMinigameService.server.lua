-- Validates token-bound sessions for Card Matching, Quick Math and Pattern Memory.
-- Scores remain client-reported: timing/range checks are not proof of completion.
-- StartJob returns success, message, token; CompleteJob takes jobType, score, token.
-- CancelJob releases an abandoned token. See docs/RELIABILITY.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local Core = require(ServerScriptService:WaitForChild("ProfileStore"))
local Guard = require(ServerScriptService:WaitForChild("InteractionGuard"))

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
local cancelJobEvent = Instance.new("RemoteEvent")
cancelJobEvent.Name = "CancelJob"
cancelJobEvent.Parent = jobRemotesFolder
cancelJobEvent.OnServerEvent:Connect(function(player, token)
	local session = activeSessions[player]
	if session and session.token == token then activeSessions[player] = nil end
end)

-- Cooldown duration — actual timestamps are now stored persistently in
-- PlayerDataService (via GetCooldownRemaining / SetCooldown), so this
-- survives players leaving, rejoining, or switching servers.
local COOLDOWN_SECONDS = 60

startJobFunction.OnServerInvoke = function(player, jobType)
	if not Guard.allowRequest(player, "start-job", 0.5) or not Core.validName(jobType) then
		return false, "Invalid request or requests too frequent."
	end
	local config = PAYOUT_CONFIG[jobType]
	if not config then
		return false, "Unknown job type."
	end
	if not PlayerDataService.GetData(player) then return false, "Player data is not ready." end
	if not Guard.near(player, "JobTrigger", "JobType", jobType) then return false, "Visit the job station to start." end
	local previous = activeSessions[player]
	if previous and os.clock() - previous.startTime <= PAYOUT_CONFIG[previous.jobType].maxSeconds then
		return false, "Close your current job before starting another."
	end

	-- Check the persistent cooldown for this specific job type — this works
	-- correctly even if the player just rejoined or switched servers, since
	-- it's based on real-world time saved in their actual player data.
	local remaining = PlayerDataService.GetCooldownRemaining(player, jobType, COOLDOWN_SECONDS)
	if remaining > 0 then
		return false, ("Wait %d more second(s) before doing this job again."):format(math.ceil(remaining))
	end

	activeSessions[player] = {
		jobType = jobType,
		startTime = os.clock(),
		token = HttpService:GenerateGUID(false),
	}

	return true, "Job started.", activeSessions[player].token
end

completeJobFunction.OnServerInvoke = function(player, jobType, score, token)
	if not Core.validName(jobType) then return false, "Invalid job.", 0 end
	local config = PAYOUT_CONFIG[jobType]
	if not config then
		return false, "Unknown job type.", 0
	end

	local session = activeSessions[player]
	if not session or session.jobType ~= jobType or session.token ~= token then
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

	if not Core.isInteger(score, config.minValue, config.maxValue) then
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

	activeSessions[player] = nil
	if not PlayerDataService.AddCash(player, payout) then return false, "Player data is unavailable.", 0 end
	PlayerDataService.SetCooldown(player, jobType)

	return true, ("Earned $%d!"):format(payout), payout
end

-- === Clean up active session tracking if a player disconnects mid-job ===
-- (No cooldown cleanup needed here anymore — cooldowns live in persistent
-- player data now, saved/cleaned up by PlayerDataService itself.)
Players.PlayerRemoving:Connect(function(player)
	activeSessions[player] = nil
end)

print("[JobMinigameService] Ready — handling job session validation and payouts.")
