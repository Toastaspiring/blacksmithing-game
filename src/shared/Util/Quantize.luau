--!strict
-- Util/Quantize (SPEC §9.5, §16.17; owner S1): the one quantizer for derived scalars. A derived scalar that is stored
-- and feeds a later computation is quantized once, where it is produced and before any threshold: G_s, m_s, D_s
-- (S2, before tierFor), step scores (S3, before the pass line, ScoreMismatch and the outcome), T, Q and stats (S4,
-- before the rarity mapping). Transforms and physics stay raw doubles; seeds, durationMs, times and ids are integers;
-- persistence and server-only code never quantize. So a recompute at the same versions is bit-identical. Pure.
--
--   q(x, scale) = math.round(x · scale) / scale          SCALAR_SCALE = 10000: the 1e-4 grid
--
-- math.round rounds halves away from zero (C round), exactly and identically on every platform. −0 → 0.
-- Idempotent bit for bit: q(q(x, s), s) == q(x, s). That holds while the grid index n = math.round(x · scale) has
-- |n| < 2^51, where (n / scale) · scale lands within 0.5 of n, so the second call rounds back to the same n; at
-- |n| ≥ 2^51 it can land on a neighbour and move the result (measured in Lune on random values of that band), so q
-- refuses it. The guard is on n, not on the raw product: a product in [2^51 − 0.5, 2^51) rounds up to n = 2^51, and
-- a guard on the product would accept that x and then refuse q(x). q errors on a non-finite x (NaN and ±inf would
-- encode silently into JSON, §9.2), on |math.round(x · scale)| ≥ 2^51 (2.25e11 on the 1e-4 grid: no game quantity
-- comes near it, so it can only be a bug; this also catches an overflowing product) and on a scale that is not a
-- positive finite number.

local IDEMPOTENT_LIMIT = 2251799813685248 -- 2^51

local Quantize = {
	SCALAR_SCALE = 10000, -- 1/unit: D, scores, T, Q and stats on the 1e-4 grid
}

function Quantize.q(x: number, scale: number): number
	if type(scale) ~= "number" or not (scale > 0 and scale < math.huge) then
		error("Quantize.q: scale must be a positive finite number, got " .. tostring(scale), 2)
	end
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		error("Quantize.q: non-finite value " .. tostring(x), 2)
	end
	local n = math.round(x * scale) -- the grid index; ±inf when the product overflows
	if not (math.abs(n) < IDEMPOTENT_LIMIT) then
		error(string.format("Quantize.q: |round(x · scale)| = %.17g is at or above 2^51, where q is not idempotent", n), 2)
	end
	local r = n / scale
	if r == 0 then
		return 0 -- folds −0
	end
	return r
end

return table.freeze(Quantize)
