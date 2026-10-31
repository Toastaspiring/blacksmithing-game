--!strict
-- Prototype of src/shared/Net/Guard.luau (pure). Validators for untrusted remote payloads.
-- Contract: a validator NEVER throws, whatever the input (any Luau value a remote can carry),
-- and walks at most `budget.nodes` values (bounds CPU on hostile payloads).
-- A validator returns nil when the value is acceptable, or a short error string ("path: reason").

export type Budget = { nodes: number }
export type Validator = (v: any, path: string, budget: Budget) -> string?

local Guard = {}

local function spend(budget: Budget, path: string): string?
	budget.nodes -= 1
	if budget.nodes < 0 then
		return path .. ": payload too large"
	end
	return nil
end

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Guard.int(min: number, max: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if not isFiniteNumber(v) or v % 1 ~= 0 then
			return path .. ": expected integer"
		end
		if v < min or v > max then
			return path .. ": out of range"
		end
		return nil
	end
end

function Guard.num(min: number, max: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if not isFiniteNumber(v) then
			return path .. ": expected finite number"
		end
		if v < min or v > max then
			return path .. ": out of range"
		end
		return nil
	end
end

function Guard.bool(): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "boolean" then
			return path .. ": expected boolean"
		end
		return nil
	end
end

-- UTF-8 string with byte and code-point caps; rejects C0 control characters and DEL.
function Guard.str(maxBytes: number, maxChars: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "string" then
			return path .. ": expected string"
		end
		if #v > maxBytes then
			return path .. ": too long"
		end
		local n = utf8.len(v)
		if n == nil then
			return path .. ": invalid utf8"
		end
		if n > maxChars then
			return path .. ": too long"
		end
		if string.find(v, "[%c\127]") then
			return path .. ": control character"
		end
		return nil
	end
end

local GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

function Guard.guid(): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "string" or #v ~= 36 or not string.find(v, GUID_PATTERN) then
			return path .. ": expected guid"
		end
		return nil
	end
end

function Guard.enum(values: { string }): Validator
	local set: { [string]: boolean } = {}
	for _, s in values do
		set[s] = true
	end
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "string" or set[v] ~= true then
			return path .. ": unknown value"
		end
		return nil
	end
end

function Guard.opt(inner: Validator): Validator
	return function(v, path, budget)
		if v == nil then
			return nil
		end
		return inner(v, path, budget)
	end
end

-- Dense array 1..n (n <= maxLen) with no other keys; every element checked by `inner`.
function Guard.arr(inner: Validator, maxLen: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "table" then
			return path .. ": expected array"
		end
		local n = rawlen(v)
		if n > maxLen then
			return path .. ": too many elements"
		end
		local count = 0
		for k in next, v do
			count += 1
			if count > n or type(k) ~= "number" then
				return path .. ": not a dense array"
			end
		end
		for i = 1, n do
			local err = inner(rawget(v, i), path .. "[" .. i .. "]", budget)
			if err then return err end
		end
		return nil
	end
end

-- Fast path for flat integer arrays (minigame input timelines): one budget unit per 16 values.
function Guard.intArr(maxLen: number, min: number, max: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "table" then
			return path .. ": expected integer array"
		end
		local n = rawlen(v)
		if n > maxLen then
			return path .. ": too many elements"
		end
		budget.nodes -= n // 16
		if budget.nodes < 0 then
			return path .. ": payload too large"
		end
		local count = 0
		for k in next, v do
			count += 1
			if count > n or type(k) ~= "number" then
				return path .. ": not a dense array"
			end
		end
		for i = 1, n do
			local x = rawget(v, i)
			if not isFiniteNumber(x) or x % 1 ~= 0 or x < min or x > max then
				return path .. "[" .. i .. "]: bad integer"
			end
		end
		return nil
	end
end

-- Binary payload (S3 minigame timeline): O(1) type + length check; structure is S3's Timeline.decode.
function Guard.buffer(maxBytes: number): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "buffer" then
			return path .. ": expected buffer"
		end
		if buffer.len(v) > maxBytes then
			return path .. ": buffer too large"
		end
		return nil
	end
end

-- Client keys never reach logs raw (R3-16): identifier-like keys <= 32 B are kept, anything else is "<key>".
local function safeKey(k: any): string
	if type(k) == "number" then
		return if k == k and k % 1 == 0 and math.abs(k) < 1e9 then "[" .. string.format("%d", k) .. "]" else "[<num>]"
	end
	if type(k) == "string" and #k <= 32 and string.find(k, "^[%a_][%w_%.]*$") then
		return "." .. k
	end
	return ".<key>"
end
Guard._safeKey = safeKey

-- Dictionary with a fixed key set. Unknown keys are rejected (strict protocol).
function Guard.rec(fields: { [string]: Validator }): Validator
	return function(v, path, budget)
		local e = spend(budget, path)
		if e then return e end
		if type(v) ~= "table" then
			return path .. ": expected record"
		end
		for k in next, v do
			if type(k) ~= "string" or fields[k] == nil then
				return path .. ": unexpected key"
			end
		end
		for name, check in fields do
			local err = check(rawget(v, name), path .. "." .. name, budget)
			if err then return err end
		end
		return nil
	end
end

-- Bounded plain data (used for payloads whose field-level schema belongs to another module, e.g. the
-- blueprint draft that S1's Sanitize.fromWire checks): nil, boolean, finite number, string <= 256 bytes
-- of valid UTF-8, or a table of those with string / integer keys, nested at most `maxDepth` tables deep.
-- Rejects userdata (Instances, Vector3...), functions, threads, buffers, NaN and +-inf.
function Guard.plain(maxDepth: number): Validator
	local function walk(v: any, path: string, budget: Budget, depth: number): string?
		local e = spend(budget, path)
		if e then return e end
		local t = type(v)
		if t == "nil" or t == "boolean" then
			return nil
		elseif t == "number" then
			if not isFiniteNumber(v) then
				return path .. ": non-finite number"
			end
			return nil
		elseif t == "string" then
			if #v > 256 or utf8.len(v) == nil then
				return path .. ": bad string"
			end
			return nil
		elseif t == "table" then
			if depth >= maxDepth then
				return path .. ": too deep"
			end
			for k, x in next, v do
				local kt = type(k)
				if kt == "number" then
					if not isFiniteNumber(k) or k % 1 ~= 0 then
						return path .. ": bad key"
					end
				elseif kt ~= "string" or #k > 64 then
					return path .. ": bad key"
				end
				local err = walk(x, path .. safeKey(k), budget, depth + 1)
				if err then return err end
			end
			return nil
		end
		return path .. ": unsupported type " .. t
	end
	return function(v, path, budget)
		return walk(v, path, budget, 0)
	end
end

function Guard.check(validator: Validator, value: any, maxNodes: number): (boolean, string?)
	local budget = { nodes = maxNodes }
	local err = validator(value, "args", budget)
	return err == nil, err
end

return Guard
