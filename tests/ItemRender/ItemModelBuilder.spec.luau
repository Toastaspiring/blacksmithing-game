--!strict
-- ItemRender/ItemModelBuilder (SPEC §13.7, §13.4, §3.4): the Roblox-bound builder on tests/ItemRender/FakeRoblox, which
-- models what the engine does with each property (float32 vectors and CFrames, type-checked assignments). The real
-- engine sees it in S-PAR-01's build check.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Blueprints = require("../fixtures/Blueprints")
local Materials = require("../../src/shared/Definitions/Materials")
local Presentation = require("../../src/shared/Definitions/Presentation")
local World = require("../../src/shared/Definitions/World")
local Quat = require("../../src/shared/Blueprint/Quat")
local RenderPlan = require("../../src/shared/ItemRender/RenderPlan")
local FakeRoblox = require("./FakeRoblox")

local fromBlueprint: (parts: any, opts: any?) -> (any, any) = RenderPlan.fromBlueprint :: any
local primitive: (part: any, anchor: any, scale: any) -> (any, any) = RenderPlan.primitive :: any

local FLOAT32 = 2e-5 -- studs: rounding of float32 components near the pivots used here
local R = 0.70710678118654757

local function part(id: number, shape: string, material: string, rot: { number }?): any
	return {
		id = id,
		slot = "Blade",
		shape = shape,
		material = material,
		pos = { 0.5, 1.5, -0.25 },
		rot = rot or { 0, 0, 0, 1 },
		size = { 0.5, 1, 0.25 },
	}
end

local function vecNear(v: any, x: number, y: number, z: number, tol: number, what: string)
	A.near(v.X, x, tol, what .. ".X")
	A.near(v.Y, y, tol, what .. ".Y")
	A.near(v.Z, z, tol, what .. ".Z")
end

local function setup(): (any, any)
	local world = FakeRoblox.new()
	return world, world.module("Blacksmith/ItemRender/ItemModelBuilder")
end

-- The CFrame of a primitive's Part at identity, for the expected rotations.
local function planPrim(p: any): any
	local prim, err = primitive(p, { 0, 0, 0 }, 1)
	A.truthy(prim, tostring(err))
	return prim
end

