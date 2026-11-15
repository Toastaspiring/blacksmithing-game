--!strict
-- The S-PAR-01 snippet itself (tests/studio/e2e/S-PAR-01.luau; SPEC §14.10, E-S8.6), run on tests/ItemRender/FakeRoblox
-- since the gate cannot start Studio. On a faithful engine every line passes, in the documented format, leaving nothing
-- behind; on an engine with a planted fault exactly the right lines fail; so S-PAR-01's first real run is a question
-- about Roblox, not about the snippet. That run is M2's exit test and belongs to the test place (SPEC §14.10).

local serde = require("@lune/serde")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local FakeRoblox = require("./FakeRoblox")

local SNIPPET = "tests/studio/e2e/S-PAR-01.luau"
local BUILDER = "src/shared/ItemRender/ItemModelBuilder"
local CHECKS = { "build", "mass", "com", "overlap", "thin" }
local MAX_LINE_BYTES = 2000 -- a line stays readable, and short of any console limit

type Line = { ok: boolean, data: any, text: string }

-- The snippet's run size, cut down for the many fault runs: they look for which lines fail, not for the last point.
local function small(source: string): string
	local out, a = string.gsub(source, "local SIZES_PER_SHAPE = 20", "local SIZES_PER_SHAPE = 6")
	local out2, b = string.gsub(out, "local POINTS_PER_SIZE = 200", "local POINTS_PER_SIZE = 60")
	A.eq(a, 1, "the snippet's SIZES_PER_SHAPE line")
	A.eq(b, 1, "the snippet's POINTS_PER_SIZE line")
	return out2
end

