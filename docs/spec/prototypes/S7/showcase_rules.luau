--!strict
-- Throwaway S7 prototype of the pure ShowcaseRules (place / clear / sanitize) + default item naming.
-- Run: lune run showcase_rules.luau
local R = {}

export type Code = "Ok" | "NoChange" | "BadSlot" | "SlotLocked" | "BadItem" | "NotOwned"

-- revision: no id length constant; the wire Guard checks the GUID format (S5), an unknown id is NotOwned

local function validSlot(slots: { string }, slotIndex: any): boolean
	return type(slotIndex) == "number" and slotIndex == math.floor(slotIndex) and slotIndex >= 1 and slotIndex <= #slots
end

-- slots: fixed-length array ("" = empty), mutated in place. unlocked: how many leading slots are usable.
function R.place(slots: { string }, unlocked: number, slotIndex: any, itemId: any, owns: (string) -> boolean): (Code, { number })
	if not validSlot(slots, slotIndex) then
		return "BadSlot", {}
	end
	if slotIndex > unlocked then
		return "SlotLocked", {}
	end
	if type(itemId) ~= "string" or #itemId == 0 then
		return "BadItem", {}
	end
	if not owns(itemId) then
		return "NotOwned", {}
	end
	if slots[slotIndex] == itemId then
		return "NoChange", {}
	end
	local changed = { slotIndex }
	for j = 1, #slots do
		if j ~= slotIndex and slots[j] == itemId then
			slots[j] = "" -- an item is on at most one stand: placing it elsewhere moves it
			table.insert(changed, j)
		end
	end
	slots[slotIndex] = itemId -- the previous occupant (if any) simply leaves the stand; it stays in the inventory
	return "Ok", changed
end

function R.clear(slots: { string }, unlocked: number, slotIndex: any): (Code, { number })
	if not validSlot(slots, slotIndex) then
		return "BadSlot", {}
	end
	if slotIndex > unlocked then
		return "SlotLocked", {}
	end
	if slots[slotIndex] == "" then
		return "NoChange", {}
	end
	slots[slotIndex] = ""
	return "Ok", { slotIndex }
end

-- repairs length, unknown/unowned ids, duplicates (lowest index wins), locked slots. Returns changed indices.
function R.sanitize(slots: { string }, length: number, unlocked: number, owns: (string) -> boolean): { number }
	local changed = {}
	for i = #slots + 1, length do
		slots[i] = ""
	end
	for i = #slots, length + 1, -1 do
		table.remove(slots, i)
	end
	local seen: { [string]: boolean } = {}
	for i = 1, length do
		local id = slots[i]
		if type(id) ~= "string" then
			slots[i] = ""
			table.insert(changed, i)
		elseif id ~= "" then
			if i > unlocked or seen[id] or not owns(id) then
				slots[i] = ""
				table.insert(changed, i)
			else
				seen[id] = true
			end
		end
	end
	return changed
end

-- default display name: "<blade material(s)> <type>" (revision R1-41: no per-owner serial)
function R.defaultName(parts: { { slot: string, material: string } }, typeName: string, materialOrder: { string }): string
	local present: { [string]: boolean } = {}
	for _, p in parts do
		if p.slot == "Blade" then
			present[p.material] = true
		end
	end
	local mats = {}
	for _, m in materialOrder do
		if present[m] then
			table.insert(mats, m)
		end
	end
	local phrase = #mats == 0 and "" or (table.concat(mats, "-") .. " ")
	return phrase .. typeName
end

-- ------------------------------------------------------------------ tests
local inv = { a = true, b = true, c = true }
local function owns(id: string): boolean
	return inv[id] == true
end
local function show(t: { any }): string
	local o = {}
	for _, v in t do
		table.insert(o, v == "" and "_" or tostring(v))
	end
	return "{" .. table.concat(o, ",") .. "}"
end
local fails = 0
local function check(name: string, cond: boolean)
	if not cond then
		fails += 1
	end
	print((cond and "PASS " or "FAIL ") .. name)
end

local s = { "", "", "", "", "", "" }
local c, ch = R.place(s, 6, 1, "a", owns)
check("place a on 1 -> Ok " .. show(s), c == "Ok" and s[1] == "a" and #ch == 1)
c, ch = R.place(s, 6, 3, "a", owns)
check("place a on 3 moves it " .. show(s) .. " changed " .. show(ch), c == "Ok" and s[1] == "" and s[3] == "a" and #ch == 2)
c = R.place(s, 6, 3, "a", owns)
check("same again -> NoChange", c == "NoChange")
c = R.place(s, 6, 7, "b", owns)
check("slot 7 -> BadSlot", c == "BadSlot")
c = R.place(s, 6, 2.5, "b", owns)
check("slot 2.5 -> BadSlot", c == "BadSlot")
c = R.place(s, 4, 5, "b", owns)
check("slot 5 with 4 unlocked -> SlotLocked", c == "SlotLocked")
c = R.place(s, 6, 2, "zzz", owns)
check("unowned -> NotOwned", c == "NotOwned")
c = R.place(s, 6, 2, (42 :: any), owns)
check("non-string id -> BadItem", c == "BadItem")
c = R.place(s, 6, 2, "", owns)
check("empty id -> BadItem", c == "BadItem")
c = R.place(s, 6, 2, string.rep("x", 65), owns)
check("65-char unknown id -> NotOwned", c == "NotOwned")
c, ch = R.place(s, 6, 3, "b", owns)
check("swap b onto 3 (a leaves the stand) " .. show(s), c == "Ok" and s[3] == "b" and #ch == 1)
c = R.clear(s, 6, 3)
check("clear 3 -> Ok " .. show(s), c == "Ok" and s[3] == "")
c = R.clear(s, 6, 3)
check("clear empty -> NoChange", c == "NoChange")
local bad: { any } = { "a", "a", "ghost", 42, "c", "b", "b", "x" }
local chg = R.sanitize(bad :: { string }, 6, 5, owns)
check("sanitize " .. show(bad) .. " changed " .. show(chg), #bad == 6 and bad[1] == "a" and bad[2] == "" and bad[3] == "" and bad[4] == "" and bad[5] == "c" and bad[6] == "")
local short = { "a" }
R.sanitize(short, 6, 6, owns)
check("sanitize pads to length " .. show(short), #short == 6)
local parts = { { slot = "Blade", material = "Steel" }, { slot = "Blade", material = "Iron" }, { slot = "Grip", material = "Iron" } }
check("name mixed -> " .. R.defaultName(parts, "Sword", { "Iron", "Steel" }), R.defaultName(parts, "Sword", { "Iron", "Steel" }) == "Iron-Steel Sword")
check("name steel -> " .. R.defaultName({ { slot = "Blade", material = "Steel" } }, "Sword", { "Iron", "Steel" }), R.defaultName({ { slot = "Blade", material = "Steel" } }, "Sword", { "Iron", "Steel" }) == "Steel Sword")
print(("%d failures"):format(fails))
