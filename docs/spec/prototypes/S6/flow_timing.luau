--!strict
-- S6 prototype: forge-flow time budget (client presentation overhead vs play time).
-- Minigame durations from S3 prototype Params (Normal): HoldZone 15 s, TimingStrike 12 x 900 ms + 400 ms, PrecisionTrace ~5 panel units / 0.30 + 1 s. Countdown 3000 ms (S5 prototype). Run: lune run flow_timing.luau

local T = {
	fadeIn = 250, overviewRead = 8000, confirm = 0,
	cameraMove = 900, stepTitle = 1200, introRead = 4000, countdown = 3000,
	verifyRtt = 300, resultRead = 3500,
	finishRtt = 400, rarityReveal = 2600, resultsRead = 8000,
}
local steps = {
	{ name = "Smelting (HoldZone)", play = 15000 },
	{ name = "Hammering (TimingStrike)", play = 11200 },
	{ name = "Sharpening (PrecisionTrace)", play = 17700 },
}

local overhead, play = T.fadeIn + T.overviewRead + T.confirm, 0
local lines = {}
for i, s in steps do
	local stepOverhead = T.cameraMove + T.stepTitle + T.introRead + T.countdown + T.verifyRtt + T.resultRead
	overhead += stepOverhead
	play += s.play
	table.insert(lines, string.format("  step %d %-28s overhead %5.1f s  play %5.1f s", i, s.name, stepOverhead / 1000, s.play / 1000))
end
overhead += T.finishRtt + T.rarityReveal + T.resultsRead
for _, l in lines do print(l) end
local total = overhead + play
print(string.format("total %.1f s = play %.1f s (%.0f%%) + presentation %.1f s (%.0f%%)", total / 1000, play / 1000, 100 * play / total, overhead / 1000, 100 * overhead / total))
-- repeat-forge (player skips reading): intro 1 s, result 1.5 s, overview 2 s, results 3 s
local fast = 250 + 2000 + 3 * (900 + 1200 + 1000 + 3000 + 300 + 1500) + 400 + 2600 + 3000
print(string.format("experienced player (skips reading): presentation %.1f s, total %.1f s", fast / 1000, (fast + play) / 1000))
