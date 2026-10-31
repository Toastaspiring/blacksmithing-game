--!strict
-- S6 prototype: memory cost of the undo history (before/after part snapshots).
-- Run: lune run history_mem.luau

type Part = { id: number, shape: string, slot: string, material: string, pos: { x: number, y: number, z: number }, rot: { w: number, x: number, y: number, z: number }, size: { x: number, y: number, z: number } }

local function mkPart(i: number): Part
	return {
		id = i, shape = "Block", slot = "Blade", material = "Steel",
		pos = { x = i * 0.01, y = i * 0.1, z = 0 },
		rot = { w = 1, x = 0, y = 0, z = 0 },
		size = { x = 0.2, y = 0.5, z = 0.05 },
	}
end
local function copy(p: Part): Part
	return { id = p.id, shape = p.shape, slot = p.slot, material = p.material,
		pos = { x = p.pos.x, y = p.pos.y, z = p.pos.z }, rot = { w = p.rot.w, x = p.rot.x, y = p.rot.y, z = p.rot.z }, size = { x = p.size.x, y = p.size.y, z = p.size.z } }
end

collectgarbage("collect")
local before = collectgarbage("count")
local history = {}
local N_CMDS, PARTS_PER_CMD = 200, 64
for c = 1, N_CMDS do
	local patches = table.create(PARTS_PER_CMD)
	for i = 1, PARTS_PER_CMD do
		local p = mkPart(i + c)
		patches[i] = { id = i, index = i, before = copy(p), after = copy(p) }
	end
	history[c] = { label = "Move", patches = patches, selBefore = { 1, 2, 3 }, selAfter = { 1, 2, 3 } }
end
collectgarbage("collect")
local after = collectgarbage("count")
local kb = after - before
print(string.format("%d commands x %d part patches: %.0f KB total, %.0f bytes per part patch", N_CMDS, PARTS_PER_CMD, kb, kb * 1024 / (N_CMDS * PARTS_PER_CMD)))

-- transform-only patch (pos/rot/size only, no strings) as an optimisation estimate
collectgarbage("collect")
local b2 = collectgarbage("count")
local h2 = {}
for c = 1, N_CMDS do
	local patches = table.create(PARTS_PER_CMD)
	for i = 1, PARTS_PER_CMD do
		-- packed: 10 numbers before + 10 after in one array
		local t = table.create(20, 0)
		patches[i] = { id = i, t = t }
	end
	h2[c] = patches
end
collectgarbage("collect")
local a2 = collectgarbage("count")
print(string.format("packed transform patches: %.0f KB total, %.0f bytes per part patch", a2 - b2, (a2 - b2) * 1024 / (N_CMDS * PARTS_PER_CMD)))
local _ = history
local _2 = h2
