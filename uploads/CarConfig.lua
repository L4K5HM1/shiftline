--[[
	CarConfig.lua
	ModuleScript — place in ReplicatedStorage

	Single source of truth for every car brand, model, price, and race ability.
	Read by: Garage UI, Dealership NPCs, Race Engine, Job payout system.

	ABILITY KEYS (used by the Race Engine to modify typing behavior):
		autoCorrectCase   (number 0-1) -> % chance/coverage of auto-fixing capitalization mistakes
		skipPunctuation   (string)     -> which punctuation marks are auto-skipped: "period" | "comma" | "all"
		skipWord          (number)     -> number of whole words per race the player can skip (button/hotkey)
		skipSentence      (number)     -> number of whole sentences per race the player can skip
		typoForgiveness   (number 0-1) -> % of minor typos (1-2 char off) that don't count as an error
		baseSpeedMult     (number)     -> multiplier applied to the car's base race speed
]]

local CarConfig = {}

CarConfig.Brands = {

	Honda = {
		displayName = "Honda",
		description = "Reliable, cheap, and a great first investment.",
		models = {
			{
				name = "Civic 2001",
				price = 0, -- starting car, free
				baseSpeedMult = 1.0,
				abilities = {
					autoCorrectCase = 0,      -- no help yet
					skipPunctuation = "none",
					typoForgiveness = 0,
				},
			},
			{
				name = "Civic Si",
				price = 2500,
				baseSpeedMult = 1.05,
				abilities = {
					autoCorrectCase = 0.5,   -- fixes first-letter capitalization only
					skipPunctuation = "none",
					typoForgiveness = 0.1,
				},
			},
			{
				name = "Civic Type R",
				price = 9000,
				baseSpeedMult = 1.12,
				abilities = {
					autoCorrectCase = 1.0,   -- fixes ALL capitalization errors
					skipPunctuation = "none",
					typoForgiveness = 0.2,
				},
			},
		},
	},

	BMW = {
		displayName = "BMW",
		description = "Mid-tier performance with real race-day tricks.",
		models = {
			{
				name = "BMW 3 Series",
				price = 20000,
				baseSpeedMult = 1.18,
				abilities = {
					autoCorrectCase = 0,
					skipPunctuation = "period",  -- periods only
					typoForgiveness = 0.15,
				},
			},
			{
				name = "BMW M3",
				price = 55000,
				baseSpeedMult = 1.28,
				abilities = {
					autoCorrectCase = 0,
					skipPunctuation = "period_comma", -- periods + commas
					typoForgiveness = 0.25,
				},
			},
			{
				name = "BMW M5",
				price = 120000,
				baseSpeedMult = 1.38,
				abilities = {
					autoCorrectCase = 0,
					skipPunctuation = "all", -- every punctuation mark
					typoForgiveness = 0.35,
				},
			},
		},
	},

	Ferrari = {
		displayName = "Ferrari",
		description = "Endgame. Everything the small brands offer, plus more.",
		models = {
			{
				name = "Ferrari 488",
				price = 400000,
				baseSpeedMult = 1.5,
				abilities = {
					autoCorrectCase = 1.0,      -- curated: Honda's best
					skipPunctuation = "all",    -- curated: BMW's best
					skipWord = 1,                -- signature ability
					typoForgiveness = 0.4,
				},
			},
		},
	},

	Lamborghini = {
		displayName = "Lamborghini",
		description = "The absolute top. Built for players who've made it.",
		models = {
			{
				name = "Lamborghini Huracan",
				price = 900000,
				baseSpeedMult = 1.55,
				abilities = {
					autoCorrectCase = 1.0,      -- curated: Honda's best
					skipPunctuation = "all",    -- curated: BMW's best
					skipSentence = 1,             -- signature ability (stronger than Ferrari's skipWord)
					typoForgiveness = 0.5,
				},
			},
		},
	},
}

-- Ordered list for UI display (dealership order, garage sort order, etc.)
CarConfig.BrandOrder = { "Honda", "BMW", "Ferrari", "Lamborghini" }

--[[ Helper: get full car data by brand + model name ]]
function CarConfig.GetCar(brandName, modelName)
	local brand = CarConfig.Brands[brandName]
	if not brand then return nil end
	for _, model in ipairs(brand.models) do
		if model.name == modelName then
			return model
		end
	end
	return nil
end

--[[ Helper: get every car as a flat list, useful for garage/race lookups ]]
function CarConfig.GetAllCarsFlat()
	local flat = {}
	for _, brandName in ipairs(CarConfig.BrandOrder) do
		local brand = CarConfig.Brands[brandName]
		for _, model in ipairs(brand.models) do
			table.insert(flat, {
				brand = brandName,
				name = model.name,
				price = model.price,
				baseSpeedMult = model.baseSpeedMult,
				abilities = model.abilities,
			})
		end
	end
	return flat
end

return CarConfig
