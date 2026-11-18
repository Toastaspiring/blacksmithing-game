--!nocheck
local L = require("./lib")
local Quat = L.Quat
local function frameTo(m)
	local ax, az = m[3], -m[1]
	local s = math.sqrt(ax * ax + az * az)
	if s < 1e-12 then
		return if m[2] > 0 then { 0, 0, 0, 1 } else { 1, 0, 0, 0 }
	end
	local ang = math.acos(math.max(-1, math.min(1, m[2])))
	return Quat.hemisphere(Quat.normalize({ ax / s * math.sin(ang / 2), 0, az / s * math.sin(ang / 2), math.cos(ang / 2) }))
end
for _, m in ipairs({ { 0.6719, -0.3118, 0.6719 }, { 0, -1, 0 }, { 1, 0, 0 }, { -0.3569, -0.8775, -0.3204 } }) do
	local l = math.sqrt(m[1]^2 + m[2]^2 + m[3]^2)
	m = { m[1] / l, m[2] / l, m[3] / l }
	local q = frameTo(m)
	local y = Quat.rotate(q, { 0, 1, 0 })
	print(string.format("m (%.4f %.4f %.4f) -> R*Y (%.4f %.4f %.4f)", m[1], m[2], m[3], y[1], y[2], y[3]))
end
