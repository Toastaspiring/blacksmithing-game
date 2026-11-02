--!strict
-- Definitions/World (SPEC §13.2–§13.5, §13.11, §16.14, E-S7.1–E-S7.4; T-DEF-01/03/05/06): the §16.14 constants and
-- the E-S7.1 build data. Besides shape checks, the specs re-derive what E-S7.2 measured on S7's prototype from the
-- transcribed rows: the ring distances, the per-plot part budget, the plot extents, the plot-local stand points,
-- eyes, look-ats and prompts, prompt reach, stand spacing and the cradle; E-S7.3's world part and light budgets;
-- E-S7.4's stand and hitbox sizes. A mistyped number in a row fails here before M6 builds the world.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Golden = require("../lib/Golden")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local World = require("../../src/shared/Definitions/World")

type Vec3 = { number }
type PartRow = World.PartRow

local SHELL = { "Ground", "Floor", "Walls", "Frame", "Roof", "Chimney", "Sign", "Lanterns", "Decor", "Spawn" }
local STATION_IDS = { "DraftingTable", "Furnace", "Anvil", "Grindstone" } -- Definitions/Types StationId order
-- E-S7.2's part budget per component (stands: per stand)
local PER_COMPONENT: { [string]: number } = {
	Ground = 1, Floor = 2, Walls = 4, Frame = 10, Roof = 7, Chimney = 2, Sign = 3, Lanterns = 6, Decor = 14, Spawn = 1,
	Furnace = 6, Anvil = 7, Grindstone = 6, DraftingTable = 9, Stand = 4,
}
local MATERIALS = { -- the built-in Enum.Material names the world uses
	Brick = true, Cobblestone = true, Glass = true, Grass = true, Metal = true, Neon = true, Slate = true,
	SmoothPlastic = true, Wood = true, WoodPlanks = true,
}
local ROOT_ABOVE_FEET = 2.5 -- E-S7.2 measures prompt reach from a root this high above the feet

-- ── vector helpers (single-axis rotations, as CFrame.Angles applies them) ─────────────────────────────────────

local function rotate(v: Vec3, axis: number, deg: number): Vec3
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	if axis == 1 then
		return { v[1], v[2] * c - v[3] * s, v[2] * s + v[3] * c }
	elseif axis == 2 then
		return { v[1] * c + v[3] * s, v[2], -v[1] * s + v[3] * c }
	end
	return { v[1] * c - v[2] * s, v[1] * s + v[2] * c, v[3] }
end

local function rotateBy(v: Vec3, rot: Vec3?): Vec3
	if rot == nil then
		return v
	end
	local out = v
	for axis = 3, 1, -1 do -- CFrame.Angles applies Z, then Y, then X; single-axis rows make the order moot
		if rot[axis] ~= 0 then
			out = rotate(out, axis, rot[axis])
		end
	end
	return out
end

local function add(a: Vec3, b: Vec3): Vec3
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function dist(a: Vec3, b: Vec3): number
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function nearVec(actual: Vec3, expected: Vec3, tol: number, what: string)
	for i = 1, 3 do
		A.near(actual[i], expected[i], tol, what .. "[" .. i .. "]")
	end
end

local function station(id: string): World.StationDef
	for _, s in World.STATIONS do
		if s.id == id then
			return s
		end
	end
	return A.fail("no station " .. id)
end

-- station-local → plot-local
local function fromStation(s: World.StationDef, p: Vec3): Vec3
	return add(s.root, rotate(p, 2, s.yaw))
end

-- stand-local → plot-local for stand k
local function fromStand(k: number, p: Vec3): Vec3
	return add({ World.DISPLAY_SLOT_X[k], World.FLOOR_TOP, World.DISPLAY_SLOT_Z }, rotate(p, 2, World.STAND_YAW))
end

local function rowsOf(component: string): { PartRow }
	local out: { PartRow } = {}
	for _, row in World.BUILD_LIST do
		if row.component == component then
			table.insert(out, row)
		end
	end
	return out
end

local function row(component: string, name: string): PartRow
	for _, r in World.BUILD_LIST do
		if r.component == component and r.name == name then
			return r
		end
	end
	return A.fail("no part " .. component .. "." .. name)
end

