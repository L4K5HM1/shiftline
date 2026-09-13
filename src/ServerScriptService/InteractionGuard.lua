-- ProximityPrompt display is not authorization: validate distance on the server.
local CollectionService = game:GetService("CollectionService")
local Guard = {}
local lastRequests = setmetatable({}, {__mode = "k"})

function Guard.allowRequest(player, action, interval)
	local now = os.clock()
	local requests = lastRequests[player] or {}
	lastRequests[player] = requests
	if requests[action] and now - requests[action] < interval then return false end
	requests[action] = now
	return true
end

function Guard.near(player, tag, attribute, expected)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) and part:GetAttribute(attribute) == expected
			and (root.Position - part.Position).Magnitude <= 16 then return true end
	end
	return false
end
return Guard
