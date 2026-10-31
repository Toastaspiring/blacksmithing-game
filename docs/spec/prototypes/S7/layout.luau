--!strict
-- Throwaway S7 prototype: the smithy plot build list as pure data (plot-local space), the world ring,
-- stations, display stands and camera framings. Mirrors what Definitions/World.luau + WorldBuilder would hold.
-- Plot-local: origin = plot centre on the ground top (y = 0); -Z = front (towards plaza); +Y up.
-- Shapes use Roblox-native conventions (Cylinder axis = local X, Wedge tall face at +Z).

local V = require("./vecmath")

local L = {}

export type PartSpec = {
	name: string,
	comp: string,
	shape: string, -- Block | Wedge | CornerWedge | Cylinder | Ball
	size: { number }, -- Roblox Part.Size
	xf: V.Xform, -- plot-local CFrame
	collide: boolean,
	query: boolean,
	material: string,
	color: { number },
	neon: boolean?,
}

-- ---------------------------------------------------------------- palette (RGB 0..255) ----
L.PAL = {
	Cobble = { 118, 110, 102 },
	Slate = { 92, 90, 88 },
	Planks = { 124, 88, 58 },
	Brick = { 134, 82, 60 },
	BrickDark = { 96, 60, 48 },
	Timber = { 86, 60, 40 },
	RoofTile = { 112, 52, 40 },
	IronDark = { 58, 58, 62 },
	Soot = { 26, 22, 20 },
	Ember = { 255, 104, 32 },
	Stone = { 150, 144, 136 },
	Parchment = { 232, 220, 190 },
	Flame = { 255, 176, 92 },
	Water = { 64, 110, 140 },
	Grass = { 84, 104, 62 },
	PlazaStone = { 160, 150, 136 },
}

-- ---------------------------------------------------------------- constants ---------------
L.PLOT_SIZE = 40 -- studs, square
L.PLOT_COUNT = 8
L.FLOOR_TOP = 0.5
L.WALL_TOP = 12.5
L.EAVE_Y = 13.5
L.RIDGE_Y = 18.5
L.RIDGE_Z = 2.5
L.EAVE_FRONT_Z = -13
L.EAVE_BACK_Z = 18
L.HOME_POS = { 0, 0.5, -4 } -- plot-local feet position of the home pose (yaw 180: faces +Z)
L.MAX_PARTS = 24 -- revision: Definitions/Limits.MAX_PARTS (RULINGS 2.5); the renderer cap derives from it

local parts: { PartSpec } = {}

local function add(comp: string, name: string, shape: string, size: { number }, xf: V.Xform, collide: boolean, material: string, color: { number }, extra: { query: boolean?, neon: boolean? }?)
	local q = collide
	if extra and extra.query ~= nil then
		q = extra.query :: boolean
	end
	table.insert(parts, {
		name = name,
		comp = comp,
		shape = shape,
		size = size,
		xf = xf,
		collide = collide,
		query = q,
		material = material,
		color = color,
		neon = extra and extra.neon or nil,
	})
end

local function at(x: number, y: number, z: number, r: V.Mat3?): V.Xform
	return V.xf(V.v(x, y, z), r)
end

local VERT = V.rotZ(90) -- native X-axis cylinder stood upright (axis -> +Y)

