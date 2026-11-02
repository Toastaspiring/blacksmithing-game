--!strict
-- Definitions/World (SPEC §13.2–§13.5, §13.11, §16.14, E-S7.1; owner S7): the smithy world as pure data, one
-- deep-frozen table: the ring layout, stations and their framings, display stands, prompts, the build list, the
-- plaza, the palette, signs, Lighting and the forge glow. WorldBuilder builds the world from it at boot
-- (Instance.new, no assets, nothing in the place file); World/Layout computes poses from it. World only: the BALANCE
-- Manifest excludes this module.
--
-- Frames (E-S7.1). Plot i (1..PLOT_COUNT) sits at φ_i = (i − 1)·360°/PLOT_COUNT counter-clockwise from +Z seen from
-- above, centre (R·sin φ_i, 0, R·cos φ_i) with R = PLOT_RING_RADIUS, rotated by φ_i about +Y, so plot-local −Z faces
-- the plaza; the ground top is y = 0. BUILD_LIST rows (one line per row of E-S7.1's table, in its order) are in
-- their component's frame:
--   Ground, Floor, Walls, Frame, Roof, Chimney, Sign, Lanterns, Decor, Spawn   plot-local (the shell)
--   Furnace, Anvil, Grindstone, DraftingTable (StationIds)   the station frame: the STATIONS row's root, yawed by its
--                                                            yaw; station-local −Z is the front, where the smith
--                                                            stands facing +Z
--   Stand                                                    each stand's frame, repeated for the 6 stands: root
--                                                            (DISPLAY_SLOT_X[k], FLOOR_TOP, DISPLAY_SLOT_Z), STAND_YAW
-- Sizes are Roblox Part.Size (a Cylinder's length runs along its local X, so rotZ 90 stands it upright); `rot` is a
-- single-axis CFrame.Angles in degrees {x, y, z} (nil = none). `color` is a PALETTE token, "PlotAccent" (the plot's
-- PLOT_ACCENTS entry) or "Rarity" (the displayed item's Rarities colour). Per plot: 102 parts, 57 colliding.
-- Yaws are degrees about +Y; colours RGB 0–255 (Color3.fromRGB at the edge); ranges {min, max}; sequences
-- {start, end}.

local Catalog = require("./Catalog")
local DT = require("./Types")

type Vec3 = DT.Vec3
type RGB = DT.RGB

export type Pose = { pos: Vec3, yaw: number } -- upright, yaw in degrees about +Y (World/Layout's Pose)
export type PartRow = {
	component: string,
	name: string, -- Instance name
	shape: DT.ShapeId,
	size: Vec3,
	pos: Vec3,
	rot: Vec3?,
	collide: boolean, -- true: PART_FLAGS.Structure; false: PART_FLAGS.Decor
	material: string, -- Enum.Material name
	color: string,
	castShadow: boolean?, -- overrides the flag category (the sign board casts a shadow)
}
export type Framing = { eye: Vec3, at: Vec3, fov: number } -- station-local; world = stationCF * eye, CFrame.lookAt
export type StationDef = {
	id: DT.StationId,
	root: Vec3, -- plot-local, floor level
	yaw: number,
	stand: Vec3, -- station-local: the smith's feet, facing the station
	work: Vec3, -- station-local: the work point (the workpiece pivots are Presentation.WORKPIECES)
	prompt: { kind: string, pos: Vec3 }?, -- station-local ProximityPrompt attachment
	framing: Framing,
}
export type PromptDef = {
	kind: string, -- the prompt's PromptKind attribute
	actionText: string,
	objectText: string?, -- nil: the stand's ItemName
	distance: number, -- MaxActivationDistance
}
export type PartFlags = { canCollide: boolean, canQuery: boolean, castShadow: boolean, transparency: number? }
export type PlazaPart = {
	shape: DT.ShapeId,
	size: Vec3,
	pos: Vec3?, -- world (discs) or above the instance's base point; nil: not given by E-S7.1
	rot: Vec3?,
	collide: boolean?,
	material: string?, -- nil: not given by E-S7.1
	color: string?,
}
-- `materials`: the Enum.Material names the token is used with (informational: each row names its own material)
export type PaletteEntry = { token: string, color: RGB, materials: { string } }
export type LightDef = { color: RGB, brightness: number, range: number, flicker: boolean }

-- Values other entries reuse, so each has one literal.
local PLAZA_RADIUS = 64 -- studs: paved disc just inside the plot fronts (66)
local WORLD_WALL_RADIUS = 116 -- studs: plot back corners (107.9) + 8
local GROUND_DISC_DIAMETER = 240 -- studs: covers everything inside the boundary wall
local STATION_PROMPT_DISTANCE = 7 -- studs: reached from the station's stand point (prompts 1.9–2.4 studs away)
local DISPLAY_PROMPT_DISTANCE = 8 -- studs: reached from outside the front posts (3.9 studs)
local CLOCK_TIME = 17 -- hours: a fixed golden hour, no cycle [Decision to confirm] (Q20)

export type World = {
	PLOT_COUNT: number,
	PLOT_SIZE: number,
	PLOT_RING_RADIUS: number,
	PLAZA_RADIUS: number,
	WORLD_WALL_RADIUS: number,
	GROUND_DISC_DIAMETER: number,
	FLOOR_TOP: number,
	HOME_POSE: Pose,
	PLOT_INTERACT_MARGIN: number,
	EDITOR_STAGE_ORIGIN: Vec3,
	STEP_STATION: { [DT.StepId]: DT.StationId },
	STATIONS: { StationDef },
	STATION_PROMPT_DISTANCE: number,
	DISPLAY_SLOTS: number,
	DISPLAY_SLOT_KEYS: { string },
	DISPLAY_SLOT_X: { number },
	DISPLAY_SLOT_Z: number,
	STAND_YAW: number,
	STAND_PROMPT_POS: Vec3,
	CRADLE_HEIGHT: number,
	INSPECT_PAD: number,
	INSPECT_MIN_THICKNESS: number,
	DISPLAY_PROMPT_DISTANCE: number,
	INSPECT_CLICK_DISTANCE: number,
	PRESENCE_HZ: number,
	PROMPT_SETTINGS: {
		keyboardKeyCode: string,
		holdDuration: number,
		exclusivity: string,
		clickablePrompt: boolean,
		requiresLineOfSight: boolean,
	},
	PROMPTS: { PromptDef },
	BUILD_LIST: { PartRow },
	PART_DEFAULTS: { anchored: boolean, locked: boolean, canTouch: boolean, surfaces: string },
	PART_FLAGS: {
		Structure: PartFlags,
		Decor: PartFlags,
		Item: PartFlags,
		InspectHitbox: PartFlags,
		Barrier: PartFlags,
	},
	HOME_SPAWN: { transparency: number, canQuery: boolean, neutral: boolean, duration: number },
	PLAZA: {
		groundDisc: PlazaPart,
		plazaDisc: PlazaPart,
		lamps: { count: number, radius: number, post: PlazaPart, arm: PlazaPart, lantern: PlazaPart, flame: PlazaPart },
		trees: { count: number, radius: number, trunk: PlazaPart, crowns: { PlazaPart } },
		boundary: { count: number, stepDeg: number, radius: number, wall: PlazaPart, barrier: PlazaPart },
	},
	RESERVED_FLOOR: { { name: string, pos: Vec3, yaw: number? } },
	PALETTE: { PaletteEntry },
	PLOT_ACCENTS: { RGB },
	SIGN: {
		face: string,
		pixelsPerStud: number,
		titleMaxTextSize: number,
		subtitleMaxTextSize: number,
		font: string,
		fontWeight: string,
		textColor: RGB,
		vacantTitleColor: RGB,
		strokeColor: RGB,
		strokeTransparency: number,
		lightInfluence: number,
		brightness: number,
		richText: boolean,
		autoLocalize: boolean,
		titleSuffix: string,
		vacantTitle: string,
		subtitlePrefix: string,
	},
	CLOCK_TIME: number,
	LIGHTING: {
		lightingStyle: string,
		prioritizeLightingQuality: boolean,
		clockTime: number,
		geographicLatitude: number,
		brightness: number,
		ambient: RGB,
		outdoorAmbient: RGB,
		colorShiftTop: RGB,
		environmentDiffuseScale: number,
		environmentSpecularScale: number,
		shadowSoftness: number,
		globalShadows: boolean,
		exposureCompensation: number,
		sky: boolean,
		atmosphere: { density: number, offset: number, color: RGB, decay: RGB, glare: number, haze: number },
		grade: { brightness: number, contrast: number, saturation: number, tintColor: RGB },
		bloom: { intensity: number, size: number, threshold: number },
		sunRays: { intensity: number, spread: number },
	},
	LIGHTING_FX: { string },
	FORGE_GLOW: {
		fire: { size: number, heat: number, color: RGB, secondaryColor: RGB },
		light: { color: RGB, brightness: number, range: number, shadows: boolean },
		embers: {
			rate: number,
			lifetime: { number },
			speed: { number },
			size: { number },
			lightEmission: number,
			color: { RGB },
			acceleration: Vec3,
			spreadAngle: { number },
		},
		smoke: { color: RGB, opacity: number, riseVelocity: number, size: number },
	},
	LIGHTS: { lantern: LightDef, candle: LightDef, plazaLamp: LightDef },
	SPARKS: {
		rate: number,
		lifetime: { number },
		speed: { number },
		size: number,
		lightEmission: number,
		color: RGB,
		acceleration: Vec3,
		spreadAngle: { number },
	},
	VACANT_PLOT: { coalBed: { material: string, color: RGB }, lanternFlame: { material: string, color: RGB } },
	FLICKER_AMPLITUDE: number,
	FLICKER_FREQUENCY: number,
	FLICKER_HZ: number,
	FLICKER_RADIUS: number,
}

local World: World = {
	-- ── ring layout (§13.2, E-S7.2) ────────────────────────────────────────────────────────────────────────────
	PLOT_COUNT = 8, -- plots: one smithy per player, = Players.MaxPlayers (Q2); the only definition (S5's boot check)
	PLOT_SIZE = 40, -- studs, square: pavilion plus a front yard where visitors read the stands
	PLOT_RING_RADIUS = 86, -- studs: 13.6-stud gaps, plot fronts 66 studs (4.1 s walk) from the plaza centre
	PLAZA_RADIUS = PLAZA_RADIUS,
	WORLD_WALL_RADIUS = WORLD_WALL_RADIUS,
	GROUND_DISC_DIAMETER = GROUND_DISC_DIAMETER,
	FLOOR_TOP = 0.5, -- studs: smithy floor one step above the ground
	-- plot-local spawn and teleport target on the gallery floor, facing the forge row (§13.3)
	HOME_POSE = { pos = { 0, 0.5, -4 }, yaw = 180 },
	-- studs beyond the plot square that still count as "at your smithy" for Place, Clear and Begin
	PLOT_INTERACT_MARGIN = 6,
	-- studs: centre of the 256-stud cube reserved for the editor stage (§11); nothing else is built there
	EDITOR_STAGE_ORIGIN = { 0, 1000, 0 },

	-- ── stations (§13.4–§13.6, E-S7.1) ─────────────────────────────────────────────────────────────────────────
	-- the step-to-station map; new stations are data (Phase 2 hook: RESERVED_FLOOR)
	STEP_STATION = { Smelting = "Furnace", Hammering = "Anvil", Sharpening = "Grindstone" },
	STATIONS = {
		{
			id = "DraftingTable",
			root = { -13.5, 0.5, 0 },
			yaw = -90, -- the front faces plot +X
			stand = { 0, 0, -2.0 },
			work = { 0, 3.15, 0.2 }, -- parchment
			prompt = { kind = "Draft", pos = { 0, 3.5, -0.4 } },
			framing = { eye = { 0, 8.6, -3.2 }, at = { 0, 3.1, 0.3 }, fov = 40 }, -- a top-down transition shot
		},
		{
			id = "Furnace",
			root = { -9, 0.5, 9.5 },
			yaw = 0,
			stand = { 0, 0, -3.0 },
			work = { 0, 2.45, -0.35 }, -- crucible
			framing = { eye = { 5.5, 5.2, -9.0 }, at = { 0, 2.4, 0 }, fov = 50 },
		},
		{
			id = "Anvil",
			root = { 0, 0.5, 8.0 },
			yaw = 0,
			stand = { 0, 0, -2.5 },
			work = { 0, 3.0, 0 }, -- face top
			prompt = { kind = "Forge", pos = { 0, 3.3, -0.2 } },
			framing = { eye = { 4.2, 5.4, -6.2 }, at = { 0, 2.9, 0 }, fov = 45 },
		},
		{
			id = "Grindstone",
			root = { 9, 0.5, 10.5 },
			yaw = 0,
			stand = { 0, 0, -2.4 },
			work = { 0, 2.6, -1.35 }, -- wheel rim
			framing = { eye = { 5.8, 5.4, -3.6 }, at = { 0, 2.9, -1.3 }, fov = 50 }, -- a side view on purpose
		},
	},
	STATION_PROMPT_DISTANCE = STATION_PROMPT_DISTANCE,

	-- ── display stands (§13.4, §13.5, §13.9, E-S7.1) ───────────────────────────────────────────────────────────
	DISPLAY_SLOTS = 6, -- stands per plot (Q20); also the Guard's slot bound
	DISPLAY_SLOT_KEYS = { "D1", "D2", "D3", "D4", "D5", "D6" }, -- smithy.displays keys (Persistence/Prepare, Showcase)
	DISPLAY_SLOT_X = { -13.5, -8.5, -3.5, 3.5, 8.5, 13.5 }, -- studs, plot-local: pitch 5, 7 across the central aisle
	DISPLAY_SLOT_Z = -9, -- studs, plot-local: one row behind the front posts, readable from the front yard
	STAND_YAW = 0, -- the stand's front faces the plaza; its floor is FLOOR_TOP
	STAND_PROMPT_POS = { 0, 1.6, -1.2 }, -- stand-local ProximityPrompt (Display on an empty stand, else Inspect)
	-- studs above the stand base: the item's bounds bottom-centre sits at stand-local (0, CRADLE_HEIGHT, 0), 0.15
	-- above the cap, so a 5-stud item tops out under the sign
	CRADLE_HEIGHT = 1.55,
	INSPECT_PAD = 0.3, -- studs per side around the item bounds: an easier click target
	INSPECT_MIN_THICKNESS = 0.8, -- studs: thin blades stay clickable edge-on
	DISPLAY_PROMPT_DISTANCE = DISPLAY_PROMPT_DISTANCE,
	INSPECT_CLICK_DISTANCE = 24, -- studs: click an item from across the gallery (ClickDetector)
	PRESENCE_HZ = 4, -- Hz: PlotPresence check rate, fast enough for the entry toast

	-- ── prompts (§13.5, E-S7.1): the server sets the texts; attributes and setSuppressed set Enabled locally ─────
	PROMPT_SETTINGS = {
		keyboardKeyCode = "E",
		holdDuration = 0,
		exclusivity = "OnePerButton",
		clickablePrompt = true,
		requiresLineOfSight = false,
	},
	-- enabled for, and what each opens: Draft and Forge, the owner outside a stage (the editor; the forge flow);
	-- Display, the owner at an empty stand (the item picker); Inspect, everyone at an occupied stand (the panel)
	PROMPTS = {
		{ kind = "Draft", actionText = "Draft", objectText = "Drafting table", distance = STATION_PROMPT_DISTANCE },
		{ kind = "Forge", actionText = "Forge", objectText = "Anvil", distance = STATION_PROMPT_DISTANCE },
		{ kind = "Display", actionText = "Display an item", objectText = "Empty stand", distance = DISPLAY_PROMPT_DISTANCE },
		{ kind = "Inspect", actionText = "Inspect", distance = DISPLAY_PROMPT_DISTANCE }, -- ObjectText: the ItemName
	},

	-- ── build list (E-S7.1, one row per part; frames in the header) ─────────────────────────────────────────────
	BUILD_LIST = {
		{ component = "Ground", name = "Pad", shape = "Block", size = { 40, 1, 40 }, pos = { 0, -0.5, 0 }, collide = true, material = "Cobblestone", color = "Cobble" },
		{ component = "Floor", name = "ForgeFloor", shape = "Block", size = { 32, 0.5, 13 }, pos = { 0, 0.25, 10.5 }, collide = true, material = "Slate", color = "Slate" },
		{ component = "Floor", name = "GalleryFloor", shape = "Block", size = { 32, 0.5, 16 }, pos = { 0, 0.25, -4 }, collide = true, material = "WoodPlanks", color = "Planks" },
		{ component = "Walls", name = "BackWall", shape = "Block", size = { 34, 12.5, 1 }, pos = { 0, 6.25, 17.5 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Walls", name = "LeftWall", shape = "Block", size = { 1, 12.5, 14 }, pos = { -16.5, 6.25, 11 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Walls", name = "RightWall", shape = "Block", size = { 1, 12.5, 14 }, pos = { 16.5, 6.25, 11 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Walls", name = "Partition", shape = "Block", size = { 1, 4.5, 7.5 }, pos = { -16.5, 2.25, 0.25 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Frame", name = "FrontPost1", shape = "Block", size = { 1, 12.5, 1 }, pos = { -16.5, 6.25, -12.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "FrontPost2", shape = "Block", size = { 1, 12.5, 1 }, pos = { -5.5, 6.25, -12.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "FrontPost3", shape = "Block", size = { 1, 12.5, 1 }, pos = { 5.5, 6.25, -12.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "FrontPost4", shape = "Block", size = { 1, 12.5, 1 }, pos = { 16.5, 6.25, -12.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "SidePostL", shape = "Block", size = { 1, 12.5, 1 }, pos = { -16.5, 6.25, -4 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "SidePostR", shape = "Block", size = { 1, 12.5, 1 }, pos = { 16.5, 6.25, -4 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "FrontBeam", shape = "Block", size = { 34, 1, 1 }, pos = { 0, 13, -12.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "SideBeamL", shape = "Block", size = { 1, 1, 31 }, pos = { -16.5, 13, 2.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "SideBeamR", shape = "Block", size = { 1, 1, 31 }, pos = { 16.5, 13, 2.5 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Frame", name = "TieBeam", shape = "Block", size = { 32, 0.8, 0.8 }, pos = { 0, 12.9, 4 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Roof", name = "RoofFront", shape = "Block", size = { 35, 0.5, 16.686 }, pos = { 0, 16.238, -5.327 }, rot = { -17.88, 0, 0 }, collide = true, material = "Slate", color = "RoofTile" },
		{ component = "Roof", name = "RoofBack", shape = "Block", size = { 35, 0.5, 16.686 }, pos = { 0, 16.238, 10.327 }, rot = { 17.88, 0, 0 }, collide = true, material = "Slate", color = "RoofTile" },
		{ component = "Roof", name = "Ridge", shape = "Block", size = { 35.4, 0.7, 0.7 }, pos = { 0, 18.85, 2.5 }, rot = { 45, 0, 0 }, collide = false, material = "Wood", color = "Timber" },
		{ component = "Roof", name = "GableFrontL", shape = "Wedge", size = { 1, 5, 15.5 }, pos = { -16.5, 16, -5.25 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Roof", name = "GableBackL", shape = "Wedge", size = { 1, 5, 15.5 }, pos = { -16.5, 16, 10.25 }, rot = { 0, 180, 0 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Roof", name = "GableFrontR", shape = "Wedge", size = { 1, 5, 15.5 }, pos = { 16.5, 16, -5.25 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Roof", name = "GableBackR", shape = "Wedge", size = { 1, 5, 15.5 }, pos = { 16.5, 16, 10.25 }, rot = { 0, 180, 0 }, collide = true, material = "Brick", color = "Brick" },
		{ component = "Chimney", name = "Chimney", shape = "Block", size = { 4, 11, 4 }, pos = { -9, 15, 15 }, collide = true, material = "Brick", color = "BrickDark" },
		{ component = "Chimney", name = "ChimneyCap", shape = "Block", size = { 4.6, 0.6, 4.6 }, pos = { -9, 20.8, 15 }, collide = true, material = "Slate", color = "Slate" },
		{ component = "Sign", name = "SignBoard", shape = "Block", size = { 10, 2, 0.3 }, pos = { 0, 10.5, -12.5 }, collide = false, material = "Wood", color = "PlotAccent", castShadow = true },
		{ component = "Sign", name = "SignChainL", shape = "Block", size = { 0.12, 1, 0.12 }, pos = { -4, 12, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Sign", name = "SignChainR", shape = "Block", size = { 0.12, 1, 0.12 }, pos = { 4, 12, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Lanterns", name = "LanternChain1", shape = "Block", size = { 0.1, 1.2, 0.1 }, pos = { -11, 11.9, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Lanterns", name = "LanternFrame1", shape = "Block", size = { 0.8, 1, 0.8 }, pos = { -11, 10.8, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Lanterns", name = "LanternFlame1", shape = "Ball", size = { 0.4, 0.4, 0.4 }, pos = { -11, 10.8, -12.5 }, collide = false, material = "Neon", color = "Flame" },
		{ component = "Lanterns", name = "LanternChain2", shape = "Block", size = { 0.1, 1.2, 0.1 }, pos = { 11, 11.9, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Lanterns", name = "LanternFrame2", shape = "Block", size = { 0.8, 1, 0.8 }, pos = { 11, 10.8, -12.5 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Lanterns", name = "LanternFlame2", shape = "Ball", size = { 0.4, 0.4, 0.4 }, pos = { 11, 10.8, -12.5 }, collide = false, material = "Neon", color = "Flame" },
		{ component = "Decor", name = "ToolRack", shape = "Block", size = { 4, 2.5, 0.2 }, pos = { 12.5, 6, 16.9 }, collide = false, material = "Wood", color = "Timber" },
		{ component = "Decor", name = "Hammer1Handle", shape = "Block", size = { 0.15, 1.6, 0.15 }, pos = { 11.3, 5.8, 16.72 }, collide = false, material = "Wood", color = "Timber" },
		{ component = "Decor", name = "Hammer1Head", shape = "Block", size = { 0.7, 0.35, 0.35 }, pos = { 11.3, 6.7, 16.72 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Decor", name = "Hammer2Handle", shape = "Block", size = { 0.15, 1.4, 0.15 }, pos = { 12.4, 5.9, 16.72 }, collide = false, material = "Wood", color = "Timber" },
		{ component = "Decor", name = "Hammer2Head", shape = "Block", size = { 0.5, 0.3, 0.3 }, pos = { 12.4, 6.7, 16.72 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Decor", name = "TongsA", shape = "Block", size = { 0.1, 1.8, 0.1 }, pos = { 13.6, 5.9, 16.72 }, rot = { 0, 0, 8 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Decor", name = "TongsB", shape = "Block", size = { 0.1, 1.8, 0.1 }, pos = { 13.8, 5.9, 16.72 }, rot = { 0, 0, -8 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Decor", name = "Coal1", shape = "Ball", size = { 0.9, 0.9, 0.9 }, pos = { -4.4, 0.95, 14.6 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Decor", name = "Coal2", shape = "Ball", size = { 0.8, 0.8, 0.8 }, pos = { -3.6, 0.9, 15.2 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Decor", name = "Coal3", shape = "Ball", size = { 0.7, 0.7, 0.7 }, pos = { -4.9, 0.85, 15.5 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Decor", name = "Coal4", shape = "Ball", size = { 0.7, 0.7, 0.7 }, pos = { -4, 1.5, 15 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Decor", name = "Coal5", shape = "Ball", size = { 0.6, 0.6, 0.6 }, pos = { -3.3, 0.8, 14.2 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Decor", name = "CrateA", shape = "Block", size = { 2.2, 2.2, 2.2 }, pos = { 14.5, 1.6, 15.2 }, collide = true, material = "WoodPlanks", color = "Planks" },
		{ component = "Decor", name = "CrateB", shape = "Block", size = { 2, 2, 2 }, pos = { 14.6, 3.7, 15.1 }, rot = { 0, 12, 0 }, collide = true, material = "WoodPlanks", color = "Planks" },
		{ component = "Spawn", name = "HomeSpawn", shape = "Block", size = { 4, 0.2, 4 }, pos = { 0, 0.4, -4 }, rot = { 0, 180, 0 }, collide = false, material = "SmoothPlastic", color = "Slate" },
		{ component = "Furnace", name = "Body", shape = "Block", size = { 7, 6, 5 }, pos = { 0, 3, 2.5 }, collide = true, material = "Brick", color = "BrickDark" },
		{ component = "Furnace", name = "Hood", shape = "Block", size = { 5, 3.5, 4 }, pos = { 0, 7.75, 3 }, collide = true, material = "Brick", color = "BrickDark" },
		{ component = "Furnace", name = "Mouth", shape = "Block", size = { 3, 2.2, 0.3 }, pos = { 0, 2.6, -0.05 }, collide = false, material = "Slate", color = "Soot" },
		{ component = "Furnace", name = "CoalBed", shape = "Block", size = { 2.6, 0.35, 0.8 }, pos = { 0, 1.65, -0.2 }, collide = false, material = "Neon", color = "Ember" },
		{ component = "Furnace", name = "Bellows", shape = "Wedge", size = { 1.6, 0.9, 2.4 }, pos = { 4.6, 0.45, 0.8 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Furnace", name = "Crucible", shape = "Cylinder", size = { 0.8, 0.9, 0.9 }, pos = { 0, 2.2, -0.35 }, rot = { 0, 0, 90 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Anvil", name = "Stump", shape = "Cylinder", size = { 1.5, 2.2, 2.2 }, pos = { 0, 0.75, 0 }, rot = { 0, 0, 90 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Anvil", name = "Base", shape = "Block", size = { 1.6, 0.5, 1.1 }, pos = { 0, 1.75, 0 }, collide = true, material = "Metal", color = "IronDark" },
		{ component = "Anvil", name = "Waist", shape = "Block", size = { 0.9, 0.55, 0.7 }, pos = { 0, 2.275, 0 }, collide = true, material = "Metal", color = "IronDark" },
		{ component = "Anvil", name = "Face", shape = "Block", size = { 2.4, 0.45, 0.95 }, pos = { 0, 2.775, 0 }, collide = true, material = "Metal", color = "IronDark" },
		{ component = "Anvil", name = "Horn", shape = "Wedge", size = { 0.7, 0.45, 1.1 }, pos = { 1.75, 2.775, 0 }, rot = { 0, -90, 0 }, collide = true, material = "Metal", color = "IronDark" },
		{ component = "Anvil", name = "Barrel", shape = "Cylinder", size = { 2, 1.6, 1.6 }, pos = { 3.4, 1, 1.4 }, rot = { 0, 0, 90 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Anvil", name = "Water", shape = "Cylinder", size = { 0.1, 1.4, 1.4 }, pos = { 3.4, 1.95, 1.4 }, rot = { 0, 0, 90 }, collide = false, material = "Glass", color = "Water" },
		{ component = "Grindstone", name = "LegL", shape = "Block", size = { 0.35, 2.6, 1.4 }, pos = { -0.6, 1.3, 0 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Grindstone", name = "LegR", shape = "Block", size = { 0.35, 2.6, 1.4 }, pos = { 0.6, 1.3, 0 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Grindstone", name = "Axle", shape = "Cylinder", size = { 1.8, 0.22, 0.22 }, pos = { 0, 2.6, 0 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "Grindstone", name = "Wheel", shape = "Cylinder", size = { 0.45, 2.6, 2.6 }, pos = { 0, 2.6, 0 }, collide = true, material = "Slate", color = "Stone" },
		{ component = "Grindstone", name = "Trough", shape = "Block", size = { 0.9, 0.5, 2 }, pos = { 0, 0.85, 0 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "Grindstone", name = "Crank", shape = "Block", size = { 0.15, 0.15, 0.7 }, pos = { 1, 2.6, -0.3 }, collide = false, material = "Metal", color = "IronDark" },
		{ component = "DraftingTable", name = "Top", shape = "Block", size = { 4, 0.25, 2.4 }, pos = { 0, 3, 0.2 }, rot = { -12, 0, 0 }, collide = true, material = "Wood", color = "Planks" },
		{ component = "DraftingTable", name = "Leg1", shape = "Block", size = { 0.25, 2.9, 0.25 }, pos = { -1.75, 1.45, -0.8 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "DraftingTable", name = "Leg2", shape = "Block", size = { 0.25, 2.9, 0.25 }, pos = { 1.75, 1.45, -0.8 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "DraftingTable", name = "Leg3", shape = "Block", size = { 0.25, 2.9, 0.25 }, pos = { -1.75, 1.45, 1.2 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "DraftingTable", name = "Leg4", shape = "Block", size = { 0.25, 2.9, 0.25 }, pos = { 1.75, 1.45, 1.2 }, collide = true, material = "Wood", color = "Timber" },
		{ component = "DraftingTable", name = "Parchment", shape = "Block", size = { 2.6, 0.02, 1.8 }, pos = { 0, 3.14, 0.2 }, rot = { -12, 0, 0 }, collide = false, material = "SmoothPlastic", color = "Parchment" },
		{ component = "DraftingTable", name = "InkPot", shape = "Cylinder", size = { 0.3, 0.3, 0.3 }, pos = { 1.6, 3.38, 0.95 }, rot = { 0, 0, 90 }, collide = false, material = "Glass", color = "Soot" },
		{ component = "DraftingTable", name = "Candle", shape = "Cylinder", size = { 0.5, 0.18, 0.18 }, pos = { -1.6, 3.5, 0.95 }, rot = { 0, 0, 90 }, collide = false, material = "SmoothPlastic", color = "Parchment" },
		{ component = "DraftingTable", name = "CandleFlame", shape = "Ball", size = { 0.16, 0.16, 0.16 }, pos = { -1.6, 3.83, 0.95 }, collide = false, material = "Neon", color = "Flame" },
		{ component = "Stand", name = "Plinth", shape = "Block", size = { 2, 1.2, 2 }, pos = { 0, 0.6, 0 }, collide = true, material = "Slate", color = "Stone" },
		{ component = "Stand", name = "Cap", shape = "Block", size = { 2.3, 0.2, 2.3 }, pos = { 0, 1.3, 0 }, collide = true, material = "Slate", color = "Stone" },
		{ component = "Stand", name = "Band", shape = "Block", size = { 2.04, 0.12, 2.04 }, pos = { 0, 0.95, 0 }, collide = false, material = "Neon", color = "Rarity" }, -- material per Presentation.RARITY_FX
		{ component = "Stand", name = "Nameplate", shape = "Block", size = { 1.6, 0.45, 0.08 }, pos = { 0, 0.75, -1.06 }, rot = { 15, 0, 0 }, collide = false, material = "Wood", color = "Planks" },
	},

	-- ── part flags (E-S7.1) ────────────────────────────────────────────────────────────────────────────────────
	PART_DEFAULTS = { anchored = true, locked = true, canTouch = false, surfaces = "Smooth" }, -- every part
	-- Structure: the `collide = true` rows (pad, floors, walls, posts, beams, roof, gables, chimney, crates, station
	-- bodies, plinths, caps) and the plaza trunks. Decor: the `collide = false` rows and the plaza crowns; the sign
	-- board alone casts a shadow. Item: displayed item and workpiece parts. Barrier: the boundary barrier (the engine
	-- always queries colliding parts).
	PART_FLAGS = {
		Structure = { canCollide = true, canQuery = true, castShadow = true },
		Decor = { canCollide = false, canQuery = false, castShadow = false },
		Item = { canCollide = false, canQuery = false, castShadow = true },
		InspectHitbox = { canCollide = false, canQuery = true, castShadow = false, transparency = 1 },
		Barrier = { canCollide = true, canQuery = true, castShadow = false, transparency = 1 },
	},
	-- the HomeSpawn row is a SpawnLocation: invisible, non-colliding, its top flush with the floor at HOME_POSE (§13.3)
	HOME_SPAWN = { transparency = 1, canQuery = false, neutral = true, duration = 0 },

	-- ── plaza (E-S7.1, world space; no SpawnLocation: players spawn at their plot's HomeSpawn) ──────────────────
	-- The discs are walkable ground (the plaza disc's top is y = 0). Lamps, trees and boundary segments repeat
	-- `count` times around the plaza centre at `radius` (boundary segment k at angle stepDeg·k, its long axis on the
	-- tangent); their parts' `pos` is above the instance's base point on the ground ("upright" cylinders stand on it,
	-- crowns at +8 and +10.5, the barrier above the wall). E-S7.1 gives no lamp or tree angles, no offsets for the
	-- lamp's arm, lantern and flame, and no material or colour for lamp parts and trunks: those fields are nil.
	PLAZA = {
		groundDisc = {
			shape = "Cylinder",
			size = { 1, GROUND_DISC_DIAMETER, GROUND_DISC_DIAMETER },
			pos = { 0, -0.55, 0 },
			rot = { 0, 0, 90 },
			collide = true,
			material = "Grass",
			color = "Grass",
		},
		plazaDisc = {
			shape = "Cylinder",
			size = { 1, 2 * PLAZA_RADIUS, 2 * PLAZA_RADIUS },
			pos = { 0, -0.5, 0 },
			rot = { 0, 0, 90 },
			collide = true,
			material = "Cobblestone",
			color = "PlazaStone",
		},
		lamps = {
			count = 8,
			radius = 60,
			post = { shape = "Cylinder", size = { 9, 0.5, 0.5 }, pos = { 0, 4.5, 0 }, rot = { 0, 0, 90 } },
			arm = { shape = "Block", size = { 0.3, 0.3, 1.6 }, collide = false },
			lantern = { shape = "Block", size = { 0.8, 1, 0.8 }, collide = false },
			-- the flame carries the LIGHTS.plazaLamp PointLight
			flame = { shape = "Ball", size = { 0.45, 0.45, 0.45 }, collide = false, material = "Neon" },
		},
		trees = {
			count = 8,
			radius = 92,
			trunk = { shape = "Cylinder", size = { 7, 1.2, 1.2 }, pos = { 0, 3.5, 0 }, rot = { 0, 0, 90 }, collide = true },
			crowns = {
				{ shape = "Ball", size = { 6, 6, 6 }, pos = { 0, 8, 0 }, collide = false, material = "Grass", color = "Foliage" },
				{
					shape = "Ball",
					size = { 4.5, 4.5, 4.5 },
					pos = { 0, 10.5, 0 },
					collide = false,
					material = "Grass",
					color = "Foliage",
				},
			},
		},
		boundary = {
			count = 36,
			stepDeg = 10,
			radius = WORLD_WALL_RADIUS,
			wall = {
				shape = "Block",
				size = { 20.6, 3, 1.2 },
				pos = { 0, 1.5, 0 },
				collide = true,
				material = "Cobblestone",
				color = "PlazaStone",
			},
			-- invisible and colliding (PART_FLAGS.Barrier), on top of the wall
			barrier = { shape = "Block", size = { 20.6, 27, 1.2 }, pos = { 0, 16.5, 0 }, collide = true },
		},
	},
	RESERVED_FLOOR = { -- Phase 2 stations (plot-local; kept free); a second grindstone wheel for Finishing joins them
		{ name = "QuenchTrough", pos = { 3.4, 0.5, 9.4 } }, -- beside the anvil barrel
		{ name = "AssemblyBench", pos = { 13.5, 0.5, 0 }, yaw = 90 }, -- mirrors the drafting table
	},

	-- ── look (§13.11, E-S7.1): built-in materials only, no MaterialVariant, SurfaceAppearance, mesh or decal ────
	PALETTE = {
		{ token = "Cobble", color = { 118, 110, 102 }, materials = { "Cobblestone" } }, -- plot pads
		{ token = "PlazaStone", color = { 160, 150, 136 }, materials = { "Cobblestone" } }, -- plaza disc, boundary wall
		{ token = "Grass", color = { 84, 104, 62 }, materials = { "Grass" } }, -- ground disc
		{ token = "Foliage", color = { 72, 96, 52 }, materials = { "Grass" } }, -- tree crowns
		{ token = "Slate", color = { 92, 90, 88 }, materials = { "Slate" } }, -- forge floor, chimney cap
		{ token = "Planks", color = { 124, 88, 58 }, materials = { "WoodPlanks", "Wood" } }, -- floors, crates, tables
		{ token = "Brick", color = { 134, 82, 60 }, materials = { "Brick" } }, -- walls, gables
		{ token = "BrickDark", color = { 96, 60, 48 }, materials = { "Brick" } }, -- furnace, chimney
		{ token = "Timber", color = { 86, 60, 40 }, materials = { "Wood" } }, -- posts, beams, stump, legs, tools
		{ token = "RoofTile", color = { 112, 52, 40 }, materials = { "Slate" } }, -- roof slabs
		{ token = "IronDark", color = { 58, 58, 62 }, materials = { "Metal" } }, -- anvil, chains, lantern frames, tool heads
		{ token = "Soot", color = { 26, 22, 20 }, materials = { "Slate" } }, -- furnace mouth, coal
		{ token = "Ember", color = { 255, 104, 32 }, materials = { "Neon" } }, -- coal bed (lit plots)
		{ token = "Stone", color = { 150, 144, 136 }, materials = { "Slate" } }, -- plinths, grindstone wheel
		{ token = "Parchment", color = { 232, 220, 190 }, materials = { "SmoothPlastic" } }, -- parchment, candle
		{ token = "Flame", color = { 255, 176, 92 }, materials = { "Neon" } }, -- lantern and candle flames
		{ token = "Water", color = { 64, 110, 140 }, materials = { "Glass" } }, -- barrel water
	},
	PLOT_ACCENTS = { -- sign board colour per plot, so plots tell apart
		{ 150, 52, 44 }, -- 1 crimson
		{ 52, 84, 150 }, -- 2 azure
		{ 56, 112, 64 }, -- 3 forest
		{ 176, 128, 44 }, -- 4 amber
		{ 104, 64, 136 }, -- 5 violet
		{ 44, 120, 124 }, -- 6 teal
		{ 160, 92, 56 }, -- 7 copper
		{ 96, 104, 112 }, -- 8 slate
	},
	SIGN = { -- SignBoard front-face SurfaceGui (500 × 100 px); the stand nameplates use the same style
		face = "Front",
		pixelsPerStud = 50,
		titleMaxTextSize = 52, -- px, TextScaled
		subtitleMaxTextSize = 26, -- px
		font = "Merriweather", -- Font.fromEnum(Enum.Font.Merriweather), Bold; §12 may swap it for its font token
		fontWeight = "Bold",
		textColor = { 245, 226, 190 },
		vacantTitleColor = { 190, 180, 165 },
		strokeColor = { 0, 0, 0 }, -- UIStroke
		strokeTransparency = 0.5,
		lightInfluence = 0.4,
		brightness = 1.2,
		richText = false, -- player text: RichText and AutoLocalize off (§13.3)
		autoLocalize = false,
		titleSuffix = "'s Smithy", -- "<DisplayName>'s Smithy"
		vacantTitle = "Vacant Smithy",
		subtitlePrefix = "@", -- "@<Name>", unless equal to the display name
	},

	-- ── Lighting (§13.11, E-S7.1): set by WorldBuilder, replicates; no Sky instance (built-in sky) ──────────────
	CLOCK_TIME = CLOCK_TIME,
	LIGHTING = {
		lightingStyle = "Realistic",
		prioritizeLightingQuality = true,
		clockTime = CLOCK_TIME,
		geographicLatitude = 30,
		brightness = 2,
		ambient = { 44, 36, 32 },
		outdoorAmbient = { 128, 112, 100 },
		colorShiftTop = { 255, 220, 180 },
		environmentDiffuseScale = 0.5,
		environmentSpecularScale = 0.8,
		shadowSoftness = 0.3,
		globalShadows = true,
		exposureCompensation = 0,
		sky = false,
		-- the four children, named LIGHTING_FX in this order (Atmosphere, ColorCorrection, Bloom, SunRays)
		atmosphere = {
			density = 0.26,
			offset = 0.1,
			color = { 199, 170, 146 },
			decay = { 110, 86, 70 },
			glare = 0.2,
			haze = 1.2,
		},
		grade = { brightness = 0.02, contrast = 0.08, saturation = 0.05, tintColor = { 255, 244, 232 } },
		bloom = { intensity = 0.5, size = 24, threshold = 1.3 },
		sunRays = { intensity = 0.03, spread = 0.5 },
	},
	-- the named Lighting children the editor neutralises while it is open (§11.2)
	LIGHTING_FX = { "BS_Atmosphere", "BS_Grade", "BS_Bloom", "BS_SunRays" },

	-- ── glow and lights (E-S7.1); station activity raises them (Presentation.STATION_ACTIVITY) ──────────────────
	FORGE_GLOW = { -- a lit (owned) plot: the furnace light is the only shadow caster
		fire = { size = 5, heat = 9, color = { 255, 110, 40 }, secondaryColor = { 255, 190, 90 } }, -- coal bed Fire
		light = { color = { 255, 140, 60 }, brightness = 3, range = 18, shadows = true }, -- coal bed PointLight
		embers = { -- coal bed "Embers" ParticleEmitter, default texture
			rate = 8,
			lifetime = { 1.2, 2.0 },
			speed = { 1.5, 3 },
			size = { 0.10, 0 },
			lightEmission = 1,
			color = { { 255, 160, 60 }, { 255, 60, 20 } },
			acceleration = { 0, 2, 0 },
			spreadAngle = { 25, 25 },
		},
		smoke = { color = { 70, 66, 62 }, opacity = 0.12, riseVelocity = 4, size = 4 }, -- chimney Smoke
	},
	LIGHTS = { -- PointLights; `flicker` lights carry the BS_Flicker tag
		lantern = { color = { 255, 176, 100 }, brightness = 1.3, range = 16, flicker = true },
		candle = { color = { 255, 190, 120 }, brightness = 0.9, range = 8, flicker = true },
		plazaLamp = { color = { 255, 190, 130 }, brightness = 1.2, range = 22, flicker = false },
	},
	SPARKS = { -- anvil and grindstone "Sparks" emitters on the WorkAttachment, default texture; Rate 0 unless active
		rate = 0,
		lifetime = { 0.25, 0.5 },
		speed = { 8, 14 },
		size = 0.06,
		lightEmission = 1,
		color = { 255, 200, 120 },
		acceleration = { 0, -30, 0 },
		spreadAngle = { 60, 60 },
	},
	VACANT_PLOT = { -- a vacant plot is cold: coal-bed Fire, lights, embers and smoke off
		coalBed = { material = "Slate", color = { 60, 36, 28 } },
		lanternFlame = { material = "SmoothPlastic", color = { 90, 80, 70 } },
	},
	-- lanterns flicker client-side: base·(1 + FLICKER_AMPLITUDE·math.noise(t·FLICKER_FREQUENCY, seed)), updated at
	-- FLICKER_HZ for lights within FLICKER_RADIUS of the camera
	FLICKER_AMPLITUDE = 0.08, -- fraction of the base brightness: a subtle flame flicker
	FLICKER_FREQUENCY = 6, -- 1/s, the math.noise frequency
	FLICKER_HZ = 20, -- Hz, the client update rate of flickering lights
	FLICKER_RADIUS = 80, -- studs: only lights near the camera flicker
}

return Catalog.deepFreeze(World)
