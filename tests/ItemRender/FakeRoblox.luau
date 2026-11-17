--!strict
-- tests/ItemRender/FakeRoblox.luau — a small stand-in for the engine, so Lune can run the Roblox-bound item code and
-- the S-PAR-01 and S-PAR-02 snippets (nobody can run Studio from the test gate). Not a spec (the runner loads *.spec.luau
-- only).
--
-- It proves that this code does what it says against an engine that behaves as documented, and that S-PAR-01 fails when
-- the engine behaves otherwise. It proves nothing about Roblox itself: that is S-PAR-01's job, in Studio.
--
-- Modelled, from SPEC §3.2, §4.3, E-S2.1 and the Creator Docs (independent of Physics/Shapes):
--   datatypes  Vector3 and CFrame (float32 components, as the engine stores them), Color3, enums, PhysicalProperties,
--              OverlapParams
--   instances  the DataModel with the test project's ReplicatedStorage (src/shared, tests/lib, tests/fixtures read from
--              disk; tests/golden as StringValues named by the file's stem, as Rojo maps a .txt file), Part and Folder
--              with type-checked properties: an unknown member or a wrong value type errors
--   RunService IsRunning, IsServer and IsClient: a Play session's Server data model, or its Client one (Options.server)
--   Part       Mass = density × volume, CenterOfMass (local), ExtentsSize (sides below PHYSICS_MIN_DIM enlarged)
--   queries    workspace:GetPartsInPart for a Ball probe: filter, CanQuery, both parts in the Workspace, collision
--              shape at the physics size
--
-- Options.faults plants a wrong engine, one switch per fault (the Faults type); Options.moduleRewrite(path, source)
-- plants a fault in a Roblox-bound module's source, Options.goldenRewrite(stem, text) in a golden's Value. A pure module
-- is the real one, through Lune's require.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

export type Faults = {
	wedgeFlipped: boolean?, -- the Wedge's slope cuts the other half of the box
	cornerApexFlipped: boolean?, -- the CornerWedge's apex sits over −X
	cylinderAxisY: boolean?, -- the Cylinder's axis is local Y
	ballHalfRadius: boolean?, -- the Ball's collision radius is half
	massIgnoresShape: boolean?, -- Mass = density × the block's volume, for every shape
	comNegated: boolean?, -- CenterOfMass has the wrong sign
	comWorld: boolean?, -- CenterOfMass is a world position
	queryNeverHits: boolean?,
	queryAlwaysHits: boolean?,
	physicsSizeMass: boolean?, -- Mass and CenterOfMass come from the physics size (see PHYSICS_MIN_DIM)
	staleQueries: boolean?, -- queries see positions as of the last frame (task.wait)
}
export type Options = {
	faults: Faults?,
	running: boolean?, -- RunService:IsRunning(), default true
	server: boolean?, -- RunService:IsServer(), default true; IsClient() is its inverse
	omit: { string }?, -- module or golden paths left out of the tree, e.g. "src/shared/Physics/Shapes",
	-- "tests/golden/parity.bv1.digest"
	moduleRewrite: ((path: string, source: string) -> string)?,
	goldenRewrite: ((stem: string, text: string) -> string)?,
}
export type World = {
	env: { [string]: any },
	workspace: any,
	printed: { string },
	frames: number,
	parts: () -> { any },
	run: (path: string, rewrite: ((source: string) -> string)?) -> (boolean, any),
	module: (path: string) -> any,
}

local FakeRoblox = {}

local PHYSICS_MIN_DIM = 0.05 -- BasePart.Size: sides below it are physically simulated at it; the visual size stays
local DEFAULT_DENSITY = 0.7 -- Plastic (E-S2.1)

local function f32(x: number): number
	return (string.unpack("<f", string.pack("<f", x)))
end

-- ── datatypes ─────────────────────────────────────────────────────────────────────────────────────────────────────

local Vector3Mt: any = {}
local CFrameMt: any = {}
local Vector3: any = {}
local CFrame: any = {}

function Vector3.new(x: number?, y: number?, z: number?): any
	return setmetatable({ _kind = "Vector3", X = f32(x or 0), Y = f32(y or 0), Z = f32(z or 0) }, Vector3Mt)
end

Vector3Mt.__index = function(self: any, key: string): any
	if key == "Magnitude" then
		return f32(math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z))
	end
	error(tostring(key) .. " is not a valid member of Vector3", 2)
