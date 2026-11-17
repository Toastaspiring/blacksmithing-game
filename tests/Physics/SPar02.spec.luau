--!strict
-- The S-PAR-02 snippet itself (tests/studio/e2e/S-PAR-02.luau; SPEC §14.10, E-S8.6), run on tests/ItemRender/FakeRoblox
-- since the gate cannot start Studio: in the Server and the Client data model it computes Parity.spec's digest to the
-- bit, against the golden as Rojo maps it, in the documented lines; the wrong data model, a missing golden or module and
-- a mismatch fail the right lines. So S-PAR-02's first real run is a question about Roblox, not about the snippet. That
-- run is M3's exit test and belongs to the test place (§14.10). The full runs take about 2.5 s each and are slow (the
-- lead's L17); the failure paths run on few designs and are fast.

local serde = require("@lune/serde")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Golden = require("../lib/Golden")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local FakeRoblox = require("../ItemRender/FakeRoblox")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Analyze = require("../../src/shared/Physics/Analyze")

local SNIPPET = "tests/studio/e2e/S-PAR-02.luau"
local DIGEST = string.format("parity.bv%d", Versions.BALANCE_VERSION)
local DESIGNS = string.format("parity_designs.bv%d", Versions.BALANCE_VERSION)
local MAX_LINE_BYTES = 2000 -- a line stays readable, and short of any console limit

type Line = { ok: boolean, data: any, text: string }

-- One of the snippet's constants set otherwise, e.g. set("GROUP", '"generated"').
local function set(name: string, value: string): (string) -> string
	return function(source: string): string
		local out, n = string.gsub(source, "\nlocal " .. name .. " = [^\n]-( %-%- [^\n]*)\n", "\nlocal " .. name .. " = "
			.. value .. "%1\n")
		A.eq(n, 1, "the snippet's " .. name .. " line")
		return out
	end
end

-- A short run: the generated group alone, on its first n designs.
local function short(n: number): (string) -> string
	local group = set("GROUP", '"generated"')
	return function(source: string): string
		local out, count = string.gsub(group(source), "Tol%.PARITY_DESIGNS do", tostring(n) .. " do")
		A.eq(count, 1, "the snippet's design loop")
		return out
	end
end

