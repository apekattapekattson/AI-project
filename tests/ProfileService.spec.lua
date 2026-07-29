--[[
	ProfileService test suite

	The Roblox services (DataStoreService, Players, RunService) are mocked so
	migration + locking logic can be verified in plain Lua. What's tested here
	is the pure logic, which is where the data-loss bugs actually live.

	    lua5.4 tests/ProfileService.spec.lua
]]

package.path = package.path .. ";./tests/?.lua"

--------------------------------------------------------------------------------
-- ROBLOX MOCKS
--------------------------------------------------------------------------------

local mockStore = { data = {}, failNext = 0, failCount = 0 }

function mockStore:UpdateAsync(key, transform)
	if self.failNext > 0 then
		self.failNext = self.failNext - 1
		self.failCount = self.failCount + 1
		error("simulated DataStore failure")
	end
	local result = transform(self.data[key])
	if result ~= nil then
		self.data[key] = result
	end
	return result
end

local connections = {}
local function mockSignal()
	return { Connect = function(_, fn)
		connections[#connections + 1] = fn
		return { Disconnect = function() end }
	end }
end

_G.game = {
	JobId = "server-A",
	GetService = function(_, name)
		if name == "DataStoreService" then
			return { GetDataStore = function() return mockStore end }
		elseif name == "Players" then
			return { PlayerAdded = mockSignal(), PlayerRemoving = mockSignal() }
		elseif name == "RunService" then
			return { IsStudio = function() return true end }
		elseif name == "ReplicatedStorage" then
			return { Config = { EconomyConfig = "ECONOMY_CONFIG_SENTINEL" } }
		end
		return {}
	end,
	BindToClose = function() end,
}

_G.task = {
	wait  = function() end,
	spawn = function() end,
}

_G.warn = function(...)
	local parts = {}
	for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
	io.stderr:write("[warn] " .. table.concat(parts, " ") .. "\n")
end

if not table.clone then
	table.clone = function(t)
		local c = {}
		for k, v in pairs(t) do c[k] = v end
		return c
	end
end

-- Intercept the module's require() of EconomyConfig.
local shim = require("luau_shim")
local realRequire = require
local function patchedRequire(target)
	if target == "ECONOMY_CONFIG_SENTINEL" then
		return {
			SCHEMA_VERSION = 4,
			Security = { AUTOSAVE_INTERVAL = 120 },
		}
	end
	return realRequire(target)
end

local src = io.open("src/ServerScriptService/Services/ProfileService.lua"):read("*a")
local stripped = shim.stripTypes(src)
local env = setmetatable({ require = patchedRequire }, { __index = _G })
local chunk = assert(load(stripped, "@ProfileService.lua", "t", env))
local PS = chunk()

--------------------------------------------------------------------------------
-- HARNESS
--------------------------------------------------------------------------------

local passed, failed, failures = 0, 0, {}

local function check(name, cond, detail)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		failures[#failures + 1] = name .. (detail and ("  -> " .. tostring(detail)) or "")
	end
end

local function reset()
	mockStore.data = {}
	mockStore.failNext = 0
	mockStore.failCount = 0
	_G.game.JobId = "server-A"
end

--------------------------------------------------------------------------------
print("=== default profile shape ===")

local d = PS.defaultProfile()
check("has schemaVersion 4", d.schemaVersion == 4, d.schemaVersion)
check("coins is a STRING not a number", type(d.currencies.coins) == "string",
	type(d.currencies.coins))
check("lifetimeCoins is a string", type(d.progression.lifetimeCoins) == "string")
check("shards is a plain number", type(d.currencies.shards) == "number")
check("has purchases.productReceipts", type(d.purchases.productReceipts) == "table")
check("starts at layer 1", d.progression.currentLayer == 1)
check("furnace tier 1", d.progression.furnaceTier == 1)

--------------------------------------------------------------------------------
print("=== migrations ===")

-- A v1 profile from the earliest build.
local v1 = {
	schemaVersion = 1,
	currencies = { coins = 5000, cores = 3 },
	progression = { currentLayer = 4, lifetimeCoins = 9000, lifetimeCores = 3 },
}

local migrated, applied = PS.migrate(v1)
check("v1 -> v4 applies 3 migrations", applied == 3, applied)
check("ends at version 4", migrated.schemaVersion == 4, migrated.schemaVersion)
check("shards backfilled", migrated.currencies.shards == 0)
check("retention branch created", type(migrated.retention) == "table")
check("loginStreak defaulted", migrated.retention.loginStreak == 0)
check("coins converted to string", type(migrated.currencies.coins) == "string",
	tostring(migrated.currencies.coins))
check("receipts backfilled", type(migrated.purchases.productReceipts) == "table")
check("existing data preserved", migrated.progression.currentLayer == 4,
	migrated.progression.currentLayer)
check("missing branches filled from default", migrated.automation ~= nil
	and migrated.automation.drills.count == 0)

-- Already current: no-op.
local current = PS.defaultProfile()
local _, applied2 = PS.migrate(current)
check("current version applies 0 migrations", applied2 == 0, applied2)

-- Newer than us: must be left alone.
local future = PS.defaultProfile()
future.schemaVersion = 99
future.mysteryField = "from the future"
local futureOut, applied3 = PS.migrate(future)
check("future save is not downgraded", applied3 == -1, applied3)
check("future save keeps unknown fields", futureOut.mysteryField == "from the future")
check("future save keeps its version", futureOut.schemaVersion == 99)

-- Partial/corrupt v2.
local partial = { schemaVersion = 2, currencies = { coins = 100 } }
local pOut = PS.migrate(partial)
check("partial profile survives migration", pOut.schemaVersion == 4)
check("partial profile gets full shape", pOut.collections ~= nil
	and pOut.quests ~= nil and pOut.meta ~= nil)

--------------------------------------------------------------------------------
print("=== session locking ===")

local held = PS._lockIsHeldElsewhere

check("nil lock is free", held(nil) == false)
check("own jobId is not 'elsewhere'",
	held({ jobId = "server-A", timestamp = os.time() }) == false)
check("other server's fresh lock blocks",
	held({ jobId = "server-B", timestamp = os.time() }) == true)
check("stale lock (>600s) is stealable",
	held({ jobId = "server-B", timestamp = os.time() - 700 }) == false)
check("lock at boundary still held",
	held({ jobId = "server-B", timestamp = os.time() - 100 }) == true)

--------------------------------------------------------------------------------
print("=== load / save round trip ===")

reset()
local p = PS.loadProfile(123)
check("fresh load is not safe mode", p.__safeMode == false)
check("createdAt stamped", p.meta.createdAt > 0)
check("lock written to store", mockStore.data["Player_123"].lock.jobId == "server-A")

p.currencies.coins = "1.234000e18"
p.progression.currentLayer = 7
local saved = PS.saveProfile(123)
check("save succeeds", saved == true)
check("saveCount incremented", mockStore.data["Player_123"].profile.meta.saveCount == 1)
check("value persisted", mockStore.data["Player_123"].profile.currencies.coins == "1.234000e18")
check("runtime fields stripped", mockStore.data["Player_123"].profile.__safeMode == nil)
check("userId stripped", mockStore.data["Player_123"].profile.__userId == nil)

PS.releaseProfile(123)
check("lock released on leave", mockStore.data["Player_123"].lock == nil)
check("profile cleared from memory", PS.getProfile(123) == nil)

--------------------------------------------------------------------------------
print("=== duplication defence ===")

reset()
-- Server A loads the profile.
PS.loadProfile(456)
check("A holds the lock", mockStore.data["Player_456"].lock.jobId == "server-A")

-- Server B tries to load while A holds it.
_G.game.JobId = "server-B"
local pB = PS.loadProfile(456)
check("B is refused and enters safe mode", pB.__safeMode == true, pB.__safeReason)
check("B reports session_locked", pB.__safeReason == "session_locked", pB.__safeReason)
check("lock still belongs to A", mockStore.data["Player_456"].lock.jobId == "server-A")

-- Safe-mode profiles must never write.
pB.currencies.coins = "9.999999e99"
local badSave = PS.saveProfile(456)
check("safe-mode profile refuses to save", badSave == false)
check("store not corrupted by safe-mode session",
	mockStore.data["Player_456"].profile.currencies.coins == "0",
	mockStore.data["Player_456"].profile.currencies.coins)

--------------------------------------------------------------------------------
print("=== receipt anti-duplication ===")

reset()
_G.game.JobId = "server-A"
PS.loadProfile(789)

check("unknown receipt not present", PS.hasReceipt(789, "receipt-abc") == false)
local first = PS.recordReceipt(789, "receipt-abc")
check("first grant records", first == true)
check("receipt now present", PS.hasReceipt(789, "receipt-abc") == true)

local second = PS.recordReceipt(789, "receipt-abc")
check("duplicate receipt refused", second == false)

local count = 0
for _, id in ipairs(PS.getProfile(789).purchases.productReceipts) do
	if id == "receipt-abc" then count = count + 1 end
end
check("receipt stored exactly once", count == 1, count)
check("receipt persisted immediately",
	#mockStore.data["Player_789"].profile.purchases.productReceipts == 1)

--------------------------------------------------------------------------------
print("=== failure handling ===")

reset()
mockStore.failNext = 2          -- fail twice, then succeed
local recovered = PS.loadProfile(999)
check("retries then succeeds", recovered.__safeMode == false)
check("two failures were consumed", mockStore.failCount == 2, mockStore.failCount)

reset()
mockStore.failNext = 99         -- fail every attempt
local dead = PS.loadProfile(1000)
check("exhausted retries -> safe mode", dead.__safeMode == true)
check("safe mode records a reason", dead.__safeReason ~= nil)
check("safe mode still returns a usable shape",
	dead.currencies ~= nil and dead.progression.currentLayer == 1)
check("safe mode refuses to save", PS.saveProfile(1000) == false)

--------------------------------------------------------------------------------
print()
print(("=== %d passed, %d failed ==="):format(passed, failed))
for _, f in ipairs(failures) do print("  FAIL: " .. f) end
os.exit(failed == 0 and 0 or 1)
