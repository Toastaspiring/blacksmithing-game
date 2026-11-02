--!strict
-- tests/Definitions/DefsHelpers.luau — helpers shared by the Definitions specs (not a spec: the runner loads only
-- *.spec.luau). Pure Luau; the specs pass modules in, this file requires only tests/lib.
--   deepCopy          an unfrozen structural copy (functions kept by reference)
--   reshuffled        the same copy, but every table's keys inserted in a seeded random order (P-ORDER)
--   isDeepFrozen      every table reachable from v is frozen
--   jsonSafe          JSON-safe data: string-keyed maps or holeless arrays (never mixed), finite numbers, strings,
--                     booleans, no cycles or shared tables; functions only where allowFunctions says so
--   garbage           a hostile value for P-TOTAL (nil, NaN, ±inf, −0, huge strings, deep or cyclic tables, …)
--   ids, shuffle      small list helpers

local Dump = require("../lib/Dump")
local TestRng = require("../lib/TestRng")

local H = {}

function H.deepCopy<T>(v: T): T
	local seen: { [any]: any } = {}
	local function copy(x: any): any
		if type(x) ~= "table" then
			return x
		end
		if seen[x] then
			return seen[x]
		end
		local out = {}
		seen[x] = out
		for k, child in x do
			out[copy(k)] = copy(child)
		end
		return out
	end
	return copy(v)
end

-- Fisher–Yates on a copy.
function H.shuffle<T>(list: { T }, rng: TestRng.TestRng): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A deep copy whose tables receive their keys in a random order (array keys included), so hash-part layouts and
-- pairs order differ from the original while the data is equal.
function H.reshuffled<T>(v: T, rng: TestRng.TestRng): T
	local seen: { [any]: any } = {}
	local function copy(x: any): any
		if type(x) ~= "table" then
			return x
		end
		if seen[x] then
			return seen[x]
		end
		local keys = Dump.sortedKeys(x)
		keys = H.shuffle(keys, rng)
		local out = {}
		seen[x] = out
		for _, k in keys do
			out[k] = copy(x[k])
		end
		return out
	end
	return copy(v)
end

function H.isDeepFrozen(v: any): (boolean, string?)
	local seen: { [any]: boolean } = {}
	local function walk(x: any, path: string): string?
		if type(x) ~= "table" or seen[x] then
			return nil
		end
		seen[x] = true
		if not table.isfrozen(x) then
			return path
		end
		for _, k in Dump.sortedKeys(x) do
			local bad = walk(x[k], path .. "." .. tostring(k))
			if bad then
				return bad
			end
		end
		return nil
	end
	local bad = walk(v, "$")
	return bad == nil, bad
end

-- (true) or (false, path of the first violation). allowFunctions: functions are skipped (module APIs).
function H.jsonSafe(v: any, allowFunctions: boolean?): (boolean, string?)
	local seen: { [any]: boolean } = {}
	local function walk(x: any, path: string): string?
		local tx = type(x)
		if tx == "string" or tx == "boolean" then
			return nil
		elseif tx == "number" then
			if x ~= x or x == math.huge or x == -math.huge then
				return path .. " (non-finite number)"
			end
			return nil
		elseif tx == "function" then
			return if allowFunctions then nil else path .. " (function)"
		elseif tx ~= "table" then
			return path .. " (" .. tx .. ")"
		end
		if seen[x] then
			return path .. " (table shared or cyclic)"
		end
		seen[x] = true
		local n = #x
		local numeric, stringy, count = 0, 0, 0
		for k in x do
			count += 1
			if type(k) == "number" then
				if k < 1 or k > n or k % 1 ~= 0 then
					return path .. " (non-array number key " .. tostring(k) .. ")"
				end
				numeric += 1
			elseif type(k) == "string" then
				stringy += 1
			else
				return path .. " (" .. type(k) .. " key)"
			end
		end
		if numeric > 0 and stringy > 0 then
			return path .. " (mixed array and map)"
		end
		if numeric ~= n and stringy == 0 and count > 0 then
			return path .. " (array with holes)"
		end
		for _, k in Dump.sortedKeys(x) do
			local bad = walk(x[k], if type(k) == "number" then path .. "[" .. tostring(k) .. "]" else path .. "." .. k)
			if bad then
				return bad
			end
		end
		return nil
	end
	local bad = walk(v, "$")
	return bad == nil, bad
end

function H.ids(rows: { any }): { string }
	local out: { string } = {}
	for _, r in rows do
		table.insert(out, r.id)
	end
	return out
end

local GARBAGE_STRINGS = {
	"", "Iron", "iron", "IRON", " Iron", "Iron ", "Sword", "__index", "ordered", "byId", "get", "nil", "0", "NaN",
	"\0", "\255\254", "Ünïcødé", "<b>x</b>",
}

-- A hostile value: scalars of every kind, long strings, tables with odd keys, deep nesting and cycles.
function H.garbage(rng: TestRng.TestRng, depth: number?): any
	local d = depth or 0
	local pick = rng:int(1, if d >= 3 then 12 else 16)
	if pick == 1 then
		return nil
	elseif pick == 2 then
		return 0 / 0
	elseif pick == 3 then
		return math.huge
	elseif pick == 4 then
		return -math.huge
	elseif pick == 5 then
		return -0
	elseif pick == 6 then
		return rng:range(-1e9, 1e9)
	elseif pick == 7 then
		return rng:int(-3, 30)
	elseif pick == 8 then
		return rng:float() < 0.5
	elseif pick == 9 then
		return rng:pick(GARBAGE_STRINGS)
	elseif pick == 10 then
		return string.rep("x", rng:int(0, 5000))
	elseif pick == 11 then
		return function() end
	elseif pick == 12 then
		return {}
	elseif pick == 13 then
		local t = {}
		for i = 1, rng:int(1, 6) do
			t[i] = H.garbage(rng, d + 1)
		end
		return t
	elseif pick == 14 then
		local t: { [any]: any } = {}
		for _ = 1, rng:int(1, 6) do
			local k = H.garbage(rng, 3)
			if k ~= nil and k == k then
				t[k] = H.garbage(rng, d + 1)
			end
		end
		return t
	elseif pick == 15 then
		local t: { [any]: any } = { id = H.garbage(rng, 3), order = H.garbage(rng, 3), enabled = H.garbage(rng, 3) }
		t.self = t -- a cycle
		return t
	end
	local t: any = {}
	local cur = t
	for _ = 1, 150 do -- deeper than anything a definition holds
		cur.next = {}
		cur = cur.next
	end
	return t
end

return H
