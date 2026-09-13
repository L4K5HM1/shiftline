local count = 0
local function test(name, fn)
 fn(); count += 1; print("PASS " .. name)
end
local function fixture()
 local records, clock = {}, 1000
 local function update(key, transform)
  local nextValue = transform(Core.copy(records[key]))
  if nextValue then records[key] = Core.copy(nextValue) end
  return Core.copy(nextValue)
 end
 return records, Core.new(update, function() return clock end, "A"),
  Core.new(update, function() return clock end, "B"), function(t) clock = t end
end
test("new profiles and scalar backfill are independent", function()
 local a, b = Core.normalize({}), Core.normalize({})
 assert(a.Cash == 500)
 a.OwnedCars.test = true
 assert(b.OwnedCars.test == nil)
end)
test("corrupt saves fail instead of resetting balances", function()
 for _, value in ipairs({"bad", {Cash=-1}, {Cash=0/0}, {Cash=math.huge}, {OwnedCars="bad"}}) do
  assert(not pcall(Core.normalize, value))
 end
end)
test("failed storage reads never produce default profiles", function()
 local called = 0
 local store = Core.new(function() called += 1; error("offline") end, function() return 1000 end, "A")
 assert(not pcall(store.acquire, "player")); assert(called == 1)
end)
test("a second live session cannot load or overwrite a profile", function()
 local records, a, b = fixture()
 local data = a.acquire("p"); assert(data)
 assert(b.acquire("p") == nil)
 data.Cash = 600; assert(a.save("p",data,false))
 assert(records.p.Cash == 600)
 assert(b.save("p",data,false) == nil)
end)
test("expired sessions cannot overwrite a newer server", function()
 local records, a, b, time = fixture()
 local old = a.acquire("p"); time(1181)
 local new = b.acquire("p"); new.Cash = 700
 assert(b.save("p",new,false)); old.Cash = 900
 assert(a.save("p",old,false) == nil); assert(records.p.Cash == 700)
end)
test("release persists progress and permits immediate rejoin", function()
 local records, a, b = fixture()
 local data = a.acquire("p"); data.Cash = 650
 assert(a.save("p",data,true)); assert(records.p._Session == nil)
 assert(b.acquire("p").Cash == 650)
end)
test("renewal extends the lease and preserves cooldowns", function()
 local records, a, _, time = fixture()
 local data = a.acquire("p"); data.JobCooldowns["Quick Math"] = 1010
 time(1060); local saved = a.save("p",data,false)
 assert(saved._Session.Expires == 1240); assert(records.p.JobCooldowns["Quick Math"] == 1010)
end)
test("invalid amounts cannot alter money", function()
 local data = Core.normalize(nil)
 for _, value in ipairs({-1,0/0,math.huge,1.5,"25"}) do
  assert(not Core.addCash(data,value)); assert(not Core.spendCash(data,value))
 end
 assert(data.Cash == 500)
end)
test("duplicate and unaffordable purchases preserve money and ownership", function()
 local data = Core.normalize(nil)
 assert(Core.purchase(data,"Test","Car",200)); assert(data.Cash == 300)
 assert(not Core.purchase(data,"Test","Car",200)); assert(data.Cash == 300)
 assert(not Core.purchase(data,"Test","Expensive",400)); assert(not data.OwnedCars.Test_Expensive)
end)
test("integer scores reject NaN, infinity and fractions", function()
 for _, value in ipairs({0/0,math.huge,-1,11,2.5,"5"}) do assert(not Core.isInteger(value,0,10)) end
 assert(Core.isInteger(0,0,10)); assert(Core.isInteger(10,0,10))
end)
return count
