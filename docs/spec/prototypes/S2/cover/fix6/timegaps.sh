#!/bin/bash
# m2x-fix-6: fix5/gaps5.luau on the repo's build (src unchanged this round), with and without a collection at every
# checkpoint; the other Lune processes and the CPU load logged before and after each run (V2's timeall's measure).
#   bash timegaps.sh <tag> [collect|plain ...]
W=/c/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-6
R="/c/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
ROOT="C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
others() { tasklist //FI "IMAGENAME eq lune.exe" //NH 2>/dev/null | grep -c lune.exe; }
load() { powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average" 2>/dev/null | tr -d '\r'; }
TAG=$1; shift
cd "$R"
for mode in "$@"; do
	echo "== gaps_$mode start $(date +%T) others $(others) load $(load)%" >> "$W/out/timegaps_$TAG.log"
	arg=""; [ "$mode" = collect ] && arg=collect
	lune run docs/spec/prototypes/S2/cover/fix5/gaps5.luau -- "$ROOT" 15 fixtures,perf,worst $arg > "$W/out/gaps_${mode}_$TAG.txt" 2>&1
	echo "== gaps_$mode end $(date +%T) others $(others) load $(load)%" >> "$W/out/timegaps_$TAG.log"
done
cat "$W/out/timegaps_$TAG.log"
