local HZ = require("./HoldZone")
local Params = require("./Params")
local Bots = require("./Bots")
local p = Params.resolve("HoldZone", "Iron", "Normal", Params.refFactors(0.1))
local pat = HZ.generate(12345, p)
local s = HZ.newSession(pat)
s.hist = { T = {}, C = {} }
local ev, res = Bots.hzPerfect(pat)
print("events", #ev, "score", res.score)
-- replay with history
local s2 = HZ.newSession(pat)
s2.hist = { T = {}, C = {} }
for _, e in ev do HZ.push(s2, e) end
HZ.finish(s2)
for k = 0, 1499, 100 do
	print(k * 10, string.format("T=%.3f c=%.3f", s2.hist.T[k], s2.hist.C[k]))
end
local nd = 0
for _, e in ev do if e.down then nd += 1 end end
print("downs", nd)
