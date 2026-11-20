--!strict
-- Minigames/Types (SPEC §6.2, §6.8–§6.10; owner S3): the types every Minigames module and its callers (S5's judge,
-- S6's host and views, Bots, tests) share. Types only; it returns an empty frozen table.
-- S2's three types (Physics/Edge's Vec2 and EdgeChain, Physics/Factors' FactorValue) are declared again here as
-- structural copies, so no Minigames module requires Physics (Luau has no type-only require: requiring
-- Physics/Analyze would load its whole stack). Luau types are structural, so they are the same types; a test helper
-- typed from Analyze's exports makes luau-lsp check that the two stay compatible.
-- String literals inside optional table fields widen to `string` under luau-lsp, so FlagId, InvalidReason and Grade
-- values are built through typed locals or constructors.

local DT = require("../Definitions/Types")

-- ── S2's types, as structural copies (owners Physics/Edge and Physics/Factors) ───────────────────────────────

export type Vec2 = { number } -- {x, y}
export type EdgeChain = { points: { Vec2 }, length: number }
export type FactorValue = { factor: DT.FactorId, raw: number, x: number }

-- ── §6.2 ──────────────────────────────────────────────────────────────────────────────────────────────────────

export type FlagId = "HzInhumanRate" | "TsLowVariance" | "TsExactHits" | "PtTooPrecise" | "PtTooSmooth"
	| "PtTeleport" | "PtSparse"
export type InvalidReason = "NotBuffer" | "Short" | "Version" | "Family" | "TooMany" | "Length" | "Duration"
	| "NotIncreasing" | "PastEnd" | "BadKind" | "NotAlternating" | "OutOfPanel" | "BadFlags" | "HashMismatch"
export type PrepareInput = {
	family: DT.FamilyId,
	seed: number,
	material: DT.MaterialId,
	tier: DT.TierId,
	factors: { FactorValue }, -- all 8 factors on this step's work set, FactorId order (S2)
	edge: { chains: { EdgeChain }, gripPoint: DT.Vec3, gripAxis: Vec2 }?, -- Sharpening
	balanceVersion: number,
}
export type StepSpec = {
	family: DT.FamilyId,
	seed: number,
	params: { [string]: number },
	source: { number }?,
	durationMs: number,
	countdownMs: number,
	patternHash: number,
	balanceVersion: number,
}
export type MinigameResult = {
	status: "Ok" | "Invalid",
	score: number,
	rawScore: number,
	passed: boolean,
	flags: { FlagId },
	invalidReason: InvalidReason?,
	breakdown: { [string]: number },
	elapsedMs: number,
}
export type FeedbackEvent = { kind: string, t: number, i: number?, value: number?, label: string? }
export type HoldRecord = { t: number, down: boolean } -- TimingStrike's record is the press time t
export type TraceRecord = { t: number, u: number, v: number, grind: boolean } -- u, v in 1/16384 panel units
export type FamilyModule<P, R, S, V> = {
	id: DT.FamilyId,
	generate: (number, { [string]: number }, { number }?) -> P,
	hash: (P) -> number,
	newSession: (P) -> S,
	push: (S, R) -> { FeedbackEvent },
	advance: (S, nowMs: number) -> { FeedbackEvent },
	view: (S, nowMs: number) -> V,
	finish: (S) -> MinigameResult,
	checks: (P, { R }, MinigameResult) -> { FlagId },
}

-- ── views and the Recorder (§6.8–§6.11; the views carry presentation only, no score) ───────────────────────────

export type Grade = "Perfect" | "Good" | "Ok" | "Miss"
export type HoldZoneView = {
	t: number,
	phase: "Ramp" | "Hold" | "Done",
	temperature: number,
	fire: number,
	zoneCenter: number,
	zoneHalf: number,
	softBand: number,
	inZone: boolean,
	runningScore: number,
	timeLeftMs: number,
}
export type TimingStrikeView = {
	t: number,
	cycle: number,
	cycles: number,
	marker: number,
	windowCenter: number,
	windowHalf: number,
	perfectHalf: number,
	goodHalf: number,
	next: { windowCenter: number, windowHalf: number }?,
	lastGrade: Grade?,
	lastErrorMs: number?,
	combo: number,
	runningScore: number,
	timeLeftMs: number,
}
export type PrecisionTraceView = {
	t: number,
	pacerU: number,
	pacerV: number,
	pacerArc: number,
	cursorArc: number?,
	distance: number?,
	onPath: boolean,
	grinding: boolean,
	accuracySoFar: number,
	coverage: number,
	paceLag: number?,
	credit: number?, -- the latest evaluated tick's accuracy credit, for §12.8's trail
	coveredRuns: { number }, -- covered bins as runs {first1, last1, first2, last2, …}, for §12.8's tint
	runningScore: number, -- §12.2's live score, as the other two views carry it (O14)
	timeLeftMs: number,
}
-- the only producer of records (§6.2): S6's InputCapture, Bots and autoplay; horizonMs and since are the host
-- loop's (§12.5), so a live session sees every record before a tick or span the replay would process after it
export type Recorder = {
	go: (self: Recorder, held: boolean, u: number?, v: number?, grind: boolean?) -> (),
	button: (self: Recorder, down: boolean, clockS: number, frameDtS: number) -> (),
	cursor: (self: Recorder, u: number, v: number, grind: boolean, clockS: number) -> (),
	release: (self: Recorder) -> (),
	records: (self: Recorder) -> { any },
	horizonMs: (self: Recorder, clockS: number, frameDtS: number) -> number,
	since: (self: Recorder, count: number) -> { any },
}

return table.freeze({})
