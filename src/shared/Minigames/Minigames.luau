--!strict
-- Minigames/Minigames (SPEC §6.1, §6.2, §10.5; owner S3): the facade. With Input.new and Params.explain it is the only
-- minigame API S5 (the server's session) and S6 (the client's host) call. Pure; it emits nothing (S5 logs StepScored).
--
--   prepare(input)        server, StartStep's P0 burst (§1.6): params = Params.resolve(family, material, tier,
--                         factors); Sharpening's source = PrecisionTrace.edgeToPanel(sidesFromChains(edge.chains,
--                         edge.gripPoint, edge.gripAxis), …, params.pacerSpeed), nil without an edge or when the
--                         pattern plays the fallback; pattern = generate(seed, params, source); the StepSpec (frozen)
--                         carries the pattern's durationMs and hash, Network's COUNTDOWN_MS and the input's
--                         balanceVersion
--   start(spec)           client: the pattern again from the spec's seed, params (verbatim, §6.4 rule 5) and source;
--                         nil, "Desync" when its hash is not the spec's (§12.1's flow)
--   judge(spec, pattern, timeline, elapsedMs)   server, in the Submit handler (§10.5), never throwing on any timeline:
--                         1 Timeline.decode → Invalid(reason); 1b more records than recordCap(spec) → Invalid
--                         ("TooMany"), an O(1) check (L6); 2 the header's hash ≠ the spec's → Invalid("HashMismatch");
--                         3–6 replay, with elapsedMs (S5's E) copied in for telemetry. Invalid: score = rawScore = 0,
--                         passed false, flags {}, breakdown {}
--   replay(spec, pattern, records)   the client's own code path: a session pushed every record, finish (rawScore);
--                         flags = the family's checks, sorted by id; any HIGH flag clamps score = min(rawScore,
--                         passThreshold); passed = score ≥ passThreshold (so passed ⇔ rawScore ≥ passThreshold,
--                         T-MG-14)
--   encode(spec, records) the client's Submit timeline (Timeline.encode with the spec's header fields)
--   get(family)           the family module (§6.2's FamilyModule), for S6's host: newSession, push, advance, view,
--                         finish
--   recordCap(spec)       the most records judge accepts: the family's MAX_RECORDS, and for PrecisionTrace
--                         floor(durationMs / PT_EVAL_MS) + 1, the most an unmodified client makes (§6.6 Caps): a trace
--                         sample is due once per PT_EVAL_MS from GO (L6, proven by Input.spec's property)
--
-- Every family module is a row of a frozen registry: a Phase 2 family adds one (§15), with its codec, Input rule and
-- Bots policy. TS_OFFSET_OFFER_MIN_JUDGED is re-exported for S6's results card (§6.9), which calls the facade only.

local MinigameFamilies = require("../Definitions/MinigameFamilies")
local Network = require("../Definitions/Network")
local DT = require("../Definitions/Types")
local Checks = require("./Checks")
local HoldZone = require("./HoldZone")
local Params = require("./Params")
local PrecisionTrace = require("./PrecisionTrace")
local Timeline = require("./Timeline")
local TimingStrike = require("./TimingStrike")
local Types = require("./Types")

type StepSpec = Types.StepSpec
type PrepareInput = Types.PrepareInput
type MinigameResult = Types.MinigameResult
type InvalidReason = Types.InvalidReason
type FlagId = Types.FlagId
type Family = Types.FamilyModule<any, any, any, any>

local REGISTRY: { [DT.FamilyId]: Family } = table.freeze({
	HoldZone = HoldZone,
	TimingStrike = TimingStrike,
	PrecisionTrace = PrecisionTrace,
} :: { [DT.FamilyId]: Family })

-- typed, so luau-lsp keeps the literal types (M1's lesson)
local DESYNC: "Desync" = "Desync"
local TOO_MANY: InvalidReason = "TooMany"
local HASH_MISMATCH: InvalidReason = "HashMismatch"
local OK: "Ok" = "Ok"
local INVALID: "Invalid" = "Invalid"

local function familyOf(family: DT.FamilyId, fn: string): Family
	local F = REGISTRY[family]
	if F == nil then
		error(string.format("Minigames.%s: no minigame module for %s", fn, tostring(family)), 3)
	end
	return F
end

local function invalid(reason: InvalidReason, elapsedMs: number): MinigameResult
	return {
		status = INVALID,
		score = 0,
		rawScore = 0,
		passed = false,
		flags = {},
		invalidReason = reason,
		breakdown = {},
		elapsedMs = elapsedMs,
	}
end

local Minigames = {
	TS_OFFSET_OFFER_MIN_JUDGED = TimingStrike.TS_OFFSET_OFFER_MIN_JUDGED,
}

function Minigames.get(family: DT.FamilyId): Family
	return familyOf(family, "get")
end

function Minigames.recordCap(spec: StepSpec): number
	local cap = MinigameFamilies.MAX_RECORDS[spec.family]
	if spec.family == "PrecisionTrace" then
		cap = math.min(cap, math.floor(spec.durationMs / PrecisionTrace.PT_EVAL_MS) + 1)
	end
	return cap
end

function Minigames.prepare(input: PrepareInput): (StepSpec, any)
	local family: DT.FamilyId = input.family
	local F = familyOf(family, "prepare")
	local params = table.freeze(Params.resolve(family, input.material, input.tier, input.factors))
	local source: { number }? = nil
	local edge = input.edge
	if family == "PrecisionTrace" and edge then
		source = PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(edge.chains, edge.gripPoint, edge.gripAxis),
			edge.gripPoint, edge.gripAxis, params.pacerSpeed)
	end
	local pattern = F.generate(input.seed, params, source)
	if source and pattern.usedFallback then
		source = nil -- the fallback plays whatever the source: the spec need not carry it
	end
	local spec: StepSpec = table.freeze({
		family = family,
		seed = input.seed,
		params = params,
		source = if source then table.freeze(source) else nil,
		durationMs = pattern.durationMs,
		countdownMs = Network.COUNTDOWN_MS,
		patternHash = F.hash(pattern),
		balanceVersion = input.balanceVersion,
	})
	return spec, pattern
end

function Minigames.start(spec: StepSpec): (any?, "Desync"?)
	local F = familyOf(spec.family, "start")
	local pattern = F.generate(spec.seed, spec.params, spec.source)
	if F.hash(pattern) ~= spec.patternHash then
		return nil, DESYNC
	end
	return pattern, nil
end

function Minigames.replay(spec: StepSpec, pattern: any, records: { any }): MinigameResult
	local family: DT.FamilyId = spec.family
	local F = familyOf(family, "replay")
	local S = F.newSession(pattern)
	for _, r in ipairs(records) do
		F.push(S, r) -- the events are the live host's, not the judge's (M4's D13)
	end
	local result = F.finish(S)
	local flags: { FlagId } = Checks.sorted(F.checks(pattern, records, result))
	local raw = result.rawScore
	local pass = spec.params.passThreshold
	local score = if Checks.anyHigh(family, flags) then math.min(raw, pass) else raw
	return {
		status = OK,
		score = score,
		rawScore = raw,
		passed = score >= pass,
		flags = flags,
		invalidReason = nil,
		breakdown = result.breakdown,
		elapsedMs = 0,
	}
end

function Minigames.judge(spec: StepSpec, pattern: any, timeline: unknown, elapsedMs: number): MinigameResult
	local records, hash = Timeline.decode(timeline, spec.family, spec.durationMs)
	if records == nil then
		return invalid(hash :: any, elapsedMs)
	end
	if #records > Minigames.recordCap(spec) then
		return invalid(TOO_MANY, elapsedMs)
	end
	if hash ~= spec.patternHash then
		return invalid(HASH_MISMATCH, elapsedMs)
	end
	local result = Minigames.replay(spec, pattern, records)
	result.elapsedMs = elapsedMs
	return result
end

function Minigames.encode(spec: StepSpec, records: { any }): buffer
	return Timeline.encode(spec.family, spec.durationMs, spec.patternHash, records)
end

return table.freeze(Minigames)
