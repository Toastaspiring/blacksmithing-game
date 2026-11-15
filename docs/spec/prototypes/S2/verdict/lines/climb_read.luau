--!nocheck
-- Try wider: a climb on what the verdict reads against the truth, on a core plate under cover parts. Scores: false Enclosed (read under 2 %, true share as high as it goes), false kept (read 2 % or more, true
-- share as low as it goes). Cover parts are lids on the faces, edges free or snapped to the core's reading grid. args: mode(E|K) seed evals out [w h t]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local Sets = require("./b_sets")
local fmt = string.format
local I = V.I
local T = V.T

local mode = process.args[1] or "E"
local seed = tonumber(process.args[2]) or 1
local EVALS = tonumber(process.args[3]) or 2000
local OUT = process.args[4] or ("out/climb_" .. mode .. seed .. ".json")
local W, H_, TH = tonumber(process.args[5]) or 1.0, tonumber(process.args[6]) or 2.0, tonumber(process.args[7]) or 0.02
local R = Sets.rng(seed * 104729 + (if mode == "E" then 3 else 5))
local MAXLIDS = 20
local LID_T = 0.03

local Force = V.Force
local Geo = require("./tree/src/shared/Definitions/Balance").Geometry

-- the core's reading grid
local function gridOf()
	local P = V.Shapes.prepare(V.part("Core", "Block", "Blade", { 0, 2.5, 0 }, I, { W, H_, TH }), 1)
	local h = V.Sampling.ladder(Geo.H_SURF, function(s)
		local a, b, c = math.ceil(W / s), math.ceil(H_ / s), math.ceil(TH / s)
		return 2 * (a * b + b * c + a * c) <= Geo.VERDICT_SAMPLES
	end)
	return math.ceil(W / h), math.ceil(H_ / h)
end
local NA, NB = gridOf()