-- ---------------------------------------------------------------- shell -------------------
local function shell()
	local P = L.PAL
	add("Ground", "Pad", "Block", { 40, 1, 40 }, at(0, -0.5, 0), true, "Cobblestone", P.Cobble)
	add("Floor", "ForgeFloor", "Block", { 32, 0.5, 13 }, at(0, 0.25, 10.5), true, "Slate", P.Slate)
	add("Floor", "GalleryFloor", "Block", { 32, 0.5, 16 }, at(0, 0.25, -4), true, "WoodPlanks", P.Planks)
	add("Walls", "BackWall", "Block", { 34, 12.5, 1 }, at(0, 6.25, 17.5), true, "Brick", P.Brick)
	add("Walls", "LeftWall", "Block", { 1, 12.5, 14 }, at(-16.5, 6.25, 11), true, "Brick", P.Brick)
	add("Walls", "RightWall", "Block", { 1, 12.5, 14 }, at(16.5, 6.25, 11), true, "Brick", P.Brick)
	add("Walls", "Partition", "Block", { 1, 4.5, 7.5 }, at(-16.5, 2.25, 0.25), true, "Brick", P.Brick)
	for i, x in { -16.5, -5.5, 5.5, 16.5 } do
		add("Frame", "FrontPost" .. i, "Block", { 1, 12.5, 1 }, at(x, 6.25, -12.5), true, "Wood", P.Timber)
	end
	add("Frame", "SidePostL", "Block", { 1, 12.5, 1 }, at(-16.5, 6.25, -4), true, "Wood", P.Timber)
	add("Frame", "SidePostR", "Block", { 1, 12.5, 1 }, at(16.5, 6.25, -4), true, "Wood", P.Timber)
	add("Frame", "FrontBeam", "Block", { 34, 1, 1 }, at(0, 13, -12.5), true, "Wood", P.Timber)
	add("Frame", "SideBeamL", "Block", { 1, 1, 31 }, at(-16.5, 13, 2.5), true, "Wood", P.Timber)
	add("Frame", "SideBeamR", "Block", { 1, 1, 31 }, at(16.5, 13, 2.5), true, "Wood", P.Timber)
	add("Frame", "TieBeam", "Block", { 32, 0.8, 0.8 }, at(0, 12.9, 4), true, "Wood", P.Timber)

	-- pitched roof: eaves (z=-12.5 / 18.5, y=13.5), ridge (z=3, y=18.5)
	local run = L.RIDGE_Z - L.EAVE_FRONT_Z -- 15.5
	local rise = L.RIDGE_Y - L.EAVE_Y -- 5
	local ang = math.deg(math.atan(rise / run))
	local slabLen = math.sqrt(run * run + rise * rise) + 0.4
	local th = 0.5
	-- front slab: local +Z goes up-and-back => rotX(-ang); centre = mid of eave-ridge line + th/2 along normal
	local rf = V.rotX(-ang)
	local nf = V.col(rf, 2) -- slab normal (local +Y)
	local midF = V.v(0, (L.EAVE_Y + L.RIDGE_Y) / 2, (L.EAVE_FRONT_Z + L.RIDGE_Z) / 2)
	add("Roof", "RoofFront", "Block", { 35, th, slabLen }, V.xf(V.add(midF, V.scale(nf, th / 2)), rf), true, "Slate", P.RoofTile)
	local rb = V.rotX(ang)
	local nb = V.col(rb, 2)
	local midB = V.v(0, (L.EAVE_Y + L.RIDGE_Y) / 2, (L.EAVE_BACK_Z + L.RIDGE_Z) / 2)
	add("Roof", "RoofBack", "Block", { 35, th, slabLen }, V.xf(V.add(midB, V.scale(nb, th / 2)), rb), true, "Slate", P.RoofTile)
	add("Roof", "Ridge", "Block", { 35.4, 0.7, 0.7 }, at(0, L.RIDGE_Y + 0.35, L.RIDGE_Z, V.rotX(45)), false, "Wood", P.Timber)
	for _, x in { -16.5, 16.5 } do
		add("Roof", "GableFront", "Wedge", { 1, rise, run }, at(x, L.EAVE_Y + rise / 2, L.RIDGE_Z - run / 2), true, "Brick", P.Brick)
		add("Roof", "GableBack", "Wedge", { 1, rise, run }, at(x, L.EAVE_Y + rise / 2, L.RIDGE_Z + run / 2, V.rotY(180)), true, "Brick", P.Brick)
	end
	add("Chimney", "Chimney", "Block", { 4, 11, 4 }, at(-9, 15, 15), true, "Brick", P.BrickDark)
	add("Chimney", "ChimneyCap", "Block", { 4.6, 0.6, 4.6 }, at(-9, 20.8, 15), true, "Slate", P.Slate)

	-- hanging sign + chains
	add("Sign", "SignBoard", "Block", { 10, 2, 0.3 }, at(0, 10.5, -12.5), false, "Wood", P.Planks)
	add("Sign", "SignChainL", "Block", { 0.12, 1, 0.12 }, at(-4, 12, -12.5), false, "Metal", P.IronDark)
	add("Sign", "SignChainR", "Block", { 0.12, 1, 0.12 }, at(4, 12, -12.5), false, "Metal", P.IronDark)

	-- lanterns on the front beam
	for i, x in { -11, 11 } do
		add("Lanterns", "LanternChain" .. i, "Block", { 0.1, 1.2, 0.1 }, at(x, 11.9, -12.5), false, "Metal", P.IronDark)
		add("Lanterns", "LanternFrame" .. i, "Block", { 0.8, 1.0, 0.8 }, at(x, 10.8, -12.5), false, "Metal", P.IronDark)
		add("Lanterns", "LanternFlame" .. i, "Ball", { 0.4, 0.4, 0.4 }, at(x, 10.8, -12.5), false, "Neon", P.Flame, { neon = true })
	end

	-- decor
	add("Decor", "ToolRack", "Block", { 4, 2.5, 0.2 }, at(12.5, 6, 16.9), false, "Wood", P.Timber)
	add("Decor", "Hammer1Handle", "Block", { 0.15, 1.6, 0.15 }, at(11.3, 5.8, 16.72), false, "Wood", P.Timber)
	add("Decor", "Hammer1Head", "Block", { 0.7, 0.35, 0.35 }, at(11.3, 6.7, 16.72), false, "Metal", P.IronDark)
	add("Decor", "Hammer2Handle", "Block", { 0.15, 1.4, 0.15 }, at(12.4, 5.9, 16.72), false, "Wood", P.Timber)
	add("Decor", "Hammer2Head", "Block", { 0.5, 0.3, 0.3 }, at(12.4, 6.7, 16.72), false, "Metal", P.IronDark)
	add("Decor", "TongsA", "Block", { 0.1, 1.8, 0.1 }, at(13.6, 5.9, 16.72, V.rotZ(8)), false, "Metal", P.IronDark)
	add("Decor", "TongsB", "Block", { 0.1, 1.8, 0.1 }, at(13.8, 5.9, 16.72, V.rotZ(-8)), false, "Metal", P.IronDark)
	for i, b in { { -4.4, 0.95, 14.6, 0.9 }, { -3.6, 0.9, 15.2, 0.8 }, { -4.9, 0.85, 15.5, 0.7 }, { -4.0, 1.5, 15.0, 0.7 }, { -3.3, 0.8, 14.2, 0.6 } } do
		add("Decor", "Coal" .. i, "Ball", { b[4], b[4], b[4] }, at(b[1], b[2], b[3]), false, "Slate", P.Soot)
	end
	add("Decor", "CrateA", "Block", { 2.2, 2.2, 2.2 }, at(14.5, 1.6, 15.2), true, "WoodPlanks", P.Planks)
	add("Decor", "CrateB", "Block", { 2.0, 2.0, 2.0 }, at(14.6, 3.7, 15.1, V.rotY(12)), true, "WoodPlanks", P.Planks)

	-- revision (RULINGS 2.24): one SpawnLocation per plot at the home pose; invisible, non-colliding pad whose
	-- top is flush with the gallery floor (FLOOR_TOP), yawed 180 deg so the character faces the forge row (+Z)
	add("Spawn", "HomeSpawn", "Block", { 4, 0.2, 4 }, at(L.HOME_POS[1], L.FLOOR_TOP - 0.1, L.HOME_POS[3], V.rotY(180)), false, "SmoothPlastic", P.Slate, { query = false })
