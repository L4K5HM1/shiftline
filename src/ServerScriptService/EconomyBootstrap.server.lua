--[[
	EconomyBootstrap.server.lua
	Script (NOT ModuleScript) — place in ServerScriptService, alongside PlayerDataService

	Wires PlayerDataService into the actual game lifecycle, and sets up the
	RemoteEvents/RemoteFunctions the client UI (garage, dealership, cash display)
	will use to talk to the server.

	Creates a folder in ReplicatedStorage called "EconomyRemotes" containing:
		RemoteEvent  "CashUpdated"       (server -> client, fires with new cash amount)
		RemoteFunction "PurchaseCar"     (client -> server, args: brand, model -> returns success, message)
		RemoteFunction "SelectCar"       (client -> server, args: brand, model -> returns success, message)
		RemoteFunction "GetPlayerData"   (client -> server, no args -> returns full data table)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local CarConfig = require(ReplicatedStorage:WaitForChild("CarConfig"))
local Core = require(ServerScriptService:WaitForChild("ProfileStore"))
local Guard = require(ServerScriptService:WaitForChild("InteractionGuard"))

-- === Set up RemoteEvents/RemoteFunctions ===
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "EconomyRemotes"
remotesFolder.Parent = ReplicatedStorage

local cashUpdatedEvent = Instance.new("RemoteEvent")
cashUpdatedEvent.Name = "CashUpdated"
cashUpdatedEvent.Parent = remotesFolder

local purchaseCarFunction = Instance.new("RemoteFunction")
purchaseCarFunction.Name = "PurchaseCar"
purchaseCarFunction.Parent = remotesFolder

local selectCarFunction = Instance.new("RemoteFunction")
selectCarFunction.Name = "SelectCar"
selectCarFunction.Parent = remotesFolder

local getPlayerDataFunction = Instance.new("RemoteFunction")
getPlayerDataFunction.Name = "GetPlayerData"
getPlayerDataFunction.Parent = remotesFolder

-- === Player lifecycle ===
Players.PlayerAdded:Connect(function(player)
	PlayerDataService.OnPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.OnPlayerRemoving(player)
end)

-- Handle players already in-game if this script gets reloaded (e.g. in Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
	PlayerDataService.OnPlayerAdded(player)
end

-- === Cash change -> notify client ===
PlayerDataService.CashChanged.Event:Connect(function(player, newCash)
	if player and player.Parent then
		cashUpdatedEvent:FireClient(player, newCash)
	end
end)

-- === RemoteFunction: PurchaseCar ===
purchaseCarFunction.OnServerInvoke = function(player, brand, model)
	if not Guard.allowRequest(player, "purchase", 0.25) or not Core.validName(brand) or not Core.validName(model) then
		return false, "Invalid request or requests too frequent."
	end
	local carData = CarConfig.GetCar(brand, model)
	if not carData then
		return false, "That car doesn't exist."
	end

	return PlayerDataService.PurchaseCar(player, brand, model, carData.price)
end

-- === RemoteFunction: SelectCar ===
selectCarFunction.OnServerInvoke = function(player, brand, model)
	if not Guard.allowRequest(player, "select", 0.25) or not Core.validName(brand) or not Core.validName(model) then
		return false, "Invalid request or requests too frequent."
	end
	if not CarConfig.GetCar(brand, model) or not Guard.near(player, "DealershipTrigger", "Brand", brand) then
		return false, "Visit this brand's dealership to pick up your car."
	end
	local success = PlayerDataService.SetCurrentCar(player, brand, model)
	if success then
		return true, ("Now driving the %s %s."):format(brand, model)
	else
		return false, "You don't own that car yet."
	end
end

-- === RemoteFunction: GetPlayerData ===
getPlayerDataFunction.OnServerInvoke = function(player)
	if not Guard.allowRequest(player, "profile", 0.1) then return nil end
	local deadline = os.clock() + 10
	while player.Parent and not PlayerDataService.GetData(player) and os.clock() < deadline do task.wait(0.1) end
	return PlayerDataService.GetData(player)
end

-- === Autosave + graceful shutdown ===
PlayerDataService.StartAutosaveLoop()

game:BindToClose(function()
	PlayerDataService.SaveAllOnShutdown()
end)

print("[EconomyBootstrap] Economy backbone initialized.")
