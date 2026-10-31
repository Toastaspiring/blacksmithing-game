--!strict
-- S3 prototype: HoldZone (Smelting). Fixed-timestep simulation, TICK_MS = 10.
local R = require("./Rng")
local Rng = R.Rng

local TICK_MS = 10

export type HoldEvent = { t: number, down: boolean }

export type Pattern = {
	p: { [string]: number },
	keysT: { number }, -- keyframe times (ms, integers)
	keysC: { number }, -- keyframe zone centers (gauge 0..1)
	durationMs: number,
	rampMs: number,
	hash: number,
}

local HZ = {}
HZ.TICK_MS = TICK_MS

local function hashInts(h: number, v: number): number
	-- FNV-1a over 4 little-endian bytes of a u32
	v = v % 4294967296
	for _ = 1, 4 do
		h = R.mul32(bit32.bxor(h, v % 256), 0x01000193)
		v = v // 256
	end
	return h
end
HZ.hashInts = hashInts

function HZ.generate(seed: number, p: { [string]: number }): Pattern
	local rng = Rng.new(seed, "HoldZone.Target")
	local lo, hi = p.targetMin, p.targetMax
	local c0 = lo + (hi - lo) * rng:range(0.3, 0.7)
	local keysT, keysC = { 0, p.rampMs }, { c0, c0 }
	local t, c = p.rampMs, c0
	while t < p.durationMs do
		local seg = rng:int(p.segMinMs, p.segMaxMs)
		local nc = c
		if not rng:chance(p.holdChance) then
			local mag = p.driftSpeed * seg / 1000 * rng:range(0.5, 1.0)
			local sgn = rng:sign()
			nc = c + sgn * mag
			if nc > hi or nc < lo then
				nc = c - sgn * mag
			end
			nc = math.clamp(nc, lo, hi)
		end
		t += seg
		c = nc
		table.insert(keysT, t)
		table.insert(keysC, c)
	end
	local h = 0x811C9DC5
	for i = 1, #keysT do
		h = hashInts(h, keysT[i])
		h = hashInts(h, math.floor(keysC[i] * 1000000 + 0.5))
	end
	return { p = p, keysT = keysT, keysC = keysC, durationMs = p.durationMs, rampMs = p.rampMs, hash = h }
end

-- zone center at time t using a moving segment cursor (st.seg)
local function centerAt(pat: Pattern, st: { seg: number }, t: number): number
	local kt, kc = pat.keysT, pat.keysC
	while st.seg < #kt - 1 and kt[st.seg + 1] <= t do
		st.seg += 1
	end
	local t0, t1 = kt[st.seg], kt[st.seg + 1]
	local c0, c1 = kc[st.seg], kc[st.seg + 1]
	if t1 == nil or t1 <= t0 then
		return c0
	end
	local s = (t - t0) / (t1 - t0)
	if s > 1 then
		s = 1
	end
	local e = s * s * (3 - 2 * s) -- smoothstep, exact ops only
	return c0 + (c1 - c0) * e
end
HZ.centerAt = centerAt

export type Session = {
	pat: Pattern,
	events: { HoldEvent },
	ei: number,
	k: number, -- next tick index to integrate
	T: number,
	F: number,
	u: number,
	pressT: number,
	releaseAt: number?,
	credit: number,
	n: number,
	inZone: number,
	segState: { seg: number },
	lastC: number,
}

function HZ.newSession(pat: Pattern): Session
	return {
		pat = pat,
		events = {},
		ei = 1,
		k = 0,
		T = 0,
		F = 0,
		u = 0,
		pressT = -1e9,
		releaseAt = nil,
		credit = 0,
		n = 0,
		inZone = 0,
		segState = { seg = 1 },
		lastC = pat.keysC[1],
	}
end

function HZ.push(s: Session, ev: HoldEvent)
	table.insert(s.events, ev)
end

-- integrate all ticks k with k*TICK <= nowMs (and < duration)
function HZ.advance(s: Session, nowMs: number)
	local pat = s.pat
	local p = pat.p
	local K = pat.durationMs // TICK_MS
	local alpha = TICK_MS / p.fireLagMs
	local dts = TICK_MS / 1000
	local h = p.zoneWidth / 2
	local soft = p.softFrac * p.zoneWidth
	local evs = s.events
	while s.k < K and s.k * TICK_MS <= nowMs do
		local t = s.k * TICK_MS
		while s.ei <= #evs and evs[s.ei].t <= t do
			local e = evs[s.ei]
			local ra = s.releaseAt
			if ra and ra <= e.t then
				s.u = 0
				s.releaseAt = nil
			end
			if e.down then
				s.u = 1
				s.pressT = e.t
				s.releaseAt = nil
			else
				if e.t - s.pressT >= p.minStrokeMs then
					s.u = 0
				else
					s.releaseAt = s.pressT + p.minStrokeMs
				end
			end
			s.ei += 1
		end
		local ra = s.releaseAt
		if ra and ra <= t then
			s.u = 0
			s.releaseAt = nil
		end
		s.F = s.F + (s.u - s.F) * alpha
		local T = s.T + p.heatDecay * (p.fullHeat * s.F - s.T) * dts
		if T < 0 then
			T = 0
		elseif T > 1 then
			T = 1
		end
		s.T = T
		local tEnd = t + TICK_MS
		local c = centerAt(pat, s.segState, tEnd)
		s.lastC = c
		local hist = (s :: any).hist
		if hist then
			hist.T[s.k] = T
			hist.C[s.k] = c
			hist.F[s.k] = s.F
		end
		if tEnd > pat.rampMs then
			local d = math.abs(T - c)
			local cr
			if d <= h then
				cr = 1
				s.inZone += 1
			else
				cr = 1 - (d - h) / soft
				if cr < 0 then
					cr = 0
				end
			end
			s.credit += cr
			s.n += 1
		end
		s.k += 1
	end
end

export type Result = { score: number, passed: boolean, inZoneFrac: number, flags: { string } }

local function round4(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end

function HZ.finish(s: Session): Result
	HZ.advance(s, s.pat.durationMs)
	local score = if s.n > 0 then round4(s.credit / s.n) else 0
	return { score = score, passed = score >= s.pat.p.passThreshold, inZoneFrac = if s.n > 0 then s.inZone / s.n else 0, flags = {} }
end

function HZ.replay(pat: Pattern, events: { HoldEvent }): Result
	local s = HZ.newSession(pat)
	for _, e in events do
		HZ.push(s, e)
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events)
	return res
end

-- impossible-input checks
HZ.RATE_WINDOW_MS = 1000
HZ.RATE_MAX_PRESSES = 30
function HZ.checks(pat: Pattern, events: { HoldEvent }): { string }
	local flags = {}
	local presses = {}
	for _, e in events do
		if e.down then
			table.insert(presses, e.t)
		end
	end
	local j = 1
	for i = 1, #presses do
		while presses[i] - presses[j] >= HZ.RATE_WINDOW_MS do
			j += 1
		end
		if i - j + 1 >= HZ.RATE_MAX_PRESSES then
			table.insert(flags, "HZ_InhumanRate")
			break
		end
	end
	return flags
end

return HZ
