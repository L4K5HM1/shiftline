-- Persistence core, independent of Roblox services for deterministic regression tests.
-- update(key, transform) must provide DataStore UpdateAsync semantics and retries.
local ProfileStore = {}
ProfileStore.LEASE_SECONDS = 180
local MAX_CASH = 1000000000

function ProfileStore.isInteger(value, minimum, maximum)
	return type(value) == "number" and value == value and value >= minimum
		and value <= maximum and value % 1 == 0
end

function ProfileStore.copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = ProfileStore.copy(child) end
	return result
end

function ProfileStore.validName(value)
	return type(value) == "string" and #value > 0 and #value <= 100
end

function ProfileStore.normalize(value)
	-- Only missing fields are migrated. Corrupt existing values never become defaults.
	if value == nil then value = {} end
	assert(type(value) == "table", "Invalid saved profile")
	local data = ProfileStore.copy(value)
	if data.Cash == nil then data.Cash = 500 end
	if data.OwnedCars == nil then data.OwnedCars = { ["Honda_Civic 2001"] = true } end
	if data.CurrentCar == nil then data.CurrentCar = {Brand = "Honda", Model = "Civic 2001"} end
	if data.JobCooldowns == nil then data.JobCooldowns = {} end
	assert(ProfileStore.isInteger(data.Cash, 0, MAX_CASH), "Invalid saved cash")
	assert(type(data.OwnedCars) == "table", "Invalid owned cars")
	for key, owned in pairs(data.OwnedCars) do
		assert(type(key) == "string" and #key <= 201 and type(owned) == "boolean", "Invalid car entry")
	end
	assert(type(data.CurrentCar) == "table" and ProfileStore.validName(data.CurrentCar.Brand)
		and ProfileStore.validName(data.CurrentCar.Model), "Invalid current car")
	assert(type(data.JobCooldowns) == "table", "Invalid cooldowns")
	for job, timestamp in pairs(data.JobCooldowns) do
		assert(ProfileStore.validName(job) and ProfileStore.isInteger(timestamp, 0, 1000000000000), "Invalid cooldown")
	end
	return data
end

function ProfileStore.new(update, now, token)
	local self = {}
	function self.acquire(key)
		local result = update(key, function(current)
			local data = ProfileStore.normalize(current)
			local lease = data._Session
			if lease ~= nil then
				assert(type(lease) == "table" and type(lease.Token) == "string"
					and ProfileStore.isInteger(lease.Expires, 0, 1000000000000), "Invalid session metadata")
				if lease.Token ~= token and lease.Expires > now() then return nil end
			end
			data._Session = {Token = token, Expires = now() + ProfileStore.LEASE_SECONDS}
			return data
		end)
		if not result or not result._Session or result._Session.Token ~= token then return nil end
		return result
	end
	function self.save(key, snapshot, release)
		local result = update(key, function(current)
			local lease = current and current._Session
			-- Stale servers cannot overwrite a newer session or revive an expired lease.
			if not lease or lease.Token ~= token or lease.Expires <= now() then return nil end
			local data = ProfileStore.normalize(snapshot)
			if release then
				data._Session = nil
			else
				data._Session = {Token = token, Expires = now() + ProfileStore.LEASE_SECONDS}
			end
			return data
		end)
		return result
	end
	return self
end

function ProfileStore.addCash(data, amount)
	if not data or not ProfileStore.isInteger(amount, 0, MAX_CASH) or data.Cash + amount > MAX_CASH then return false end
	data.Cash += amount
	return true
end

function ProfileStore.spendCash(data, amount)
	if not data or not ProfileStore.isInteger(amount, 0, MAX_CASH) or data.Cash < amount then return false end
	data.Cash -= amount
	return true
end

function ProfileStore.purchase(data, brand, model, price)
	if not data or not ProfileStore.validName(brand) or not ProfileStore.validName(model) then return false, "Data not ready or invalid car." end
	local key = brand .. "_" .. model
	if data.OwnedCars[key] then return false, "You already own this car." end
	if not ProfileStore.spendCash(data, price) then return false, "Not enough cash or invalid price." end
	-- No yielding between deduction and ownership update: one server transaction.
	data.OwnedCars[key] = true
	return true, "Car purchased."
end

return ProfileStore
