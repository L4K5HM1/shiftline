--[[
	RaceQueueBootstrap.server.lua
	Script (NOT ModuleScript) — place in ServerScriptService, alongside RaceQueueService

	Wires RaceQueueService into RemoteEvents/RemoteFunctions the client UI uses,
	and connects Players.PlayerRemoving so leaving players are cleanly dequeued.

	Creates a folder in ReplicatedStorage called "RaceRemotes" containing:
		RemoteFunction "JoinQueue"    (client -> server, no args -> returns success, message)
		RemoteFunction "LeaveQueue"   (client -> server, no args -> returns success, message)
		RemoteEvent    "QueueTick"    (server -> all clients, fires every second with
		                               timeRemaining, queueCount — drive your countdown UI off this)
		RemoteEvent    "RaceStarted"  (server -> specific clients who got into a race group,
		                               fires with raceId, botCount — Race Engine will expand
		                               on this later to actually teleport players)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RaceQueueService = require(ServerScriptService:WaitForChild("RaceQueueService"))

-- === Set up RemoteEvents/RemoteFunctions ===
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "RaceRemotes"
remotesFolder.Parent = ReplicatedStorage

local joinQueueFunction = Instance.new("RemoteFunction")
joinQueueFunction.Name = "JoinQueue"
joinQueueFunction.Parent = remotesFolder

local leaveQueueFunction = Instance.new("RemoteFunction")
leaveQueueFunction.Name = "LeaveQueue"
leaveQueueFunction.Parent = remotesFolder

local queueTickEvent = Instance.new("RemoteEvent")
queueTickEvent.Name = "QueueTick"
queueTickEvent.Parent = remotesFolder

local raceStartedEvent = Instance.new("RemoteEvent")
raceStartedEvent.Name = "RaceStarted"
raceStartedEvent.Parent = remotesFolder

-- === RemoteFunction hookups ===
joinQueueFunction.OnServerInvoke = function(player)
	return RaceQueueService.JoinQueue(player)
end

leaveQueueFunction.OnServerInvoke = function(player)
	return RaceQueueService.LeaveQueue(player)
end

-- === Broadcast the countdown to every client every second ===
RaceQueueService.QueueTick.Event:Connect(function(timeRemaining, queueCount)
	queueTickEvent:FireAllClients(timeRemaining, queueCount)
end)

-- === Notify only the players who made it into a race group ===
RaceQueueService.RaceStarted.Event:Connect(function(group)
	for _, player in ipairs(group.realPlayers) do
		if player and player.Parent then
			raceStartedEvent:FireClient(player, group.raceId, group.botCount)
		end
	end

	-- Placeholder until the Race Engine exists — remove this print once that's built
	print(("[RaceQueue] Race %s starting with %d real player(s) + %d bot(s)")
		:format(group.raceId, #group.realPlayers, group.botCount))
end)

-- === Player lifecycle: clean up queue on disconnect ===
Players.PlayerRemoving:Connect(function(player)
	RaceQueueService.OnPlayerRemoving(player)
end)

-- === Start the 5-minute timer loop ===
RaceQueueService.StartTimerLoop()

print("[RaceQueueBootstrap] Race queue system initialized. Races run every 5 minutes.")
