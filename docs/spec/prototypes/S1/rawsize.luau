--!strict
-- S1 prototype: part size if transforms were stored as raw (unquantized) doubles.
-- Shortest round-trip formatting (what Roblox JSONEncode emits for 1/3: 16-17 sig. digits).
local function fmt(x: number): string
	if x == math.floor(x) then return string.format("%d", x) end
	for d = 1, 17 do
		local s = string.format("%." .. d .. "g", x)
		if tonumber(s) == x then return s end
	end
	return string.format("%.17g", x)
end
math.randomseed(3)
local total, n, maxLen = 0, 20000, 0
for _ = 1, n do
	local nums = {}
	for i = 1, 3 do nums[#nums + 1] = (math.random() * 2 - 1) * 3 end      -- pos
	local g = { math.random() - 0.5, math.random() - 0.5, math.random() - 0.5, math.random() - 0.5 }
	local s = math.sqrt(g[1]^2 + g[2]^2 + g[3]^2 + g[4]^2)
	for i = 1, 4 do nums[#nums + 1] = g[i] / s end                          -- rot
	for i = 1, 3 do nums[#nums + 1] = 0.05 + math.random() * 3 end         -- size
	local len = 0
	for _, v in nums do len += #fmt(v) end
	total += len
	maxLen = math.max(maxLen, len)
end
-- same numbers quantized (1e-4 / 1e-6) for comparison
local qt = 0
math.randomseed(3)
for _ = 1, n do
	local len = 0
	for i = 1, 3 do len += #fmt(math.round(((math.random() * 2 - 1) * 3) * 1e4) / 1e4) end
	local g = { math.random() - 0.5, math.random() - 0.5, math.random() - 0.5, math.random() - 0.5 }
	local s = math.sqrt(g[1]^2 + g[2]^2 + g[3]^2 + g[4]^2)
	for i = 1, 4 do len += #fmt(math.round(g[i] / s * 1e6) / 1e6) end
	for i = 1, 3 do len += #fmt(math.round((0.05 + math.random() * 3) * 1e4) / 1e4) end
	qt += len
end
print(("10 transform numbers per part: raw doubles avg %.1f chars (max %d); quantized avg %.1f chars"):format(total / n, maxLen, qt / n))
print(("=> part record ~%.0f B raw vs ~%.0f B quantized (keys/ids/punctuation ~%d B)"):format(total / n + 101, qt / n + 101, 101))
