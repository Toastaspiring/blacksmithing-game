--!strict
-- S-PAR-02 (SPEC §14.10, §17.2 S8, E-S8.6): Lune = Studio Server = Studio Client, M3's part of it: Analyze.run on every
-- fixture of the repo and on Tol.PARITY_DESIGNS Gen.validSword designs, digested. Equal digests show that the three
-- runtimes compute every analysis to the bit: no FMA contraction, --!native off, the same string.format, math.round
-- and table.sort (§4.1). M5 adds Pipeline.analyze, judged bot runs and T-CR-08's outcomes to the digest (§18).
--
-- HOW TO RUN. Start a Play session of a place synced from test.project.json (the test place, §14.10), then pass this
-- file's whole text to the Studio MCP's execute_luau with datamodel_type "Server", and again with "Client". It needs
-- no bridge and no player, only ReplicatedStorage.Blacksmith and ReplicatedStorage.BlacksmithTests (lib, fixtures,
-- golden). Every analysis yields to the next frame once SLICE_MS of work is used, as the AnalysisQueue's slices do
-- (§1.6): Lune takes about 2.4 s for the whole digest, so at 4 ms of work a frame, Studio about 2.6 × Lune (§4.9), a
-- call takes about 26 s. If execute_luau stops it first, set GROUP to "fixtures", then to "generated", one call each.
-- It changes nothing and leaves nothing behind. A milestone exit needs 3 fresh Play sessions, both data models green in
-- each.
--
-- WHAT IS DIGESTED. One line per design: its name, a tab, Dump.canonical(Analyze.run(core, {measureInvalid = true})),
-- a newline. Group "fixtures" is tests/fixtures/Parity's list in its order, an Adversarial variant handed to
-- Blueprint/Canonical.draft first and dropped when Canonical refuses it; group "generated" is Tol.PARITY_DESIGNS
-- designs drawn in turn by Gen.validSword from TestRng.new(Tol.PARITY_SEED), named "Gen k". Per group the digest keeps
-- the designs, the bytes and the fnv1a32 of all its lines. tests/Physics/Parity.spec writes the same from Lune into
-- tests/golden/parity.bv<N>.digest.txt, the StringValue BlacksmithTests.golden["parity.bv<N>.digest"] here, and every
-- design's own fnv1a32 into parity_designs.bv<N>.golden.txt, which this snippet never reads (Studio reads digests).
--
-- OUTPUT. One line per assertion, on the console (get_console_output) and in execute_luau's result:
--   [E2E] S-PAR-02 PASS|FAIL {"check": ..., "datamodel": "Server"|"Client", ...}
--   preflight  a Play session's Server or Client data model, and a known GROUP
--   golden     the digest's StringValue is there; a FAIL names the golden folder's children
--   analyze    per group run: designs, dropped drafts, bytes and fnv1a32, against the golden's entry ("expected"),
--              with the group's wall time
--   digest     with GROUP "all": the whole digest's text = the golden's, its version included
--   summary    last; FAIL when any line failed
-- After an analyze FAIL, FAIL lines {"check": "hashes"} give every design of that group as [name, fnv1a32],
-- HASHES_PER_LINE to a line, to diff against parity_designs.bv<N>.golden.txt; they explain the failure and are not
-- counted as assertions. {"check": "crash"} is an uncaught error.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ID = "S-PAR-02"
local GROUP = "all" -- "all", or "fixtures" or "generated" alone when one execute_luau call cannot hold both
local GROUPS = { "fixtures", "generated" } -- the digest's groups, in its order
local SLICE_MS = 4 -- ANALYSIS_SLICE_MS (§1.6): work between two yields
local HASHES_PER_LINE = 20 -- designs per "hashes" line, so a line stays readable
local VERSION = 1 -- the digest's layout, as Parity.spec writes it

local lines: { string } = {}
local assertions = 0
local failed = 0
local datamodel = "unknown"
local yields = 0

local function line(ok: boolean, data: { [string]: any })
	local encoded, json = pcall(function(): string
		return HttpService:JSONEncode(data)
	end)
	if not encoded then
		ok = false
		json = HttpService:JSONEncode({ check = tostring(data.check), why = tostring(json) })
	end
	local text = "[E2E] " .. ID .. (if ok then " PASS " else " FAIL ") .. json
	table.insert(lines, text)
	print(text)
end

-- An assertion's line.
local function emit(ok: boolean, data: { [string]: any })
	assertions += 1
	if not ok then
		failed += 1
	end
	line(ok, data)
end

-- JSON has no NaN or inf, and six digits are enough to read a time.
local function num(x: number): any
	if x ~= x or x == math.huge or x == -math.huge then
		return tostring(x)
	end
	return tonumber(string.format("%.6g", x))
end