local SNAP = { -1, -0.98, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 0.98, 1 }
local function snapX()
	local c = R.int(0, NA - 1)
	local hw = W / NA / 2
	return -W / 2 + (2 * c + 1) * hw + hw * SNAP[R.int(1, #SNAP)] + (if R.u() < 0.5 then 0 else R.pick({ -0.01, -0.003, -0.0005, 0.0005, 0.003, 0.01 }))
end
local function snapY()
	local c = R.int(0, NB - 1)
	local hw = H_ / NB / 2
	return 2.5 - H_ / 2 + (2 * c + 1) * hw + hw * SNAP[R.int(1, #SNAP)] + (if R.u() < 0.5 then 0 else R.pick({ -0.01, -0.003, -0.0005, 0.0005, 0.003, 0.01 }))
end

-- a design: lids { x0, x1, y0, y1, side }; far past the rims they stop at the core's edge
local function build(lids)
	local parts = { V.part("Core", "Block", "Blade", { 0, 2.5, 0 }, I, { W, H_, TH }) }
	-- walls over the rims
	local thick = TH + 2 * LID_T
	table.insert(parts, V.part("Wall", "Block", "Blade", { W / 2 + 0.02, 2.5, 0 }, I, { 0.04, H_ + 0.08, thick }))
	table.insert(parts, V.part("Wall", "Block", "Blade", { -W / 2 - 0.02, 2.5, 0 }, I, { 0.04, H_ + 0.08, thick }))
	table.insert(parts, V.part("Wall", "Block", "Blade", { 0, 2.5 + H_ / 2 + 0.02, 0 }, I, { W, 0.04, thick }))
	table.insert(parts, V.part("Wall", "Block", "Blade", { 0, 2.5 - H_ / 2 - 0.02, 0 }, I, { W, 0.04, thick }))
	for _, l in ipairs(lids) do
		local x0, x1 = math.max(l[1], -W / 2), math.min(l[2], W / 2)
		local y0, y1 = math.max(l[3], 2.5 - H_ / 2), math.min(l[4], 2.5 + H_ / 2)
		if x1 - x0 >= 0.02 and y1 - y0 >= 0.02 then
			table.insert(parts, V.part("Lid", "Block", "Guard", { (x0 + x1) / 2, (y0 + y1) / 2, l[5] * (TH / 2 + LID_T / 2) }, I, { x1 - x0, y1 - y0, LID_T }))
		end
	end
	return V.renumber(parts)
end

local function evaluate(lids)
	local parts = build(lids)
	if #parts > 24 then return nil end
	local real, read = V.reads(parts)
	local S = T.solids(parts)
	local hider = T.hidersOf(S)
	local s = T.share(S, 1, hider, 0.001)
	return read[1], s, real.kept[1]
end

local function scoreOf(read, s)
	if mode == "E" then
		-- read below 2 % with the most showing; else how close the reading comes down
		if read < 0.02 then return s end
		return -read
	end
	if read >= 0.02 then return 1 - s end -- kept with the least showing
	return read - 1
end

local function start()
	-- both faces striped or tiled, with slits
	local lids = {}
	local cols = R.int(2, 5)
	local cuts = { -W / 2 - 0.1 }
	for c = 1, cols - 1 do
		local x = snapX()
		table.insert(cuts, x)
		table.insert(cuts, x + R.pick({ 0.0001, 0.001, 0.01, 0.02, 0.05 }))
	end
	table.sort(cuts)
	table.insert(cuts, W / 2 + 0.1)
	for i = 1, #cuts, 2 do
		table.insert(lids, { cuts[i], cuts[i + 1], 2.5 - H_ / 2 - 0.1, 2.5 + H_ / 2 + 0.1, 1 })
	end
	table.insert(lids, { -W / 2 - 0.1, W / 2 + 0.1, 2.5 - H_ / 2 - 0.1, 2.5 + H_ / 2 + 0.1, -1 })
	return lids
end

local function mutate(lids)
	local q = {}
	for i, l in ipairs(lids) do q[i] = table.clone(l) end
	for _ = 1, R.int(1, 3) do
		local u = R.u()
		if u < 0.5 and #q > 0 then
			local l = q[R.int(1, #q)]
			local k = R.int(1, 4)
			if k <= 2 then
				l[k] = if R.u() < 0.6 then snapX() else l[k] + R.range(-0.05, 0.05)
			else
				l[k] = if R.u() < 0.6 then snapY() else l[k] + R.range(-0.05, 0.05)
			end
		elseif u < 0.7 and #q < MAXLIDS then
			-- split a lid
			local l = q[R.int(1, #q)]
			local c = table.clone(l)
			if R.u() < 0.5 then
				local x = snapX()
				l[2] = x
				c[1] = x + R.pick({ 0.00001, 0.001, 0.01, 0.03, 0.06 })
			else
				local y = snapY()
				l[4] = y
				c[3] = y + R.pick({ 0.00001, 0.001, 0.01, 0.03, 0.06 })
			end
			table.insert(q, c)
		elseif u < 0.8 and #q > 1 then
			table.remove(q, R.int(1, #q))
		elseif #q > 0 then
			local l = q[R.int(1, #q)]
			local dx, dy = R.range(-0.03, 0.03), R.range(-0.03, 0.03)
			l[1] += dx
			l[2] += dx
			l[3] += dy
			l[4] += dy
		end
	end
	return q
end

local best, bestRow = -math.huge, nil
local evals = 0
while evals < EVALS do
	local lids = start()
	local read, s = evaluate(lids)
	if read then
		local score = scoreOf(read, s)
		local stale = 0
		while stale < 120 and evals < EVALS do
			local q = mutate(lids)
			local r2, s2 = evaluate(q)
			evals += 1
			if r2 then
				local sc = scoreOf(r2, s2)
				if sc >= score then
					if sc > score then stale = 0 else stale += 1 end
					lids, score, read, s = q, sc, r2, s2
				else
					stale += 1
				end
			else
				stale += 1
			end
		end
		if score > best then
			best = score
			bestRow = { score = score, read = read, share = s, lids = lids }
			print(fmt("%s seed %d evals %d: read %.2f %% true %.2f %% lids %d", mode, seed, evals, read * 100, s * 100, #lids))
			fs.writeFile(OUT, serde.encode("json", bestRow))
		end
	end
end
print(fmt("%s seed %d done: read %.2f %% true %.2f %%", mode, seed, bestRow.read * 100, bestRow.share * 100))
