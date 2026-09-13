-- Server-only player profiles. Persistent loads fail closed; never save defaults
-- after a failed read. See docs/RELIABILITY.md for rollout and Studio testing.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Core = require(script.Parent:WaitForChild("ProfileStore"))
local Service = {}
Service.CashChanged = Instance.new("BindableEvent")

-- Explicit opt-in only; this cannot enable mock data in a live server.
local mock = RunService:IsStudio() and script:GetAttribute("UseMockData") == true
local dataStore
if not mock then
	local ok, result = pcall(function() return DataStoreService:GetDataStore("CarGame_PlayerData_v1") end)
	if ok then dataStore = result else warn("[PlayerDataService] DataStore initialization failed:", result) end
else
	warn("[PlayerDataService] Studio mock data enabled. Progress will not persist.")
end
local cache, loading, closing, saving, stores = {}, {}, {}, {}, {}
local autosaveStarted = false
local shuttingDown = false
local function update(key, transform)
	assert(dataStore, "DataStore unavailable")
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(function() return dataStore:UpdateAsync(key, transform) end)
		if ok then return result end
		lastError = result
		if attempt < 3 then task.wait(attempt) end
	end
	error(tostring(lastError))
end
local function ready(player)
	local data = cache[player]
	if not data or closing[player] or shuttingDown then return nil end
	if not mock and (not data._Session or data._Session.Expires <= os.time()) then return nil end
	return data
end
local function save(player, release)
	-- Serialize autosave and leave/shutdown saves to prevent snapshots going backwards.
	while saving[player] do task.wait() end
	local data = cache[player]
	if not data then return true end
	if mock then return true end
	saving[player] = true
	local ok, result = pcall(function()
		return stores[player].save("Player_" .. player.UserId, Core.copy(data), release)
	end)
	saving[player] = nil
	if ok and result then
		if not release then data._Session = result._Session end
		return true
	end
	warn("[PlayerDataService] Save failed or session ownership expired for", player.UserId)
	if not ok then warn(result) end
	-- Stop awarding progress that can no longer be saved safely.
	if not release and (ok or not data._Session or data._Session.Expires <= os.time()) then
		closing[player] = true
		player:Kick("Your data session was interrupted. Please rejoin.")
	end
	return false
end
function Service.GetData(player)
	local data = ready(player)
	if not data then return nil end
	local result = Core.copy(data)
	result._Session = nil -- never expose ownership metadata to clients
	return result
end
function Service.GetCash(player)
	local data = ready(player)
	return data and data.Cash or 0
end
function Service.AddCash(player, amount)
	local data = ready(player)
	if not Core.addCash(data, amount) then return false end
	Service.CashChanged:Fire(player, data.Cash)
	return true
end
function Service.SpendCash(player, amount)
	local data = ready(player)
	if not Core.spendCash(data, amount) then return false end
	Service.CashChanged:Fire(player, data.Cash)
	return true
end
function Service.PurchaseCar(player, brand, model, price)
	local data = ready(player)
	local ok, message = Core.purchase(data, brand, model, price)
	if ok then Service.CashChanged:Fire(player, data.Cash) end
	return ok, message
end
function Service.OwnsCar(player, brand, model)
	local data = ready(player)
	return data ~= nil and Core.validName(brand) and Core.validName(model)
		and data.OwnedCars[brand .. "_" .. model] == true
end
function Service.AddOwnedCar(player, brand, model)
	local data = ready(player)
	if not data or not Core.validName(brand) or not Core.validName(model) then return false end
	data.OwnedCars[brand .. "_" .. model] = true
	return true
end
function Service.SetCurrentCar(player, brand, model)
	if not Service.OwnsCar(player, brand, model) then return false end
	ready(player).CurrentCar = {Brand = brand, Model = model}
	return true
end
function Service.GetCurrentCar(player)
	local data = ready(player)
	return data and Core.copy(data.CurrentCar) or nil
end
function Service.GetCooldownRemaining(player, jobType, seconds)
	local data = ready(player)
	if not data then return math.huge end
	if not Core.validName(jobType) or not Core.isInteger(seconds, 0, 86400) then return math.huge end
	local timestamp = data.JobCooldowns[jobType]
	return timestamp and math.max(0, seconds - (os.time() - timestamp)) or 0
end
function Service.SetCooldown(player, jobType)
	local data = ready(player)
	if not data or not Core.validName(jobType) then return false end
	data.JobCooldowns[jobType] = os.time()
	return true
end
function Service.OnPlayerAdded(player)
	if cache[player] or loading[player] or shuttingDown then return end
	loading[player] = true
	stores[player] = Core.new(update, os.time, HttpService:GenerateGUID(false))
	local ok, data = pcall(function()
		return mock and Core.normalize(nil) or stores[player].acquire("Player_" .. player.UserId)
	end)
	if ok and data then cache[player] = data end
	loading[player] = nil
	if not ok or not data then
		warn("[PlayerDataService] Load failed or another session is active for", player.UserId)
		player:Kick("Your saved data could not be loaded safely. Please try again shortly.")
		return
	end
	if not player.Parent or closing[player] or shuttingDown then
		save(player, true)
		cache[player] = nil
		return
	end
	Service.CashChanged:Fire(player, data.Cash)
end
function Service.OnPlayerRemoving(player)
	closing[player] = true
	while loading[player] do task.wait() end
	save(player, true)
	cache[player], closing[player], stores[player] = nil, nil, nil
end
function Service.StartAutosaveLoop()
	if autosaveStarted then return end
	autosaveStarted = true
	task.spawn(function()
		while not shuttingDown do
			task.wait(60)
			if shuttingDown then break end
			for player in pairs(cache) do
				if not closing[player] then task.spawn(save, player, false) end
			end
		end
	end)
end
function Service.SaveAllOnShutdown()
	shuttingDown = true
	local pending = 0
	-- Include profiles still loading or already leaving, not only Players:GetPlayers().
	local profiles = {}
	for player in pairs(cache) do profiles[player] = true end
	for player in pairs(loading) do profiles[player] = true end
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			Service.OnPlayerRemoving(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait() end
end
return Service
