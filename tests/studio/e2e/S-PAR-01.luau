--!strict
-- S-PAR-01 (SPEC §14.10, §17.2 V-09, E-S8.6, E-S2.1): engine parity of the five shapes. It proves the shape conventions
-- before anything builds on them: what the game measures (Physics/Shapes, §3.2's solids) is what Roblox makes of the
-- Part that RenderPlan and ItemModelBuilder build from the same PartData. T-RND-01 ties §13.7's Wedge and CornerWedge
-- vertex sets to Shapes' solids; this snippet ties those solids to the engine (§17.2, before the bounds goldens
-- freeze).
--
-- HOW TO RUN. Start a Play session of a place synced from test.project.json (the test place, §14.10), then pass
-- this file's whole text to the Studio MCP's execute_luau with datamodel_type "Server". It needs nothing else: no
-- bridge, no player, no reference data. It yields once per case and takes a few seconds; the seed is fixed, so a re-run
-- draws the same parts and points. It leaves nothing behind. A milestone exit needs 3 fresh Play sessions, all green.
--
-- OUTPUT. One line per assertion, on the console (get_console_output) and in execute_luau's result:
--   [E2E] S-PAR-01 PASS|FAIL {"check": ..., "shape": ..., ...}
-- Per shape, in Definitions/Types' order:
--   build    the Part is what §13.7 and §13.4 say: class, Shape, Size, CFrame, look, name, PartId, item flags,
--            unparented
--   mass     Part.Mass (density 1) = Shapes volume, relative error ≤ Tol.TOL_PARITY_MASS_REL, on SIZES_PER_SHAPE sizes
--   com      the world position of Part.CenterOfMass (a local position) = Shapes centroid, ≤ Tol.TOL_PARITY_COM_ABS
--   overlap  GetPartsInPart agrees with Shapes.sd on POINTS_PER_SIZE margin points per size, 100 %
--   thin     sizes below the engine's physics minimum: the visual Size survives; Mass and CenterOfMass are reported
-- and a last line {"check": "summary"}, FAIL when any line failed. A FAIL line names its first cases (size, rotation,
-- position, values). {"check": "preflight"} means the wrong data model or mode, {"check": "crash"} an uncaught error.
--
-- SIZES. Per BasePart.Size in the Creator Docs, physics treats any side below 0.05 as 0.05, while rendering keeps the
-- true size; collision uses ExtentsSize. MIN_DIM is 0.02, so a legal part can be thinner than the engine's collision
-- shape, while S2 measures the true solid. That is why the 20 sizes of E-S8.6 keep every side in [PHYSICS_MIN_DIM,
-- MAX_DIM]: there the solids are comparable. The thin sizes run apart: nothing in the game reads engine mass or
-- collision of item parts (S2 measures, §4; items are not queryable, §13.4), so what the engine reports for them is a
-- fact to record, not a requirement, and only the Size read-back, which is what gets drawn (E-S7.4), can fail.
--
-- MARGIN POINTS. The probe is a Ball of PROBE_DIAMETER (the smallest that physics does not enlarge). Half the points
-- lie inside the solid by marginIn: the probe's centre is in the target, so the query must hit. Half lie outside by
-- marginOut = probe radius + slack: the whole probe is clear (sd is exact inside and a lower bound outside, §4.3), so
-- the query must miss. The slack is generous on purpose: OverlapParams.Tolerance's largest value, 0.05 studs, as a
-- bound on any contact tolerance inside the query, and for curved solids a share of the radius, so a collision shape
-- that is only close to round passes. A wrong axis, slope, apex, radius or sign shows by far more than that on the
-- larger sizes. All probes move first and one frame passes before the queries, so the result never depends on how fast
-- the engine's broad phase sees a moved part.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ID = "S-PAR-01"
local FOLDER_NAME = "BS_SPar01"
local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

local SIZES_PER_SHAPE = 20 -- E-S8.6
local POINTS_PER_SIZE = 200 -- E-S8.6; half inside, half outside
local MAX_DRAWS_PER_POINT = 64 -- rejection sampling; the worst case accepts about 1 draw in 10

