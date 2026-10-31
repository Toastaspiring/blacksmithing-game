-- replay (+ checks) and generate costs for HoldZone and TimingStrike, worst honest timelines (Lune ms)
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local Params = require("./Params")
local Bots = require("./Bots")
local function ms(f) local t = os.clock(); f(); return (os.clock() - t) * 1000 end
local pH = Params.resolve("HoldZone", "Steel", "Hard", Params.refFactors(1))
local g, r, pat = 0, 0, nil
for s = 1, 20 do g = math.max(g, ms(function() pat = HZ.generate(s, pH) end)) end
-- worst honest: 28 presses/s for the whole 18 s step (1,008 records)
local ev = {}
local t = 0
while t + 15 < pat.durationMs and #ev < 1022 do table.insert(ev, { t = t, down = true }); table.insert(ev, { t = t + 15, down = false }); t += 36 end
for _ = 1, 10 do r = math.max(r, ms(function() HZ.replay(pat, ev) end)) end
print(string.format("HoldZone: generate max %.3f ms; replay+checks %.3f ms (%d records, %d ms)", g, r, #ev, pat.durationMs))
local pT = Params.resolve("TimingStrike", "Steel", "Hard", Params.refFactors(1))
local g2, r2 = 0, 0
for s = 1, 20 do g2 = math.max(g2, ms(function() pat = TS.generate(s, pT) end)) end
local pr = {}
t = 0
while t <= pat.durationMs and #pr < 512 do table.insert(pr, t); t += 33 end
for _ = 1, 10 do r2 = math.max(r2, ms(function() TS.replay(pat, pr) end)) end
print(string.format("TimingStrike: generate max %.3f ms; replay+checks %.3f ms (%d presses)", g2, r2, #pr))
