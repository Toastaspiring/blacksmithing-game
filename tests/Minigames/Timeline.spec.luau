--!strict
-- Minigames/Timeline (SPEC §6.7, §10.3; T-MG-08's decode level, M4's D8): the wire constants and each family's cap;
-- one hand-written byte golden per family (E-S3.4's, E-S3.5's and E-S3.7's patterns), which a layout error made alike
-- in encode and decode cannot pass; round trips at the format's extremes; encode refuses every record decode would;
-- one planted timeline per decode reason (Cheats.malformed) reads exactly that reason, and the first failure wins;
-- flood timelines (the count, and D8's length past the cap) read TooMany; and decode is total: garbage values and
-- structured buffers (Cheats.garbageBuffers) never throw, and what decodes lies within the step and the panel.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Cheats = require("../lib/Cheats")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local DT = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local HoldZone = require("../../src/shared/Minigames/HoldZone")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

type HoldRecord = Types.HoldRecord
type TraceRecord = Types.TraceRecord
-- what a header carries, and what a spec gives decode
type Head = { family: DT.FamilyId, durationMs: number, patternHash: number, countdownMs: number }

local CHEATS = Cheats.new({ Timeline = Timeline, MinigameFamilies = MF })
local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)

local function fromHex(hex: string): buffer
	local bytes = string.gsub(string.gsub(hex, "%s", ""), "%x%x", function(h: string): string
		return string.char(tonumber(h, 16) :: number)
	end)
	return buffer.fromstring(bytes)
end

local function toHex(b: buffer): string
	return (string.gsub(buffer.tostring(b), ".", function(c: string): string
		return string.format("%02X", string.byte(c))
	end))
end

local function paramsOf(family: DT.FamilyId): { [string]: number }
	return Params.resolve(family, "Iron", "Normal", Params.refFactors(0))
end

-- the three golden patterns (seed 1, Iron/Normal, x = 0; the trace on Edges.arming): E-S3.4, E-S3.5, E-S3.7
local function goldenPattern(family: DT.FamilyId): any
	local p = paramsOf(family)
	if family == "HoldZone" then
		return HoldZone.generate(1, p)
	elseif family == "TimingStrike" then
		return TimingStrike.generate(1, p)
	end
	local e = Edges.arming
	local source = PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(e.chains, e.gripPoint, e.gripAxis),
		e.gripPoint, e.gripAxis, p.pacerSpeed)
	return PrecisionTrace.generate(1, p, source)
end

local function headOf(family: DT.FamilyId, P: any): Head
	return { family = family, durationMs = P.durationMs, patternHash = P.hash, countdownMs = 3000 }
end

local function timeOf(r: any): number
	return if type(r) == "number" then r else r.t
end

-- decoded records are honest: times within [0, durationMs] and non-decreasing, HoldZone's kinds alternating from
-- down, the trace's times increasing and its points in the panel
local function inRange(family: DT.FamilyId, records: { any }, durationMs: number)
	local prev = -1
	for i, r in ipairs(records) do
		local t = timeOf(r)
		A.truthy(t >= 0 and t <= durationMs and math.floor(t) == t, "an integer time within the step")
		A.truthy(t >= prev, "times non-decreasing")
		if family == "HoldZone" then
			A.eq(r.down, i % 2 == 1, "kinds alternate from down")
		elseif family == "PrecisionTrace" then
			A.truthy(t > prev, "trace times increase")
			A.within(r.u, 0, Timeline.U_MAX, "u")
			A.within(r.v, 0, Timeline.V_MAX, "v")
			A.eq(type(r.grind), "boolean", "grind")
		end
		prev = t
	end
end

-- a fuzz case at FUZZ_N_STRUCT_FAST values in the quick run and FUZZ_N_GARBAGE under t.slow (M4's L1 share, D10)
local function fuzzSized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.FUZZ_N_STRUCT_FAST)
	end)
	t.slow(name .. " (FUZZ_N_GARBAGE)", function()
		body(Tol.FUZZ_N_GARBAGE)
	end)
end

-- a property case at PROP_N_FAST cases in the quick run and PROP_N under t.slow
local function sized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.PROP_N_FAST)
	end)
	t.slow(name .. " (PROP_N cases)", function()
		body(Tol.PROP_N)
	end)
end

-- deep equality, numbers bit for bit, building no string (A.deepEq only words a failure: it is slow on long timelines)
local function same(a: any, b: any): boolean
	if a == b then
		return true
	elseif type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function deepEqFast(actual: any, expected: any, msg: string)
	if not same(actual, expected) then
		A.deepEq(actual, expected, msg)
	end
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

