--!strict
-- Definitions/Presentation (SPEC §13.6–§13.10, §16.15, E-S7.6; owner S7): item render orientations, rarity FX, heat,
-- workpieces, viewports and the station stage, one deep-frozen table. Rendering only: the BALANCE Manifest excludes
-- this module, and item parts are never recoloured (rarity shows on the stand and in the UI, §13.8).
--   ORIENTATIONS  §13.7: R00..R22 row-major, as in CFrame.new(x, y, z, R00 … R22); column j is where blueprint axis j
--                 points. The names are render presets in capitals, never stored or sent (§2.2 rule 5): `FLAT` is
--                 the workpiece pose, not the editor's Flat view, which is `VIEW_H`.
--   RARITY_FX     E-S7.6, one row per rarity in Rarities order: the stand Band's material, the RarityLight
--                 (PointLight, Rare and above) and RaritySparkles (ParticleEmitter, Epic and above), both direct
--                 children of InspectHitbox, and the Item's Highlight (Legendary and above: data only in the MVP).
--                 Colours are the Rarities rows' (§2.7).
-- Ranges are {min, max} (NumberRange), sequences {start, end}, colours RGB 0–255 (Color3.fromRGB at the edge).

local Catalog = require("./Catalog")
local DT = require("./Types")

type Vec3 = DT.Vec3
type RGB = DT.RGB

export type Range = { number }
export type Orientation = "STAND" | "FLAT" | "VIEW_H" | "VIEW_V" -- ItemModelBuilder's Orientation (§13.7)
export type Anchor = "BaseCenter" | "Center" | "Origin" -- RenderPlan's Anchor (§13.7)
export type RenderPreset = { orientation: Orientation, anchor: Anchor }
-- `pivot` is station-local: Hammering adds the plan's half extent e_z to y; Sharpening subtracts
-- (bladeMax.x − centre.x) and edgeClearance from z (bladeMax.x = plan.slotBounds.Blade.max.x, centre = the plan
-- bounds centre).
export type WorkpieceDef = {
	step: DT.StepId,
	station: DT.StationId,
	model: "Ingots" | "Item", -- Ingots: one INGOT_SIZE block per distinct work-set material, in its colour
	orientation: Orientation?, -- nil: the ingots sit at yaw 0
	anchor: Anchor?,
	pivot: Vec3,
	ingotOffsetX: number?, -- ingots at x ± this
	edgeClearance: number?, -- studs between the blade's +X edge and the wheel rim
}
export type RarityFxDef = {
	rarity: DT.RarityId,
	bandMaterial: string, -- Enum.Material of the stand's Band: Slate (no glow) for Common, Neon from Uncommon up
	light: { range: number, brightness: number }?,
	sparkles: { rate: number, lifetime: Range }?,
	highlight: { outlineTransparency: number, fillTransparency: number? }?,
}

export type Presentation = {
	DISPLAY_SCALE: number,
	VIEWPORT_FOV: number,
	VIEWPORT_MARGIN: number,
	VIEWPORT_LIGHTING: { ambient: RGB, lightColor: RGB, lightDirection: Vec3 },
	ORIENTATIONS: { STAND: { number }, FLAT: { number }, VIEW_H: { number }, VIEW_V: { number } },
	STAND_PRESET: RenderPreset,
	VIEWPORT_PRESET: RenderPreset,
	HEAT_COLOR: RGB,
	HEAT_BLEND: number,
	HEAT_NEON_THRESHOLD: number,
	HEAT_LIGHT_BRIGHTNESS: number,
	HEAT_LIGHT_RANGE: number,
	WORKPIECE_HEAT: { [DT.StepId]: number },
	WORKPIECES: { WorkpieceDef },
	INGOT_SIZE: Vec3,
	PLACEHOLDER_SIZE: number,
	RARITY_FX: { RarityFxDef },
	RARITY_LIGHT: { shadows: boolean },
	RARITY_SPARKLES: {
		shape: string,
		shapeStyle: string,
		size: { number },
		speed: Range,
		drag: number,
		lightEmission: number,
		lightInfluence: number,
		transparency: { number },
	},
	RARITY_HIGHLIGHT: { depthMode: string },
	INSPECT_TURNTABLE_SPEED: number,
	INSPECT_AUTOCLOSE_DISTANCE: number,
	CAM_ENTER_S: number,
	CAM_MOVE_S: number,
	CAM_EXIT_S: number,
	CAM_EASING: { style: string, direction: string, exitDirection: string },
	CAM_EXIT_OFFSET: Vec3,
	CAM_EXIT_LOOK_OFFSET: Vec3,
	WALK_TIMEOUT_S: number,
	ARRIVE_TOLERANCE: number,
	STATION_ACTIVITY: { -- keyed by the StationId that the plot's StationActivity attribute holds (§13.4)
		Furnace: { fireSize: number, fireHeat: number, lightBrightness: number, emberRate: number },
		DraftingTable: { candleBrightness: number },
	},
	ANVIL_SPARK_INTERVAL: number,
	ANVIL_SPARK_COUNT: number,
	GRINDSTONE_SPIN: number,
	GRINDSTONE_SPARK_RATE: number,
}

