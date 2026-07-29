--!strict
--[[
	BigNumber
	---------
	Mantissa + exponent arithmetic for values that exceed float64 integer
	precision (2^53 ≈ 9.007e15).

	WHY THIS EXISTS, AND WHY IT SHIPS ON DAY ONE:
	By mid-game this design produces Coin totals around 1e18-1e21. Lua numbers
	are float64: past 2^53 they silently lose integer precision, so a balance
	of 1e18 starts rounding in visible increments and players watch currency
	drift. Retrofitting this module after launch means migrating every saved
	profile from lossy floats to strings — you cannot recover the precision
	that was already lost. See docs/GAME_DESIGN.md section 15.

	REPRESENTATION
	  { m = mantissa, e = exponent }  where value = m * 10^e
	  Normalised so 1 <= |m| < 10, except zero which is exactly { m=0, e=0 }.

	SERIALISATION
	  Always stored in DataStores as a STRING ("1.234e18"), never a Lua number.

	Immutable: every operation returns a new table.
]]

local BigNumber = {}
BigNumber.__index = BigNumber

export type BigNumber = { m: number, e: number }

local MAX_SAFE_EXP = 308  -- float64 overflow guard

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

local function normalise(m: number, e: number): BigNumber
	if m == 0 or m ~= m then
		return setmetatable({ m = 0, e = 0 }, BigNumber) :: any
	end

	local sign = m < 0 and -1 or 1
	m = math.abs(m)

	-- Shift mantissa into [1, 10)
	local shift = math.floor(math.log(m, 10))
	m = m / (10 ^ shift)
	e = e + shift

	-- log10 rounding can land just outside the range; correct it.
	while m >= 10 do
		m = m / 10
		e = e + 1
	end
	while m < 1 and m > 0 do
		m = m * 10
		e = e - 1
	end

	return setmetatable({ m = sign * m, e = e }, BigNumber) :: any
end

function BigNumber.new(mantissa: number, exponent: number?): BigNumber
	return normalise(mantissa, exponent or 0)
end

function BigNumber.fromNumber(n: number): BigNumber
	return normalise(n, 0)
end

function BigNumber.zero(): BigNumber
	return setmetatable({ m = 0, e = 0 }, BigNumber) :: any
end

--------------------------------------------------------------------------------
-- SERIALISATION
--------------------------------------------------------------------------------

function BigNumber.toString(a: BigNumber): string
	if a.m == 0 then return "0" end
	return string.format("%.6fe%d", a.m, a.e)
end

function BigNumber.fromString(s: string): BigNumber
	if s == "0" or s == "" then return BigNumber.zero() end

	local mantissa, exponent = string.match(s, "^(-?[%d%.]+)e(-?%d+)$")
	if mantissa and exponent then
		return normalise(tonumber(mantissa) :: number, tonumber(exponent) :: number)
	end

	-- Plain numeric string fallback (legacy saves from before this module).
	local plain = tonumber(s)
	if plain then return normalise(plain, 0) end

	warn(("BigNumber.fromString: unparseable value %q, defaulting to 0"):format(s))
	return BigNumber.zero()
end

-- Only safe when the value is known small (UI widths, small counters).
function BigNumber.toNumber(a: BigNumber): number
	if a.e > MAX_SAFE_EXP then
		return a.m > 0 and math.huge or -math.huge
	end
	return a.m * (10 ^ a.e)
end

--------------------------------------------------------------------------------
-- ARITHMETIC
--------------------------------------------------------------------------------

function BigNumber.add(a: BigNumber, b: BigNumber): BigNumber
	if a.m == 0 then return normalise(b.m, b.e) end
	if b.m == 0 then return normalise(a.m, a.e) end

	local diff = a.e - b.e
	-- Beyond ~15 orders of magnitude the smaller term is below float
	-- precision; adding it is a no-op, so skip the work.
	if diff > 15 then return normalise(a.m, a.e) end
	if diff < -15 then return normalise(b.m, b.e) end

	if diff >= 0 then
		return normalise(a.m + b.m / (10 ^ diff), a.e)
	else
		return normalise(b.m + a.m / (10 ^ -diff), b.e)
	end
end

function BigNumber.sub(a: BigNumber, b: BigNumber): BigNumber
	return BigNumber.add(a, { m = -b.m, e = b.e } :: any)
end

function BigNumber.mul(a: BigNumber, b: BigNumber): BigNumber
	if a.m == 0 or b.m == 0 then return BigNumber.zero() end
	return normalise(a.m * b.m, a.e + b.e)
end

function BigNumber.div(a: BigNumber, b: BigNumber): BigNumber
	if b.m == 0 then
		warn("BigNumber.div: division by zero, returning 0")
		return BigNumber.zero()
	end
	if a.m == 0 then return BigNumber.zero() end
	return normalise(a.m / b.m, a.e - b.e)
