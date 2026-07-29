--!strict
--[[
	ProfileService
	--------------
	Session-locked profile load/save for Roblox DataStores.

	WHY SESSION LOCKING:
	Without it, a player joining server B while still loaded on server A has
	two authoritative copies of their currency. Buy an upgrade on A, let B
	save over it, and the upgrade is free. This is the single most common
	duplication exploit in Roblox incrementals. A lock key claimed on join and
	released on leave makes the window closeable.

	WHY SAFE MODE:
	If a load fails after retries we do NOT hand the player a fresh profile.
	That looks identical to a wipe, they rebuild on top of it, and then the
	real profile can never be restored. Instead the session is marked
	read-only: they can look around, nothing saves, and the UI says so.

	WHY VERSIONED MIGRATIONS:
	Schema changes are inevitable across a multi-year live game. Every change
	gets a numbered migration that runs in sequence on load. Never mutate a
	shape in place without one.

	See docs/GAME_DESIGN.md sections 10-11.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)

local ProfileService = {}
ProfileService.__index = ProfileService

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local STORE_NAME    = "PlayerProfiles_v1"
local KEY_PREFIX    = "Player_"

local AUTOSAVE_INTERVAL = EconomyConfig.Security.AUTOSAVE_INTERVAL  -- 120s
local CURRENT_VERSION   = EconomyConfig.SCHEMA_VERSION             -- 4

-- Exponential backoff: 1s, 2s, 4s, 8s, then give up -> safe mode.
local RETRY_DELAYS = { 1, 2, 4, 8 }

-- A lock older than this is considered abandoned (server crashed without
-- releasing). Must exceed the longest plausible autosave gap.
local LOCK_STALE_SECONDS = 600

local store = DataStoreService:GetDataStore(STORE_NAME)

--------------------------------------------------------------------------------
-- DEFAULT PROFILE
--------------------------------------------------------------------------------
-- BigNumbers are stored as STRINGS. See BigNumber.lua for why.

local function defaultProfile()
	return {
		schemaVersion = CURRENT_VERSION,

		currencies = {
			coins        = "0",
			cores        = "0",
			shards       = 0,
			ascensionPts = 0,
		},

		progression = {
			currentLayer    = 1,
			highestLayer    = 1,
			delveCount      = 0,
			ascensionCount  = 0,
			lifetimeCoins   = "0",
			lifetimeCores   = "0",
			furnaceTier     = 1,
			playtimeSeconds = 0,
		},

		upgrades = {
			coin      = {},
			core      = {},
			ascension = {},
		},

		automation = {
			drills    = { count = 0, tier = 1 },
			conveyors = { count = 0, tier = 1 },
			autoBuy   = { enabled = false, rule = "cheapest" },
		},

		quests = {
			daily     = {},
			weekly    = {},
			lastReset = 0,
		},

		retention = {
			loginStreak     = 0,
			longestStreak   = 0,
			lastLoginDay    = 0,
			lastLogoutTime  = 0,
			offlineRateSnap = "0",
		},

		collections = {
			oresDiscovered = {},
			achievements   = {},
			cosmetics      = { owned = {}, equipped = {} },
		},

		purchases = {
			gamepasses      = {},
			productReceipts = {},
		},

		meta = {
			createdAt  = 0,
			lastSaveAt = 0,
			saveCount  = 0,
		},
	}
end

ProfileService.defaultProfile = defaultProfile

--------------------------------------------------------------------------------
-- MIGRATIONS
--------------------------------------------------------------------------------
--[[
	Migrations[n] upgrades a profile from version n to version n+1.
	They run in sequence, so a v1 save loads correctly on a v4 server.

	RULES:
	  - Never delete a migration, however old.
	  - Never edit a shipped migration; add a new one instead.
	  - Each must be idempotent-safe on partial data (fields may be missing).
]]

local Migrations = {}

-- v1 -> v2: Shards introduced as a permanent currency.
Migrations[1] = function(p)
	p.currencies = p.currencies or {}
	p.currencies.shards = p.currencies.shards or 0
	return p
end

-- v2 -> v3: Retention tracking (streaks, offline snapshot).
Migrations[2] = function(p)
	p.retention = p.retention or {}
	local r = p.retention
	r.loginStreak     = r.loginStreak or 0
	r.longestStreak   = r.longestStreak or 0
	r.lastLoginDay    = r.lastLoginDay or 0
	r.lastLogoutTime  = r.lastLogoutTime or 0
	r.offlineRateSnap = r.offlineRateSnap or "0"
	return p
end

-- v3 -> v4: Coin/Core totals move from Lua numbers to BigNumber strings.
-- Values above 2^53 were already lossy; we cannot recover that precision,
-- only stop it getting worse.
Migrations[3] = function(p)
	local function toStr(v)
		if type(v) == "number" then
			return string.format("%.6fe%d", v / (10 ^ math.floor(math.log(math.max(v, 1), 10))),
				math.floor(math.log(math.max(v, 1), 10)))
		end
		return v or "0"
	end

	p.currencies   = p.currencies or {}
	p.progression  = p.progression or {}
	p.currencies.coins         = toStr(p.currencies.coins)
	p.currencies.cores         = toStr(p.currencies.cores)
	p.progression.lifetimeCoins = toStr(p.progression.lifetimeCoins)
	p.progression.lifetimeCores = toStr(p.progression.lifetimeCores)

	p.purchases = p.purchases or {}
	p.purchases.productReceipts = p.purchases.productReceipts or {}
	return p
end

ProfileService.Migrations = Migrations

--[[
	migrate(profile) -> profile, migrationsApplied

	Fills missing branches against the default shape, then runs each
	sequential migration.
]]
function ProfileService.migrate(profile)
	local applied = 0
	local version = profile.schemaVersion or 1

	if version > CURRENT_VERSION then
		-- Save is from a NEWER server than this one. Do not touch it —
		-- downgrading would destroy fields we don't understand.
		return profile, -1
	end

	while version < CURRENT_VERSION do
		local fn = Migrations[version]
		if not fn then
			warn(("ProfileService: no migration from v%d, aborting"):format(version))
			break
		end
		profile = fn(profile)
		version = version + 1
		applied = applied + 1
	end

	profile.schemaVersion = version

	-- Backfill any branch added to the default shape without a migration.
	local function fill(target, template)
		for k, v in pairs(template) do
			if target[k] == nil then
				target[k] = (type(v) == "table") and (table.clone(v)) or v
			elseif type(v) == "table" and type(target[k]) == "table" then
				fill(target[k], v)
			end
		end
	end
	fill(profile, defaultProfile())

	return profile, applied
end

--------------------------------------------------------------------------------
-- SESSION LOCKING
--------------------------------------------------------------------------------

local function lockIsHeldElsewhere(lock): boolean
	if not lock then return false end
	if lock.jobId == game.JobId then return false end          -- our own lock
	if (os.time() - (lock.timestamp or 0)) > LOCK_STALE_SECONDS then
		return false                                            -- stale, steal it
	end
	return true
end

ProfileService._lockIsHeldElsewhere = lockIsHeldElsewhere

--------------------------------------------------------------------------------
-- LOAD
--------------------------------------------------------------------------------

local activeProfiles: { [number]: any } = {}

--[[
	loadProfile(userId) -> profile

	profile.__safeMode = true means the load failed. The caller must treat the
	session as read-only and surface a banner. Never save a safe-mode profile.
]]
function ProfileService.loadProfile(userId: number)
	local key = KEY_PREFIX .. userId
	local lastError

	for attempt = 1, #RETRY_DELAYS + 1 do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(stored)
				stored = stored or { profile = defaultProfile(), lock = nil }

				if lockIsHeldElsewhere(stored.lock) then
					-- Abort the write; another server owns this profile.
					return nil
				end

				stored.lock = { jobId = game.JobId, timestamp = os.time() }
				return stored
			end)
		end)

		if ok and result then
			local profile = ProfileService.migrate(result.profile)

			if profile.meta.createdAt == 0 then
				profile.meta.createdAt = os.time()
			end

			profile.__safeMode = false
			profile.__userId   = userId
			profile.__dirty    = false
			activeProfiles[userId] = profile
			return profile
		end

		if ok and result == nil then
			lastError = "session_locked"
		else
			lastError = tostring(result)
		end

		local delay = RETRY_DELAYS[attempt]
		if delay then task.wait(delay) end
	end

	-- All retries exhausted.
	warn(("ProfileService: load failed for %d (%s), entering SAFE MODE")
		:format(userId, tostring(lastError)))

	local safe = defaultProfile()
	safe.__safeMode   = true
	safe.__safeReason = lastError
	safe.__userId     = userId
	activeProfiles[userId] = safe
	return safe
