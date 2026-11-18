--!nocheck
-- m3-plan-r2: §17.1 O8's numbers through the emulator in the measure's rank order: F3 with its main blade (part 6)
-- labelled Guard (Sharpening 0.6104 → 0.0645), C08 with its blade (part 4) labelled Guard (0.2487 → 0).
--   lune run <abs>/proto/o8.luau
local L = require("./lib")
local fmt = string.format
for _, c in ipairs({ { "F3", 6 }, { "C08", 4 } }) do
	local b = L.find(c[1])
	local parts = {}
	for i, p in ipairs(b.parts) do
		parts[i] = table.clone(p)
	end
	local before = L.run(L.inRankOrder(b))
	parts[c[2]].slot = "Guard"
	local after = L.run(L.inRankOrder({ name = b.name, parts = parts }))
	print(fmt("%s part %d (%s) relabelled Guard: %s → %s", c[1], c[2], b.parts[c[2]].label or "?", (L.dline(before)), (L.dline(after))))
end
