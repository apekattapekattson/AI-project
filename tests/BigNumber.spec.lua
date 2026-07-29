--[[
	BigNumber test suite

	Plain Lua so it runs in CI without Roblox. Also runnable under TestEZ in
	Studio with a thin wrapper.

	    lua5.4 tests/BigNumber.spec.lua
]]

package.path = package.path .. ";./tests/?.lua"

-- Roblox `warn` shim for standalone runs.
if not warn then
	_G.warn = function(...) io.stderr:write("[warn] ", table.concat({ ... }, " "), "\n") end
end

-- Luau-typed module loaded via the type-stripping shim (see tests/luau_shim.lua).
local shim = require("luau_shim")
local BN = shim.requireLuau("src/ReplicatedStorage/Shared/BigNumber.lua")

local passed, failed = 0, 0
local failures = {}

local function check(name, cond, detail)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		failures[#failures + 1] = name .. (detail and ("  -> " .. tostring(detail)) or "")
	end
end

local function approx(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-9) * math.max(1, math.abs(a), math.abs(b))
end

--------------------------------------------------------------------------------
print("=== construction & normalisation ===")

local a = BN.fromNumber(1234)
check("normalises mantissa into [1,10)", a.m >= 1 and a.m < 10, a.m)
check("1234 -> e=3", a.e == 3, a.e)
check("1234 round-trips", approx(BN.toNumber(a), 1234), BN.toNumber(a))

local z = BN.zero()
check("zero is canonical", z.m == 0 and z.e == 0)
check("zero formats as '0'", BN.format(z) == "0", BN.format(z))

local neg = BN.fromNumber(-5000)
check("negative sign preserved", neg.m < 0, neg.m)
check("negative round-trips", approx(BN.toNumber(neg), -5000), BN.toNumber(neg))

--------------------------------------------------------------------------------
print("=== arithmetic ===")

local x = BN.fromNumber(1e10)
local y = BN.fromNumber(5e9)

check("add", approx(BN.toNumber(BN.add(x, y)), 1.5e10), BN.toNumber(BN.add(x, y)))
check("sub", approx(BN.toNumber(BN.sub(x, y)), 5e9), BN.toNumber(BN.sub(x, y)))
check("mul", approx(BN.toNumber(BN.mul(x, y)), 5e19), BN.toNumber(BN.mul(x, y)))
check("div", approx(BN.toNumber(BN.div(x, y)), 2), BN.toNumber(BN.div(x, y)))

check("add identity (x+0)", BN.eq(BN.add(x, BN.zero()), x))
check("mul by zero", BN.eq(BN.mul(x, BN.zero()), BN.zero()))
check("sub to zero", BN.eq(BN.sub(x, x), BN.zero()))
check("div by zero is guarded", BN.eq(BN.div(x, BN.zero()), BN.zero()))

-- The precision cliff this module exists to solve.
local huge = BN.new(1, 300)
local tiny = BN.new(1, 1)
check("add across >15 magnitudes is a no-op", BN.eq(BN.add(huge, tiny), huge))

--------------------------------------------------------------------------------
print("=== beyond 2^53 (the whole point) ===")

-- float64 loses integer precision past 9.007e15.
local big1 = BN.new(1.5, 18)   -- 1.5e18
local big2 = BN.new(2.5, 18)   -- 2.5e18
local sum  = BN.add(big1, big2)
check("1.5e18 + 2.5e18 = 4e18", approx(sum.m, 4.0, 1e-9) and sum.e == 18,
	BN.toString(sum))

local prod = BN.mul(BN.new(1, 100), BN.new(1, 100))
check("1e100 * 1e100 = 1e200", approx(prod.m, 1.0) and prod.e == 200, BN.toString(prod))

local vast = BN.new(1, 5000)
check("exponent far beyond float64 range survives", vast.e == 5000, vast.e)
check("toNumber saturates rather than NaN", BN.toNumber(vast) == math.huge)

--------------------------------------------------------------------------------
print("=== pow (prestige formulas) ===")

-- Delve: Cores = (lifetimeCoins / 1e5) ^ 0.55
local lifetime = BN.new(1, 18)
local ratio    = BN.div(lifetime, BN.fromNumber(1e5))
local cores    = BN.pow(ratio, 0.55)
-- (1e13)^0.55 = 10^7.15
check("delve exponent ^0.55", approx(BN.log10(cores), 7.15, 1e-6), BN.log10(cores))

-- Ascension: AP = (lifetimeCores / 1e9) ^ 0.5
local ap = BN.pow(BN.div(BN.new(1, 15), BN.fromNumber(1e9)), 0.5)
check("ascension exponent ^0.5", approx(BN.log10(ap), 3.0, 1e-6), BN.log10(ap))

check("pow exp=0 -> 1", approx(BN.toNumber(BN.pow(x, 0)), 1))
check("pow of zero -> 0", BN.eq(BN.pow(BN.zero(), 0.5), BN.zero()))
check("pow preserves huge exponents", BN.pow(BN.new(1, 1000), 2).e == 2000)

--------------------------------------------------------------------------------
print("=== comparison ===")

check("gte true",  BN.gte(x, y))
check("gte false", not BN.gte(y, x))
check("lt true",   BN.lt(y, x))
check("eq self",   BN.eq(x, x))
check("neg < pos", BN.lt(BN.fromNumber(-1), BN.fromNumber(1)))
check("neg ordering", BN.lt(BN.fromNumber(-100), BN.fromNumber(-1)))
check("zero vs neg", BN.gte(BN.zero(), BN.fromNumber(-5)))
check("max", BN.eq(BN.max(x, y), x))
check("min", BN.eq(BN.min(x, y), y))
check("same exp, diff mantissa", BN.lt(BN.new(1.1, 20), BN.new(9.9, 20)))

--------------------------------------------------------------------------------
print("=== serialisation ===")

local vals = { BN.fromNumber(0), BN.fromNumber(1), BN.fromNumber(-42),
               BN.new(1.234, 18), BN.new(9.999, 250) }
for i, v in ipairs(vals) do
	local rt = BN.fromString(BN.toString(v))
	check("round-trip #" .. i, BN.eq(rt, v),
		BN.toString(v) .. " -> " .. BN.toString(rt))
end

check("legacy plain-number string", approx(BN.toNumber(BN.fromString("1000")), 1000))
check("garbage string defaults to 0", BN.eq(BN.fromString("banana"), BN.zero()))
check("empty string defaults to 0", BN.eq(BN.fromString(""), BN.zero()))

--------------------------------------------------------------------------------
print("=== formatting ===")

check("small int",    BN.format(BN.fromNumber(42)) == "42", BN.format(BN.fromNumber(42)))
check("thousands",    BN.format(BN.fromNumber(1500)) == "1.50K", BN.format(BN.fromNumber(1500)))
check("millions",     BN.format(BN.fromNumber(2.5e6)) == "2.50M", BN.format(BN.fromNumber(2.5e6)))
check("billions",     BN.format(BN.fromNumber(7.89e9)) == "7.89B", BN.format(BN.fromNumber(7.89e9)))
check("trillions",    BN.format(BN.fromNumber(1e12)) == "1.00T", BN.format(BN.fromNumber(1e12)))
check("aa tier",      BN.format(BN.new(1, 15)) == "1.00aa", BN.format(BN.new(1, 15)))
check("ab tier",      BN.format(BN.new(1, 18)) == "1.00ab", BN.format(BN.new(1, 18)))
check("negative fmt", BN.format(BN.fromNumber(-1500)) == "-1.50K", BN.format(BN.fromNumber(-1500)))
check("beyond suffix table falls back to sci",
	BN.format(BN.new(1, 500)):find("e") ~= nil, BN.format(BN.new(1, 500)))

local full = BN.format(BN.fromNumber(1234567), true)
check("fullNumbers separators", full == "1,234,567", full)

--------------------------------------------------------------------------------
print("=== operator metamethods ===")

check("__add", approx(BN.toNumber(x + y), 1.5e10))
check("__mul", approx(BN.toNumber(x * y), 5e19))
check("__lt",  y < x)
check("__le",  y <= x and x <= x)
check("__unm", BN.eq(-BN.fromNumber(5), BN.fromNumber(-5)))
check("__tostring", tostring(BN.fromNumber(1500)) == "1.50K", tostring(BN.fromNumber(1500)))

--------------------------------------------------------------------------------
print("=== simulated 6-hour progression ===")
-- Accumulate at an exponentially growing rate and confirm no precision
-- collapse, no NaN, and monotonic growth.

local balance = BN.zero()
local rate = BN.fromNumber(1)
local monotonic = true
local prev = BN.zero()

for tick = 1, 21600 do            -- 6 hours of 1-second ticks
	balance = BN.add(balance, rate)
	if tick % 600 == 0 then       -- every 10 min, upgrades multiply income
		rate = BN.mul(rate, BN.fromNumber(3.2))
	end
	if BN.lt(balance, prev) then monotonic = false end
	prev = balance
end

check("6h sim stays monotonic", monotonic)
check("6h sim produced no NaN", balance.m == balance.m and balance.e == balance.e)
check("6h sim reached expected magnitude", BN.log10(balance) > 18,
	"log10=" .. string.format("%.2f", BN.log10(balance)))
print("  final balance: " .. BN.format(balance) .. "  (" .. BN.toString(balance) .. ")")

-- Prestige on that balance, then verify the next run outpaces the last.
local earned = BN.pow(BN.div(balance, BN.fromNumber(1e5)), 0.55)
print("  cores from delve: " .. BN.format(earned))
check("delve yields positive cores", BN.gte(earned, BN.fromNumber(1)))

--------------------------------------------------------------------------------
print()
print(("=== %d passed, %d failed ==="):format(passed, failed))
for _, f in ipairs(failures) do print("  FAIL: " .. f) end
os.exit(failed == 0 and 0 or 1)