local function parse(world: any): { Line }
	local lines: { Line } = {}
	for _, text in world.printed do
		local verdict, json = string.match(text, "^%[E2E%] S%-PAR%-01 (%u+) ({.*})$")
		A.truthy(verdict == "PASS" or verdict == "FAIL", "the line format, got: " .. text)
		A.truthy(#text <= MAX_LINE_BYTES, "a line of " .. #text .. " bytes: " .. string.sub(text, 1, 200))
		table.insert(lines, { ok = verdict == "PASS", data = serde.decode("json", json :: string), text = text })
	end
	return lines
end

local function runOn(options: FakeRoblox.Options?, rewrite: ((string) -> string)?): (any, { Line }, any)
	local world = FakeRoblox.new(options)
	local ok, result = world.run(SNIPPET, rewrite)
	A.truthy(ok, "the snippet never throws: " .. tostring(result))
	local lines = parse(world)
	A.eq(result, table.concat(world.printed, "\n"), "execute_luau's result holds the same lines")
	A.eq(world.workspace:FindFirstChild("BS_SPar01"), nil, "the folder is gone")
	A.eq(#world.parts(), 0, "no Part left behind")
	return world, lines, result
end

-- "check shape" of every failed line, sorted, the summary left out.
local function failures(lines: { Line }): string
	local out: { string } = {}
	for _, line in lines do
		if not line.ok and line.data.check ~= "summary" then
			table.insert(out, line.data.check .. " " .. tostring(line.data.shape))
		end
	end
	table.sort(out)
	return table.concat(out, ", ")
end

local function shapeList(check: string, shapes: { string }): string
	local out: { string } = {}
	for _, s in shapes do
		table.insert(out, check .. " " .. s)
	end
	table.sort(out)
	return table.concat(out, ", ")
end

local function summaryOf(lines: { Line }): any
	local last = lines[#lines]
	A.eq(last.data.check, "summary", "the last line")
	return last
end

return Test.suite("ItemRender/S-PAR-01 snippet", function(t)
	t.it("a faithful engine: every line PASS, 5 checks per shape, E-S8.6's run size", function()
		local world, lines = runOn()
		A.eq(failures(lines), "", "no line failed")
		A.eq(#lines, #CHECKS * #Gen.SHAPES + 1, "one line per assertion and the summary")
		local at = 0
		for _, shape in Gen.SHAPES do
			for _, check in CHECKS do
				at += 1
				A.truthy(lines[at].ok, lines[at].text)
				A.eq(lines[at].data.shape, shape, "line " .. at)
				A.eq(lines[at].data.check, check, "line " .. at)
			end
			local overlap = lines[at - 1].data
			A.eq(overlap.points, 20 * 200, shape .. ": 20 sizes × 200 margin points")
			A.eq(overlap.wanted, 20 * 200, shape .. ": none short")
			A.eq(overlap.inside, 2000, shape .. ": half inside")
			A.eq(overlap.outside, 2000, shape .. ": half outside")
			A.eq(lines[at - 3].data.cases, 20, shape .. ": mass over 20 sizes")
			A.eq(lines[at].data.cases, 5, shape .. ": 5 thin sizes")
			A.eq(lines[at - 4].data.cases, 25, shape .. ": every case built")
		end
		local summary = summaryOf(lines)
		A.truthy(summary.ok, "summary PASS")
		A.eq(summary.data.assertions, 25, "summary counts the assertions")
		A.eq(summary.data.failed, 0, "summary counts the failures")
		A.truthy(world.frames >= 100, "it yields at least once per case, got " .. world.frames)
	end)

	t.it("the seed is fixed: a second run prints the same lines", function()
		local _, first = runOn(nil, small)
		local _, second = runOn(nil, small)
		A.eq(#first, #second, "line count")
		for i = 1, #first - 1 do -- the summary carries the wall clock
			A.eq(first[i].text, second[i].text, "line " .. i)
		end
	end)

	t.it("queries that lag a frame behind moves still agree: probes move, a frame passes, then the queries", function()
		local _, lines = runOn({ faults = { staleQueries = true } }, small)
		A.eq(failures(lines), "", "no line failed")
	end)

	t.it("thin sizes: mass reported against the true and the physics size; neither model fails the run", function()
		local function row(lines: { Line }, shape: string): any
			for _, line in lines do
				if line.data.check == "thin" and line.data.shape == shape then
					return line
				end
			end
			return A.fail("no thin line for " .. shape)
		end
		local _, plain = runOn(nil, small)
		local _, enlarged = runOn({ faults = { physicsSizeMass = true } }, small)
		A.eq(failures(enlarged), "", "the physics size is the engine's business, below its minimum")
		for _, shape in Gen.SHAPES do
			for i, r in row(plain, shape).data.rows do
				A.eq(r.massModel, "true size", shape .. " row " .. i)
				A.eq(r.comModel, "true size", shape .. " row " .. i)
			end
			for i, r in row(enlarged, shape).data.rows do
				A.eq(r.massModel, "physics size", shape .. " row " .. i)
			end
		end
		local first = row(enlarged, "Wedge").data.rows[1]
		A.deepEq(first.size, { 0.02, 1, 1 }, "the first thin size as stored")
		A.deepEq(first.extentsSize, { 0.05, 1, 1 }, "the physics size is on the line")
		local thinZ = row(enlarged, "Wedge").data.rows[3]
		A.deepEq(thinZ.size, { 1, 1, 0.02 }, "the third thin size")
		A.eq(thinZ.comModel, "physics size", "a thin wedge's centroid moves with its physics size")
	end)

	t.it("each planted engine fault fails exactly the lines that measure it", function()
		local ALL = Gen.SHAPES
		local NON_BLOCK = { "Wedge", "CornerWedge", "Cylinder", "Ball" }
		local cases: { { fault: string, expected: string } } = {
			{ fault = "wedgeFlipped", expected = shapeList("overlap", { "Wedge" }) },
			{ fault = "cornerApexFlipped", expected = shapeList("overlap", { "CornerWedge" }) },
			{ fault = "cylinderAxisY", expected = shapeList("overlap", { "Cylinder" }) },
			{ fault = "ballHalfRadius", expected = shapeList("overlap", { "Ball" }) },
			{ fault = "massIgnoresShape", expected = shapeList("mass", NON_BLOCK) },
			{ fault = "comNegated", expected = shapeList("com", { "Wedge", "CornerWedge" }) },
			{ fault = "comWorld", expected = shapeList("com", ALL) },
			{ fault = "queryNeverHits", expected = shapeList("overlap", ALL) },
			{ fault = "queryAlwaysHits", expected = shapeList("overlap", ALL) },
		}
		for _, case in cases do
			local _, lines = runOn({ faults = { [case.fault] = true } :: any }, small)
			A.eq(failures(lines), case.expected, case.fault)
			local summary = summaryOf(lines)
			A.falsy(summary.ok, case.fault .. ": the summary fails")
			A.truthy(summary.data.failed > 0, case.fault .. ": the summary counts the failures")
		end
	end)

	t.it("a FAIL line names its cases, so one run is enough to see what the engine did", function()
		local _, lines = runOn({ faults = { wedgeFlipped = true, massIgnoresShape = true, comNegated = true } }, small)
		local function line(check: string): any
			for _, l in lines do
				if l.data.check == check and l.data.shape == "Wedge" then
					return l.data
				end
			end
			return A.fail("no line " .. check)
		end
		local overlap = line("overlap")
		A.truthy(overlap.disagree > 0, "how many points disagree")
		A.truthy(#overlap.first >= 1 and #overlap.first <= 3, "the first few points")
		local entry = overlap.first[1]
		A.truthy(entry.expected == "hit" or entry.expected == "miss", "which way")
		A.eq(type(entry.sd), "number", "S2's signed distance")
		A.eq(#entry.atLocal, 3, "the point in the part's frame")
		A.eq(#entry.case.size, 3, "the size")
		A.eq(#entry.case.rot, 4, "the rotation")
		local mass = line("mass")
		A.truthy(mass.worstRel > 0.5, "the worst relative error")
		A.eq(type(mass.at.mass), "number", "the engine's Mass")
		A.eq(type(mass.at.volume), "number", "S2's volume")
		local com = line("com")
		A.eq(#com.at.centerOfMass, 3, "the engine's CenterOfMass")
		A.eq(#com.at.expectedLocal, 3, "S2's local centroid")
	end)

	t.it("a planted builder fault fails the build check", function()
		local function planted(pattern: string, replacement: string): (path: string, source: string) -> string
			return function(path: string, source: string): string
				if path ~= BUILDER then
					return source
				end
				local out, n = string.gsub(source, pattern, replacement)
				A.eq(n, 1, "the builder's line for " .. pattern)
				return out
			end
		end
		local forceBlock = planted("%(Enum%.PartType :: any%)%[prim%.shape%]", "Enum.PartType.Block")
		local _, wrongShape = runOn({ moduleRewrite = forceBlock }, small)
		for _, line in wrongShape do
			if line.data.check == "build" then
				A.eq(line.ok, line.data.shape == "Block", "Shape forced to Block, " .. line.data.shape)
			end
		end
		local _, wrongOrder = runOn({ moduleRewrite = planted("pivot%s*%*%s*(CFrame%.new%b())", "%1 * pivot") }, small)
		for _, line in wrongOrder do
			if line.data.check == "build" then
				A.falsy(line.ok, "primitive * pivot, " .. line.data.shape)
				A.contains(line.text, "Position", "the line says what is wrong")
			end
		end
		local _, queryable = runOn({ moduleRewrite = planted("part%.CanQuery = flags%.canQuery\n", "") }, small)
		for _, line in queryable do
			if line.data.check == "build" then
				A.falsy(line.ok, "a queryable item part, " .. line.data.shape)
			end
		end
		local throw = planted("part%.Anchored = defaults%.anchored", "error('planted')")
		local _, throwing = runOn({ moduleRewrite = throw }, small)
		A.eq(throwing[#throwing - 1].data.check, "crash", "an uncaught error is a crash line")
		A.contains(throwing[#throwing - 1].text, "planted", "with the error's text")
		A.falsy(summaryOf(throwing).ok, "the summary fails")
	end)

	t.it("the wrong data model or mode is a preflight FAIL, not a run", function()
		local MODES: { FakeRoblox.Options } = { { server = false }, { running = false } }
		for _, options in MODES do
			local world, lines = runOn(options)
			A.eq(#lines, 2, "the preflight line and the summary")
			A.falsy(lines[1].ok, "FAIL")
			A.eq(lines[1].data.check, "preflight", "preflight")
			A.contains(lines[1].data.why, "datamodel_type Server", "it says how to run")
			A.falsy(lines[2].ok, "the summary fails")
			A.eq(world.frames, 0, "no frame spent")
		end
	end)

	t.it("a place without the test tree is a crash line that names the missing module", function()
		local _, lines = runOn({ omit = { "src/shared/Physics/Shapes" } })
		A.eq(lines[1].data.check, "crash", "crash")
		A.contains(lines[1].data.why, "Shapes", "the missing module")
		A.falsy(lines[#lines].ok, "the summary fails")
	end)

	t.it("the snippet runs as one text: a leftover folder is replaced, no script, no argument", function()
		local world = FakeRoblox.new()
		local env = world.env
		local stale = env.Instance.new("Folder")
		stale.Name = "BS_SPar01"
		stale.Parent = world.workspace
		A.eq(env.script, nil, "execute_luau gives no script")
		local ok, result = world.run(SNIPPET, small)
		A.truthy(ok, tostring(result))
		A.eq(world.workspace:FindFirstChild("BS_SPar01"), nil, "the leftover is gone too")
	end)
end)
