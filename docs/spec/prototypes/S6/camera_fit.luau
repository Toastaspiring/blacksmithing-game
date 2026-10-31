--!strict
-- S6 prototype: editor display scale k and camera framing numbers.
-- Pinhole camera; full window 1920x1080; FOV is vertical (Roblox Camera.FieldOfView).
-- Run: lune run camera_fit.luau

local VW, VH = 1920, 1080
local CENTRE_W, CENTRE_H = 1300, 942 -- editor viewport area left between panels (from ui_scale @1080p)
local FOV = 50 -- degrees, editor camera
local NEAR_MAX = 0.5 -- worst-case |Camera.NearPlaneZ| (docs: between 0.1 and 0.5)
local CAM_MIN_DIST = 2 * NEAR_MAX -- display studs
-- ASSUMED sword hitbox (S2 owns): X guard width, Y length, Z thickness, blueprint studs
local HB = { x = 1.6, y = 5.0, z = 0.6 } -- S2 prototype hitbox: x [-0.8,0.8], y [0,5], z [-0.3,0.3]
local MIN_DIM = 0.05 -- ASSUMED min part dimension (S1/S2 own), blueprint studs
local MARGIN = 0.9 -- fill 90% of the target rect

local f = (VH / 2) / math.tan(math.rad(FOV / 2)) -- focal length in px
print(string.format("FOV %d deg vertical -> focal %.1f px; hFOV %.1f deg", FOV, f, 2 * math.deg(math.atan((VW / VH) * math.tan(math.rad(FOV / 2))))))

-- Front view: blueprint Y horizontal on screen, X vertical, Z = depth.
local function frameDistance(k: number): number
	-- half extents in display studs
	local hx, hy, hz = HB.y * k / 2, HB.x * k / 2, HB.z * k / 2 -- screen-x half, screen-y half, depth half
	-- nearest face is at distance d - hz; require projection of half extents within margin of centre rect
	local dW = f * hx / (CENTRE_W / 2 * MARGIN) + hz
	local dH = f * hy / (CENTRE_H / 2 * MARGIN) + hz
	return math.max(dW, dH)
end

print("\n k   frameDist  pxPerBpStud@frame  minDetail(0.05bp)@minDist  zoomRange  lightVoxelsAlongBlade  floatUlp@y1000(bp)")
for _, k in { 1, 2, 3, 4, 5, 6 } do
	local d = frameDistance(k)
	local pxPerBp = f * k / d
	local detailPx = f * (MIN_DIM * k) / CAM_MIN_DIST
	local zoomRatio = (4 * d) / CAM_MIN_DIST
	local voxels = HB.y * k / 4
	local ulp = 2 ^ (math.floor(math.log(1000, 2)) - 23) / k
	print(string.format("%2d  %9.2f  %17.1f  %24.1f px  %8.1fx  %21.2f  %.2e", k, d, pxPerBp, detailPx, zoomRatio, voxels, ulp))
end

-- Orthographic frame-all size (vertical extent in display studs) for k = 4
local k = 4
local orthoV = math.max(HB.x * k / MARGIN * (VH / CENTRE_H), HB.y * k / MARGIN * (VH / CENTRE_W) * (VH / VH) * (VW / VH) / (VW / VH))
-- simpler: the ortho vertical size S must satisfy: blade length * (VH/S) <= CENTRE_W*MARGIN  and  width*(VH/S) <= CENTRE_H*MARGIN
local S1 = HB.y * k * VH / (CENTRE_W * MARGIN)
local S2 = HB.x * k * VH / (CENTRE_H * MARGIN)
print(string.format("\northo frame-all OrthographicSize (Vertical mode) at k=4: %.2f display studs (length-limited %.2f, width-limited %.2f)", math.max(S1, S2), S1, S2))
local _ = orthoV

-- world-per-pixel at the frame distance (k=4) and the gizmo arrow length for 110 px
local d4 = frameDistance(4)
local wpp = 2 * d4 * math.tan(math.rad(FOV / 2)) / VH
print(string.format("k=4: frame distance %.2f -> %.4f display studs/px (%.4f bp studs/px); 110px gizmo = %.2f display studs", d4, wpp, wpp / 4, 110 * wpp))
-- smallest/largest camera distance
print(string.format("CAM_MIN_DIST = %.2f display studs; CAM_MAX_DIST (4x frame) = %.1f", CAM_MIN_DIST, 4 * d4))
