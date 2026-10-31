--!strict
-- PrecisionTrace scripted bots + reference blade edges (not authoritative code)
local PT = require("./PrecisionTrace")
local Bots = require("./Bots")

local M = {}

-- reference blade edges (blueprint X-Y studs, base -> tip)
local function straightDouble(halfW: number, len: number, taperFrom: number)
	return {
		{ { halfW, 0 }, { halfW, taperFrom }, { 0, len } },
		{ { -halfW, 0 }, { -halfW, taperFrom }, { 0, len } },
	}
end
local function sabre()
	local e = {}
	for i = 0, 16 do
		local y = 3.2 * i / 16
		table.insert(e, { 0.24 + 0.35 * (y / 3.4) ^ 2, y })
	end
	table.insert(e, { 0.62, 3.45 })
	return { e }
end
local function flamberge(vox: number)
	local a, b = {}, {}
	local function q(x: number): number
		return math.floor(x / vox + 0.5) * vox
	end
	for i = 0, 60 do
		local y = 3.0 * i / 60
		local w = 0.24 + 0.05 * math.sin(2 * math.pi * y / 0.55)
		table.insert(a, { q(w), q(y) })
		table.insert(b, { q(-w), q(y) })
	end
	table.insert(a, { 0, 3.7 })
	table.insert(b, { 0, 3.7 })
	return { a, b }
end
M.BLADES = {
	{ "longsword (2 edges, 3.6 st)", straightDouble(0.22, 3.6, 2.9) },
	{ "sabre (1 curved edge, 3.45 st)", sabre() },
	{ "flamberge (wavy, voxel 0.05 st)", flamberge(0.05) },
	{ "dagger (2 edges, 1.5 st)", straightDouble(0.16, 1.5, 1.1) },
	{ "no usable edge -> fallback", nil },
}

export type Prof = { tau: number, sCross: number, tCross: number, tremor: number, lagMu: number, lagSigma: number, tLag: number, liftRate: number, startOff: number, pressMs: number }
M.PROFILES = {
	elite = { tau = 70, sCross = 0.006, tCross = 0.3, tremor = 0.0012, lagMu = -0.02, lagSigma = 0.02, tLag = 1.0, liftRate = 0, startOff = 0.005, pressMs = 0 },
	good = { tau = 100, sCross = 0.012, tCross = 0.35, tremor = 0.0015, lagMu = -0.04, lagSigma = 0.04, tLag = 1.0, liftRate = 0.003, startOff = 0.01, pressMs = 150 },
	poor = { tau = 160, sCross = 0.025, tCross = 0.4, tremor = 0.002, lagMu = -0.07, lagSigma = 0.08, tLag = 1.2, liftRate = 0.015, startOff = 0.03, pressMs = 350 },
} :: { [string]: Prof }
M.PANEL_PX = 500

local function normalAt(pat: PT.Pattern, s: number): (number, number)
	local u1, v1 = PT.pointAt(pat, math.max(0, s - 0.01))
	local u2, v2 = PT.pointAt(pat, math.min(pat.L, s + 0.01))
	local tu, tv = u2 - u1, v2 - v1
	local l = math.sqrt(tu * tu + tv * tv)
	if l == 0 then
		return 0, 0
	end
	return -tv / l, tu / l
end

local function q(x: number): number
	return math.floor(x * PT.Q + 0.5)
end

-- human hand: first-order tracking of a target that is the pacer +- an OU along-track lag, offset by an OU
-- cross-track error (scaled with sqrt(speed)), tremor, integer-pixel mouse, 60 fps frames, 20 ms recording schedule
function M.human(pat: PT.Pattern, prof: Prof, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "pt-human")
	local frames = Bots.frames(r, pat.durationMs)
	local su, sv = PT.pointAt(pat, 0)
	local cu, cv = su + prof.startOff * Bots.gauss(r), sv + prof.startOff * Bots.gauss(r)
	local lag, cross = prof.lagMu, 0
	local pressAt = if r:nextFloat() < 0.7 then 0 else prof.pressMs
	local liftUntil = -1
	local samples: { PT.Sample } = {}
	local nextDue = 0
	local fi = 1
	local lastGrind: boolean? = nil
	local dt = 2
	local t = 0
	local sScale = math.sqrt(pat.speed / 0.3)
	while t <= pat.durationMs and fi <= #frames do
		local dts = dt / 1000
		lag = Bots.ou(r, lag, prof.lagMu, prof.lagSigma, prof.tLag, dts)
		cross = Bots.ou(r, cross, 0, prof.sCross * sScale, prof.tCross, dts)
		local sStar = PT.pacerArc(pat, t)
		local sT = math.clamp(sStar + lag, 0, pat.L)
		if t < pat.leadInMs then
			sT = 0
		end
		local pu, pv = PT.pointAt(pat, sT)
		local nu, nv = normalAt(pat, sT)
		local du, dv = pu + cross * nu, pv + cross * nv
		local a = dt / prof.tau
		cu += (du - cu) * a
		cv += (dv - cv) * a
		if prof.liftRate > 0 and t > liftUntil and r:nextFloat() < prof.liftRate * dts then
			liftUntil = t + r:range(150, 400)
		end
		while fi <= #frames and frames[fi] <= t do
			local f = frames[fi]
			local grind = f >= pressAt and f > liftUntil
			if f >= nextDue or grind ~= lastGrind then
				local mu = cu + prof.tremor * Bots.gauss(r)
				local mv = cv + prof.tremor * Bots.gauss(r)
				mu = math.floor(mu * M.PANEL_PX + 0.5) / M.PANEL_PX
				mv = math.floor(mv * M.PANEL_PX + 0.5) / M.PANEL_PX
				local smp = { t = f, u = math.clamp(q(mu), 0, q(PT.PANEL_W)), v = math.clamp(q(mv), 0, PT.Q), grind = grind }
				if #samples > 0 and samples[#samples].t == f then
					samples[#samples] = smp
				else
					table.insert(samples, smp)
				end
				lastGrind = grind
				while nextDue <= f do
					nextDue += PT.EVAL_MS
				end
			end
			fi += 1
		end
		t += dt
	end
	return samples
end

-- fabricated: exactly on the pacer every `every` ms, optional white noise
function M.perfect(pat: PT.Pattern, noise: number, every: number, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "pt-cheat")
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
		if noise > 0 then
			u += noise * Bots.gauss(r)
			v += noise * Bots.gauss(r)
		end
		table.insert(out, { t = t, u = q(u), v = q(v), grind = true })
		t += every
	end
	return out
end

-- live session: push samples one at a time, advance after each (what the client does every frame)
function M.live(pat: PT.Pattern, samples: { PT.Sample }): PT.Result
	local s = PT.newSession(pat)
	for _, sm in samples do
		PT.push(s, sm)
		PT.advance(s)
	end
	local res = PT.finish(s)
	res.flags = PT.checks(pat, samples)
	return res
end

return M
