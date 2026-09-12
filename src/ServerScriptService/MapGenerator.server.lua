--[[
	MapGenerator.server.lua
	Script — place in ServerScriptService

	Procedurally builds a small placeholder map on server start, with
	RANDOMIZED locations each time the server restarts:

		- Ground plate (~550x550 studs)
		- A SpawnLocation at the center
		- 4 dealership plots (Honda / BMW / Ferrari / Lamborghini), each
		  randomly placed at one of 8 possible spots around the map
		- 3 job-minigame plots (Card Matching / Quick Math / Pattern Memory),
		  each randomly placed at one of 6 possible spots around the map
		- Roads connecting the center to every plot that got used this round

	Because locations shuffle every server restart, players have to actually
	explore the map instead of memorizing "Honda is always in the NE corner."

	Everything is placed under a Folder in Workspace called "CityMap".
	Re-running this script rebuilds the map from scratch (clears the old
	folder first), so re-testing in Studio won't pile up duplicates.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(ReplicatedStorage:WaitForChild("CarConfig"))

local rng = Random.new() -- proper random source, reseeded fresh each server start

-- === Clear any previous map (safe to re-run this script) ===
local existing = Workspace:FindFirstChild("CityMap")
if existing then
	existing:Destroy()
end

local mapFolder = Instance.new("Folder")
mapFolder.Name = "CityMap"
mapFolder.Parent = Workspace

-- === Ground ===
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(550, 1, 550)
ground.Position = Vector3.new(0, 0, 0)
ground.Anchored = true
ground.Material = Enum.Material.Concrete
ground.Color = Color3.fromRGB(120, 120, 125)
ground.Parent = mapFolder

-- === Spawn point (center of map) ===
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "MainSpawn"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = Vector3.new(0, 1, 0)
spawnLocation.Anchored = true
spawnLocation.Material = Enum.Material.Neon
spawnLocation.Color = Color3.fromRGB(80, 200, 255)
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Parent = mapFolder

-- === Helpers ===

--[[ Converts a radius + angle (degrees) into a flat XZ position ]]
local function pointOnCircle(radius, angleDegrees)
	local angleRadians = math.rad(angleDegrees)
	return Vector3.new(radius * math.cos(angleRadians), 0, radius * math.sin(angleRadians))
end

--[[ Fisher-Yates shuffle — returns a new shuffled copy, doesn't mutate the original ]]
local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function addLabel(part, text, textColor)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
end

local function createRoad(pointA, pointB, width)
	width = width or 16
	local distance = (pointB - pointA).Magnitude
	local midpoint = (pointA + pointB) / 2

	local road = Instance.new("Part")
	road.Name = "Road"
	road.Size = Vector3.new(width, 0.3, distance)
	road.CFrame = CFrame.new(midpoint, pointB)
	road.Anchored = true
	road.Material = Enum.Material.Asphalt
	road.Color = Color3.fromRGB(45, 45, 48)
	road.Parent = mapFolder
end

local function createDealership(brandName, position, color)
	local brandInfo = CarConfig.Brands[brandName]

	local building = Instance.new("Part")
	building.Name = brandName .. "Dealership"
	building.Size = Vector3.new(40, 24, 40)
	building.Position = position + Vector3.new(0, 12, 0)
	building.Anchored = true
	building.Material = Enum.Material.SmoothPlastic
	building.Color = color
	building.Parent = mapFolder

	local lot = Instance.new("Part")
	lot.Name = brandName .. "Lot"
	lot.Size = Vector3.new(60, 0.3, 60)
	lot.Position = position
	lot.Anchored = true
	lot.Material = Enum.Material.Concrete
	lot.Color = Color3.fromRGB(90, 90, 95)
	lot.Parent = mapFolder

	addLabel(building, brandInfo.displayName:upper() .. " DEALERSHIP", color)
end

local function createJobLocation(name, position, color)
	local station = Instance.new("Part")
	station.Name = name:gsub("%s+", "") .. "Station"
	station.Size = Vector3.new(16, 10, 16)
	station.Position = position + Vector3.new(0, 5, 0)
	station.Anchored = true
	station.Material = Enum.Material.Metal
	station.Color = color
	station.Parent = mapFolder

	addLabel(station, "JOB: " .. name, color)
end

-- === Dealership location pool: 8 possible spots, only 4 used per server ===
local DEALERSHIP_RADIUS = 190
local dealershipPool = {}
for _, angle in ipairs({ 0, 45, 90, 135, 180, 225, 270, 315 }) do
	table.insert(dealershipPool, pointOnCircle(DEALERSHIP_RADIUS, angle))
end

-- === Job location pool: 6 possible spots, only 3 used per server ===
local JOB_RADIUS = 120
local jobPool = {}
for _, angle in ipairs({ 0, 60, 120, 180, 240, 300 }) do
	table.insert(jobPool, pointOnCircle(JOB_RADIUS, angle))
end

-- === Randomly pick this server's 4 dealership spots and 3 job spots ===
local shuffledDealershipSpots = shuffled(dealershipPool)
local shuffledJobSpots = shuffled(jobPool)

local dealershipBrands = { "Honda", "BMW", "Ferrari", "Lamborghini" }
local dealershipColors = {
	Honda = Color3.fromRGB(200, 40, 40),
	BMW = Color3.fromRGB(40, 90, 200),
	Ferrari = Color3.fromRGB(160, 0, 0),
	Lamborghini = Color3.fromRGB(230, 200, 30),
}

local jobTypes = { "Card Matching", "Quick Math", "Pattern Memory" }
local jobColors = {
	["Card Matching"] = Color3.fromRGB(255, 220, 120), -- gold
	["Quick Math"] = Color3.fromRGB(90, 220, 160),      -- teal/green
	["Pattern Memory"] = Color3.fromRGB(180, 120, 230), -- purple
}

local center = Vector3.new(0, 0.15, 0)

-- === Place the 4 dealerships at their randomly chosen spots ===
for i, brandName in ipairs(dealershipBrands) do
	local position = shuffledDealershipSpots[i]
	createDealership(brandName, position, dealershipColors[brandName])
	createRoad(center, Vector3.new(position.X, 0.15, position.Z))
end

-- === Place the 3 job minigames at their randomly chosen spots ===
for i, jobName in ipairs(jobTypes) do
	local position = shuffledJobSpots[i]
	createJobLocation(jobName, position, jobColors[jobName])
	createRoad(center, Vector3.new(position.X, 0.15, position.Z))
end

print("[MapGenerator] City map generated with randomized layout: 4 dealerships (from a pool of 8 spots), 3 job minigames (from a pool of 6 spots), spawn point, and roads.")
