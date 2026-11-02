--!strict
-- Definitions/Presentation (SPEC §13.6–§13.10, §16.15, E-S7.4, E-S7.6; T-DEF-01/03/05/06): the §16.15 constants,
-- the render orientations, rarity FX, workpieces, heat, viewports and the station stage. The orientations are
-- checked as rotations with the axis images §13.7 names, and E-S7.4's viewport distances and anvil fit are
-- re-derived from VIEWPORT_FOV, VIEWPORT_MARGIN and the matrices.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local DT = require("../../src/shared/Definitions/Types")
local Presentation = require("../../src/shared/Definitions/Presentation")
local Rarities = require("../../src/shared/Definitions/Rarities")
local World = require("../../src/shared/Definitions/World")

type Vec3 = { number }

-- E-S7.4's arming sword: bounds (−0.55, 0.15, −0.15) → (0.55, 4.30, 0.15) in blueprint space
local ARMING_HALF = { 0.55, (4.30 - 0.15) / 2, 0.15 }

local function column(m: { number }, j: number): Vec3
	return { m[j], m[3 + j], m[6 + j] }
end

local function det3(m: { number }): number
	return m[1] * (m[5] * m[9] - m[6] * m[8]) - m[2] * (m[4] * m[9] - m[6] * m[7]) + m[3] * (m[4] * m[8] - m[5] * m[7])
end

-- half extents of a box with half sizes h after the rotation m: e_i = Σ_j |m_ij|·h_j
local function extents(m: { number }, h: Vec3): Vec3
	local e: Vec3 = {}
	for i = 0, 2 do
		e[i + 1] = math.abs(m[3 * i + 1]) * h[1] + math.abs(m[3 * i + 2]) * h[2] + math.abs(m[3 * i + 3]) * h[3]
	end
	return e
end

local function station(id: string): World.StationDef
	for _, s in World.STATIONS do
		if s.id == id then
			return s
		end
	end
	return A.fail("no station " .. id)
end

local function worldRow(component: string, name: string): World.PartRow
	for _, r in World.BUILD_LIST do
		if r.component == component and r.name == name then
			return r
		end
	end
	return A.fail("no part " .. component .. "." .. name)
end

local function walkData(v: any, path: string, seen: { [any]: string })
	if type(v) == "number" then
		A.finite(v, path)
	elseif type(v) == "table" then
		if seen[v] then
			A.fail(path .. " shares a table with " .. seen[v])
		end
		seen[v] = path
		A.truthy(table.isfrozen(v), path .. " is frozen")
		local n = #v
		for k, child in v do
			if type(k) == "number" then
				A.truthy(k % 1 == 0 and k >= 1 and k <= n, path .. ": array keys are dense")
			else
				A.eq(type(k), "string", path .. ": keys are strings or array indices")
			end
			walkData(child, path .. "." .. tostring(k), seen)
		end
	elseif type(v) ~= "string" and type(v) ~= "boolean" then
		A.fail(path .. " holds a " .. type(v))
	end
end