return Test.suite("ItemRender/ItemModelBuilder", function(t)
	t.it("is frozen, with the two functions of §13.7 M2 needs", function()
		local _, Builder = setup()
		A.truthy(table.isfrozen(Builder), "frozen like the other modules")
		A.eq(type(Builder.buildPart), "function", "buildPart")
		A.eq(type(Builder.applyPrimitive), "function", "applyPrimitive")
	end)

	t.it("buildPart: a new, unparented Part with the item flags of Definitions/World", function()
		local world, Builder = setup()
		local inst = Builder.buildPart(planPrim(part(3, "Block", "Iron")), world.env.CFrame.new())
		local defaults, flags = World.PART_DEFAULTS, World.PART_FLAGS.Item
		A.eq(inst.ClassName, "Part", "class")
		A.eq(inst.Parent, nil, "builds unparented")
		A.eq(inst.Anchored, defaults.anchored, "Anchored")
		A.eq(inst.Locked, defaults.locked, "Locked")
		A.eq(inst.CanTouch, defaults.canTouch, "CanTouch")
		A.eq(inst.CanCollide, flags.canCollide, "CanCollide")
		A.eq(inst.CanQuery, flags.canQuery, "CanQuery")
		A.eq(inst.CastShadow, flags.castShadow, "CastShadow")
		for _, face in { "Top", "Bottom", "Front", "Back", "Left", "Right" } do
			A.eq(inst[face .. "Surface"].Name, defaults.surfaces, face .. "Surface")
		end
		A.eq(inst.Transparency, 0, "a part stays opaque unless a caller says otherwise")
	end)

	t.it("applyPrimitive: Name P%02d_<slot>, PartId, Shape, Size, CFrame and look, every shape and material", function()
		local world, Builder = setup()
		local env = world.env
		local id = 0
		for _, shape in { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" } do
			for _, def in Materials.enabled do
				id += 1
				local p = part(id, shape, def.id, { 0, 0, R, R })
				local prim = planPrim(p)
				local inst = Builder.buildPart(prim, env.CFrame.new())
				A.eq(inst.Name, string.format("P%02d_Blade", id), "Name")
				A.eq(inst:GetAttribute("PartId"), id, "PartId")
				A.eq(inst.Shape.Name, shape, "Shape")
				vecNear(inst.Size, 0.5, 1, 0.25, FLOAT32, "Size as stored")
				vecNear(inst.Position, 0.5, 1.5, -0.25, FLOAT32, "Position")
				-- 90° about Z: local X → +Y, local Y → −X, local Z stays
				vecNear(inst.CFrame.XVector, 0, 1, 0, FLOAT32, "local X")
				vecNear(inst.CFrame.YVector, -1, 0, 0, FLOAT32, "local Y")
				vecNear(inst.CFrame.ZVector, 0, 0, 1, FLOAT32, "local Z")
				A.near(inst.Color.R, def.color[1] / 255, 1e-9, "Color.R")
				A.near(inst.Color.G, def.color[2] / 255, 1e-9, "Color.G")
				A.near(inst.Color.B, def.color[3] / 255, 1e-9, "Color.B")
				A.eq(inst.Material.Name, def.robloxMaterial, "Material")
				A.eq(inst.Reflectance, def.reflectance, "Reflectance")
			end
		end
	end)

	t.it("applyPrimitive on an existing Part changes what the primitive decides, and nothing else", function()
		local world, Builder = setup()
		local env = world.env
		local inst = env.Instance.new("Part")
		inst.CanCollide = true
		inst.Transparency = 0.5
		local holder = env.Instance.new("Folder")
		inst.Parent = holder
		Builder.applyPrimitive(inst, planPrim(part(12, "Wedge", "Steel")), env.CFrame.new(1, 2, 3))
		A.eq(inst.Shape.Name, "Wedge", "Shape applied")
		A.eq(inst.Parent, holder, "Parent left alone")
		A.eq(inst.CanCollide, true, "flags left alone")
		A.eq(inst.Transparency, 0.5, "Transparency left alone")
		vecNear(inst.Position, 1.5, 3.5, 2.75, FLOAT32, "pivot * position")
		-- the editor re-applies on every edit: the second primitive wins completely
		local next_ = part(13, "Ball", "Iron")
		next_.pos = { -1, 0, 0 }
		next_.size = { 0.25, 0.25, 0.25 }
		Builder.applyPrimitive(inst, planPrim(next_), env.CFrame.new())
		A.eq(inst.Name, "P13_Blade", "Name")
		A.eq(inst:GetAttribute("PartId"), 13, "PartId")
		A.eq(inst.Shape.Name, "Ball", "Shape")
		A.eq(inst.Material.Name, "Metal", "Material")
		A.eq(inst.Reflectance, Materials.byId.Iron.reflectance, "Reflectance")
		vecNear(inst.Size, 0.25, 0.25, 0.25, FLOAT32, "Size")
		vecNear(inst.Position, -1, 0, 0, FLOAT32, "Position")
	end)

	t.it("a fixture draws where its records say: position and axes of every Part, at the Origin anchor", function()
		local world, Builder = setup()
		local CFrame = world.env.CFrame
		for _, id in Blueprints.order do
			local parts = Blueprints.get(id).core.parts
			local plan = fromBlueprint(parts, { anchor = "Origin" })
			for i, record in parts do
				local inst = Builder.buildPart(plan.primitives[i], CFrame.new())
				vecNear(inst.Position, record.pos[1], record.pos[2], record.pos[3], FLOAT32, id .. " Position")
				vecNear(inst.Size, record.size[1], record.size[2], record.size[3], FLOAT32, id .. " Size")
				local rot = record.rot
				local x, y, z = Quat.rotate(rot, { 1, 0, 0 }), Quat.rotate(rot, { 0, 1, 0 }), Quat.rotate(rot, { 0, 0, 1 })
				vecNear(inst.CFrame.XVector, x[1], x[2], x[3], FLOAT32, id .. " local X")
				vecNear(inst.CFrame.YVector, y[1], y[2], y[3], FLOAT32, id .. " local Y")
				vecNear(inst.CFrame.ZVector, z[1], z[2], z[3], FLOAT32, id .. " local Z")
			end
		end
	end)

	t.it("pivot * primitive: F2, BaseCenter, on a stand pivot sits on the cradle, +Z face to the viewer", function()
		local world, Builder = setup()
		local env = world.env
		local CFrame, Vector3 = env.CFrame, env.Vector3
		local s = Presentation.ORIENTATIONS.STAND
		local cradle = CFrame.new(10, 2, -5, s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9])
		local plan = fromBlueprint(Blueprints.get("F2").core.parts, { anchor = "BaseCenter" })
		local lowest = math.huge
		for _, prim in plan.primitives do
			local inst = Builder.buildPart(prim, cradle)
			-- all of F2 is axis-aligned Blocks: blueprint +Z becomes −Z, +X becomes −X, +Y stays up
			vecNear(inst.CFrame.ZVector, 0, 0, -1, FLOAT32, "blueprint +Z")
			vecNear(inst.CFrame.XVector, -1, 0, 0, FLOAT32, "blueprint +X")
			vecNear(inst.CFrame.YVector, 0, 1, 0, FLOAT32, "blueprint +Y")
			lowest = math.min(lowest, inst.Position.Y - inst.Size.Y / 2)
			local here = cradle:PointToWorldSpace(Vector3.new(prim.cf[1], prim.cf[2], prim.cf[3]))
			vecNear(inst.Position, here.X, here.Y, here.Z, FLOAT32, "pivot applied after the primitive")
		end
		A.near(lowest, 2, FLOAT32, "the bounds' bottom sits on the cradle")
	end)
end)
