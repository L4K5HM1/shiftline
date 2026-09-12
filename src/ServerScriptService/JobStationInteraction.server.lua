--[[
	JobStationInteraction.server.lua
	Script — place in ServerScriptService

	Adds a ProximityPrompt ("Press E to start job") to every part tagged
	"JobTrigger" in the world. When a player interacts, it fires a RemoteEvent
	telling that player's client which job type to open (Card Matching,
	Quick Math, or Pattern Memory).

	This is currently a HOOK/PLACEHOLDER — the actual minigame UIs don't
	exist yet, so for now it just fires the event with the job type. Once
	each minigame is built, its client script will listen to this same
	OpenJobMinigame RemoteEvent and open the right game based on the jobType
	argument.

	HOW TO TAG A PART (do this whenever you resume building/polishing the map):
		local CollectionService = game:GetService("CollectionService")
		CollectionService:AddTag(jobStationPart, "JobTrigger")
		jobStationPart:SetAttribute("JobType", "Card Matching") -- or "Quick Math" / "Pattern Memory"
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VALID_JOB_TYPES = {
	["Card Matching"] = true,
	["Quick Math"] = true,
	["Pattern Memory"] = true,
}

-- === RemoteEvent: server -> client, tells the client which job minigame to open ===
local jobRemotesFolder = ReplicatedStorage:FindFirstChild("JobRemotes")
if not jobRemotesFolder then
	jobRemotesFolder = Instance.new("Folder")
	jobRemotesFolder.Name = "JobRemotes"
	jobRemotesFolder.Parent = ReplicatedStorage
end

local openJobMinigameEvent = jobRemotesFolder:FindFirstChild("OpenJobMinigame")
if not openJobMinigameEvent then
	openJobMinigameEvent = Instance.new("RemoteEvent")
	openJobMinigameEvent.Name = "OpenJobMinigame"
	openJobMinigameEvent.Parent = jobRemotesFolder
end

local function setupJobStationPart(part)
	local jobType = part:GetAttribute("JobType")
	if not jobType or not VALID_JOB_TYPES[jobType] then
		warn("[JobStationInteraction] Part '" .. part.Name .. "' is tagged JobTrigger but has no valid JobType attribute set.")
		return
	end

	if part:FindFirstChild("JobPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JobPrompt"
	prompt.ActionText = "Start Job"
	prompt.ObjectText = jobType
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		openJobMinigameEvent:FireClient(player, jobType)
	end)
end

for _, part in ipairs(CollectionService:GetTagged("JobTrigger")) do
	setupJobStationPart(part)
end

CollectionService:GetInstanceAddedSignal("JobTrigger"):Connect(setupJobStationPart)

print("[JobStationInteraction] Ready — watching for parts tagged 'JobTrigger'.")
