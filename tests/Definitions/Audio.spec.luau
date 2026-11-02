--!strict
-- Definitions/Audio (SPEC §12.10, §13.11, §16.16; T-DEF-07 "Audio cues well formed"): the 14 cue rows, their order,
-- and what a row may hold: a PascalCase hook, a sound id that is "" (silent) or an rbxassetid, a Sound Volume and a
-- PlaybackSpeed range.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Audio = require("../../src/shared/Definitions/Audio")

-- §12.10's hooks, in its order (Q20: about 14 sound effects)
local HOOKS = {
	"Go", "CountdownTick", "CycleStart", "StrikePerfect", "StrikeGood", "StrikeOk", "Miss", "Bellows", "FurnaceLoop",
	"GrindLoop", "Pass", "Fail", "RarityReveal", "UiClick",
}

return Test.suite("Definitions/Audio", function(t)
	t.it("T-DEF-07 the 14 cues of §12.10, in order, one row each", function()
		local hooks: { string } = {}
		for _, cue in Audio.CUES do
			table.insert(hooks, cue.hook)
		end
		A.deepEq(hooks, HOOKS, "hooks")
		A.deepEq(Dump.sortedKeys(Audio), { "CUES" }, "the module holds the cue rows only")
	end)

	t.it("T-DEF-07 cues well formed: hook, id, volume, pitch range", function()
		local seen: { [string]: boolean } = {}
		for i, cue in Audio.CUES do
			local where = "cue " .. i .. " (" .. tostring(cue.hook) .. ")"
			A.deepEq(Dump.sortedKeys(cue), { "hook", "id", "pitchRange", "volume" }, where .. " fields")
			A.truthy(string.match(cue.hook, "^%u%w*$") ~= nil, where .. ": PascalCase hook")
			A.falsy(seen[cue.hook], where .. ": unique hook")
			seen[cue.hook] = true
			A.truthy(cue.id == "" or string.match(cue.id, "^rbxassetid://%d+$") ~= nil,
				where .. ": id is \"\" (silent) or rbxassetid://<n>")
			A.within(cue.volume, 0, 10, where .. ": Sound.Volume range")
			A.eq(#cue.pitchRange, 2, where .. ": pitchRange is {min, max}")
			A.finite(cue.pitchRange[1], where .. ".pitchRange[1]")
			A.finite(cue.pitchRange[2], where .. ".pitchRange[2]")
			A.truthy(cue.pitchRange[1] > 0 and cue.pitchRange[1] <= cue.pitchRange[2], where .. ": 0 < min ≤ max")
		end
	end)

	t.it("T-DEF-06 frozen", function()
		A.truthy(table.isfrozen(Audio), "module frozen")
		A.truthy(table.isfrozen(Audio.CUES), "rows frozen")
		for _, cue in Audio.CUES do
			A.truthy(table.isfrozen(cue) and table.isfrozen(cue.pitchRange), cue.hook .. " frozen")
		end
	end)
end)
