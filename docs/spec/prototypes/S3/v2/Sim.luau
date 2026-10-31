--!strict
-- S3 prototype v2: run N bot plays of one (family, material, tier, design x, profile) and collect scores.
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Bots = require("./Bots")
local Blades = require("./Blades")

local Sim = {}

-- reference design point per tier (every factor of the step's weight list at this x)
Sim.REF_X = { Normal = 0.10, Hard = 0.30 }

function Sim.seedOf(i: number, salt: number): number
	return (i * 2654435761 + salt * 40503 + 12345) % 4294967296
end

local sourceCache: { [string]: { number }? } = {}
function Sim.source(bladeKey: string, pacerSpeed: number): { number }?
	local key = bladeKey .. "@" .. pacerSpeed
	if sourceCache[key] == nil then
		local b = (Blades :: any)[bladeKey]
		local sides = PT.sidesFromChains(b.chains, b.grip, b.axis)
		local src = PT.edgeToPanel(sides, b.grip, b.axis, pacerSpeed)
		sourceCache[key] = src or false :: any
	end
	local v = sourceCache[key]
	return if v == false then nil else v
end

export type RunOpts = { family: string, material: string, tier: string, x: number?, profile: string, fps: number?, policy: string?, n: number, salt: number?, blade: string?, offsetMs: number? }

-- returns scores, passes, flags (booleans), extra
function Sim.run(o: RunOpts): ({ number }, { boolean }, { boolean }, any)
	local x = o.x or Sim.REF_X[o.tier]
	local p = Params.resolve(o.family, o.material, o.tier, Params.refFactors(x))
	local prof = (Bots.PROFILES :: any)[o.profile]
	if o.fps and prof then
		prof = Bots.variant(prof, o.fps)
	end
	local salt = o.salt or 1
	local scores, passes, flags = {}, {}, {}
	local extra = { presses = 0 }
	for i = 1, o.n do
		local seed = Sim.seedOf(i, salt)
		local botSeed = i * 7919 + salt * 31 + 17
		local res
		if o.family == "HoldZone" then
			local pat = HZ.generate(seed, p)
			if o.profile == "Idle" then
				res = HZ.replay(pat, {})
			elseif o.profile == "Perfect" then
				local _, r0 = Bots.hzPerfect(pat)
				res = r0
			elseif o.policy == "best" then
				local _, r1 = Bots.hzHuman(pat, prof, botSeed, "hold")
				local _, r2 = Bots.hzHuman(pat, prof, botSeed, "pump")
				res = if r2.score > r1.score then r2 else r1
			else
				local ev, r = Bots.hzHuman(pat, prof, botSeed, o.policy or "pump")
				res = r
				for _, e in ev do
					if e.down then
						extra.presses += 1
					end
				end
			end
		elseif o.family == "TimingStrike" then
			local pat = TS.generate(seed, p)
			local presses
			if o.profile == "Idle" then
				presses = {}
			elseif o.profile == "Perfect" then
				presses = Bots.tsPerfect(pat, o.fps or 60, botSeed)
			else
				presses = Bots.tsHuman(pat, prof, botSeed, o.offsetMs)
			end
			res = TS.replay(pat, presses)
		else
			local pat = PT.generate(seed, p, Sim.source(o.blade or "arming", p.pacerSpeed))
			local samples
			if o.profile == "Idle" then
				samples = {}
			elseif o.profile == "Perfect" then
				samples = Bots.ptPerfect(pat, 0, 20, botSeed)
			else
				samples = Bots.ptHuman(pat, prof, botSeed)
			end
			res = PT.replay(pat, samples)
		end
		scores[i] = res.score
		passes[i] = res.passed
		flags[i] = #res.flags > 0
	end
	return scores, passes, flags, extra
end

function Sim.summary(o: RunOpts): Bots.Stats
	local s, p, f = Sim.run(o)
	return Bots.stats(s, p, f)
end

return Sim
