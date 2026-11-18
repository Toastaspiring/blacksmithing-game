#!/bin/bash
# mkvariant.sh <dir>: <dir>/repo is a patched copy; give it lib.luau, emu/proto and emu/repo (with the FORCE hook)
set -e
S="$(cd "$(dirname "$0")" && pwd)"
D="$1"
cp "$S/lib.luau" "$D/lib.luau"
cp "$S/aftman.toml" "$D/aftman.toml"
mkdir -p "$D/emu/repo" "$D/emu/proto"
rm -rf "$D/emu/repo/src" "$D/emu/repo/tests"
cp -r "$D/repo/src" "$D/emu/repo/"
cp -r "$D/repo/tests" "$D/emu/repo/"
mkdir -p "$D/emu/repo/docs/spec/prototypes/S2"
cp -r "$D/repo/docs/spec/prototypes/S2/v2" "$D/emu/repo/docs/spec/prototypes/S2/" 2>/dev/null || true
cp "$S/emu/proto/"*.luau "$D/emu/proto/"
F="$D/emu/repo/src/shared/Physics/Sampling.luau"
python - "$F" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
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
s=s.replace(a2,"Sampling.INSIDE_MARGIN = INSIDE_MARGIN;\nlocal _ = nil;\n(Sampling :: any).FORCE = {} -- verifier's hook\n")
s=s.replace("--!strict","--!nocheck",1)
open(p,'w',encoding='utf-8').write(s)
PY
echo "variant ready: $D"
