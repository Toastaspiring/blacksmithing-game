--!strict
-- Throwaway: print the plot build list as Markdown tables (shell in plot-local, stations/stands in their local frame).
local V = require("./vecmath")
local L = require("./layout")

local function rotText(r: V.Mat3): string
	local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-6 end
	if near(r[1], 1) and near(r[5], 1) and near(r[9], 1) then return "-" end
	if near(r[1], 1) then return string.format("rotX(%.2f)", math.deg(math.atan2(r[8], r[9]))) end
	if near(r[5], 1) then return string.format("rotY(%.2f)", math.deg(math.atan2(r[3], r[1]))) end
	if near(r[9], 1) then return string.format("rotZ(%.2f)", math.deg(math.atan2(r[4], r[1]))) end
	return "composite"
end
local function n(x: number): string
	local s = string.format("%.3f", x):gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" then s = "0" end
	return s
end
local function v3(v: { number }): string return n(v[1]) .. ", " .. n(v[2]) .. ", " .. n(v[3]) end

local plot = L.buildPlot()
local roots: { [string]: V.Xform } = {}
for _, st in L.STATIONS do roots["Station:" .. st.id] = st.root end

local tokenOf: { [string]: string } = {}
for k, c in L.PAL do tokenOf[table.concat(c, ",")] = k end

print("| Component | Part | Shape | Size | Position | Rotation | Collide | Material | Colour |")
print("|---|---|---|---|---|---|---|---|---|")
for _, p in plot do
	local xf = p.xf
	local comp = p.comp
	local name = p.name
	if roots[comp] then
		xf = V.compose(V.inverse(roots[comp]), xf)
		name = name:gsub("^[^%.]+%.", "")
	elseif comp == "Displays" then
		local i = tonumber(name:match("^Stand(%d+)")) :: number
		if i ~= 1 then continue end
		xf = V.compose(V.inverse(L.slotRoot(1)), xf)
		name = name:gsub("^Stand1%.", "")
		comp = "Stand (each)"
	end
	local col = tokenOf[table.concat(p.color, ",")] or ("(" .. table.concat(p.color, ",") .. ")")
	print(string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s |", comp:gsub("Station:", ""), name, p.shape, v3(p.size), v3(xf.p), rotText(xf.r), p.collide and "yes" or "no", p.material, col))
end
-- roof numbers
local run, rise = L.RIDGE_Z - L.EAVE_FRONT_Z, L.RIDGE_Y - L.EAVE_Y
print(string.format("\nroof: run %.2f rise %.2f pitch %.2f deg slab length %.2f", run, rise, math.deg(math.atan(rise / run)), math.sqrt(run * run + rise * rise) + 0.4))