local DENSITY = 1 -- E-S8.6: Mass reads as volume
local FRICTION, ELASTICITY = 0.3, 0.5 -- required by PhysicalProperties.new; they play no part here
local PHYSICS_MIN_DIM = 0.05 -- studs; BasePart.Size: smaller sides are simulated at this size
local PROBE_DIAMETER = PHYSICS_MIN_DIM
local PROBE_RADIUS = PROBE_DIAMETER / 2
local INSIDE_MARGIN = 0.005 -- studs; the smallest solid here, a 0.05 CornerWedge, has an inradius of 0.0146
local OUTSIDE_SLACK = 0.05 -- studs of clear air beyond the probe
local CURVED_SLACK = 0.03 -- × radius, Cylinder and Ball: both margins are at least this
local OUTSIDE_SPREAD = 0.25 -- × half extent; outside points reach this far beyond the solid's box, plus 2 × marginOut
local READBACK_REL = 1e-6 -- sizes: Vector3 is float32 (6e-8), with room to spare
local READBACK_ABS = 1e-3 -- studs, axis components, Reflectance: float32 near WORLD_ORIGIN is about 4e-6
local MAX_REPORTED = 3 -- cases named per FAIL line, so a line stays readable

local WORLD_ORIGIN = Vector3.new(0, 64, 0) -- clear of a default place's ground and spawn; the filter ignores all else

local lines: { string } = {}
local failed = 0

local function emit(ok: boolean, data: { [string]: any })
	local encoded, json = pcall(function(): string
		return HttpService:JSONEncode(data)
	end)
	if not encoded then
		ok = false
		json = HttpService:JSONEncode({
			check = tostring(data.check),
			shape = tostring(data.shape),
			why = tostring(json),
		})
	end
	local line = "[E2E] " .. ID .. (if ok then " PASS " else " FAIL ") .. json
	if not ok then
		failed += 1
	end
	table.insert(lines, line)
	print(line)
end

-- JSON has no NaN or inf, and six digits are enough to read a value.
local function num(x: number): any
	if x ~= x or x == math.huge or x == -math.huge then
		return tostring(x)
	end
	return tonumber(string.format("%.6g", x))
end

