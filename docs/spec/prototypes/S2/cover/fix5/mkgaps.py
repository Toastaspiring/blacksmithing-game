"""m2x-fix-5: gaps/ = a copy of hook/ (the build + Cover._lies) whose Analyze calls its checkpoint with the units reported
since the last one and the report that crossed CHECK_UNITS (−1 at a phase), for gapwhy.luau.
   python mkgaps.py"""
import os, shutil
W = os.path.dirname(os.path.abspath(__file__))
src, dst = os.path.join(W, "hook"), os.path.join(W, "gaps")
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst)
p = os.path.join(dst, "src/shared/Physics/Analyze.luau")
s = open(p, encoding="utf-8", newline="").read()
a = """	local function spend(n: number)
		units += n
		if units >= CHECK_UNITS then
			units = 0
			if checkpoint then
				checkpoint()
			end
		end
	end
	local function phase()
		units = 0
		if checkpoint then
			checkpoint()
		end
	end"""
b = """	local function spend(n: number)
		units += n
		if units >= CHECK_UNITS then
			local u = units
			units = 0
			if checkpoint then
				(checkpoint :: any)(u, n)
			end
		end
	end
	local function phase()
		local u = units
		units = 0
		if checkpoint then
			(checkpoint :: any)(u, -1)
		end
	end"""
assert s.count(a) == 1
s = s.replace(a, b).replace("--!strict", "--!nocheck", 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", dst)
