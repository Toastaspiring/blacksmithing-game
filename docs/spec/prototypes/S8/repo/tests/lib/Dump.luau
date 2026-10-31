--!strict
-- tests/lib/Dump.luau — canonical serialization (sorted keys, %.17g numbers) used for
-- failure messages, deep comparison paths and the balance fingerprint. PROTOTYPE (S8).

local Dump = {}

local function num(n: number): string
	if n ~= n then return "nan" end
	if n == math.huge then return "inf" end
	if n == -math.huge then return "-inf" end
	if n == 0 then return "0" end -- folds -0 into 0
	return string.format("%.17g", n)
end

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do table.insert(keys, k) end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" or ta == "string" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Canonical, deterministic text form. Errors on cycles, functions, userdata.
function Dump.canonical(v: any, depth: number?): string
	local d = depth or 0
	if d > 64 then error("Dump.canonical: depth > 64 (cycle?)") end
	local tv = type(v)
	if tv == "nil" then return "nil" end
	if tv == "boolean" then return if v then "true" else "false" end
	if tv == "number" then return num(v) end
	if tv == "string" then return string.format("%q", v) end
	if tv == "table" then
		local parts = {}
		for _, k in sortedKeys(v) do
			local ks = if type(k) == "string" then k else "[" .. Dump.canonical(k, d + 1) .. "]"
			table.insert(parts, ks .. "=" .. Dump.canonical(v[k], d + 1))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("Dump.canonical: unsupported type " .. tv)
end

function Dump.short(v: any): string
	local ok, s = pcall(Dump.canonical, v)
	local text = if ok then s else tostring(v)
	if #text > 200 then text = string.sub(text, 1, 200) .. "…" end
	return text
end

-- Returns nil when equal, else a path like "parts[3].size.y: 0.5 ~= 0.6".
function Dump.firstDifference(a: any, b: any, path: string?): string?
	local p = path or "$"
	if type(a) ~= type(b) then
		return p .. ": type " .. type(a) .. " ~= " .. type(b)
	end
	if type(a) ~= "table" then
		if a == b then return nil end
		if type(a) == "number" and a ~= a and b ~= b then return nil end -- NaN == NaN structurally
		return p .. ": " .. Dump.short(a) .. " ~= " .. Dump.short(b)
	end
	for k, va in a do
		local sub = if type(k) == "number" then p .. "[" .. k .. "]" else p .. "." .. tostring(k)
		local diff = Dump.firstDifference(va, b[k], sub)
		if diff then return diff end
	end
	for k in b do
		if a[k] == nil then
			local sub = if type(k) == "number" then p .. "[" .. k .. "]" else p .. "." .. tostring(k)
			return sub .. ": missing on actual side"
		end
	end
	return nil
end

-- FNV-1a 32-bit over a string, pure bit32 (used for the balance fingerprint).
function Dump.fnv1a32(s: string): number
	local h = 0x811C9DC5
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		-- h * 16777619 mod 2^32 without losing precision: split the multiplier.
		h = bit32.band(h * 0x193 + bit32.lshift(bit32.band(h, 0xFF), 24) * 1, 0xFFFFFFFF)
	end
	return h
end

return Dump
