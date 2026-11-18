#!/bin/bash
# mkvariant.sh <dir>: <dir>/repo is a patched copy; give it lib.luau, the scripts, emu/proto and emu/repo (FORCE hook)
set -e
S="$(cd "$(dirname "$0")" && pwd)"
D="$1"
cp "$S/lib.luau" "$S/aftman.toml" "$S/.luaurc" "$D/"
cp "$S"/a_*.luau "$S"/x_*.luau "$S"/exactlib.luau "$S"/arrbrute.luau "$S"/tangles.luau "$D/" 2>/dev/null || true
mkdir -p "$D/emu/repo" "$D/emu/proto" "$D/out"
rm -rf "$D/emu/repo/src" "$D/emu/repo/tests"
cp -r "$D/repo/src" "$D/repo/tests" "$D/emu/repo/"
mkdir -p "$D/emu/repo/docs/spec/prototypes/S2"
cp -r "$D/repo/docs/spec/prototypes/S2/v2" "$D/emu/repo/docs/spec/prototypes/S2/"
cp "$S"/emu/proto/*.luau "$D/emu/proto/"
cp "$S/emu/repo/src/shared/Physics/Sampling.luau" "$D/emu/repo/src/shared/Physics/Sampling.luau.base"
python - "$D/emu/repo/src/shared/Physics/Sampling.luau" <<'PY'
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
s=s.replace(a2,"Sampling.INSIDE_MARGIN = INSIDE_MARGIN;\nlocal _ = nil;\n(Sampling :: any).FORCE = {} -- verifier's hook (emulator copy only)\n")
s=s.replace("--!strict","--!nocheck",1)
open(p,'w',encoding='utf-8',newline='').write(s)
PY
rm -f "$D/emu/repo/src/shared/Physics/Sampling.luau.base"
echo "variant ready: $D"
