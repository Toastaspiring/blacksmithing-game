--!nocheck
-- m3-plan-r2: is tests/Physics/PhysicsHelpers' H.p1() the prototype's P1 bit for bit (H.axisAngle normalizes, the
-- prototype's Quat.axisAngle does not), and H.ornate() the prototype's C09? Prints the parts that differ and how.
--   lune run <abs>/proto/p1bits.luau
local L = require("./lib")
local H = require("../repo/tests/Physics/PhysicsHelpers")
local fmt = string.format

local function cmp(name, mine, theirs)
	local n = 0
	for i, p in ipairs(mine) do
		local q = theirs[i]
		for _, f in ipairs({ "pos", "rot", "size" }) do
			for k = 1, #p[f] do
				if p[f][k] ~= q[f][k] then
					n += 1
					if n <= 4 then
						print(fmt("  %s part %d %s[%d]: %.17g vs the prototype's %.17g", name, i, f, k, p[f][k], q[f][k]))
					end
				end
			end
		end
		if p.slot ~= q.slot or p.shape ~= q.shape or p.material ~= q.material or p.id ~= q.id then
			n += 1
		end
	end
	print(fmt("%s: %d parts, %d differing fields", name, #mine, n))
end
cmp("H.p1", H.p1().parts, L.find("P1").parts)
cmp("H.ornate", H.ornate().parts, L.find("C09").parts)
