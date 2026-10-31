--!strict
-- Throwaway S7 prototype v2: ShowcaseRules on S1's draft shape Smithy.Displays = { [SlotKey]: ItemId },
-- SlotKey = "D1".."Dn", absent key = empty stand. Run: lune run showcase_rules_dict.luau
local R = {}
export type Code = "Ok" | "NoChange" | "BadSlot" | "SlotLocked" | "BadItem" | "NotOwned"
local MAX_ID_LEN = 64

function R.key(i: number): string
	return "D" .. tostring(i)
end
local function validIndex(i: any, layoutMax: number): boolean
	return type(i) == "number" and i == math.floor(i) and i >= 1 and i <= layoutMax
end

function R.place(d: { [string]: string }, layoutMax: number, unlocked: number, i: any, itemId: any, owns: (string) -> boolean): (Code, { number })
	if not validIndex(i, layoutMax) then return "BadSlot", {} end
	if i > unlocked then return "SlotLocked", {} end
	if type(itemId) ~= "string" or #itemId == 0 or #itemId > MAX_ID_LEN then return "BadItem", {} end
	if not owns(itemId) then return "NotOwned", {} end
	if d[R.key(i)] == itemId then return "NoChange", {} end
	local changed = { i }
	for j = 1, layoutMax do
		if j ~= i and d[R.key(j)] == itemId then
			d[R.key(j)] = nil
			table.insert(changed, j)
		end
	end
	d[R.key(i)] = itemId
	return "Ok", changed
end

function R.clear(d: { [string]: string }, layoutMax: number, unlocked: number, i: any): (Code, { number })
	if not validIndex(i, layoutMax) then return "BadSlot", {} end
	if i > unlocked then return "SlotLocked", {} end
	if d[R.key(i)] == nil then return "NoChange", {} end
	d[R.key(i)] = nil
	return "Ok", { i }
end

function R.sanitize(d: { [string]: any }, layoutMax: number, unlocked: number, owns: (string) -> boolean): { string }
	local removed = {}
	-- unknown keys first (deterministic order: sorted)
	local keys = {}
	for k in d do table.insert(keys, k) end
	table.sort(keys)
	local valid: { [string]: number } = {}
	for i = 1, layoutMax do valid[R.key(i)] = i end
	for _, k in keys do
		if valid[k] == nil then d[k] = nil; table.insert(removed, k) end
	end
	local seen: { [string]: boolean } = {}
	for i = 1, layoutMax do
		local k = R.key(i)
		local id = d[k]
		if id ~= nil then
			if type(id) ~= "string" or i > unlocked or seen[id] or not owns(id) then
				d[k] = nil
				table.insert(removed, k)
			else
				seen[id] = true
			end
		end
	end
	return removed
end

-- tests
local inv = { I1 = true, I2 = true, I3 = true }
local function owns(id: string): boolean return inv[id] == true end
local fails = 0
local function check(name: string, cond: boolean)
	if not cond then fails += 1 end
	print((cond and "PASS " or "FAIL ") .. name)
end
local d: { [string]: string } = {}
check("place I1 on 1", (R.place(d, 6, 6, 1, "I1", owns)) == "Ok" and d.D1 == "I1")
local c, ch = R.place(d, 6, 6, 4, "I1", owns)
check("move I1 1->4 (changed 4,1)", c == "Ok" and d.D1 == nil and d.D4 == "I1" and #ch == 2)
check("NoChange", (R.place(d, 6, 6, 4, "I1", owns)) == "NoChange")
check("BadSlot 0 / 7 / 1.5 / '1'", (R.place(d, 6, 6, 0, "I2", owns)) == "BadSlot" and (R.place(d, 6, 6, 7, "I2", owns)) == "BadSlot" and (R.place(d, 6, 6, 1.5, "I2", owns)) == "BadSlot" and (R.place(d, 6, 6, "1", "I2", owns)) == "BadSlot")
check("SlotLocked", (R.place(d, 12, 6, 7, "I2", owns)) == "SlotLocked")
check("NotOwned", (R.place(d, 6, 6, 2, "I9", owns)) == "NotOwned")
check("BadItem number", (R.place(d, 6, 6, 2, 5, owns)) == "BadItem")
check("swap I2 onto 4", (R.place(d, 6, 6, 4, "I2", owns)) == "Ok" and d.D4 == "I2")
check("clear 4", (R.clear(d, 6, 6, 4)) == "Ok" and d.D4 == nil)
check("clear empty NoChange", (R.clear(d, 6, 6, 4)) == "NoChange")
local bad: { [string]: any } = { D1 = "I1", D2 = "I1", D3 = "ghost", D4 = 42, D5 = "I3", D6 = "I2", D9 = "I2", X = "I1" }
local removed = R.sanitize(bad, 6, 5, owns)
table.sort(removed)
check("sanitize -> removed " .. table.concat(removed, ","), bad.D1 == "I1" and bad.D2 == nil and bad.D3 == nil and bad.D4 == nil and bad.D5 == "I3" and bad.D6 == nil and bad.D9 == nil and bad.X == nil)
print(("%d failures"):format(fails))
