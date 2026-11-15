--!strict
-- @roblox-bound
-- ItemRender/ItemModelBuilder (SPEC §13.7, §3.4, §13.4; owner S7): the only code that creates item Parts. It draws a
-- RenderPlan's primitives, one to one: always class Part, Shape = Enum.PartType[shape], Size as stored (scaled by the
-- plan), rotation only through the primitive's Quat.toMatrix components, look from the Materials row. Instances are
-- one-way views (§3.4): nothing here reads a value back.
--
--   buildPart       a new, unparented Part with the item flags (§13.4: PART_DEFAULTS and PART_FLAGS.Item in
--                   Definitions/World) and the primitive applied. It never yields; the caller parents it once
--   applyPrimitive  everything a primitive decides, on an existing Part: Name P%02d_<slot>, attribute PartId, Shape,
--                   Size, CFrame = pivot * primitive, Color, Material, Reflectance. Flags, Transparency and Parent are
--                   left alone, so the editor (§11) can call it on its own parts on every edit
--
-- M2 builds these two (S-PAR-01 draws through them). M6 adds, next to them and without changing them, what §13.7 lists:
-- build (a Model of buildPart parts carrying ItemId and Rarity, BuildOptions.transparency), placeholder, setHeat,
-- applyRarityFx and mountInViewport, with the Orientation and BuildOptions types.

local RenderPlan = require(script.Parent:WaitForChild("RenderPlan"))
local World = require(script.Parent.Parent:WaitForChild("Definitions"):WaitForChild("World"))

type RenderPrimitive = RenderPlan.RenderPrimitive

local ItemModelBuilder = {}

-- Shape, then Size, then CFrame: the shape the size is for comes first, and the CFrame written last is what holds.
function ItemModelBuilder.applyPrimitive(part: Part, prim: RenderPrimitive, pivot: CFrame): ()
	local size, cf, rgb = prim.size, prim.cf, prim.color
	part.Name = string.format("P%02d_%s", prim.partId, prim.slot)
	part.Shape = (Enum.PartType :: any)[prim.shape]
	part.Size = Vector3.new(size[1], size[2], size[3])
	part.CFrame = pivot
		* CFrame.new(cf[1], cf[2], cf[3], cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12])
	part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	part.Material = (Enum.Material :: any)[prim.robloxMaterial]
	part.Reflectance = prim.reflectance
	part:SetAttribute("PartId", prim.partId)
end

function ItemModelBuilder.buildPart(prim: RenderPrimitive, pivot: CFrame): Part
	local defaults, flags = World.PART_DEFAULTS, World.PART_FLAGS.Item
	local surface = (Enum.SurfaceType :: any)[defaults.surfaces]
	local part = Instance.new("Part")
	part.Anchored = defaults.anchored
	part.Locked = defaults.locked
	part.CanTouch = defaults.canTouch
	part.CanCollide = flags.canCollide -- before CanQuery: a colliding part is always queried
	part.CanQuery = flags.canQuery
	part.CastShadow = flags.castShadow
	part.TopSurface = surface
	part.BottomSurface = surface
	part.FrontSurface = surface
	part.BackSurface = surface
	part.LeftSurface = surface
	part.RightSurface = surface
	ItemModelBuilder.applyPrimitive(part, prim, pivot)
	return part
end

return table.freeze(ItemModelBuilder)
