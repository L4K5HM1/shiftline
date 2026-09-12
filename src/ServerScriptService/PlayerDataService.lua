--[[
	PlayerDataService.lua
	ModuleScript — place in ServerScriptService

	Handles ALL persistent player data: cash, owned cars, current car.
	Every other system (job payouts, dealership purchases, race payouts)
	should go through this module — never write to DataStore directly elsewhere.

	USAGE FROM OTHER SERVER SCRIPTS:
		local PlayerDataService = require(game.ServerScriptService.PlayerDataService)

		PlayerDataService.AddCash(player, 50)
		PlayerDataService.GetCash(player)
		PlayerDataService.SpendCash(player, 2500)  -> returns true/false (false if not enough)
		PlayerDataService.OwnsCar(player, "Honda", "Civic Si")
		PlayerDataService.AddOwnedCar(player, "Honda", "Civic Si")
		PlayerDataService.SetCurrentCar(player, "Honda", "Civic Si")
		PlayerDataService.GetCurrentCar(player)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}

local DATASTORE_NAME = "CarGame_PlayerData_v1"
local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- In-memory cache: [player] = dataTable
local cache = {}

-- How often to autosave every active player's data (seconds)
local AUTOSAVE_INTERVAL = 120

local DEFAULT_DATA = {
	Cash = 500, -- small starting cash so new players aren't stuck at 0
	OwnedCars = { -- brand_model keys, true = owned
		["Honda_Civic 2001"] = true,
	},
	CurrentCar = {
		Brand = "Honda",
		Model = "Civic 2001",
	},
}

--[[ Deep copy helper so we never accidentally share tables between players ]]
local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

--[[ Retry wrapper — DataStore calls can fail transiently, always retry a few times ]]
local function retry(fn, attempts)
	attempts = attempts or 3
	local lastErr
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(1 * i) -- backoff
	end
	warn("[PlayerDataService] Failed after retries:", lastErr)
	return false, lastErr
end

--[[ Load a player's data on join ]]
local function loadData(player)
	local key = "Player_" .. player.UserId
	local success, result = retry(function()
		return dataStore:GetAsync(key)
	end)

	local data
	if success and result then
		data = result
		-- Backfill any new default fields for players with old save data
		for k, v in pairs(DEFAULT_DATA) do
			if data[k] == nil then
				data[k] = deepCopy(v)
			end
		end
	else
		data = deepCopy(DEFAULT_DATA)
	end

	cache[player] = data
	return data
end

--[[ Save a player's data (call on leave, on autosave, and after big purchases) ]]
local function saveData(player)
	local data = cache[player]
	if not data then return end

	local key = "Player_" .. player.UserId
	retry(function()
		dataStore:SetAsync(key, data)
	end)
end

--[[ PUBLIC API ]]

function PlayerDataService.GetData(player)
	return cache[player]
end

function PlayerDataService.GetCash(player)
	local data = cache[player]
	return data and data.Cash or 0
end

function PlayerDataService.AddCash(player, amount)
	local data = cache[player]
	if not data then return end
	data.Cash += amount
	PlayerDataService.CashChanged:Fire(player, data.Cash)
end

function PlayerDataService.SpendCash(player, amount)
	local data = cache[player]
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	PlayerDataService.CashChanged:Fire(player, data.Cash)
	return true
end

function PlayerDataService.OwnsCar(player, brand, model)
	local data = cache[player]
	if not data then return false end
	return data.OwnedCars[brand .. "_" .. model] == true
end

function PlayerDataService.AddOwnedCar(player, brand, model)
	local data = cache[player]
	if not data then return end
	data.OwnedCars[brand .. "_" .. model] = true
end

function PlayerDataService.SetCurrentCar(player, brand, model)
	local data = cache[player]
	if not data then return end
	if not PlayerDataService.OwnsCar(player, brand, model) then
		warn(("[PlayerDataService] %s tried to set unowned car %s %s"):format(player.Name, brand, model))
		return false
	end
	data.CurrentCar = { Brand = brand, Model = model }
	return true
end

function PlayerDataService.GetCurrentCar(player)
	local data = cache[player]
	if not data then return nil end
	return data.CurrentCar
end

--[[ Bindable-style event so UI/other scripts can react to cash changes.
     Using a plain BindableEvent instance created at runtime keeps this
     module self-contained (no extra manual Studio setup needed). ]]
PlayerDataService.CashChanged = Instance.new("BindableEvent")

--[[ Lifecycle hooks — call these from a bootstrap Script ]]
function PlayerDataService.OnPlayerAdded(player)
	local data = loadData(player)
	PlayerDataService.CashChanged:Fire(player, data.Cash)
end

function PlayerDataService.OnPlayerRemoving(player)
	saveData(player)
	cache[player] = nil
end

--[[ Autosave loop — call once from bootstrap Script ]]
function PlayerDataService.StartAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				saveData(player)
			end
		end
	end)
end

--[[ Save everyone immediately — call from game:BindToClose in bootstrap Script ]]
function PlayerDataService.SaveAllOnShutdown()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end

return PlayerDataService
