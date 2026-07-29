--!strict
--[[
	EconomyConfig
	-------------
	Every tunable number that shapes progression pacing lives here.
	Nothing in this file should ever be edited by gameplay code at runtime.

	Rebalancing the game = editing this file + bumping SCHEMA_VERSION if a
	change invalidates existing saves. It should never require a code change.

	See docs/GAME_DESIGN.md sections 7 (Economy) and 15 (Risks).
]]

local EconomyConfig = {}

-- Bump when a change here invalidates saved data (see ProfileService migrations).
EconomyConfig.SCHEMA_VERSION = 4

--------------------------------------------------------------------------------
-- CORE CURVES
--------------------------------------------------------------------------------

-- Standard incremental cost curve: cost = base * GROWTH ^ level
-- 1.15 is the genre convention. Readable, players can eyeball it.
EconomyConfig.UPGRADE_COST_GROWTH = 1.15

-- Ore value grows slightly faster than node HP, so each layer is a genuine
-- income increase IF you have the pick damage to break it.
-- Keep the ratio (VALUE/HP) between 1.08 and 1.14. Wider = layers trivialise
-- the game. Narrower = pushing down feels bad. This gap IS the pacing mechanism.
EconomyConfig.ORE_VALUE_GROWTH = 3.2
EconomyConfig.NODE_HP_GROWTH   = 2.9

--------------------------------------------------------------------------------
-- PRESTIGE
--------------------------------------------------------------------------------

EconomyConfig.Prestige = {
	Delve = {
		-- Cores = floor((lifetimeCoinsThisRun / THRESHOLD) ^ EXPONENT)
		THRESHOLD = 1e5,

		-- !! THE SINGLE MOST IMPORTANT NUMBER IN THE GAME !!
		-- Below ~0.50 long runs feel pointless; above ~0.60 players over-extend
		-- and stall. This WILL be wrong at launch. Instrument time-between-Delves
		-- from day one and expect to retune it in week one.
		EXPONENT = 0.55,

		UNLOCK_LIFETIME_COINS = 1e5,
	},

	Ascension = {
		-- AP = floor((lifetimeCores / THRESHOLD) ^ EXPONENT)
		THRESHOLD = 1e9,
		EXPONENT  = 0.50,

		UNLOCK_DELVE_COUNT     = 15,
		UNLOCK_LIFETIME_CORES  = 1e9,
	},

	-- Layer 3 (Convergence) is deliberately unbuilt. The number space is
	-- reserved so it can be appended without touching layers 1-2.
	-- Convergence = { THRESHOLD = 1e14, EXPONENT = 0.45 },
}

--------------------------------------------------------------------------------
-- SOFT CAPS
--------------------------------------------------------------------------------
-- effective = cap * (1 - e^(-x / cap))
-- Asymptotic: approaches the cap, never blocks the purchase. Players keep
-- buying, the number keeps moving, runaway inflation is still contained.

EconomyConfig.SoftCaps = {
	luck             = 250,   -- % bonus yield chance
	swingSpeed       = 12,    -- swings/sec before diminishing
	offlineEfficiency= 70,    -- % of online rate
}

--------------------------------------------------------------------------------
-- HARD CAPS
--------------------------------------------------------------------------------
-- Only where genuinely required for stability. Each one has a reason.

EconomyConfig.HardCaps = {
	swingSpeed   = 20,   -- network: remote rate-limit ceiling
	drillCount   = 50,   -- performance: mobile devices
	furnaceSlots = 12,   -- UI: panel real estate
	conveyors    = 40,   -- performance
}

--------------------------------------------------------------------------------
-- OFFLINE / AFK
--------------------------------------------------------------------------------

EconomyConfig.Offline = {
	BASE_EFFICIENCY = 0.25,  -- 25% of online rate at zero upgrades
	MAX_EFFICIENCY  = 0.70,  -- ceiling with full Core investment

	CAP_SECONDS          = 8 * 3600,
	CAP_SECONDS_ASCENDED = 24 * 3600,  -- Ascension perk

	-- Rate is snapshotted server-side at logout. NEVER recompute from a
	-- client-claimed elapsed time; that is a trivial dupe vector.
}

--------------------------------------------------------------------------------
-- ANTI-EXPLOIT THRESHOLDS
--------------------------------------------------------------------------------

EconomyConfig.Security = {
	-- Flag to analytics when a currency delta exceeds this multiple of the
	-- player's current legitimate rate/sec.
	ANOMALY_RATE_MULTIPLIER = 10,

	-- Tolerance above configured swing speed before a remote is dropped.
	SWING_RATE_TOLERANCE = 1.20,

	-- Autosave cadence, plus forced saves on prestige and before granting
	-- any Robux purchase.
	AUTOSAVE_INTERVAL = 120,
}

--------------------------------------------------------------------------------
-- HEALTH METRICS (for live telemetry dashboards)
--------------------------------------------------------------------------------
-- If median time-to-first-Delve drifts outside this window, the early curve
-- needs attention. Day-1 retention lives or dies on this number.

EconomyConfig.Targets = {
	TIME_TO_FIRST_DRILL_SEC  = { min = 600,  max = 900  },  -- 10-15 min
	TIME_TO_FIRST_DELVE_SEC  = { min = 2100, max = 3000 },  -- 35-50 min
	TIME_TO_ASCENSION_SEC    = { min = 18000, max = 23400 },-- 5-6.5 hr
}

return EconomyConfig