return Test.suite("Definitions/Presentation", function(t)
	t.it("§16.15 constants", function()
		local expected: { [string]: any } = {
			DISPLAY_SCALE = 1.0,
			VIEWPORT_FOV = 30,
			VIEWPORT_MARGIN = 1.08,
			HEAT_COLOR = { 255, 96, 32 },
			HEAT_BLEND = 0.85,
			HEAT_NEON_THRESHOLD = 0.55,
			HEAT_LIGHT_BRIGHTNESS = 2.5,
			HEAT_LIGHT_RANGE = 8,
			WORKPIECE_HEAT = { Smelting = 0.9, Hammering = 0.7, Sharpening = 0 },
			INGOT_SIZE = { 0.5, 0.25, 1.0 },
			PLACEHOLDER_SIZE = 0.8,
			INSPECT_TURNTABLE_SPEED = 24,
			INSPECT_AUTOCLOSE_DISTANCE = 16,
			CAM_ENTER_S = 0.8,
			CAM_MOVE_S = 0.9,
			CAM_EXIT_S = 0.6,
			WALK_TIMEOUT_S = 1.4,
			ARRIVE_TOLERANCE = 0.75,
			ANVIL_SPARK_INTERVAL = 0.7,
			ANVIL_SPARK_COUNT = 12,
			GRINDSTONE_SPIN = 270,
			GRINDSTONE_SPARK_RATE = 30,
		}
		local presentation = Presentation :: any
		for _, name in Dump.sortedKeys(expected) do
			A.deepEq(presentation[name], expected[name], name)
		end
		for _, name in Dump.sortedKeys(presentation) do
			A.truthy(string.match(name, "^%u[%u%d_]*$") ~= nil, name .. " is UPPER_SNAKE")
		end
	end)

	t.it("T-DEF-05 orientations are rotations with §13.7's axis images", function()
		local O = Presentation.ORIENTATIONS
		local expected: { [string]: { Vec3 } } = { -- where blueprint +X, +Y, +Z point
			STAND = { { -1, 0, 0 }, { 0, 1, 0 }, { 0, 0, -1 } }, -- stand −X / up / −Z (toward the viewer)
			FLAT = { { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 } }, -- station +Z / +X / up
			VIEW_H = { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } }, -- down / right / toward the camera
			VIEW_V = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, -- right / up / toward the camera
		}
		A.deepEq(Dump.sortedKeys(O), { "FLAT", "STAND", "VIEW_H", "VIEW_V" }, "the four presets")
		for _, name in Dump.sortedKeys(expected) do
			local m = (O :: any)[name] :: { number }
			A.eq(#m, 9, name .. " has R00..R22")
			A.eq(det3(m), 1, name .. " is a proper rotation (det +1)")
			for j = 1, 3 do
				A.deepEq(column(m, j), expected[name][j], name .. " axis " .. j)
				for k = 1, 3 do
					local a, b = column(m, j), column(m, k)
					A.eq(a[1] * b[1] + a[2] * b[2] + a[3] * b[3], if j == k then 1 else 0, name .. " orthonormal")
				end
			end
		end
		-- a stand shows the +Z face to the plaza: plot-local −Z faces the plaza and stands are not yawed (E-S7.4)
		A.eq(World.STAND_YAW, 0, "stands face the plaza")
		A.deepEq(column(O.STAND, 3), { 0, 0, -1 }, "blueprint +Z faces the plaza (dot 1)")
		A.deepEq(Presentation.STAND_PRESET, { orientation = "STAND", anchor = "BaseCenter" }, "stands")
		A.deepEq(Presentation.VIEWPORT_PRESET, { orientation = "VIEW_H", anchor = "Center" }, "viewports")
	end)

	t.it("T-DEF-05 viewport fit = E-S7.4 (4.85 / 6.42 / 8.51 studs, |NDC| 1/1.08)", function()
		local m = Presentation.ORIENTATIONS.VIEW_H
		local e = extents(m, ARMING_HALF) -- on screen: x right, y up, z depth
		local tanHalf = math.tan(math.rad(Presentation.VIEWPORT_FOV / 2))
		local function fit(aspect: number): number
			return e[3] + Presentation.VIEWPORT_MARGIN * math.max(e[1] / (aspect * tanHalf), e[2] / tanHalf)
		end
		A.near(fit(16 / 9), 4.85, 0.005, "16:9 results card")
		A.near(fit(4 / 3), 6.42, 0.005, "4:3 inspect")
		A.near(fit(1), 8.51, 0.005, "1:1 tile")
		A.near(1 / Presentation.VIEWPORT_MARGIN, 0.926, 0.0005, "projected corners reach |NDC| 0.926")
		A.deepEq(Presentation.VIEWPORT_LIGHTING, {
			ambient = { 110, 100, 92 },
			lightColor = { 255, 240, 220 },
			lightDirection = { -1, -1, -0.6 },
		}, "viewport lighting")
	end)

	t.it("T-DEF-01 rarity FX: one row per rarity in Rarities order (E-S7.6)", function()
		A.eq(#Presentation.RARITY_FX, #Rarities.ordered, "a row per rarity")
		for i, fx in Presentation.RARITY_FX do
			local rarity = Rarities.ordered[i]
			A.eq(fx.rarity, rarity.id, "row " .. i)
			A.eq(fx.bandMaterial, if rarity.id == "Common" then "Slate" else "Neon", fx.rarity .. " band")
			A.eq(fx.light ~= nil, rarity.order >= 3, fx.rarity .. ": a RarityLight from Rare up")
			A.eq(fx.sparkles ~= nil, rarity.order >= 4, fx.rarity .. ": RaritySparkles from Epic up")
			A.eq(fx.highlight ~= nil, rarity.order >= 5, fx.rarity .. ": a Highlight from Legendary up")
			A.truthy(fx.highlight == nil or not rarity.enabled, fx.rarity .. ": Highlights are data only in the MVP")
		end
		local fx = Presentation.RARITY_FX
		local expected: { { any } } = { -- light, sparkles, highlight per row of E-S7.6 (Common and Uncommon: none)
			{ nil, nil, nil },
			{ nil, nil, nil },
			{ { range = 6, brightness = 0.8 }, nil, nil },
			{ { range = 7, brightness = 1.1 }, { rate = 3, lifetime = { 0.8, 1.4 } }, nil },
			{ { range = 8, brightness = 1.3 }, { rate = 5, lifetime = { 0.9, 1.5 } }, { outlineTransparency = 0.4 } },
			{ { range = 9, brightness = 1.5 }, { rate = 7, lifetime = { 1.0, 1.6 } }, { outlineTransparency = 0.3 } },
			{
				{ range = 10, brightness = 1.8 },
				{ rate = 9, lifetime = { 1.0, 1.8 } },
				{ outlineTransparency = 0.2, fillTransparency = 0.85 },
			},
		}
		for i, row in fx do
			local got: { any } = { row.light, row.sparkles, row.highlight }
			A.deepEq(got, expected[i], row.rarity .. " FX")
		end
		-- each rarity shows more than the one below
		for i = 4, #fx do
			local lo, hi = fx[i - 1].light :: any, fx[i].light :: any
			A.truthy(hi.range > lo.range and hi.brightness > lo.brightness, fx[i].rarity .. "'s light outshines")
		end
		for i = 5, #fx do
			local lo, hi = fx[i - 1].sparkles :: any, fx[i].sparkles :: any
			A.truthy(hi.rate > lo.rate, fx[i].rarity .. " sparkles more")
		end
		for i = 4, #fx do
			local s = fx[i].sparkles :: any
			A.truthy(s.lifetime[1] < s.lifetime[2], fx[i].rarity .. " lifetime range")
		end
		A.deepEq(Presentation.RARITY_LIGHT, { shadows = false }, "RarityLight")
		A.deepEq(Presentation.RARITY_SPARKLES, {
			shape = "Box",
			shapeStyle = "Volume",
			size = { 0.12, 0 },
			speed = { 0.1, 0.3 },
			drag = 2,
			lightEmission = 1,
			lightInfluence = 0,
			transparency = { 0.2, 1 },
		}, "RaritySparkles")
		A.deepEq(Presentation.RARITY_HIGHLIGHT, { depthMode = "Occluded" }, "Highlight")
	end)

	t.it("T-DEF-03 workpieces and heat: one per plan step, at its station's work point (E-S7.6)", function()
		local steps = CraftPlans.Sword.steps
		A.eq(#Presentation.WORKPIECES, #steps, "a workpiece per step")
		local lastHeat = math.huge
		for i, wp in Presentation.WORKPIECES do
			A.eq(wp.step, steps[i].step, "plan order")
			A.eq(wp.station, World.STEP_STATION[wp.step], wp.step .. " at its station")
			local heat = Presentation.WORKPIECE_HEAT[wp.step]
			A.truthy(heat ~= nil and heat >= 0 and heat <= 1, wp.step .. " heat in [0, 1]")
			A.truthy(heat <= lastHeat, wp.step .. ": cooling as the craft goes on")
			lastHeat = heat
		end
		A.deepEq(Dump.sortedKeys(Presentation.WORKPIECE_HEAT), { "Hammering", "Sharpening", "Smelting" }, "heat keys")
		local threshold = Presentation.HEAT_NEON_THRESHOLD
		local hammer: DT.StepId, grind: DT.StepId = "Hammering", "Sharpening"
		A.truthy(Presentation.WORKPIECE_HEAT[hammer] >= threshold, "the anvil workpiece glows Neon")
		A.truthy(Presentation.WORKPIECE_HEAT[grind] < threshold, "the ground blade is cold")
		local smelting, hammering, sharpening = Presentation.WORKPIECES[1], Presentation.WORKPIECES[2],
			Presentation.WORKPIECES[3]
		-- Smelting: ingots at the crucible, side by side without overlapping
		A.eq(smelting.model, "Ingots", "Smelting shows ingots")
		A.deepEq(smelting.pivot, station("Furnace").work, "ingots at the furnace work point")
		A.truthy(2 * (smelting.ingotOffsetX :: number) >= Presentation.INGOT_SIZE[1], "two ingots do not overlap")
		-- Hammering: the item lies FLAT on the anvil face (top y 3.0); E-S7.4: the arming sword's Center pivot sits at
		-- 3.0 + 0.15 and the blade overhangs the 2.4-stud face by 1.75
		A.eq(hammering.model, "Item", "anvil item")
		A.eq(hammering.orientation, "FLAT", "anvil item orientation")
		A.eq(hammering.anchor, "Center", "anvil item anchor")
		A.deepEq(hammering.pivot, station("Anvil").work, "the anvil work point")
		local face = worldRow("Anvil", "Face")
		A.near(face.pos[2] + face.size[2] / 2, hammering.pivot[2], 1e-12, "the pivot base is the face top")
		local flat = extents(Presentation.ORIENTATIONS.FLAT, ARMING_HALF) -- station x, y (up), z
		A.near(hammering.pivot[2] + flat[2], 3.15, 1e-12, "Center pivot y on the anvil")
		A.near(2 * flat[1] - face.size[1], 1.75, 1e-12, "overhang past the face")
		-- Sharpening: the blade's +X edge sits edgeClearance in front of the wheel rim (the grindstone work point)
		A.eq(sharpening.model, "Item", "grind item")
		A.eq(sharpening.orientation, "FLAT", "grind item orientation")
		A.eq(sharpening.anchor, "Center", "grind item anchor")
		local wheel = worldRow("Grindstone", "Wheel")
		A.near(sharpening.pivot[3], -wheel.size[3] / 2, 1e-12, "the pivot base is the wheel rim")
		local work = station("Grindstone").work
		A.near(sharpening.pivot[2], work[2], 1e-12, "at the wheel's height")
		A.near(sharpening.pivot[3] - (sharpening.edgeClearance :: number), work[3], 1e-12, "the edge at the work point")
		-- heat: colour, blend and light
		A.truthy(Presentation.HEAT_BLEND > 0 and Presentation.HEAT_BLEND <= 1, "HEAT_BLEND")
		A.truthy(threshold > 0 and threshold < 1, "HEAT_NEON_THRESHOLD")
		A.truthy(Presentation.HEAT_LIGHT_RANGE <= World.PLOT_SIZE / 2, "the glow stays on the station")
	end)

	t.it("T-DEF-05 station activity raises the lit plot's values (E-S7.6 over E-S7.1)", function()
		local active, glow = Presentation.STATION_ACTIVITY, World.FORGE_GLOW
		A.deepEq(active, {
			Furnace = { fireSize = 8, fireHeat = 14, lightBrightness = 4.5, emberRate = 24 },
			DraftingTable = { candleBrightness = 1.2 },
		}, "STATION_ACTIVITY")
		-- keyed by the StationId the plot's StationActivity attribute holds (§13.4), so the lookup needs no mapping
		for _, id in Dump.sortedKeys(active :: any) do
			A.truthy(station(id) ~= nil, "STATION_ACTIVITY." .. id .. " is a World.STATIONS id")
		end
		A.truthy(active.Furnace.fireSize > glow.fire.size, "Fire Size 5 → 8")
		A.truthy(active.Furnace.fireHeat > glow.fire.heat, "Heat 9 → 14")
		A.truthy(active.Furnace.lightBrightness > glow.light.brightness, "light 3 → 4.5")
		A.truthy(active.Furnace.emberRate > glow.embers.rate, "embers 8 → 24")
		A.truthy(active.DraftingTable.candleBrightness > World.LIGHTS.candle.brightness, "candle 0.9 → 1.2")
		A.truthy(Presentation.GRINDSTONE_SPARK_RATE > World.SPARKS.rate, "sparks only while active")
		A.truthy(Presentation.ANVIL_SPARK_COUNT >= 1 and Presentation.ANVIL_SPARK_COUNT % 1 == 0, "a burst")
	end)

	t.it("T-DEF-05 station stage timings (E-S7.6)", function()
		-- the move covers the ≈ 0.6 s walk between stations at WalkSpeed 16 (E-S7.2: 9.1 and 9.4 studs)
		local function walkS(a: string, b: string): number
			local sa, sb = station(a), station(b)
			local pa = { sa.root[1] + sa.stand[1], sa.root[3] + sa.stand[3] }
			local pb = { sb.root[1] + sb.stand[1], sb.root[3] + sb.stand[3] }
			return math.sqrt((pa[1] - pb[1]) * (pa[1] - pb[1]) + (pa[2] - pb[2]) * (pa[2] - pb[2])) / 16
		end
		for _, pair in { { "Furnace", "Anvil" }, { "Anvil", "Grindstone" } } do
			local s = walkS(pair[1], pair[2])
			A.within(s, 0.5, 0.6, pair[1] .. " → " .. pair[2] .. " walk")
			A.truthy(Presentation.CAM_MOVE_S >= s, "the camera move covers the walk")
		end
		A.truthy(Presentation.WALK_TIMEOUT_S > Presentation.CAM_MOVE_S, "the walk times out after the move")
		A.truthy(Presentation.ARRIVE_TOLERANCE > 0, "ARRIVE_TOLERANCE")
		A.deepEq(Presentation.CAM_EASING, { style = "Sine", direction = "InOut", exitDirection = "Out" }, "easing")
		A.deepEq(Presentation.CAM_EXIT_OFFSET, { 0, 2.5, 9 }, "exit camera offset")
		A.deepEq(Presentation.CAM_EXIT_LOOK_OFFSET, { 0, 1.5, 0 }, "exit look offset")
		A.truthy(Presentation.INSPECT_AUTOCLOSE_DISTANCE > World.DISPLAY_PROMPT_DISTANCE,
			"the panel stays open where its prompt works")
	end)

	t.it("T-DEF-06 finite, frozen, JSON-safe, no shared tables", function()
		A.truthy(table.isfrozen(Presentation), "module frozen")
		local seen: { [any]: string } = {}
		for _, k in Dump.sortedKeys(Presentation) do
			walkData((Presentation :: any)[k], "Presentation." .. k, seen)
		end
	end)
end)