end
Vector3Mt.__add = function(a: any, b: any): any
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Mt.__sub = function(a: any, b: any): any
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Mt.__tostring = function(v: any): string
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end

function CFrame.new(...: any): any
	local n = select("#", ...)
	local a: { any } = { ... }
	local x, y, z = 0, 0, 0
	local m = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	if n == 1 and type(a[1]) == "table" and a[1]._kind == "Vector3" then
		x, y, z = a[1].X, a[1].Y, a[1].Z
	elseif n == 3 or n == 12 then
		x, y, z = a[1], a[2], a[3]
		if n == 12 then
			for k = 1, 9 do
				m[k] = a[3 + k]
			end
		end
	elseif n ~= 0 then
		error("CFrame.new: the fake takes 0, 1 (Vector3), 3 or 12 arguments, got " .. n, 2)
	end
	for k = 1, 9 do
		assert(type(m[k]) == "number", "CFrame.new: a component is not a number")
		m[k] = f32(m[k])
	end
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "CFrame.new: a position is no number")
	return setmetatable({ _kind = "CFrame", _x = f32(x), _y = f32(y), _z = f32(z), _m = m }, CFrameMt)
end

local cframeMethods: any = {}

function cframeMethods.VectorToWorldSpace(self: any, v: any): any
	local m = self._m
	return Vector3.new(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end

function cframeMethods.PointToWorldSpace(self: any, v: any): any
	local m = self._m
	return Vector3.new(self._x + m[1] * v.X + m[2] * v.Y + m[3] * v.Z, self._y + m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		self._z + m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end

function cframeMethods.PointToObjectSpace(self: any, v: any): any
	local m = self._m
	local dx, dy, dz = v.X - self._x, v.Y - self._y, v.Z - self._z
	return Vector3.new(m[1] * dx + m[4] * dy + m[7] * dz, m[2] * dx + m[5] * dy + m[8] * dz,
		m[3] * dx + m[6] * dy + m[9] * dz)
end

CFrameMt.__index = function(self: any, key: string): any
	if key == "Position" then
		return Vector3.new(self._x, self._y, self._z)
	elseif key == "XVector" then
		return Vector3.new(self._m[1], self._m[4], self._m[7])
	elseif key == "YVector" then
		return Vector3.new(self._m[2], self._m[5], self._m[8])
	elseif key == "ZVector" then
		return Vector3.new(self._m[3], self._m[6], self._m[9])
	elseif cframeMethods[key] then
		return cframeMethods[key]
	end
	error(tostring(key) .. " is not a valid member of CFrame", 2)
end
CFrameMt.__mul = function(a: any, b: any): any
	assert(type(b) == "table" and b._kind == "CFrame", "CFrame * x: the fake takes a CFrame")
	local p = a:PointToWorldSpace(Vector3.new(b._x, b._y, b._z))
	local m, n = a._m, b._m
	local r: { number } = {}
	for row = 0, 2 do
		for col = 0, 2 do
			local at = row * 3
			r[at + col + 1] = m[at + 1] * n[col + 1] + m[at + 2] * n[col + 4] + m[at + 3] * n[col + 7]
		end
	end
	return CFrame.new(p.X, p.Y, p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
end

local Color3: any = {}
function Color3.fromRGB(r: number, g: number, b: number): any
	for _, c in { r, g, b } do
		assert(type(c) == "number" and c >= 0 and c <= 255, "Color3.fromRGB: out of range")
	end
	return { _kind = "Color3", R = r / 255, G = g / 255, B = b / 255 }
end

local function enumOf(enumName: string, names: { string }): any
	local items: { [string]: any } = {}
	for _, name in names do
		items[name] = table.freeze({ _kind = "Enum." .. enumName, Name = name })
	end
	return setmetatable({}, {
		__index = function(_: any, key: any): any
			local item = items[key]
			if item == nil then
				error(tostring(key) .. " is not a valid member of Enum." .. enumName, 2)
			end
			return item
		end,
	})
end

local Enum: any = {
	PartType = enumOf("PartType", { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" }),
	Material = enumOf("Material", { "Plastic", "Metal", "Foil", "Glass", "Wood", "Leather", "Neon", "Slate" }),
	SurfaceType = enumOf("SurfaceType", { "Smooth", "Studs", "Inlet" }),
	RaycastFilterType = enumOf("RaycastFilterType", { "Include", "Exclude" }),
}

local PhysicalProperties: any = {}
function PhysicalProperties.new(density: number, friction: number, elasticity: number): any
	assert(density >= 0.01 and density <= 100, "PhysicalProperties.new: density out of range")
	return { _kind = "PhysicalProperties", Density = density, Friction = friction, Elasticity = elasticity }
end

local OverlapParams: any = {}
function OverlapParams.new(): any
	return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, MaxParts = 0, Tolerance = 0 }
end

local function kindOf(v: any): string
	if type(v) == "table" and type(v._kind) == "string" then
		return v._kind
	end
	return type(v)
end

-- ── the engine's solids (§3.2, §4.3), written apart from Physics/Shapes ───────────────────────────────────────────

local function sizeOf(part: any, physics: boolean): (number, number, number)
	local s = part._props.Size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	if physics then
		local least = PHYSICS_MIN_DIM / 2
		hx, hy, hz = math.max(hx, least), math.max(hy, least), math.max(hz, least)
	end
	return hx, hy, hz
end

local function collisionDistance(part: any, faults: Faults, x: number, y: number, z: number): number
	local hx, hy, hz = sizeOf(part, true)
	local shape = part._props.Shape.Name
	if shape == "Ball" then
		local r = math.min(hx, hy, hz)
		return math.sqrt(x * x + y * y + z * z) - (if faults.ballHalfRadius then r / 2 else r)
	elseif shape == "Cylinder" then
		if faults.cylinderAxisY then
			return math.max(math.abs(y) - hy, math.sqrt(x * x + z * z) - math.min(hx, hz))
		end
		return math.max(math.abs(x) - hx, math.sqrt(y * y + z * z) - math.min(hy, hz))
	end
	local box = math.max(math.abs(x) - hx, math.abs(y) - hy, math.abs(z) - hz)
	if shape == "Wedge" then
		local slope = (y * hz - z * hy) / math.sqrt(hy * hy + hz * hz)
		return math.max(box, if faults.wedgeFlipped then -slope else slope)
	elseif shape == "CornerWedge" then
		local sx = if faults.cornerApexFlipped then -x else x
		return math.max(box, (y * hx - sx * hy) / math.sqrt(hx * hx + hy * hy),
			(y * hz + z * hy) / math.sqrt(hy * hy + hz * hz))
	end
	return box
end

local function partVolume(part: any, faults: Faults): number
	local hx, hy, hz = sizeOf(part, faults.physicsSizeMass == true)
	local box = 8 * hx * hy * hz
	if faults.massIgnoresShape then
		return box
	end
	local shape = part._props.Shape.Name
	if shape == "Wedge" then
		return box / 2
	elseif shape == "CornerWedge" then
		return box / 3
	elseif shape == "Cylinder" then
		local r = math.min(hy, hz)
		return 2 * math.pi * r * r * hx
	elseif shape == "Ball" then
		local r = math.min(hx, hy, hz)
		return 4 * math.pi * r * r * r / 3
	end
	return box
end

local function localCentroid(part: any, faults: Faults): any
	local hx, hy, hz = sizeOf(part, faults.physicsSizeMass == true)
	local shape = part._props.Shape.Name
	local x, y, z = 0, 0, 0
	if shape == "Wedge" then
		y, z = -hy / 3, hz / 3
	elseif shape == "CornerWedge" then
		x, y, z = hx / 4, -hy / 2, -hz / 4
	end
	if faults.comNegated then
		x, y, z = -x, -y, -z
	end
	local c = Vector3.new(x, y, z)
	if faults.comWorld then
		return part._props.CFrame:PointToWorldSpace(c)
	end
	return c
end

-- ── instances ─────────────────────────────────────────────────────────────────────────────────────────────────────

local NAME_ONLY = { Name = "string" }
local WRITABLE: { [string]: { [string]: string } } = {
	Folder = NAME_ONLY,
	ModuleScript = NAME_ONLY,
	StringValue = { Name = "string", Value = "string" },
	Part = {
		Name = "string",
		Anchored = "boolean",
		Locked = "boolean",
		CanCollide = "boolean",
		CanTouch = "boolean",
		CanQuery = "boolean",
		CastShadow = "boolean",
		Transparency = "number",
		Reflectance = "number",
		Size = "Vector3",
		CFrame = "CFrame",
		Color = "Color3",
		Shape = "Enum.PartType",
		Material = "Enum.Material",
		TopSurface = "Enum.SurfaceType",
		BottomSurface = "Enum.SurfaceType",
		FrontSurface = "Enum.SurfaceType",
		BackSurface = "Enum.SurfaceType",
		LeftSurface = "Enum.SurfaceType",
		RightSurface = "Enum.SurfaceType",
		CustomPhysicalProperties = "PhysicalProperties",
	},
}

local function partDefaults(): { [string]: any }
	local studs = Enum.SurfaceType.Studs -- not the real default: a builder must set what it relies on
	return {
		Name = "Part",
		Anchored = false,
		Locked = false,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		CastShadow = true,
		Transparency = 0,
		Reflectance = 0,
		Size = Vector3.new(4, 1.2, 2),
		CFrame = CFrame.new(),
		Color = Color3.fromRGB(163, 162, 165),
		Shape = Enum.PartType.Block,
		Material = Enum.Material.Plastic,
		TopSurface = studs,
		BottomSurface = studs,
		FrontSurface = studs,
		BackSurface = studs,
		LeftSurface = studs,
		RightSurface = studs,
	}
end

-- rawget, typed any: an instance's own fields are not its Roblox members.
local function raw(inst: any, key: string): any
	return rawget(inst, key)
end

local function isInside(inst: any, ancestor: any): boolean
	local cur = raw(inst, "_parent")
	while cur do
		if cur == ancestor then
			return true
		end
		cur = raw(cur, "_parent")
	end
	return false
end

function FakeRoblox.new(options: Options?): World
	local opts: Options = options or {}
	local faults: Faults = opts.faults or {}
	local world: any = { printed = {}, frames = 0 }
	local liveParts: { [any]: boolean } = {}
	local InstanceMt: any = {}
	local methods: any = {}
	local moduleCache: { [any]: any } = {}

	local function setParent(self: any, parent: any)
		local old = raw(self, "_parent")
		if old then
			local list = raw(old, "_children")
			local at = table.find(list, self)
			if at then
				table.remove(list, at)
			end
		end
		rawset(self, "_parent", parent)
		if parent then
			table.insert(raw(parent, "_children"), self)
		end
	end

	local function instance(className: string, name: string, props: { [string]: any }?, extra: { [string]: any }?): any
		local p: { [string]: any } = props or {}
		p.Name = p.Name or name
		local fields: { [string]: any } = { _class = className, _props = p, _children = {}, _attributes = {} }
		if extra then
			for k, v in extra do
				fields[k] = v
			end
		end
		return setmetatable(fields, InstanceMt)
	end

	InstanceMt.__index = function(self: any, key: string): any
		local p = raw(self, "_props")
		local v = p[key]
		if v ~= nil then
			return v
		end
		local class = raw(self, "_class")
		if key == "ClassName" then
			return class
		elseif key == "Parent" then
			return raw(self, "_parent")
		end
		if class == "Part" then
			if key == "Mass" then
				local custom = p.CustomPhysicalProperties
				local density = if custom then custom.Density else DEFAULT_DENSITY
				return f32(density * partVolume(self, faults))
			elseif key == "CenterOfMass" then
				return localCentroid(self, faults)
			elseif key == "Position" then
				return p.CFrame.Position
			elseif key == "ExtentsSize" then
				local hx, hy, hz = sizeOf(self, true)
				return Vector3.new(2 * hx, 2 * hy, 2 * hz)
			elseif key == "CustomPhysicalProperties" then
				return nil
			end
		end
		if methods[key] then
			return methods[key]
		end
		for _, child in raw(self, "_children") do
			if child.Name == key then
				return child
			end
		end
		error(tostring(key) .. " is not a valid member of " .. tostring(p.Name), 2)
	end

	InstanceMt.__newindex = function(self: any, key: string, value: any)
		local class = raw(self, "_class")
		if key == "Parent" then
			setParent(self, value)
			return
		end
		local want = (WRITABLE[class] or NAME_ONLY)[key]
		if want == nil then
			error(string.format("%s cannot be assigned to on a %s (the fake's writable members)", key, class), 2)
		end
		if kindOf(value) ~= want then
			error(string.format("%s.%s: unable to assign a %s, expected %s", class, key, kindOf(value), want), 2)
		end
		raw(self, "_props")[key] = value
	end

	function methods.Destroy(self: any)
		setParent(self, nil)
		liveParts[self] = nil
		local children: { any } = table.clone(raw(self, "_children"))
		for _, child in children do
			child:Destroy()
		end
	end

	function methods.FindFirstChild(self: any, name: string): any
		for _, child in raw(self, "_children") do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function methods.GetChildren(self: any): { any }
		return table.clone(raw(self, "_children"))
	end

	function methods.IsA(self: any, className: string): boolean
		return raw(self, "_class") == className -- the fake has no class tree: exact classes only
	end

	function methods.WaitForChild(self: any, name: string): any
		return methods.FindFirstChild(self, name) or error("the fake would wait forever for " .. name, 2)
	end

	function methods.SetAttribute(self: any, key: string, value: any)
		raw(self, "_attributes")[key] = value
	end

	function methods.GetAttribute(self: any, key: string): any
		return raw(self, "_attributes")[key]
	end

	-- ── services ──────────────────────────────────────────────────────────────────────────────────────────────────

	local function checkJson(v: any, path: string)
		local t = type(v)
		if t == "number" then
			assert(v == v and v ~= math.huge and v ~= -math.huge, "JSONEncode: not a finite number at " .. path)
		elseif t == "table" then
			local n, keys = #v, 0
			for k, x in v do
				keys += 1
				assert(type(k) == "string" or n > 0, "JSONEncode: mixed keys at " .. path)
				checkJson(x, path .. "." .. tostring(k))
			end
			assert(n == 0 or keys == n, "JSONEncode: mixed table at " .. path)
		elseif t ~= "string" and t ~= "boolean" then
			error("JSONEncode: cannot encode a " .. t .. " at " .. path)
		end
	end

	local game = instance("DataModel", "game")
	local workspaceInst = instance("Workspace", "Workspace")
	local replicated = instance("ReplicatedStorage", "ReplicatedStorage")
	local http = instance("HttpService", "HttpService", nil, {})
	local runService = instance("RunService", "RunService", nil, {})
	setParent(workspaceInst, game)
	setParent(replicated, game)

	local services: { [string]: any } = {
		Workspace = workspaceInst,
		ReplicatedStorage = replicated,
		HttpService = http,
		RunService = runService,
	}
	function methods.GetService(_self: any, name: string): any
		return services[name] or error("the fake has no service " .. name, 2)
	end
	function methods.JSONEncode(_self: any, value: any): string
		checkJson(value, "$")
		return serde.encode("json", value)
	end
	function methods.IsRunning(_self: any): boolean
		return opts.running ~= false
	end
	function methods.IsServer(_self: any): boolean
		return opts.server ~= false
	end
	function methods.IsClient(_self: any): boolean
		return opts.server == false
	end

	function methods.GetPartsInPart(_self: any, probe: any, params: any): { any }
		assert(isInside(probe, workspaceInst), "GetPartsInPart: the part must be in the same WorldRoot")
		assert(probe._props.Shape.Name == "Ball", "the fake's GetPartsInPart takes a Ball probe")
		local probeCf = if faults.staleQueries then raw(probe, "_settled") else probe._props.CFrame
		if probeCf == nil then
			return {} -- not seen by the broad phase yet
		end
		local hx, hy, hz = sizeOf(probe, true)
		local radius = math.min(hx, hy, hz)
		local centre = probeCf.Position
		local out: { any } = {}
		assert(params.FilterType == Enum.RaycastFilterType.Include, "the fake's GetPartsInPart takes an Include filter")
		for _, target in params.FilterDescendantsInstances do
			local cf = if faults.staleQueries then raw(target, "_settled") else target._props.CFrame
			if target._props.CanQuery and isInside(target, workspaceInst) and cf ~= nil then
				local l = cf:PointToObjectSpace(centre)
				local hit = collisionDistance(target, faults, l.X, l.Y, l.Z) <= radius
				if faults.queryAlwaysHits then
					hit = true
				elseif faults.queryNeverHits then
					hit = false
				end
				if hit then
					table.insert(out, target)
				end
			end
		end
		return out
	end

	-- ── the module tree of test.project.json ──────────────────────────────────────────────────────────────────────

	local omitted: { [string]: boolean } = {}
	if opts.omit then
		for _, path in opts.omit do
			omitted[path] = true
		end
	end

	local function mapDir(parent: any, name: string, dir: string)
		local folder = instance("Folder", name)
		setParent(folder, parent)
		local entries = fs.readDir(dir)
		table.sort(entries)
		for _, entry in entries do
			local full = dir .. "/" .. entry
			if fs.isDir(full) then
				mapDir(folder, entry, full)
			else
				local base = string.match(entry, "^(.*)%.luau$")
				if base and not string.find(base, ".", 1, true) and not omitted[dir .. "/" .. base] then
					setParent(instance("ModuleScript", base, nil, { _path = dir .. "/" .. base }), folder)
				end
			end
		end
	end
	mapDir(replicated, "Blacksmith", "src/shared")
	local tests = instance("Folder", "BlacksmithTests")
	setParent(tests, replicated)
	mapDir(tests, "lib", "tests/lib")
	mapDir(tests, "fixtures", "tests/fixtures")

	-- tests/golden: Rojo makes each <stem>.txt a StringValue named <stem> holding the file's text.
	local golden = instance("Folder", "golden")
	setParent(golden, tests)
	local goldenFiles = fs.readDir("tests/golden")
	table.sort(goldenFiles)
	for _, entry in goldenFiles do
		local stem = string.match(entry, "^(.*)%.txt$")
		if stem and not omitted["tests/golden/" .. stem] then
			local text = fs.readFile("tests/golden/" .. entry)
			if opts.goldenRewrite then
				text = opts.goldenRewrite(stem, text)
			end
			setParent(instance("StringValue", stem, { Value = text }), golden)
		end
	end

	-- ── the globals a chunk sees ──────────────────────────────────────────────────────────────────────────────────

	local env: { [string]: any } = {
		game = game,
		workspace = workspaceInst,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		PhysicalProperties = PhysicalProperties,
		OverlapParams = OverlapParams,
		print = function(...: any)
			local list = {}
			for k = 1, select("#", ...) do
				list[k] = tostring((select(k, ...)))
			end
			table.insert(world.printed, table.concat(list, " "))
		end,
		task = {
			wait = function(): (number, number)
				world.frames += 1
				for part in liveParts do
					rawset(part, "_settled", if isInside(part, workspaceInst) then part._props.CFrame else nil)
				end
				return 1 / 60, 0
			end,
		},
		Instance = {
			new = function(className: string): any
				if className == "Part" then
					local part = instance("Part", "Part", partDefaults())
					liveParts[part] = true
					return part
				elseif className == "Folder" then
					return instance("Folder", "Folder")
				end
				error("the fake cannot create a " .. className, 2)
			end,
		},
	}

	-- A pure module is the real one; a Roblox-bound one loads here, with the fake as its world.
	env.require = function(moduleScript: any): any
		assert(type(moduleScript) == "table" and raw(moduleScript, "_class") == "ModuleScript",
			"require takes a ModuleScript instance")
		if moduleCache[moduleScript] ~= nil then
			return moduleCache[moduleScript]
		end
		local path: string = raw(moduleScript, "_path")
		local source = fs.readFile(path .. ".luau")
		local bound = string.match(source, "^[^\n]*\n%-%- @roblox%-bound") ~= nil
		local result: any
		if bound then
			if opts.moduleRewrite then
				source = opts.moduleRewrite(path, source)
			end
			local moduleEnv = table.clone(env)
			moduleEnv.script = moduleScript
			result = luau.load(source, { debugName = path, environment = moduleEnv })()
		else
			result = (require :: any)("../../" .. path)
		end
		moduleCache[moduleScript] = result
		return result
	end

	world.env = env
	world.workspace = workspaceInst
	-- The Parts in the Workspace now.
	function world.parts(): { any }
		local out = {}
		for part in liveParts do
			if isInside(part, workspaceInst) then
				table.insert(out, part)
			end
		end
		return out
	end
	-- The instance at a test-project path, e.g. "Blacksmith/ItemRender/ItemModelBuilder" under ReplicatedStorage.
	function world.module(path: string): any
		local cur = replicated
		for _, name in string.split(path, "/") do
			cur = methods.WaitForChild(cur, name)
		end
		return env.require(cur)
	end
	-- Runs a chunk as execute_luau would: (true, its result) or (false, the error it threw).
	function world.run(path: string, rewrite: ((source: string) -> string)?): (boolean, any)
		local source = fs.readFile(path)
		if rewrite then
			source = rewrite(source)
		end
		local chunk = luau.load(source, { debugName = path, environment = env })
		return pcall(chunk)
	end
	return world
end

return FakeRoblox