end

-- ---------------------------------------------------------------- stations ----------------
export type StationDef = {
	id: string,
	root: V.Xform, -- plot-local; station-local -Z = front (where the smith stands)
	stand: { number }, -- station-local stand point (feet), smith faces +Z (the station)
	work: { number }, -- station-local work point (workpiece pivot)
	prompt: { number }?, -- station-local prompt attachment
	promptKind: string?,
	cam: { eye: { number }, at: { number }, fov: number }, -- station-local
}

L.STATIONS = {
	{
		id = "Furnace",
		root = at(-9, 0.5, 9.5),
		stand = { 0, 0, -3.0 },
		work = { 0, 2.45, -0.35 },
		cam = { eye = { 5.5, 5.2, -9.0 }, at = { 0, 2.4, 0 }, fov = 50 },
	},
	{
		id = "Anvil",
		root = at(0, 0.5, 8.0),
		stand = { 0, 0, -2.5 },
		work = { 0, 3.0, 0 },
		prompt = { 0, 3.3, -0.2 },
		promptKind = "Forge",
		cam = { eye = { 4.2, 5.4, -6.2 }, at = { 0, 2.9, 0 }, fov = 45 },
	},
	{
		id = "Grindstone",
		root = at(9, 0.5, 10.5),
		stand = { 0, 0, -2.4 },
		work = { 0, 2.6, -1.35 },
		cam = { eye = { 5.8, 5.4, -3.6 }, at = { 0, 2.9, -1.3 }, fov = 50 },
	},
	{
		id = "DraftingTable",
		root = at(-13.5, 0.5, 0, V.rotY(-90)),
		stand = { 0, 0, -2.0 },
		work = { 0, 3.15, 0.2 },
		prompt = { 0, 3.5, -0.4 },
		promptKind = "Draft",
		cam = { eye = { 0, 8.6, -3.2 }, at = { 0, 3.1, 0.3 }, fov = 40 },
	},
} :: { StationDef }