local function run()
	local running = RunService:IsRunning()
	datamodel = if RunService:IsServer() then "Server" elseif RunService:IsClient() then "Client" else "unknown"
	local knownGroup = GROUP == "all" or table.find(GROUPS, GROUP) ~= nil
	if not running or datamodel == "unknown" or not knownGroup then
		emit(false, {
			check = "preflight",
			datamodel = datamodel,
			running = running,
			group = GROUP,
			why = "run through execute_luau with datamodel_type Server or Client, in a Play session; GROUP all, "
				.. "fixtures or generated",
		})
		return
	end

	local Blacksmith = ReplicatedStorage.Blacksmith
	local Versions = require(Blacksmith.Definitions.Versions)

	-- the golden first: without it there is nothing to compare, so nothing is analysed
	local tests = ReplicatedStorage:FindFirstChild("BlacksmithTests")
	local goldenFolder = if tests then tests:FindFirstChild("golden") else nil
	local goldenName = string.format("parity.bv%d.digest", Versions.BALANCE_VERSION)
	local value = if goldenFolder then goldenFolder:FindFirstChild(goldenName) else nil
	if value == nil or not value:IsA("StringValue") then
		local children: { string } = {}
		if goldenFolder then
			for _, child in goldenFolder:GetChildren() do
				table.insert(children, child.Name)
			end
		end
		emit(false, { check = "golden", datamodel = datamodel, name = goldenName, children = children })
		return
	end
	local expected = (string.gsub((value :: StringValue).Value, "\r\n", "\n"))

	local TestLib = ReplicatedStorage.BlacksmithTests.lib
	local Analyze = require(Blacksmith.Physics.Analyze)
	local Canonical = require(Blacksmith.Blueprint.Canonical)
	local Balance = require(Blacksmith.Definitions.Balance)
	local EquipmentTypes = require(Blacksmith.Definitions.EquipmentTypes)
	local Limits = require(Blacksmith.Definitions.Limits)
	local Materials = require(Blacksmith.Definitions.Materials)
	local Dump = require(TestLib.Dump)
	local Gen = require(TestLib.Gen)
	local TestRng = require(TestLib.TestRng)
	local Tol = require(TestLib.Tol)
	local Parity = require(ReplicatedStorage.BlacksmithTests.fixtures.Parity)

	-- the AnalysisQueue's checkpoint (§1.6), also between designs
	local sliceStart = os.clock()
	local function slice()
		if os.clock() - sliceStart > SLICE_MS / 1000 then
			task.wait()
			yields += 1
			sliceStart = os.clock()
		end
	end

	local function lineOf(name: string, core: any): string
		local report = Analyze.run(core, { measureInvalid = true, checkpoint = slice })
		slice()
		return name .. "\t" .. Dump.canonical(report) .. "\n"
	end

	-- A group's lines and names, in the digest's order, and how many drafts Canonical refused.
	local function linesOf(group: string): ({ string }, { string }, number)
		local out: { string }, names: { string }, dropped = {}, {}, 0
		if group == "fixtures" then
			for _, entry in Parity.list do
				local core: any = entry.core
				if core == nil and entry.draft then
					local result = Canonical.draft(entry.draft())
					core = if result.ok then result.value else nil
				end
				if core == nil then
					dropped += 1
				else
					table.insert(out, lineOf(entry.name, core))
					table.insert(names, entry.name)
				end
			end
		else
			local ctx = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled,
				Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
			local rng = TestRng.new(Tol.PARITY_SEED)
			for k = 1, Tol.PARITY_DESIGNS do
				local name = "Gen " .. k
				table.insert(out, lineOf(name, Gen.validSword(rng, ctx)))
				table.insert(names, name)
			end
		end
		return out, names, dropped
	end

	local analyze: { [string]: any } = {}
	for _, group in GROUPS do
		if GROUP ~= "all" and GROUP ~= group then
			continue
		end
		local started = os.clock()
		local out, names, dropped = linesOf(group)
		local text = table.concat(out)
		local entry = { bytes = #text, designs = #out, fnv1a32 = Dump.fnv1a32(text) }
		analyze[group] = entry
		-- the golden's entry for the group: Dump.canonical writes "<group>={…}" after "{" or ","
		local want = string.match(expected, "[{,]" .. group .. "=(%b{})")
		local ok = Dump.canonical(entry) == want
		emit(ok, {
			check = "analyze",
			datamodel = datamodel,
			group = group,
			designs = entry.designs,
			dropped = dropped,
			bytes = entry.bytes,
			fnv1a32 = entry.fnv1a32,
			expected = want or "none",
			seconds = num(os.clock() - started),
		})
		if not ok then
			for from = 1, #out, HASHES_PER_LINE do
				local list: { any } = {}
				for i = from, math.min(#out, from + HASHES_PER_LINE - 1) do
					local pair: { any } = { names[i], Dump.fnv1a32(out[i]) }
					table.insert(list, pair)
				end
				line(false, { check = "hashes", datamodel = datamodel, group = group, from = from, designs = list })
			end
		end
	end
	if GROUP == "all" then
		local text = Dump.canonical({ version = VERSION, analyze = analyze }) .. "\n"
		emit(text == expected, { check = "digest", datamodel = datamodel, bytes = #text, expectedBytes = #expected })
	end
end

-- ── main ──────────────────────────────────────────────────────────────────────────────────────────────────────────

local started = os.clock()
local ok, err = xpcall(function()
	run()
end, function(e: any): string
	return debug.traceback(tostring(e), 2)
end)
if not ok then
	emit(false, { check = "crash", datamodel = datamodel, why = tostring(err) })
end

emit(failed == 0, {
	check = "summary",
	datamodel = datamodel,
	group = GROUP,
	assertions = assertions, -- the lines before this one, the hashes left out
	failed = failed,
	yields = yields,
	sliceMs = SLICE_MS,
	seconds = num(os.clock() - started),
})

return table.concat(lines, "\n")
