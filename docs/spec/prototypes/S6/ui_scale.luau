--!strict
-- S6 prototype: UI scale + editor/minigame layout fit across PC resolutions.
-- Run: lune run ui_scale.luau

local BASE_W, BASE_H = 1920, 1080
local SCALE_MIN, SCALE_MAX = 0.75, 2.0
local TOPBAR = 58 -- Roblox core topbar inset (px, not scaled by our UIScale) - assumed; real value from GuiService:GetGuiInset()

-- Editor layout in design px
local TOP_H, STATUS_H, LEFT_W, RIGHT_W = 52, 28, 280, 340
local RIGHT_MIN_CONTENT = 330 + 270 + 120 + 30 -- properties + preview + issues(min) + gaps
-- Minigame widgets in design px
local GAUGE_W, GAUGE_H = 140, 600
local DIAL_D = 440
local CANVAS_W, CANVAS_H = 1560, 520 -- S3 panel aspect 3:1 (PT.PANEL_W = 3)
local BODY_PT, SMALL_PT, MONO_PT = 16, 14, 15

local function uiScale(w: number, h: number, userMul: number): number
	local s = math.min(w / BASE_W, h / BASE_H) * userMul
	return math.clamp(s, SCALE_MIN, SCALE_MAX)
end

local resolutions = {
	{ 1024, 640 }, { 1280, 720 }, { 1366, 768 }, { 1440, 900 }, { 1536, 864 }, { 1600, 900 },
	{ 1920, 1080 }, { 1920, 1200 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 2160 },
}

print("res        scale  left  right  centreW  centreH  rightAvail(design)  fits  body  small  canvas(px)   band@hw.037  dial  gauge")
for _, r in resolutions do
	local w, h = r[1], r[2]
	local s = uiScale(w, h, 1.0)
	local left, right = LEFT_W * s, RIGHT_W * s
	local centreW = w - left - right
	local centreH = h - TOPBAR - (TOP_H + STATUS_H) * s
	local rightAvailDesign = (h - TOPBAR) / s - TOP_H - STATUS_H
	local fits = rightAvailDesign >= RIGHT_MIN_CONTENT
	local cw, ch = CANVAS_W * s, CANVAS_H * s
	-- shrink to 90% of the window width and to the height between header and hints (aspect kept)
	local availH = (h - TOPBAR) - (90 + 60) * s
	local f = math.min(1, (w * 0.9) / cw, availH / ch)
	cw, ch = cw * f, ch * f
	-- canvas must fit between header (~90 design) and hint bar (~60 design)
	local canvasFits = f >= 1
	print(string.format("%4dx%-4d  %.3f  %4.0f  %5.0f  %7.0f  %7.0f  %18.0f  %-4s  %4.1f  %5.1f  %4.0fx%-4.0f%s  %8.1f  %4.0f  %3.0fx%-3.0f",
		w, h, s, left, right, centreW, centreH, rightAvailDesign, fits and "yes" or "NO",
		BODY_PT * s, SMALL_PT * s, cw, ch, canvasFits and "" or "!", 2 * 0.037 * ch, DIAL_D * s, GAUGE_W * s, GAUGE_H * s))
end

-- user multiplier extremes at 1920x1080
print("\nuser UI-size multiplier at 1920x1080:")
for _, m in { 0.8, 0.9, 1.0, 1.1, 1.25, 1.5 } do
	local s = uiScale(1920, 1080, m)
	local rightAvailDesign = (1080 - TOPBAR) / s - TOP_H - STATUS_H
	print(string.format("  mul %.2f -> scale %.3f  centreW %4.0f  rightAvail %4.0f  fits %s  body %.1fpx",
		m, s, 1920 - (LEFT_W + RIGHT_W) * s, rightAvailDesign, tostring(rightAvailDesign >= RIGHT_MIN_CONTENT), BODY_PT * s))
end

-- minimum path half-width in canvas-height units so the band is >= 12 px wide at the smallest supported scale
local minCanvasH = math.min(CANVAS_H * SCALE_MIN, 1280 * 0.9 / 3)
print(string.format("\nsmallest canvas height = %.0f px -> band >= 12 px needs width >= %.4f canvas-height units (half-width >= %.4f)",
	minCanvasH, 12 / minCanvasH, 6 / minCanvasH))

-- S3 PrecisionTrace halfWidth values (panel-height units) -> band width in px (2*hw*H)
print("\ntrace band width (px) = 2 * halfWidth * canvasH:")
local hws = { { "Iron Normal", 0.037 }, { "Iron Hard", 0.037 * 0.85 }, { "Steel Hard", 0.037 * 0.92 * 0.85 }, { "Steel Hard thin (x0.85 design)", 0.037 * 0.92 * 0.85 * 0.85 }, { "S3 floor (min)", 0.012 } }
for _, r in { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } } do
	local s = uiScale(r[1], r[2], 1.0)
	local H = math.min(CANVAS_H * s, r[1] * 0.9 / 3)
	local line = string.format("  %4dx%-4d canvas %4.0fx%-4.0f:", r[1], r[2], 3 * H, H)
	for _, h in hws do
		line ..= string.format("  %s %.1f", h[1], 2 * h[2] * H)
	end
	print(line)
end
