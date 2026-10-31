-- longest checkpoint gap: median and max over 15 runs per fixture (Lune; GC noise included)
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local fmt = string.format
local list = { Fx.arming("Iron"), Fx.cleaver(), Fx.ornate(), Fx.golden()[4], Fx.golden()[5] }
for _, b in ipairs(Fx.perf()) do table.insert(list, b) end
for _, b in ipairs(list) do
	local gaps, calls = {}, 0
	for _ = 1, 15 do
		local last, longest = os.clock(), 0
		calls = 0
		Analyze.run(b, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			longest = math.max(longest, now - last)
			last = now
			calls += 1
		end })
		table.insert(gaps, longest)
	end
	table.sort(gaps)
	print(fmt("%-40s checkpoints %4d | longest gap median %.3f ms max %.3f ms (Lune) -> x2.6 %.2f / %.2f ms", b.name, calls, gaps[8] * 1000, gaps[15] * 1000, gaps[8] * 2600, gaps[15] * 2600))
end