local function stationParts(st: StationDef)
	local P = L.PAL
	local function sadd(name: string, shape: string, size: { number }, lp: { number }, lr: V.Mat3?, collide: boolean, mat: string, col: { number }, extra: any?)
		add("Station:" .. st.id, st.id .. "." .. name, shape, size, V.compose(st.root, at(lp[1], lp[2], lp[3], lr)), collide, mat, col, extra)
	end
	if st.id == "Furnace" then
		sadd("Body", "Block", { 7, 6, 5 }, { 0, 3, 2.5 }, nil, true, "Brick", P.BrickDark)
		sadd("Hood", "Block", { 5, 3.5, 4 }, { 0, 7.75, 3.0 }, nil, true, "Brick", P.BrickDark)
		sadd("Mouth", "Block", { 3, 2.2, 0.3 }, { 0, 2.6, -0.05 }, nil, false, "Slate", P.Soot)
		sadd("CoalBed", "Block", { 2.6, 0.35, 0.8 }, { 0, 1.65, -0.2 }, nil, false, "Neon", P.Ember, { neon = true })
		sadd("Bellows", "Wedge", { 1.6, 0.9, 2.4 }, { 4.6, 0.45, 0.8 }, nil, true, "Wood", P.Timber)
		sadd("Crucible", "Cylinder", { 0.8, 0.9, 0.9 }, { 0, 2.2, -0.35 }, VERT, false, "Metal", P.IronDark)
	elseif st.id == "Anvil" then
		sadd("Stump", "Cylinder", { 1.5, 2.2, 2.2 }, { 0, 0.75, 0 }, VERT, true, "Wood", P.Timber)
		sadd("Base", "Block", { 1.6, 0.5, 1.1 }, { 0, 1.75, 0 }, nil, true, "Metal", P.IronDark)
		sadd("Waist", "Block", { 0.9, 0.55, 0.7 }, { 0, 2.275, 0 }, nil, true, "Metal", P.IronDark)
		sadd("Face", "Block", { 2.4, 0.45, 0.95 }, { 0, 2.775, 0 }, nil, true, "Metal", P.IronDark)
		sadd("Horn", "Wedge", { 0.7, 0.45, 1.1 }, { 1.75, 2.775, 0 }, V.rotY(-90), true, "Metal", P.IronDark)
		sadd("Barrel", "Cylinder", { 2.0, 1.6, 1.6 }, { 3.4, 1.0, 1.4 }, VERT, true, "Wood", P.Timber)
		sadd("Water", "Cylinder", { 0.1, 1.4, 1.4 }, { 3.4, 1.95, 1.4 }, VERT, false, "Glass", P.Water)
	elseif st.id == "Grindstone" then
		sadd("LegL", "Block", { 0.35, 2.6, 1.4 }, { -0.6, 1.3, 0 }, nil, true, "Wood", P.Timber)
		sadd("LegR", "Block", { 0.35, 2.6, 1.4 }, { 0.6, 1.3, 0 }, nil, true, "Wood", P.Timber)
		sadd("Axle", "Cylinder", { 1.8, 0.22, 0.22 }, { 0, 2.6, 0 }, nil, false, "Metal", P.IronDark)
		sadd("Wheel", "Cylinder", { 0.45, 2.6, 2.6 }, { 0, 2.6, 0 }, nil, true, "Slate", P.Stone)
		sadd("Trough", "Block", { 0.9, 0.5, 2.0 }, { 0, 0.85, 0 }, nil, true, "Wood", P.Timber)
		sadd("Crank", "Block", { 0.15, 0.15, 0.7 }, { 1.0, 2.6, -0.3 }, nil, false, "Metal", P.IronDark)
	elseif st.id == "DraftingTable" then
		sadd("Top", "Block", { 4.0, 0.25, 2.4 }, { 0, 3.0, 0.2 }, V.rotX(-12), true, "Wood", P.Planks)
		for i, p in { { -1.75, 1.45, -0.8 }, { 1.75, 1.45, -0.8 }, { -1.75, 1.45, 1.2 }, { 1.75, 1.45, 1.2 } } do
			sadd("Leg" .. i, "Block", { 0.25, 2.9, 0.25 }, p, nil, true, "Wood", P.Timber)
		end
		sadd("Parchment", "Block", { 2.6, 0.02, 1.8 }, { 0, 3.14, 0.2 }, V.rotX(-12), false, "SmoothPlastic", P.Parchment)
		sadd("InkPot", "Cylinder", { 0.3, 0.3, 0.3 }, { 1.6, 3.38, 0.95 }, VERT, false, "Glass", P.Soot)
		sadd("Candle", "Cylinder", { 0.5, 0.18, 0.18 }, { -1.6, 3.5, 0.95 }, VERT, false, "SmoothPlastic", P.Parchment)
		sadd("CandleFlame", "Ball", { 0.16, 0.16, 0.16 }, { -1.6, 3.83, 0.95 }, nil, false, "Neon", P.Flame, { neon = true })
	end