end

-- Fractional exponents required: prestige uses ^0.55 and ^0.5.
function BigNumber.pow(a: BigNumber, exp: number): BigNumber
	if a.m == 0 then return BigNumber.zero() end
	if exp == 0 then return BigNumber.new(1) end

	-- (m * 10^e)^x = 10^(x * (log10(m) + e))
	local log10 = math.log(math.abs(a.m), 10) + a.e
	local result = log10 * exp
	local intPart = math.floor(result)
	return normalise(10 ^ (result - intPart), intPart)
end

function BigNumber.log10(a: BigNumber): number
	if a.m <= 0 then return -math.huge end
	return math.log(a.m, 10) + a.e
end

--------------------------------------------------------------------------------
-- COMPARISON
--------------------------------------------------------------------------------

function BigNumber.compare(a: BigNumber, b: BigNumber): number
	if a.m == 0 and b.m == 0 then return 0 end
	if a.m == 0 then return b.m > 0 and -1 or 1 end
	if b.m == 0 then return a.m > 0 and 1 or -1 end

	local aNeg, bNeg = a.m < 0, b.m < 0
	if aNeg ~= bNeg then return aNeg and -1 or 1 end

	local flip = aNeg and -1 or 1
	if a.e ~= b.e then
		return (a.e > b.e and 1 or -1) * flip
	end
	if math.abs(a.m - b.m) < 1e-12 then return 0 end
	return (a.m > b.m and 1 or -1) * flip
end

function BigNumber.gte(a: BigNumber, b: BigNumber): boolean
	return BigNumber.compare(a, b) >= 0
end

function BigNumber.lt(a: BigNumber, b: BigNumber): boolean
	return BigNumber.compare(a, b) < 0
end

function BigNumber.eq(a: BigNumber, b: BigNumber): boolean
	return BigNumber.compare(a, b) == 0
end

function BigNumber.max(a: BigNumber, b: BigNumber): BigNumber
	return BigNumber.gte(a, b) and a or b
end

function BigNumber.min(a: BigNumber, b: BigNumber): BigNumber
	return BigNumber.lt(a, b) and a or b
end

--------------------------------------------------------------------------------
-- DISPLAY
--------------------------------------------------------------------------------

local SUFFIXES = {
	"", "K", "M", "B", "T",
	"aa","ab","ac","ad","ae","af","ag","ah","ai","aj","ak","al","am",
	"an","ao","ap","aq","ar","as","at","au","av","aw","ax","ay","az",
	"ba","bb","bc","bd","be","bf","bg","bh","bi","bj","bk","bl","bm",
}

--[[
	format(value, fullNumbers?)
	Standard K/M/B/T then aa/ab/ac. `fullNumbers` honours the accessibility
	toggle from the UI spec (design doc section 12).
]]
function BigNumber.format(a: BigNumber, fullNumbers: boolean?): string
	if a.m == 0 then return "0" end

	local neg = a.m < 0
	local mag = math.abs(a.m)
	local exp = a.e

	if fullNumbers then
		if exp > 20 then
			return (neg and "-" or "") .. string.format("%.3fe%d", mag, exp)
		end
		local full = mag * (10 ^ exp)
		local s = string.format("%.0f", full)
		-- Thousands separators, applied right-to-left.
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return (neg and "-" or "") .. out
	end

	if exp < 3 then
		local v = mag * (10 ^ exp)
		local s = (v % 1 == 0) and string.format("%d", v) or string.format("%.2f", v)
		return (neg and "-" or "") .. s
	end

	local tier = math.floor(exp / 3)
	local suffix = SUFFIXES[tier + 1]
	if not suffix then
		return (neg and "-" or "") .. string.format("%.3fe%d", mag, exp)
	end

	local display = mag * (10 ^ (exp % 3))
	return (neg and "-" or "") .. string.format("%.2f%s", display, suffix)
end

--------------------------------------------------------------------------------
-- OPERATOR METAMETHODS
--------------------------------------------------------------------------------

BigNumber.__add = BigNumber.add
BigNumber.__sub = BigNumber.sub
BigNumber.__mul = BigNumber.mul
BigNumber.__div = BigNumber.div
BigNumber.__pow = BigNumber.pow
BigNumber.__eq  = function(a, b) return BigNumber.compare(a, b) == 0 end
BigNumber.__lt  = function(a, b) return BigNumber.compare(a, b) < 0 end
BigNumber.__le  = function(a, b) return BigNumber.compare(a, b) <= 0 end
BigNumber.__tostring = function(a) return BigNumber.format(a) end
BigNumber.__unm = function(a) return normalise(-a.m, a.e) end

return BigNumber