local Presentation: Presentation = {
	-- ── item rendering and viewports (§13.7) ───────────────────────────────────────────────────────────────────
	DISPLAY_SCALE = 1.0, -- items show at true size on stands and stations
	VIEWPORT_FOV = 30, -- degrees; low distortion in item viewports
	VIEWPORT_MARGIN = 1.08, -- 8 % margin: camera on +Z at d = e_z + m·max(e_x/(a·tan(φ/2)), e_y/tan(φ/2))
	VIEWPORT_LIGHTING = { -- a ViewportFrame renders no lights, particles or post effects; default Sky (asset-free)
		ambient = { 110, 100, 92 },
		lightColor = { 255, 240, 220 },
		lightDirection = { -1, -1, -0.6 },
	},
	ORIENTATIONS = { -- blueprint +X / +Y / +Z become …
		STAND = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }, -- stand −X / up / −Z (toward the viewer)
		FLAT = { 0, 1, 0, 0, 0, 1, 1, 0, 0 }, -- station +Z / +X / up
		VIEW_H = { 0, 1, 0, -1, 0, 0, 0, 0, 1 }, -- down / right / toward the camera (= the editor's Flat view)
		VIEW_V = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, -- right / up / toward the camera (identity)
	},
	STAND_PRESET = { orientation = "STAND", anchor = "BaseCenter" }, -- server-rendered stands: +Z face to the plaza
	VIEWPORT_PRESET = { orientation = "VIEW_H", anchor = "Center" }, -- turntables and tiles (mountInViewport)

	-- ── heat and workpieces (§13.6, E-S7.6) ────────────────────────────────────────────────────────────────────
	-- setHeat(model, h): Color = lerp(base, HEAT_COLOR, HEAT_BLEND·h); Neon if h ≥ HEAT_NEON_THRESHOLD;
	-- Reflectance = base·(1 − h); for h > 0 one PointLight in HEAT_COLOR with Range HEAT_LIGHT_RANGE and
	-- Brightness HEAT_LIGHT_BRIGHTNESS·h
	HEAT_COLOR = { 255, 96, 32 }, -- hot-metal orange
	HEAT_BLEND = 0.85, -- colour lerp factor at h = 1
	HEAT_NEON_THRESHOLD = 0.55, -- heat above which the workpiece turns Neon and blooms
	HEAT_LIGHT_BRIGHTNESS = 2.5, -- × heat; no light at h = 0
	HEAT_LIGHT_RANGE = 8, -- studs; the glow stays on the station
	WORKPIECE_HEAT = { Smelting = 0.9, Hammering = 0.7, Sharpening = 0 }, -- heat 0–1: cooling as the craft goes on
	WORKPIECES = { -- the server's workpiece per step, scale 1 (§13.6)
		{ step = "Smelting", station = "Furnace", model = "Ingots", pivot = { 0, 2.45, -0.35 }, ingotOffsetX = 0.3 },
		{ -- pivot y + e_z: the item lies on the face top
			step = "Hammering",
			station = "Anvil",
			model = "Item",
			orientation = "FLAT",
			anchor = "Center",
			pivot = { 0, 3.0, 0 },
		},
		{ -- pivot z − (bladeMax.x − centre.x) − edgeClearance: the blade's edge against the wheel
			step = "Sharpening",
			station = "Grindstone",
			model = "Item",
			orientation = "FLAT",
			anchor = "Center",
			pivot = { 0, 2.6, -1.3 },
			edgeClearance = 0.05,
		},
	},
	INGOT_SIZE = { 0.5, 0.25, 1.0 }, -- studs; the Smelting workpiece, one per distinct material
	PLACEHOLDER_SIZE = 0.8, -- studs; the grey block shown when a plan fails

	-- ── rarity presentation (§13.8, E-S7.6) ────────────────────────────────────────────────────────────────────
	RARITY_FX = {
		{ rarity = "Common", bandMaterial = "Slate" },
		{ rarity = "Uncommon", bandMaterial = "Neon" },
		{ rarity = "Rare", bandMaterial = "Neon", light = { range = 6, brightness = 0.8 } },
		{
			rarity = "Epic",
			bandMaterial = "Neon",
			light = { range = 7, brightness = 1.1 },
			sparkles = { rate = 3, lifetime = { 0.8, 1.4 } },
		},
		{ -- Legendary, Mythic, Divine: data only in the MVP (the rarities are not enabled)
			rarity = "Legendary",
			bandMaterial = "Neon",
			light = { range = 8, brightness = 1.3 },
			sparkles = { rate = 5, lifetime = { 0.9, 1.5 } },
			highlight = { outlineTransparency = 0.4 },
		},
		{
			rarity = "Mythic",
			bandMaterial = "Neon",
			light = { range = 9, brightness = 1.5 },
			sparkles = { rate = 7, lifetime = { 1.0, 1.6 } },
			highlight = { outlineTransparency = 0.3 },
		},
		{
			rarity = "Divine",
			bandMaterial = "Neon",
			light = { range = 10, brightness = 1.8 },
			sparkles = { rate = 9, lifetime = { 1.0, 1.8 } },
			highlight = { outlineTransparency = 0.2, fillTransparency = 0.85 },
		},
	},
	RARITY_LIGHT = { shadows = false }, -- the RarityLight PointLight, in the rarity colour
	RARITY_SPARKLES = { -- default texture, rarity colour; they spawn inside InspectHitbox, around the blade
		shape = "Box",
		shapeStyle = "Volume",
		size = { 0.12, 0 }, -- start → end
		speed = { 0.1, 0.3 },
		drag = 2,
		lightEmission = 1,
		lightInfluence = 0,
		transparency = { 0.2, 1 }, -- start → end
	},
	RARITY_HIGHLIGHT = { depthMode = "Occluded" },

	-- ── inspect (§13.10) ───────────────────────────────────────────────────────────────────────────────────────
	INSPECT_TURNTABLE_SPEED = 24, -- degrees/s; slow camera orbit about the blade axis in the inspect preview
	INSPECT_AUTOCLOSE_DISTANCE = 16, -- studs; the panel closes when you walk away

	-- ── station stage (§13.6, E-S7.6) ──────────────────────────────────────────────────────────────────────────
	-- enter: camera Scriptable, TweenService on CFrame and FieldOfView to Layout.framing (Camera.Focus set every
	-- frame) while Humanoid:MoveTo(stand point); on MoveToFinished or after WALK_TIMEOUT_S a root farther than
	-- ARRIVE_TOLERANCE from the stand point is placed on it, then turned to face the station; onArrived once both are
	-- done. leave: to root.CFrame * CFrame.new(CAM_EXIT_OFFSET) looking at root.Position + CAM_EXIT_LOOK_OFFSET, then
	-- Custom. Reduced motion: cuts to the same end states.
	CAM_ENTER_S = 0.8, -- s; free camera to the first station
	CAM_MOVE_S = 0.9, -- s; station to station, covers the ≈ 0.6 s walk
	CAM_EXIT_S = 0.6, -- s; back to the free camera
	CAM_EASING = { style = "Sine", direction = "InOut", exitDirection = "Out" }, -- enter and move; leave
	CAM_EXIT_OFFSET = { 0, 2.5, 9 }, -- studs, in the root's frame
	CAM_EXIT_LOOK_OFFSET = { 0, 1.5, 0 }, -- studs, from root.Position
	WALK_TIMEOUT_S = 1.4, -- s; after it the smith is placed on the stand point
	ARRIVE_TOLERANCE = 0.75, -- studs; closer than this, no snap is needed

	-- ── station activity (E-S7.6): values while the plot's StationActivity names the station ───────────────────
	STATION_ACTIVITY = { -- keyed by StationId: the plot's StationActivity value indexes it directly
		Furnace = { -- the server's coal-bed Fire, light and embers, raised from World.FORGE_GLOW's lit values
			fireSize = 8,
			fireHeat = 14,
			lightBrightness = 4.5,
			emberRate = 24,
		},
		DraftingTable = { candleBrightness = 1.2 }, -- raised from World.LIGHTS.candle
	},
	ANVIL_SPARK_INTERVAL = 0.7, -- s; visitors' spark rhythm while Hammering (the owner's follow real strikes)
	ANVIL_SPARK_COUNT = 12, -- particles per burst (Sparks:Emit)
	GRINDSTONE_SPIN = 270, -- degrees/s; the wheel spins locally while Sharpening (the server never moves it)
	GRINDSTONE_SPARK_RATE = 30, -- particles/s while Sharpening (server)
}

return Catalog.deepFreeze(Presentation)