end

-- ---------------------------------------------------------------- display stands ----------
L.SLOT_X = { -13.5, -8.5, -3.5, 3.5, 8.5, 13.5 }
L.SLOT_Z = -9
L.SLOT_COUNT_MVP = 6
L.STAND = {
	cradle = { 0, 1.55, 0 }, -- stand-local: item AABB bottom-centre goes here
	prompt = { 0, 1.6, -1.2 },
}

function L.slotRoot(i: number): V.Xform
	return at(L.SLOT_X[i], L.FLOOR_TOP, L.SLOT_Z)
end

local function standParts(i: number)
	local P = L.PAL
	local root = L.slotRoot(i)
	local function d(name: string, shape: string, size: { number }, lp: { number }, lr: V.Mat3?, collide: boolean, mat: string, col: { number }, extra: any?)
		add("Displays", ("Stand%d.%s"):format(i, name), shape, size, V.compose(root, at(lp[1], lp[2], lp[3], lr)), collide, mat, col, extra)
	end
	d("Plinth", "Block", { 2.0, 1.2, 2.0 }, { 0, 0.6, 0 }, nil, true, "Slate", P.Stone)
	d("Cap", "Block", { 2.3, 0.2, 2.3 }, { 0, 1.3, 0 }, nil, true, "Slate", P.Stone)
	d("Band", "Block", { 2.04, 0.12, 2.04 }, { 0, 0.95, 0 }, nil, false, "Neon", { 170, 170, 170 }, { neon = true })
	d("Nameplate", "Block", { 1.6, 0.45, 0.08 }, { 0, 0.75, -1.06 }, V.rotX(15), false, "Wood", P.Planks)
end

-- ---------------------------------------------------------------- plaza / ring ------------
function L.plotXform(index: number, R: number): V.Xform
	local phi = (index - 1) * 360 / L.PLOT_COUNT
	local a = math.rad(phi)
	return V.xf(V.v(R * math.sin(a), 0, R * math.cos(a)), V.rotY(phi))
end

function L.buildPlot(): { PartSpec }
	table.clear(parts)
	shell()
	for _, st in L.STATIONS do
		stationParts(st)
	end
	for i = 1, L.SLOT_COUNT_MVP do
		standParts(i)
	end
	local out = table.clone(parts)
	return out
end

return L