-- The generated group's entry on its first n designs, as Parity.spec writes an entry, in Dump.canonical's text.
local function shortEntry(n: number): string
	local ctx = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
		Balance.Geometry)
	local rng = TestRng.new(Tol.PARITY_SEED)
	local lines: { string } = {}
	for k = 1, n do
		local report = Analyze.run(Gen.validSword(rng, ctx) :: any, { measureInvalid = true })
		table.insert(lines, "Gen " .. k .. "\t" .. Dump.canonical(report) .. "\n")
	end
	local text = table.concat(lines)
	return Dump.canonical({ bytes = #text, designs = n, fnv1a32 = Dump.fnv1a32(text) })
end

-- The digest golden with its generated group's entry replaced (FakeRoblox's goldenRewrite).
local function generatedEntry(entry: string): (string, string) -> string
	return function(stem: string, text: string): string
		if stem ~= DIGEST .. ".digest" then
			return text
		end
		local out, count = string.gsub(text, ",generated=%b{}", function(): string
			return ",generated=" .. entry
		end)
		A.eq(count, 1, "the golden's generated entry")
		return out
	end
end

local function parse(world: any): { Line }
	local lines: { Line } = {}
	for _, text in world.printed do
		local verdict, json = string.match(text, "^%[E2E%] S%-PAR%-02 (%u+) ({.*})$")
		A.truthy(verdict == "PASS" or verdict == "FAIL", "the line format, got: " .. text)
		A.truthy(#text <= MAX_LINE_BYTES, "a line of " .. #text .. " bytes: " .. string.sub(text, 1, 200))
		table.insert(lines, { ok = verdict == "PASS", data = serde.decode("json", json :: string), text = text })
	end
	return lines
end

local function runOn(options: FakeRoblox.Options?, rewrite: ((string) -> string)?): (any, { Line })
	local world = FakeRoblox.new(options)
	local before = #world.workspace:GetChildren()
	local ok, result = world.run(SNIPPET, rewrite)
	A.truthy(ok, "the snippet never throws: " .. tostring(result))
	local lines = parse(world)
	A.eq(result, table.concat(world.printed, "\n"), "execute_luau's result holds the same lines")
	A.eq(#world.workspace:GetChildren(), before, "nothing left in the Workspace")
	return world, lines
end

local function summaryOf(lines: { Line }): any
	local last = lines[#lines]
	A.eq(last.data.check, "summary", "the last line")
	return last
end

-- The lines of one check, in order.
local function linesOf(lines: { Line }, check: string): { Line }
	local out: { Line } = {}
	for _, l in lines do
		if l.data.check == check then
			table.insert(out, l)
		end
	end
	return out
end

-- A full run in one data model: every line PASS, each group's entry the golden's, and it yields.
local function full(server: boolean)
	local world, lines = runOn({ server = server })
	local want = if server then "Server" else "Client"
	local digest = Golden.readDigest(DIGEST)
	A.truthy(digest ~= nil, "the Lune digest is blessed (Physics/Parity)")
	A.eq(#lines, 4, "fixtures, generated, digest, summary")
	for i, l in lines do
		A.truthy(l.ok, l.text)
		A.eq(l.data.datamodel, want, "line " .. i)
	end
	local analyze = linesOf(lines, "analyze")
	A.eq(analyze[1].data.group, "fixtures", "the digest's order")
	A.eq(analyze[2].data.group, "generated", "the digest's order")
	for _, l in analyze do
		local entry = digest.analyze[l.data.group]
		A.eq(l.data.designs, entry.designs, l.data.group .. ": designs")
		A.eq(l.data.bytes, entry.bytes, l.data.group .. ": bytes")
		A.eq(l.data.fnv1a32, entry.fnv1a32, l.data.group .. ": fnv1a32")
	end
	A.eq(analyze[1].data.dropped, 106, "the drafts Canonical refuses")
	A.eq(analyze[2].data.designs, Tol.PARITY_DESIGNS, "Gen designs")
	local summary = summaryOf(lines).data
	A.eq(summary.assertions, 3, "the summary counts the assertions before it")
	A.eq(summary.failed, 0, "none failed")
	A.truthy(world.frames > Tol.PARITY_DESIGNS, "it yields as the AnalysisQueue slices, got " .. world.frames)
	A.eq(summary.yields, world.frames, "every yield is a slice's")
end

return Test.suite("Physics/S-PAR-02 snippet", function(t)
	t.slow("the Server data model: both groups and the whole digest = the Lune golden, every line PASS", function()
		full(true)
	end)

	t.slow("the Client data model: the same digest", function()
		full(false)
	end)

	t.slow("GROUP fixtures, then generated: one call each, each group's line as in one run, no digest line", function()
		local digest = Golden.readDigest(DIGEST)
		for _, group in { "fixtures", "generated" } do
			local _, lines = runOn(nil, set("GROUP", '"' .. group .. '"'))
			A.eq(#lines, 2, group .. ": its analyze line and the summary")
			A.truthy(lines[1].ok, lines[1].text)
			A.eq(lines[1].data.group, group, "the group run")
			A.eq(lines[1].data.fnv1a32, digest.analyze[group].fnv1a32, group .. ": fnv1a32")
			A.truthy(summaryOf(lines).ok, group .. ": the summary")
		end
	end)

	t.it("a group passes on its golden entry and fails on any other, then lists [name, fnv1a32] per design", function()
		local n = 25
		local entry = shortEntry(n)
		local _, passing = runOn({ goldenRewrite = generatedEntry(entry) }, short(n))
		A.eq(#passing, 2, "the generated group's line and the summary")
		A.truthy(passing[1].ok, passing[1].text)
		A.eq(passing[1].data.expected, entry, "the golden's entry, as text")
		A.truthy(summaryOf(passing).ok, "the summary passes")

		local wrong = (string.gsub(entry, "fnv1a32=(%d+)", function(h: string): string
			return "fnv1a32=" .. tostring(tonumber(h) :: number + 1)
		end))
		local world, lines = runOn({ goldenRewrite = generatedEntry(wrong) }, short(n))
		local analyze = linesOf(lines, "analyze")
		A.eq(#analyze, 1, "the generated group alone")
		A.falsy(analyze[1].ok, "one hash off")
		A.eq(analyze[1].data.designs, n, "the designs run")
		A.eq(analyze[1].data.expected, wrong, "the golden's entry, as text")
		local hashes = linesOf(lines, "hashes")
		A.eq(#hashes, 2, "20 designs to a line")
		local lune = (Golden.read(DESIGNS) :: any).generated
		local at = 0
		for _, l in hashes do
			A.falsy(l.ok, "a hashes line is a FAIL line")
			A.eq(l.data.from, at + 1, "the first design's index")
			for _, pair in l.data.designs do
				at += 1
				A.eq(pair[1], lune[at].name, "design " .. at)
				A.eq(pair[2], lune[at].fnv1a32, "design " .. at .. ": Parity.spec's hash, so a diff finds the one that moved")
			end
		end
		A.eq(at, n, "every design of the run")
		local summary = summaryOf(lines)
		A.falsy(summary.ok, "the summary fails")
		A.eq(summary.data.assertions, 1, "the hashes lines are no assertions")
		A.eq(summary.data.failed, 1, "one assertion failed")
		A.truthy(world.frames >= 1, "it yields")
	end)

	t.it("the wrong data model or mode, or an unknown GROUP, is a preflight FAIL, not a run", function()
		local cases: { { options: FakeRoblox.Options?, rewrite: ((string) -> string)? } } = {
			{ options = { running = false } },
			{ options = { running = false, server = false } },
			{ rewrite = set("GROUP", '"everything"') },
		}
		for i, case in cases do
			local world, lines = runOn(case.options, case.rewrite)
			A.eq(#lines, 2, "case " .. i .. ": the preflight line and the summary")
			A.falsy(lines[1].ok, "case " .. i .. ": FAIL")
			A.eq(lines[1].data.check, "preflight", "case " .. i)
			A.contains(lines[1].data.why, "datamodel_type Server or Client", "case " .. i .. ": it says how to run")
			A.falsy(lines[2].ok, "case " .. i .. ": the summary fails")
			A.eq(world.frames, 0, "case " .. i .. ": no frame spent")
		end
	end)

	t.it("a place without the digest is a golden FAIL that names what the folder holds, before any analysis", function()
		local world, lines = runOn({ omit = { "tests/golden/" .. DIGEST .. ".digest" } })
		A.eq(#lines, 2, "the golden line and the summary")
		A.falsy(lines[1].ok, "FAIL")
		A.eq(lines[1].data.check, "golden", "golden")
		A.eq(lines[1].data.name, DIGEST .. ".digest", "the StringValue it looked for")
		A.truthy(table.find(lines[1].data.children, DESIGNS .. ".golden") ~= nil, "the folder's children, by name")
		A.eq(world.frames, 0, "nothing analysed")
	end)

	t.it("a place without the test tree is a crash line that names the missing module", function()
		local _, lines = runOn({ omit = { "src/shared/Physics/Analyze" } })
		A.eq(lines[1].data.check, "crash", "crash")
		A.contains(lines[1].data.why, "Analyze", "the missing module")
		A.falsy(lines[#lines].ok, "the summary fails")
	end)

	t.it("the snippet runs as one text: no script, no argument", function()
		local world = FakeRoblox.new()
		A.eq(world.env.script, nil, "execute_luau gives no script")
		local ok, result = world.run(SNIPPET, short(1))
		A.truthy(ok, tostring(result))
		A.contains(result, "[E2E] S-PAR-02 ", "it returns its lines")
	end)
end)
