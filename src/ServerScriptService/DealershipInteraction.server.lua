--[[
	DealershipInteraction.server.lua
	Script — place in ServerScriptService

	Adds a ProximityPrompt ("Press E to pick up a car") to every part tagged
	"DealershipTrigger" in the world. When a player interacts, it looks up
	which brand that dealership sells (via the part's "Brand" attribute) and
	fires a RemoteEvent telling that player's client to open the car pickup
	list (built in CarPickupUI.client.lua).

	HOW TO TAG A PART (do this whenever you resume building/polishing the map):
		local CollectionService = game:GetService("CollectionService")
		CollectionService:AddTag(dealershipPart, "DealershipTrigger")
		dealershipPart:SetAttribute("Brand", "Honda") -- must match a CarConfig brand name exactly

	This script automatically picks up any part tagged this way, whether it
	exists when the server starts or gets added later (e.g. if the map
	regenerates).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local CarConfig = require(ReplicatedStorage:WaitForChild("CarConfig"))

-- === RemoteEvent: server -> client, tells the client to open the pickup list ===
local dealershipRemotesFolder = ReplicatedStorage:FindFirstChild("DealershipRemotes")
if not dealershipRemotesFolder then
	dealershipRemotesFolder = Instance.new("Folder")
	dealershipRemotesFolder.Name = "DealershipRemotes"
	dealershipRemotesFolder.Parent = ReplicatedStorage
end

local openCarPickupEvent = dealershipRemotesFolder:FindFirstChild("OpenCarPickup")
if not openCarPickupEvent then
	openCarPickupEvent = Instance.new("RemoteEvent")
	openCarPickupEvent.Name = "OpenCarPickup"
	openCarPickupEvent.Parent = dealershipRemotesFolder
end

--[[ Builds the list of {brand, modelName} the player owns for this specific brand ]]
local function getOwnedModelsForBrand(player, brand)
	local data = PlayerDataService.GetData(player)
	if not data then return {} end

	local owned = {}
	local brandInfo = CarConfig.Brands[brand]
	if not brandInfo then return owned end

	for _, model in ipairs(brandInfo.models) do
		if data.OwnedCars[brand .. "_" .. model.name] == true then
			table.insert(owned, model.name)
		end
	end
	return owned
end

--[[ Sets up a ProximityPrompt on one dealership part ]]
local function setupDealershipPart(part)
	local brand = part:GetAttribute("Brand")
	if not brand or not CarConfig.Brands[brand] then
		warn("[DealershipInteraction] Part '" .. part.Name .. "' is tagged DealershipTrigger but has no valid Brand attribute set.")
		return
	end

	-- Avoid double-adding a prompt if this part somehow gets processed twice
	if part:FindFirstChild("PickupPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up Car"
	prompt.ObjectText = CarConfig.Brands[brand].displayName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		local ownedModels = getOwnedModelsForBrand(player, brand)
		openCarPickupEvent:FireClient(player, brand, ownedModels)
	end)
end

-- === Wire up every dealership part currently tagged, and any added later ===
for _, part in ipairs(CollectionService:GetTagged("DealershipTrigger")) do
	setupDealershipPart(part)
end

CollectionService:GetInstanceAddedSignal("DealershipTrigger"):Connect(setupDealershipPart)

print("[DealershipInteraction] Ready — watching for parts tagged 'DealershipTrigger'.")
