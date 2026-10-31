--!strict
-- tests/lib/Dump.luau — canonical text of a value (SPEC §14.3): sorted keys, %.17g numbers, −0 → 0. The text is a
-- single-line Luau expression, so a golden can be read back with `return <text>`. Also failure messages, deep
-- comparison paths, byte-wise string order and FNV-1a 32. Pure Luau, no requires.

local Dump = {}

local KEYWORDS = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true,
	["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
	["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true,
	["true"] = true, ["until"] = true, ["while"] = true,
}

-- Byte-wise string order (independent of locale), shorter prefix first.
function Dump.byteLess(a: string, b: string): boolean
	local n = math.min(#a, #b)
	for i = 1, n do
		local x, y = string.byte(a, i), string.byte(b, i)
		if x ~= y then
			return x < y
		end
	end
	return #a < #b
end

local function num(n: number): string
	if n ~= n then
		return "0/0"
	elseif n == math.huge then
		return "math.huge"
	elseif n == -math.huge then
		return "-math.huge"
	elseif n == 0 then
		return "0" -- folds −0 into 0
	end
	return string.format("%.17g", n)
end

-- Quoted string on one line: \\ \" \n \r \t, other control bytes as \ddd, bytes >= 0x80 kept (UTF-8).
local function quote(s: string): string
	local out = string.gsub(s, '[%c"\\]', function(ch: string): string
		if ch == "\\" then
			return "\\\\"
		elseif ch == '"' then
			return '\\"'
		elseif ch == "\n" then
			return "\\n"
		elseif ch == "\r" then
			return "\\r"
		elseif ch == "\t" then
			return "\\t"
		end
		return string.format("\\%03d", string.byte(ch))
	end)
	return '"' .. out .. '"'
end
Dump.quote = quote

local TYPE_RANK = { boolean = 1, number = 2, string = 3 }

local function keyLess(a: any, b: any): boolean
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return (TYPE_RANK[ta] or 9) < (TYPE_RANK[tb] or 9)
	end
	if ta == "string" then
		return Dump.byteLess(a, b)
	elseif ta == "number" then
		return a < b
	elseif ta == "boolean" then
		return (not a) and b
	end
	return false
end

function Dump.sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		local tk = type(k)
		if tk ~= "string" and tk ~= "number" and tk ~= "boolean" then
			error("Dump: unsupported key type " .. tk)
		end
		table.insert(keys, k)
	end
	table.sort(keys, keyLess)
	return keys
end

local function keyText(k: any): string
	if type(k) == "string" then
		if string.match(k, "^[%a_][%w_]*$") and not KEYWORDS[k] then
			return k
		end
		return "[" .. quote(k) .. "]"
	elseif type(k) == "number" then
		return "[" .. num(k) .. "]"
	end
	return "[" .. tostring(k) .. "]"
end

local function canonical(v: any, visiting: { [any]: boolean }, depth: number): string
	local tv = type(v)
	if tv == "nil" then
		return "nil"
	elseif tv == "boolean" then
		return if v then "true" else "false"
	elseif tv == "number" then
		return num(v)
	elseif tv == "string" then
		return quote(v)
	elseif tv == "table" then
		if visiting[v] then
			error("Dump.canonical: cycle")
		end
		if depth > 200 then
			error("Dump.canonical: deeper than 200")
		end
		visiting[v] = true
		local parts = {}
		for _, k in Dump.sortedKeys(v) do
			table.insert(parts, keyText(k) .. "=" .. canonical(v[k], visiting, depth + 1))
		end
		visiting[v] = nil
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("Dump.canonical: unsupported type " .. tv)
end

-- Canonical, deterministic text form. Errors on cycles and on functions, userdata, threads and buffers.
function Dump.canonical(v: any): string
	return canonical(v, {}, 0)
end

-- For messages: canonical form cut at 200 characters, or tostring when the value cannot be dumped.
function Dump.short(v: any): string
	local ok, s = pcall(Dump.canonical, v)
	local text = if ok then s else tostring(v)
	if #text > 200 then
		text = string.sub(text, 1, 200) .. "..."
	end
	return text
end

local function child(path: string, k: any): string
	if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
		return path .. "." .. k
	end
	return path .. "[" .. (if type(k) == "string" then quote(k) else tostring(k)) .. "]"
end

-- nil when structurally equal (numbers exactly, except −0 == 0 and NaN == NaN), else the first differing path in
-- sorted-key order, e.g. "$.parts[3].size: 0.5 ~= 0.6".
function Dump.firstDifference(a: any, b: any, path: string?): string?
	local p = path or "$"
	if type(a) ~= type(b) then
		return p .. ": type " .. type(a) .. " ~= " .. type(b)
	end
	if type(a) ~= "table" then
		if a == b then
			return nil
		end
		if type(a) == "number" and a ~= a and b ~= b then
			return nil
		end
		return p .. ": " .. Dump.short(a) .. " ~= " .. Dump.short(b)
	end
	if a == b then
		return nil
	end
	for _, k in Dump.sortedKeys(a) do
		if b[k] == nil then
			return child(p, k) .. ": missing on the expected side"
		end
		local diff = Dump.firstDifference(a[k], b[k], child(p, k))
		if diff then
			return diff
		end
	end
	for _, k in Dump.sortedKeys(b) do
		if a[k] == nil then
			return child(p, k) .. ": missing on the actual side"
		end
	end
	return nil
end

-- FNV-1a 32-bit over the bytes of s. The multiply by 16777619 = 2^24 + 403 is split so every intermediate stays
-- below 2^53 and bit32 reduces it exactly.
function Dump.fnv1a32(s: string): number
	local h = 0x811C9DC5
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = bit32.band(h * 403 + bit32.lshift(bit32.band(h, 0xFF), 24), 0xFFFFFFFF)
	end
	return h
end

return Dump
