--!strict
-- T-UD-01 editor transforms survive Save → load bit-identically (SPEC §3.4, §3.5, §9.6, §14.6, E-S1.3). The path,
-- with every M1 piece on it:
--   editor   values the editor's tools produce (snapped moves cleaned as round(v·1e12)/1e12, typed decimals, mirrors,
--            free drags; rotations composed through Blueprint/Quat), committed through Canonical.draft as the editor
--            does on every commit (§11.5)
--   Save     the remote carries the doubles exactly (a deep copy) and the server runs Canonical.draft again: the result
--            is the editor's draft bit for bit
--   store    the BlueprintRecord written as Roblox's HttpService:JSONEncode writes it (shortest round-trip digits)
--   load     decoded; Prepare's repair keeps it, since isCanonical(core, {bounds = false}) holds (§9.6)
--   forge    Views.snapshot of the loaded record, and a second Save of it: still the same bits
-- Editor quaternions (|‖q‖² − 1| ≈ 1e-16) sit far inside QUAT_NORM_TOL, so C3 never touches them.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("./Drafts")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Quat = require("../../src/shared/Blueprint/Quat")
local Views = require("../../src/shared/Blueprint/Views")
local Limits = require("../../src/shared/Definitions/Limits")

type TestRng = TestRng.TestRng

local function noDiff(a: any, b: any, what: string)
	local diff = Drafts.bitDiff(a, b)
	A.truthy(diff == nil, what .. ": " .. tostring(diff))
end

local function roundTrip(x: number): number
	return Drafts.jsonDecode(Drafts.jsonEncode({ x }))[1]
end

return Test.suite("Blueprint/SaveLoad", function(t)
	t.it("T-UD-01 editor drafts survive Save → JSON → load → snapshot bit for bit (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.editorDraft(rng, Quat, Canonical)
		end, function(editor: any)
			-- Save: the wire copy reaches the server, which canonicalizes again
			local server: any = Canonical.draft(Drafts.deepCopy(editor))
			A.truthy(server.ok, "the server accepts every editor draft")
			noDiff(server.value, editor, "server draft = editor draft")
			-- store and load
			local rec = Drafts.deepCopy(server.value)
			rec.id, rec.revision = "93E32E8A-59BA-4037-9A7F-AA5613CD6213", 1
			rec.createdAt, rec.updatedAt = 1793404800, 1793404800
			local loaded = Drafts.jsonDecode(Drafts.jsonEncode(rec))
			noDiff(loaded, rec, "JSON round trip")
			A.truthy(Canonical.isCanonical(loaded, { bounds = false }), "kept by Prepare's repair")
			A.truthy(Canonical.isCanonical(loaded), "and valid for Begin and Pipeline.analyze")
			-- forge and save again
			noDiff((Views.snapshot(loaded) :: any).parts, editor.parts, "snapshot parts = editor parts")
			local again: any = Canonical.draft(loaded)
			A.truthy(again.ok, "a second Save is accepted")
			noDiff(again.value, editor, "a second Save changes nothing")
		end)
	end)

	t.it("T-UD-01 the commit keeps editor quaternions' bits (C3 never fires below 1e-9) (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { number }
			return Drafts.editorRot(rng, Quat)
		end, function(q: { number })
			local m = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
			A.truthy(math.abs(m - 1) <= 1e-14, string.format("editor rotations are unit to 1e-14 (%.3g)", math.abs(m - 1)))
			A.truthy(math.abs(m - 1) <= Limits.QUAT_NORM_TOL)
			noDiff(Canonical.quat(q), Quat.hemisphere(q), "only the hemisphere rule applies")
		end)
	end)

	t.it("T-UD-01 shortest round-trip JSON digits decode bit-identically (E-S1.3, S-PAR-03's values)", function()
		for _, x in {
			0.1, 1 / 3, 9007199254740992 + 1, 1e-300, 123456.789012345678, -0.0000021366226676248005, 0.036324661366823635,
			0.9999999999931523, 16, -16, 0.02, 6, 5e-324, 2.2250738585072014e-308, 1e21, 1.7976931348623157e308,
		} do -- 2^53 + 1 is 2^53 in doubles
			local back = roundTrip(x)
			A.truthy(Drafts.sameBits(back, x), string.format("%.17g came back as %.17g", x, back))
		end
		A.eq(Drafts.jsonNumber(-0.0), "-0", "JSONEncode writes −0 as -0; C5 keeps it out of records")
		Prop.check(Tol.PROP_N, function(rng: TestRng): { number }
			local xs = {}
			for i = 1, 50 do
				local mode = i % 5
				xs[i] = if mode == 0 then rng:range(-16, 16)
					elseif mode == 1 then rng:range(-1e-5, 1e-5)
					elseif mode == 2 then rng:range(Limits.MIN_DIM, Limits.MAX_DIM)
					elseif mode == 3 then rng:normal(0, 1) / 2
					else rng:range(-1, 1) * 1e-7
			end
			return xs
		end, function(xs: { number })
			for _, x in xs do
				local text = Drafts.jsonNumber(x)
				A.truthy(#text <= 25, string.format("%s is longer than 25 characters (§3.5)", text))
				A.truthy(Drafts.sameBits(roundTrip(x), x), string.format("%.17g", x))
			end
		end)
	end)
end)
