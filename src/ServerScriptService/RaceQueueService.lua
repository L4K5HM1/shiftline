--[[
	RaceQueueService.lua
	ModuleScript — place in ServerScriptService

	Manages the race queue and the repeating 5-minute global timer.

	FLOW:
		1. Player clicks "Join Race" UI button -> JoinQueue(player)
		2. Every second, timer ticks down and broadcasts to clients
		3. When timer hits 0:
			- Takes the first MAX_RACE_SIZE players who queued (first-come, first-served)
			- If fewer than TARGET_RACE_SIZE real players, fills remaining seats with bots
			- Fires RaceService.RaceStarted with the group (the Race Engine, built later,
			  will listen to this event and actually teleport players + start the typing race)
			- Clears those players from the queue and resets the timer
		4. If nobody queued when timer hits 0, it just resets silently (no empty race)

	PUBLIC API (used by RaceQueueBootstrap.server.lua):
		RaceQueueService.JoinQueue(player)      -> success (bool), message (string)
		RaceQueueService.LeaveQueue(player)      -> success (bool), message (string)
		RaceQueueService.GetTimeRemaining()      -> number (seconds left)
		RaceQueueService.GetQueueCount()         -> number
		RaceQueueService.IsPlayerQueued(player)  -> bool
		RaceQueueService.RaceStarted             -> BindableEvent, fires with a "group" table:
			{
				raceId = string,
				realPlayers = { player, player, ... },
				botCount = number,
			}
		RaceQueueService.OnPlayerRemoving(player) -> call from bootstrap so leaving players
		                                             are cleanly removed from the queue
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local RaceQueueService = {}

-- === Tunable constants ===
local TIMER_DURATION = 300      -- 5 minutes, in seconds
local MAX_RACE_SIZE = 6         -- hard cap on real players per race group
local TARGET_RACE_SIZE = 4      -- if fewer real players than this, bots fill the rest
local MIN_BOTS_IF_ALONE = 1     -- guarantees at least 1 bot if only 1 real player queues

-- Ordered queue (array preserves first-come order) + a lookup set for O(1) checks
local queue = {}          -- array of Player
local queuedSet = {}      -- [Player] = true

local timeRemaining = TIMER_DURATION

RaceQueueService.RaceStarted = Instance.new("BindableEvent")
RaceQueueService.QueueTick = Instance.new("BindableEvent") -- fires every second: (timeRemaining, queueCount)

-- === Public API ===

function RaceQueueService.IsPlayerQueued(player)
	return queuedSet[player] == true
end

function RaceQueueService.GetQueueCount()
	return #queue
end

function RaceQueueService.GetTimeRemaining()
	return timeRemaining
end

function RaceQueueService.JoinQueue(player)
	if queuedSet[player] then
		return false, "You're already queued for the next race."
	end
	table.insert(queue, player)
	queuedSet[player] = true
	return true, "Queued! Race starts when the timer hits 0."
end

function RaceQueueService.LeaveQueue(player)
	if not queuedSet[player] then
		return false, "You're not in the queue."
	end
	for i, p in ipairs(queue) do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	queuedSet[player] = nil
	return true, "Left the queue."
end

--[[ Call from bootstrap's Players.PlayerRemoving so a disconnecting player
     doesn't leave a ghost entry in the queue ]]
function RaceQueueService.OnPlayerRemoving(player)
	if queuedSet[player] then
		RaceQueueService.LeaveQueue(player)
	end
end

--[[ Forms and fires off a race group from whoever is currently queued.
     Only the first MAX_RACE_SIZE players (first-come, first-served) get in;
     anyone left in the queue waits for the next timer. ]]
local function startRaceFromQueue()
	if #queue == 0 then
		return -- nobody queued, nothing to do
	end

	local groupSize = math.min(#queue, MAX_RACE_SIZE)
	local realPlayers = {}
	for i = 1, groupSize do
		table.insert(realPlayers, queue[i])
	end

	-- Remove the selected players from the queue; anyone beyond MAX_RACE_SIZE stays queued
	for i = 1, groupSize do
		local player = table.remove(queue, 1)
		queuedSet[player] = nil
	end

	-- Figure out how many bots are needed to fill up to TARGET_RACE_SIZE
	local botCount = 0
	if #realPlayers < TARGET_RACE_SIZE then
		botCount = TARGET_RACE_SIZE - #realPlayers
	end
	if #realPlayers == 1 then
		botCount = math.max(botCount, MIN_BOTS_IF_ALONE)
	end

	local group = {
		raceId = HttpService:GenerateGUID(false),
		realPlayers = realPlayers,
		botCount = botCount,
	}

	-- Race Engine (built later) listens to this event to actually teleport
	-- players into the race instance and start the typing race.
	RaceQueueService.RaceStarted:Fire(group)
end

--[[ Main timer loop — ticks every second, broadcasts state, fires races at 0.
     Call once from bootstrap. ]]
function RaceQueueService.StartTimerLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			timeRemaining -= 1

			RaceQueueService.QueueTick:Fire(timeRemaining, #queue)

			if timeRemaining <= 0 then
				startRaceFromQueue()
				timeRemaining = TIMER_DURATION
				RaceQueueService.QueueTick:Fire(timeRemaining, #queue)
			end
		end
	end)
end

return RaceQueueService
