#!/bin/bash
# mkemu.sh <tree> <dir>: <dir>/proto = the S2 v2 prototype + verdict/analyze_build.luau (the M3 emulator); <dir>/repo = the
# tree's src, tests and S2 v2 with a FORCE.kept hook in Sampling (the emulator's hook, nothing else; V1's mkvariant.sh)
set -e
T="$1"
D="$2"
rm -rf "$D"
mkdir -p "$D/proto" "$D/repo/docs/spec/prototypes/S2"
R="/c/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game" # the prototype and its emulator come from the repo
cp "$R"/docs/spec/prototypes/S2/v2/*.luau "$D/proto/"
cp "$R/docs/spec/prototypes/S2/verdict/analyze_build.luau" "$D/proto/"
cp -r "$T/src" "$T/tests" "$D/repo/"
cp -r "$T/docs/spec/prototypes/S2/v2" "$D/repo/docs/spec/prototypes/S2/"
python - "$D/repo/src/shared/Physics/Sampling.luau" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8',newline='').read()
a="""	if capped then
		local contact: { { number } } = table.create(N)"""
b="""	local FK = (Sampling :: any).FORCE.kept
	if FK ~= nil and not capped then
		cleaned = {}
		for i = 1, N do
			kept[i] = FK[i] == true
			if not kept[i] then
				table.insert(cleaned, { partId = parts[i].id, reason = (if parts[i].volume < Geo.MIN_PART_VOLUME then "Dust" else "Enclosed") :: CleanReason })
			end
		end
	end
	if capped then
		local contact: { { number } } = table.create(N)"""
assert s.count(a)==1
s=s.replace(a,b)
a2="Sampling.INSIDE_MARGIN = INSIDE_MARGIN\n"
assert s.count(a2)==1
s=s.replace(a2,"Sampling.INSIDE_MARGIN = INSIDE_MARGIN;\nlocal _ = nil;\n(Sampling :: any).FORCE = {} -- the emulator's hook (this copy only)\n")
s=s.replace("--!strict","--!nocheck",1)
open(p,'w',encoding='utf-8',newline='').write(s)
PY
echo "emulator ready: $D"
