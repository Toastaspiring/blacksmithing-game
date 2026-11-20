--!strict
-- Minigames/Checks (SPEC §6.2 "sample SD, windows", §6.4, §10.5, §10.6; owner S3): the statistics the families'
-- inhuman-input checks share, and the check rows and flag levels of Definitions/MinigameFamilies (no copies: S8 reads
-- the same rows). Pure.
--
--   mean(xs)                 the left-to-right sum over the array / n; 0 for none
--   sampleSd(xs)             sample SD (n − 1, §6.4 rule 7) in two passes: the mean, then Σ (x − mean)·(x − mean),
--                            as the S3 prototype's TimingStrike check computes it, bit for bit; n ≥ 2
--   maxInWindow(times, w)    the most entries in any [t_j, t_j + w), times non-decreasing (the prototype's two
--                            pointers; the largest count is reached in a window that starts at an entry)
--   value(family, name)      a `checks` threshold (§10.6)
--   level(family, flag)      a flag's level, "High" (the judge clamps the score, §10.5) or "Medium" (telemetry)
--   anyHigh(family, flags)   whether any of the flags is High
--   sorted(flags)            a new array in byte order (§10.5 "sorted by id")
--
-- Rows are found by name, and names are unique within a family (T-DEF-05), so the rows' order changes no result.

local MinigameFamilies = require("../Definitions/MinigameFamilies")
local DT = require("../Definitions/Types")
local Types = require("./Types")

type FlagId = Types.FlagId
type MinigameFamilyDef = MinigameFamilies.MinigameFamilyDef

local function familyDef(family: DT.FamilyId, fn: string): MinigameFamilyDef
	local def = MinigameFamilies.get(family)
	if def == nil then
		error(string.format("Checks.%s: no minigame family %s", fn, tostring(family)), 3)
	end
	return def
end

-- byte order (Luau compares strings bytewise): a strict total order on the distinct FlagIds
local function byteOrder(a: string, b: string): boolean
	return a < b
end

local Checks = {}

function Checks.mean(xs: { number }): number
	local n = #xs
	if n == 0 then
		return 0
	end
	local sum = 0
	for i = 1, n do
		sum += xs[i]
	end
	return sum / n
end

function Checks.sampleSd(xs: { number }): number
	local n = #xs
	if n < 2 then
		error(string.format("Checks.sampleSd: needs at least 2 values, got %d", n), 2)
	end
	local mean = Checks.mean(xs)
	local ss = 0
	for i = 1, n do
		ss += (xs[i] - mean) * (xs[i] - mean)
	end
	return math.sqrt(ss / (n - 1))
end

function Checks.maxInWindow(times: { number }, windowMs: number): number
	if not (windowMs > 0) then
		error(string.format("Checks.maxInWindow: windowMs must be positive, got %s", tostring(windowMs)), 2)
	end
	local most, j = 0, 1
	for i = 1, #times do
		while times[i] - times[j] >= windowMs do
			j += 1
		end
		most = math.max(most, i - j + 1)
	end
	return most
end

function Checks.value(family: DT.FamilyId, name: string): number
	for _, c in ipairs(familyDef(family, "value").checks) do
		if c.name == name then
			return c.value
		end
	end
	error(string.format("Checks.value: %s has no check %s", family, tostring(name)), 2)
end

function Checks.level(family: DT.FamilyId, flag: FlagId): "High" | "Medium"
	for _, f in ipairs(familyDef(family, "level").flagLevels) do
		if f.flag == flag then
			return f.level
		end
	end
	error(string.format("Checks.level: %s raises no flag %s", family, tostring(flag)), 2)
end

-- (indexed loops: luau-lsp widens an ipairs value of a string-literal union to string)
function Checks.anyHigh(family: DT.FamilyId, flags: { FlagId }): boolean
	for i = 1, #flags do
		if Checks.level(family, flags[i]) == "High" then
			return true
		end
	end
	return false
end

function Checks.sorted(flags: { FlagId }): { FlagId }
	local out: { FlagId } = {}
	for i = 1, #flags do
		out[i] = flags[i]
	end
	table.sort(out, byteOrder)
	return out
end

return table.freeze(Checks)
