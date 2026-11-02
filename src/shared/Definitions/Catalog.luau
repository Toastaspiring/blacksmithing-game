--!strict
-- Definitions/Catalog (SPEC §2.3; owner S1): builds the frozen catalogs every Definitions module returns from its
-- rows, and deep-freezes Definitions data. Pure.
--   ordered  all rows, ascending `order`: the list consumers iterate
--   enabled  enabled rows, ascending `order`
--   byId     lookup only, never iterated (pairs order differs between Lune and Roblox)
--   get      nil for unknown ids (and for anything that is not a string): the only way an untrusted string becomes
--            a typed id, with isEnabled
-- Catalog.build reads row.id / order / enabled and errors on a duplicate id or order or a malformed row: a bad
-- Definitions file is a bug that must stop the require. Validate checks the raw rows again (D1) so its own tests can
-- plant errors that build would refuse.

export type Catalog<Def> = {
	ordered: { Def },
	enabled: { Def },
	byId: { [string]: Def },
	get: (id: string) -> Def?,
	isEnabled: (id: string) -> boolean,
}

local Catalog = {}

-- Recursive table.freeze. Tables already frozen (shared or built elsewhere) are left as they are; a table met twice
-- is frozen once. Returns its argument.
function Catalog.deepFreeze<T>(t: T): T
	local seen: { [any]: boolean } = {}
	local function freeze(v: any)
		if type(v) ~= "table" or seen[v] then
			return
		end
		seen[v] = true
		for key, child in v do
			freeze(key)
			freeze(child)
		end
		if not table.isfrozen(v) then
			table.freeze(v)
		end
	end
	freeze(t)
	return t
end

function Catalog.build<Def>(rows: { Def }): Catalog<Def>
	if type(rows) ~= "table" then
		error("Catalog.build: rows must be an array of records, got " .. type(rows), 2)
	end
	local n = #rows
	local keys = 0
	for key in rows :: { [any]: any } do
		keys += 1
		if type(key) ~= "number" or key < 1 or key > n or key % 1 ~= 0 then
			error("Catalog.build: rows must be a plain array (found the key " .. tostring(key) .. ")", 2)
		end
	end
	if keys ~= n then
		error("Catalog.build: rows must be a plain array without holes", 2)
	end
	local list: { Def } = {}
	local idSeen: { [string]: number } = {}
	local orderSeen: { [number]: number } = {}
	for i = 1, n do
		local row: any = rows[i]
		if type(row) ~= "table" then
			error(string.format("Catalog.build: row %d is a %s, not a record", i, type(row)), 2)
		end
		local id, order, enabled = row.id, row.order, row.enabled
		if type(id) ~= "string" or id == "" then
			error(string.format("Catalog.build: row %d needs a non-empty string id", i), 2)
		end
		if type(order) ~= "number" or order ~= order or order == math.huge or order == -math.huge then
			error(string.format("Catalog.build: row %d (%s) needs a finite number order", i, id), 2)
		end
		if type(enabled) ~= "boolean" then
			error(string.format("Catalog.build: row %d (%s) needs a boolean enabled", i, id), 2)
		end
		if idSeen[id] then
			error(string.format("Catalog.build: duplicate id %s (rows %d and %d)", id, idSeen[id], i), 2)
		end
		if orderSeen[order] then
			error(string.format("Catalog.build: duplicate order %s (rows %d and %d)", tostring(order), orderSeen[order], i), 2)
		end
		idSeen[id] = i
		orderSeen[order] = i
		table.insert(list, row)
	end
	-- orders are unique, so this comparator is a total order and the result does not depend on the input order
	table.sort(list, function(a: Def, b: Def): boolean
		return (a :: any).order < (b :: any).order
	end)

	local enabledRows: { Def } = {}
	local byId: { [string]: Def } = {}
	for _, row in list do
		local r: any = row
		byId[r.id] = row
		if r.enabled then
			table.insert(enabledRows, row)
		end
	end
	Catalog.deepFreeze(list)
	table.freeze(enabledRows)
	table.freeze(byId)

	local function get(id: string): Def?
		if type(id) ~= "string" then
			return nil
		end
		return byId[id]
	end
	local function isEnabled(id: string): boolean
		local row: any = get(id)
		return row ~= nil and row.enabled == true
	end

	local catalog: Catalog<Def> = {
		ordered = list,
		enabled = enabledRows,
		byId = byId,
		get = get,
		isEnabled = isEnabled,
	}
	return table.freeze(catalog)
end

return table.freeze(Catalog)