local function nums(list: { number }): { any }
	local out = table.create(#list)
	for k = 1, #list do
		out[k] = num(list[k])
	end
	return out
end

local function report(list: { any }, entry: any)
	if #list < MAX_REPORTED then
		table.insert(list, entry)
	end
end

local function run(folder: Folder)
	if not (RunService:IsRunning() and RunService:IsServer()) then
		emit(false, {
			check = "preflight",
			why = "run through execute_luau with datamodel_type Server, in a Play session",
		})
		return
	end

	local Blacksmith = ReplicatedStorage.Blacksmith
	local TestLib = ReplicatedStorage.BlacksmithTests.lib
	local Canonical = require(Blacksmith.Blueprint.Canonical)
	local ItemModelBuilder = require(Blacksmith.ItemRender.ItemModelBuilder)
	local Limits = require(Blacksmith.Definitions.Limits)
	local Quat = require(Blacksmith.Blueprint.Quat)
	local RenderPlan = require(Blacksmith.ItemRender.RenderPlan)
	local Shapes = require(Blacksmith.Physics.Shapes)
	local World = require(Blacksmith.Definitions.World)
	local Dump = require(TestLib.Dump)
	local TestRng = require(TestLib.TestRng)
	local Tol = require(TestLib.Tol)

	local MIN_DIM, MAX_DIM = Limits.MIN_DIM, Limits.MAX_DIM

	-- The first sizes are the ones worth reading by hand; the rest are log-uniform in [PHYSICS_MIN_DIM, MAX_DIM].
	local DESIGNED_SIZES: { { number } } = {
		{ 2, 4, 6 }, -- E-S2.1's probe
		{ 1, 1, 1 },
		{ 0.16, 2.6, 0.06 }, -- F1's blade
		{ MAX_DIM, MAX_DIM, MAX_DIM },
		{ PHYSICS_MIN_DIM, PHYSICS_MIN_DIM, PHYSICS_MIN_DIM },
	}
	local THIN_SIZES: { { number } } = {
		{ MIN_DIM, 1, 1 },
		{ 1, MIN_DIM, 1 },
		{ 1, 1, MIN_DIM },
		{ MIN_DIM, MIN_DIM, MIN_DIM },
		{ 0.07, 3.4, 0.035 }, -- F3's blade, the thinnest fixture
	}

	local function logUniform(rng: any, lo: number, hi: number): number
		return lo * (hi / lo) ^ rng:float()
	end

	local function randomSize(rng: any): { number }
		return {
			logUniform(rng, PHYSICS_MIN_DIM, MAX_DIM),
			logUniform(rng, PHYSICS_MIN_DIM, MAX_DIM),
			logUniform(rng, PHYSICS_MIN_DIM, MAX_DIM),
		}
	end

	-- A canonical random rotation: a normal 4-vector, normalized (uniform on the sphere of unit quaternions).
	local function randomRot(rng: any): { number }
		local g = { rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }
		return Canonical.quat(Quat.normalize(g))
	end

	-- One case: canonical PartData and the pivot it is drawn at. Case 1 of a shape is axis-aligned, at the origin of
	-- the pivot and with no pivot rotation, so it reads like E-S2.1's probe.
	local function makeCase(rng: any, shape: string, index: number, rawSize: { number }): (any, CFrame)
		local plain = index == 1
		local part: any = {
			id = index,
			slot = "Blade",
			shape = shape,
			material = if index % 2 == 0 then "Steel" else "Iron",
			pos = if plain then { 0, 0, 0 } else { rng:range(-2, 2), rng:range(-2, 2), rng:range(-2, 2) },
			rot = if plain then table.clone(Quat.IDENTITY) else randomRot(rng),
			size = Canonical.canonicalSize(shape :: any, rawSize),
		}
		local turn = if plain then Quat.IDENTITY else randomRot(rng)
		return part, CFrame.new(WORLD_ORIGIN.X, WORLD_ORIGIN.Y, WORLD_ORIGIN.Z, Quat.toMatrix(turn))
	end

	-- Which of the thin sizes' two readings the engine's value fits.
	local function model(fitsTrueSize: boolean, fitsPhysicsSize: boolean): string
		return if fitsTrueSize then "true size" elseif fitsPhysicsSize then "physics size" else "neither"
	end

	-- What a FAIL line needs to rebuild the case.
	local function caseOf(part: any): { [string]: any }
		return { id = part.id, size = nums(part.size), rot = nums(part.rot), pos = nums(part.pos) }
	end

	-- The first thing about a freshly built Part that is not what §13.7 and §13.4 say, or nil.
	local function buildProblem(inst: Part, prim: any, part: any, pivot: CFrame): string?
		local defaults, flags = World.PART_DEFAULTS, World.PART_FLAGS.Item
		local surface = (Enum.SurfaceType :: any)[defaults.surfaces]
		local color = prim.color
		if inst.ClassName ~= "Part" then
			return "ClassName " .. inst.ClassName
		elseif inst.Parent ~= nil then
			return "buildPart parented the Part"
		elseif inst.Shape ~= (Enum.PartType :: any)[part.shape] then
			return "Shape " .. tostring(inst.Shape)
		elseif inst.Material ~= (Enum.Material :: any)[prim.robloxMaterial] then
			return "Material " .. tostring(inst.Material)
		elseif inst.Name ~= string.format("P%02d_%s", part.id, part.slot) then
			return "Name " .. inst.Name
		elseif inst:GetAttribute("PartId") ~= part.id then
			return "attribute PartId " .. tostring(inst:GetAttribute("PartId"))
		elseif inst.Anchored ~= defaults.anchored or inst.Locked ~= defaults.locked
			or inst.CanTouch ~= defaults.canTouch
		then
			return "Anchored, Locked or CanTouch"
		elseif inst.CanCollide ~= flags.canCollide or inst.CanQuery ~= flags.canQuery
			or inst.CastShadow ~= flags.castShadow
		then
			return "CanCollide, CanQuery or CastShadow"
		elseif inst.TopSurface ~= surface or inst.BottomSurface ~= surface or inst.FrontSurface ~= surface
			or inst.BackSurface ~= surface or inst.LeftSurface ~= surface or inst.RightSurface ~= surface
		then
			return "surfaces"
		elseif math.abs(inst.Reflectance - prim.reflectance) > READBACK_ABS then
			return "Reflectance " .. tostring(inst.Reflectance)
		elseif math.abs(inst.Color.R - color[1] / 255) > 1 / 510 or math.abs(inst.Color.G - color[2] / 255) > 1 / 510
			or math.abs(inst.Color.B - color[3] / 255) > 1 / 510
		then
			return "Color " .. tostring(inst.Color)
		end
		local size = { inst.Size.X, inst.Size.Y, inst.Size.Z }
		for k = 1, 3 do
			if math.abs(size[k] - part.size[k]) > READBACK_REL * part.size[k] then
				return "Size " .. tostring(inst.Size)
			end
		end
		-- the Part's frame against the record's, through the pivot: position, then the three local axes
		local want = pivot:PointToWorldSpace(Vector3.new(part.pos[1], part.pos[2], part.pos[3]))
		if (inst.Position - want).Magnitude > READBACK_ABS then
			return "Position " .. tostring(inst.Position)
		end
		local cf = inst.CFrame
		local got = { cf.XVector, cf.YVector, cf.ZVector }
		local unit = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
		for k = 1, 3 do
			local a = Quat.rotate(part.rot, unit[k])
			local axis = pivot:VectorToWorldSpace(Vector3.new(a[1], a[2], a[3]))
			if (got[k] - axis).Magnitude > READBACK_ABS then
				return "CFrame axis " .. k .. " " .. tostring(got[k])
			end
		end
		return nil
	end

	-- Up to n margin points in blueprint space: inside by marginIn, or outside by marginOut.
	local function drawPoints(rng: any, P: Shapes.Prepared, n: number, inside: boolean, marginIn: number,
		marginOut: number): { { number } }
		local out: { { number } } = {}
		local hx, hy, hz = P.hx, P.hy, P.hz
		if not inside then
			local pad, spread = 2 * marginOut, 1 + OUTSIDE_SPREAD
			hx, hy, hz = hx * spread + pad, hy * spread + pad, hz * spread + pad
		end
		for _ = 1, n * MAX_DRAWS_PER_POINT do
			if #out >= n then
				break
			end
			local lx, ly, lz = rng:range(-hx, hx), rng:range(-hy, hy), rng:range(-hz, hz)
			local x, y, z = Shapes.toWorld(P, lx, ly, lz)
			local sd = Shapes.sd(P, x, y, z)
			if (inside and sd <= -marginIn) or (not inside and sd >= marginOut) then
				table.insert(out, { x, y, z, sd, lx, ly, lz })
			end
		end
		return out
	end

	-- ── the probes ────────────────────────────────────────────────────────────────────────────────────────────────

	local probes: { Part } = table.create(POINTS_PER_SIZE)
	for i = 1, POINTS_PER_SIZE do
		local probe = Instance.new("Part")
		probe.Name = "Probe"
		probe.Shape = Enum.PartType.Ball
		probe.Size = Vector3.new(PROBE_DIAMETER, PROBE_DIAMETER, PROBE_DIAMETER)
		probe.Anchored = true
		probe.CanCollide = false
		probe.CanTouch = false
		probe.CastShadow = false
		probe.Transparency = 1
		probe.CFrame = CFrame.new(WORLD_ORIGIN)
		probe.Parent = folder
		probes[i] = probe
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	-- ── one shape ─────────────────────────────────────────────────────────────────────────────────────────────────

	for _, shape in SHAPES do
		local rng = TestRng.new(Dump.fnv1a32(ID .. " " .. shape))
		local buildProblems: { any } = {}
		local buildFailures = 0
		local massWorst, massAt, comWorst, comAt = 0, nil :: any, 0, nil :: any
		local inside, outside, shortfall = 0, 0, 0
		local misses: { any } = {} -- inside points the engine missed, outside points it hit
		local missCount = 0

		-- A case's Part, density 1; nil when the plan refuses the part. A wrong Part is counted and still measured.
		local function buildCase(part: any, pivot: CFrame): Part?
			local prim, planError = RenderPlan.primitive(part, { 0, 0, 0 }, 1)
			if prim == nil then
				buildFailures += 1
				report(buildProblems, { why = "RenderPlan " .. tostring(planError), case = caseOf(part) })
				return nil
			end
			local inst = ItemModelBuilder.buildPart(prim, pivot)
			local why = buildProblem(inst, prim, part, pivot)
			if why then
				buildFailures += 1
				report(buildProblems, { why = why, case = caseOf(part) })
			end
			inst.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY)
			return inst
		end

		for index = 1, SIZES_PER_SHAPE do
			local rawSize = DESIGNED_SIZES[index] or randomSize(rng)
			local part, pivot = makeCase(rng, shape, index, rawSize)
			local P = Shapes.prepare(part, index)
			local target = buildCase(part, pivot)
			if target == nil then
				continue
			end
			local inst = target :: Part
			inst.CanQuery = true -- the one change for the test: item parts are not queryable (§13.4)
			inst.Parent = folder

			local facet = if P.r > 0 then CURVED_SLACK * P.r else 0
			local marginIn = math.max(INSIDE_MARGIN, facet)
			local marginOut = PROBE_RADIUS + math.max(OUTSIDE_SLACK, facet)
			local half = POINTS_PER_SIZE // 2
			local points = drawPoints(rng, P, half, true, marginIn, marginOut)
			local nInside = #points
			for _, q in drawPoints(rng, P, POINTS_PER_SIZE - half, false, marginIn, marginOut) do
				table.insert(points, q)
			end
			shortfall += POINTS_PER_SIZE - #points
			for i, q in points do
				probes[i].CFrame = CFrame.new(pivot:PointToWorldSpace(Vector3.new(q[1], q[2], q[3])))
			end
			task.wait() -- a frame between the moves and the queries, and Studio stays responsive

			local mass = inst.Mass
			local expectedMass = DENSITY * P.volume
			local massRel = math.abs(mass - expectedMass) / expectedMass
			if massRel ~= massRel or massRel > massWorst then -- a NaN counts as the worst possible
				massWorst = if massRel ~= massRel then math.huge else massRel
				massAt = { case = caseOf(part), mass = num(mass), volume = num(P.volume) }
			end

			local com = inst.CFrame:PointToWorldSpace(inst.CenterOfMass)
			local expectedCom = pivot:PointToWorldSpace(Vector3.new(P.gx, P.gy, P.gz))
			local comErr = (com - expectedCom).Magnitude
			if comErr ~= comErr or comErr > comWorst then
				comWorst = if comErr ~= comErr then math.huge else comErr
				comAt = {
					case = caseOf(part),
					centerOfMass = nums({ inst.CenterOfMass.X, inst.CenterOfMass.Y, inst.CenterOfMass.Z }),
					expectedLocal = nums({ P.lcx, P.lcy, P.lcz }),
					atWorld = nums({ com.X, com.Y, com.Z }),
					expectedWorld = nums({ expectedCom.X, expectedCom.Y, expectedCom.Z }),
				}
			end

			params.FilterDescendantsInstances = { inst }
			for i, q in points do
				local hit = table.find(workspace:GetPartsInPart(probes[i], params), inst) ~= nil
				local isInside = i <= nInside
				if isInside then
					inside += 1
				else
					outside += 1
				end
				if hit ~= isInside then
					missCount += 1
					report(misses, {
						expected = if isInside then "hit" else "miss",
						sd = num(q[4]),
						atLocal = nums({ q[5], q[6], q[7] }),
						case = caseOf(part),
					})
				end
			end
			inst:Destroy()
		end

		-- the thin sizes: the same build; Mass and CenterOfMass against the true size and the physics size
		local thin: { any } = {}
		local buildFailuresBeforeThin = buildFailures
		for index, rawSize in THIN_SIZES do
			local part, pivot = makeCase(rng, shape, SIZES_PER_SHAPE + index, rawSize)
			local target = buildCase(part, pivot)
			if target == nil then
				continue
			end
			local inst = target :: Part
			inst.Parent = folder
			local clamped = table.clone(part)
			clamped.size = {
				math.max(PHYSICS_MIN_DIM, part.size[1]),
				math.max(PHYSICS_MIN_DIM, part.size[2]),
				math.max(PHYSICS_MIN_DIM, part.size[3]),
			}
			local exact, enlarged = Shapes.prepare(part, 1), Shapes.prepare(clamped, 1)
			local mass, localCom = inst.Mass, inst.CenterOfMass
			local function comIs(P: Shapes.Prepared): boolean
				local d = Vector3.new(localCom.X - P.lcx, localCom.Y - P.lcy, localCom.Z - P.lcz)
				return d.Magnitude <= Tol.TOL_PARITY_COM_ABS
			end
			local function massIs(P: Shapes.Prepared): boolean
				return math.abs(mass - DENSITY * P.volume) <= Tol.TOL_PARITY_MASS_REL * DENSITY * P.volume
			end
			table.insert(thin, {
				size = nums(part.size),
				extentsSize = nums({ inst.ExtentsSize.X, inst.ExtentsSize.Y, inst.ExtentsSize.Z }),
				mass = num(mass),
				massModel = model(massIs(exact), massIs(enlarged)),
				comModel = model(comIs(exact), comIs(enlarged)),
			})
			inst:Destroy()
		end

		-- ── the assertions of this shape ──────────────────────────────────────────────────────────────────────────

		emit(buildFailures == 0, {
			check = "build",
			shape = shape,
			cases = SIZES_PER_SHAPE + #THIN_SIZES,
			failures = buildFailures,
			first = buildProblems,
		})
		local massData: { [string]: any } = {
			check = "mass",
			shape = shape,
			cases = SIZES_PER_SHAPE,
			worstRel = num(massWorst),
			tol = Tol.TOL_PARITY_MASS_REL,
		}
		local massOk = massWorst <= Tol.TOL_PARITY_MASS_REL
		if not massOk then
			massData.at = massAt
		end
		emit(massOk, massData)
		local comData: { [string]: any } = {
			check = "com",
			shape = shape,
			cases = SIZES_PER_SHAPE,
			worstAbs = num(comWorst),
			tol = Tol.TOL_PARITY_COM_ABS,
		}
		local comOk = comWorst <= Tol.TOL_PARITY_COM_ABS
		if not comOk then
			comData.at = comAt
		end
		emit(comOk, comData)
		local wanted = SIZES_PER_SHAPE * POINTS_PER_SIZE
		emit(missCount == 0 and shortfall == 0 and inside + outside == wanted, {
			check = "overlap",
			shape = shape,
			points = inside + outside,
			wanted = wanted,
			inside = inside,
			outside = outside,
			disagree = missCount,
			first = misses,
		})
		emit(buildFailures == buildFailuresBeforeThin, { check = "thin", shape = shape, cases = #thin, rows = thin })
	end
end

-- ── main ──────────────────────────────────────────────────────────────────────────────────────────────────────────

local started = os.clock()
local leftover = workspace:FindFirstChild(FOLDER_NAME)
if leftover then
	leftover:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = workspace

local ok, err = xpcall(function()
	run(folder)
end, function(e: any): string
	return debug.traceback(tostring(e), 2)
end)
if not ok then
	emit(false, { check = "crash", why = tostring(err) })
end
folder:Destroy()

local count = #lines
emit(failed == 0, {
	check = "summary",
	assertions = count,
	failed = failed,
	sizesPerShape = SIZES_PER_SHAPE,
	pointsPerSize = POINTS_PER_SIZE,
	probeDiameter = PROBE_DIAMETER,
	insideMargin = INSIDE_MARGIN,
	outsideSlack = OUTSIDE_SLACK,
	curvedSlack = CURVED_SLACK,
	seconds = num(os.clock() - started),
})

return table.concat(lines, "\n")
