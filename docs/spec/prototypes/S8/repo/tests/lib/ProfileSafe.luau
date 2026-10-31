--!strict
-- tests/lib/ProfileSafe.luau — checks that a value can live in ProfileStore's Profile.Data:
-- plain tables only (array 1..n without gaps, or string-keyed dictionary), finite numbers,
-- valid UTF-8 strings, no functions/userdata/metatables, bounded depth. PROTOTYPE (S8).

local ProfileSafe = {}

local MAX_DEPTH = 16

-- Returns nil when safe, else "<path>: <reason>".
function ProfileSafe.check(v: any, path: string?, depth: number?): string?
	local p = path or "Data"
	local d = depth or 0
	local tv = type(v)
	if tv == "boolean" then return nil end
	if tv == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return p .. ": non-finite number" end
		return nil
	end
	if tv == "string" then
		if utf8.len(v) == nil then return p .. ": invalid UTF-8" end
		return nil
	end
	if tv ~= "table" then return p .. ": unsupported type " .. tv end
	if getmetatable(v) ~= nil then return p .. ": has a metatable" end
	if d >= MAX_DEPTH then return p .. ": deeper than " .. MAX_DEPTH end
	local n = #v
	local count, stringKeys, numberKeys = 0, 0, 0
	for k in v do
		count += 1
		if type(k) == "string" then stringKeys += 1
		elseif type(k) == "number" then numberKeys += 1
		else return p .. ": key of type " .. type(k) end
	end
	if stringKeys > 0 and numberKeys > 0 then return p .. ": mixed table (string and number keys)" end
	if numberKeys > 0 and numberKeys ~= n then return p .. ": array with gaps or non-1..n keys" end
	for k, child in v do
		local sub = if type(k) == "number" then p .. "[" .. k .. "]" else p .. "." .. k
		local err = ProfileSafe.check(child, sub, d + 1)
		if err then return err end
	end
	local _ = count
	return nil
end

return ProfileSafe
