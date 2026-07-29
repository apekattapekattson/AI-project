--!strict
--[[
	LayerConfig
	-----------
	The 16 mine layers, grouped into 4 zones.

	EXPANSION: adding content = appending entries to this array. Layer values
	are derived from EconomyConfig growth constants rather than hand-typed, so
	a new zone stays on-curve automatically. Zone 5 (The Core, layers 17-20) is
	specced in the roadmap and drops in below with no code changes.

	See docs/GAME_DESIGN.md section 8 (Worlds/Areas).
]]

local EconomyConfig = require(script.Parent.EconomyConfig)

local LayerConfig = {}

--------------------------------------------------------------------------------
-- ZONES
--------------------------------------------------------------------------------

LayerConfig.Zones = {
	{
		id = "surface_quarry",
		name = "Surface Quarry",
		layers = { 1, 4 },
		palette = "warm_earth",
		ambient = "birds_wind",
		hazard = nil,
		gate = nil,
	},
	{
		id = "iron_depths",
		name = "Iron Depths",
		layers = { 5, 8 },
		palette = "cool_slate",
		ambient = "dripping_echo",
		hazard = "darkness",       -- mitigated by Lantern upgrade
		gate = { furnaceTier = 2, delveCount = 2 },
	},
	{
		id = "molten_reach",
		name = "Molten Reach",
		layers = { 9, 12 },
		palette = "ember_red",
		ambient = "lava_rumble",
		hazard = "heat",           -- mitigated by Heat Suit upgrade
		gate = { furnaceTier = 4, delveCount = 6 },
	},
	{
		id = "the_rift",
		name = "The Rift",
		layers = { 13, 16 },
		palette = "void_violet",
		ambient = "void_hum",
		hazard = "instability",    -- mitigated by Stabiliser upgrade
		gate = { furnaceTier = 6, ascensionCount = 1 },
	},

	-- ROADMAP 2.0 — uncomment when art is ready, no code change required:
	-- {
	--   id = "the_core", name = "The Core", layers = {17, 20},
	--   palette = "gold_white", ambient = "core_pulse", hazard = "pressure",
	--   gate = { furnaceTier = 8, ascensionCount = 5 },
	-- },
}

--------------------------------------------------------------------------------
-- LAYERS
--------------------------------------------------------------------------------
-- baseValue / baseHP are derived from the growth curves, NOT hand-tuned.
-- This guarantees new layers stay on-curve. Use `valueMod` only for
-- deliberate, documented exceptions.

local BASE_ORE_VALUE = 1
local BASE_NODE_HP   = 10

local ORES = {
	-- layer, id, display, minFurnaceTier, rarity of bonus node
	{  1, "dirt",       "Dirt",        1, 0.00 },
	{  2, "stone",      "Stone",       1, 0.00 },
	{  3, "copper",     "Copper",      1, 0.02 },
	{  4, "coal",       "Coal",        1, 0.02 },
	{  5, "iron",       "Iron",        2, 0.03 },
	{  6, "silver",     "Silver",      2, 0.03 },
	{  7, "gold",       "Gold",        3, 0.04 },
	{  8, "ruby",       "Ruby",        3, 0.04 },
	{  9, "platinum",   "Platinum",    4, 0.05 },
	{ 10, "titanium",   "Titanium",    4, 0.05 },
	{ 11, "diamond",    "Diamond",     5, 0.06 },
	{ 12, "obsidian",   "Obsidian",    5, 0.06 },
	{ 13, "voidstone",  "Voidstone",   6, 0.08 },
	{ 14, "starmetal",  "Starmetal",   6, 0.08 },
	{ 15, "aether",     "Aether",      7, 0.10 },
	{ 16, "singularity","Singularity", 7, 0.10 },
}

LayerConfig.Layers = {}

for _, ore in ipairs(ORES) do
	local depth, id, display, furnaceTier, shardChance = ore[1], ore[2], ore[3], ore[4], ore[5]
	local n = depth - 1

	LayerConfig.Layers[depth] = {
		depth        = depth,
		oreId        = id,
		displayName  = display,

		-- Derived from EconomyConfig — do not hand-edit.
		oreValue     = BASE_ORE_VALUE * (EconomyConfig.ORE_VALUE_GROWTH ^ n),
		nodeHP       = BASE_NODE_HP   * (EconomyConfig.NODE_HP_GROWTH   ^ n),

		minFurnaceTier = furnaceTier,

		-- Rare node that drops Shards (the never-resetting currency).
		shardNodeChance = shardChance,

		-- Cost to unlock access to this layer, in Coins.
		unlockCost = depth == 1 and 0
			or (100 * (EconomyConfig.ORE_VALUE_GROWTH ^ n)),
	}
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

function LayerConfig.getZoneForDepth(depth: number)
	for _, zone in ipairs(LayerConfig.Zones) do
		if depth >= zone.layers[1] and depth <= zone.layers[2] then
			return zone
		end
	end
	return nil
end

function LayerConfig.getMaxDepth(): number
	return #ORES
end

-- Server-side gate check. Never trust a client claim of layer access.
function LayerConfig.canAccessDepth(depth: number, profile): (boolean, string?)
	local layer = LayerConfig.Layers[depth]
	if not layer then
		return false, "no_such_layer"
	end

	if profile.progression.furnaceTier < layer.minFurnaceTier then
		return false, "furnace_tier_too_low"
	end

	local zone = LayerConfig.getZoneForDepth(depth)
	if zone and zone.gate then
		local g = zone.gate
		if g.furnaceTier and profile.progression.furnaceTier < g.furnaceTier then
			return false, "zone_furnace_gate"
		end
		if g.delveCount and profile.progression.delveCount < g.delveCount then
			return false, "zone_delve_gate"
		end
		if g.ascensionCount and profile.progression.ascensionCount < g.ascensionCount then
			return false, "zone_ascension_gate"
		end
	end

	return true, nil
end

return LayerConfig