return Test.suite("Minigames/Timeline", function(t)
	t.it("the wire constants: the panel bounds from PrecisionTrace and each family's cap (§6.7, §10.3)", function()
		A.eq(Timeline.U_MAX, 49152, "U_MAX = 3 · 16384")
		A.eq(Timeline.V_MAX, 16384, "V_MAX")
		A.eq(Timeline.capBytes("HoldZone"), 3084, "12 + 1024 · 3")
		A.eq(Timeline.capBytes("TimingStrike"), 1036, "12 + 512 · 2")
		A.eq(Timeline.capBytes("PrecisionTrace"), 14348, "12 + 2048 · 7")
		A.eq(math.max(Timeline.capBytes("HoldZone"), Timeline.capBytes("TimingStrike"),
			Timeline.capBytes("PrecisionTrace")), MF.MAX_TIMELINE_BYTES, "MAX_TIMELINE_BYTES is the largest cap")
		A.throws(function()
			Timeline.capBytes("FitPuzzle")
		end, "no timeline codec")
	end)

	t.it("T-MG-08 byte goldens: one hand-written timeline per family decodes to its records and re-encodes to its bytes", function()
		-- header: u8 version 1, u8 family code, u16 count, u32 durationMs, u32 patternHash; records: u16 dt from the
		-- previous record, then HoldZone u8 kind, TimingStrike nothing, PrecisionTrace u16 u, u16 v, u8 flags; all
		-- little-endian. The durations and hashes are E-S3's goldens; the bytes were written by hand from §6.7.
		local goldens: { { family: DT.FamilyId, hex: string, durationMs: number, hash: number, records: { any } } } = {
			{ -- E-S3.7: a press at GO, released at 80 ms, pressed again at 300 ms
				family = "HoldZone",
				hex = "01 01 0300 983A0000 F277264E  0000 01  5000 00  DC00 01",
				durationMs = 15000,
				hash = 0x4E2677F2,
				records = { { t = 0, down = true }, { t = 80, down = false }, { t = 300, down = true } },
			},
			{ -- E-S3.4: its first three worked presses, errors 0, +6, −15 on targets 489, 1479, 2354
				family = "TimingStrike",
				hex = "01 02 0300 DB2A0000 AEF2D4E2  E901  E403  5603",
				durationMs = 10971,
				hash = 0xE2D4F2AE,
				records = { 489, 1485, 2339 },
			},
			{ -- E-S3.5: the arming source's first two points, grinding, then a lifted sample at 41 ms
				family = "PrecisionTrace",
				hex = "01 03 0300 942F0000 03CDB5F0  0000 A02A AE27 01  1400 B488 AE27 01  1500 6095 C520 00",
				durationMs = 12180,
				hash = 0xF0B5CD03,
				records = {
					{ t = 0, u = 10912, v = 10158, grind = true },
					{ t = 20, u = 34996, v = 10158, grind = true },
					{ t = 41, u = 38240, v = 8389, grind = false },
				},
			},
		}
		for _, g in goldens do
			local P = goldenPattern(g.family)
			A.eq(P.durationMs, g.durationMs, g.family .. ": the golden pattern's duration")
			A.eq(P.hash, g.hash, g.family .. ": the golden pattern's hash")
			local records, hash = Timeline.decode(fromHex(g.hex), g.family, g.durationMs)
			A.deepEq(records, g.records, g.family .. ": the records")
			A.eq(hash, g.hash, g.family .. ": the hash")
			local bytes = Timeline.encode(g.family, g.durationMs, g.hash, g.records)
			A.eq(toHex(bytes), string.gsub(g.hex, "%s", ""), g.family .. ": encode writes the golden bytes")
		end
	end)

	t.it("round trips: decode(encode(r)) = r with the header's count, duration and hash, at the format's extremes", function()
		local cases: { { family: DT.FamilyId, durationMs: number, records: { any } } } = {
			{ family = "HoldZone", durationMs = 15000, records = {} },
			{ family = "HoldZone", durationMs = 70000, records = { { t = 0, down = true }, { t = 0, down = false },
				{ t = 65535, down = true }, { t = 70000, down = false } } },
			{ family = "TimingStrike", durationMs = 65536, records = { 0, 0, 1, 65536, 65536 } },
			{ family = "PrecisionTrace", durationMs = 65536, records = {
				{ t = 0, u = 0, v = 0, grind = false },
				{ t = 1, u = Timeline.U_MAX, v = Timeline.V_MAX, grind = true },
				{ t = 65536, u = 1, v = 2, grind = true },
			} },
		}
		for _, c in cases do
			local hash = 0xFFFFFFFF
			local b = Timeline.encode(c.family, c.durationMs, hash, c.records)
			A.eq(buffer.len(b), 12 + #c.records * MF.RECORD_BYTES[c.family], c.family .. ": 12 + n · RECORD_BYTES")
			A.eq(buffer.readu8(b, 0), MF.TIMELINE_FORMAT_VERSION, "version")
			A.eq(buffer.readu8(b, 1), MF.FAMILY_CODE[c.family], "family code")
			A.eq(buffer.readu16(b, 2), #c.records, "count")
			A.eq(buffer.readu32(b, 4), c.durationMs, "durationMs")
			A.eq(buffer.readu32(b, 8), hash, "patternHash")
			local records, h = Timeline.decode(b, c.family, c.durationMs)
			A.deepEq(records, c.records, c.family .. ": the records back")
			A.eq(h, hash, "the hash back")
		end
		-- MAX_RECORDS of each family encode and decode
		for k = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[k]
			local records: { any } = {}
			for i = 1, MF.MAX_RECORDS[family] do
				records[i] = if family == "HoldZone" then { t = i, down = i % 2 == 1 }
					elseif family == "TimingStrike" then i
					else { t = i, u = i, v = i, grind = true }
			end
			local back = Timeline.decode(Timeline.encode(family, 5000, 7, records), family, 5000)
			A.eq(#(back :: { any }), MF.MAX_RECORDS[family], family .. ": MAX_RECORDS records decode")
		end
	end)

	sized(t, "random honest records round-trip on the golden patterns (P-DET, P-NOMUT, P-RANGE)", function(n: number)
		local patterns: { [string]: any } = {}
		for k = 1, #H.FAMILIES do
			patterns[H.FAMILIES[k]] = goldenPattern(H.FAMILIES[k])
		end
		Prop.check(n, function(rng: TestRng.TestRng): { family: DT.FamilyId, records: { any } }
			local family: DT.FamilyId = H.FAMILIES[rng:int(1, 3)]
			return { family = family, records = H.randomRecords(rng, family, patterns[family]) }
		end, function(c: { family: DT.FamilyId, records: { any } })
			local P = patterns[c.family]
			local before = copy(c.records)
			local b = Timeline.encode(c.family, P.durationMs, P.hash, c.records)
			local bytes = buffer.tostring(b)
			A.eq(buffer.tostring(Timeline.encode(c.family, P.durationMs, P.hash, c.records)), bytes, "P-DET encode")
			deepEqFast(c.records, before, "P-NOMUT: encode leaves the records alone")
			local records, h = Timeline.decode(b, c.family, P.durationMs)
			A.eq(buffer.tostring(b), bytes, "P-NOMUT: decode leaves the buffer alone")
			deepEqFast(records, c.records, "the records back")
			A.eq(h, P.hash, "the hash back")
			deepEqFast(Timeline.decode(b, c.family, P.durationMs), records, "P-DET decode")
			inRange(c.family, records :: { any }, P.durationMs)
		end)
	end)

	t.it("encode refuses every record decode would refuse (a caller bug: an honest timeline always decodes)", function()
		local function refuses(family: DT.FamilyId, records: { any }, contains: string, durationMs: number?)
			A.throws(function()
				Timeline.encode(family, durationMs or 1000, 1, records)
			end, contains, family .. " " .. Dump.short(records))
		end
		refuses("HoldZone", { { t = 0, down = false } }, "alternate from a down")
		refuses("HoldZone", { { t = 0, down = true }, { t = 5, down = true } }, "alternate from a down")
		refuses("HoldZone", { { t = 0, down = 1 } }, "down must be a boolean")
		refuses("TimingStrike", { 10, 9 }, "non-decreasing")
		refuses("TimingStrike", { 0, 65536 }, "65535 ms apart", 70000)
		refuses("TimingStrike", { 1001 }, "past durationMs")
		refuses("TimingStrike", { 1.5 }, "integers")
		refuses("TimingStrike", { 0 / 0 }, "integers")
		refuses("PrecisionTrace", { { t = 0, u = 1, v = 1, grind = true }, { t = 0, u = 1, v = 1, grind = true } },
			"times must increase")
		refuses("PrecisionTrace", { { t = 0, u = Timeline.U_MAX + 1, v = 1, grind = true } }, "U_MAX")
		refuses("PrecisionTrace", { { t = 0, u = 1, v = Timeline.V_MAX + 1, grind = true } }, "V_MAX")
		refuses("PrecisionTrace", { { t = 0, u = 1.5, v = 1, grind = true } }, "integers")
		refuses("PrecisionTrace", { { t = 0, u = -1, v = 1, grind = true } }, "integers")
		refuses("PrecisionTrace", { { t = 0, u = 1, v = 1, grind = 1 } }, "grind must be a boolean")
		local many: { any } = {}
		local ts: DT.FamilyId = "TimingStrike"
		for i = 1, MF.MAX_RECORDS[ts] + 1 do
			many[i] = i
		end
		refuses("TimingStrike", many, "MAX_RECORDS")
		A.throws(function()
			Timeline.encode("TimingStrike", -1, 1, {})
		end, "u32")
		A.throws(function()
			Timeline.encode("TimingStrike", 1000, 4294967296, {})
		end, "u32")
		A.throws(function()
			Timeline.encode("RhythmSequence", 1000, 1, {})
		end, "no timeline codec")
	end)

	t.it("T-MG-08 each planted timeline (Cheats.malformed) reads exactly its reason, in every family it can occur in", function()
		local seen: { [string]: number } = {}
		for k = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[k]
			local head = headOf(family, goldenPattern(family))
			local reasons = CHEATS.reasons(family)
			for _, reason in reasons do
				local values = CHEATS.malformed(head, reason)
				A.truthy(#values >= 1, reason .. " has a planted value")
				for k, v in values do
					local records, why = Timeline.decode(v, family, head.durationMs)
					A.eq(records, nil, string.format("%s %s #%d is refused", family, reason, k))
					A.eq(why, reason, string.format("%s %s #%d", family, reason, k))
				end
				seen[reason] = (seen[reason] or 0) + 1
			end
			A.throws(function()
				CHEATS.malformed(head, if family == "HoldZone" then "OutOfPanel" else "BadKind")
			end, "no ", family .. ": a reason the family cannot have")
		end
		-- every InvalidReason but HashMismatch (the judge's) is planted somewhere
		for _, reason in { "NotBuffer", "Short", "Version", "Family", "TooMany", "Length", "Duration", "NotIncreasing",
			"PastEnd", "BadKind", "NotAlternating", "OutOfPanel", "BadFlags" } do
			A.truthy(seen[reason] ~= nil, reason .. " is planted")
		end
		A.eq(Timeline.decode(nil, "HoldZone", 15000), nil, "nil is not a buffer")
	end)

	t.it("T-MG-08 the first failure wins, in §6.7's order", function()
		local P = goldenPattern("PrecisionTrace")
		local D = P.durationMs
		local honest: { TraceRecord } = {
			{ t = 0, u = 100, v = 100, grind = true },
			{ t = 20, u = 200, v = 100, grind = true },
			{ t = 40, u = 300, v = 100, grind = true },
		}
		local function planted(plant: (b: buffer) -> ()): buffer
			local b = Timeline.encode("PrecisionTrace", D, P.hash, honest)
			plant(b)
			return b
		end
		local function reads(b: buffer, reason: string, what: string)
			local _, why = Timeline.decode(b, "PrecisionTrace", D)
			A.eq(why, reason, what)
		end
		local function rec(i: number): number
			return 12 + (i - 1) * 7
		end
		-- the header's checks, two faults at a time
		local long = buffer.create(12 + 3 * 7 + 1)
		buffer.copy(long, 0, planted(function(b)
			buffer.writeu8(b, 0, 9)
		end))
		reads(long, "Version", "Version before Length")
		reads(planted(function(b)
			buffer.writeu8(b, 1, 1)
			buffer.writeu16(b, 2, 4000)
		end), "Family", "Family before TooMany")
		reads(planted(function(b)
			buffer.writeu16(b, 2, 2049)
		end), "TooMany", "TooMany before Length")
		reads(planted(function(b)
			buffer.writeu16(b, 2, 2)
			buffer.writeu32(b, 4, D + 1)
		end), "Length", "Length before Duration")
		reads(planted(function(b)
			buffer.writeu32(b, 4, D + 1)
			buffer.writeu16(b, rec(2), 0)
		end), "Duration", "Duration before the records")
		-- the records in order: an earlier record's fault wins
		reads(planted(function(b)
			buffer.writeu8(b, rec(2) + 6, 2)
			buffer.writeu16(b, rec(3) + 2, 60000)
		end), "BadFlags", "record 2's BadFlags before record 3's OutOfPanel")
		reads(planted(function(b)
			buffer.writeu16(b, rec(2) + 2, 60000)
			buffer.writeu16(b, rec(3), 0)
		end), "OutOfPanel", "record 2's OutOfPanel before record 3's NotIncreasing")
		-- within a record: NotIncreasing, PastEnd, then the fields; OutOfPanel before BadFlags
		reads(planted(function(b)
			buffer.writeu16(b, rec(2), 0)
			buffer.writeu16(b, rec(2) + 2, 60000)
		end), "NotIncreasing", "NotIncreasing before OutOfPanel")
		reads(planted(function(b)
			buffer.writeu16(b, rec(2), 65535)
			buffer.writeu8(b, rec(2) + 6, 2)
		end), "PastEnd", "PastEnd before BadFlags")
		reads(planted(function(b)
			buffer.writeu16(b, rec(2) + 4, 16385)
			buffer.writeu8(b, rec(2) + 6, 2)
		end), "OutOfPanel", "OutOfPanel before BadFlags")
		-- HoldZone: PastEnd before BadKind, BadKind before NotAlternating
		local Z = goldenPattern("HoldZone")
		local function zone(plant: (b: buffer) -> ()): buffer
			local b = Timeline.encode("HoldZone", Z.durationMs, Z.hash, H.taps(Z.durationMs, 300, 80))
			plant(b)
			return b
		end
		local function zoneReads(b: buffer, reason: string, what: string)
			local _, why = Timeline.decode(b, "HoldZone", Z.durationMs)
			A.eq(why, reason, what)
		end
		zoneReads(zone(function(b)
			buffer.writeu16(b, 12, 65535)
			buffer.writeu8(b, 14, 7)
		end), "PastEnd", "PastEnd before BadKind")
		zoneReads(zone(function(b)
			buffer.writeu8(b, 14, 7)
			buffer.writeu8(b, 17, 1)
		end), "BadKind", "record 1's BadKind before record 2's NotAlternating")
		zoneReads(zone(function(b)
			buffer.writeu8(b, 14, 0)
		end), "NotAlternating", "an up first")
	end)

	t.it("T-MG-08 flood: MAX_RECORDS + 1 records, and more bytes than the cap with a count within it, read TooMany (D8)", function()
		for k = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[k]
			local head = headOf(family, goldenPattern(family))
			local flood = CHEATS.flood(head)
			local _, why = Timeline.decode(flood.overCount, family, head.durationMs)
			A.eq(why, "TooMany", family .. ": MAX_RECORDS + 1")
			A.eq(buffer.readu16(flood.overLength, 2), MF.MAX_RECORDS[family], family .. ": a count within the cap")
			A.eq(buffer.len(flood.overLength), Timeline.capBytes(family) + 1, family .. ": one byte past the cap")
			local _, whyLong = Timeline.decode(flood.overLength, family, head.durationMs)
			A.eq(whyLong, "TooMany", family .. ": D8, not Length")
			A.eq(flood.overCap, nil, family .. ": no judge cap without the facade")
		end
	end)

	fuzzSized(t, "T-MG-08 P-TOTAL: garbage values (Gen.garbage) never throw and give a reason", function(n: number)
		local families = H.FAMILIES
		Prop.check(n, function(rng: TestRng.TestRng): any
			return Gen.garbage(rng, CTX)
		end, function(v: any)
			for k = 1, #families do
				local family: DT.FamilyId = families[k]
				local ok, records, why = pcall(Timeline.decode, v, family, 15000)
				A.truthy(ok, "decode never throws: " .. tostring(records))
				if records == nil then
					A.eq(type(why), "string", "a refusal names its reason")
				else
					inRange(family, records, 15000)
				end
			end
		end)
	end)

	fuzzSized(t, "T-MG-08 structured buffers (Cheats.garbageBuffers) never throw; what decodes is honest", function(n: number)
		local rng = TestRng.new(0x7117E108)
		for k = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[k]
			local P = goldenPattern(family)
			local head = headOf(family, P)
			local reasons = CHEATS.reasons(family)
			local decoded = 0
			for j, b in CHEATS.garbageBuffers(rng, head, H.randomRecords(rng, family, P), n) do
				local ok, records, why = pcall(Timeline.decode, b, family, head.durationMs)
				A.truthy(ok, string.format("%s buffer %d: decode never throws: %s", family, j, tostring(records)))
				if records == nil then
					A.truthy(table.find(reasons, why :: any) ~= nil, string.format("%s buffer %d: %s is a %s reason",
						family, j, tostring(why), family))
				else
					decoded += 1
					inRange(family, records, head.durationMs)
					A.eq(buffer.len(b), 12 + #records * MF.RECORD_BYTES[family], "a decoded buffer is all records")
				end
			end
			A.truthy(decoded > 0, family .. ": some structured buffers decode")
		end
	end)
end)
