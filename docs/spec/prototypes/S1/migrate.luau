--!strict
-- S1 prototype: migration chain + ProfileStore Reconcile ordering trap.
-- ReconcileTable copied in behaviour from vendor/ProfileStore/ProfileStore.luau (lines 396-422).

local function deepCopy(t: any): any
	local c = {}
	for k, v in t do
		c[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return c
end
local function reconcile(target: any, template: any)
	for k, v in template do
		if type(k) == "string" then
			if target[k] == nil then
				target[k] = if type(v) == "table" then deepCopy(v) else v
			elseif type(target[k]) == "table" and type(v) == "table" then
				reconcile(target[k], v)
			end
		end
	end
end

local DATA_VERSION = 3
local TEMPLATE = { DataVersion = DATA_VERSION, Items = {}, Counters = { ItemsForged = 0, ItemsScrapped = 0 } }

-- Migrations[v] upgrades data from version v to v+1 (pure, in place, idempotent per step).
local Migrations: { [number]: (any) -> () } = {
	[1] = function(d) -- v1 -> v2: item field "Rarity" split into Rarity + RarityAtForge
		for _, item in d.Items do
			item.RarityAtForge = item.RarityAtForge or item.Rarity
		end
	end,
	[2] = function(d) -- v2 -> v3: rename counter Forged -> ItemsForged
		if d.Counters and d.Counters.Forged ~= nil then
			d.Counters.ItemsForged = d.Counters.Forged
			d.Counters.Forged = nil
		end
	end,
}

local function load(stored: any, reconcileFirst: boolean): (any, string)
	local d = deepCopy(stored)
	if reconcileFirst then
		reconcile(d, TEMPLATE)
	end
	local v = d.DataVersion or 1
	if v > DATA_VERSION then
		return d, "REFUSE: newer data (" .. v .. ") than server (" .. DATA_VERSION .. ")"
	end
	while v < DATA_VERSION do
		Migrations[v](d)
		v += 1
		d.DataVersion = v
	end
	if not reconcileFirst then
		reconcile(d, TEMPLATE)
	end
	return d, "ok"
end

-- a v1 profile written before DataVersion existed in the template
local v1 = { Items = { I1 = { Rarity = "Rare" } }, Counters = { Forged = 7 } }
local good, s1 = load(v1, false)
local bad, s2 = load(v1, true)
print("migrate-then-reconcile:", s1, "DataVersion", good.DataVersion, "RarityAtForge", good.Items.I1.RarityAtForge, "ItemsForged", good.Counters.ItemsForged)
print("reconcile-then-migrate:", s2, "DataVersion", bad.DataVersion, "RarityAtForge", bad.Items.I1.RarityAtForge, "ItemsForged", bad.Counters.ItemsForged)
local _, s3 = load({ DataVersion = 4 }, false)
print("future profile:", s3)
