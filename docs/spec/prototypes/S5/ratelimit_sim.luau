--!strict
-- Token-bucket table check (Lune 0.8.9): lune run ratelimit_sim.luau
-- Revised catalogue: + Craft.ReportDesync, Showcase.TeleportHome; Get actions are batched (<= 12 ids per call).
local RL = require("./lib/RateLimit")

local SPECS: { { name: string, capacity: number, refillPerSec: number } } = {
	{ name = "Profile.Hello", capacity = 2, refillPerSec = 1 / 30 },
	{ name = "Profile.Sync", capacity = 3, refillPerSec = 1 / 10 },
	{ name = "Profile.SetSettings", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Blueprint.Get", capacity = 10, refillPerSec = 2 },
	{ name = "Blueprint.Save", capacity = 4, refillPerSec = 1 / 3 },
	{ name = "Blueprint.Rename", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Blueprint.Delete", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Craft.Begin", capacity = 3, refillPerSec = 1 / 10 },
	{ name = "Craft.StartStep", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Craft.Submit", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Craft.Abandon", capacity = 3, refillPerSec = 1 / 5 },
	{ name = "Craft.Resume", capacity = 3, refillPerSec = 1 / 5 },
	{ name = "Craft.ReportDesync", capacity = 3, refillPerSec = 1 / 10 },
	{ name = "Showcase.Place", capacity = 6, refillPerSec = 1 },
	{ name = "Showcase.Clear", capacity = 6, refillPerSec = 1 },
	{ name = "Showcase.Scrap", capacity = 5, refillPerSec = 1 / 2 },
	{ name = "Showcase.Inspect", capacity = 10, refillPerSec = 3 },
	{ name = "Showcase.GetItems", capacity = 10, refillPerSec = 2 },
	{ name = "Showcase.TeleportHome", capacity = 1, refillPerSec = 1 / 3 },
	{ name = "(global, all channels)", capacity = 30, refillPerSec = 15 },
}

print("flood at 500 req/s for 60 s (Roblox per-client remote ceiling ~500/s):")
for _, s in SPECS do
	local b = RL.newBucket({ capacity = s.capacity, refillPerSec = s.refillPerSec }, 0)
	local accepted = 0
	for i = 0, 60 * 500 - 1 do
		if RL.take(b, i * 2) then
			accepted += 1
		end
	end
	print(string.format("  %-24s cap %2d  refill %5.2f/s  -> accepted %4d / 30000 (%.2f/s)", s.name, s.capacity, s.refillPerSec, accepted, accepted / 60))
end

local function trace(name: string, spec, timesMs: { number })
	local b = RL.newBucket(spec, 0)
	local ok = 0
	for _, t in timesMs do
		if RL.take(b, t) then
			ok += 1
		end
	end
	print(string.format("  %-56s %d / %d accepted", name, ok, #timesMs))
end
local function every(periodMs: number, count: number, offset: number?): { number }
	local r = {}
	for i = 0, count - 1 do
		r[i + 1] = (offset or 0) + i * periodMs
	end
	return r
end

print("legit traces:")
local begins, starts, submits = {}, {}, {}
local t = 0
for _ = 1, 5 do
	table.insert(begins, t)
	for _ = 1, 3 do
		t += 1000
		table.insert(starts, t)
		t += 3000 + 8000 + 100
		table.insert(submits, t)
	end
	t += 2000
end
trace("Craft.Begin, 5 back-to-back crafts (8 s steps)", { capacity = 3, refillPerSec = 1 / 10 }, begins)
trace("Craft.StartStep, same (+1 desync re-open per step)", { capacity = 5, refillPerSec = 1 / 2 }, (function()
	local r = {}
	for _, s in starts do
		table.insert(r, s)
		table.insert(r, s + 150)
	end
	return r
end)())
trace("Craft.Submit, same", { capacity = 5, refillPerSec = 1 / 2 }, submits)
trace("Blueprint.Save, Ctrl+S mashed 6x in 2 s", { capacity = 4, refillPerSec = 1 / 3 }, { 0, 400, 800, 1200, 1600, 2000 })
local saves = every(60000, 30) -- autosave every 60 s for 30 min ...
for _, x in every(10000, 180, 5000) do -- ... plus a manual save every 10 s
	table.insert(saves, x)
end
table.sort(saves)
trace("Blueprint.Save, autosave 60 s + manual every 10 s, 30 min", { capacity = 4, refillPerSec = 1 / 3 }, saves)
trace("Showcase.Inspect, browsing 30 stands in 15 s", { capacity = 10, refillPerSec = 3 }, every(500, 30))
trace("Showcase.GetItems, 150-item grid, 13 calls of 12 ids in 4 s", { capacity = 10, refillPerSec = 2 }, every(300, 13))
trace("Showcase.Place, rearranging 6 slots in 3 s", { capacity = 6, refillPerSec = 1 }, every(500, 6))
trace("Showcase.TeleportHome, one click every 3 s for 1 min", { capacity = 1, refillPerSec = 1 / 3 }, every(3000, 20))