-- every placed part of one plot, in plot-local space: {row, place(p)}
local function placedParts(): { { row: PartRow, place: (Vec3) -> Vec3 } }
	local out = {}
	for _, r in World.BUILD_LIST do
		if table.find(SHELL, r.component) then
			table.insert(out, { row = r, place = function(p: Vec3): Vec3
				return p
			end })
		elseif r.component == "Stand" then
			for k = 1, World.DISPLAY_SLOTS do
				table.insert(out, { row = r, place = function(p: Vec3): Vec3
					return fromStand(k, p)
				end })
			end
		else
			local s = station(r.component)
			table.insert(out, { row = r, place = function(p: Vec3): Vec3
				return fromStation(s, p)
			end })
		end
	end
	return out
end

local function isRGB(c: any): boolean
	if type(c) ~= "table" or #c ~= 3 then
		return false
	end
	for i = 1, 3 do
		local x = c[i]
		if type(x) ~= "number" or x % 1 ~= 0 or x < 0 or x > 255 then
			return false
		end
	end
	return true
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

return Test.suite("Definitions/World", function(t)
	t.it("§16.14 constants", function()
		local expected: { [string]: any } = {
			PLOT_COUNT = 8,
			PLOT_SIZE = 40,
			PLOT_RING_RADIUS = 86,
			PLAZA_RADIUS = 64,
			WORLD_WALL_RADIUS = 116,
			GROUND_DISC_DIAMETER = 240,
			FLOOR_TOP = 0.5,
			HOME_POSE = { pos = { 0, 0.5, -4 }, yaw = 180 },
			PLOT_INTERACT_MARGIN = 6,
			STEP_STATION = { Smelting = "Furnace", Hammering = "Anvil", Sharpening = "Grindstone" },
			EDITOR_STAGE_ORIGIN = { 0, 1000, 0 },
			DISPLAY_SLOTS = 6,
			DISPLAY_SLOT_KEYS = { "D1", "D2", "D3", "D4", "D5", "D6" },
			DISPLAY_SLOT_X = { -13.5, -8.5, -3.5, 3.5, 8.5, 13.5 },
			DISPLAY_SLOT_Z = -9,
			CRADLE_HEIGHT = 1.55,
			INSPECT_PAD = 0.3,
			INSPECT_MIN_THICKNESS = 0.8,
			STATION_PROMPT_DISTANCE = 7,
			DISPLAY_PROMPT_DISTANCE = 8,
			INSPECT_CLICK_DISTANCE = 24,
			PRESENCE_HZ = 4,
			CLOCK_TIME = 17,
			FLICKER_AMPLITUDE = 0.08,
			FLICKER_FREQUENCY = 6,
			FLICKER_HZ = 20,
			FLICKER_RADIUS = 80,
			LIGHTING_FX = { "BS_Atmosphere", "BS_Grade", "BS_Bloom", "BS_SunRays" },
		}
		local world = World :: any
		for _, name in Dump.sortedKeys(expected) do
			A.deepEq(world[name], expected[name], name)
		end
		for _, name in Dump.sortedKeys(world) do
			A.truthy(string.match(name, "^%u[%u%d_]*$") ~= nil, name .. " is UPPER_SNAKE")
		end
	end)

	t.it("T-DEF-05 ring layout = E-S7.2 (gaps, plaza walk, back corners, wall, discs)", function()
		local R, half = World.PLOT_RING_RADIUS, World.PLOT_SIZE / 2
		local function plotPoint(i: number, p: Vec3): Vec3
			local phi = (i - 1) * 360 / World.PLOT_COUNT
			local centre = { R * math.sin(math.rad(phi)), 0, R * math.cos(math.rad(phi)) }
			return add(centre, rotate(p, 2, phi))
		end
		nearVec(plotPoint(3, { 0, 0, 0 }), { 86, 0, 0 }, 1e-9, "plot 3 centre")
		nearVec(rotate({ 0, 0, -1 }, 2, 90), { -1, 0, 0 }, 1e-12, "plot 3 faces the plaza")
		-- the nearest corners of neighbouring plots: 13.56 studs apart (walkable gaps)
		local gap = dist(plotPoint(1, { half, 0, -half }), plotPoint(2, { -half, 0, -half }))
		A.near(gap, 13.56, 0.005, "adjacent-plot gap")
		A.eq(R - half, 66, "plot fronts 66 studs from the plaza centre")
		A.near(2 * (R - half) * math.sin(math.rad(180 / World.PLOT_COUNT)), 50.5, 0.05, "neighbouring fronts")
		local backCorner = dist({ 0, 0, 0 }, plotPoint(1, { half, 0, half }))
		A.near(backCorner, 107.87, 0.005, "back-corner radius")
		A.eq(World.WORLD_WALL_RADIUS, math.ceil(backCorner + 8), "wall = back corners + 8")
		A.truthy(World.PLAZA_RADIUS < R - half, "the paved disc stays inside the plot fronts")
		A.truthy(World.GROUND_DISC_DIAMETER / 2 > World.WORLD_WALL_RADIUS, "the ground covers the boundary wall")
		-- the editor's reserved 256-stud cube is clear of the world
		A.truthy(World.EDITOR_STAGE_ORIGIN[2] - 128 > 100, "the stage cube is far above the world")
	end)

	t.it("T-DEF-03 build list: 102 parts per plot, 57 colliding (E-S7.2), rows per component", function()
		local counts: { [string]: number } = {}
		for _, r in World.BUILD_LIST do
			counts[r.component] = (counts[r.component] or 0) + 1
		end
		A.deepEq(counts, PER_COMPONENT, "rows per component")
		local parts, colliding = 0, 0
		for _, placed in placedParts() do
			parts += 1
			if placed.row.collide then
				colliding += 1
			end
		end
		A.eq(parts, 102, "parts per plot")
		A.eq(colliding, 57, "colliding parts per plot")
		-- E-S7.3: 946 static parts = 8 plots × 102 + the plaza's 130
		local plaza = World.PLAZA
		local plazaParts = 2 + plaza.lamps.count * 4 + plaza.trees.count * (1 + #plaza.trees.crowns)
			+ plaza.boundary.count * 2
		A.eq(plazaParts, 130, "plaza parts")
		A.eq(World.PLOT_COUNT * parts + plazaParts, 946, "static world parts")
		-- the worst case adds 48 displayed items and their hitboxes, and 8 workpieces, of MAX_PARTS each: 2,338
		local items = World.PLOT_COUNT * World.DISPLAY_SLOTS * (Limits.MAX_PARTS + 1)
		A.eq(World.PLOT_COUNT * parts + plazaParts + items + World.PLOT_COUNT * Limits.MAX_PARTS, 2338, "all parts")
	end)

	t.it("T-DEF-03 the build list stays E-S7.1, row by row (golden)", function()
		Golden.check("world_build_list", World.BUILD_LIST)
	end)

	t.it("T-DEF-03 build rows: names, shapes, sizes, rotations, materials and colours", function()
		local tokens: { [string]: boolean } = {}
		for _, entry in World.PALETTE do
			tokens[entry.token] = true
		end
		local names: { [string]: boolean } = {}
		local frames: { [string]: boolean } = { Stand = true }
		for _, c in SHELL do
			frames[c] = true
		end
		for _, id in STATION_IDS do
			frames[id] = true
		end
		for _, r in World.BUILD_LIST do
			local where = r.component .. "." .. r.name
			A.truthy(frames[r.component] == true, where .. ": a shell component, a StationId or Stand")
			A.truthy(string.match(r.name, "^%u%w*$") ~= nil, where .. ": PascalCase name")
			-- one Instance name per frame: shell names are unique per plot, station and stand names per model
			local scope = if table.find(SHELL, r.component) then "Shell" else r.component
			A.falsy(names[scope .. "." .. r.name], where .. " is unique in its frame")
			names[scope .. "." .. r.name] = true
			A.truthy(r.shape == "Block" or r.shape == "Wedge" or r.shape == "Cylinder" or r.shape == "Ball",
				where .. ": a Part shape")
			A.eq(#r.size, 3, where .. ".size")
			for i = 1, 3 do
				A.truthy(r.size[i] >= 0.02, where .. ": sizes ≥ 0.02 (Roblox's floor is 0.001)")
			end
			if r.shape == "Ball" then
				A.truthy(r.size[1] == r.size[2] and r.size[2] == r.size[3], where .. ": a Ball is round")
			end
			A.eq(#r.pos, 3, where .. ".pos")
			local rot = r.rot
			if rot then
				local nonZero = 0
				for i = 1, 3 do
					if rot[i] ~= 0 then
						nonZero += 1
					end
				end
				A.eq(nonZero, 1, where .. ": a single-axis rotation")
			end
			A.truthy(MATERIALS[r.material] == true, where .. ": built-in material " .. r.material)
			A.truthy(tokens[r.color] == true or r.color == "PlotAccent" or r.color == "Rarity", where .. ": colour "
				.. r.color)
			A.truthy(r.castShadow == nil or r.name == "SignBoard", where .. ": only the sign overrides its shadow")
		end
		A.eq(row("Sign", "SignBoard").castShadow, true, "the sign casts a shadow")
		A.eq(row("Sign", "SignBoard").color, "PlotAccent", "sign boards take the plot accent")
		A.eq(row("Stand", "Band").color, "Rarity", "bands take the rarity colour")
	end)

	t.it("T-DEF-05 plot-local extents x [−20, 20], y [−1, 21.1], z [−20, 20] (E-S7.2)", function()
		local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		for _, placed in placedParts() do
			local r = placed.row
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = { sx * r.size[1] / 2, sy * r.size[2] / 2, sz * r.size[3] / 2 }
						local p = placed.place(add(r.pos, rotateBy(corner, r.rot)))
						for i = 1, 3 do
							lo[i] = math.min(lo[i], p[i])
							hi[i] = math.max(hi[i], p[i])
						end
					end
				end
			end
		end
		nearVec(lo, { -20, -1, -20 }, 1e-9, "min")
		nearVec(hi, { 20, 21.1, 20 }, 1e-9, "max")
	end)

	t.it("T-DEF-05 stations: plot-local stand points, eyes, look-ats and prompts = E-S7.1 / E-S7.2", function()
		local ids: { string } = {}
		for _, s in World.STATIONS do
			table.insert(ids, s.id)
			A.eq(s.root[2], World.FLOOR_TOP, s.id .. " stands on the floor")
			A.eq(s.stand[2], 0, s.id .. ": the stand point is at floor level")
			A.truthy(s.stand[3] < 0, s.id .. ": the smith stands at the front (station −Z)")
		end
		A.deepEq(ids, STATION_IDS, "stations in StationId order")
		local expected: { [string]: { any } } = { -- stand point, eye, look-at (plot-local), fov, parts
			DraftingTable = { { -11.5, 0.5, 0 }, { -10.3, 9.1, 0 }, { -13.8, 3.6, 0 }, 40, 9 },
			Furnace = { { -9, 0.5, 6.5 }, { -3.5, 5.7, 0.5 }, { -9, 2.9, 9.5 }, 50, 6 },
			Anvil = { { 0, 0.5, 5.5 }, { 4.2, 5.9, 1.8 }, { 0, 3.4, 8 }, 45, 7 },
			Grindstone = { { 9, 0.5, 8.1 }, { 14.8, 5.9, 6.9 }, { 9, 3.4, 9.2 }, 50, 6 },
		}
		for _, id in STATION_IDS do
			local s, e = station(id), expected[id]
			nearVec(fromStation(s, s.stand), e[1], 1e-9, id .. " stand point")
			nearVec(fromStation(s, s.framing.eye), e[2], 1e-9, id .. " eye")
			nearVec(fromStation(s, s.framing.at), e[3], 1e-9, id .. " look-at")
			A.eq(s.framing.fov, e[4], id .. " fov")
			A.eq(#rowsOf(id), e[5], id .. " parts")
		end
		-- prompts: Draft on the drafting table, Forge on the anvil; reach measured from the smith's root (E-S7.2)
		local kinds: { [string]: string } = {}
		for _, s in World.STATIONS do
			local prompt = s.prompt
			if prompt then
				kinds[s.id] = prompt.kind
			end
		end
		A.deepEq(kinds, { DraftingTable = "Draft", Anvil = "Forge" }, "station prompts")
		local function reach(id: string): number
			local s = station(id)
			local root = add(fromStation(s, s.stand), { 0, ROOT_ABOVE_FEET, 0 })
			return dist(root, fromStation(s, (s.prompt :: any).pos))
		end
		A.near(reach("Anvil"), 2.44, 0.005, "Anvil prompt from its stand point")
		A.near(reach("DraftingTable"), 1.89, 0.005, "drafting prompt from its stand point")
		A.truthy(reach("Anvil") < World.STATION_PROMPT_DISTANCE, "the stand point reaches the station prompt")
		-- walks between stations (E-S7.2): 9.1 and 9.4 studs
		local function walk(a: string, b: string): number
			return dist(fromStation(station(a), station(a).stand), fromStation(station(b), station(b).stand))
		end
		A.near(walk("Furnace", "Anvil"), 9.1, 0.05, "furnace → anvil")
		A.near(walk("Anvil", "Grindstone"), 9.4, 0.05, "anvil → grindstone")
	end)

	t.it("T-DEF-03 STEP_STATION covers the sword plan; prompt kinds resolve (§13.4, §13.5)", function()
		for _, s in CraftPlans.Sword.steps do
			local id = World.STEP_STATION[s.step]
			A.truthy(id ~= nil and table.find(STATION_IDS, id) ~= nil, s.step .. " has a station")
		end
		local kinds: { [string]: number } = {}
		for _, p in World.PROMPTS do
			A.falsy(kinds[p.kind], p.kind .. " is unique")
			kinds[p.kind] = p.distance
			A.truthy(string.match(p.kind, "^%u%l+$") ~= nil, p.kind .. " is PascalCase")
			A.truthy(p.actionText ~= "", p.kind .. " has an ActionText")
		end
		A.deepEq(kinds, { Draft = 7, Forge = 7, Display = 8, Inspect = 8 }, "prompt kinds and distances")
		for _, s in World.STATIONS do
			local prompt = s.prompt
			if prompt then
				A.eq(kinds[prompt.kind], World.STATION_PROMPT_DISTANCE, s.id .. ": a station prompt")
			end
		end
		A.deepEq(World.PROMPT_SETTINGS, {
			keyboardKeyCode = "E",
			holdDuration = 0,
			exclusivity = "OnePerButton",
			clickablePrompt = true,
			requiresLineOfSight = false,
		}, "prompt settings")
	end)

	t.it("T-DEF-05 stands: keys, spacing, prompts, cradle and inspect hitboxes (E-S7.2, E-S7.4)", function()
		local n = World.DISPLAY_SLOTS
		A.eq(#World.DISPLAY_SLOT_KEYS, n, "a key per stand")
		A.eq(#World.DISPLAY_SLOT_X, n, "an x per stand")
		for k = 1, n do
			A.eq(World.DISPLAY_SLOT_KEYS[k], "D" .. k, "key " .. k)
			A.eq(World.DISPLAY_SLOT_X[k], -World.DISPLAY_SLOT_X[n + 1 - k], "stands are symmetric about the aisle")
		end
		local pitches: { number } = {}
		for k = 2, n do
			table.insert(pitches, World.DISPLAY_SLOT_X[k] - World.DISPLAY_SLOT_X[k - 1])
		end
		A.deepEq(pitches, { 5, 5, 7, 5, 5 }, "pitch 5, 7 across the central aisle")
		local cap = row("Stand", "Cap")
		A.near(7 - cap.size[1], 4.7, 1e-9, "the central aisle")
		A.near(5 - cap.size[1], 2.7, 1e-9, "gaps between caps")
		local sword = EquipmentTypes.get("Sword")
		if sword == nil then
			return A.fail("no Sword")
		end
		local hitbox = sword.geometry
		A.truthy(5 >= (hitbox.hitboxMax[1] - hitbox.hitboxMin[1]) + 2.5, "the 1.6-wide hitbox fits the pitch")
		-- prompts: neighbouring stands' prompts are the closest pair; a visitor outside the front posts reaches one
		local p1, p2 = fromStand(1, World.STAND_PROMPT_POS), fromStand(2, World.STAND_PROMPT_POS)
		A.near(dist(p1, p2), 5.0, 1e-9, "closest prompt pair")
		local visitor = { World.DISPLAY_SLOT_X[1], World.FLOOR_TOP + ROOT_ABOVE_FEET, -14 }
		A.near(dist(visitor, p1), 3.91, 0.005, "a visitor at z = −14 reaches the stand prompt")
		A.truthy(dist(visitor, p1) < World.DISPLAY_PROMPT_DISTANCE, "within the display prompt distance")
		-- cradle: the item's bounds bottom-centre sits 0.15 above the cap, plot y 2.05; a 6-stud item stays under the
		-- sign (bottom 9.5) and the front beam (12.5)
		local cradleY = fromStand(1, { 0, World.CRADLE_HEIGHT, 0 })[2]
		A.near(cradleY, 2.05, 1e-9, "cradle plot y")
		A.near(World.CRADLE_HEIGHT - (cap.pos[2] + cap.size[2] / 2), 0.15, 1e-9, "the item floats above the cap")
		local sign = row("Sign", "SignBoard")
		A.near(cradleY + Limits.MAX_DIM, 8.05, 1e-9, "a 6-stud item tops out at 8.05")
		A.truthy(cradleY + Limits.MAX_DIM < sign.pos[2] - sign.size[2] / 2, "under the sign")
		-- E-S7.4: the arming sword (bounds (−0.55, 0.15, −0.15) → (0.55, 4.30, 0.15)) stands from 2.05 to 6.20 with a
		-- 1.70 × 4.75 × 0.90 InspectHitbox; a full-hitbox item tops out at 7.05 with a 2.2 × 5.6 × 1.2 hitbox
		local function inspectHitbox(size: Vec3): Vec3
			local pad = 2 * World.INSPECT_PAD
			return { size[1] + pad, size[2] + pad, math.max(size[3] + pad, World.INSPECT_MIN_THICKNESS) }
		end
		A.near(cradleY + (4.30 - 0.15), 6.20, 1e-9, "arming sword top")
		nearVec(inspectHitbox({ 1.10, 4.15, 0.30 }), { 1.70, 4.75, 0.90 }, 1e-9, "arming sword hitbox")
		A.near(cradleY + 5, 7.05, 1e-9, "full-hitbox item top")
		nearVec(inspectHitbox({ 1.6, 5, 0.6 }), { 2.2, 5.6, 1.2 }, 1e-9, "full-hitbox item hitbox")
		A.eq(inspectHitbox({ 0.07, 3.4, 0.035 })[3], World.INSPECT_MIN_THICKNESS, "thin blades stay clickable")
	end)

	t.it("T-DEF-05 floors, home pose and HomeSpawn agree (§13.3)", function()
		for _, name in { "ForgeFloor", "GalleryFloor" } do
			local f = row("Floor", name)
			A.near(f.pos[2] + f.size[2] / 2, World.FLOOR_TOP, 1e-12, name .. " top")
		end
		local spawn = row("Spawn", "HomeSpawn")
		A.near(spawn.pos[2] + spawn.size[2] / 2, World.FLOOR_TOP, 1e-12, "HomeSpawn top flush with the floor")
		A.eq(World.HOME_POSE.pos[2], World.FLOOR_TOP, "the home pose stands on the floor")
		A.eq(spawn.pos[1], World.HOME_POSE.pos[1], "HomeSpawn x")
		A.eq(spawn.pos[3], World.HOME_POSE.pos[3], "HomeSpawn z")
		A.deepEq(spawn.rot, { 0, World.HOME_POSE.yaw, 0 }, "HomeSpawn faces the forge row")
		A.falsy(spawn.collide, "HomeSpawn does not collide")
		A.deepEq(World.HOME_SPAWN, { transparency = 1, canQuery = false, neutral = true, duration = 0 }, "HOME_SPAWN")
		-- facing the forge row: yaw 180 turns the character's −Z look toward plot +Z
		nearVec(rotate({ 0, 0, -1 }, 2, World.HOME_POSE.yaw), { 0, 0, 1 }, 1e-12, "home pose look")
		local half = World.PLOT_SIZE / 2
		for _, s in World.STATIONS do
			local p = fromStation(s, s.stand)
			A.truthy(math.abs(p[1]) <= half and math.abs(p[3]) <= half, s.id .. " stand point inside the plot")
		end
		for _, r in World.RESERVED_FLOOR do
			A.truthy(math.abs(r.pos[1]) <= half and math.abs(r.pos[3]) <= half, r.name .. " inside the plot")
			A.eq(r.pos[2], World.FLOOR_TOP, r.name .. " on the floor")
		end
	end)

	t.it("T-DEF-01 palette, plot accents and the sign (E-S7.1)", function()
		local used: { [string]: boolean } = {}
		for _, r in World.BUILD_LIST do
			used[r.color] = true
		end
		local plaza = World.PLAZA
		for _, p in { plaza.groundDisc, plaza.plazaDisc, plaza.boundary.wall, plaza.trees.crowns[1], plaza.trees.crowns[2] } do
			used[p.color :: string] = true
		end
		local byToken: { [string]: World.PaletteEntry } = {}
		for _, entry in World.PALETTE do
			A.truthy(string.match(entry.token, "^%u%a*$") ~= nil, entry.token .. " is PascalCase")
			A.falsy(byToken[entry.token], entry.token .. " is unique")
			byToken[entry.token] = entry
			A.truthy(isRGB(entry.color), entry.token .. " is RGB 0–255")
			A.truthy(#entry.materials >= 1, entry.token .. " names its materials")
			for _, m in entry.materials do
				A.truthy(MATERIALS[m] == true, entry.token .. ": built-in material " .. m)
			end
			A.truthy(used[entry.token] == true, entry.token .. " is used")
		end
		A.eq(#World.PALETTE, 17, "17 tokens")
		-- each part's material is one its colour token is used with, except two invisible-or-glass details
		local exceptions = { HomeSpawn = true, InkPot = true }
		for _, r in World.BUILD_LIST do
			local entry = byToken[r.color]
			if entry and not exceptions[r.name] then
				A.truthy(table.find(entry.materials, r.material) ~= nil, r.name .. ": " .. r.material .. " with " .. r.color)
			end
		end
		A.eq(#World.PLOT_ACCENTS, World.PLOT_COUNT, "an accent per plot")
		local seen: { [string]: boolean } = {}
		for i, c in World.PLOT_ACCENTS do
			A.truthy(isRGB(c), "accent " .. i)
			local key = table.concat(c, ",")
			A.falsy(seen[key], "accent " .. i .. " is distinct")
			seen[key] = true
		end
		A.deepEq(World.PLOT_ACCENTS[1], { 150, 52, 44 }, "plot 1 crimson")
		A.deepEq(World.PLOT_ACCENTS[8], { 96, 104, 112 }, "plot 8 slate")
		local sign = World.SIGN
		A.eq(sign.pixelsPerStud * row("Sign", "SignBoard").size[1], 500, "500 px wide")
		A.eq(sign.pixelsPerStud * row("Sign", "SignBoard").size[2], 100, "100 px tall")
		A.truthy(sign.titleMaxTextSize <= 100 and sign.subtitleMaxTextSize < sign.titleMaxTextSize, "text sizes")
		A.truthy(isRGB(sign.textColor) and isRGB(sign.vacantTitleColor) and isRGB(sign.strokeColor), "sign colours")
		A.falsy(sign.richText or sign.autoLocalize, "player text: RichText and AutoLocalize off")
		A.eq("Ada" .. sign.titleSuffix, "Ada's Smithy", "title")
		A.eq(sign.vacantTitle, "Vacant Smithy", "vacant title")
		A.eq(sign.subtitlePrefix .. "ada", "@ada", "subtitle")
	end)

	t.it("T-DEF-05 plaza (E-S7.1, E-S7.3)", function()
		local plaza = World.PLAZA
		A.eq(plaza.groundDisc.size[2], World.GROUND_DISC_DIAMETER, "ground disc diameter")
		A.eq(plaza.plazaDisc.size[2], 2 * World.PLAZA_RADIUS, "plaza disc diameter")
		local plazaTop = (plaza.plazaDisc.pos :: Vec3)[2] + plaza.plazaDisc.size[1] / 2
		local groundTop = (plaza.groundDisc.pos :: Vec3)[2] + plaza.groundDisc.size[1] / 2
		A.near(plazaTop, 0, 1e-12, "the plaza disc's top is the ground top")
		A.truthy(groundTop < plazaTop, "the ground disc sits just below (no z-fighting)")
		A.truthy(plaza.lamps.radius < World.PLAZA_RADIUS, "lamps stand on the paved disc")
		A.eq(plaza.boundary.radius, World.WORLD_WALL_RADIUS, "boundary radius")
		A.eq(plaza.boundary.count * plaza.boundary.stepDeg, 360, "the boundary closes")
		local chord = 2 * plaza.boundary.radius * math.sin(math.rad(plaza.boundary.stepDeg / 2))
		A.near(chord, 20.22, 0.005, "segment chord")
		A.truthy(plaza.boundary.wall.size[1] >= chord, "wall segments leave no gap")
		local wall, barrier = plaza.boundary.wall, plaza.boundary.barrier
		A.near((barrier.pos :: Vec3)[2] - barrier.size[2] / 2, (wall.pos :: Vec3)[2] + wall.size[2] / 2, 1e-12,
			"the barrier sits on the wall")
		A.near((plaza.lamps.post.pos :: Vec3)[2], plaza.lamps.post.size[1] / 2, 1e-12, "the lamp post stands on the ground")
		A.near((plaza.trees.trunk.pos :: Vec3)[2], plaza.trees.trunk.size[1] / 2, 1e-12, "the trunk stands on the ground")
		-- E-S7.3: 96 PointLights = 8 × (furnace, 2 lanterns, candle) + 8 plaza lamps + 48 rarity + 8 workpiece lights
		local perPlot = 1 + #rowsOf("Lanterns") // 3 + 1
		A.eq(perPlot, 4, "lights per plot")
		local lights = World.PLOT_COUNT * perPlot + plaza.lamps.count + World.PLOT_COUNT * World.DISPLAY_SLOTS
			+ World.PLOT_COUNT
		A.eq(lights, 96, "PointLight budget")
	end)

	t.it("T-DEF-05 Lighting, glow, lights and flicker (E-S7.1)", function()
		local L = World.LIGHTING
		A.eq(L.clockTime, World.CLOCK_TIME, "ClockTime")
		A.eq(L.lightingStyle, "Realistic")
		A.truthy(L.prioritizeLightingQuality and L.globalShadows, "quality and shadows")
		A.falsy(L.sky, "no Sky instance")
		A.deepEq({ L.geographicLatitude, L.brightness, L.environmentDiffuseScale, L.environmentSpecularScale,
			L.shadowSoftness, L.exposureCompensation }, { 30, 2, 0.5, 0.8, 0.3, 0 }, "Lighting numbers")
		A.deepEq({ L.ambient, L.outdoorAmbient, L.colorShiftTop }, { { 44, 36, 32 }, { 128, 112, 100 }, { 255, 220, 180 } },
			"Lighting colours")
		A.deepEq(L.atmosphere, { density = 0.26, offset = 0.1, color = { 199, 170, 146 }, decay = { 110, 86, 70 },
			glare = 0.2, haze = 1.2 }, "BS_Atmosphere")
		A.deepEq(L.grade, { brightness = 0.02, contrast = 0.08, saturation = 0.05, tintColor = { 255, 244, 232 } },
			"BS_Grade")
		A.deepEq(L.bloom, { intensity = 0.5, size = 24, threshold = 1.3 }, "BS_Bloom")
		A.deepEq(L.sunRays, { intensity = 0.03, spread = 0.5 }, "BS_SunRays")
		local names: { [string]: boolean } = {}
		for _, name in World.LIGHTING_FX do
			A.truthy(string.match(name, "^BS_%u%a+$") ~= nil, name .. " is a BS_ name")
			A.falsy(names[name], name .. " is unique")
			names[name] = true
		end
		local glow = World.FORGE_GLOW
		A.deepEq(glow.fire, { size = 5, heat = 9, color = { 255, 110, 40 }, secondaryColor = { 255, 190, 90 } }, "Fire")
		A.deepEq(glow.light, { color = { 255, 140, 60 }, brightness = 3, range = 18, shadows = true }, "furnace light")
		A.deepEq(glow.embers, { rate = 8, lifetime = { 1.2, 2.0 }, speed = { 1.5, 3 }, size = { 0.10, 0 },
			lightEmission = 1, color = { { 255, 160, 60 }, { 255, 60, 20 } }, acceleration = { 0, 2, 0 },
			spreadAngle = { 25, 25 } }, "Embers")
		A.deepEq(glow.smoke, { color = { 70, 66, 62 }, opacity = 0.12, riseVelocity = 4, size = 4 }, "Smoke")
		A.deepEq(World.LIGHTS, {
			lantern = { color = { 255, 176, 100 }, brightness = 1.3, range = 16, flicker = true },
			candle = { color = { 255, 190, 120 }, brightness = 0.9, range = 8, flicker = true },
			plazaLamp = { color = { 255, 190, 130 }, brightness = 1.2, range = 22, flicker = false },
		}, "LIGHTS")
		A.deepEq(World.SPARKS, { rate = 0, lifetime = { 0.25, 0.5 }, speed = { 8, 14 }, size = 0.06, lightEmission = 1,
			color = { 255, 200, 120 }, acceleration = { 0, -30, 0 }, spreadAngle = { 60, 60 } }, "Sparks")
		A.deepEq(World.VACANT_PLOT, { coalBed = { material = "Slate", color = { 60, 36, 28 } },
			lanternFlame = { material = "SmoothPlastic", color = { 90, 80, 70 } } }, "vacant plot")
		A.truthy(World.LIGHTS.lantern.range < World.FLICKER_RADIUS, "flickering lights are local")
		A.truthy(World.FLICKER_AMPLITUDE > 0 and World.FLICKER_AMPLITUDE < 1, "subtle flicker")
		A.truthy(World.LIGHTS.lantern.flicker and World.LIGHTS.candle.flicker, "lanterns and the candle flicker")
		A.truthy(glow.light.shadows, "the furnace light is the shadow caster")
	end)

	t.it("T-DEF-05 part flags (E-S7.1)", function()
		A.deepEq(World.PART_DEFAULTS, { anchored = true, locked = true, canTouch = false, surfaces = "Smooth" }, "defaults")
		A.deepEq(World.PART_FLAGS, {
			Structure = { canCollide = true, canQuery = true, castShadow = true },
			Decor = { canCollide = false, canQuery = false, castShadow = false },
			Item = { canCollide = false, canQuery = false, castShadow = true },
			InspectHitbox = { canCollide = false, canQuery = true, castShadow = false, transparency = 1 },
			Barrier = { canCollide = true, canQuery = true, castShadow = false, transparency = 1 },
		}, "PART_FLAGS")
	end)

	t.it("T-DEF-06 finite, frozen, JSON-safe, no shared tables", function()
		A.truthy(table.isfrozen(World), "module frozen")
		local seen: { [any]: string } = {}
		for _, k in Dump.sortedKeys(World) do
			walkData((World :: any)[k], "World." .. k, seen)
		end
	end)
end)