end

--------------------------------------------------------------------------------
-- SAVE
--------------------------------------------------------------------------------

function ProfileService.saveProfile(userId: number, releaseLock: boolean?): boolean
	local profile = activeProfiles[userId]
	if not profile then return false end

	if profile.__safeMode then
		-- Refusing to save is the entire point of safe mode.
		return false
	end

	local key = KEY_PREFIX .. userId
	profile.meta.lastSaveAt = os.time()
	profile.meta.saveCount  = (profile.meta.saveCount or 0) + 1

	-- Strip runtime-only fields before persisting.
	local toStore = table.clone(profile)
	toStore.__safeMode   = nil
	toStore.__safeReason = nil
	toStore.__userId     = nil
	toStore.__dirty      = nil

	for attempt = 1, #RETRY_DELAYS + 1 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored)
				stored = stored or {}

				-- Only write if we still hold the lock.
				if stored.lock and stored.lock.jobId ~= game.JobId
					and (os.time() - (stored.lock.timestamp or 0)) <= LOCK_STALE_SECONDS then
					return nil
				end

				stored.profile = toStore

				-- NOTE: deliberately an if/else, not `releaseLock and nil or {...}`.
				-- That idiom is broken when the "true" branch is nil: Lua falls
				-- through to the `or`, so the lock would never be released and
				-- the player could not rejoin until it went stale (10 min).
				if releaseLock then
					stored.lock = nil
				else
					stored.lock = { jobId = game.JobId, timestamp = os.time() }
				end

				return stored
			end)
		end)

		if ok then
			profile.__dirty = false
			return true
		end

		warn(("ProfileService: save attempt %d failed for %d: %s")
			:format(attempt, userId, tostring(err)))

		local delay = RETRY_DELAYS[attempt]
		if delay then task.wait(delay) end
	end

	return false
