-- Execute the actual server script against small Roblox service doubles.
local now, serial, balance = 0, 0, 500
local ready, nearby, cooldown = true, true, 0
local children = {}
local function signal()
 return {Connect=function(self, fn) self.callback=fn end}
end
local function node()
 return {FindFirstChild=function(_,name) return children[name] end,
  WaitForChild=function(_,name) return name end}
end
local replicated, server = node(), node()
local Instance = {new=function()
 local object=node(); object.OnServerEvent=signal()
 return setmetatable(object,{__newindex=function(t,k,v)
  rawset(t,k,v);if k=="Parent" then children[t.Name]=t end
 end})
end}
local profiles = {
 GetData=function() return ready and {} or nil end,
 GetCooldownRemaining=function() return cooldown end,
 AddCash=function(_,amount) if not ready then return false end;balance+=amount;return true end,
 SetCooldown=function() cooldown=60 end
}
local guard={allowRequest=function() return true end, near=function() return nearby end}
local services={ReplicatedStorage=replicated,ServerScriptService=server,
 Players={PlayerRemoving=signal()},HttpService={GenerateGUID=function()serial+=1;return tostring(serial)end}}
local game={GetService=function(_,name)return services[name]end}
local require=function(name) return ({PlayerDataService=profiles,ProfileStore=Core,InteractionGuard=guard})[name] end
local os={clock=function() return now end}
-- SERVER_SOURCE is inserted here by the Node runner.
__SERVER_SOURCE__
local start=children.StartJob.OnServerInvoke
local complete=children.CompleteJob.OnServerInvoke
local player={}
assert(not start(player,{}))
ready=false;assert(not start(player,"Quick Math"));ready=true
nearby=false;assert(not start(player,"Quick Math"));nearby=true
local ok,_,token=start(player,"Quick Math");assert(ok)
assert(not start(player,"Card Matching")) -- no session replacement
now=6
assert(not complete(player,"Quick Math",10,"wrong-token"))
assert(complete(player,"Quick Math",10,token));assert(balance==525)
assert(not complete(player,"Quick Math",10,token));assert(balance==525)
assert(not start(player,"Quick Math")) -- persisted cooldown
cooldown=0
local _,_,invalidToken=start(player,"Quick Math");now=12
assert(not complete(player,"Quick Math",0/0,invalidToken));assert(balance==525)
local _,_,cancelled=start(player,"Quick Math")
children.CancelJob.OnServerEvent.callback(player,cancelled)
assert(not complete(player,"Quick Math",10,cancelled))
local _,_,expired=start(player,"Quick Math");now=1000
assert(not complete(player,"Quick Math",10,expired));assert(balance==525)
print("PASS job handlers: readiness, proximity, duplicate starts, tokens, payout, replay, cooldown, NaN, cancellation, expiry")
