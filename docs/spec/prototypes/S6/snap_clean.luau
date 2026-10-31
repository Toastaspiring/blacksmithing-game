--!strict
-- S6 revise prototype: snapped-value cleaning for ANY positive finite step (R4a-01 removes the 0.001 floor).
-- Variants: clean9 (draft: floor(v*1e9+0.5)/1e9), clean12rel (%.12g), cleanAbs12 (round(v*1e12)/1e12, used only
-- when the step >= SNAP_CLEAN_MIN_STEP = 1e-9; smaller steps keep the raw product).
-- Checks: (a) snapped deltas n*s equal the typed literal; (b) x0 + delta equals the typed literal of the exact sum;
-- (c) tiny steps; (d) the |delta/s| guard; (e) max change on arbitrary values.  Run: lune run snap_clean.luau

local SNAP_CLEAN_MIN_STEP = 1e-9

local function clean9(v: number, _s: number): number
	if math.abs(v) >= 1e6 then
		return v
	end
	return math.floor(v * 1e9 + 0.5) / 1e9
end

local function clean12rel(v: number, _s: number): number
	return tonumber(string.format("%.12g", v)) :: number
end

local function cleanAbs12(v: number, s: number): number
	if s < SNAP_CLEAN_MIN_STEP or math.abs(v) >= 1e3 then
		return v
	end
	return math.round(v * 1e12) / 1e12
end

local function parseDec(s: string): (number, number)
	local neg = string.sub(s, 1, 1) == "-"
	if neg then
		s = string.sub(s, 2)
	end
	local ip, fp = string.match(s, "^(%d+)%.?(%d*)$")
	assert(ip, "bad literal " .. s)
	local m = tonumber(ip .. (fp or "")) :: number
	return (neg and -m or m), -#(fp or "")
end

local function decToString(m: number, e: number): string
	local neg = m < 0
	local digits = string.format("%d", math.abs(m))
	if e < 0 then
		local k = -e
		if #digits <= k then
			digits = string.rep("0", k - #digits + 1) .. digits
		end
		digits = string.sub(digits, 1, #digits - k) .. "." .. string.sub(digits, #digits - k + 1)
	end
	return (neg and "-" or "") .. digits
end

local function literal(m: number, e: number): number
	return tonumber(decToString(m, e)) :: number
end

local function snapDelta(clean: (number, number) -> number, delta: number, s: number): number
	local r = delta / s
	if s ~= s or s <= 0 or s == math.huge or math.abs(r) > 1e12 then
		return delta -- free
	end
	return clean(math.round(r) * s, s)
end

local steps = { "0.1", "0.05", "0.25", "0.01", "0.001", "0.125", "0.2", "0.3", "0.0003", "0.0001", "0.00001",
	"0.0000001", "0.000000001", "0.0000000001", "15", "22.5", "7.5", "1", "0.5", "0.07", "0.333" }
local starts = { "0", "0.3", "0.1", "2.35", "-0.15", "4.9999", "-16", "0.0001", "1.2345", "15.95", "-0.8" }

local variants = { { "clean9", clean9 }, { "clean12rel", clean12rel }, { "cleanAbs12", cleanAbs12 } }
for _, v in variants do
	local name, clean = v[1], v[2]
	local nD, badD, nS, badS = 0, 0, 0, 0
	local badSteps = {}
	for _, sl in steps do
		local sm, se = parseDec(sl)
		local s = literal(sm, se)
		local below = s < SNAP_CLEAN_MIN_STEP
		local stepBad = 0
		for n = -400, 400 do
			local delta = (n + 0.3) * s
			local got = snapDelta(clean, delta, s)
			if not below then
				nD += 1
				if got ~= literal(n * sm, se) then
					badD += 1
					stepBad += 1
				end
			end
			for _, x0l in starts do
				local xm, xe = parseDec(x0l)
				local e = math.min(xe, se)
				local sumM = xm * 10 ^ (xe - e) + n * sm * 10 ^ (se - e)
				local wantSum = literal(sumM, e)
				local x0 = literal(xm, xe)
				if not below then
					nS += 1
					if clean(x0 + got, s) ~= wantSum then
						badS += 1
						stepBad += 1
					end
				end
			end
		end
		if stepBad > 0 then
			table.insert(badSteps, sl)
		end
	end
	print(string.format("%-11s steps >= 1e-9: delta mismatches %d / %d, sum mismatches %d / %d  (steps with errors: %s)",
		name, badD, nD, badS, nS, table.concat(badSteps, " ")))
end

print(string.format("tiny step 1e-10, delta 3.7e-10 -> cleanAbs12 keeps the raw product %.17g (clean9 gives %.17g)",
	snapDelta(cleanAbs12, 3.7e-10, 1e-10), snapDelta(clean9, 3.7e-10, 1e-10)))
print(string.format("guard: step 5e-324, delta 0.5 -> %.17g (treated as free, no inf)", snapDelta(cleanAbs12, 0.5, 5e-324)))

local maxAbs = 0
for i = 1, 200000 do
	local x = (i * 0.6180339887498949) % 1 * 32 - 16
	local d = math.abs(cleanAbs12(x, 0.05) - x)
	if d > maxAbs then
		maxAbs = d
	end
end
print(string.format("cleanAbs12 max absolute change over 200k values in [-16, 16]: %.3g stud", maxAbs))