end

function ProfileService.releaseProfile(userId: number)
	ProfileService.saveProfile(userId, true)
	activeProfiles[userId] = nil
end

function ProfileService.getProfile(userId: number)
	return activeProfiles[userId]
end

--------------------------------------------------------------------------------
-- ANTI-DUPLICATION: PRODUCT RECEIPTS
--------------------------------------------------------------------------------
--[[
	Roblox can re-deliver a ProcessReceipt callback for the same purchase.
	Granting twice is free currency, so every receipt id is recorded and
	checked before granting. Must be saved BEFORE the grant is acknowledged.
]]

function ProfileService.hasReceipt(userId: number, receiptId: string): boolean
	local profile = activeProfiles[userId]
	if not profile then return false end
	for _, id in ipairs(profile.purchases.productReceipts) do
		if id == receiptId then return true end
	end
	return false
end

function ProfileService.recordReceipt(userId: number, receiptId: string): boolean
	local profile = activeProfiles[userId]
	if not profile or profile.__safeMode then return false end
	if ProfileService.hasReceipt(userId, receiptId) then return false end

	table.insert(profile.purchases.productReceipts, receiptId)
	-- Force an immediate save; never acknowledge a purchase we haven't stored.
	return ProfileService.saveProfile(userId)
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

function ProfileService:Init()
	Players.PlayerAdded:Connect(function(player)
		ProfileService.loadProfile(player.UserId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProfileService.releaseProfile(player.UserId)
	end)
end

function ProfileService:Start()
	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for userId in pairs(activeProfiles) do
				ProfileService.saveProfile(userId)
			end
		end
	end)

	-- Shutdown save. Without this, up to AUTOSAVE_INTERVAL of progress is lost
	-- on every server shutdown — and Roblox shuts servers down constantly.
	game:BindToClose(function()
		if RunService:IsStudio() then return end

		local pending = 0
		for userId in pairs(activeProfiles) do
			pending += 1
			task.spawn(function()
				ProfileService.releaseProfile(userId)
				pending -= 1
			end)
		end

		local deadline = os.clock() + 25  -- Roblox allows ~30s
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return ProfileService
